const builtin = @import("std").builtin;
const uart = @import("uart.zig");
const freelist = @import("freelist.zig");
const pagetable = @import("pagetable.zig");

pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    uart.printf("\nPANIC MESSAGE:\n", .{});
    uart.printf("{s}", .{message});
    uart.printf("\n", .{});

    while (true) {}
}

export fn kmain() noreturn {
    uart.uartInit();
    freelist.initFreeList();
    // TODO: set the kernel's satp to this. right?
    const kpgt = pagetable.kvmInit();
    uart.printf("Kernel page table: {any}", .{kpgt});

    freelist.printFreePages();
    @panic("You reached kmain!");
}
