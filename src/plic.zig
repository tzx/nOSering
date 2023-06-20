const memlayout = @import("memlayout.zig");

pub const UART_SRC = 0x0a;
pub const VIRTIO0_SRC = 0x01;

pub fn plicInit() void {
    // Turn on priority
    const uart_priority = @intToPtr(*u32, memlayout.PLIC + 4 * UART_SRC);
    uart_priority.* = 1;
    const virtio0_priority = @intToPtr(*u32, memlayout.PLIC + 4 * VIRTIO0_SRC);
    virtio0_priority.* = 1;

    // TODO: cpu hartid
    const cpu_id = 0;
    const smode_enable = @intToPtr(*u32, memlayout.PLIC + 0x2080 + 0x100 * cpu_id);
    smode_enable.* = 1 << UART_SRC | 1 << VIRTIO0_SRC;
    const smode_threshold = @intToPtr(*u32, memlayout.PLIC + 0x20_1000 + 0x2000 * cpu_id);
    smode_threshold.* = 0;
}

pub fn plicClaim() u32 {
    // TODO: cpu hartid
    const hart_id = 0;
    const irq_p = @intToPtr(*u32, memlayout.PLIC + 0x201004 + 0x2000 * hart_id);
    return irq_p.*;
}

pub fn plicComplete(irq: u32) void {
    // TODO: cpu hartid
    const hart_id = 0;
    const irq_p = @intToPtr(*u32, memlayout.PLIC + 0x201004 + 0x2000 * hart_id);
    irq_p.* = irq;
}
