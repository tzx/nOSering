pub const MPP_MASK = 0b11 << 11;
pub const MPP_U = 0b00 << 11;
pub const MPP_S = 0b01 << 11;
pub const MPP_M = 0b10 << 11;

pub inline fn readMstatus() u64 {
    return asm volatile ("csrr %[ret], mstatus"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeMstatus(val: u64) void {
    asm volatile ("csrw mstatus, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeMepc(func: *const fn () noreturn) void {
    const val = @ptrToInt(func);
    asm volatile ("csrw mepc, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writePmpcfg0(val: u64) void {
    asm volatile ("csrw pmpcfg0, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writePmpaddr0(val: u64) void {
    asm volatile ("csrw pmpaddr0, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeSatp(val: u64) void {
    asm volatile ("csrw satp, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeMtvec(val: u64) void {
    asm volatile ("csrw mtvec, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeStvec(val: u64) void {
    asm volatile ("csrw stvec, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn readSepc() u64 {
    return asm volatile ("csrr %[ret], sepc"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeSepc(val: u64) void {
    asm volatile ("csrw sepc, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeMideleg(val: u64) void {
    asm volatile ("csrw mideleg, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeMedeleg(val: u64) void {
    asm volatile ("csrw medeleg, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn writeSie(val: u64) void {
    asm volatile ("csrw sie, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn readMie() u64 {
    return asm volatile ("csrr %[ret], mie"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeMie(val: u64) void {
    asm volatile ("csrw mie, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

pub inline fn flushAllSfence() void {
    asm volatile ("sfence.vma zero, zero");
}
