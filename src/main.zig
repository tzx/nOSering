const builtin = @import("std").builtin;
const uart = @import("uart.zig");
const freelist = @import("freelist.zig");

pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    uart.printf("\nPANIC MESSAGE:\n", .{});
    uart.printf("{s}", .{message});
    uart.printf("\n", .{});

    while (true) {}
}

export fn kmain() noreturn {
    uart.uartInit();
    freelist.initFreeList();
    freelist.printFreePages();
    @panic("You reached kmain!");
}
