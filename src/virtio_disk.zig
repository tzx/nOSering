const std = @import("std");

const printf = @import("uart.zig").printf;
const freelist = @import("freelist.zig");
const SpinLock = @import("spinlock.zig").SpinLock;
const VIRTIO_BASE_ADDR = @import("memlayout.zig").VIRTIO0;

// All from QEMU
const REQUIRED_MAGIC_VAL = 0x74726976;
const REQUIRED_VERSION = 0x2;
const REQUIRED_BLOCK_DEVICE_ID = 0x2;
const REQUIRED_VENDOR_ID = 0x554d4551;

const VIRTIO_BLK_F_RO = 5;

const VIRTIO_BLK_T_IN = 0;
const VIRTIO_BLK_T_OUT = 1;

const VIRTQ_DESC_F_NEXT = 1;
const VIRTQ_DESC_F_WRITE = 2;

const QUEUE_SIZE = 64;
pub const SECTOR_SIZE = 512;

// XXX: Zig's packed struct does not allow arrays
// https://github.com/ziglang/zig/issues/12547
const VirtioRegisters = extern struct {
    magic_value: u32,
    version: u32,
    device_id: u32,
    vendor_id: u32,
    device_features: u32,
    device_features_sel: u32,
    _reserved_0: [2]u32,
    driver_features: u32,
    driver_features_sel: u32,
    _reserved_1: [2]u32,
    queue_sel: u32,
    queue_num_max: u32,
    queue_num: u32,
    _reserved_2: [2]u32,
    queue_ready: u32,
    _reserved_3: [2]u32,
    queue_notify: u32,
    _reserved_4: [3]u32,
    interrupt_status: u32,
    interrupt_ack: u32,
    _reserved_5: [2]u32,
    status: u32,
    _reserved_6: [3]u32,
    queue_desc_low: u32,
    queue_desc_high: u32,
    _reserved_7: [2]u32,
    queue_driver_low: u32,
    queue_driver_high: u32,
    _reserved_8: [2]u32,
    queue_device_low: u32,
    queue_device_high: u32,
    _reserved_9: [21]u32,
    config_generation: u32,
    // https://en.wikipedia.org/wiki/Flexible_array_member; we just assume it has 1 lol
    config: [1]u32,

    comptime {
        const debug = @import("std").debug;
        const mmio_end = 0x100;
        // All bytes to the end + the bytes (u32) of the last address
        debug.assert(@sizeOf(@This()) == mmio_end + @sizeOf(u32));
    }
};

const VirtioCapability = struct {
    name: []const u8,
    bit_flag: u32,
    enable: bool,
};

const VIRT_CAPABILITIES = [_]VirtioCapability{
    .{
        .name = "VIRTIO_F_RING_INDIRECT_DESC",
        .bit_flag = 1 << 28,
        .enable = false,
    },
    .{
        .name = "VIRTIO_F_RING_EVENT_IDX",
        .bit_flag = 1 << 29,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_SIZE_MAX",
        .bit_flag = 1 << 1,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_SEG_MAX",
        .bit_flag = 1 << 2,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_GEOMETRY",
        .bit_flag = 1 << 4,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_RO",
        .bit_flag = 1 << 5,
        .enable = true,
    },
    .{
        .name = "VIRTIO_BLK_F_BLK_SIZE",
        .bit_flag = 1 << 6,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_FLUSH",
        .bit_flag = 1 << 9,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_TOPOLOGY",
        .bit_flag = 1 << 10,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_CONFIG_WCE",
        .bit_flag = 1 << 11,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_DISCARD",
        .bit_flag = 1 << 13,
        .enable = false,
    },
    .{
        .name = "VIRTIO_BLK_F_WRITE_ZEROES",
        .bit_flag = 1 << 14,
        .enable = false,
    },
};

const DEVICE_STATUS_RESET = 0;
const DEVICE_STATUS_ACKNOWLEDGE = 1;
const DEVICE_STATUS_DRIVER = 2;
const DEVICE_STATUS_FAILED = 128;
const DEVICE_STATUS_FEATURES_OK = 8;
const DEVICE_STATUS_DRIVER_OK = 4;
const DEVICE_STATUS_NEEDS_RESET = 64;

const VirtqDesc = extern struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

const VirtqAvail = extern struct {
    flags: u16,
    idx: u16,
    ring: [QUEUE_SIZE]u16,
};

const VirtqUsed = extern struct {
    const VirtqUsedElement = extern struct {
        id: u32,
        len: u32,
    };
    flags: u16,
    idx: u16,
    ring: [QUEUE_SIZE]VirtqUsedElement,
};

const VirtioBlkReqHeader = extern struct {
    type: u32,
    reserved: u32,
    sector: u64,
};

const disk = struct {
    var virtq_desc: ?*[QUEUE_SIZE]VirtqDesc = null;
    var virtq_avail: ?*VirtqAvail = null;
    var virtq_used: ?*VirtqUsed = null;

    var occupied_descs = std.mem.zeroes([QUEUE_SIZE]bool);
    var last_seen_used: usize = 0;

    // Have data structure that has space for
    // buf0 (type, reserved, sector) and buf2 (status)
    // buf1 is what we read/write, so that's not in this data structure
    // for each descriptor
    var headers = std.mem.zeroes([QUEUE_SIZE]VirtioBlkReqHeader);
    var status = [_]u8{0xff} ** QUEUE_SIZE; // status = 0 means good
    // We just keep track of buf1 by saving pointers to them
    var buffer_pointers = std.mem.zeroes([QUEUE_SIZE]?[*]u8);

    var spinlock = SpinLock.new();

    fn get_free_desc() ?u16 {
        // XXX: Zig enumerate right now
        var i: usize = 0;
        while (i < QUEUE_SIZE) : (i += 1) {
            if (!disk.occupied_descs[i]) {
                disk.occupied_descs[i] = true;
                // TODO: runtime error for truncate?
                return @truncate(u16, i);
            }
        }
        return null;
    }
};

const regs = @intToPtr(*volatile VirtioRegisters, VIRTIO_BASE_ADDR);

// TODO: this currently only does VIRTIO0
// Which is actually fine b/c we only have one
pub fn virtioDiskInit() void {
    if (regs.magic_value != REQUIRED_MAGIC_VAL or
        regs.version != REQUIRED_VERSION or
        regs.device_id != REQUIRED_BLOCK_DEVICE_ID or
        regs.vendor_id != REQUIRED_VENDOR_ID)
    {
        printf("magic value: {x}, version: {x}, device_id: {x}, vendor_id: {x}\n,", .{ regs.magic_value, regs.version, regs.device_id, regs.vendor_id });
        @panic("Wrong required values when initing virtio disk");
    }

    // Reset
    regs.status = DEVICE_STATUS_RESET;
    // Acknowledge
    regs.status = regs.status | DEVICE_STATUS_ACKNOWLEDGE;
    // Driver
    regs.status = regs.status | DEVICE_STATUS_DRIVER;
    // Set Features
    virtioBlkSetFeatures();
    // Features OK
    regs.status = regs.status | DEVICE_STATUS_FEATURES_OK;
    // Reread device status to see if features_ok is set
    if (regs.status & DEVICE_STATUS_FEATURES_OK == 0) {
        @panic("virtio blk says device does not support features or device is unstable");
    }
    // Do discovery queue
    virtioBlkConfigVirtqueue();
    regs.status = regs.status | DEVICE_STATUS_DRIVER_OK;
}

fn virtioBlkSetFeatures() void {
    regs.device_features_sel = 0;
    regs.driver_features_sel = 0;

    // We check each possible feature and flip them off
    var device_features = regs.device_features;
    var request: u32 = 0;
    for (VIRT_CAPABILITIES) |cap| {
        if (device_features & cap.bit_flag != 0) {
            if (cap.enable) {
                request |= cap.bit_flag;
            }
            // else {
            //     printf("Your virtio device supports {s}\n", .{cap.name});
            // }
        }
        device_features &= ~cap.bit_flag;
    }

    if (device_features != 0) {
        printf("device_features: {x}\n", .{device_features});
        @panic("There are capabilities you forgot to add");
    }
}

fn virtioBlkConfigVirtqueue() void {
    // Select the queue writing its index (first queue is 0) to QueueSel.
    // There's only request queue for block device
    regs.queue_sel = 0;
    // Check if the queue is not already in use: read QueueReady, and expect a returned value of zero (0x0).
    if (regs.queue_ready != 0) {
        @panic("Read queue is not ready for virtio-blk: QueueReady != 0");
    }
    // Read maximum queue size (number of elements) from QueueNumMax. If the returned value is zero (0x0) the queue is not available.
    const queue_num_max = regs.queue_num_max;
    if (queue_num_max == 0) {
        @panic("Read queue is not available for virtio-blk: QueueNumMax == 0");
    }
    // Allocate and zero the queue memory, making sure the memory is physically contiguous.
    // 3 parts: Descriptor Table, Available Ring, Used Ring
    const desc_table = freelist.kalloc() catch unreachable;
    const avail_ring = freelist.kalloc() catch unreachable;
    const used_ring = freelist.kalloc() catch unreachable;
    std.mem.set(u8, desc_table, 0);
    std.mem.set(u8, avail_ring, 0);
    std.mem.set(u8, used_ring, 0);

    disk.virtq_desc = @ptrCast(*[QUEUE_SIZE]VirtqDesc, @alignCast(@alignOf(*[QUEUE_SIZE]VirtqDesc), desc_table));
    disk.virtq_avail = @ptrCast(*VirtqAvail, @alignCast(@alignOf(*VirtqAvail), avail_ring));
    disk.virtq_used = @ptrCast(*VirtqUsed, @alignCast(@alignOf(*VirtqUsed), used_ring));

    // Notify the device about the queue size by writing the size to QueueNum.
    // 4096 bytes => 256 max queue size: let's just use 64
    regs.queue_num = QUEUE_SIZE;
    // Write physical addresses of the queue’s Descriptor Area, Driver Area and Device Area to (respectively) the QueueDescLow/QueueDescHigh, QueueDriverLow/QueueDriverHigh and QueueDeviceLow/QueueDeviceHigh register pairs.
    const dt_addr = @ptrToInt(desc_table.ptr);
    const ar_addr = @ptrToInt(avail_ring.ptr);
    const ur_addr = @ptrToInt(used_ring.ptr);
    regs.queue_desc_low = @truncate(u32, dt_addr);
    regs.queue_desc_high = @truncate(u32, dt_addr >> 32);
    regs.queue_driver_low = @truncate(u32, ar_addr);
    regs.queue_driver_high = @truncate(u32, ar_addr >> 32);
    regs.queue_device_low = @truncate(u32, ur_addr);
    regs.queue_device_high = @truncate(u32, ur_addr >> 32);
    // Write 0x1 to QueueReady.
    regs.queue_ready = 0x1;
}

// Assumes buffer len is u32 and is a multiple of SECTOR_SIZE
pub fn virtioDiskRW(buf: []u8, sector: usize, write: bool) void {
    // Lock, so only one disk operation works, this should be fine because the interrupts unlocks this after done
    disk.spinlock.lock();
    // printf("locked\n", .{});
    // printf("len: {d}\n", .{buf.len});
    if (buf.len % SECTOR_SIZE != 0) {
        @panic("virtioDiskRW: must provide buffer that is multiple of SECTOR_SIZE");
    }

    const idx = [_]u16{ disk.get_free_desc().?, disk.get_free_desc().?, disk.get_free_desc().? };

    var blk_header = &disk.headers[idx[0]];
    blk_header.type = if (write) VIRTIO_BLK_T_OUT else VIRTIO_BLK_T_IN;
    // blk_header.reserved = 0;
    blk_header.sector = sector;

    // 3 Sections: Header, Data, Status Writable sections must come after
    // readable ones Why 3 sections instead of 2? Data can be readable or
    // writable depending if we are writing or reading

    disk.virtq_desc.?[idx[0]].addr = @ptrToInt(blk_header);
    disk.virtq_desc.?[idx[0]].len = @sizeOf(VirtioBlkReqHeader);
    disk.virtq_desc.?[idx[0]].flags = VIRTQ_DESC_F_NEXT;
    disk.virtq_desc.?[idx[0]].next = idx[1];

    disk.virtq_desc.?[idx[1]].addr = @ptrToInt(buf.ptr);
    disk.virtq_desc.?[idx[1]].len = @truncate(u32, buf.len);
    disk.virtq_desc.?[idx[1]].flags = if (write) 0 else VIRTQ_DESC_F_WRITE;
    disk.virtq_desc.?[idx[1]].flags |= VIRTQ_DESC_F_NEXT;
    disk.virtq_desc.?[idx[1]].next = idx[2];

    disk.virtq_desc.?[idx[2]].addr = @ptrToInt(&disk.status[idx[0]]);
    disk.virtq_desc.?[idx[2]].len = @sizeOf(u8);
    disk.virtq_desc.?[idx[2]].flags = VIRTQ_DESC_F_WRITE;
    disk.virtq_desc.?[idx[2]].next = 0;

    // We keep track of item by using first descriptor (status, buffer_pointer)
    disk.buffer_pointers[idx[0]] = buf.ptr;

    disk.virtq_avail.?.ring[disk.virtq_avail.?.idx % QUEUE_SIZE] = idx[0];

    @fence(std.atomic.Ordering.SeqCst);
    disk.virtq_avail.?.idx += 1;
    @fence(std.atomic.Ordering.SeqCst);

    // Available buffer notification, there's only 1 queue indexed at "0"
    regs.queue_notify = 0;
}

pub fn virtioDiskIntr() void {
    const status = regs.interrupt_status;
    regs.interrupt_ack = status;
    while (disk.last_seen_used != disk.virtq_used.?.idx) : (disk.last_seen_used += 1) {
        const elem = disk.virtq_used.?.ring[disk.last_seen_used % QUEUE_SIZE];
        const idx = elem.id;
        // const buf = disk.buffer_pointers[idx].?;
        // printf("buffer content: {s}\n", .{buf[0..SECTOR_SIZE]});
        freeChain(idx);
        // Free the lock on RW
        // printf("unlocking\n", .{});
        disk.spinlock.unlock();
    }
}

fn freeChain(idx_: usize) void {
    var idx = idx_;
    while (true) {
        disk.occupied_descs[idx] = false;
        const desc = disk.virtq_desc.?[idx];
        if (desc.flags & VIRTQ_DESC_F_NEXT == 0) {
            break;
        }
        idx = desc.next;
    }
}

test "packed struct" {
    const mmio_end = 0x100;
    // All the bytes to end + the bytes (u32) of the last address
    try std.testing.expectEqual(@sizeOf(VirtioRegisters), mmio_end + @sizeOf(u32));
}
