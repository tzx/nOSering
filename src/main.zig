const builtin = @import("std").builtin;
const uart = @import("uart.zig");

pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    uart.print("\nPANIC MESSAGE:\n");
    uart.print(message);
    uart.print("\n");

    while (true) {}
}

export fn kmain() noreturn {
    uart.uartInit();
    @panic("You reached kmain!");
}
