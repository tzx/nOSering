const builtin = @import("std").builtin;
const uart = @import("uart.zig");
const freelist = @import("freelist.zig");
const pagetable = @import("pagetable.zig");
const riscv_asm = @import("asm.zig");

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

    // TODO: remove
    // uart.uartPutc(0x2000, 'x');
    // uart.printf("hi", .{});
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
    riscv_asm.writeMideleg(0b001000100010);
    riscv_asm.writeMedeleg(0b1011001111111111);

    // Enable all possible interrupts in supervisor mode
    riscv_asm.writeSie(0b1000100010);
    // We have not setup turning on interrupts (need to set sstatus)
    // Remember interrupts != exceptions; Exceptions usually cannot be disabled

    // Trap handler
    const trap_handler = &trapTest;
    if (@typeInfo(@TypeOf(trap_handler)).Pointer.alignment != 4) {
        @panic("function is not aligned by 4");
    }
    riscv_asm.writeMtvec(trap_handler);
    riscv_asm.writeStvec(&ktrapTest);

    asm volatile ("mret");
    unreachable;
}

// TODO: remove
// must be aligned(4)
fn trapTest() align(0b100) void {
    uart.printf("you are trapped!\n", .{});
}

fn ktrapTest() align(0b100) void {
    uart.printf("you are kernel trapped!\n", .{});
    asm volatile ("sret");
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
