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
    addr: u64,
};

const LL = LinkedList(Block);
var free_list = LL{};

pub fn pageUp(addr: u64) u64 {
    return (addr + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
}

pub fn pageDown(addr: u64) u64 {
    return addr & ~(PAGE_SIZE - 1);
}

pub fn initFreeList() void {
    const heap = heapInfo();
    var p = pageUp(heap.start);
    while (p + PAGE_SIZE < pageDown(heap.end)) {
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

    const ptr = @intToPtr([*]u8, addr);
    // Fill with junk
    for (ptr[0..PAGE_SIZE]) |*p| p.* = 1;

    const block = .{ .addr = addr };
    var node = LL.Node{ .data = block };
    // lol is a reference even safe?
    free_list.prepend(&node);
}

pub fn kalloc() []u8 {
    const block = free_list.popFirst();
    const addr = block.addr;
    const ptr = @intToPtr([PAGE_SIZE]u8, addr);
    return ptr;
}

pub fn printFreePages() void {
    // const heap = heapInfo();
    // var p = pageUp(heap.start);
    // while (p < pageDown(heap.end)): (p += PAGE_SIZE) {

    {
        var n = free_list.first;
        const len = free_list.len();
        printf("Length: {d}\n", .{len});
        var cnt: usize = 0;
        while (n) |node| : (n = node.next) {
            const block = node.data;
            printf("Addr: {x}\n", .{block.addr});
            cnt += 1;
        }
    }
    // while (node) |n| {
    //     const block = n.data;
    //     printf("Addr: {x}\n", .{block.addr});
    //     // colon doesn't with |n| ?
    //     node = n.next;
    // }
}
