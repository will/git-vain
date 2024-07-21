const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Representation of an in-progress walk through the commits in a repo
pub const RevWalk = opaque {
    pub fn deinit(self: *RevWalk) void {
        if (internal.trace_log) log.debug("RevWalk.deinit called", .{});

        c.git_revwalk_free(@as(*c.git_revwalk, @ptrCast(self)));
    }

    /// Return the repository on which this walker is operating.
    pub fn repository(self: *RevWalk) *git.Repository {
        if (internal.trace_log) log.debug("RevWalk.repository called", .{});

        return @as(
            *git.Repository,
            @ptrCast(c.git_revwalk_repository(@as(*c.git_revwalk, @ptrCast(self)))),
        );
    }

    /// Reset the revision walker for reuse.
    ///
    /// This will clear all the pushed and hidden commits, and leave the walker in a blank state (just like at creation) ready to
    /// receive new commit pushes and start a new walk.
    ///
    /// The revision walk is automatically reset when a walk is over.
    pub fn reset(self: *RevWalk) !void {
        if (internal.trace_log) log.debug("RevWalk.reset called", .{});

        try internal.wrapCall("git_revwalk_reset", .{
            @as(*c.git_revwalk, @ptrCast(self)),
        });
    }

    /// Add a new root for the traversal
    ///
    /// The pushed commit will be marked as one of the roots from which to start the walk. This commit may not be walked if it or
    /// a child is hidden.
    ///
    /// At least one commit must be pushed onto the walker before a walk can be started.
    ///
    /// The given id must belong to a committish on the walked repository.
    ///
    /// ## Parameters
    /// * `id` - The oid of the commit to start from.
    pub fn push(self: *RevWalk, id: *const git.Oid) !void {
        if (internal.trace_log) log.debug("RevWalk.reset called", .{});

        try internal.wrapCall("git_revwalk_push", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });
    }

    /// Push matching references
    ///
    /// The OIDs pointed to by the references that match the given glob pattern will be pushed to the revision walker.
    ///
    /// A leading 'refs/' is implied if not present as well as a trailing '/\*' if the glob lacks '?', '\*' or '['.
    ///
    /// Any references matching this glob which do not point to a committish will be ignored.
    ///
    /// ## Parameters
    /// * `glob` - The glob pattern references should match.
    pub fn pushGlob(self: *RevWalk, glob: [:0]const u8) !void {
        if (internal.trace_log) log.debug("RevWalk.pushGlob called", .{});

        try internal.wrapCall("git_revwalk_push_glob", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            glob.ptr,
        });
    }

    /// Push the repository's HEAD
    pub fn pushHead(self: *RevWalk) !void {
        if (internal.trace_log) log.debug("RevWalk.pushHead called", .{});

        try internal.wrapCall("git_revwalk_push_head", .{
            @as(*c.git_revwalk, @ptrCast(self)),
        });
    }

    /// Mark a commit (and its ancestors) uninteresting for the output.
    ///
    /// The given id must belong to a committish on the walked repository.
    ///
    /// The resolved commit and all its parents will be hidden from the output on the revision walk.
    ///
    /// ## Parameters
    /// * `id` - The oid of commit that will be ignored during the traversal.
    pub fn hide(self: *RevWalk, id: *const git.Oid) !void {
        if (internal.trace_log) log.debug("RevWalk.hide called", .{});

        try internal.wrapCall("git_revwalk_hide", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });
    }

    /// Hide matching references.
    ///
    /// The OIDs pointed to by the references that match the given glob pattern and their ancestors will be hidden from the output
    /// on the revision walk.
    ///
    /// A leading 'refs/' is implied if not present as well as a trailing '/\*' if the glob lacks '?', '\*' or '['.
    ///
    /// Any references matching this glob which do not point to a committish will be ignored.
    ///
    /// ## Parameters
    /// * `glob` - The glob pattern references should match.
    pub fn hideGlob(self: *RevWalk, glob: [:0]const u8) !void {
        if (internal.trace_log) log.debug("RevWalk.hideGlob called", .{});

        try internal.wrapCall("git_revwalk_hide_glob", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            glob.ptr,
        });
    }

    /// Hide the repository's HEAD
    pub fn hideHead(self: *RevWalk) !void {
        if (internal.trace_log) log.debug("RevWalk.hideHead called", .{});

        try internal.wrapCall("git_revwalk_hide_head", .{
            @as(*c.git_revwalk, @ptrCast(self)),
        });
    }

    /// Push the OID pointed to by a reference
    ///
    /// The reference must point to a committish.
    ///
    /// ## Parameters
    /// * `ref` - The reference to push.
    pub fn pushRef(self: *RevWalk, ref: [:0]const u8) !void {
        if (internal.trace_log) log.debug("RevWalk.pushRef called", .{});

        try internal.wrapCall("git_revwalk_push_ref", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            ref.ptr,
        });
    }

    /// Hide the OID pointed to by a reference
    ///
    /// The reference must point to a committish.
    ///
    /// ## Parameters
    /// * `ref` - The reference to hide.
    pub fn hideRef(self: *RevWalk, ref: [:0]const u8) !void {
        if (internal.trace_log) log.debug("RevWalk.hideRef called", .{});

        try internal.wrapCall("git_revwalk_hide_ref", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            ref.ptr,
        });
    }

    /// Push and hide the respective endpoints of the given range.
    ///
    /// The range should be of the form "<commit>..<commit>" where each <commit> is in the form accepted by
    /// 'Repository.revParseSingle'. The left-hand commit will be hidden and the right-hand commit pushed.
    ///
    /// ## Parameters
    /// * `range` - The range.
    pub fn pushRange(self: *RevWalk, range: [:0]const u8) !void {
        if (internal.trace_log) log.debug("RevWalk.pushRange called", .{});

        try internal.wrapCall("git_revwalk_push_range", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            range.ptr,
        });
    }

    /// Simplify the history by first-parent.
    ///
    /// No parents other than the first for each commit will be enqueued.
    pub fn simplifyFirstParent(self: *RevWalk) !void {
        if (internal.trace_log) log.debug("RevWalk.simplifyFirstParent called", .{});

        try internal.wrapCall("git_revwalk_simplify_first_parent", .{
            @as(*c.git_revwalk, @ptrCast(self)),
        });
    }

    /// Get the next commit from the revision walk.
    ///
    /// The initial call to this method is *not* blocking when iterating through a repo with a time-sorting mode.
    ///
    /// Iterating with Topological or inverted modes makes the initial call blocking to preprocess the commit list, but this block
    /// should be mostly unnoticeable on most repositories (topological preprocessing times at 0.3s on the git.git repo).
    ///
    /// The revision walker is reset when the walk is over.
    pub fn next(self: *RevWalk) !?git.Oid {
        if (internal.trace_log) log.debug("RevWalk.next called", .{});

        var oid: git.Oid = undefined;

        internal.wrapCall("git_revwalk_next", .{
            @as(*c.git_oid, @ptrCast(&oid)),
            @as(*c.git_revwalk, @ptrCast(self)),
        }) catch |err| switch (err) {
            git.GitError.IterOver => return null,
            else => |e| return e,
        };

        return oid;
    }

    /// Change the sorting mode when iterating through the repository's contents.
    ///
    /// Changing the sorting mode resets the walker.
    ///
    /// ## Parameters
    /// * `sort_mode` - The sort mode to apply.
    pub fn setSortingMode(self: *RevWalk, sort_mode: SortMode) !void {
        if (internal.trace_log) log.debug("RevWalk.setSortingMode called", .{});

        try internal.wrapCall("git_revwalk_sorting", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            @as(u32, @bitCast(sort_mode)),
        });
    }

    /// Mode to specify the sorting which a revwalk should perform.
    /// Defaults to the same default method from `git`: reverse chronological order.
    pub const SortMode = packed struct {
        /// Sort the repository contents in topological order (no parents before all of its children are shown); this sorting mode
        /// can be combined with time sorting to produce `git`'s `--date-order`
        topological: bool = false,

        /// Sort the repository contents by commit time; this sorting mode can be combined with topological sorting.
        time: bool = false,

        /// Iterate through the repository contents in reverse order; this sorting mode can be combined with any of the above.
        reverse: bool = false,

        z_padding: u29 = 0,

        pub fn format(
            value: SortMode,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            return internal.formatWithoutFields(
                value,
                options,
                writer,
                &.{
                    "z_padding",
                },
            );
        }

        test {
            try std.testing.expectEqual(@sizeOf(u32), @sizeOf(SortMode));
            try std.testing.expectEqual(@bitSizeOf(u32), @bitSizeOf(SortMode));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Adds, changes or removes a callback function to hide a commit and its parents
    ///
    /// If the callback function returns non-zero value, then this commit and its parents will be hidden.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function to hide a commit and its parents.
    ///
    /// ## Callback Parameters
    /// * `commit_id` - OID of Commit
    pub fn addHideCallback(
        self: *RevWalk,
        comptime callback_fn: fn (commit_id: *const git.Oid) c_int,
    ) !void {
        const cb = struct {
            pub fn cb(
                commit_id: *const git.Oid,
                _: *u8,
            ) c_int {
                return callback_fn(commit_id);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.addHideCallbackWithUserData(&dummy_data, cb);
    }

    /// Adds, changes or removes a callback function to hide a commit and its parents
    ///
    /// If the callback function returns non-zero value, then this commit and its parents will be hidden.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function to hide a commit and its parents.
    ///
    /// ## Callback Parameters
    /// * `commit_id` - OID of Commit
    /// * `user_data_ptr` - The user data
    pub fn addHideCallbackWithUserData(
        self: *RevWalk,
        user_data: anytype,
        comptime callback_fn: fn (
            commit_id: *const git.Oid,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                commit_id: *const c.commit_id,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.Oid, @ptrCast(commit_id)),
                    @as(UserDataType, @ptrCast(@alignCast( payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("RevWalk.addHideCallbackWithUserData called", .{});

        try internal.wrapCall("git_revwalk_add_hide_cb", .{
            @as(*c.git_revwalk, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
