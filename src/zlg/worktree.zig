const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Worktree = opaque {
    pub fn deinit(self: *Worktree) void {
        if (internal.trace_log) log.debug("Worktree.deinit called", .{});

        c.git_worktree_free(@as(*c.git_worktree, @ptrCast(self)));
    }

    /// Check if worktree is valid
    ///
    /// A valid worktree requires both the git data structures inside the linked parent repository and the linked working
    /// copy to be present.
    pub fn valid(self: *const Worktree) !void {
        if (internal.trace_log) log.debug("Worktree.valid called", .{});

        try internal.wrapCall("git_worktree_validate", .{
            @as(*const c.git_worktree, @ptrCast(self)),
        });
    }

    /// Lock worktree if not already locked
    ///
    /// Lock a worktree, optionally specifying a reason why the linked working tree is being locked.
    ///
    /// ## Parameters
    /// * `reason` - Reason why the working tree is being locked
    pub fn lock(self: *Worktree, reason: ?[:0]const u8) !void {
        if (internal.trace_log) log.debug("Worktree.lock called", .{});

        const c_reason = if (reason) |s| s.ptr else null;

        try internal.wrapCall("git_worktree_lock", .{
            @as(*c.git_worktree, @ptrCast(self)),
            c_reason,
        });
    }

    /// Unlock a locked worktree
    ///
    /// Returns `true` if the worktree was no locked
    pub fn unlock(self: *Worktree) !bool {
        if (internal.trace_log) log.debug("Worktree.unlock called", .{});

        return (try internal.wrapCallWithReturn("git_worktree_unlock", .{@as(*c.git_worktree, @ptrCast(self))})) != 0;
    }

    /// Check if worktree is locked
    //
    /// A worktree may be locked if the linked working tree is stored on a portable device which is not available.
    ///
    /// Returns `null` if the worktree is *not* locked, returns the reason for the lock if it is locked.
    pub fn is_locked(self: *const Worktree) !?git.Buf {
        if (internal.trace_log) log.debug("Worktree.is_locked called", .{});

        var ret: git.Buf = .{};

        const locked = (try internal.wrapCallWithReturn("git_worktree_is_locked", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*const c.git_worktree, @ptrCast(self)),
        })) != 0;

        return if (locked) ret else null;
    }

    /// Retrieve the name of the worktree
    ///
    /// The slice returned is valid for the lifetime of the `Worktree`
    pub fn name(self: *Worktree) ![:0]const u8 {
        if (internal.trace_log) log.debug("Worktree.name called", .{});

        return std.mem.sliceTo(c.git_worktree_name(@as(*c.git_worktree, @ptrCast(self))), 0);
    }

    /// Retrieve the path of the worktree
    ///
    /// The slice returned is valid for the lifetime of the `Worktree`
    pub fn path(self: *Worktree) ![:0]const u8 {
        if (internal.trace_log) log.debug("Worktree.path called", .{});

        return std.mem.sliceTo(c.git_worktree_path(@as(*c.git_worktree, @ptrCast(self))), 0);
    }

    pub fn repositoryOpen(self: *Worktree) !*git.Repository {
        if (internal.trace_log) log.debug("Worktree.repositoryOpen called", .{});

        var repo: *git.Repository = undefined;

        try internal.wrapCall("git_repository_open_from_worktree", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            @as(*c.git_worktree, @ptrCast(self)),
        });

        return repo;
    }

    /// Is the worktree prunable with the given options?
    ///
    /// A worktree is not prunable in the following scenarios:
    ///
    /// - the worktree is linking to a valid on-disk worktree. The `valid` member will cause this check to be ignored.
    /// - the worktree is locked. The `locked` flag will cause this check to be ignored.
    ///
    /// If the worktree is not valid and not locked or if the above flags have been passed in, this function will return a
    /// `true`
    pub fn isPruneable(self: *Worktree, options: PruneOptions) !bool {
        if (internal.trace_log) log.debug("Worktree.isPruneable called", .{});

        var c_options = internal.make_c_option.pruneOptions(options);

        return (try internal.wrapCallWithReturn("git_worktree_is_prunable", .{
            @as(*c.git_worktree, @ptrCast(self)),
            &c_options,
        })) != 0;
    }

    /// Prune working tree
    ///
    /// Prune the working tree, that is remove the git data structures on disk. The repository will only be pruned of
    /// `Worktree.isPruneable` succeeds.
    pub fn prune(self: *Worktree, options: PruneOptions) !void {
        if (internal.trace_log) log.debug("Worktree.prune called", .{});

        var c_options = internal.make_c_option.pruneOptions(options);

        try internal.wrapCall("git_worktree_prune", .{
            @as(*c.git_worktree, @ptrCast(self)),
            &c_options,
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const WorktreeAddOptions = struct {
    /// lock newly created worktree
    lock: bool = false,

    /// reference to use for the new worktree HEAD
    ref: ?*git.Reference = null,

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const PruneOptions = packed struct {
    /// Prune working tree even if working tree is valid
    valid: bool = false,
    /// Prune working tree even if it is locked
    locked: bool = false,
    /// Prune checked out working tree
    working_tree: bool = false,

    z_padding: u29 = 0,

    pub fn format(
        value: PruneOptions,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        return internal.formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_padding"},
        );
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_worktree_prune_t), @sizeOf(PruneOptions));
        try std.testing.expectEqual(@bitSizeOf(c.git_worktree_prune_t), @bitSizeOf(PruneOptions));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
