const std = @import("std");

const Self = @This();

found: bool = false,
lock: std.Thread.Mutex = .{},

// returns true if was able to set from false to true,
// returns false if it was already found
pub fn setFound(self: *Self) bool {
    self.lock.lock();
    defer self.lock.unlock();
    if (self.found) {
        return false;
    }

    self.found = true;
    return true;
}

test "setFound" {
    var ff = Self{};

    try std.testing.expect(!ff.found);

    var result = ff.setFound();
    try std.testing.expect(result);
    try std.testing.expect(ff.found);

    result = ff.setFound();
    try std.testing.expect(!result);
    try std.testing.expect(ff.found);
}
