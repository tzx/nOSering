const PAGE_SIZE = @import("memlist.zig").PAGE_SIZE;

pub const UART0 = 0x1000_0000;
pub const VIRTIO0 = 0x1000_1000;
pub const PLIC = 0xc00_0000;
pub const PLIC_SIZE = 0x60_0000;
pub const CLINT = 0x200_0000;

pub const MAX_VIRT_ADDR = 2 ** 39;
pub const TRAMPOLINE = MAX_VIRT_ADDR - PAGE_SIZE;
pub const TRAPFRAME = MAX_VIRT_ADDR - 2 * PAGE_SIZE;
