// We are doing sv39
// XXX: Zig 0.11 to memset
const printf = @import("uart.zig").printf;

const mem = @import("std").mem;
const memlist = @import("freelist.zig");
const memlayout = @import("memlayout.zig");
const PAGE_SIZE = memlist.PAGE_SIZE;
// XXX: sign extend??
const MAX_VA = (1 << 39) - 1;

const NUM_ENTRIES = 512;
const pagetable_t = *[NUM_ENTRIES]pagetable_entry_t;
const pagetable_entry_t = u64;

pub fn kvmInit() pagetable_t {
    const loced = memlist.kalloc() catch unreachable;
    const kpgt = @ptrCast(pagetable_t, @alignCast(@alignOf(pagetable_t), loced));
    mem.set(pagetable_entry_t, kpgt, 0);
    map(kpgt, memlayout.UART0, memlayout.UART0, PTE_R | PTE_W, PAGE_SIZE);

    return kpgt;
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

fn pteToPagetable(pte: pagetable_entry_t) pagetable_t {
    const ppn = pte >> 10;
    const address = ppn * PAGE_SIZE;
    return @intToPtr(pagetable_t, address);
}

fn pagetableToPte(pagetable: pagetable_t) pagetable_entry_t {
    const addr = @ptrToInt(pagetable);
    const ppn = addr >> 12;
    return ppn << 10;
}

fn paToPte(pa: u64) pagetable_entry_t {
    const ppn = pa >> 12;
    return ppn << 10;
}

fn walk(pagetable_: pagetable_t, v_addr: u64, alloc: bool) pagetable_entry_t {
    if (v_addr > MAX_VA) {
        @panic("walk: v_addr > MAX_VA");
    }

    var pagetable = pagetable_;
    var level: usize = 2;
    while (level > 0) : (level -= 1) {
        const pte_idx = getVPNEntryIdx(v_addr, level);
        var pte = pagetable[pte_idx];
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
            (&pte).* = pagetableToPte(pagetable) | PTE_V;
        }
    }
    const pte_idx = getVPNEntryIdx(v_addr, 0);
    return pagetable[pte_idx];
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
        var pte = walk(pagetable, v_addr, true);
        if (pte & PTE_V != 0) {
            @panic("map: mapping already mapped address for specific pagetable");
        }
        (&pte).* = paToPte(mapped_addr) | pte_bits | PTE_V;
    }
}
