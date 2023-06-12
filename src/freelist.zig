const LinkedList = @import("std").SinglyLinkedList;
const printf = @import("uart.zig").printf;

extern const _heap_start: u8;
extern const _PHYSTOP: u8;
pub const PAGE_SIZE: usize = 4096;

// Not lazy: https://github.com/ziglang/zig/issues/15080
const HeapInfo = struct {
    start: usize,
    end: usize,
};

fn heapInfo() HeapInfo {
    const start = @ptrToInt(&_heap_start);
    const end = @ptrToInt(&_PHYSTOP);
    return .{ .start = start, .end = end };
}

const Block = struct {
    next: ?*Block,
};

const FreeList = struct {
    head: ?*Block,
};

var free_list = FreeList{
    .head = null,
};

pub fn pageUp(addr: u64) u64 {
    return (addr + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
}

pub fn pageDown(addr: u64) u64 {
    return addr & ~(PAGE_SIZE - 1);
}

pub fn initFreeList() void {
    const heap = heapInfo();
    var p = pageUp(heap.start);
    while (p + PAGE_SIZE <= pageDown(heap.end)) {
        kfree(p);
        p += PAGE_SIZE;
    }
}

pub fn kfree(addr: u64) void {
    // Not aligned
    if (addr % PAGE_SIZE != 0) {
        @panic("freeBlock: Address is not aligned to PAGE_SIZE");
    }
    // Not in range of heap
    const heap = heapInfo();
    if (addr < heap.start or addr >= heap.end) {
        @panic("freeBlock: Address is not in range of heap");
    }

    // Fill with junk
    const ptr = @intToPtr([*]u8, addr);
    for (ptr[0..PAGE_SIZE]) |*p| p.* = 1;

    var bptr = @ptrCast(*Block, @alignCast(@alignOf(*Block), ptr));
    // TODO: function for free_list
    bptr.next = free_list.head;
    free_list.head = bptr;
}

pub fn kalloc() ![]u8 {
    const bptr = free_list.head orelse return error.OutOfMemory;
    free_list.head = bptr.next;
    const ptr = @ptrCast([*]u8, bptr)[0..PAGE_SIZE];
    return ptr;
}

pub fn printFreePages() void {
    var len: usize = 0;
    var head = free_list.head;
    while (head) |block| : (head = block.next) {
        len += 1;
        const addr = @ptrToInt(block);
        printf("Addr: {x}\n", .{addr});
    }
    printf("Number of free pages: {d}\n", .{len});
}
