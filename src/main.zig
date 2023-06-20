const builtin = @import("std").builtin;
const uart = @import("uart.zig");
const freelist = @import("freelist.zig");
const pagetable = @import("pagetable.zig");
const plic = @import("plic.zig");
const riscv_asm = @import("asm.zig");
const trap = @import("trap.zig");
const virtio_disk = @import("virtio_disk.zig");

extern const kernelvec: u8;
extern const machinevec: u8;

pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    uart.printf("\nPANIC MESSAGE:\n", .{});
    uart.printf("{s}", .{message});
    uart.printf("\n", .{});

    while (true) {}
}

fn kmain() noreturn {
    uart.printf("kmain\n", .{});
    freelist.initFreeList();
    pagetable.kvmInit();
    plic.plicInit();
    virtio_disk.virtioDiskInit();

    var arr = [_]u8{ 'h', 'e' };
    virtio_disk.virtioDiskRW(arr[0..]);

    @panic("You reached kmain!");
}

export fn setup() noreturn {
    uart.uartInit();
    uart.printf("setup\n", .{});
    const mstatus = riscv_asm.readMstatus();
    // Set MPP to Supervisor mode when we mret
    const new_mstatus = (mstatus & ~@intCast(u64, riscv_asm.MPP_MASK)) | riscv_asm.MPP_S;
    riscv_asm.writeMstatus(new_mstatus);
    // Go to kmain when we mret
    riscv_asm.writeMepc(&kmain);

    // https://stackoverflow.com/questions/69133848/risc-v-illegal-instruction-exception-when-switching-to-supervisor-mode
    // Cool thing that helped me find this: Using -d int: https://en.wikibooks.org/wiki/QEMU/Invocation
    // https://github.com/qemu/qemu/commit/d102f19a2085ac931cb998e6153b73248cca49f1
    pmpInit();

    // Delegate all (*possible) interrupts and exceptions to supervisor mode
    // Possible as some interrupts/exceptions cannot be delegated (i.e machine
    // interrupts/calls + the more important timer interrupts
    //
    // Put S-mode interrupts to S-mode
    riscv_asm.writeMideleg(riscv_asm.MCAUSE_I_SSI | riscv_asm.MCAUSE_I_STI | riscv_asm.MCAUSE_I_SEI);
    // Put all possible exceptions to S-mode
    riscv_asm.writeMedeleg(riscv_asm.MCAUSE_E_ALL_POSSIBLE_SMODE);

    // Enable all possible interrupts in supervisor mode
    riscv_asm.writeSie(riscv_asm.IEIP_SS | riscv_asm.IEIP_ST | riscv_asm.IEIP_SE);
    // Remember interrupts != exceptions; Exceptions usually cannot be disabled

    // Trap handlers
    riscv_asm.writeMtvec(@ptrToInt(&machinevec));
    riscv_asm.writeStvec(@ptrToInt(&kernelvec));

    // Enable timer interrupts
    timerInit();

    asm volatile ("mret");
    unreachable;
}

// Set PMP entry 0 to TOR max address, so supervisor mode can access all addresses
inline fn pmpInit() void {
    // We set everything on and use TOR; we only set pmp0cfg
    // L = 1, A = 1, X = 1, W = 1, R = 1
    const cfg0 = 0x8f;
    riscv_asm.writePmpcfg0(cfg0);

    // For RV64, each PMP address register encodes bits 55-2 of a 56-bit physical address
    // We want the max address as TOR, so we set all 54 bits to 1 (2 ** 54 - 1)
    const top_addr = (1 << 54) - 1;
    riscv_asm.writePmpaddr0(top_addr);
}

fn timerInit() void {
    const cpu_id = riscv_asm.readMhartid();
    const scratch = trap.mtrap_scratch[cpu_id][0..];

    // TODO: generalize to more CPUS
    const cmp = 0x200_4000;
    const ptr = @intToPtr(*u64, cmp);
    ptr.* = 2000000;
    scratch[0] = cmp;
    const interval = 10000000000;
    scratch[1] = interval;

    riscv_asm.writeMscratch(@ptrToInt(scratch));
    riscv_asm.writeMie(riscv_asm.readMie() | riscv_asm.IEIP_MT);

    // Need to enable SIE so timer interrupts happens in SUPERVISOR MODE
    // TODO: maybe when we reach init, we turn this off
    riscv_asm.writeMstatus(riscv_asm.readMstatus() | 0x02);
}

comptime {
    @export(trap.kernelTrap, .{ .name = "kerneltrap", .linkage = .Strong });
    @export(trap.machineTrap, .{ .name = "machinetrap", .linkage = .Strong });
}
