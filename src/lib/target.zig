const std = @import("std");

const Self = @This();

buf: [20]u8 = undefined,
buf_len: u8 = 0,
half: bool = false,

const TargetError = error{
    // not 0-9 or a-z
    NotHexChr,
    NoInput,
    TooLong,
};

pub fn init(str: []const u8) TargetError!Self {
    if (str.len < 1) return TargetError.NoInput;
    if (str.len > 16) return TargetError.TooLong; // NOTE: just picking this, real hard limit would probably be 40?

    var half = false;
    var buf: [20]u8 = undefined;
    var i: u8 = 0;

    var itr = std.mem.window(u8, str, 2, 2);
    while (itr.next()) |ch| : (i += 1) {
        var val = try hexChrToInt(ch[0]);
        val <<= 4;

        if (ch.len == 2) {
            val += try hexChrToInt(ch[1]);
        } else {
            half = true;
        }

        buf[i] = val;
    }

    return Self{ .buf = buf, .buf_len = i, .half = half };
}

fn hexChrToInt(chr: u8) TargetError!u8 {
    if (chr >= '0' and chr <= '9') {
        return chr - '0';
    } else if (chr >= 'a' and chr <= 'f') {
        return chr + 10 - 'a';
    } else return TargetError.NotHexChr;
}

test "init" {
    var t = try Self.init("cafe12");
    try std.testing.expectEqual(3, t.buf_len);
    try std.testing.expectEqualDeep(([3]u8{ 0xca, 0xfe, 0x12 })[0..], t.buf[0..3]);
    try std.testing.expectEqual(false, t.half);

    t = try Self.init("123");
    try std.testing.expectEqual(t.buf_len, 2);
    try std.testing.expectEqualDeep(t.buf[0..2], ([2]u8{ 0x12, 0x30 })[0..]);
    try std.testing.expectEqual(true, t.half);

    t = try Self.init("abcdef0123456789");
    try std.testing.expectEqual(8, t.buf_len);
    try std.testing.expectEqual(false, t.half);

    try std.testing.expectError(TargetError.NotHexChr, Self.init("great"));
    try std.testing.expectError(TargetError.NoInput, Self.init(""));
    try std.testing.expectError(TargetError.TooLong, Self.init("12345678901234567"));
}

pub fn match(self: *const Self, other: *const [20]u8) bool {
    const stop = self.buf_len - 1;

    for (0..stop) |i| {
        if (self.buf[i] != other[i]) return false;
    }

    if (self.half) {
        if (self.buf[stop] >> 4 != other[stop] >> 4) return false;
    } else {
        if (self.buf[stop] != other[stop]) return false;
    }

    return true;
}

test "match" {
    var sha = @import("gitSha.zig").init();
    const result = sha.trySha("howdy"); // { ef, 42, ba, b1, 19, 1d, a2, 72, f1, 39, 35, f7, 8c, 40, 1e, 3d, e0, c1, 1a, fb }

    var t = try Self.init("cafe12");
    try std.testing.expectEqual(false, t.match(&result));

    // even number of chrs
    t = try Self.init("ef");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self.init("ef42bab1");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self.init("ef40bab1"); // error in middle
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self.init("ef42bab100"); // make sure last chrs are actually checked
    try std.testing.expectEqual(false, t.match(&result));

    // odd
    t = try Self.init("e");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self.init("f");
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self.init("ef42b");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self.init("ef42a"); // error in last chr
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self.init("ef42bab1191da");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self.init("ef02bab1191da"); // error in 3rd chr
    try std.testing.expectEqual(false, t.match(&result));
}
