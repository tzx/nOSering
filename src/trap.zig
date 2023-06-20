const consts = @import("consts.zig");
const riscv_asm = @import("asm.zig");
const plic = @import("plic.zig");
const uart = @import("uart.zig");
const virtio_disk = @import("virtio_disk.zig");

const printf = @import("uart.zig").printf;

// 0. stores the clint's cmp
// 1. stores the interval to increment
// [2..=3]. temp space to store registers
const mtrap_single_scratch_t = [4]u64;
const mtrap_scratch_t = [consts.MAX_CPUS]mtrap_single_scratch_t;
pub var mtrap_scratch: mtrap_scratch_t = undefined;

pub export fn kernelTrap() void {
    const scause = riscv_asm.readScause();

    // Interrupt
    if (scause & 1 << 63 != 0) {
        // TODO: magic number?
        if (scause & 0xff == 9) {
            const irq = plic.plicClaim();
            if (irq == plic.UART_SRC) {
                uart.handleUartIntr();
            } else { // TODO: virtio
                virtio_disk.virtioDiskIntr();
            }
            plic.plicComplete(irq);
        } else {}
    } else { // Exception
    }

    // TODO: move this into the if
    // Remove software interrupt bit
    const val = 0x02;
    asm volatile ("csrc sip, %[arg1]"
        :
        : [arg1] "r" (val),
    );

    // TODO: change: Go to next instruction in the trap
    // riscv_asm.writeSepc(epc + 4);
}

pub export fn machineTrap() void {
    printf("you are machine trapped!\n", .{});
}
