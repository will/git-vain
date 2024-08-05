const std = @import("std");
const Git = @import("git.zig");

const Self = @This();
const MaxSize = 16; // NOTE: just picking this, real hard limit would probably be 40?
buf: [20]u8 = undefined,
buf_len: u8 = 0,
half: bool = false,

const TargetError = error{
    NotHexChr, // not 0-9 or a-z
    NoInput,
    TooLong,
};

// pub fn init() Git.GitError|TargetError!Self {
pub fn init(git: *Git) !Self {
    var args = std.process.args(); // wont work on windows or wasi
    const progname = args.next() orelse "git-vain";

    if (args.next()) |arg| {
        const isTest = (progname.len >= 4 and std.mem.eql(u8, progname[progname.len - 4 ..], "test"));
        if (!isTest) return _init(arg);
    }

    const dft = git.getDefault();
    return _init(dft);
}

pub fn _init(str: []const u8) TargetError!Self {
    if (str.len < 1) return TargetError.NoInput;
    if (str.len > MaxSize) return TargetError.TooLong;

    var half = false;
    var buf: [20]u8 = undefined;
    var i: u8 = 0;

    var itr = std.mem.window(u8, str, 2, 2);
    while (itr.next()) |ch| : (i += 1) {
        // if (ch[0] == 0) break; // might have a 0 from getDefault
        var val = try hexChrToInt(ch[0]);
        val <<= 4;

        if (ch.len == 2) {
            val += try hexChrToInt(ch[1]);
        } else {
            half = true;
        }

        buf[i] = val;
    }

    return .{ .buf = buf, .buf_len = i, .half = half };
}

fn hexChrToInt(chr: u8) TargetError!u8 {
    if (chr >= '0' and chr <= '9') {
        return chr - '0';
    } else if (chr >= 'a' and chr <= 'f') {
        return chr + 10 - 'a';
    } else return TargetError.NotHexChr;
}

test "init" {
    var git = try Git.init();
    const t = try Self.init(&git); // default value
    try std.testing.expectEqual(2, t.buf_len);
    try std.testing.expectEqual(false, t.half);
}

test "_init" {
    var t = try Self._init("cafe12");
    try std.testing.expectEqual(3, t.buf_len);
    try std.testing.expectEqualDeep(([3]u8{ 0xca, 0xfe, 0x12 })[0..], t.buf[0..3]);
    try std.testing.expectEqual(false, t.half);

    t = try Self._init("123");
    try std.testing.expectEqual(t.buf_len, 2);
    try std.testing.expectEqualDeep(t.buf[0..2], ([2]u8{ 0x12, 0x30 })[0..]);
    try std.testing.expectEqual(true, t.half);

    t = try Self._init("abcdef0123456789");
    try std.testing.expectEqual(8, t.buf_len);
    try std.testing.expectEqual(false, t.half);

    try std.testing.expectError(TargetError.NotHexChr, Self._init("great"));
    try std.testing.expectError(TargetError.NoInput, Self._init(""));
    try std.testing.expectError(TargetError.TooLong, Self._init("12345678901234567"));
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
    const result: [20]u8 = .{ 0xef, 0x42, 0xba, 0xb1, 0x19, 0x1d, 0xa2, 0x72, 0xf1, 0x39, 0x35, 0xf7, 0x8c, 0x40, 0x1e, 0x3d, 0xe0, 0xc1, 0x1a, 0xfb };

    var t = try Self._init("cafe12");
    try std.testing.expectEqual(false, t.match(&result));

    // even number of chrs
    t = try Self._init("ef");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self._init("ef42bab1");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self._init("ef40bab1"); // error in middle
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self._init("ef42bab100"); // make sure last chrs are actually checked
    try std.testing.expectEqual(false, t.match(&result));

    // odd
    t = try Self._init("e");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self._init("f");
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self._init("ef42b");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self._init("ef42a"); // error in last chr
    try std.testing.expectEqual(false, t.match(&result));
    t = try Self._init("ef42bab1191da");
    try std.testing.expectEqual(true, t.match(&result));
    t = try Self._init("ef02bab1191da"); // error in 3rd chr
    try std.testing.expectEqual(false, t.match(&result));
}

comptime {
    std.testing.refAllDecls(Self);
}
