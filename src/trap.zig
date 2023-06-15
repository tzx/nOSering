const riscv_asm = @import("asm.zig");

const printf = @import("uart.zig").printf;

pub export fn kernelTrap() void {
    const epc = riscv_asm.readSepc();
    printf("you are kernel trapped! epc: {x}\n", .{epc});

    // Go to next instruction in the trap
    riscv_asm.writeSepc(epc + 4);
}
