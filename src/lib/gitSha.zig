const std = @import("std");
const Sha1 = std.crypto.hash.Sha1;
const Git = @import("git.zig");
const Allocator = std.mem.Allocator;

const Self = @This();

hash: Sha1 = undefined,
startingSha: [20]u8 = undefined,
header: []const u8 = undefined,
message: []const u8 = undefined,

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

    // TODO: split from head,msg into <1st part until first date> <middle part until second date> <time offset, extra newline, and message>
    hash.update(commitTag);
    hash.update(header);
    hash.update("\n");
    // hash.update(message);

    return Self{
        .hash = hash,
        .startingSha = startingSha,
        .header = retHeader,
        .message = retMessage,
    };
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

comptime {
    std.testing.refAllDecls(@This());
}
