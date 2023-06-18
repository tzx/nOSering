pub inline fn readMhartid() u64 {
    return asm volatile ("csrr %[ret], mhartid"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeMscratch(val: u64) void {
    asm volatile ("csrw mscratch, %[arg1]"
        :
        : [arg1] "r" (val),
    );
}

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

pub inline fn flushAllSfence() void {
    asm volatile ("sfence.vma zero, zero");
}

// bits for the xIP and xIE bits
pub const IEIP_US = 1 << 0;
pub const IEIP_SS = 1 << 1;
pub const IEIP_MS = 1 << 3;
pub const IEIP_UT = 1 << 4;
pub const IEIP_ST = 1 << 5;
pub const IEIP_MT = 1 << 7;
pub const IEIP_UE = 1 << 8;
pub const IEIP_SE = 1 << 9;
pub const IEIP_ME = 1 << 11;

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

// TODO: MCAUSE -> CAUSE
// Flags for MCAUSE, used for mideleg and medeleg
// We don't set the flag to indicate if interrupt
pub const MCAUSE_I_USI = 1 << 0;
pub const MCAUSE_I_SSI = 1 << 1;
pub const MCAUSE_I_MSI = 1 << 3;
pub const MCAUSE_I_UTI = 1 << 4;
pub const MCAUSE_I_STI = 1 << 5;
pub const MCAUSE_I_MTI = 1 << 7;
pub const MCAUSE_I_UEI = 1 << 8;
pub const MCAUSE_I_SEI = 1 << 9;
pub const MCAUSE_I_MEI = 1 << 11;

pub const MCAUSE_E_INSTR_ADDR_MISALIGN = 1 << 0;
pub const MCAUSE_E_INSTR_ACC_FAULT = 1 << 1;
pub const MCAUSE_E_ILLEGAL_INSTR = 1 << 2;
pub const MCAUSE_E_BREAKPT = 1 << 3;
pub const MCAUSE_E_LOAD_ADDR_MISALIGN = 1 << 4;
pub const MCAUSE_E_LOAD_ACC_FAULT = 1 << 5;
pub const MCAUSE_E_STORE_ADDR_MISALIGN = 1 << 6;
pub const MCAUSE_E_STORE_ACC_FAULT = 1 << 7;
pub const MCAUSE_E_ECALL_U = 1 << 8;
pub const MCAUSE_E_ECALL_S = 1 << 9;
pub const MCAUSE_E_ECALL_M = 1 << 11;
pub const MCAUSE_E_INSTR_PG_FAULT = 1 << 12;
pub const MCAUSE_E_LOAD_PG_FAULT = 1 << 13;
pub const MCAUSE_E_STORE_PG_FAULT = 1 << 15;

// Flag for delegating all exceptions to S-mode
pub const MCAUSE_E_ALL_POSSIBLE_SMODE =
    MCAUSE_E_INSTR_ADDR_MISALIGN |
    MCAUSE_E_INSTR_ACC_FAULT |
    MCAUSE_E_ILLEGAL_INSTR |
    MCAUSE_E_BREAKPT |
    MCAUSE_E_LOAD_ADDR_MISALIGN |
    MCAUSE_E_LOAD_ACC_FAULT |
    MCAUSE_E_STORE_ADDR_MISALIGN |
    MCAUSE_E_STORE_ACC_FAULT |
    MCAUSE_E_ECALL_U |
    MCAUSE_E_ECALL_S |
    MCAUSE_E_ECALL_M |
    MCAUSE_E_INSTR_PG_FAULT |
    MCAUSE_E_LOAD_PG_FAULT |
    MCAUSE_E_STORE_PG_FAULT;

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

pub inline fn readScause() u64 {
    return asm volatile ("csrr %[ret], scause"
        : [ret] "=r" (-> u64),
    );
}
