const std = @import("std");

const Self = @This();

buf: [20]u8 = undefined,
buf_len: u8 = 0,

pub fn init(str: []const u8) Self {
    _ = str;
    return Self{};
}

test "init" {
    const t = Self.init("cafe");
    _ = t;

    try std.testing.expect(true);
}
