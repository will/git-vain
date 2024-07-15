const std = @import("std");

const Self = @This();
const MaxSize = 16; // NOTE: just picking this, real hard limit would probably be 40?
buf: [20]u8 = undefined,
buf_len: u8 = 0,
half: bool = false,

const TargetError = error{
    // not 0-9 or a-z
    NotHexChr,
    NoInput,
    TooLong,
};

pub fn init() TargetError!Self {
    var args = std.process.args(); // wont work on windows or wasi
    _ = args.skip(); // program name
    if (args.next()) |arg| return _init(arg);
    return _init(&getDefault());
}

pub fn _init(str: []const u8) TargetError!Self {
    if (str.len < 1) return TargetError.NoInput;
    if (str.len > MaxSize) return TargetError.TooLong;

    var half = false;
    var buf: [20]u8 = undefined;
    var i: u8 = 0;

    var itr = std.mem.window(u8, str, 2, 2);
    while (itr.next()) |ch| : (i += 1) {
        if (ch[0] == 0) break; // might have a 0 from getDefault
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
    const t = try Self.init(); // default value
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
    var sha = @import("gitSha.zig").init();
    const result = sha.trySha("howdy"); // { ef, 42, ba, b1, 19, 1d, a2, 72, f1, 39, 35, f7, 8c, 40, 1e, 3d, e0, c1, 1a, fb }

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

fn getGitDefault() ![MaxSize]u8 {
    const argv = [_][]const u8{ "git", "config", "vain.default" };

    const Child = std.process.Child;
    const ArrayList = std.ArrayList;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var child = Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var stdout = ArrayList(u8).init(allocator);
    var stderr = ArrayList(u8).init(allocator);
    defer {
        stdout.deinit();
        stderr.deinit();
    }

    try child.spawn();
    try child.collectOutput(&stdout, &stderr, 1024);
    const term = try child.wait();

    if (term.Exited == 0) {
        var ret: [MaxSize]u8 = .{0} ** MaxSize;
        std.mem.copyForwards(u8, &ret, stdout.items);
        if (ret[stdout.items.len - 1] == '\n') ret[stdout.items.len - 1] = 0;
        return ret;
    } else return error.NonZeroExitGit;
}

fn getDefault() [MaxSize]u8 {
    if (getGitDefault()) |git| {
        return git;
    } else |err| {
        std.debug.print("error getting git config vain.default: {!}\n", .{err});
        return .{ '1', '2', '3', '4' } ++ .{0} ** (MaxSize - 4);
    }
}

test "getDefault" {
    const d = getDefault();
    try std.testing.expect(d[0] != 0);
}

comptime {
    std.testing.refAllDecls(Self);
}
