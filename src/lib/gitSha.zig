const std = @import("std");
const Sha1 = std.crypto.hash.Sha1;
const Git = @import("git.zig");

const Self = @This();

hash: Sha1 = undefined,
startingSha: [20]u8 = undefined,
header: *const []u8 = undefined,
message: *const []u8 = undefined,

pub fn init(git: *Git) !Self {
    const commit = try git.currentCommit();
    const startingSha = commit.id().id;

    return Self{
        .hash = Sha1.init(.{}),
        .startingSha = startingSha,
    };
}

pub fn trySha(self: *const Self, str: []const u8) [20]u8 {
    const original = self.hash;
    var dupe_hash = Sha1{ .s = original.s, .buf = original.buf, .buf_len = original.buf_len };
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
