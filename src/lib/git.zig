const Self = @This();
const std = @import("std");
const libgit = @import("libgit.zig");
const libgit2 = libgit.libgit2;
const wrapCall = libgit.wrapCall;

// repo: ?*libgit2.git_repository,
repo: *zlg.Repository,

pub fn init() !Self {
    // var repo: ?*libgit2.git_repository = null;
    //
    // if (libgit2.git_libgit2_init() < 0) return error.ErrorInitializingLibgit2;
    // _ = libgit2.git_repository_open(&repo, ".");

    const hand = try zlg.init();
    //   defer hand.deinit();
    const repo = try hand.repositoryOpen(".");
    //    defer repo.deinit();
    return Self{ .repo = repo };
}

// fn getVainDefaultFromConfig(self: *const Self) libgit.GitError![]const u8 {
fn getVainDefaultFromConfig(self: *const Self) zlg.GitError![]const u8 {
    // var cfg: ?*libgit2.git_config = null;
    // try wrapCall("git_repository_config_snapshot", .{ &cfg, self.repo });
    // var str: ?[*:0]const u8 = undefined;
    // try wrapCall("git_config_get_string", .{ &str, cfg, "vain.default" });
    // return std.mem.sliceTo(str.?, 0);
    const snap = try self.repo.configSnapshot();
    const ret = try snap.getString("vain.default");
    return ret;
}

pub fn getDefault(self: *Self) []const u8 {
    if (self.getVainDefaultFromConfig()) |gvd| {
        return gvd;
    } else |err| switch (err) {
        error.NotFound => {}, // expected
        error.GenericError => libgit.printLastError(),
        inline else => std.debug.print("error getting git config vain.default: {!}\n", .{err}),
    }
    return "1234";
}

test "getDefault" {
    var git = try init();

    const d = git.getDefault();
    try std.testing.expect(d[0] != 0);
}

const zlg = @import("../zlg/git.zig");

pub fn currentCommit(self: *Self) !*zlg.Commit {
    const ac = try self.repo.annotatedCommitCreateFromRevisionString("HEAD");
    const oid = try ac.commitId();
    const commit = try self.repo.commitLookup(oid);
    return commit;
}

comptime {
    std.testing.refAllDecls(Self);
}
