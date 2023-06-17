const builtin = @import("std").builtin;
const uart = @import("uart.zig");
const freelist = @import("freelist.zig");
const pagetable = @import("pagetable.zig");
const riscv_asm = @import("asm.zig");
const trap = @import("trap.zig");

extern const kernelvec: u8;
extern const machinevec: u8;

pub fn panic(message: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    uart.printf("\nPANIC MESSAGE:\n", .{});
    uart.printf("{s}", .{message});
    uart.printf("\n", .{});

    while (true) {}
    var i: usize = 1;
    while (true) {
        uart.printf("shit: {x}\n", .{i});
        i += 1;
    }
}

fn kmain() noreturn {
    uart.printf("kmain\n", .{});
    // freelist.initFreeList();
    // pagetable.kvmInit();

    // const ptr = @intToPtr(*volatile u8, 0x2000);
    // ptr.* = 'x';
    uart.printf("hi", .{});
    @panic("You reached kmain!");
}

export fn setup() noreturn {
    uart.uartInit();
    uart.printf("setup\n", .{});
    const mstatus = riscv_asm.readMstatus();
    // TODO: is it possible to do csrs?
    // Set MPP to Supervisor mode when we mret
    const new_mstatus = (mstatus & ~@intCast(u64, riscv_asm.MPP_MASK)) | riscv_asm.MPP_S;
    riscv_asm.writeMstatus(new_mstatus);
    // Go to kmain when we mret
    riscv_asm.writeMepc(&kmain);

    // https://stackoverflow.com/questions/69133848/risc-v-illegal-instruction-exception-when-switching-to-supervisor-mode
    // Cool thing that helped me find this: Using -d int: https://en.wikibooks.org/wiki/QEMU/Invocation
    // https://github.com/qemu/qemu/commit/d102f19a2085ac931cb998e6153b73248cca49f1
    pmpInit();

    // TODO: magic numbers move to -> asm.zig
    // Delegate all (*possible) interrupts and exceptions to supervisor mode
    // Possible as some interrupts/exceptions cannot be delegated (i.e machine
    // interrupts/calls + the more important timer interrupts
    riscv_asm.writeMideleg(0b001000100010);
    riscv_asm.writeMedeleg(0b1011001111111111);

    // Enable all possible interrupts in supervisor mode
    riscv_asm.writeSie(0b1000100010);
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
    const cfg0 = 0b10001111;
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
    scratch[1] = 100000;

    riscv_asm.writeMscratch(@ptrToInt(scratch));
    riscv_asm.writeMie(riscv_asm.readMie() | 0x80);
    // Need to enable SIE so timer interrupts happens
    riscv_asm.writeMstatus(riscv_asm.readMstatus() | 0x02);
}

comptime {
    @export(trap.kernelTrap, .{ .name = "kerneltrap", .linkage = .Strong });
    @export(trap.machineTrap, .{ .name = "machinetrap", .linkage = .Strong });
}
