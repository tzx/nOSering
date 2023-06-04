export fn kmain() callconv(.Naked) noreturn {
    var uart = @intToPtr(*u8, 0x1000_0000);
    uart.* = 'h';
    while (true) {}
}
