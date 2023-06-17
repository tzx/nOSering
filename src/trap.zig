const consts = @import("consts.zig");
const riscv_asm = @import("asm.zig");

const printf = @import("uart.zig").printf;

// 0. stores the clint's cmp
// 1. stores the interval to increment
// [2..=3]. temp space to store registers
const mtrap_single_scratch_t = [4]u64;
const mtrap_scratch_t = [consts.MAX_CPUS]mtrap_single_scratch_t;
pub var mtrap_scratch: mtrap_scratch_t = undefined;

pub export fn kernelTrap() void {
    const epc = riscv_asm.readSepc();
    printf("you are kernel trapped! epc: {x}\n", .{epc});

    // Go to next instruction in the trap
    riscv_asm.writeSepc(epc + 4);
}

pub export fn machineTrap() void {
    printf("you are machine trapped!\n", .{});
}
