const std = @import("std");
const virtio_disk = @import("virtio_disk.zig");

const printf = @import("uart.zig").printf;

// Read SHITFS.md
const NUM_FILES = 128;
// Really wish I can do ? on name instead of checking for 0
const fst_entry = extern struct {
    name: [4]u8,
    size: u32,
};

const fst_t = [NUM_FILES]fst_entry;

comptime {
    std.debug.assert(@sizeOf(fst_t) == 1024);
}

var fst: ?fst_t = null;

pub fn fsInit() void {
    var bytes = [_]u8{0} ** 1024;
    virtio_disk.virtioDiskRW(&bytes, 0, false);
    fst = @bitCast(fst_t, bytes);
}

// TODO: duplicate file names error
pub fn fsNew(name: *const [3:0]u8) ?*fst_entry {
    var i: usize = 0;
    while (i < NUM_FILES) : (i += 1) {
        var entry = &(fst.?[i]);
        if (entry.name[0] == 0) {
            // copy TODO: need to write to disk the fst
            @memcpy(&entry.name, name, 4);
            // entry.name = name.*;
            return entry;
        }
    }
    return null;
}

pub fn fsWrite(entry: *fst_entry, data: []u8) void {
    const WRITE_SIZE = @sizeOf(fst_t);
    const ONE_MiB = 1048576;

    const idx = findIndex(entry).?;
    // Write in sector size byte increments
    const section_start = @sizeOf(fst_t) + idx * ONE_MiB;
    var sector = section_start / virtio_disk.SECTOR_SIZE;
    var written: usize = 0;
    while (written < data.len) : ({
        written += WRITE_SIZE;
        sector += WRITE_SIZE / virtio_disk.SECTOR_SIZE;
        comptime {
            std.debug.assert(WRITE_SIZE / virtio_disk.SECTOR_SIZE == 2);
        }
    }) {
        var buf = [_]u8{0} ** WRITE_SIZE;
        @memcpy(&buf, data[written..].ptr, @min(WRITE_SIZE, data.len - written));
        virtio_disk.virtioDiskRW(buf[0..WRITE_SIZE], sector, true);
    }
}

fn findIndex(entry: *fst_entry) ?usize {
    var i: usize = 0;
    while (i < NUM_FILES) : (i += 1) {
        const e = fst.?[i];
        if (e.name[0] != 0 and std.mem.eql(u8, &e.name, &entry.name)) {
            return i;
        }
    }
    return null;
}
