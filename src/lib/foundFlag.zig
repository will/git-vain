const std = @import("std");

const Self = @This();

found: bool = false,
lock: std.Thread.Mutex = .{},
sem: std.Thread.Semaphore = .{},
value: i32 = 0,

// returns true if was able to set from false to true,
// returns false if it was already found
pub fn setFound(self: *Self, value: i32) bool {
    self.lock.lock();
    defer self.lock.unlock();
    if (self.found) {
        return false;
    }

    self.sem.post();
    self.found = true;
    self.value = value;
    return true;
}

pub fn wait(self: *Self) void {
    self.sem.wait();
}

test "setFound" {
    var ff = Self{};

    try std.testing.expect(!ff.found);

    var result = ff.setFound(1);
    try std.testing.expect(result);
    try std.testing.expect(ff.found);

    result = ff.setFound(1);
    try std.testing.expect(!result);
    try std.testing.expect(ff.found);
}
