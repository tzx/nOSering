export fn kmain() noreturn {
    var uart = @intToPtr(*volatile u8, 0x1000_0000);
    for ("hello world!") |c| {
        uart.* = c;
    }
    while (true) {}
}
