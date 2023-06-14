// We are doing sv39
// XXX: Zig 0.11 to memset
const mem = @import("std").mem;

const riscv_asm = @import("asm.zig");
const memlist = @import("freelist.zig");
const memlayout = @import("memlayout.zig");

const printf = @import("uart.zig").printf;

const PAGE_SIZE = memlist.PAGE_SIZE;
// XXX: sign extend??
const MAX_VA = (1 << 39) - 1;

const NUM_ENTRIES = 512;
const pagetable_t = *[NUM_ENTRIES]pagetable_entry_t;
const pagetable_entry_t = u64;

extern const _text_start: u8;
extern const _text_end: u8;
extern const _kernel_end: u8;

pub fn kvmInit() void {
    const loced = memlist.kalloc() catch unreachable;
    const kpgt = @ptrCast(pagetable_t, @alignCast(@alignOf(pagetable_t), loced));
    mem.set(pagetable_entry_t, kpgt, 0);
    map(kpgt, memlayout.UART0, memlayout.UART0, PTE_R | PTE_W, PAGE_SIZE);
    map(kpgt, memlayout.VIRTIO0, memlayout.VIRTIO0, PTE_R | PTE_W, PAGE_SIZE);
    map(kpgt, memlayout.PLIC, memlayout.PLIC, PTE_R | PTE_W, memlayout.PLIC_SIZE);

    const text_start = @ptrToInt(&_text_start);
    const text_end = @ptrToInt(&_text_end);
    map(kpgt, text_start, text_start, PTE_R | PTE_X, text_end - text_start);

    const kernel_end = @ptrToInt(&_kernel_end);
    map(kpgt, text_end, text_end, PTE_R | PTE_W, kernel_end - text_end);

    // Map uart and write to virtual address to test out
    // TODO: remove
    map(kpgt, 0x2000, memlayout.UART0, PTE_R | PTE_W, PAGE_SIZE);
    setSatp(kpgt);
}

// Pagetable Entry bits: D A G U X W R V
const PTE_V = 1;
const PTE_R = 1 << 1;
const PTE_W = 1 << 2;
const PTE_X = 1 << 3;
const PTE_U = 1 << 4;
const PTE_G = 1 << 5;
const PTE_A = 1 << 6;
const PTE_D = 1 << 7;

fn getVPNEntryIdx(v_addr: u64, level: usize) u64 {
    // RISC-V Privileged: 4.4.1 Addressing and Memory Protection
    const mask = 0x1FF; // 9 bit mask
    // We need u6 to cast safely
    // 12 bits for page offset, and each VPN[level] is 9 bits
    const shift = @intCast(u6, 12 + 9 * level);
    const index = (v_addr >> shift) & mask;
    return index;
}

fn pteToAddr(pte: pagetable_entry_t) u64 {
    const ppn = pte >> 10;
    return ppn * PAGE_SIZE;
}

inline fn pa_to_ppn(pa: u64) u64 {
    return pa >> 12;
}

fn pteToPagetable(pte: pagetable_entry_t) pagetable_t {
    const address = pteToAddr(pte);
    return @intToPtr(pagetable_t, address);
}

fn pagetableToPte(pagetable: pagetable_t) pagetable_entry_t {
    const addr = @ptrToInt(pagetable);
    const ppn = pa_to_ppn(addr);
    return ppn << 10;
}

fn paToPte(pa: u64) pagetable_entry_t {
    const ppn = pa_to_ppn(pa);
    return ppn << 10;
}

// Returns pointer to final page table entry corresponding to v_addr, if alloc
// is true then allocate pages if they are missing along the walk
fn walk(pagetable_: pagetable_t, v_addr: u64, alloc: bool) *pagetable_entry_t {
    if (v_addr > MAX_VA) {
        @panic("walk: v_addr > MAX_VA");
    }

    var pagetable = pagetable_;
    var level: usize = 2;
    while (level > 0) : (level -= 1) {
        const pte_idx = getVPNEntryIdx(v_addr, level);
        const pte_p = &pagetable[pte_idx];
        const pte = pte_p.*;
        if (pte & PTE_V != 0) {
            pagetable = pteToPagetable(pte);
        } else {
            // Not valid -> need to allocate an page for it
            if (!alloc) {
                @panic("Walking through invalid page with alloc being false");
            }
            // TODO: panic? better error handling
            const lloced = memlist.kalloc() catch unreachable;
            pagetable = @ptrCast(pagetable_t, @alignCast(@alignOf(pagetable_t), lloced));
            mem.set(pagetable_entry_t, pagetable, 0);
            pte_p.* = pagetableToPte(pagetable) | PTE_V;
        }
    }
    const pte_idx = getVPNEntryIdx(v_addr, 0);
    return &pagetable[pte_idx];
}

fn map(pagetable: pagetable_t, v_addr: u64, p_addr: u64, pte_bits: u8, size: u64) void {
    if (size == 0) {
        @panic("Mapping 0 addresses in page table");
    }

    var addr = memlist.pageDown(v_addr);
    var mapped_addr = p_addr;
    const last_pg_aligned_addr = memlist.pageDown(v_addr + size - 1);
    while (addr <= last_pg_aligned_addr) : ({
        addr += PAGE_SIZE;
        mapped_addr += PAGE_SIZE;
    }) {
        if (addr > last_pg_aligned_addr) {
            @panic("map: address is out of bounds");
        }
        const pte_p = walk(pagetable, addr, true);
        if (pte_p.* & PTE_V != 0) {
            printf("failed: pte_p: {x}\n", .{pte_p.*});
            @panic("map: mapping already mapped address for specific pagetable");
        }
        pte_p.* = paToPte(mapped_addr) | pte_bits | PTE_V;
    }
}

// TODO: Refactor ugly ass code to something recursive? O(512 ** num_levels)
pub fn printPgEntries(root_pg: pagetable_t) void {
    printf("root page table: {*}\n", .{root_pg});

    // XXX: Zig 0.11 can do enumerate
    var i: usize = 0;
    while (i < NUM_ENTRIES) : (i += 1) {
        const pte_i = root_pg[i];
        if (pte_i & PTE_V == 0) {
            continue;
        }
        printf("..{d}: pte {x}\n", .{ i, pte_i });
        const pg_j = pteToPagetable(pte_i);

        var j: usize = 0;
        while (j < NUM_ENTRIES) : (j += 1) {
            const pte_j = pg_j[j];
            if (pte_j & PTE_V == 0) {
                continue;
            }
            printf(".. ..{d}: pte {x}\n", .{ j, pte_j });
            const pg_k = pteToPagetable(pte_j);

            var k: usize = 0;
            while (k < NUM_ENTRIES) : (k += 1) {
                const pte_k = pg_k[k];
                if (pte_k & PTE_V == 0) {
                    continue;
                }

                const pa = pteToAddr(pte_k);
                const va = i << 12 + 18 | j << 12 + 9 | k << 12; //  || j << 12 + 9 || k << 12);
                printf(".. .. ..{d}: pte {x} pa: {x} <- va: {x}\n", .{ k, pte_k, pa, va });
            }
        }
    }
}

fn setSatp(root: pagetable_t) void {
    // We use sv39 -> Mode = 8
    const mode = 8 << 60;
    // We flush the cache when we switch, so we don't use ASID
    const ppn = pa_to_ppn(@ptrToInt(root));
    const satp = mode | ppn;

    riscv_asm.flushAllSfence();
    riscv_asm.writeSatp(satp);
    riscv_asm.flushAllSfence();
}
