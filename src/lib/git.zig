const Self = @This();
const std = @import("std");
const libgit = @import("libgit.zig");
const libgit2 = libgit.libgit2;
const wrapCall = libgit.wrapCall;

repo: ?*libgit2.git_repository,

pub fn init() !Self {
    var repo: ?*libgit2.git_repository = null;

    if (libgit2.git_libgit2_init() < 0) return error.ErrorInitializingLibgit2;
    _ = libgit2.git_repository_open(&repo, ".");
    return Self{ .repo = repo };
}

fn getVainDefaultFromConfig(self: *const Self) libgit.GitError![]const u8 {
    var cfg: ?*libgit2.git_config = null;
    try wrapCall("git_repository_config_snapshot", .{ &cfg, self.repo });
    var str: ?[*:0]const u8 = undefined;
    try wrapCall("git_config_get_string", .{ &str, cfg, "vain.default" });
    return std.mem.sliceTo(str.?, 0);
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

pub fn getHead(self: *const Self) !void {
    // git cat-file -p HEAD
    // https://libgit2.org/libgit2/ex/HEAD/cat-file.html
    // https://github.com/leecannon/zig-libgit2/blob/ff3e20b1343f35d639e945795314c05ac23a9d65/src/repository.zig#L2918
    //
    // var commit: *libgit.Object = undefined;

    // try libgit.wrapCall("git_revparse_single", .{
    //     @as(*?*libgit2.git_object, @ptrCast(&commit)),
    //     self.repo,
    //     "HEAD",
    // });
    //
    // TODO: use git_repository_head
    // const gctid = libgit2.git_commit_tree_id(@ptrCast(self));
    // const tree: *libgit.Oid = @constCast(@ptrCast(gctid));
    //
    // var buf: [libgit.Oid.hex_buffer_size]u8 = undefined;
    // const hex = try tree.formatHex(&buf);
    // std.debug.print("tree {s}, {x}\n", .{ hex, tree.id });
    _ = self;

    const hand = try zlg.init();
    defer hand.deinit();
    var repo = try hand.repositoryOpen(".");
    defer repo.deinit();
    //const ac = try obj.annotatedCommitCreate(repo);
    //defer ac.deinit();

    const ac = try repo.annotatedCommitCreateFromRevisionString("HEAD");
    const oid = try ac.commitId();
    const commit = try repo.commitLookup(oid);

    const header = commit.getHeaderRaw() orelse unreachable;
    const message = commit.getMessageRaw() orelse unreachable;

    const Sha = @import("gitSha.zig");
    var sha = Sha.init();

    var buffer = [_]u8{undefined} ** 1000;
    const content = try std.fmt.bufPrint(&buffer, "{s}\n{s}", .{ header, message });

    var commitTagBuf = [_]u8{undefined} ** 50;
    const commitTag = try std.fmt.bufPrint(&commitTagBuf, "commit {d}\x00", .{content.len});
    // sha.hash.update("commit 240\x00");
    sha.hash.update(commitTag);
    sha.hash.update(content);
    var result: [20]u8 = undefined;
    sha.hash.final(&result);
    std.debug.print("myhash: {x}\ntheirs: {x}", .{ result, oid.id });
}

test "getHead" {
    const git = try init();
    try git.getHead();
}

comptime {
    std.testing.refAllDecls(Self);
}
