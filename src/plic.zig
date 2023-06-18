const memlayout = @import("memlayout.zig");

const UART_SRC = 0x0a;

pub fn plicInit() void {
    // Turn on priority
    const uart_priority = @intToPtr(*u32, memlayout.PLIC + 4 * UART_SRC);
    uart_priority.* = 1;

    // TODO: cpu hartid
    const cpu_id = 0;
    const smode_enable = @intToPtr(*u32, memlayout.PLIC + 0x2080 + 0x100 * cpu_id);
    smode_enable.* = 1 << UART_SRC;
    const smode_threshold = @intToPtr(*u32, memlayout.PLIC + 0x20_1000 + 0x2000 * cpu_id);
    smode_threshold.* = 0;
}
