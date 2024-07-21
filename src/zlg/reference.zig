const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Reference = opaque {
    pub fn deinit(self: *Reference) void {
        if (internal.trace_log) log.debug("Reference.deinit called", .{});

        c.git_reference_free(@as(*c.git_reference, @ptrCast(self)));
    }

    /// Delete an existing branch reference.
    ///
    /// Note that if the deletion succeeds, the reference will not be valid anymore, and should be freed immediately by the user
    /// using `deinit`.
    pub fn deleteBranch(self: *Reference) !void {
        if (internal.trace_log) log.debug("Reference.deleteBranch called", .{});

        try internal.wrapCall("git_branch_delete", .{@as(*c.git_reference, @ptrCast(self))});
    }

    pub fn annotatedCommitCreate(self: *const Reference, repository: *git.Repository) !*git.AnnotatedCommit {
        if (internal.trace_log) log.debug("Reference.annotatedCommitCreate called", .{});

        var result: *git.AnnotatedCommit = undefined;

        try internal.wrapCall("git_annotated_commit_from_ref", .{
            @as(*?*c.git_annotated_commit, @ptrCast(&result)),
            @as(*c.git_repository, @ptrCast(repository)),
            @as(*const c.git_reference, @ptrCast(self)),
        });

        return result;
    }

    /// Move/rename an existing local branch reference.
    ///
    /// The new branch name will be checked for validity.
    ///
    /// Note that if the move succeeds, the old reference will not be valid anymore, and should be freed immediately by the user
    /// using `deinit`.
    pub fn move(self: *Reference, new_branch_name: [:0]const u8, force: bool) !*Reference {
        if (internal.trace_log) log.debug("Reference.move called", .{});

        var ref: *Reference = undefined;

        try internal.wrapCall("git_branch_move", .{
            @as(*?*c.git_reference, @ptrCast(&ref)),
            @as(*c.git_reference, @ptrCast(self)),
            new_branch_name.ptr,
            @intFromBool(force),
        });

        return ref;
    }

    pub fn nameGet(self: *Reference) ![:0]const u8 {
        if (internal.trace_log) log.debug("Reference.nameGet called", .{});

        var name: ?[*:0]const u8 = undefined;

        try internal.wrapCall("git_branch_name", .{ &name, @as(*const c.git_reference, @ptrCast(self)) });

        return std.mem.sliceTo(name.?, 0);
    }

    pub fn upstreamGet(self: *Reference) !*Reference {
        if (internal.trace_log) log.debug("Reference.upstreamGet called", .{});

        var ref: *Reference = undefined;

        try internal.wrapCall("git_branch_upstream", .{
            @as(*?*c.git_reference, @ptrCast(&ref)),
            @as(*const c.git_reference, @ptrCast(self)),
        });

        return ref;
    }

    pub fn upstreamSet(self: *Reference, branch_name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Reference.upstreamSet called", .{});

        try internal.wrapCall("git_branch_set_upstream", .{ @as(*c.git_reference, @ptrCast(self)), branch_name.ptr });
    }

    pub fn isHead(self: *const Reference) !bool {
        if (internal.trace_log) log.debug("Reference.isHead", .{});

        return (try internal.wrapCallWithReturn("git_branch_is_head", .{@as(*const c.git_reference, @ptrCast(self))})) == 1;
    }

    pub fn isCheckedOut(self: *const Reference) !bool {
        if (internal.trace_log) log.debug("Reference.isCheckedOut", .{});

        return (try internal.wrapCallWithReturn("git_branch_is_checked_out", .{@as(*const c.git_reference, @ptrCast(self))})) == 1;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
