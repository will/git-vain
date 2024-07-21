const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Repository = opaque {
    pub fn deinit(self: *Repository) void {
        if (internal.trace_log) log.debug("Repository.deinit called", .{});

        c.git_repository_free(@as(*c.git_repository, @ptrCast(self)));
    }

    pub fn state(self: *Repository) RepositoryState {
        if (internal.trace_log) log.debug("Repository.state called", .{});

        return @as(RepositoryState, @enumFromInt(c.git_repository_state(@as(*c.git_repository, @ptrCast(self)))));
    }

    pub const RepositoryState = enum(c_int) {
        none,
        merge,
        revert,
        revert_sequence,
        cherrypick,
        cherrypick_sequence,
        bisect,
        rebase,
        rebase_interactive,
        rebase_merge,
        apply_mailbox,
        apply_mailbox_or_rebase,
    };

    /// Describe a commit
    ///
    /// Perform the describe operation on the current commit and the worktree.
    pub fn describe(self: *Repository, options: git.DescribeOptions) !*git.DescribeResult {
        if (internal.trace_log) log.debug("Repository.describe called", .{});

        var result: *git.DescribeResult = undefined;

        var c_options = internal.make_c_option.describeOptions(options);

        try internal.wrapCall("git_describe_workdir", .{
            @as(*?*c.git_describe_result, @ptrCast(&result)),
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
        });

        return result;
    }

    /// Retrieve the configured identity to use for reflogs
    pub fn identityGet(self: *const Repository) !Identity {
        if (internal.trace_log) log.debug("Repository.identityGet called", .{});

        var c_name: ?[*:0]u8 = undefined;
        var c_email: ?[*:0]u8 = undefined;

        try internal.wrapCall("git_repository_ident", .{ &c_name, &c_email, @as(*const c.git_repository, @ptrCast(self)) });

        const name: ?[:0]const u8 = if (c_name) |ptr| std.mem.sliceTo(ptr, 0) else null;
        const email: ?[:0]const u8 = if (c_email) |ptr| std.mem.sliceTo(ptr, 0) else null;

        return Identity{ .name = name, .email = email };
    }

    /// Set the identity to be used for writing reflogs
    ///
    /// If both are set, this name and email will be used to write to the reflog.
    /// Set to `null` to unset; When unset, the identity will be taken from the repository's configuration.
    pub fn identitySet(self: *Repository, identity: Identity) !void {
        if (internal.trace_log) log.debug("Repository.identitySet called", .{});

        const name_temp = if (identity.name) |slice| slice.ptr else null;
        const email_temp = if (identity.email) |slice| slice.ptr else null;
        try internal.wrapCall("git_repository_set_ident", .{ @as(*c.git_repository, @ptrCast(self)), name_temp, email_temp });
    }

    pub const Identity = struct {
        name: ?[:0]const u8,
        email: ?[:0]const u8,
    };

    pub fn namespaceGet(self: *Repository) !?[:0]const u8 {
        if (internal.trace_log) log.debug("Repository.namespaceGet called", .{});

        return if (c.git_repository_get_namespace(@as(*c.git_repository, @ptrCast(self)))) |s| std.mem.sliceTo(s, 0) else null;
    }

    /// Sets the active namespace for this Git Repository
    ///
    /// This namespace affects all reference operations for the repo. See `man gitnamespaces`
    ///
    /// ## Parameters
    /// * `namespace` - The namespace. This should not include the refs folder, e.g. to namespace all references under
    ///                 "refs/namespaces/foo/", use "foo" as the namespace.
    pub fn namespaceSet(self: *Repository, namespace: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.namespaceSet called", .{});

        try internal.wrapCall("git_repository_set_namespace", .{ @as(*c.git_repository, @ptrCast(self)), namespace.ptr });
    }

    pub fn isHeadDetached(self: *Repository) !bool {
        if (internal.trace_log) log.debug("Repository.isHeadDetached called", .{});

        return (try internal.wrapCallWithReturn("git_repository_head_detached", .{
            @as(*c.git_repository, @ptrCast(self)),
        })) == 1;
    }

    pub fn head(self: *Repository) !*git.Reference {
        if (internal.trace_log) log.debug("Repository.head called", .{});

        var ref: *git.Reference = undefined;

        try internal.wrapCall("git_repository_head", .{
            @as(*?*c.git_reference, @ptrCast(&ref)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ref;
    }

    /// Make the repository HEAD point to the specified reference.
    ///
    /// If the provided reference points to a Tree or a Blob, the HEAD is unaltered and an error is returned.
    ///
    /// If the provided reference points to a branch, the HEAD will point to that branch, staying attached, or become attached if
    /// it isn't yet. If the branch doesn't exist yet, the HEAD will be attached to an unborn branch.
    ///
    /// Otherwise, the HEAD will be detached and will directly point to the commit.
    ///
    /// ## Parameters
    /// * `ref_name` - Canonical name of the reference the HEAD should point at
    pub fn headSet(self: *Repository, ref_name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.headSet called", .{});

        try internal.wrapCall("git_repository_set_head", .{ @as(*c.git_repository, @ptrCast(self)), ref_name.ptr });
    }

    /// Make the repository HEAD directly point to a commit.
    ///
    /// If the provided commit cannot be found in the repository `GitError.NotFound` is returned.
    /// If the provided commit cannot be peeled into a commit, the HEAD is unaltered and an error is returned.
    /// Otherwise, the HEAD will eventually be detached and will directly point to the peeled commit.
    ///
    /// ## Parameters
    /// * `commit` - Object id of the commit the HEAD should point to
    pub fn headDetachedSet(self: *Repository, commit: *const git.Oid) !void {
        if (internal.trace_log) log.debug("Repository.headDetachedSet called", .{});

        try internal.wrapCall("git_repository_set_head_detached", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(commit)),
        });
    }

    /// Make the repository HEAD directly point to the commit.
    ///
    /// This behaves like `Repository.setHeadDetached` but takes an annotated commit, which lets you specify which
    /// extended sha syntax string was specified by a user, allowing for more exact reflog messages.
    ///
    /// See the documentation for `Repository.setHeadDetached`.
    pub fn setHeadDetachedFromAnnotated(self: *Repository, commitish: *git.AnnotatedCommit) !void {
        if (internal.trace_log) log.debug("Repository.setHeadDetachedFromAnnotated called", .{});

        try internal.wrapCall("git_repository_set_head_detached_from_annotated", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_annotated_commit, @ptrCast(commitish)),
        });
    }

    /// Detach the HEAD.
    ///
    /// If the HEAD is already detached and points to a Tag, the HEAD is updated into making it point to the peeled commit.
    /// If the HEAD is already detached and points to a non commitish, the HEAD is unaltered, and an error is returned.
    ///
    /// Otherwise, the HEAD will be detached and point to the peeled commit.
    pub fn detachHead(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.detachHead called", .{});

        try internal.wrapCall("git_repository_detach_head", .{@as(*c.git_repository, @ptrCast(self))});
    }

    pub fn isHeadForWorktreeDetached(self: *Repository, name: [:0]const u8) !bool {
        if (internal.trace_log) log.debug("Repository.isHeadForWorktreeDetached called", .{});

        return (try internal.wrapCallWithReturn(
            "git_repository_head_detached_for_worktree",
            .{ @as(*c.git_repository, @ptrCast(self)), name.ptr },
        )) == 1;
    }

    pub fn headForWorktree(self: *Repository, name: [:0]const u8) !*git.Reference {
        if (internal.trace_log) log.debug("Repository.headForWorktree called", .{});

        var ref: *git.Reference = undefined;

        try internal.wrapCall("git_repository_head_for_worktree", .{
            @as(*?*c.git_reference, @ptrCast(&ref)),
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });

        return ref;
    }

    pub fn isHeadUnborn(self: *Repository) !bool {
        if (internal.trace_log) log.debug("Repository.isHeadUnborn called", .{});

        return (try internal.wrapCallWithReturn("git_repository_head_unborn", .{@as(*c.git_repository, @ptrCast(self))})) == 1;
    }

    pub fn isShallow(self: *Repository) bool {
        if (internal.trace_log) log.debug("Repository.isShallow called", .{});

        return c.git_repository_is_shallow(@as(*c.git_repository, @ptrCast(self))) == 1;
    }

    pub fn isEmpty(self: *Repository) !bool {
        if (internal.trace_log) log.debug("Repository.isEmpty called", .{});

        return (try internal.wrapCallWithReturn("git_repository_is_empty", .{@as(*c.git_repository, @ptrCast(self))})) == 1;
    }

    pub fn isBare(self: *const Repository) bool {
        if (internal.trace_log) log.debug("Repository.isBare called", .{});

        return c.git_repository_is_bare(@as(*const c.git_repository, @ptrCast(self))) == 1;
    }

    pub fn isWorktree(self: *const Repository) bool {
        if (internal.trace_log) log.debug("Repository.isWorktree called", .{});

        return c.git_repository_is_worktree(@as(*const c.git_repository, @ptrCast(self))) == 1;
    }

    /// Get the location of a specific repository file or directory
    pub fn itemPath(self: *const Repository, item: RepositoryItem) !git.Buf {
        if (internal.trace_log) log.debug("Repository.itemPath called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_repository_item_path", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*const c.git_repository, @ptrCast(self)),
            @intFromEnum(item),
        });

        return buf;
    }

    pub const RepositoryItem = enum(c_uint) {
        gitdir,
        workdir,
        commondir,
        index,
        objects,
        refs,
        packed_refs,
        remotes,
        config,
        info,
        hooks,
        logs,
        modules,
        worktrees,
    };

    pub fn pathGet(self: *const Repository) [:0]const u8 {
        if (internal.trace_log) log.debug("Repository.pathGet called", .{});

        return std.mem.sliceTo(c.git_repository_path(@as(*const c.git_repository, @ptrCast(self))), 0);
    }

    pub fn workdirGet(self: *const Repository) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Repository.workdirGet called", .{});

        return if (c.git_repository_workdir(@as(*const c.git_repository, @ptrCast(self)))) |ret| std.mem.sliceTo(ret, 0) else null;
    }

    pub fn workdirSet(self: *Repository, workdir: [:0]const u8, update_gitlink: bool) !void {
        if (internal.trace_log) log.debug("Repository.workdirSet called", .{});

        try internal.wrapCall("git_repository_set_workdir", .{
            @as(*c.git_repository, @ptrCast(self)),
            workdir.ptr,
            @intFromBool(update_gitlink),
        });
    }

    pub fn commondir(self: *const Repository) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Repository.commondir called", .{});

        return if (c.git_repository_commondir(@as(*const c.git_repository, @ptrCast(self)))) |ret| std.mem.sliceTo(ret, 0) else null;
    }

    /// Get the configuration file for this repository.
    ///
    /// If a configuration file has not been set, the default config set for the repository will be returned, including any global
    /// and system configurations.
    pub fn configGet(self: *Repository) !*git.Config {
        if (internal.trace_log) log.debug("Repository.configGet called", .{});

        var config: *git.Config = undefined;

        try internal.wrapCall("git_repository_config", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return config;
    }

    /// Get a snapshot of the repository's configuration
    ///
    /// The contents of this snapshot will not change, even if the underlying config files are modified.
    pub fn configSnapshot(self: *Repository) !*git.Config {
        if (internal.trace_log) log.debug("Repository.configSnapshot called", .{});

        var config: *git.Config = undefined;

        try internal.wrapCall("git_repository_config_snapshot", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return config;
    }

    pub fn odbGet(self: *Repository) !*git.Odb {
        if (internal.trace_log) log.debug("Repository.odbGet called", .{});

        var odb: *git.Odb = undefined;

        try internal.wrapCall("git_repository_odb", .{
            @as(*?*c.git_odb, @ptrCast(&odb)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return odb;
    }

    pub fn refDb(self: *Repository) !*git.Refdb {
        if (internal.trace_log) log.debug("Repository.refDb called", .{});

        var ref_db: *git.Refdb = undefined;

        try internal.wrapCall("git_repository_refdb", .{
            @as(*?*c.git_refdb, @ptrCast(&ref_db)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ref_db;
    }

    pub fn indexGet(self: *Repository) !*git.Index {
        if (internal.trace_log) log.debug("Repository.indexGet called", .{});

        var index: *git.Index = undefined;

        try internal.wrapCall("git_repository_index", .{
            @as(*?*c.git_index, @ptrCast(&index)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return index;
    }

    /// Retrieve git's prepared message
    ///
    /// Operations such as git revert/cherry-pick/merge with the -n option stop just short of creating a commit with the changes
    /// and save their prepared message in .git/MERGE_MSG so the next git-commit execution can present it to the user for them to
    /// amend if they wish.
    ///
    /// Use this function to get the contents of this file. Don't forget to remove the file after you create the commit.
    pub fn preparedMessage(self: *Repository) !git.Buf {
        if (internal.trace_log) log.debug("Repository.preparedMessage called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_repository_message", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return buf;
    }

    /// Remove git's prepared message file.
    pub fn preparedMessageRemove(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.preparedMessageRemove called", .{});

        try internal.wrapCall("git_repository_message_remove", .{@as(*c.git_repository, @ptrCast(self))});
    }

    /// Remove all the metadata associated with an ongoing command like merge, revert, cherry-pick, etc.
    /// For example: MERGE_HEAD, MERGE_MSG, etc.
    pub fn stateCleanup(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.stateCleanup called", .{});

        try internal.wrapCall("git_repository_state_cleanup", .{@as(*c.git_repository, @ptrCast(self))});
    }

    /// Invoke `callback_fn` for each entry in the given FETCH_HEAD file.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `ref_name` - The reference name
    /// * `remote_url` - The remote URL
    /// * `oid` - The reference OID
    /// * `is_merge` - Was the reference the result of a merge
    pub fn fetchHeadForeach(
        self: *Repository,
        comptime callback_fn: fn (
            ref_name: [:0]const u8,
            remote_url: [:0]const u8,
            oid: *const git.Oid,
            is_merge: bool,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                ref_name: [:0]const u8,
                remote_url: [:0]const u8,
                oid: *const git.Oid,
                is_merge: bool,
                _: *u8,
            ) c_int {
                return callback_fn(ref_name, remote_url, oid, is_merge);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.fetchHeadForeachWithUserData(&dummy_data, cb);
    }

    /// Invoke `callback_fn` for each entry in the given FETCH_HEAD file.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `ref_name` - The reference name
    /// * `remote_url` - The remote URL
    /// * `oid` - The reference OID
    /// * `is_merge` - Was the reference the result of a merge
    /// * `user_data_ptr` - Pointer to user data
    pub fn fetchHeadForeachWithUserData(
        self: *Repository,
        user_data: anytype,
        comptime callback_fn: fn (
            ref_name: [:0]const u8,
            remote_url: [:0]const u8,
            oid: *const git.Oid,
            is_merge: bool,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                c_ref_name: ?[*:0]const u8,
                c_remote_url: ?[*:0]const u8,
                c_oid: ?*const c.git_oid,
                c_is_merge: c_uint,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(c_ref_name.?, 0),
                    std.mem.sliceTo(c_remote_url.?, 0),
                    @as(*const git.Oid, @ptrCast(c_oid)),
                    c_is_merge == 1,
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.fetchHeadForeachWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_repository_fetchhead_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// If a merge is in progress, invoke 'callback' for each commit ID in the MERGE_HEAD file.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `oid` - The merge OID
    pub fn mergeHeadForeach(
        self: *Repository,
        comptime callback_fn: fn (oid: *const git.Oid) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(oid: *const git.Oid, _: *u8) c_int {
                return callback_fn(oid);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.mergeHeadForeachWithUserData(&dummy_data, cb);
    }

    /// If a merge is in progress, invoke 'callback' for each commit ID in the MERGE_HEAD file.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `oid` - The merge OID
    /// * `user_data_ptr` - Pointer to user data
    pub fn mergeHeadForeachWithUserData(
        self: *Repository,
        user_data: anytype,
        comptime callback_fn: fn (
            oid: *const git.Oid,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(c_oid: ?*const c.git_oid, payload: ?*anyopaque) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.Oid, @ptrCast(c_oid)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.mergeHeadForeachWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_repository_mergehead_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Calculate hash of file using repository filtering rules.
    ///
    /// If you simply want to calculate the hash of a file on disk with no filters, you can just use `git.Odb.hashFile`.
    /// However, if you want to hash a file in the repository and you want to apply filtering rules (e.g. crlf filters) before
    /// generating the SHA, then use this function.
    ///
    /// Note: if the repository has `core.safecrlf` set to fail and the filtering triggers that failure, then this function will
    /// return an error and not calculate the hash of the file.
    ///
    /// ## Parameters
    /// * `path` - Path to file on disk whose contents should be hashed. This can be a relative path.
    /// * `object_type` - The object type to hash as (e.g. `ObjectType.blob`)
    /// * `as_path` - The path to use to look up filtering rules. If this is `null`, then the `path` parameter will be used
    ///               instead. If this is passed as the empty string, then no filters will be applied when calculating the hash.
    pub fn hashFile(
        self: *Repository,
        path: [:0]const u8,
        object_type: git.ObjectType,
        as_path: ?[:0]const u8,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.hashFile called", .{});

        var oid: git.Oid = undefined;

        const as_path_temp = if (as_path) |slice| slice.ptr else null;

        try internal.wrapCall("git_repository_hashfile", .{
            @as(*c.git_oid, @ptrCast(&oid)),
            @as(*c.git_repository, @ptrCast(self)),
            path.ptr,
            @intFromEnum(object_type),
            as_path_temp,
        });

        return oid;
    }

    /// Get file status for a single file.
    ///
    /// This tries to get status for the filename that you give. If no files match that name (in either the HEAD, index, or
    /// working directory), this returns `GitError.NotFound`.
    ///
    /// If the name matches multiple files (for example, if the `path` names a directory or if running on a case- insensitive
    /// filesystem and yet the HEAD has two entries that both match the path), then this returns `GitError.Ambiguous`.
    ///
    /// This does not do any sort of rename detection.
    pub fn fileStatus(self: *Repository, path: [:0]const u8) !git.FileStatus {
        if (internal.trace_log) log.debug("Repository.fileStatus called", .{});

        var flags: c_uint = undefined;

        try internal.wrapCall("git_status_file", .{ &flags, @as(*c.git_repository, @ptrCast(self)), path.ptr });

        return @as(git.FileStatus, @bitCast(flags));
    }

    /// Gather file statuses and run a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `path` - The file path
    /// * `status` - The status of the file
    pub fn fileStatusForeach(
        self: *Repository,
        comptime callback_fn: fn (path: [:0]const u8, status: git.FileStatus) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(path: [:0]const u8, status: git.FileStatus, _: *u8) c_int {
                return callback_fn(path, status);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachFileStatusWithUserData(&dummy_data, cb);
    }

    /// Gather file statuses and run a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `path` - The file path
    /// * `status` - The status of the file
    /// * `user_data_ptr` - Pointer to user data
    pub fn fileStatusForeachWithUserData(
        self: *Repository,
        user_data: anytype,
        comptime callback_fn: fn (
            path: [:0]const u8,
            status: git.FileStatus,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(path: ?[*:0]const u8, status: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(path.?, 0),
                    @as(git.FileStatus, @bitCast(status)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.fileStatusForeachWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_status_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Gather file status information and run callbacks as requested.
    ///
    /// This is an extended version of the `foreachFileStatus` function that allows for more granular control over which paths
    /// will be processed. See `FileStatusOptions` for details about the additional options that this makes available.
    ///
    /// Note that if a `pathspec` is given in the `FileStatusOptions` to filter the status, then the results from rename
    /// detection (if you enable it) may not be accurate. To do rename detection properly, this must be called with no `pathspec`
    /// so that all files can be considered.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `options` - Callback options
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `path` - The file path
    /// * `status` - The status of the file
    pub fn fileStatusForeachExtended(
        self: *Repository,
        options: FileStatusOptions,
        comptime callback_fn: fn (path: [:0]const u8, status: git.FileStatus) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(path: [:0]const u8, status: git.FileStatus, _: *u8) c_int {
                return callback_fn(path, status);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachFileStatusExtendedWithUserData(options, &dummy_data, cb);
    }

    /// Gather file status information and run callbacks as requested.
    ///
    /// This is an extended version of the `foreachFileStatus` function that allows for more granular control over which paths
    /// will be processed. See `FileStatusOptions` for details about the additional options that this makes available.
    ///
    /// Note that if a `pathspec` is given in the `FileStatusOptions` to filter the status, then the results from rename
    /// detection (if you enable it) may not be accurate. To do rename detection properly, this must be called with no `pathspec`
    /// so that all files can be considered.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `options` - Callback options
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `path` - The file path
    /// * `status` - The status of the file
    /// * `user_data_ptr` - Pointer to user data
    pub fn fileStatusForeachExtendedWithUserData(
        self: *Repository,
        options: FileStatusOptions,
        user_data: anytype,
        comptime callback_fn: fn (
            path: [:0]const u8,
            status: git.FileStatus,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(path: ?[*:0]const u8, status: c_uint, payload: ?*anyopaque) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(path.?, 0),
                    @as(git.FileStatus, @bitCast(status)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.fileStatusForeachExtendedWithUserData called", .{});

        const c_options = internal.make_c_option.fileStatusOptions(options);

        return try internal.wrapCallWithReturn("git_status_foreach_ext", .{
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
            cb,
            user_data,
        });
    }

    /// Gather file status information and populate a `git.StatusList`.
    ///
    /// Note that if a `pathspec` is given in the `FileStatusOptions` to filter the status, then the results from rename detection
    /// (if you enable it) may not be accurate. To do rename detection properly, this must be called with no `pathspec` so that
    /// all files can be considered.
    ///
    /// ## Parameters
    /// * `options` - Options regarding which files to get the status of
    pub fn statusList(self: *Repository, options: FileStatusOptions) !*git.StatusList {
        if (internal.trace_log) log.debug("Repository.statusList called", .{});

        var status_list: *git.StatusList = undefined;

        const c_options = internal.make_c_option.fileStatusOptions(options);

        try internal.wrapCall("git_status_list_new", .{
            @as(*?*c.git_status_list, @ptrCast(&status_list)),
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
        });

        return status_list;
    }

    /// Test if the ignore rules apply to a given file.
    ///
    /// ## Parameters
    /// * `path` - The file to check ignores for, rooted at the repo's workdir.
    pub fn statusShouldIgnore(self: *Repository, path: [:0]const u8) !bool {
        if (internal.trace_log) log.debug("Repository.statusShouldIgnore called", .{});

        var result: c_int = undefined;

        try internal.wrapCall("git_status_should_ignore", .{ &result, @as(*c.git_repository, @ptrCast(self)), path.ptr });

        return result == 1;
    }

    pub fn annotatedCommitCreateFromFetchHead(
        self: *git.Repository,
        branch_name: [:0]const u8,
        remote_url: [:0]const u8,
        id: *const git.Oid,
    ) !*git.AnnotatedCommit {
        if (internal.trace_log) log.debug("Repository.annotatedCommitCreateFromFetchHead", .{});

        var result: *git.AnnotatedCommit = undefined;

        try internal.wrapCall("git_annotated_commit_from_fetchhead", .{
            @as(*?*c.git_annotated_commit, @ptrCast(&result)),
            @as(*c.git_repository, @ptrCast(self)),
            branch_name.ptr,
            remote_url.ptr,
            @as(*const c.git_oid, @ptrCast(id)),
        });

        return result;
    }

    pub fn annotatedCommitCreateFromLookup(self: *Repository, id: *const git.Oid) !*git.AnnotatedCommit {
        if (internal.trace_log) log.debug("Repository.annotatedCommitCreateFromLookup called", .{});

        var result: *git.AnnotatedCommit = undefined;

        try internal.wrapCall("git_annotated_commit_lookup", .{
            @as(*?*c.git_annotated_commit, @ptrCast(&result)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });

        return result;
    }

    pub fn annotatedCommitCreateFromRevisionString(self: *Repository, revspec: [:0]const u8) !*git.AnnotatedCommit {
        if (internal.trace_log) log.debug("Repository.annotatedCommitCreateFromRevisionString called", .{});

        var result: *git.AnnotatedCommit = undefined;

        try internal.wrapCall("git_annotated_commit_from_revspec", .{
            @as(*?*c.git_annotated_commit, @ptrCast(&result)),
            @as(*c.git_repository, @ptrCast(self)),
            revspec.ptr,
        });

        return result;
    }

    /// Apply a `Diff` to the given repository, making changes directly in the working directory, the index, or both.
    ///
    /// ## Parameters
    /// * `diff` - The diff to apply
    /// * `location` - The location to apply (workdir, index or both)
    /// * `options` - The options for the apply (or null for defaults)
    pub fn applyDiff(
        self: *Repository,
        diff: *git.Diff,
        location: git.ApplyLocation,
        options: git.ApplyOptions,
    ) !void {
        if (internal.trace_log) log.debug("Repository.applyDiff called", .{});

        const c_options = internal.make_c_option.applyOptions(options);

        try internal.wrapCall("git_apply", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_diff, @ptrCast(diff)),
            @intFromEnum(location),
            &c_options,
        });
    }

    /// Apply a `Diff` to the given repository, making changes directly in the working directory, the index, or both.
    ///
    /// ## Parameters
    /// * `diff` - The diff to apply
    /// * `location` - The location to apply (workdir, index or both)
    /// * `user_data` - User data to be passed to callbacks
    /// * `options` - The options for the apply (or null for defaults)
    pub fn applyDiffWithUserData(
        comptime T: type,
        self: *Repository,
        diff: *git.Diff,
        location: git.ApplyLocation,
        options: git.ApplyOptionsWithUserData(T),
    ) !void {
        if (internal.trace_log) log.debug("Repository.applyDiffWithUserData(" ++ @typeName(T) ++ ") called", .{});

        const c_options = internal.make_c_option.applyOptionsWithUserData(T, options);

        try internal.wrapCall("git_apply", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_diff, @ptrCast(diff)),
            @as(c_int, @bitCast(location)),
            &c_options,
        });
    }

    /// Apply a `Diff` to a `Tree`, and return the resulting image as an index.
    ///
    /// ## Parameters
    /// * `diff` - The diff to apply`
    /// * `preimage` - The tree to apply the diff to
    /// * `options` - The options for the apply (or null for defaults)
    pub fn applyDiffToTree(
        self: *Repository,
        diff: *git.Diff,
        preimage: *git.Tree,
        options: git.ApplyOptions,
    ) !*git.Index {
        if (internal.trace_log) log.debug("Repository.applyDiffToTree called", .{});

        var ret: *git.Index = undefined;

        const c_options = internal.make_c_option.applyOptions(options);

        try internal.wrapCall("git_apply_to_tree", .{
            @as(*?*c.git_index, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_tree, @ptrCast(preimage)),
            @as(*c.git_diff, @ptrCast(diff)),
            &c_options,
        });

        return ret;
    }

    /// Apply a `Diff` to a `Tree`, and return the resulting image as an index.
    ///
    /// ## Parameters
    /// * `diff` - The diff to apply`
    /// * `preimage` - The tree to apply the diff to
    /// * `options` - The options for the apply (or null for defaults)
    pub fn applyDiffToTreeWithUserData(
        comptime T: type,
        self: *Repository,
        diff: *git.Diff,
        preimage: *git.Tree,
        options: git.ApplyOptionsWithUserData(T),
    ) !*git.Index {
        if (internal.trace_log) log.debug("Repository.applyDiffToTreeWithUserData(" ++ @typeName(T) ++ ") called", .{});

        var ret: *git.Index = undefined;

        const c_options = internal.make_c_option.applyOptionsWithUserData(T, options);

        try internal.wrapCall("git_apply_to_tree", .{
            @as(*?*c.git_index, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_tree, @ptrCast(preimage)),
            @as(*c.git_diff, @ptrCast(diff)),
            &c_options,
        });

        return ret;
    }

    /// Look up the value of one git attribute for path.
    ///
    /// ## Parameters
    /// * `flags` - Options for fetching attributes
    /// * `path` - The path to check for attributes. Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `name` - The name of the attribute to look up.
    pub fn attribute(self: *Repository, flags: git.AttributeFlags, path: [:0]const u8, name: [:0]const u8) !git.Attribute {
        if (internal.trace_log) log.debug("Repository.attribute called", .{});

        var result: ?[*:0]const u8 = undefined;

        try internal.wrapCall("git_attr_get", .{
            &result,
            @as(*c.git_repository, @ptrCast(self)),
            internal.make_c_option.attributeFlags(flags),
            path.ptr,
            name.ptr,
        });

        return git.Attribute{
            .z_attr = result,
        };
    }

    /// Look up a list of git attributes for path.
    ///
    /// Use this if you have a known list of attributes that you want to look up in a single call. This is somewhat more efficient
    /// than calling `attributeGet` multiple times.
    ///
    /// ## Parameters
    /// * `output_buffer` - Output buffer, *must* be atleast as long as `names`
    /// * `flags` - Options for fetching attributes
    /// * `path` - The path to check for attributes. Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `names` - He names of the attributes to look up.
    pub fn attributeMany(
        self: *Repository,
        output_buffer: [][*:0]const u8,
        flags: git.AttributeFlags,
        path: [:0]const u8,
        names: [][*:0]const u8,
    ) ![]const [*:0]const u8 {
        if (output_buffer.len < names.len) return error.BufferTooShort;

        if (internal.trace_log) log.debug("Repository.attributeMany called", .{});

        try internal.wrapCall("git_attr_get_many", .{
            @as([*]?[*:0]const u8, @ptrCast(output_buffer.ptr)),
            @as(*c.git_repository, @ptrCast(self)),
            internal.make_c_option.attributeFlags(flags),
            path.ptr,
            names.len,
            @as([*]?[*:0]const u8, @ptrCast(names.ptr)),
        });

        return output_buffer[0..names.len];
    }

    /// Invoke `callback_fn` for all the git attributes for a path.
    ///
    ///
    /// ## Parameters
    /// * `flags` - Options for fetching attributes
    /// * `path` - The path to check for attributes. Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `name` - The attribute name
    /// * `value` - The attribute value. May be `null` if the attribute is explicitly set to unspecified using the '!' sign.
    pub fn attributeForeach(
        self: *const Repository,
        flags: git.AttributeFlags,
        path: [:0]const u8,
        comptime callback_fn: fn (
            name: [:0]const u8,
            value: ?[:0]const u8,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(name: [:0]const u8, value: ?[:0]const u8, _: *u8) c_int {
                return callback_fn(name, value);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.attributeForeachWithUserData(flags, path, &dummy_data, cb);
    }

    /// Invoke `callback_fn` for all the git attributes for a path.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `flags` - Options for fetching attributes
    /// * `path` - The path to check for attributes. Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `name` - The attribute name
    /// * `value` - The attribute value. May be `null` if the attribute is explicitly set to unspecified using the '!' sign.
    /// * `user_data_ptr` - Pointer to user data
    pub fn attributeForeachWithUserData(
        self: *const Repository,
        flags: git.AttributeFlags,
        path: [:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (
            name: [:0]const u8,
            value: ?[:0]const u8,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                name: ?[*:0]const u8,
                value: ?[*:0]const u8,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(name.?, 0),
                    if (value) |ptr| std.mem.sliceTo(ptr, 0) else null,
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.attributeForeachWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_attr_foreach", .{
            @as(*const c.git_repository, @ptrCast(self)),
            internal.make_c_option.attributeFlags(flags),
            path.ptr,
            cb,
            user_data,
        });
    }

    pub fn attributeCacheFlush(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.attributeCacheFlush called", .{});

        try internal.wrapCall("git_attr_cache_flush", .{@as(*c.git_repository, @ptrCast(self))});
    }

    pub fn attributeAddMacro(self: *Repository, name: [:0]const u8, values: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.attributeCacheFlush called", .{});

        try internal.wrapCall("git_attr_add_macro", .{ @as(*c.git_repository, @ptrCast(self)), name.ptr, values.ptr });
    }

    pub fn blameFile(self: *Repository, path: [:0]const u8, options: git.BlameOptions) !*git.Blame {
        if (internal.trace_log) log.debug("Repository.blameFile called", .{});

        var blame: *git.Blame = undefined;

        var c_options = internal.make_c_option.blameOptions(options);

        try internal.wrapCall("git_blame_file", .{
            @as(*?*c.git_blame, @ptrCast(&blame)),
            @as(*c.git_repository, @ptrCast(self)),
            path.ptr,
            &c_options,
        });

        return blame;
    }

    pub fn blobLookup(self: *Repository, id: *const git.Oid) !*git.Blob {
        if (internal.trace_log) log.debug("Repository.blobLookup called", .{});

        var blob: *git.Blob = undefined;

        try internal.wrapCall("git_blob_lookup", .{
            @as(*?*c.git_blob, @ptrCast(&blob)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });

        return blob;
    }

    /// Lookup a blob object from a repository, given a prefix of its identifier (short id).
    pub fn blobLookupPrefix(self: *Repository, id: *const git.Oid, len: usize) !*git.Blob {
        if (internal.trace_log) log.debug("Repository.blobLookup called", .{});

        var blob: *git.Blob = undefined;

        try internal.wrapCall("git_blob_lookup_prefix", .{
            @as(*?*c.git_blob, @ptrCast(&blob)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            len,
        });

        return blob;
    }

    /// Create a new branch pointing at a target commit
    ///
    /// A new direct reference will be created pointing to this target commit. If `force` is true and a reference already exists
    /// with the given name, it'll be replaced.
    ///
    /// The returned reference must be freed by the user.
    ///
    /// The branch name will be checked for validity.
    ///
    /// ## Parameters
    /// * `branch_name` - Name for the branch; this name is validated for consistency. It should also not conflict with an already
    /// existing branch name.
    /// * `target` - Commit to which this branch should point. This object must belong to the given `repo`.
    /// * `force` - Overwrite existing branch.
    pub fn branchCreate(self: *Repository, branch_name: [:0]const u8, target: *const git.Commit, force: bool) !*git.Reference {
        if (internal.trace_log) log.debug("Repository.branchCreate called", .{});

        var reference: *git.Reference = undefined;

        try internal.wrapCall("git_branch_create", .{
            @as(*?*c.git_reference, @ptrCast(&reference)),
            @as(*c.git_repository, @ptrCast(self)),
            branch_name.ptr,
            @as(*const c.git_commit, @ptrCast(target)),
            @intFromBool(force),
        });

        return reference;
    }

    /// Create a new branch pointing at a target commit
    ///
    /// This behaves like `branchCreate` but takes an annotated commit, which lets you specify which extended sha syntax string
    /// was specified by a user, allowing for more exact reflog messages.
    ///
    /// ## Parameters
    /// * `branch_name` - Name for the branch; this name is validated for consistency. It should also not conflict with an already
    /// existing branch name.
    /// * `target` - Commit to which this branch should point. This object must belong to the given `repo`.
    /// * `force` - Overwrite existing branch.
    pub fn branchCreateFromAnnotated(
        self: *Repository,
        branch_name: [:0]const u8,
        target: *const git.AnnotatedCommit,
        force: bool,
    ) !*git.Reference {
        if (internal.trace_log) log.debug("Repository.branchCreateFromAnnotated called", .{});

        var reference: *git.Reference = undefined;

        try internal.wrapCall("git_branch_create_from_annotated", .{
            @as(*?*c.git_reference, @ptrCast(&reference)),
            @as(*c.git_repository, @ptrCast(self)),
            branch_name.ptr,
            @as(*const c.git_annotated_commit, @ptrCast(target)),
            @intFromBool(force),
        });

        return reference;
    }

    pub fn iterateBranches(self: *Repository, branch_type: BranchType) !*BranchIterator {
        if (internal.trace_log) log.debug("Repository.iterateBranches called", .{});

        var iterator: *BranchIterator = undefined;

        try internal.wrapCall("git_branch_iterator_new", .{
            @as(*?*c.git_branch_iterator, @ptrCast(&iterator)),
            @as(*c.git_repository, @ptrCast(self)),
            @intFromEnum(branch_type),
        });

        return iterator;
    }

    pub const BranchType = enum(c_uint) {
        local = 1,
        remote = 2,
        all = 3,
    };

    pub const BranchIterator = opaque {
        pub fn next(self: *BranchIterator) !?Item {
            if (internal.trace_log) log.debug("BranchIterator.next called", .{});

            var reference: *git.Reference = undefined;
            var branch_type: c.git_branch_t = undefined;

            internal.wrapCall("git_branch_next", .{
                @as(*?*c.git_reference, @ptrCast(&reference)),
                &branch_type,
                @as(*c.git_branch_iterator, @ptrCast(self)),
            }) catch |err| switch (err) {
                git.GitError.IterOver => return null,
                else => |e| return e,
            };

            return Item{
                .reference = reference,
                .branch_type = @as(BranchType, @enumFromInt(branch_type)),
            };
        }

        pub const Item = struct {
            reference: *git.Reference,
            branch_type: BranchType,
        };

        pub fn deinit(self: *BranchIterator) void {
            if (internal.trace_log) log.debug("BranchIterator.deinit called", .{});

            c.git_branch_iterator_free(@as(*c.git_branch_iterator, @ptrCast(self)));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Lookup a branch by its name in a repository.
    ///
    /// The generated reference must be freed by the user.
    /// The branch name will be checked for validity.
    pub fn branchLookup(self: *Repository, branch_name: [:0]const u8, branch_type: BranchType) !*git.Reference {
        if (internal.trace_log) log.debug("Repository.branchLookup called", .{});

        var ref: *git.Reference = undefined;

        try internal.wrapCall("git_branch_lookup", .{
            @as(*?*c.git_reference, @ptrCast(&ref)),
            @as(*c.git_repository, @ptrCast(self)),
            branch_name.ptr,
            @intFromEnum(branch_type),
        });

        return ref;
    }

    /// Find the remote name of a remote-tracking branch
    ///
    /// This will return the name of the remote whose fetch refspec is matching the given branch. E.g. given a branch
    /// "refs/remotes/test/master", it will extract the "test" part. If refspecs from multiple remotes match, the function will
    /// return `GitError.Ambiguous`.
    pub fn remoteGetName(self: *Repository, refname: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Repository.remoteGetName called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_branch_remote_name", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_repository, @ptrCast(self)),
            refname.ptr,
        });

        return buf;
    }

    /// Retrieve the upstream remote of a local branch
    ///
    /// This will return the currently configured "branch.*.remote" for a given branch. This branch must be local.
    pub fn remoteUpstreamRemote(self: *Repository, refname: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Repository.remoteUpstreamRemote called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_branch_upstream_remote", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_repository, @ptrCast(self)),
            refname.ptr,
        });

        return buf;
    }

    /// Get the upstream name of a branch
    ///
    /// Given a local branch, this will return its remote-tracking branch information, as a full reference name, ie.
    /// "feature/nice" would become "refs/remote/origin/feature/nice", depending on that branch's configuration.
    pub fn upstreamGetName(self: *Repository, refname: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Repository.upstreamGetName called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_branch_upstream_name", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_repository, @ptrCast(self)),
            refname.ptr,
        });

        return buf;
    }

    /// Updates files in the index and the working tree to match the content of the commit pointed at by HEAD.
    ///
    /// Note that this is _not_ the correct mechanism used to switch branches; do not change your `HEAD` and then call this
    /// method, that would leave you with checkout conflicts since your working directory would then appear to be dirty.
    /// Instead, checkout the target of the branch and then update `HEAD` using `git_repository_set_head` to point to the branch
    /// you checked out.
    ///
    /// Returns a non-zero value is the `notify_cb` callback returns non-zero.
    pub fn checkoutHead(self: *Repository, options: CheckoutOptions) !c_uint {
        if (internal.trace_log) log.debug("Repository.checkoutHead called", .{});

        const c_options = internal.make_c_option.checkoutOptions(options);

        return @as(
            c_uint,
            @intCast(try internal.wrapCallWithReturn("git_checkout_head", .{
                @as(*c.git_repository, @ptrCast(self)),
                &c_options,
            })),
        );
    }

    /// Updates files in the working tree to match the content of the index.
    ///
    /// Returns a non-zero value is the `notify_cb` callback returns non-zero.
    pub fn checkoutIndex(self: *Repository, index: *git.Index, options: CheckoutOptions) !c_uint {
        if (internal.trace_log) log.debug("Repository.checkoutHead called", .{});

        const c_options = internal.make_c_option.checkoutOptions(options);

        return @as(
            c_uint,
            @intCast(try internal.wrapCallWithReturn("git_checkout_index", .{
                @as(*c.git_repository, @ptrCast(self)),
                @as(*c.git_index, @ptrCast(index)),
                &c_options,
            })),
        );
    }

    /// Updates files in the working tree to match the content of the index.
    ///
    /// Returns a non-zero value is the `notify_cb` callback returns non-zero.
    pub fn checkoutTree(self: *Repository, treeish: *const git.Object, options: CheckoutOptions) !c_uint {
        if (internal.trace_log) log.debug("Repository.checkoutHead called", .{});

        const c_option = internal.make_c_option.checkoutOptions(options);

        return @as(
            c_uint,
            @intCast(try internal.wrapCallWithReturn("git_checkout_tree", .{
                @as(*c.git_repository, @ptrCast(self)),
                @as(*const c.git_object, @ptrCast(treeish)),
                &c_option,
            })),
        );
    }

    pub fn cherrypickCommit(
        self: *Repository,
        cherrypick_commit: *git.Commit,
        our_commit: *git.Commit,
        mainline: bool,
        options: git.MergeOptions,
    ) !*git.Index {
        if (internal.trace_log) log.debug("Repository.cherrypickCommit called", .{});

        var index: *git.Index = undefined;

        const c_options = internal.make_c_option.mergeOptions(options);

        try internal.wrapCall("git_cherrypick_commit", .{
            @as(*?*c.git_index, @ptrCast(&index)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(cherrypick_commit)),
            @as(*c.git_commit, @ptrCast(our_commit)),
            @intFromBool(mainline),
            &c_options,
        });

        return index;
    }

    pub fn cherrypick(
        self: *Repository,
        commit: *git.Commit,
        options: CherrypickOptions,
    ) !void {
        if (internal.trace_log) log.debug("Repository.cherrypick called", .{});

        const c_options = internal.make_c_option.cherrypickOptions(options);

        try internal.wrapCall("git_cherrypick", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(commit)),
            &c_options,
        });
    }

    /// Lookup a commit object from a repository.
    pub fn commitLookup(self: *Repository, oid: *const git.Oid) !*git.Commit {
        if (internal.trace_log) log.debug("Repository.commitLookup called", .{});

        var commit: *git.Commit = undefined;

        try internal.wrapCall("git_commit_lookup", .{
            @as(*?*c.git_commit, @ptrCast(&commit)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(oid)),
        });

        return commit;
    }

    /// Lookup a commit object from a repository, given a prefix of its identifier (short id).
    pub fn commitLookupPrefix(self: *Repository, oid: *const git.Oid, size: usize) !*git.Commit {
        if (internal.trace_log) log.debug("Repository.commitLookupPrefix called", .{});

        var commit: *git.Commit = undefined;

        try internal.wrapCall("git_commit_lookup_prefix", .{
            @as(*?*c.git_commit, @ptrCast(&commit)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(oid)),
            size,
        });

        return commit;
    }

    pub fn commitExtractSignature(self: *Repository, commit: *git.Oid, field: ?[:0]const u8) !ExtractSignatureResult {
        if (internal.trace_log) log.debug("Repository.commitExtractSignature called", .{});

        var result: ExtractSignatureResult = .{};

        const field_temp = if (field) |slice| slice.ptr else null;

        try internal.wrapCall("git_commit_extract_signature", .{
            @as(*c.git_buf, @ptrCast(&result.signature)),
            @as(*c.git_buf, @ptrCast(&result.signed_data)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_oid, @ptrCast(commit)),
            field_temp,
        });

        return result;
    }

    pub const ExtractSignatureResult = struct {
        signature: git.Buf = .{},
        signed_data: git.Buf = .{},
    };

    pub fn commitCreate(
        self: *Repository,
        update_ref: ?[:0]const u8,
        author: *const git.Signature,
        committer: *const git.Signature,
        message_encoding: ?[:0]const u8,
        message: [:0]const u8,
        tree: *const git.Tree,
        parents: []*const git.Commit,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.commitCreate called", .{});

        var ret: git.Oid = undefined;

        const update_ref_temp = if (update_ref) |slice| slice.ptr else null;
        const encoding_temp = if (message_encoding) |slice| slice.ptr else null;

        try internal.wrapCall("git_commit_create", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            update_ref_temp,
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(committer)),
            encoding_temp,
            message.ptr,
            @as(*const c.git_tree, @ptrCast(tree)),
            parents.len,
            @as(?[*]?*const c.git_commit, @ptrCast(parents.ptr)),
        });

        return ret;
    }

    pub fn commitCreateBuffer(
        self: *Repository,
        author: *const git.Signature,
        committer: *const git.Signature,
        message_encoding: ?[:0]const u8,
        message: [:0]const u8,
        tree: *const git.Tree,
        parents: []*const git.Commit,
    ) !git.Buf {
        if (internal.trace_log) log.debug("Repository.commitCreateBuffer called", .{});

        var ret: git.Buf = .{};

        const encoding_temp = if (message_encoding) |slice| slice.ptr else null;

        try internal.wrapCall("git_commit_create_buffer", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(committer)),
            encoding_temp,
            message.ptr,
            @as(*const c.git_tree, @ptrCast(tree)),
            parents.len,
            @as(?[*]?*const c.git_commit, @ptrCast(parents.ptr)),
        });

        return ret;
    }

    pub fn commitCreateWithSignature(
        self: *Repository,
        commit_content: [:0]const u8,
        signature: ?[:0]const u8,
        signature_field: ?[:0]const u8,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.commitCreateWithSignature called", .{});

        var ret: git.Oid = undefined;

        const signature_temp = if (signature) |slice| slice.ptr else null;
        const signature_field_temp = if (signature_field) |slice| slice.ptr else null;

        try internal.wrapCall("git_commit_create_with_signature", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            commit_content.ptr,
            signature_temp,
            signature_field_temp,
        });

        return ret;
    }

    /// Create a new mailmap instance from a repository, loading mailmap files based on the repository's configuration.
    ///
    /// Mailmaps are loaded in the following order:
    ///  1. '.mailmap' in the root of the repository's working directory, if present.
    ///  2. The blob object identified by the 'mailmap.blob' config entry, if set.
    /// 	   [NOTE: 'mailmap.blob' defaults to 'HEAD:.mailmap' in bare repositories]
    ///  3. The path in the 'mailmap.file' config entry, if set.
    pub fn mailmapFromRepo(self: *Repository) !*git.Mailmap {
        if (internal.trace_log) log.debug("Repository.mailmapFromRepo called", .{});

        var mailmap: *git.Mailmap = undefined;

        try internal.wrapCall("git_mailmap_from_repository", .{
            @as(*?*c.git_mailmap, @ptrCast(&mailmap)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return mailmap;
    }

    /// Load the filter list for a given path.
    ///
    /// This will return null if no filters are requested for the given file.
    ///
    /// ## Parameters
    /// * `blob` - The blob to which the filter will be applied (if known)
    /// * `path` - Relative path of the file to be filtered
    /// * `mode` - Filtering direction (WT->ODB or ODB->WT)
    /// * `flags` - Filter flags
    pub fn filterListLoad(
        self: *Repository,
        blob: ?*git.Blob,
        path: [:0]const u8,
        mode: git.FilterMode,
        flags: git.FilterFlags,
    ) !?*git.FilterList {
        if (internal.trace_log) log.debug("Repository.filterListLoad called", .{});

        var opt: ?*git.FilterList = undefined;

        try internal.wrapCall("git_filter_list_load", .{
            @as(*?*c.git_filter_list, @ptrCast(&opt)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*c.git_blob, @ptrCast(blob)),
            path.ptr,
            @intFromEnum(mode),
            @as(c_uint, @bitCast(flags)),
        });

        return opt;
    }

    /// Count the number of unique commits between two commit objects
    ///
    /// There is no need for branches containing the commits to have any upstream relationship, but it helps to think of one as a
    // branch and the other as its upstream, the `ahead` and `behind` values will be what git would report for the branches.
    ///
    /// ## Parameters
    /// * `local` - The commit for local
    /// * `upstream` - The commit for upstream
    pub fn graphAheadBehind(
        self: *Repository,
        local: *const git.Oid,
        upstream: *const git.Oid,
    ) !GraphAheadBehindResult {
        if (internal.trace_log) log.debug("Repository.graphAheadBehind called", .{});

        var ret: GraphAheadBehindResult = undefined;

        try internal.wrapCall("git_graph_ahead_behind", .{
            &ret.ahead,
            &ret.behind,
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(local)),
            @as(*const c.git_oid, @ptrCast(upstream)),
        });

        return ret;
    }

    pub const GraphAheadBehindResult = struct { ahead: usize, behind: usize };

    /// Determine if a commit is the descendant of another commit.
    ///
    /// Note that a commit is not considered a descendant of itself, in contrast to `git merge-base --is-ancestor`.
    ///
    /// ## Parameters
    /// * `commit` - A previously loaded commit
    /// * `ancestor` - A potential ancestor commit
    pub fn graphDecendantOf(self: *Repository, commit: *const git.Oid, ancestor: *const git.Oid) !bool {
        if (internal.trace_log) log.debug("Repository.graphDecendantOf called", .{});

        return (try internal.wrapCallWithReturn("git_graph_descendant_of", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(commit)),
            @as(*const c.git_oid, @ptrCast(ancestor)),
        })) != 0;
    }

    /// Add ignore rules for a repository.
    ///
    /// Excludesfile rules (i.e. .gitignore rules) are generally read from .gitignore files in the repository tree or from a
    /// shared system file only if a "core.excludesfile" config value is set. The library also keeps a set of per-repository
    /// internal ignores that can be configured in-memory and will not persist. This function allows you to add to that internal
    /// rules list.
    ///
    /// Example usage:
    /// ```zig
    /// try repo.ignoreAddRule("*.c\ndir/\nFile with space\n");
    /// ```
    ///
    /// This would add three rules to the ignores.
    ///
    /// ## Parameters
    /// * `rules` - Text of rules, a la the contents of a .gitignore file. It is okay to have multiple rules in the text; if so,
    ///             each rule should be terminated with a newline.
    pub fn ignoreAddRule(self: *Repository, rules: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.ignoreAddRule called", .{});

        try internal.wrapCall("git_ignore_add_rule", .{ @as(*c.git_repository, @ptrCast(self)), rules.ptr });
    }

    /// Clear ignore rules that were explicitly added.
    ///
    /// Resets to the default internal ignore rules.  This will not turn off
    /// rules in .gitignore files that actually exist in the filesystem.
    ///
    /// The default internal ignores ignore ".", ".." and ".git" entries.
    pub fn ignoreClearRules(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.git_ignore_clear_internal_rules called", .{});

        try internal.wrapCall("git_ignore_clear_internal_rules", .{@as(*c.git_repository, @ptrCast(self))});
    }

    /// Test if the ignore rules apply to a given path.
    ///
    /// This function checks the ignore rules to see if they would apply to the given file. This indicates if the file would be
    /// ignored regardless of whether the file is already in the index or committed to the repository.
    ///
    /// One way to think of this is if you were to do "git check-ignore --no-index" on the given file, would it be shown or not?
    ///
    /// ## Parameters
    /// * `path` - The file to check ignores for, relative to the repo's workdir.
    pub fn ignorePathIsIgnored(self: *Repository, path: [:0]const u8) !bool {
        if (internal.trace_log) log.debug("Repository.ignorePathIsIgnored called", .{});

        var ignored: c_int = undefined;

        try internal.wrapCall("git_ignore_path_is_ignored", .{
            &ignored,
            @as(*c.git_repository, @ptrCast(self)),
            path.ptr,
        });

        return ignored != 0;
    }

    /// Load the filter list for a given path.
    ///
    /// This will return null if no filters are requested for the given file.
    ///
    /// ## Parameters
    /// * `blob` - The blob to which the filter will be applied (if known)
    /// * `path` - Relative path of the file to be filtered
    /// * `mode` - Filtering direction (WT->ODB or ODB->WT)
    /// * `options` - Filter options
    pub fn filterListLoadExtended(
        self: *Repository,
        blob: ?*git.Blob,
        path: [:0]const u8,
        mode: git.FilterMode,
        options: git.FilterOptions,
    ) !?*git.FilterList {
        if (internal.trace_log) log.debug("Repository.filterListLoad called", .{});

        var opt: ?*git.FilterList = undefined;

        var c_options = internal.make_c_option.filterOptions(options);

        try internal.wrapCall("git_filter_list_load_ext", .{
            @as(*?*c.git_filter_list, @ptrCast(&opt)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*c.git_blob, @ptrCast(blob)),
            path.ptr,
            @intFromEnum(mode),
            &c_options,
        });

        return opt;
    }

    /// Determine if a commit is reachable from any of a list of commits by following parent edges.
    ///
    /// ## Parameters
    /// * `commit` - A previously loaded commit
    /// * `decendants` - Oids of the commits
    pub fn graphReachableFromAny(
        self: *Repository,
        commit: *const git.Oid,
        decendants: []const git.Oid,
    ) !bool {
        if (internal.trace_log) log.debug("Repository.graphReachableFromAny called", .{});

        return (try internal.wrapCallWithReturn("git_graph_reachable_from_any", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(commit)),
            @as([*]const c.git_oid, @ptrCast(decendants.ptr)),
            decendants.len,
        })) != 0;
    }

    /// Retrieve the upstream merge of a local branch
    ///
    /// This will return the currently configured "branch.*.remote" for a given branch. This branch must be local.
    pub fn remoteUpstreamMerge(self: *Repository, refname: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Repository.remoteUpstreamMerge called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_branch_upstream_merge", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_repository, @ptrCast(self)),
            refname.ptr,
        });

        return buf;
    }

    /// Look up the value of one git attribute for path with extended options.
    ///
    /// ## Parameters
    /// * `options` - Options for fetching attributes
    /// * `path` - The path to check for attributes.  Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `name` - The name of the attribute to look up.
    pub fn attributeExtended(
        self: *Repository,
        options: git.AttributeOptions,
        path: [:0]const u8,
        name: [:0]const u8,
    ) !git.Attribute {
        if (internal.trace_log) log.debug("Repository.attributeExtended called", .{});

        var c_options = internal.make_c_option.attributeOptions(options);

        var result: ?[*:0]const u8 = undefined;

        try internal.wrapCall("git_attr_get_ext", .{
            &result,
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
            path.ptr,
            name.ptr,
        });

        return git.Attribute{
            .z_attr = result,
        };
    }

    /// Look up a list of git attributes for path with extended options.
    ///
    /// Use this if you have a known list of attributes that you want to look up in a single call. This is somewhat more efficient
    /// than calling `attributeGet` multiple times.
    ///
    /// ## Parameters
    /// * `output_buffer` - Output buffer, *must* be atleast as long as `names`
    /// * `options` - Options for fetching attributes
    /// * `path` - The path to check for attributes.  Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `names` - The names of the attributes to look up.
    pub fn attributeManyExtended(
        self: *Repository,
        output_buffer: [][*:0]const u8,
        options: git.AttributeOptions,
        path: [:0]const u8,
        names: [][*:0]const u8,
    ) ![]const [*:0]const u8 {
        if (output_buffer.len < names.len) return error.BufferTooShort;

        if (internal.trace_log) log.debug("Repository.attributeManyExtended called", .{});

        var c_options = internal.make_c_option.attributeOptions(options);

        try internal.wrapCall("git_attr_get_many_ext", .{
            @as([*]?[*:0]const u8, @ptrCast(output_buffer.ptr)),
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
            path.ptr,
            names.len,
            @as([*]?[*:0]const u8, @ptrCast(names.ptr)),
        });

        return output_buffer[0..names.len];
    }

    /// Invoke `callback_fn` for all the git attributes for a path with extended options.
    ///
    ///
    /// ## Parameters
    /// * `options` - Options for fetching attributes
    /// * `path` - The path to check for attributes.  Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `name` - The attribute name
    /// * `value` - The attribute value. May be `null` if the attribute is explicitly set to unspecified using the '!' sign.
    pub fn attributeForeachExtended(
        self: *const Repository,
        options: git.AttributeOptions,
        path: [:0]const u8,
        comptime callback_fn: fn (
            name: [:0]const u8,
            value: ?[:0]const u8,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(name: [:0]const u8, value: ?[:0]const u8, _: *u8) c_int {
                return callback_fn(name, value);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.attributeForeachExtendedWithUserData(options, path, &dummy_data, cb);
    }

    /// Invoke `callback_fn` for all the git attributes for a path with extended options.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `options` - Options for fetching attributes
    /// * `path` - The path to check for attributes.  Relative paths are interpreted relative to the repo root. The file does not
    /// have to exist, but if it does not, then it will be treated as a plain file (not a directory).
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `name` - The attribute name
    /// * `value` - The attribute value. May be `null` if the attribute is explicitly set to unspecified using the '!' sign.
    /// * `user_data_ptr` - Pointer to user data
    pub fn attributeForeachExtendedWithUserData(
        self: *const Repository,
        options: git.AttributeOptions,
        path: [:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (
            name: [:0]const u8,
            value: ?[:0]const u8,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                name: ?[*:0]const u8,
                value: ?[*:0]const u8,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(name.?, 0),
                    if (value) |ptr| std.mem.sliceTo(ptr, 0) else null,
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.attributeForeachWithUserData called", .{});

        const c_options = internal.make_c_option.attributeOptions(options);

        return try internal.wrapCallWithReturn("git_attr_foreach_ext", .{
            @as(*const c.git_repository, @ptrCast(self)),
            &c_options,
            path.ptr,
            cb,
            user_data,
        });
    }

    /// Read a file from the filesystem and write its content to the Object Database as a loose blob
    pub fn blobFromBuffer(self: *Repository, buffer: []const u8) !git.Oid {
        if (internal.trace_log) log.debug("Repository.blobFromBuffer called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_blob_create_from_buffer", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            buffer.ptr,
            buffer.len,
        });

        return ret;
    }

    /// Create a stream to write a new blob into the object db
    ///
    /// This function may need to buffer the data on disk and will in general not be the right choice if you know the size of the
    /// data to write. If you have data in memory, use `blobFromBuffer()`. If you do not, but know the size of the contents
    /// (and don't want/need to perform filtering), use `Odb.openWriteStream()`.
    ///
    /// Don't close this stream yourself but pass it to `WriteStream.commit()` to commit the write to the object db and get the
    /// object id.
    ///
    /// If the `hintpath` parameter is filled, it will be used to determine what git filters should be applied to the object
    /// before it is written to the object database.
    pub fn blobFromStream(self: *Repository, hint_path: ?[:0]const u8) !*git.WriteStream {
        if (internal.trace_log) log.debug("Repository.blobFromDisk called", .{});

        var write_stream: *git.WriteStream = undefined;

        const hint_path_c = if (hint_path) |ptr| ptr.ptr else null;

        try internal.wrapCall("git_blob_create_from_stream", .{
            @as(*?*c.git_writestream, @ptrCast(&write_stream)),
            @as(*c.git_repository, @ptrCast(self)),
            hint_path_c,
        });

        return write_stream;
    }

    /// Read a file from the filesystem and write its content to the Object Database as a loose blob
    pub fn blobFromDisk(self: *Repository, path: [:0]const u8) !git.Oid {
        if (internal.trace_log) log.debug("Repository.blobFromDisk called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_blob_create_from_disk", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            path.ptr,
        });

        return ret;
    }

    /// Read a file from the working folder of a repository and write it to the Object Database as a loose blob
    pub fn blobFromWorkdir(self: *Repository, relative_path: [:0]const u8) !git.Oid {
        if (internal.trace_log) log.debug("Repository.blobFromWorkdir called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_blob_create_from_workdir", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            relative_path.ptr,
        });

        return ret;
    }

    /// List names of linked working trees
    ///
    /// The returned list needs to be `deinit`-ed
    pub fn worktreeList(self: *Repository) !git.StrArray {
        if (internal.trace_log) log.debug("Repository.worktreeList called", .{});

        var ret: git.StrArray = .{};

        try internal.wrapCall("git_worktree_list", .{
            @as(*c.git_strarray, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Lookup a working tree by its name for a given repository
    pub fn worktreeByName(self: *Repository, name: [:0]const u8) !*git.Worktree {
        if (internal.trace_log) log.debug("Repository.worktreeByName called", .{});

        var ret: *git.Worktree = undefined;

        try internal.wrapCall("git_worktree_lookup", .{
            @as(*?*c.git_worktree, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });

        return ret;
    }

    /// Open a worktree of a given repository
    ///
    /// If a repository is not the main tree but a worktree, this function will look up the worktree inside the parent
    /// repository and create a new `git.Worktree` structure.
    pub fn worktreeOpenFromRepository(self: *Repository) !*git.Worktree {
        if (internal.trace_log) log.debug("Repository.worktreeOpenFromRepository called", .{});

        var ret: *git.Worktree = undefined;

        try internal.wrapCall("git_worktree_open_from_repository", .{
            @as(*?*c.git_worktree, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Add a new working tree
    ///
    /// Add a new working tree for the repository, that is create the required data structures inside the repository and
    /// check out the current HEAD at `path`
    ///
    /// ## Parameters
    /// * `name` - Name of the working tree
    /// * `path` - Path to create working tree at
    /// * `options` - Options to modify default behavior.
    pub fn worktreeAdd(self: *Repository, name: [:0]const u8, path: [:0]const u8, options: git.WorktreeAddOptions) !*git.Worktree {
        if (internal.trace_log) log.debug("Repository.worktreeAdd called", .{});

        var ret: *git.Worktree = undefined;

        const c_options = internal.make_c_option.worktreeAddOptions(options);

        try internal.wrapCall("git_worktree_add", .{
            @as(*?*c.git_worktree, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
            path.ptr,
            &c_options,
        });

        return ret;
    }

    /// Lookup a tree object from the repository.
    ///
    /// ## Parameters
    /// * `id` - Identity of the tree to locate.
    pub fn treeLookup(self: *Repository, id: *const git.Oid) !*git.Tree {
        if (internal.trace_log) log.debug("Repository.treeLookup called", .{});

        var ret: *git.Tree = undefined;

        try internal.wrapCall("git_tree_lookup", .{
            @as(*?*c.git_tree, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });

        return ret;
    }

    /// Lookup a tree object from the repository, given a prefix of its identifier (short id).
    ///
    /// ## Parameters
    /// * `id` - Identity of the tree to locate.
    /// * `len` - The length of the short identifier
    pub fn treeLookupPrefix(self: *Repository, id: *const git.Oid, len: usize) !*git.Tree {
        if (internal.trace_log) log.debug("Repository.treeLookupPrefix", .{});

        var ret: *git.Tree = undefined;

        try internal.wrapCall("git_tree_lookup_prefix", .{
            @as(*?*c.git_tree, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            len,
        });

        return ret;
    }

    /// Convert a tree entry to the git_object it points to.
    ///
    /// You must call `git.Object.deint` on the object when you are done with it.
    pub fn treeEntrytoObject(self: *Repository, entry: *const git.TreeEntry) !*git.Object {
        if (internal.trace_log) log.debug("Repository.treeEntrytoObject called", .{});

        var ret: *git.Object = undefined;

        try internal.wrapCall("git_tree_entry_to_object", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_tree_entry, @ptrCast(entry)),
        });

        return ret;
    }

    /// Create a new tree builder.
    ///
    /// The tree builder can be used to create or modify trees in memory and write them as tree objects to the database.
    ///
    /// If the `source` parameter is not `null`, the tree builder will be initialized with the entries of the given tree.
    ///
    /// If the `source` parameter is `null`, the tree builder will start with no entries and will have to be filled manually.
    pub fn treebuilderNew(self: *Repository, source: ?*const git.Tree) !*git.TreeBuilder {
        if (internal.trace_log) log.debug("Repository.treebuilderNew called", .{});

        var ret: *git.TreeBuilder = undefined;

        try internal.wrapCall("git_treebuilder_new", .{
            @as(*?*c.git_treebuilder, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*const c.git_tree, @ptrCast(source)),
        });

        return ret;
    }

    pub const TreeUpdateAction = extern struct {
        /// Update action. If it's an removal, only the path is looked at
        action: Action,
        /// The entry's id
        id: git.Oid,
        /// The filemode/kind of object
        filemode: git.FileMode,
        // The full path from the root tree
        path: [*:0]const u8,

        pub const Action = enum(c_uint) {
            /// Update or insert an entry at the specified path
            upsert = 0,
            /// Remove an entry from the specified path
            remove = 1,
        };

        test {
            try std.testing.expectEqual(@sizeOf(c.git_tree_update), @sizeOf(TreeUpdateAction));
            try std.testing.expectEqual(@bitSizeOf(c.git_tree_update), @bitSizeOf(TreeUpdateAction));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Create a tree based on another one with the specified modifications
    ///
    /// Given the `baseline` perform the changes described in the list of `updates` and create a new tree.
    ///
    /// This function is optimized for common file/directory addition, removal and replacement in trees.
    /// It is much more efficient than reading the tree into a `git.Index` and modifying that, but in exchange it is not as
    /// flexible.
    ///
    /// Deleting and adding the same entry is undefined behaviour, changing a tree to a blob or viceversa is not supported.
    ///
    /// ## Parameters
    /// * `baseline` - The tree to base these changes on, must be the repository `baseline` is in
    /// * `updates` - The updates to perform
    pub fn createUpdatedTree(self: *Repository, baseline: *git.Tree, updates: []const TreeUpdateAction) !git.Oid {
        if (internal.trace_log) log.debug("Repository.createUpdatedTree called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_tree_create_updated", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_tree, @ptrCast(baseline)),
            updates.len,
            @as([*]const c.git_tree_update, @ptrCast(updates.ptr)),
        });

        return ret;
    }

    /// Creates a new iterator for notes
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    pub fn noteIterator(self: *Repository, notes_ref: ?[:0]const u8) !*git.NoteIterator {
        if (internal.trace_log) log.debug("Repository.noteIterator called", .{});

        var ret: *git.NoteIterator = undefined;

        const c_notes = if (notes_ref) |p| p.ptr else null;

        try internal.wrapCall("git_note_iterator_new", .{
            @as(*?*c.git_note_iterator, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            c_notes,
        });

        return ret;
    }

    /// Read the note for an object
    ///
    /// ## Parameters
    /// * `oid` - OID of the git object to read the note from
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    pub fn noteRead(self: *Repository, oid: *const git.Oid, notes_ref: ?[:0]const u8) !*git.Note {
        if (internal.trace_log) log.debug("Repository.noteRead called", .{});

        var ret: *git.Note = undefined;

        const c_notes = if (notes_ref) |p| p.ptr else null;

        try internal.wrapCall("git_note_read", .{
            @as(*?*c.git_note, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            c_notes,
            @as(*const c.git_oid, @ptrCast(oid)),
        });

        return ret;
    }

    /// Read the note for an object
    ///
    /// ## Parameters
    /// * `oid` - OID of the git object to read the note from
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    pub fn noteReadFromNoteCommit(self: *Repository, oid: *const git.Oid, note_commit: *git.Commit) !*git.Note {
        if (internal.trace_log) log.debug("Repository.noteReadFromNoteCommit called", .{});

        var ret: *git.Note = undefined;

        try internal.wrapCall("git_note_commit_read", .{
            @as(*?*c.git_note, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(note_commit)),
            @as(*const c.git_oid, @ptrCast(oid)),
        });

        return ret;
    }

    /// Add a note for an object
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `author` - Signature of the notes commit author
    /// * `commiter` - Signature of the notes commit committer
    /// * `oid` - OID of the git object to decorate
    /// * `note` - Content of the note to add for object oid
    /// * `force` - Overwrite existing note
    pub fn noteCreate(
        self: *Repository,
        notes_ref: ?[:0]const u8,
        author: *const git.Signature,
        commiter: *const git.Signature,
        oid: *const git.Oid,
        note: [:0]const u8,
        force: bool,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.noteCreate called", .{});

        var ret: git.Oid = undefined;

        const c_notes = if (notes_ref) |p| p.ptr else null;

        try internal.wrapCall("git_note_create", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            c_notes,
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(commiter)),
            @as(*const c.git_oid, @ptrCast(oid)),
            note.ptr,
            @intFromBool(force),
        });

        return ret;
    }

    pub const NoteCommitResult = struct {
        note_commit: git.Oid,
        note_blob: git.Oid,
    };

    /// Add a note for an object from a commit
    ///
    /// This function will create a notes commit for a given object, the commit is a dangling commit, no reference is created.
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `author` - Signature of the notes commit author
    /// * `commiter` - Signature of the notes commit committer
    /// * `oid` - OID of the git object to decorate
    /// * `note` - Content of the note to add for object oid
    /// * `allow_note_overwrite` - Overwrite existing note
    pub fn noteCommitCreate(
        self: *Repository,
        parent: *git.Commit,
        author: *const git.Signature,
        commiter: *const git.Signature,
        oid: *const git.Oid,
        note: [:0]const u8,
        allow_note_overwrite: bool,
    ) !NoteCommitResult {
        if (internal.trace_log) log.debug("Repository.noteCommitCreate called", .{});

        var ret: NoteCommitResult = undefined;

        try internal.wrapCall("git_note_commit_create", .{
            @as(*c.git_oid, @ptrCast(&ret.note_commit)),
            @as(*c.git_oid, @ptrCast(&ret.note_blob)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(parent)),
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(commiter)),
            @as(*const c.git_oid, @ptrCast(oid)),
            note.ptr,
            @intFromBool(allow_note_overwrite),
        });

        return ret;
    }

    /// Remove the note for an object
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `author` - Signature of the notes commit author
    /// * `commiter` - Signature of the notes commit committer
    /// * `oid` - OID of the git object to remove the note from
    pub fn noteRemove(
        self: *Repository,
        notes_ref: ?[:0]const u8,
        author: *const git.Signature,
        commiter: *const git.Signature,
        oid: *const git.Oid,
    ) !void {
        if (internal.trace_log) log.debug("Repository.noteRemove called", .{});

        const c_notes = if (notes_ref) |p| p.ptr else null;

        try internal.wrapCall("git_note_remove", .{
            @as(*c.git_repository, @ptrCast(self)),
            c_notes,
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(commiter)),
            @as(*const c.git_oid, @ptrCast(oid)),
        });
    }

    /// Remove the note for an object
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `author` - Signature of the notes commit author
    /// * `commiter` - Signature of the notes commit committer
    /// * `oid` - OID of the git object to remove the note from
    pub fn noteCommitRemove(
        self: *Repository,
        note_commit: *git.Commit,
        author: *const git.Signature,
        commiter: *const git.Signature,
        oid: *const git.Oid,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.noteCommitRemove called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_note_commit_remove", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(note_commit)),
            @as(*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(commiter)),
            @as(*const c.git_oid, @ptrCast(oid)),
        });

        return ret;
    }

    /// Get the default notes reference for a repository
    pub fn noteDefaultRef(self: *Repository) !git.Buf {
        if (internal.trace_log) log.debug("Repository.noteDefaultRef called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_note_default_ref", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Loop over all the notes within a specified namespace and issue a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `blob_id` - Oid of the blob containing the message
    /// * `annotated_object_id` - Oid of the git object being annotated
    pub fn noteForeach(
        self: *Repository,
        notes_ref: ?[:0]const u8,
        comptime callback_fn: fn (
            blob_id: *const git.Oid,
            annotated_object_id: *const git.Oid,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                blob_id: *const git.Oid,
                annotated_object_id: *const git.Oid,
                _: *u8,
            ) c_int {
                return callback_fn(blob_id, annotated_object_id);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.noteForeachWithUserData(&dummy_data, notes_ref, cb);
    }

    /// Loop over all the notes within a specified namespace and issue a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `notes_ref` - Canonical name of the reference to use; if `null` defaults to "refs/notes/commits"
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `blob_id` - Oid of the blob containing the message
    /// * `annotated_object_id` - Oid of the git object being annotated
    /// * `user_data_ptr` - Pointer to user data
    pub fn noteForeachWithUserData(
        self: *Repository,
        notes_ref: ?[:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (
            blob_id: *const git.Oid,
            annotated_object_id: *const git.Oid,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                blob_id: *const c.git_oid,
                annotated_object_id: *const c.git_oid,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.Oid, @ptrCast(blob_id)),
                    @as(*const git.Oid, @ptrCast(annotated_object_id)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.noteForeachWithUserData called", .{});

        const c_notes = if (notes_ref) |p| p.ptr else null;

        return try internal.wrapCallWithReturn("git_note_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            c_notes,
            cb,
            user_data,
        });
    }

    /// Lookup a reference to one of the objects in a repository.
    ///
    /// The generated reference is owned by the repository and should be closed with `git.Object.deinit`.
    ///
    /// The 'object_type' parameter must match the type of the object in the odb; the method will fail otherwise.
    /// The special value 'git.ObjectType.any' may be passed to let the method guess the object's type.
    ///
    /// ## Parameters
    /// * `id` - The unique identifier for the object
    /// * `object_type` - The type of the object
    pub fn objectLookup(self: *Repository, id: *const git.Oid, object_type: git.ObjectType) !*git.Object {
        if (internal.trace_log) log.debug("Repository.objectLookup called", .{});

        var ret: *git.Object = undefined;

        try internal.wrapCall("git_object_lookup", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            @intFromEnum(object_type),
        });

        return ret;
    }

    /// Lookup a reference to one of the objects in a repository, given a prefix of its identifier (short id).
    ///
    /// The object obtained will be so that its identifier matches the first 'len' hexadecimal characters (packets of 4 bits) of
    /// the given 'id'.
    /// 'len' must be at least `git.Oid.min_prefix_len`, and long enough to identify a unique object matching/ the prefix;
    /// otherwise the method will fail.
    ///
    /// The generated reference is owned by the repository and should be closed with `git.Object.deinit`.
    ///
    /// The 'object_type' parameter must match the type of the object in the odb; the method will fail otherwise.
    /// The special value 'git.ObjectType.any' may be passed to let the method guess the object's type.
    ///
    /// ## Parameters
    /// * `id` - A short identifier for the object
    /// * `len` - The length of the short identifier
    /// * `object_type` - The type of the object
    pub fn objectLookupPrefix(self: *Repository, id: *const git.Oid, len: usize, object_type: git.ObjectType) !*git.Object {
        if (internal.trace_log) log.debug("Repository.objectLookupPrefix called", .{});

        var ret: *git.Object = undefined;

        try internal.wrapCall("git_object_lookup_prefix", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            len,
            @intFromEnum(object_type),
        });

        return ret;
    }

    /// Initialize a new packbuilder
    pub fn packbuilderNew(self: *Repository) !*git.PackBuilder {
        if (internal.trace_log) log.debug("Repository.packbuilderNew called", .{});

        var ret: *git.PackBuilder = undefined;

        try internal.wrapCall("git_packbuilder_new", .{
            @as(*?*c.git_packbuilder, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Add a remote with the default fetch refspec to the repository's configuration.
    ///
    /// ## Parameters
    /// * `name` - The remote's name.
    /// * `url` - The remote's url.
    // BUG: removed due to bitcast error
    // pub fn remoteCreate(self: *Repository, name: [:0]const u8, url: [:0]const u8) !*git.Remote {
    //     if (internal.trace_log) log.debug("Repository.remoteCreate called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     try internal.wrapCall("git_remote_create", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         @as(*c.git_repository, @ptrCast(self)),
    //         name.ptr,
    //         url.ptr,
    //     });
    //
    //     return remote;
    // }

    /// Add a remote with the provided refspec (or default if `null`) to the repository's configuration.
    ///
    /// ## Parameters
    /// * `name` - The remote's name.
    /// * `url` - The remote's url.
    /// * `fetch` - The remote fetch value.
    // BUG: removed due to bitcast error
    // pub fn remoteCreateWithFetchspec(
    //     repository: *Repository,
    //     name: [:0]const u8,
    //     url: [:0]const u8,
    //     fetch: ?[:0]const u8,
    // ) !*git.Remote {
    //     if (internal.trace_log) log.debug("Repository.remoteCreateWithFetchspec called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     const c_fetch = if (fetch) |s| s.ptr else null;
    //
    //     try internal.wrapCall("git_remote_create_with_fetchspec", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         @as(*c.git_repository, @ptrCast(repository)),
    //         name.ptr,
    //         url.ptr,
    //         c_fetch,
    //     });
    //
    //     return remote;
    // }

    /// Create a remote with the given url in-memory. You can use this when you have a url instead of a remote's name.
    ///
    /// ## Parameters
    /// * `name` - The remote's name.
    /// * `url` - The remote's url.
    // BUG: removed due to bitcast error
    // pub fn remoteCreateAnonymous(repository: *Repository, url: [:0]const u8) !*git.Remote {
    //     if (internal.trace_log) log.debug("Repository.remoteCreateAnonymous called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     try internal.wrapCall("git_remote_create_anonymous", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         @as(*c.git_repository, @ptrCast(repository)),
    //         url.ptr,
    //     });
    //
    //     return remote;
    // }

    /// Get the information for a particular remote.
    ///
    /// ## Parameters
    /// * `name` - The remote's name
    // BUG: removed due to bitcast error
    // pub fn remoteLookup(repository: *Repository, name: [:0]const u8) !*git.Remote {
    //     if (internal.trace_log) log.debug("Repository.remoteLookup called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     try internal.wrapCall("git_remote_lookup", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         @as(*c.git_repository, @ptrCast(repository)),
    //         name.ptr,
    //     });
    //
    //     return remote;
    // }

    /// Set the remote's url in the configuration
    ///
    /// Remote objects already in memory will not be affected. This assumes the common case of a single-url remote and will
    /// otherwise return an error.
    ///
    /// ## Parameters
    /// * `remote` - The remote's name.
    /// * `url` - The url to set.
    // BUG: removed due to bitcast error
    // pub fn remoteSetUrl(repository: *Repository, remote: [:0]const u8, url: [:0]const u8) !void {
    //     if (internal.trace_log) log.debug("Repository.remoteSetUrl called", .{});
    //
    //     try internal.wrapCall("git_remote_set_url", .{
    //         @as(*c.git_repository, @ptrCast(repository)),
    //         remote.ptr,
    //         url.ptr,
    //     });
    // }

    /// Set the remote's url for pushing in the configuration.
    ///
    /// Remote objects already in memory will not be affected. This assumes the common case of a single-url remote and will
    /// otherwise return an error.
    ///
    /// ## Parameters
    /// * `remote` - The remote's name.
    /// * `url` - The url to set.
    pub fn remoteSetPushurl(repository: *Repository, remote: [:0]const u8, url: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.remoteSetPushurl called", .{});

        try internal.wrapCall("git_remote_set_pushurl", .{
            @as(*c.git_repository, @ptrCast(repository)),
            remote.ptr,
            url.ptr,
        });
    }

    /// Add a fetch refspec to the remote's configuration.
    ///
    /// Add the given refspec to the fetch list in the configuration. No loaded remote instances will be affected.
    ///
    /// ## Parameters
    /// * `remote` - Name of the remote to change.
    /// * `refspec` - The new fetch refspec.
    pub fn remoteAddFetch(repository: *Repository, remote: [:0]const u8, refspec: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.remoteAddFetch called", .{});

        try internal.wrapCall("git_remote_add_fetch", .{
            @as(*c.git_repository, @ptrCast(repository)),
            remote.ptr,
            refspec.ptr,
        });
    }

    /// Add a pull refspec to the remote's configuration.
    ///
    /// Add the given refspec to the push list in the configuration. No loaded remote instances will be affected.
    ///
    /// ## Parameters
    /// * `remote` - Name of the remote to change.
    /// * `refspec` - The new push refspec.
    pub fn remoteAddPush(repository: *Repository, remote: [:0]const u8, refspec: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.remoteAddPush called", .{});

        try internal.wrapCall("git_remote_add_push", .{
            @as(*c.git_repository, @ptrCast(repository)),
            remote.ptr,
            refspec.ptr,
        });
    }

    /// Get a list of the configured remotes for a repo
    ///
    /// The returned array must be deinit by user.
    pub fn remoteList(self: *Repository) !git.StrArray {
        if (internal.trace_log) log.debug("Repository.remoteList called", .{});

        var str: git.StrArray = .{};

        try internal.wrapCall("git_remote_list", .{
            @as(*c.git_strarray, @ptrCast(&str)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return str;
    }

    /// Set the remote's tag following setting.
    ///
    /// The change will be made in the configuration. No loaded remotes will be affected.
    ///
    /// ## Parameters
    /// * `remote` - The name of the remote.
    /// * `value` - The new value to take.
    // BUG: removed due to bitcast error
    // pub fn remoteSetAutotag(self: *Repository, remote: [:0]const u8, value: git.RemoteAutoTagOption) !void {
    //     if (internal.trace_log) log.debug("Remote.setAutotag called", .{});
    //
    //     try internal.wrapCall("git_remote_set_autotag", .{
    //         @as(*c.git_repository, @ptrCast(self)),
    //         remote.ptr,
    //         @intFromEnum(value),
    //     });
    // }

    /// Give the remote a new name
    ///
    /// All remote-tracking branches and configuration settings for the remote are updated.
    ///
    /// TODO: Fix `git_tag_create()` once tag.h has been done
    /// The new name will be checked for validity. See git_tag_create() for rules about valid names.
    ///
    /// No loaded instances of a the remote with the old name will change their name or their list of refspecs.
    ///
    /// Non-default refspecs cannot be renamed and will be returned for further processing by the caller.
    /// Always free the returned `git.StrArray`.
    ///
    /// ## Problems
    /// * `name` - The current name of the remote
    /// * `new_name` - The new name the remote should bear
    pub fn remoteRename(self: *Repository, name: [:0]const u8, new_name: [:0]const u8) !git.StrArray {
        if (internal.trace_log) log.debug("Repository.remoteRename called", .{});

        var problems: git.StrArray = .{};

        try internal.wrapCall("git_remote_rename", .{
            @as(*c.git_strarray, @ptrCast(&problems)),
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
            new_name.ptr,
        });

        return problems;
    }

    /// Delete an existing persisted remote.
    ///
    /// All remote-tracking branches and configuration settings for the remote will be removed.
    ///
    /// ## Parameters
    /// * `name` - The remote to delete
    pub fn remoteDelete(self: *Repository, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.remoteDelete called", .{});

        try internal.wrapCall("git_remote_delete", .{
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });
    }

    /// Match a pathspec against the working directory of a repository.
    ///
    /// This matches the pathspec against the current files in the working directory of the repository. It is an error to invoke
    /// this on a bare repo. This handles git ignores (i.e. ignored files will not be considered to match the `pathspec` unless
    /// the file is tracked in the index).
    ///
    /// If `match_list` is not `null`, this returns a `git.PathspecMatchList`. That contains the list of all matched filenames
    /// (unless you pass the `MatchOptions.failures_only` options) and may also contain the list of pathspecs with no match (if
    /// you used the `MatchOptions.find_failures` option).
    /// You must call `PathspecMatchList.deinit()` on this object.
    ///
    /// ## Parameters
    /// * `pathspec` - Pathspec to be matched
    /// * `options` - Options to control match
    /// * `match_list` - Output list of matches; pass `null` to just get return value
    pub fn pathspecMatchWorkdir(
        self: *Repository,
        pathspec: *git.Pathspec,
        options: git.PathspecMatchOptions,
        match_list: ?**git.PathspecMatchList,
    ) !bool {
        if (internal.trace_log) log.debug("Repository.pathspecMatchWorkdir called", .{});

        return (try internal.wrapCallWithReturn("git_pathspec_match_workdir", .{
            @as(?*?*c.git_pathspec_match_list, @ptrCast(match_list)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(c.git_pathspec_flag_t, @bitCast(options)),
            @as(*c.git_pathspec, @ptrCast(pathspec)),
        })) != 0;
    }

    /// Find a single object, as specified by a revision string.
    ///
    /// See `man gitrevisions`, or http://git-scm.com/docs/git-rev-parse.html#_specifying_revisions for information on the syntax
    /// accepted.
    ///
    /// The returned object should be released with `Object.deinit()` when no longer needed.
    ///
    /// ## Parameters
    /// * `spec` - The textual specification for an object
    pub fn revisionParseSingle(self: *Repository, spec: [:0]const u8) !*git.Object {
        if (internal.trace_log) log.debug("Repository.revisionParseSingle called", .{});

        var ret: *git.Object = undefined;

        try internal.wrapCall("git_revparse_single", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            spec.ptr,
        });

        return ret;
    }

    /// Find a single object and intermediate reference by a revision string.
    ///
    /// See `man gitrevisions`, or http://git-scm.com/docs/git-rev-parse.html#_specifying_revisions for information on the syntax
    /// accepted.
    ///
    /// In some cases (`@{<-n>}` or `<branchname>@{upstream}`), the expression may point to an intermediate reference. When such
    /// expressions are being passed in, `reference` will be valued as well.
    ///
    /// The returned object should be released with `Object.deinit()` when no longer needed.
    ///
    /// ## Parameters
    /// * `reference` - Pointer to output reference or `null`
    /// * `spec` - The textual specification for an object
    pub fn revisionParseExtended(
        self: *Repository,
        reference: ?**git.Reference,
        spec: [:0]const u8,
    ) !*git.Object {
        if (internal.trace_log) log.debug("Repository.revisionParseExtended called", .{});

        var ret: *git.Object = undefined;

        try internal.wrapCall("git_revparse_ext", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(?*?*c.git_reference, @ptrCast(reference)),
            @as(*c.git_repository, @ptrCast(self)),
            spec.ptr,
        });

        return ret;
    }

    /// Parse a revision string for `from`, `to`, and intent.
    ///
    /// See `man gitrevisions`, or http://git-scm.com/docs/git-rev-parse.html#_specifying_revisions for information on the syntax
    /// accepted.
    ///
    /// The returned `RevSpec` contains two `git.Object`'s that should be freed by the user.
    ///
    /// ## Parameters
    /// * `spec` - The rev-parse spec to parse
    pub fn revisionParse(self: *Repository, spec: [:0]const u8) !RevSpec {
        if (internal.trace_log) log.debug("Repository.revisionParse called", .{});

        var ret: RevSpec = undefined;

        try internal.wrapCall("git_revparse", .{
            @as(*c.git_revspec, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            spec.ptr,
        });

        return ret;
    }

    /// Read the reflog for the given reference
    ///
    /// If there is no reflog file for the given reference yet, an empty reflog object will be returned.
    ///
    /// ## Parameters
    /// * `name` - Reference to look up
    pub fn reflogRead(self: *Repository, name: [:0]const u8) !*git.Reflog {
        if (internal.trace_log) log.debug("Repository.reflogRead called", .{});

        var ret: *git.Reflog = undefined;

        try internal.wrapCall("git_reflog_read", .{
            @as(*?*c.git_reflog, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });

        return ret;
    }

    /// Rename a reflog
    ///
    /// The reflog to be renamed is expected to already exist
    ///
    /// The new name will be checked for validity. `Repository.referenceSymbolicCreate()` for rules about valid names.
    ///
    /// ## Parameters
    /// * `old_name` - The old name of the reference
    /// * `name` - The new name of the reference
    pub fn reflogRename(self: *Repository, old_name: [:0]const u8, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.reflogRename called", .{});

        try internal.wrapCall("git_reflog_rename", .{
            @as(*c.git_repository, @ptrCast(self)),
            old_name.ptr,
            name.ptr,
        });
    }

    /// Delete the reflog for the given reference
    ///
    /// ## Parameters
    /// * `name` - The reflog to delete
    pub fn reflogDelete(self: *Repository, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.reflogDelete called", .{});

        try internal.wrapCall("git_reflog_delete", .{
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });
    }

    /// Create a new reference database with no backends.
    ///
    /// Before the Ref DB can be used for read/writing, a custom database backend must be manually set using `Refdb.setBackend()`
    pub fn refdbNew(self: *Repository) !*git.Refdb {
        if (internal.trace_log) log.debug("Repository.refdbNew called", .{});

        var ret: *git.Refdb = undefined;

        try internal.wrapCall("git_refdb_new", .{
            @as(*?*c.git_refdb, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Create a new reference database and automatically add the default backends:
    ///
    /// * git_refdb_dir: read and write loose and packed refs from disk, assuming the repository dir as the folder
    pub fn refdbOpen(self: *Repository) !*git.Refdb {
        if (internal.trace_log) log.debug("Repository.refdbOpen called", .{});

        var ret: *git.Refdb = undefined;

        try internal.wrapCall("git_refdb_open", .{
            @as(*?*c.git_refdb, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Reverts the given commit against the given "our" commit, producing an index that reflects the result of the revert.
    ///
    /// ## Parameters
    /// * `revert_commit` - The commit to revert
    /// * `our_commit` - The commit to revert against (eg, HEAD)
    /// * `mainline` - The parent of the revert commit, if it is a merge
    /// * `merge_options` - The merge options
    pub fn revertCommit(
        self: *Repository,
        revert_commit: *git.Commit,
        our_commit: *git.Commit,
        mainline: bool,
        merge_options: git.MergeOptions,
    ) !*git.Index {
        if (internal.trace_log) log.debug("Repository.revertCommit called", .{});

        const c_options = internal.make_c_option.mergeOptions(merge_options);

        var ret: *git.Index = undefined;

        try internal.wrapCall("git_revert_commit", .{
            @as(*?*c.git_index, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(revert_commit)),
            @as(*c.git_commit, @ptrCast(our_commit)),
            @intFromBool(mainline),
            &c_options,
        });

        return ret;
    }

    /// Reverts the given commit, producing changes in the index and working directory.
    ///
    /// ## Parameters
    /// * `commit` - The commit to revert
    /// * `options` - The revert options
    pub fn revert(self: *Repository, commit: *git.Commit, options: git.RevertOptions) !void {
        if (internal.trace_log) log.debug("Repository.revert called", .{});

        const c_options = internal.make_c_option.revertOptions(options);

        try internal.wrapCall("git_revert", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_commit, @ptrCast(commit)),
            &c_options,
        });
    }

    /// Create a new action signature with default user and now timestamp.
    ///
    /// This looks up the user.name and user.email from the configuration and uses the current time as the timestamp, and creates
    /// a new signature based on that information.
    /// It will return `GitError.NotFound` if either the user.name or user.email are not set.
    ///
    /// ## Parameters
    /// * `name` - Name of the person
    /// * `email` - Email of the person
    pub fn signatureInitDefault(self: *git.Repository) !*git.Signature {
        if (internal.trace_log) log.debug("Repository.signatureInitDefault called", .{});

        var ret: *git.Signature = undefined;

        try internal.wrapCall("git_signature_default", .{
            @as(*?*c.git_signature, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Sets the current head to the specified commit oid and optionally resets the index and working tree to match.
    ///
    /// `ResetType.soft` reset means the Head will be moved to the commit.
    ///
    /// `ResetType.mixed` reset will trigger a SOFT reset, plus the index will be replaced with the content of the commit tree.
    ///
    /// `ResetType.hard` reset will trigger a MIXED reset and the working directory will be replaced with the content of the index.
    /// (Untracked and ignored files will be left alone, however.)
    ///
    /// ## Parameters
    /// * `target` - Committish to which the Head should be moved to. This object must belong to the given `repo` and can either
    ///              be a commit or a tag. When a tag is being passed, it should be dereferencable to a commit which oid will be
    ///              used as the target of the branch.
    /// * `reset_type` - Kind of reset operation to perform.
    /// * `checkout_options` - Checkout options to be used for a HARD reset. The checkout_strategy field will be overridden
    ///                        (based on reset_type). This parameter can be used to propagate notify and progress callbacks.
    pub fn reset(self: *Repository, target: *const git.Object, reset_type: ResetType, checkout_options: CheckoutOptions) !void {
        if (internal.trace_log) log.debug("Repository.reset called", .{});

        const c_options = internal.make_c_option.checkoutOptions(checkout_options);

        try internal.wrapCall("git_reset", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_object, @ptrCast(target)),
            @intFromEnum(reset_type),
            &c_options,
        });
    }

    /// Sets the current head to the specified commit oid and optionally resets the index and working tree to match.
    ///
    /// This behaves like `Repository.reset` but takes an annotated commit, which lets you specify which extended sha syntax
    /// string was specified by a user, allowing for more exact reflog messages.
    ///
    /// ## Parameters
    /// * `commit` - Target annotated commit
    /// * `reset_type` - Kind of reset operation to perform.
    /// * `checkout_options` - Checkout options to be used for a HARD reset. The checkout_strategy field will be overridden
    ///                        (based on reset_type). This parameter can be used to propagate notify and progress callbacks.
    pub fn resetFromAnnotated(
        self: *Repository,
        commit: *const git.AnnotatedCommit,
        reset_type: ResetType,
        checkout_options: CheckoutOptions,
    ) !void {
        if (internal.trace_log) log.debug("Repository.resetFromAnnotated called", .{});

        const c_options = internal.make_c_option.checkoutOptions(checkout_options);

        try internal.wrapCall("git_reset_from_annotated", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_annotated_commit, @ptrCast(commit)),
            @intFromEnum(reset_type),
            &c_options,
        });
    }

    /// Updates some entries in the index from the target commit tree.
    ///
    /// The scope of the updated entries is determined by the paths being passed in the `pathspec` parameters.
    ///
    /// Passing a `null` `target` will result in removing entries in the index matching the provided pathspecs.
    ///
    /// ## Parameters
    /// * `target` - The committish which content will be used to reset the content of the index.
    /// * `pathspecs` - List of pathspecs to operate on.
    pub fn resetDefault(self: *Repository, target: ?*const git.Object, pathspecs: git.StrArray) !void {
        if (internal.trace_log) log.debug("Repository.resetDefault called", .{});

        try internal.wrapCall("git_reset_default", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*const c.git_object, @ptrCast(target)),
            @as(*const c.git_strarray, @ptrCast(&pathspecs)),
        });
    }

    /// Create a new transaction object
    ///
    /// This does not lock anything, but sets up the transaction object to know from which repository to lock.
    pub fn transactionInit(self: *Repository) !*git.Transaction {
        if (internal.trace_log) log.debug("Repository.transactionInit called", .{});

        var ret: *git.Transaction = undefined;

        try internal.wrapCall("git_transaction_new", .{
            @as(*?*c.git_transaction, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Update the filesystem config settings for an open repository
    ///
    /// When a repository is initialized, config values are set based on the properties of the filesystem that the repository is
    /// on, such as "core.ignorecase", "core.filemode", "core.symlinks", etc. If the repository is moved to a new filesystem,
    /// these properties may no longer be correct and API calls may not behave as expected. This call reruns the phase of
    /// repository initialization that sets those properties to compensate for the current filesystem of the repo.
    ///
    /// ## Parameters
    /// * `recurse_submodules` - Should submodules be updated recursively.
    pub fn reinitFilesystem(self: *Repository, recurse_submodules: bool) !void {
        if (internal.trace_log) log.debug("Repository.reinitFilesystem called", .{});

        try internal.wrapCall("git_repository_reinit_filesystem", .{
            @as(*c.git_repository, @ptrCast(self)),
            @intFromBool(recurse_submodules),
        });
    }

    /// Set the configuration file for this repository
    ///
    /// This configuration file will be used for all configuration queries involving this repository.
    ///
    /// The repository will keep a reference to the config file; the user must still free the config after setting it to the
    /// repository, or it will leak.
    ///
    /// ## Parameters
    /// * `config` - The config object.
    pub fn setConfig(self: *Repository, config: *git.Config) !void {
        if (internal.trace_log) log.debug("Repository.setConfig called", .{});

        try internal.wrapCall("git_repository_set_config", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_config, @ptrCast(config)),
        });
    }

    /// Set the Object Database for this repository
    ///
    /// The ODB will be used for all object-related operations involving this repository.
    ///
    /// The repository will keep a reference to the ODB; the user must still free the ODB object after setting it to the
    /// repository, or it will leak.
    ///
    /// ## Parameters
    /// * `config` - The odb object.
    pub fn setOdb(self: *Repository, odb: *git.Odb) !void {
        if (internal.trace_log) log.debug("Repository.setOdb called", .{});

        try internal.wrapCall("git_repository_set_odb", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_odb, @ptrCast(odb)),
        });
    }

    /// Set the Reference Database Backend for this repository
    ///
    /// The refdb will be used for all reference related operations involving this repository.
    ///
    /// The repository will keep a reference to the refdb; the user must still free the refdb object after setting it to the
    /// repository, or it will leak.
    ///
    /// ## Parameters
    /// * `refdb` - The refdb object.
    pub fn setRefdb(self: *Repository, refdb: *git.Refdb) !void {
        if (internal.trace_log) log.debug("Repository.setRefdb called", .{});

        try internal.wrapCall("git_repository_set_refdb", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(*c.git_refdb, @ptrCast(refdb)),
        });
    }

    /// Set the index file for this repository
    ///
    /// This index will be used for all index-related operations involving this repository.
    ///
    /// The repository will keep a reference to the index file; the user must still free the index after setting it to the
    /// repository, or it will leak.
    ///
    /// ## Parameters
    /// * `index` - The index object.
    pub fn setIndex(self: *Repository, index: ?*git.Index) !void {
        if (internal.trace_log) log.debug("Repository.setIndex called", .{});

        try internal.wrapCall("git_repository_set_index", .{
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*c.git_index, @ptrCast(index)),
        });
    }

    /// Set a repository to be bare.
    ///
    /// Clear the working directory and set core.bare to true. You may also want to call `repo.setIndex(null)` since a bare repo
    /// typically does not have an index, but this function will not do that for you.
    pub fn setBare(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.setBare called", .{});

        try internal.wrapCall("git_repository_set_bare", .{
            @as(*c.git_repository, @ptrCast(self)),
        });
    }

    /// Load and cache all submodules.
    ///
    /// Because the `.gitmodules` file is unstructured, loading submodules is an O(N) operation. Any operation
    /// (such as `git_rebase_init`) that requires accessing all submodules is O(N^2) in the number of submodules, if it has to
    /// look each one up individually. This function loads all submodules and caches them so that subsequent calls to
    /// `Repository.submoduleLookup` are O(1).
    pub fn submoduleCacheAll(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.submoduleCacheAll called", .{});

        try internal.wrapCall("git_repository_submodule_cache_all", .{
            @as(*c.git_repository, @ptrCast(self)),
        });
    }

    /// Clear the submodule cache.
    ///
    /// Clear the submodule cache populated by `Repository.submoduleCacheAll`. If there is no cache, do nothing.
    ///
    /// The cache incorporates data from the repository's configuration, as well as the state of the working tree, the index,
    /// and HEAD. So any time any of these has changed, the cache might become invalid.
    pub fn submoduleCacheClear(self: *Repository) !void {
        if (internal.trace_log) log.debug("Repository.submoduleCacheClear called", .{});

        try internal.wrapCall("git_repository_submodule_cache_clear", .{
            @as(*c.git_repository, @ptrCast(self)),
        });
    }

    /// Save the local modifications to a new stash.
    ///
    /// ## Parameters
    /// * `stasher` - The identity of the person performing the stashing.
    /// * `message` - Optional description along with the stashed state.
    /// * `flags` - Flags to control the stashing process.
    pub fn stashSave(self: *Repository, stasher: *const git.Signature, message: ?[:0]const u8, flags: StashFlags) !git.Oid {
        if (internal.trace_log) log.debug("Repository.stashSave called", .{});

        var ret: git.Oid = undefined;

        const c_message = if (message) |s| s.ptr else null;

        try internal.wrapCall("git_stash_save", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_signature, @ptrCast(stasher)),
            c_message,
            @as(u32, @bitCast(flags)),
        });

        return ret;
    }

    /// Apply a single stashed state from the stash list.
    ///
    /// If local changes in the working directory conflict with changes in the stash then `GitError.MergeConflict` will be returned.
    /// In this case, the index will always remain unmodified and all files in the working directory will remain unmodified.
    /// However, if you are restoring untracked files or ignored files and there is a conflict when applying the modified files,
    /// then those files will remain in the working directory.
    ///
    /// If passing the `StashApplyOptions.Flags.reinstate_index` flag and there would be conflicts when reinstating the index,
    /// the function will return GitError.MergeConflict` and both the working directory and index will be left unmodified.
    ///
    /// Note that a minimum checkout strategy of safe is implied.
    ///
    /// ## Parameters
    /// * `index` - The position within the stash list. 0 points to the most recent stashed state.
    /// * `options` - Options to control how stashes are applied.
    pub fn stashApply(self: *Repository, index: usize, options: StashApplyOptions) !void {
        if (internal.trace_log) log.debug("Repository.stashApply called", .{});

        const c_options = internal.make_c_option.stashApplyOptions(options);

        try internal.wrapCall("git_stash_apply", .{
            @as(*c.git_repository, @ptrCast(self)),
            index,
            &c_options,
        });
    }

    /// Remove a single stashed state from the stash list.
    ///
    /// ## Parameters
    /// * `index` - The position within the stash list. 0 points to the most recent stashed state.
    pub fn stashDrop(self: *Repository, index: usize) !void {
        if (internal.trace_log) log.debug("Repository.stashDrop called", .{});

        try internal.wrapCall("git_stash_drop", .{
            @as(*c.git_repository, @ptrCast(self)),
            index,
        });
    }

    /// Apply a single stashed state from the stash list and remove it from the list if successful.
    ///
    /// ## Parameters
    /// * `index` - The position within the stash list. 0 points to the most recent stashed state.
    /// * `options` - Options to control how stashes are applied.
    pub fn stashPop(self: *Repository, index: usize, options: StashApplyOptions) !void {
        if (internal.trace_log) log.debug("Repository.stashPop called", .{});

        const c_options = internal.make_c_option.stashApplyOptions(options);

        try internal.wrapCall("git_stash_pop", .{
            @as(*c.git_repository, @ptrCast(self)),
            index,
            &c_options,
        });
    }

    /// Loop over all the stashed states and issue a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `index` - The position within the stash list. 0 points to the most recent stashed state.
    /// * `message` - The stash message.
    /// * `stash_id` - The commit oid of the stashed state.
    pub fn stashForeach(
        self: *Repository,
        comptime callback_fn: fn (
            index: usize,
            message: ?[:0]const u8,
            stash_id: *const git.Oid,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                index: usize,
                message: ?[:0]const u8,
                stash_id: *const git.Oid,
                _: *u8,
            ) c_int {
                return callback_fn(index, message, stash_id);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.stashForeachWithUserData(&dummy_data, cb);
    }

    /// Loop over all the stashed states and issue a callback for each one.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `index` - The position within the stash list. 0 points to the most recent stashed state.
    /// * `message` - The stash message.
    /// * `stash_id` - The commit oid of the stashed state.
    /// * `user_data_ptr` - Pointer to user data.
    pub fn stashForeachWithUserData(
        self: *Repository,
        user_data: anytype,
        comptime callback_fn: fn (
            index: usize,
            message: ?[:0]const u8,
            stash_id: *const git.Oid,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                index: usize,
                message: ?[*:0]const u8,
                stash_id: *const c.git_oid,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    index,
                    if (message) |m| std.mem.sliceTo(m, 0) else null,
                    @as(*const git.Oid, @ptrCast(stash_id)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.stashForeachWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_stash_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Allocate a new revision walker to iterate through a repo.
    ///
    /// This revision walker uses a custom memory pool and an internal commit cache, so it is relatively expensive to allocate.
    ///
    /// For maximum performance, this revision walker should be reused for different walks.
    ///
    /// This revision walker is *not* thread safe: it may only be used to walk a repository on a single thread; however, it is
    /// possible to have several revision walkers in several different threads walking the same repository.
    pub fn revwalkNew(self: *Repository) !*git.RevWalk {
        if (internal.trace_log) log.debug("Repository.revwalkNew called", .{});

        var ret: *git.RevWalk = undefined;

        try internal.wrapCall("git_revwalk_new", .{
            @as(*?*c.git_revwalk, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Initializes a rebase operation to rebase the changes in `branch` relative to `upstream` onto another branch. To begin the
    /// rebase process, call `Rebase.next`. When you have finished with this object, call `Rebase.deinit`.
    ///
    /// ## Parameters
    /// * `branch` - The terminal commit to rebase, or `null` to rebase the current branch.
    /// * `upstream` - The commit to begin rebasing from, or `null` to rebase all reachable commits.
    /// * `onto` - The branch to rebase onto, or `null` to rebase onto the given upstream.
    /// * `options` - Options to specify how rebase is performed.
    pub fn rebaseInit(
        self: *Repository,
        branch: ?*const git.AnnotatedCommit,
        upstream: ?*const git.AnnotatedCommit,
        onto: ?*const git.AnnotatedCommit,
        options: git.RebaseOptions,
    ) !*git.Rebase {
        if (internal.trace_log) log.debug("Repository.rebaseInit called", .{});

        var ret: *git.Rebase = undefined;

        const c_options = internal.make_c_option.rebaseOptions(options);

        try internal.wrapCall("git_rebase_init", .{
            @as(*?*c.git_rebase, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(?*const c.git_annotated_commit, @ptrCast(branch)),
            @as(?*const c.git_annotated_commit, @ptrCast(upstream)),
            @as(?*const c.git_annotated_commit, @ptrCast(onto)),
            &c_options,
        });

        return ret;
    }

    /// Opens an existing rebase that was previously started by either an invocation of `Repository.rebaseInit` or by another client.
    ///
    /// ## Parameters
    /// * `options` - Options to specify how rebase is performed.
    pub fn rebaseOpen(
        self: *Repository,
        options: git.RebaseOptions,
    ) !*git.Rebase {
        if (internal.trace_log) log.debug("Repository.rebaseOpen called", .{});

        var ret: *git.Rebase = undefined;

        const c_options = internal.make_c_option.rebaseOptions(options);

        try internal.wrapCall("git_rebase_open", .{
            @as(*?*c.git_rebase, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            &c_options,
        });

        return ret;
    }

    /// Lookup a tag object from the repository.
    ///
    /// ## Parameters
    /// * `id` - Identity of the tag to locate.
    pub fn tagLookup(self: *Repository, id: *const git.Oid) !*git.Tag {
        if (internal.trace_log) log.debug("Repository.tagLookup called", .{});

        var ret: *git.Tag = undefined;

        try internal.wrapCall("git_tag_lookup", .{
            @as(*?*c.git_tag, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });

        return ret;
    }

    /// Lookup a tag object from the repository, given a prefix of its identifier (short id).
    ///
    /// ## Parameters
    /// * `id` - Identity of the tag to locate.
    /// * `id` - The length of the short identifier
    pub fn tagLookupPrefix(self: *Repository, id: *const git.Oid, len: usize) !*git.Tag {
        if (internal.trace_log) log.debug("Repository.tagLookupPrefix called", .{});

        var ret: *git.Tag = undefined;

        try internal.wrapCall("git_tag_lookup_prefix", .{
            @as(*?*c.git_tag, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            len,
        });

        return ret;
    }

    /// Create a new tag in the repository from an object.
    ///
    /// A new reference will also be created pointing to this tag object. If `force` is `true` and a reference already exists with
    /// the given name, it'll be replaced.
    ///
    /// The message will not be cleaned up. This can be achieved through `Handle.messagePrettify`.
    ///
    /// The tag name will be checked for validity. You must avoid the characters '~', '^', ':', '\\', '?', '[', and '*', and the
    /// sequences ".." and "@{" which have special meaning to revparse.
    ///
    /// ## Parameters
    /// * `tag_name` - Name for the tag; this name is validated for consistency. It should also not conflict with an already
    ///                existing tag name unless `force` is `true`.
    /// * `target` - Object to which this tag points.
    /// * `tagger` - Signature of the tagger for this tag, and of the tagging time.
    /// * `message` - Full message for this tag.
    /// * `force` - Overwrite existing references.
    pub fn tagCreate(
        self: *Repository,
        tag_name: [:0]const u8,
        target: *const git.Object,
        tagger: ?*const git.Signature,
        message: ?[:0]const u8,
        force: bool,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.tagCreate called", .{});

        var ret: git.Oid = undefined;

        const c_message = if (message) |s| s.ptr else null;

        try internal.wrapCall("git_tag_create", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            tag_name.ptr,
            @as(*const c.git_object, @ptrCast(target)),
            @as(?*const c.git_signature, @ptrCast(tagger)),
            c_message,
            @intFromBool(force),
        });

        return ret;
    }

    /// Create a new tag in the object database pointing to a `git.Object`.
    ///
    /// The message will not be cleaned up. This can be achieved through `Handle.messagePrettify`.
    ///
    /// ## Parameters
    /// * `tag_name` - Name for the tag.
    /// * `target` - Object to which this tag points.
    /// * `tagger` - Signature of the tagger for this tag, and of the tagging time.
    /// * `message` - Full message for this tag.
    pub fn tagAnnotationCreate(
        self: *Repository,
        tag_name: [:0]const u8,
        target: *const git.Object,
        tagger: ?*const git.Signature,
        message: ?[:0]const u8,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.tagAnnotationCreate called", .{});

        var ret: git.Oid = undefined;

        const c_message = if (message) |s| s.ptr else null;

        try internal.wrapCall("git_tag_annotation_create", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            tag_name.ptr,
            @as(*const c.git_object, @ptrCast(target)),
            @as(?*const c.git_signature, @ptrCast(tagger)),
            c_message,
        });

        return ret;
    }

    /// Create a new tag in the repository from a buffer
    ///
    /// ## Parameters
    /// * `buffer` - Raw tag data.
    /// * `force` - Overwrite existing tags.
    pub fn tagCreateFromBuffer(
        self: *Repository,
        buffer: [:0]const u8,
        force: bool,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.tagCreateFromBuffer called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_tag_create_from_buffer", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            buffer.ptr,
            @intFromBool(force),
        });

        return ret;
    }

    /// Create a new lightweight tag pointing at a target object.
    ///
    /// A new reference will also be created pointing to this tag object. If `force` is `true` and a reference already exists with
    /// the given name, it'll be replaced.
    ///
    /// The tag name will be checked for validity. You must avoid the characters '~', '^', ':', '\\', '?', '[', and '*', and the
    /// sequences ".." and "@{" which have special meaning to revparse.
    ///
    /// ## Parameters
    /// * `tag_name` - Name for the tag; this name is validated for consistency. It should also not conflict with an already
    ///                existing tag name unless `force` is `true`.
    /// * `target` - Object to which this tag points.
    /// * `force` - Overwrite existing references.
    pub fn tagCreateLightweight(
        self: *Repository,
        tag_name: [:0]const u8,
        target: *const git.Object,
        force: bool,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Repository.tagCreateLightweight called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_tag_create_lightweight", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
            tag_name.ptr,
            @as(*const c.git_object, @ptrCast(target)),
            @intFromBool(force),
        });

        return ret;
    }

    /// Delete an existing tag reference.
    ///
    /// The tag name will be checked for validity. See `Repository.tagCreate` for rules about valid names.
    pub fn tagDelete(self: *Repository, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Repository.tagDelete called", .{});

        try internal.wrapCall("git_tag_delete", .{
            @as(*c.git_repository, @ptrCast(self)),
            name.ptr,
        });
    }

    /// Fill a list with all the tags in the Repository
    ///
    /// The string array will be filled with the names of the matching tags; these values are owned by the user and should be
    /// free'd manually when no longer needed, using `StrArray.deinit`.
    pub fn tagList(self: *Repository) !git.StrArray {
        if (internal.trace_log) log.debug("Repository.tagList called", .{});

        var ret: git.StrArray = undefined;

        try internal.wrapCall("git_tag_list", .{
            @as(*c.git_strarray, @ptrCast(&ret)),
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Fill a list with all the tags in the Repository which name match a defined pattern.
    ///
    /// If an empty pattern is provided, all the tags will be returned.
    ///
    /// The string array will be filled with the names of the matching tags; these values are owned by the user and should be
    /// free'd manually when no longer needed, using `StrArray.deinit`.
    ///
    /// ## Parameters
    /// * `pattern` - Standard fnmatch pattern.
    pub fn tagListMatch(self: *Repository, pattern: [:0]const u8) !git.StrArray {
        if (internal.trace_log) log.debug("Repository.tagListMatch called", .{});

        var ret: git.StrArray = undefined;

        try internal.wrapCall("git_tag_list_match", .{
            @as(*c.git_strarray, @ptrCast(&ret)),
            pattern.ptr,
            @as(*c.git_repository, @ptrCast(self)),
        });

        return ret;
    }

    /// Invoke `callback_fn` for each entry tag in the repository.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function; non-zero to terminate the iteration.
    ///
    /// ## Callback Parameters
    /// * `name` - The tag name.
    /// * `oid` - The tag's OID.
    pub fn tagForeach(
        self: *Repository,
        comptime callback_fn: fn (
            name: [:0]const u8,
            oid: *const git.Oid,
        ) void,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                name: [:0]const u8,
                oid: *const git.Oid,
                _: *u8,
            ) c_int {
                return callback_fn(name, oid);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.tagForeachWithUserData(&dummy_data, cb);
    }

    /// Invoke `callback_fn` for each entry tag in the repository.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function; non-zero to terminate the iteration.
    ///
    /// ## Callback Parameters
    /// * `name` - The tag name.
    /// * `oid` - The tag's OID.
    /// * `user_data_ptr` - The user data.
    pub fn tagForeachWithUserData(
        self: *Repository,
        user_data: anytype,
        comptime callback_fn: fn (
            name: [:0]const u8,
            oid: *const git.Oid,
            user_data_ptr: @TypeOf(user_data),
        ) void,
    ) !c_int {
        if (internal.trace_log) log.debug("Index.tagForeachWithUserData called", .{});

        const UserDataType = @TypeOf(user_data);
        const ptr_info = @typeInfo(UserDataType);
        comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

        const cb = struct {
            pub fn cb(
                name: [*:0]const u8,
                oid: *const c.git_oid,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(name, 0),
                    @as(*const git.Oid, @ptrCast(oid)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        return try internal.wrapCallWithReturn("git_tag_foreach", .{
            @as(*c.git_repository, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Stash application options structure
pub const StashApplyOptions = struct {
    flags: StashApplyOptions.Flags = .{},

    /// Options to use when writing files to the working directory.
    checkout_options: CheckoutOptions = .{},

    /// Optional callback to notify the consumer of application progress.
    ///
    /// Return 0 to continue processing, or a negative value to abort the stash application.
    progress_callback: ?*const fn (progress: StashApplyProgress, payload: ?*anyopaque) callconv(.C) c_int = null,

    progress_payload: ?*anyopaque = null,

    /// Stash application flags.
    pub const Flags = packed struct {
        /// Try to reinstate not only the working tree's changes, but also the index's changes.
        reinstate_index: bool = false,

        z_padding: u31 = 0,

        pub fn format(
            value: Flags,
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
            try std.testing.expectEqual(@sizeOf(u32), @sizeOf(Flags));
            try std.testing.expectEqual(@bitSizeOf(u32), @bitSizeOf(Flags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Stash apply progression states
pub const StashApplyProgress = enum(c_uint) {
    none = 0,

    /// Loading the stashed data from the object database.
    loading_stash,

    /// The stored index is being analyzed.
    analyze_index,

    /// The modified files are being analyzed.
    analyze_modified,

    /// The untracked and ignored files are being analyzed.
    analyze_untracked,

    /// The untracked files are being written to disk.
    checkout_untracked,

    /// The modified files are being written to disk.
    checkout_modified,

    /// The stash was applied successfully.
    done,
};

/// Stash flags
pub const StashFlags = packed struct {
    /// All changes already added to the index are left intact in the working directory.
    keep_index: bool = false,

    /// All untracked files are also stashed and then cleaned up from the working directory.
    include_untracked: bool = false,

    /// All ignored files are also stashed and then cleaned up from the working directory.
    include_ignored: bool = false,

    z_padding: u29 = 0,

    pub fn format(
        value: StashFlags,
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
        try std.testing.expectEqual(@sizeOf(u32), @sizeOf(StashFlags));
        try std.testing.expectEqual(@bitSizeOf(u32), @bitSizeOf(StashFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Kinds of reset operation
pub const ResetType = enum(c_uint) {
    /// Move the head to the given commit
    soft = 1,
    /// `soft` plus reset index to the commit
    mixed = 2,
    /// `mixed` plus changes in working tree discarded
    hard = 3,
};

pub const RepositoryInitOptions = struct {
    flags: RepositoryInitExtendedFlags = .{},
    mode: InitMode = .shared_umask,

    /// The path to the working dir or `null` for default (i.e. repo_path parent on non-bare repos).
    /// *NOTE*: if this is a relative path, it must be relative to the repository path.
    /// If this is not the "natural" working directory, a .git gitlink file will be created linking to the repository path.
    workdir_path: ?[:0]const u8 = null,

    /// A "description" file to be used in the repository, instead of using the template content.
    description: ?[:0]const u8 = null,

    /// When `RepositoryInitExtendedFlags.external_template` is set, this must contain the path to use for the template
    /// directory. If this is `null`, the config or default directory options will be used instead.
    template_path: ?[:0]const u8 = null,

    /// The name of the head to point HEAD at. If `null`, then this will be treated as "master" and the HEAD ref will be set
    /// to "refs/heads/master".
    /// If this begins with "refs/" it will be used verbatim; otherwise "refs/heads/" will be prefixed.
    initial_head: ?[:0]const u8 = null,

    /// If this is non-`null`, then after the rest of the repository initialization is completed, an "origin" remote will be
    /// added pointing to this URL.
    origin_url: ?[:0]const u8 = null,

    pub const RepositoryInitExtendedFlags = packed struct {
        /// Create a bare repository with no working directory.
        bare: bool = false,

        /// Return an `GitError.EXISTS` error if the path appears to already be an git repository.
        no_reinit: bool = false,

        /// Normally a "/.git/" will be appended to the repo path for non-bare repos (if it is not already there), but passing
        /// this flag prevents that behavior.
        no_dotgit_dir: bool = false,

        /// Make the repo_path (and workdir_path) as needed. Init is always willing to create the ".git" directory even
        /// without this flag. This flag tells init to create the trailing component of the repo and workdir paths as needed.
        mkdir: bool = false,

        /// Recursively make all components of the repo and workdir paths as necessary.
        mkpath: bool = false,

        /// libgit2 normally uses internal templates to initialize a new repo.
        /// This flag enables external templates, looking at the "template_path" from the options if set, or the
        /// `init.templatedir` global config if not, or falling back on "/usr/share/git-core/templates" if it exists.
        external_template: bool = false,

        /// If an alternate workdir is specified, use relative paths for the gitdir and core.worktree.
        relative_gitlink: bool = false,

        z_padding: std.meta.Int(.unsigned, @bitSizeOf(c_uint) - 7) = 0,

        pub fn toInt(self: RepositoryInitExtendedFlags) c_uint {
            return @as(c_uint, @bitCast(self));
        }

        pub fn format(
            value: RepositoryInitExtendedFlags,
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
            try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(RepositoryInitExtendedFlags));
            try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(RepositoryInitExtendedFlags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub const InitMode = union(enum) {
        /// Use permissions configured by umask - the default.
        shared_umask: void,

        /// Use "--shared=group" behavior, chmod'ing the new repo to be group writable and "g+sx" for sticky group assignment.
        shared_group: void,

        /// Use "--shared=all" behavior, adding world readability.
        shared_all: void,

        custom: c_uint,

        pub fn toInt(self: InitMode) c_uint {
            return switch (self) {
                .shared_umask => 0,
                .shared_group => 0o2775,
                .shared_all => 0o2777,
                .custom => |custom| custom,
            };
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const FileStatusOptions = struct {
    /// which files to scan
    show: Show = .index_and_workdir,

    /// Flags to control status callbacks
    flags: Flags = .{},

    /// The `pathspec` is an array of path patterns to match (using fnmatch-style matching), or just an array of paths to
    /// match exactly if `Flags.disable_pathspec_match` is specified in the flags.
    pathspec: git.StrArray = .{},

    /// The `baseline` is the tree to be used for comparison to the working directory and index; defaults to HEAD.
    baseline: ?*git.Tree = null,

    /// Select the files on which to report status.
    pub const Show = enum(c_uint) {
        /// The default. This roughly matches `git status --porcelain` regarding which files are included and in what order.
        index_and_workdir,
        /// Only gives status based on HEAD to index comparison, not looking at working directory changes.
        index_only,
        /// Only gives status based on index to working directory comparison, not comparing the index to the HEAD.
        workdir_only,
    };

    /// Flags to control status callbacks
    ///
    /// Calling `Repository.forEachFileStatus` is like calling the extended version with: `include_ignored`,
    /// `include_untracked`, and `recurse_untracked_dirs`. Those options are provided as `Options.Defaults`.
    pub const Flags = packed struct {
        /// Says that callbacks should be made on untracked files.
        /// These will only be made if the workdir files are included in the status
        /// "show" option.
        include_untracked: bool = true,

        /// Says that ignored files get callbacks.
        /// Again, these callbacks will only be made if the workdir files are
        /// included in the status "show" option.
        include_ignored: bool = true,

        /// Indicates that callback should be made even on unmodified files.
        include_unmodified: bool = false,

        /// Indicates that submodules should be skipped.
        /// This only applies if there are no pending typechanges to the submodule
        /// (either from or to another type).
        exclude_submodules: bool = false,

        /// Indicates that all files in untracked directories should be included.
        /// Normally if an entire directory is new, then just the top-level
        /// directory is included (with a trailing slash on the entry name).
        /// This flag says to include all of the individual files in the directory
        /// instead.
        recurse_untracked_dirs: bool = true,

        /// Indicates that the given path should be treated as a literal path,
        /// and not as a pathspec pattern.
        disable_pathspec_match: bool = false,

        /// Indicates that the contents of ignored directories should be included
        /// in the status. This is like doing `git ls-files -o -i --exclude-standard`
        /// with core git.
        recurse_ignored_dirs: bool = false,

        /// Indicates that rename detection should be processed between the head and
        /// the index and enables the GIT_STATUS_INDEX_RENAMED as a possible status
        /// flag.
        renames_head_to_index: bool = false,

        /// Indicates that rename detection should be run between the index and the
        /// working directory and enabled GIT_STATUS_WT_RENAMED as a possible status
        /// flag.
        renames_index_to_workdir: bool = false,

        /// Overrides the native case sensitivity for the file system and forces
        /// the output to be in case-sensitive order.
        sort_case_sensitively: bool = false,

        /// Overrides the native case sensitivity for the file system and forces
        /// the output to be in case-insensitive order.
        sort_case_insensitively: bool = false,

        /// Iindicates that rename detection should include rewritten files.
        renames_from_rewrites: bool = false,

        /// Bypasses the default status behavior of doing a "soft" index reload
        /// (i.e. reloading the index data if the file on disk has been modified
        /// outside libgit2).
        no_refresh: bool = false,

        /// Tells libgit2 to refresh the stat cache in the index for files that are
        /// unchanged but have out of date stat einformation in the index.
        /// It will result in less work being done on subsequent calls to get status.
        /// This is mutually exclusive with the no_refresh option.
        update_index: bool = false,

        /// Normally files that cannot be opened or read are ignored as
        /// these are often transient files; this option will return
        /// unreadable files as `GIT_STATUS_WT_UNREADABLE`.
        include_unreadable: bool = false,

        /// Unreadable files will be detected and given the status
        /// untracked instead of unreadable.
        include_unreadable_as_untracked: bool = false,

        z_padding: u16 = 0,

        pub fn format(
            value: Flags,
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
            try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(Flags));
            try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(Flags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const RepositoryOpenOptions = packed struct {
    /// Only open the repository if it can be immediately found in the path. Do not walk up the directory tree to look for it.
    no_search: bool = false,

    /// Unless this flag is set, open will not search across filesystem boundaries.
    cross_fs: bool = false,

    /// Open repository as a bare repo regardless of core.bare config.
    bare: bool = false,

    /// Do not check for a repository by appending /.git to the path; only open the repository if path itself points to the
    /// git directory.
    no_dotgit: bool = false,

    /// Find and open a git repository, respecting the environment variables used by the git command-line tools. If set,
    /// `Handle.repositoryOpenExtended` will ignore the other flags and the `ceiling_dirs` argument, and will allow a `null`
    /// `path` to use `GIT_DIR` or search from the current directory.
    open_from_env: bool = false,

    z_padding: std.meta.Int(.unsigned, @bitSizeOf(c_uint) - 5) = 0,

    pub fn toInt(self: RepositoryOpenOptions) c_uint {
        return @as(c_uint, @bitCast(self));
    }

    pub fn format(
        value: RepositoryOpenOptions,
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
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(RepositoryOpenOptions));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(RepositoryOpenOptions));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Valid modes for index and tree entries.
pub const FileMode = enum(u16) {
    unreadable = 0o000000,
    tree = 0o040000,
    blob = 0o100644,
    blob_executable = 0o100755,
    link = 0o120000,
    commit = 0o160000,
};

pub const FileStatus = packed struct {
    current: bool = false,
    index_new: bool = false,
    index_modified: bool = false,
    index_deleted: bool = false,
    index_renamed: bool = false,
    index_typechange: bool = false,
    wt_new: bool = false,
    wt_modified: bool = false,
    wt_deleted: bool = false,
    wt_typechange: bool = false,
    wt_renamed: bool = false,
    wt_unreadable: bool = false,
    ignored: bool = false,
    conflicted: bool = false,

    z_padding1: u2 = 0,
    z_padding2: u16 = 0,

    pub fn format(
        value: FileStatus,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        return internal.formatWithoutFields(
            value,
            options,
            writer,
            &.{ "z_padding1", "z_padding2" },
        );
    }

    test {
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(FileStatus));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(FileStatus));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const RevSpec = extern struct {
    /// The left element of the revspec; must be freed by the user
    from: ?*git.Object,
    /// The right element of the revspec; must be freed by the user
    to: ?*git.Object,
    /// The intent of the revspec
    flags: RevSpecFlags,

    pub const RevSpecFlags = packed struct {
        /// The spec targeted a single object.
        single: bool = false,
        /// The spec targeted a range of commits.
        range: bool = false,
        /// The spec used the '...' operator, which invokes special semantics.
        merge_base: bool = false,

        z_padding: u29 = 0,

        pub fn format(
            value: RevSpecFlags,
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
            try std.testing.expectEqual(@sizeOf(c.git_revspec_t), @sizeOf(RevSpecFlags));
            try std.testing.expectEqual(@bitSizeOf(c.git_revspec_t), @bitSizeOf(RevSpecFlags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_revspec), @sizeOf(RevSpec));
        try std.testing.expectEqual(@bitSizeOf(c.git_revspec), @bitSizeOf(RevSpec));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const CheckoutOptions = struct {
    /// default will be a safe checkout
    checkout_strategy: Strategy = .{
        .safe = true,
    },

    /// don't apply filters like CRLF conversion
    disable_filters: bool = false,

    /// default is 0o755
    dir_mode: c_uint = 0,

    /// default is 0o644 or 0o755 as dictated by blob
    file_mode: c_uint = 0,

    /// default is O_CREAT | O_TRUNC | O_WRONLY
    file_open_flags: c_int = 0,

    /// Optional callback to get notifications on specific file states.
    notify_flags: Notification = .{},

    /// Optional callback to get notifications on specific file states.
    notify_cb: ?*const fn (
        why: Notification,
        path: [*:0]const u8,
        baseline: *git.DiffFile,
        target: *git.DiffFile,
        workdir: *git.DiffFile,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// Payload passed to notify_cb
    notify_payload: ?*anyopaque = null,

    /// Optional callback to notify the consumer of checkout progress
    progress_cb: ?*const fn (
        path: [*:0]const u8,
        completed_steps: usize,
        total_steps: usize,
        payload: ?*anyopaque,
    ) callconv(.C) void = null,

    /// Payload passed to progress_cb
    progress_payload: ?*anyopaque = null,

    /// A list of wildmatch patterns or paths.
    ///
    /// By default, all paths are processed. If you pass an array of wildmatch patterns, those will be used to filter which
    /// paths should be taken into account.
    ///
    /// Use GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH to treat as a simple list.
    paths: git.StrArray = .{},

    /// The expected content of the working directory; defaults to HEAD.
    ///
    /// If the working directory does not match this baseline information, that will produce a checkout conflict.
    baseline: ?*git.Tree = null,

    /// Like `baseline` above, though expressed as an index. This option overrides `baseline`.
    baseline_index: ?*git.Index = null,

    /// alternative checkout path to workdir
    target_directory: ?[:0]const u8 = null,

    /// the name of the common ancestor side of conflicts
    ancestor_label: ?[:0]const u8 = null,

    /// the name of the "our" side of conflicts
    our_label: ?[:0]const u8 = null,

    /// the name of the "their" side of conflicts
    their_label: ?[:0]const u8 = null,

    /// Optional callback to notify the consumer of performance data.
    perfdata_cb: ?*const fn (perfdata: *const PerfData, payload: *anyopaque) callconv(.C) void = null,

    /// Payload passed to perfdata_cb
    perfdata_payload: ?*anyopaque = null,

    pub const PerfData = extern struct {
        mkdir_calls: usize,
        stat_calls: usize,
        chmod_calls: usize,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_checkout_perfdata), @sizeOf(PerfData));
            try std.testing.expectEqual(@bitSizeOf(c.git_checkout_perfdata), @bitSizeOf(PerfData));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub const Strategy = packed struct {
        /// Allow safe updates that cannot overwrite uncommitted data.
        /// If the uncommitted changes don't conflict with the checked out files,
        /// the checkout will still proceed, leaving the changes intact.
        ///
        /// Mutually exclusive with force.
        /// force takes precedence over safe.
        safe: bool = false,

        /// Allow all updates to force working directory to look like index.
        ///
        /// Mutually exclusive with safe.
        /// force takes precedence over safe.
        force: bool = false,

        /// Allow checkout to recreate missing files
        recreate_missing: bool = false,

        z_padding: bool = false,

        /// Allow checkout to make safe updates even if conflicts are found
        allow_conflicts: bool = false,

        /// Remove untracked files not in index (that are not ignored)
        remove_untracked: bool = false,

        /// Remove ignored files not in index
        remove_ignored: bool = false,

        /// Only update existing files, don't create new ones
        update_only: bool = false,

        /// Normally checkout updates index entries as it goes; this stops that.
        /// Implies `dont_write_index`.
        dont_update_index: bool = false,

        /// Don't refresh index/config/etc before doing checkout
        no_refresh: bool = false,

        /// Allow checkout to skip unmerged files
        skip_unmerged: bool = false,

        /// For unmerged files, checkout stage 2 from index
        use_ours: bool = false,

        /// For unmerged files, checkout stage 3 from index
        use_theirs: bool = false,

        /// Treat pathspec as simple list of exact match file paths
        disable_pathspec_match: bool = false,

        z_padding2: u2 = 0,

        /// Recursively checkout submodules with same options (NOT IMPLEMENTED)
        update_submodules: bool = false,

        /// Recursively checkout submodules if HEAD moved in super repo (NOT IMPLEMENTED)
        update_submodules_if_changed: bool = false,

        /// Ignore directories in use, they will be left empty
        skip_locked_directories: bool = false,

        /// Don't overwrite ignored files that exist in the checkout target
        dont_overwrite_ignored: bool = false,

        /// Write normal merge files for conflicts
        conflict_style_merge: bool = false,

        /// Include common ancestor data in diff3 format files for conflicts
        conflict_style_diff3: bool = false,

        /// Don't overwrite existing files or folders
        dont_remove_existing: bool = false,

        /// Normally checkout writes the index upon completion; this prevents that.
        dont_write_index: bool = false,

        z_padding3: u8 = 0,

        pub fn format(
            value: Strategy,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            return internal.formatWithoutFields(
                value,
                options,
                writer,
                &.{ "z_padding", "z_padding2", "z_padding3" },
            );
        }

        test {
            try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(Strategy));
            try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(Strategy));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub const Notification = packed struct {
        /// Invokes checkout on conflicting paths.
        conflict: bool = false,

        /// Notifies about "dirty" files, i.e. those that do not need an update
        /// but no longer match the baseline.  Core git displays these files when
        /// checkout runs, but won't stop the checkout.
        dirty: bool = false,

        /// Sends notification for any file changed.
        updated: bool = false,

        /// Notifies about untracked files.
        untracked: bool = false,

        /// Notifies about ignored files.
        ignored: bool = false,

        z_padding: u11 = 0,
        z_padding2: u16 = 0,

        pub const all = @as(Notification, @bitCast(@as(c_uint, 0xFFFF)));

        test {
            try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(Notification));
            try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(Notification));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const CherrypickOptions = struct {
    mainline: bool = false,
    merge_options: git.MergeOptions = .{},
    checkout_options: git.CheckoutOptions = .{},

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
