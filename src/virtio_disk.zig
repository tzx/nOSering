const printf = @import("uart.zig").printf;

const VIRTIO_BASE_ADDR = @import("memlayout.zig").VIRTIO0;

// All from QEMU
const REQUIRED_MAGIC_VAL = 0x74726976;
const REQUIRED_VERSION = 0x2;
const REQUIRED_BLOCK_DEVICE_ID = 0x2;
const REQUIRED_VENDOR_ID = 0x554d4551;

const VIRTIO_BLK_F_RO = 5;

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

// TODO: this currently only does VIRTIO0
// Which is actually fine b/c we only have one
pub fn virtioDiskInit() void {
    const regs = @intToPtr(*volatile VirtioRegisters, VIRTIO_BASE_ADDR);
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
    virtioSetFeatures(regs);
    // Features OK
    regs.status = regs.status | DEVICE_STATUS_FEATURES_OK;
    // Reread device status to see if features_ok is set
    if (regs.status & DEVICE_STATUS_FEATURES_OK == 0) {
        @panic("virtio blk says device does not support features or device is unstable");
    }
    // Do discovery queue
}

fn virtioSetFeatures(regs: *volatile VirtioRegisters) void {
    regs.device_features_sel = 0;
    regs.driver_features_sel = 0;

    // We check each possible feature and flip them off
    var device_features = regs.device_features;
    var request: u32 = 0;
    for (VIRT_CAPABILITIES) |cap| {
        if (device_features & cap.bit_flag != 0) {
            if (cap.enable) {
                request |= cap.bit_flag;
            } else {
                printf("Your virtio device supports {s}\n", .{cap.name});
            }
        }
        device_features &= ~cap.bit_flag;
    }

    if (device_features != 0) {
        printf("device_features: {x}\n", .{device_features});
        @panic("There are capabilities you forgot to add");
    }
}

inline fn writeReg(p: *volatile u32, val: u32) void {
    p.* = val;
}

inline fn readReg(p: *volatile u32) u32 {
    return p.*;
}

test "packed struct" {
    const std = @import("std");
    const mmio_end = 0x100;
    // All the bytes to end + the bytes (u32) of the last address
    try std.testing.expectEqual(@sizeOf(VirtioRegisters), mmio_end + @sizeOf(u32));
}
