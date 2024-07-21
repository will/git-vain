const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const AnnotatedCommit = opaque {
    pub fn deinit(self: *AnnotatedCommit) void {
        if (internal.trace_log) log.debug("AnnotatedCommit.deinit called", .{});

        c.git_annotated_commit_free(@ptrCast(self));
    }

    /// Gets the commit ID that the given `AnnotatedCommit` refers to.
    pub fn commitId(self: *AnnotatedCommit) !*const git.Oid {
        if (internal.trace_log) log.debug("AnnotatedCommit.commitId called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_annotated_commit_id(@ptrCast(self))),
        );
    }

    /// Gets the refname that the given `AnnotatedCommit` refers to.
    pub fn refname(self: *AnnotatedCommit) ![:0]const u8 {
        if (internal.trace_log) log.debug("AnnotatedCommit.refname called", .{});

        return std.mem.sliceTo(
            c.git_annotated_commit_ref(@ptrCast(self)),
            0,
        );
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
