const Self = @This();
const zlg = @import("../zlg/git.zig");
const std = @import("std");

// repo: ?*libgit2.git_repository,
repo: *zlg.Repository,

pub fn init() !Self {
    const hand = try zlg.init();
    const repo = try hand.repositoryOpen(".");
    return .{ .repo = repo };
}

fn getVainDefaultFromConfig(self: *const Self) zlg.GitError![]const u8 {
    const snap = try self.repo.configSnapshot();
    const ret = try snap.getString("vain.default");
    return ret;
}

pub fn getDefault(self: *Self) []const u8 {
    if (self.getVainDefaultFromConfig()) |gvd| {
        return gvd;
    } else |err| switch (err) {
        error.NotFound => {}, // expected
        inline else => std.debug.print("error getting git config vain.default: {!}\n", .{err}),
    }
    return "1234";
}

test "getDefault" {
    var git = try init();

    const d = git.getDefault();
    try std.testing.expect(d[0] != 0);
}

pub fn currentCommit(self: *Self) !*zlg.Commit {
    const ac = try self.repo.annotatedCommitCreateFromRevisionString("HEAD");
    const oid = try ac.commitId();
    const commit = try self.repo.commitLookup(oid);
    return commit;
}

comptime {
    std.testing.refAllDecls(Self);
}
