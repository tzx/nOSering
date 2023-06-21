const Atomic = @import("std").atomic.Atomic;
const Ordering = @import("std").atomic.Ordering;
// Very inefficient spinlock

pub const SpinLock = struct {
    lock_: Atomic(bool),

    pub fn new() @This() {
        return SpinLock{ .lock_ = Atomic(bool).init(false) };
    }

    // This is way too strong ordering right now
    pub fn lock(self: *SpinLock) void {
        while (self.lock_.swap(true, Ordering.SeqCst)) {}
    }

    pub fn unlock(self: *SpinLock) void {
        self.lock_.store(false, Ordering.SeqCst);
    }
};
