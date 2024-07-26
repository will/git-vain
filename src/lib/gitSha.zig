const std = @import("std");
const Sha1 = std.crypto.hash.Sha1;
const Git = @import("git.zig");
const Allocator = std.mem.Allocator;

const Self = @This();

hash: Sha1 = undefined,
startingSha: [20]u8 = undefined,
header: []const u8 = undefined,
message: []const u8 = undefined,
hinfo: HeaderInfo = undefined,
git: *Git = undefined,

// git commit format:
//   commit <total len in decimal after nullbyte>\0<header ending in \n><extra \n><message ending in \n>

pub fn init(git: *Git, allocator: Allocator) !Self {
    const commit = try git.currentCommit();
    const startingSha = commit.id().id;

    const header = commit.getHeaderRaw() orelse return error.noHeader;
    const message = commit.getMessageRaw() orelse return error.noMessage;

    const retHeader = try allocator.alloc(u8, header.len);
    std.mem.copyForwards(u8, retHeader, header);

    const retMessage = try allocator.alloc(u8, message.len);
    std.mem.copyForwards(u8, retMessage, message);

    var hash = Sha1.init(.{});
    var commitTagBuf = [_]u8{undefined} ** 50;
    const commitTag = try std.fmt.bufPrint(&commitTagBuf, "commit {d}\x00", .{header.len + message.len + 1});

    hash.update(commitTag);

    const hinfo = try parseHeader(header);
    hash.update(header[0..hinfo.author_time_start]);

    return Self{
        .git = git,
        .hash = hash,
        .startingSha = startingSha,
        .message = retMessage,
        .header = retHeader,
        .hinfo = hinfo,
    };
}

const HeaderInfo = struct {
    author_time_start: u64 = 0,
    author_time: i64 = 0, // using i64 to make the offset calculations easier
    committer_time_start: u64 = 0,
    committer_time: i64 = 0,
};

fn parseHeader(header: []const u8) !HeaderInfo {
    var i: u64 = 0;

    i = advanceToProbe(i, header, "\nauthor ");
    i = advanceToProbe(i, header, "> ");
    const author_time_start = i;
    // dont have to worry about unix time adding a decimal digit until 2286-11-20
    const author_time = try std.fmt.parseUnsigned(i64, header[i .. i + 10], 10);

    i = advanceToProbe(i, header, "\ncommitter ");
    i = advanceToProbe(i, header, "> ");
    const committer_time_start = i;
    const committer_time = try std.fmt.parseUnsigned(i64, header[i .. i + 10], 10);

    return HeaderInfo{
        .author_time_start = author_time_start,
        .author_time = author_time,
        .committer_time_start = committer_time_start,
        .committer_time = committer_time,
    };
}

fn advanceToProbe(start: u64, header: []const u8, probe: []const u8) u64 {
    var i = start;
    while (i < header.len - probe.len) : (i += 1) {
        if (std.mem.eql(u8, header[i .. i + probe.len], probe)) break;
    }
    return i + probe.len;
}

test "parseHeader" {
    const header =
        \\tree e9054e9ccfee355e80c40ba84abb8f438f9e688b
        \\parent 26f67e5988b15877d2807511b262c870b2492548
        \\author Will Leinweber <my@email.com> 1721827347 +0200
        \\committer Will Leinweber <my@email.com> 4294967999 +0200
    ;

    const info = try parseHeader(header);
    try std.testing.expectEqual(info.author_time_start, 131);
    try std.testing.expectEqual(info.author_time, 1721827347);
    try std.testing.expectEqual(info.committer_time_start, 188);
    try std.testing.expectEqual(info.committer_time, 4294967999);

    const header2 =
        \\tree e9054e9ccfee355e80c40ba84abb8f438f9e688b
        \\parent 26f67e5988b15877d2807511b262c870b2492548
        \\parent 37f67e5988b15877d2807511b262c870b2492548
        \\author Will Leinweber <my@email.com> 1721827347 +0200
        \\committer Will Leinweber <my@email.com> 4294967999 +0200
    ;

    const info2 = try parseHeader(header2);
    try std.testing.expectEqual(info2.author_time_start, 179);
    try std.testing.expectEqual(info2.author_time, 1721827347);
    try std.testing.expectEqual(info2.committer_time_start, 236);
    try std.testing.expectEqual(info2.committer_time, 4294967999);
}

pub fn trySha(self: *const Self, str: []const u8) [20]u8 {
    const original = self.hash;
    var dupe_hash = Sha1{ .s = original.s, .buf = original.buf, .buf_len = original.buf_len, .total_len = original.total_len };
    var result: [20]u8 = undefined;

    dupe_hash.update(str);
    dupe_hash.final(&result);

    return result;
}

test "trySha" {
    var sha = Self{};
    sha.hash.update("abc");

    const original_state = sha.hash.s;
    // can call several times without updating original
    const result1 = trySha(&sha, "def");
    const result2 = trySha(&sha, "def");
    try std.testing.expectEqual(result1, result2);
    try std.testing.expectEqual(original_state, sha.hash.s);
}

pub fn trySpiral(self: *const Self, n: i32) ![20]u8 {
    const s = spiral(n);
    const x = s[0];
    const y = s[1];
    const original = self.hash;
    const hinfo = self.hinfo;
    var dupe_hash = Sha1{ .s = original.s, .buf = original.buf, .buf_len = original.buf_len, .total_len = original.total_len };
    var result: [20]u8 = undefined;
    var dateBuf = [_]u8{undefined} ** 10;

    var datestr = try std.fmt.bufPrint(&dateBuf, "{d}", .{hinfo.author_time + x});
    dupe_hash.update(datestr);
    dupe_hash.update(self.header[hinfo.author_time_start + 10 .. hinfo.committer_time_start]);

    datestr = try std.fmt.bufPrint(&dateBuf, "{d}", .{hinfo.committer_time + y});
    dupe_hash.update(datestr);
    dupe_hash.update(self.header[hinfo.committer_time_start + 10 .. self.header.len]);

    dupe_hash.update("\n");
    dupe_hash.update(self.message);

    dupe_hash.final(&result);
    return result;
}

fn spiral(ni: i32) [2]i32 {
    std.debug.assert(ni > 0);
    const n: f64 = @floatFromInt(ni);
    // const s: i32 = @intFromFloat(@floor((@sqrt(n) + 1) / 2));
    const s: i32 = @intFromFloat((@sqrt(n) + 1) / 2);
    const lt = ni - (((2 * s) - 1) * ((2 * s) - 1));
    const l = @divTrunc(lt, (2 * s));
    const e = lt - (2 * s * l) - s + 1;

    return switch (l) {
        0 => .{ s, e },
        1 => .{ -e, s },
        2 => .{ -s, -e },
        else => .{ e, -s },
    };
}

const expectEqual = std.testing.expectEqual;

test "spiral" {
    try expectEqual(spiral(1), .{ 1, 0 });
    try expectEqual(spiral(2), .{ 1, 1 });
    try expectEqual(spiral(3), .{ 0, 1 });
    try expectEqual(spiral(4), .{ -1, 1 });
    try expectEqual(spiral(5), .{ -1, 0 });
    try expectEqual(spiral(6), .{ -1, -1 });
    try expectEqual(spiral(7), .{ 0, -1 });
    try expectEqual(spiral(8), .{ 1, -1 });
    try expectEqual(spiral(9), .{ 2, -1 });
    try expectEqual(spiral(10), .{ 2, 0 });
    try expectEqual(spiral(11), .{ 2, 1 });
    try expectEqual(spiral(12), .{ 2, 2 });
    try expectEqual(spiral(13), .{ 1, 2 });
    try expectEqual(spiral(14), .{ 0, 2 });
    try expectEqual(spiral(15), .{ -1, 2 });
    try expectEqual(spiral(16), .{ -2, 2 });
    try expectEqual(spiral(16), .{ -2, 2 });
    try expectEqual(spiral(16), .{ -2, 2 });
}

pub fn ammend(self: *const Self, i: i32) !void {
    const commit = try self.git.currentCommit();
    const author = try commit.getAuthor().duplicate();
    const committer = try commit.getCommitter().duplicate();
    const offsets = spiral(i);

    author.when.time += offsets[0];
    committer.when.time += offsets[1];

    _ = try commit.amend("HEAD", author, committer, null, null, null);
}

comptime {
    std.testing.refAllDecls(@This());
}
