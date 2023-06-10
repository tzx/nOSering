const LinkedList = @import("std").SinglyLinkedList;

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

    const ptr = @intToPtr([*]u8, addr);
    // Fill with junk
    for (ptr[0..PAGE_SIZE]) |*p| p.* = 1;

    const block = .{ .addr = addr };
    var node = LL.Node{ .data = block };
    free_list.prepend(&node);
}

pub fn kalloc() []u8 {
    const block = free_list.popFirst();
    const addr = block.addr;
    const ptr = @intToPtr([PAGE_SIZE]u8, addr);
    return ptr;
}
