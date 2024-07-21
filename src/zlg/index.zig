const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");
const bitjuggle = @import("internal/bitjuggle.zig");

pub const Index = opaque {
    pub fn deinit(self: *Index) void {
        if (internal.trace_log) log.debug("Index.deinit called", .{});

        c.git_index_free(@as(*c.git_index, @ptrCast(self)));
    }

    pub fn versionGet(self: *Index) !IndexVersion {
        if (internal.trace_log) log.debug("Index.versionGet called", .{});

        const raw_value = c.git_index_version(@as(*c.git_index, @ptrCast(self)));

        return if (std.meta.intToEnum(IndexVersion, raw_value)) |version| version else |_| error.InvalidVersion;
    }

    pub fn versionSet(self: *Index, version: IndexVersion) !void {
        if (internal.trace_log) log.debug("Index.setVersion called", .{});

        try internal.wrapCall("git_index_set_version", .{ @as(*c.git_index, @ptrCast(self)), @intFromEnum(version) });
    }

    pub const IndexVersion = enum(c_uint) {
        @"2" = 2,
        @"3" = 3,
        @"4" = 4,
    };

    /// Update the contents of this index by reading from the hard disk.
    ///
    /// If `force` is true, in-memory changes are discarded.
    pub fn readIndexFromDisk(self: *Index, force: bool) !void {
        if (internal.trace_log) log.debug("Index.readIndexFromDisk called", .{});

        try internal.wrapCall("git_index_read", .{ @as(*c.git_index, @ptrCast(self)), @intFromBool(force) });
    }

    pub fn writeToDisk(self: *Index) !void {
        if (internal.trace_log) log.debug("Index.writeToDisk called", .{});

        try internal.wrapCall("git_index_write", .{@as(*c.git_index, @ptrCast(self))});
    }

    pub fn pathGet(self: *const Index) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Index.pathGet called", .{});

        return if (c.git_index_path(@as(*const c.git_index, @ptrCast(self)))) |ptr| std.mem.sliceTo(ptr, 0) else null;
    }

    pub fn repositoryGet(self: *const Index) ?*git.Repository {
        if (internal.trace_log) log.debug("Index.repositoryGet called", .{});

        return @as(
            ?*git.Repository,
            @ptrCast(c.git_index_owner(@as(*const c.git_index, @ptrCast(self)))),
        );
    }

    /// Get the checksum of the index
    ///
    /// This checksum is the SHA-1 hash over the index file (except the last 20 bytes which are the checksum itself). In cases
    /// where the index does not exist on-disk, it will be zeroed out.
    pub fn checksum(self: *Index) !*const git.Oid {
        if (internal.trace_log) log.debug("Index.checksum called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_index_checksum(@as(*c.git_index, @ptrCast(self)))),
        );
    }

    pub fn setToTree(self: *Index, tree: *const git.Tree) !void {
        if (internal.trace_log) log.debug("Index.setToTree called", .{});

        try internal.wrapCall("git_index_read_tree", .{
            @as(*c.git_index, @ptrCast(self)),
            @as(*const c.git_tree, @ptrCast(tree)),
        });
    }

    pub fn writeToTreeOnDisk(self: *Index) !git.Oid {
        if (internal.trace_log) log.debug("Index.writeToTreeOnDisk called", .{});

        var oid: git.Oid = undefined;

        try internal.wrapCall("git_index_write_tree", .{ @as(*c.git_oid, @ptrCast(&oid)), @as(*c.git_index, @ptrCast(self)) });

        return oid;
    }

    pub fn entryCount(self: *const Index) usize {
        if (internal.trace_log) log.debug("Index.entryCount called", .{});

        return c.git_index_entrycount(@as(*const c.git_index, @ptrCast(self)));
    }

    /// Clear the contents of this index.
    ///
    /// This clears the index in memory; changes must be written to disk for them to be persistent.
    pub fn clear(self: *Index) !void {
        if (internal.trace_log) log.debug("Index.clear called", .{});

        try internal.wrapCall("git_index_clear", .{@as(*c.git_index, @ptrCast(self))});
    }

    pub fn writeToTreeInRepository(self: *Index, repository: *git.Repository) !git.Oid {
        if (internal.trace_log) log.debug("Index.writeToTreeIngit.Repository called", .{});

        var oid: git.Oid = undefined;

        try internal.wrapCall("git_index_write_tree_to", .{
            @as(*c.git_oid, @ptrCast(&oid)),
            @as(*c.git_index, @ptrCast(self)),
            @as(*c.git_repository, @ptrCast(repository)),
        });

        return oid;
    }

    pub fn indexCapabilities(self: *const Index) IndexCapabilities {
        if (internal.trace_log) log.debug("Index.indexCapabilities called", .{});

        return @as(IndexCapabilities, @bitCast(c.git_index_caps(@as(*const c.git_index, @ptrCast(self)))));
    }

    /// If you pass `IndexCapabilities.from_owner` for the capabilities, then capabilities will be read from the config of the
    /// owner object, looking at `core.ignorecase`, `core.filemode`, `core.symlinks`.
    pub fn indexCapabilitiesSet(self: *Index, capabilities: IndexCapabilities) !void {
        if (internal.trace_log) log.debug("Index.getIndexCapabilities called", .{});

        try internal.wrapCall("git_index_set_caps", .{ @as(*c.git_index, @ptrCast(self)), @as(c_int, @bitCast(capabilities)) });
    }

    pub const IndexCapabilities = packed struct {
        ignore_case: bool = false,
        no_filemode: bool = false,
        no_symlinks: bool = false,

        z_padding1: u13 = 0,
        z_padding2: u16 = 0,

        pub fn isGetCapabilitiesFromOwner(self: IndexCapabilities) bool {
            return @as(c_int, @bitCast(self)) == -1;
        }

        pub const get_capabilities_from_owner: IndexCapabilities = @as(IndexCapabilities, @bitCast(@as(c_int, -1)));

        pub fn format(
            value: IndexCapabilities,
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
            try std.testing.expectEqual(@sizeOf(c_int), @sizeOf(IndexCapabilities));
            try std.testing.expectEqual(@bitSizeOf(c_int), @bitSizeOf(IndexCapabilities));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub fn entryByIndex(self: *Index, index: usize) ?*const IndexEntry {
        if (internal.trace_log) log.debug("Index.entryByIndex called", .{});

        return @as(
            ?*const IndexEntry,
            @ptrCast(c.git_index_get_byindex(@as(*c.git_index, @ptrCast(self)), index)),
        );
    }

    pub fn entryByPath(self: *Index, path: [:0]const u8, stage: c_int) ?*const IndexEntry {
        if (internal.trace_log) log.debug("Index.entryByPath called", .{});

        return @as(
            ?*const IndexEntry,
            @ptrCast(c.git_index_get_bypath(@as(*c.git_index, @ptrCast(self)), path.ptr, stage)),
        );
    }

    pub fn remove(self: *Index, path: [:0]const u8, stage: c_int) !void {
        if (internal.trace_log) log.debug("Index.remove called", .{});

        try internal.wrapCall("git_index_remove", .{ @as(*c.git_index, @ptrCast(self)), path.ptr, stage });
    }

    pub fn directoryRemove(self: *Index, path: [:0]const u8, stage: c_int) !void {
        if (internal.trace_log) log.debug("Index.directoryRemove called", .{});

        try internal.wrapCall("git_index_remove_directory", .{ @as(*c.git_index, @ptrCast(self)), path.ptr, stage });
    }

    pub fn add(self: *Index, entry: *const IndexEntry) !void {
        if (internal.trace_log) log.debug("Index.add called", .{});

        try internal.wrapCall("git_index_add", .{ @as(*c.git_index, @ptrCast(self)), @as(*const c.git_index_entry, @ptrCast(entry)) });
    }

    /// The `path` must be relative to the repository's working folder.
    ///
    /// This forces the file to be added to the index, not looking at gitignore rules. Those rules can be evaluated using
    /// `git.Repository.statusShouldIgnore`.
    pub fn addByPath(self: *Index, path: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Index.addByPath called", .{});

        try internal.wrapCall("git_index_add_bypath", .{ @as(*c.git_index, @ptrCast(self)), path.ptr });
    }

    pub fn addFromBuffer(self: *Index, index_entry: *const IndexEntry, buffer: []const u8) !void {
        if (internal.trace_log) log.debug("Index.addFromBuffer called", .{});

        if (@hasDecl(c, "git_index_add_from_buffer")) {
            try internal.wrapCall(
                "git_index_add_from_buffer",
                .{ @as(*c.git_index, @ptrCast(self)), @as(*const c.git_index_entry, @ptrCast(index_entry)), buffer.ptr, buffer.len },
            );
        } else {
            try internal.wrapCall(
                "git_index_add_frombuffer",
                .{ @as(*c.git_index, @ptrCast(self)), @as(*const c.git_index_entry, @ptrCast(index_entry)), buffer.ptr, buffer.len },
            );
        }
    }

    pub fn removeByPath(self: *Index, path: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Index.removeByPath called", .{});

        try internal.wrapCall("git_index_remove_bypath", .{ @as(*c.git_index, @ptrCast(self)), path.ptr });
    }

    pub fn iterate(self: *Index) !*IndexIterator {
        if (internal.trace_log) log.debug("Index.iterate called", .{});

        var iterator: *IndexIterator = undefined;

        try internal.wrapCall("git_index_iterator_new", .{
            @as(*?*c.git_index_iterator, @ptrCast(&iterator)),
            @as(*c.git_index, @ptrCast(self)),
        });

        return iterator;
    }

    pub const IndexIterator = opaque {
        pub fn next(self: *IndexIterator) !?*const IndexEntry {
            if (internal.trace_log) log.debug("IndexIterator.next called", .{});

            var index_entry: *const IndexEntry = undefined;

            internal.wrapCall("git_index_iterator_next", .{
                @as(*?*c.git_index_entry, @ptrCast(&index_entry)),
                @as(*c.git_index_iterator, @ptrCast(self)),
            }) catch |err| switch (err) {
                git.GitError.IterOver => return null,
                else => |e| return e,
            };

            return index_entry;
        }

        pub fn deinit(self: *IndexIterator) void {
            if (internal.trace_log) log.debug("IndexIterator.deinit called", .{});

            c.git_index_iterator_free(@as(*c.git_index_iterator, @ptrCast(self)));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Remove all matching index entries.
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is removed.  Returning zero will remove the item, greater than zero will skip the item, and less than zero will abort
    /// the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `callback_fn` - The callback function; return 0 to remove, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    pub fn removeAll(
        self: *Index,
        pathspec: *const git.StrArray,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
        ) c_int,
    ) !c_int {
        if (callback_fn) |callback| {
            const cb = struct {
                pub fn cb(
                    path: [:0]const u8,
                    matched_pathspec: [:0]const u8,
                    _: *u8,
                ) c_int {
                    return callback(path, matched_pathspec);
                }
            }.cb;

            var dummy_data: u8 = undefined;
            return self.removeAllWithUserData(pathspec, &dummy_data, cb);
        } else {
            return self.removeAllWithUserData(pathspec, null, null);
        }
    }

    /// Remove all matching index entries.
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is removed.  Returning zero will remove the item, greater than zero will skip the item, and less than zero will abort
    /// the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function; return 0 to remove, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    /// * `user_data_ptr` - The user data
    pub fn removeAllWithUserData(
        self: *Index,
        pathspec: *const git.StrArray,
        user_data: anytype,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
            user_data_ptr: @TypeOf(user_data),
        ) void,
    ) !c_int {
        if (internal.trace_log) log.debug("Index.removeAllWithUserData called", .{});

        if (callback_fn) |callback| {
            const UserDataType = @TypeOf(user_data);

            const cb = struct {
                pub fn cb(
                    path: [*:0]const u8,
                    matched_pathspec: [*:0]const u8,
                    payload: ?*anyopaque,
                ) callconv(.C) c_int {
                    return callback(
                        std.mem.sliceTo(path, 0),
                        std.mem.sliceTo(matched_pathspec, 0),
                        @as(UserDataType, @ptrCast(@alignCast(payload))),
                    );
                }
            }.cb;

            return try internal.wrapCallWithReturn("git_index_remove_all", .{
                @as(*const c.git_index, @ptrCast(self)),
                @as(*const c.git_strarray, @ptrCast(pathspec)),
                cb,
                user_data,
            });
        }

        _ = try internal.wrapCall("git_index_remove_all", .{
            @as(*const c.git_index, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(pathspec)),
            null,
            null,
        });

        return 0;
    }

    /// Update all index entries to match the working directory
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is updated.  Returning zero will update the item, greater than zero will skip the item, and less than zero will abort
    /// the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `callback_fn` - The callback function; return 0 to update, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    pub fn updateAll(
        self: *Index,
        pathspec: *const git.StrArray,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
        ) c_int,
    ) !c_int {
        if (callback_fn) |callback| {
            const cb = struct {
                pub fn cb(
                    path: [:0]const u8,
                    matched_pathspec: [:0]const u8,
                    _: *u8,
                ) c_int {
                    return callback(path, matched_pathspec);
                }
            }.cb;

            var dummy_data: u8 = undefined;
            return self.updateAllWithUserData(pathspec, &dummy_data, cb);
        }

        return self.updateAllWithUserData(pathspec, null, null);
    }

    /// Update all index entries to match the working directory
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is updated.  Returning zero will update the item, greater than zero will skip the item, and less than zero will abort
    /// the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function; return 0 to update, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    /// * `user_data_ptr` - The user data
    pub fn updateAllWithUserData(
        self: *Index,
        pathspec: *const git.StrArray,
        user_data: anytype,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
            user_data_ptr: @TypeOf(user_data),
        ) void,
    ) !c_int {
        if (internal.trace_log) log.debug("Index.updateAllWithUserData called", .{});

        if (callback_fn) |callback| {
            const UserDataType = @TypeOf(user_data);

            const cb = struct {
                pub fn cb(
                    path: [*:0]const u8,
                    matched_pathspec: [*:0]const u8,
                    payload: ?*anyopaque,
                ) callconv(.C) c_int {
                    return callback(
                        std.mem.sliceTo(path, 0),
                        std.mem.sliceTo(matched_pathspec, 0),
                        @as(UserDataType, @ptrCast(@alignCast(payload))),
                    );
                }
            }.cb;

            return try internal.wrapCallWithReturn("git_index_update_all", .{
                @as(*const c.git_index, @ptrCast(self)),
                @as(*const c.git_strarray, @ptrCast(pathspec)),
                cb,
                user_data,
            });
        }

        _ = try internal.wrapCall("git_index_update_all", .{
            @as(*const c.git_index, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(pathspec)),
            null,
            null,
        });

        return 0;
    }

    /// Add or update index entries matching files in the working directory.
    ///
    /// The `pathspec` is a list of file names or shell glob patterns that will be matched against files in the repository's
    /// working directory. Each file that matches will be added to the index (either updating an existing entry or adding a new
    /// entry).  You can disable glob expansion and force exact matching with the `IndexAddFlags.disable_pathspec_match` flag.
    /// Invoke `callback_fn` for each entry in the given FETCH_HEAD file.
    ///
    /// Files that are ignored will be skipped (unlike `Index.AddByPath`). If a file is already tracked in the index, then it
    /// *will* be updated even if it is ignored. Pass the `IndexAddFlags.force` flag to skip the checking of ignore rules.
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is added to/updated in the index.  Returning zero will add the item to the index, greater than zero will skip the item,
    /// and less than zero will abort the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `flags` - Flags controlling how the add is performed
    /// * `callback_fn` - The callback function; return 0 to add, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    pub fn addAll(
        self: *Index,
        pathspec: *const git.StrArray,
        flags: IndexAddFlags,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
        ) c_int,
    ) !c_int {
        if (callback_fn) |callback| {
            const cb = struct {
                pub fn cb(
                    path: [:0]const u8,
                    matched_pathspec: [:0]const u8,
                    _: *u8,
                ) c_int {
                    return callback(path, matched_pathspec);
                }
            }.cb;

            var dummy_data: u8 = undefined;
            return self.addAllWithUserData(pathspec, flags, &dummy_data, cb);
        } else {
            return self.addAllWithUserData(pathspec, flags, null, null);
        }
    }

    /// Add or update index entries matching files in the working directory.
    ///
    /// The `pathspec` is a list of file names or shell glob patterns that will be matched against files in the repository's
    /// working directory. Each file that matches will be added to the index (either updating an existing entry or adding a new
    /// entry).  You can disable glob expansion and force exact matching with the `IndexAddFlags.disable_pathspec_match` flag.
    /// Invoke `callback_fn` for each entry in the given FETCH_HEAD file.
    ///
    /// Files that are ignored will be skipped (unlike `Index.AddByPath`). If a file is already tracked in the index, then it
    /// *will* be updated even if it is ignored. Pass the `IndexAddFlags.force` flag to skip the checking of ignore rules.
    ///
    /// If you provide a callback function, it will be invoked on each matching item in the working directory immediately *before*
    /// it is added to/updated in the index.  Returning zero will add the item to the index, greater than zero will skip the item,
    /// and less than zero will abort the scan and return that value to the caller.
    ///
    /// ## Parameters
    /// * `pathspec` - Array of path patterns
    /// * `flags` - Flags controlling how the add is performed
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function; return 0 to add, < 0 to abort, > 0 to skip.
    ///
    /// ## Callback Parameters
    /// * `path` - The reference name
    /// * `matched_pathspec` - The remote URL
    /// * `user_data_ptr` - The user data
    pub fn addAllWithUserData(
        self: *Index,
        pathspec: *const git.StrArray,
        flags: IndexAddFlags,
        user_data: anytype,
        comptime callback_fn: ?fn (
            path: [:0]const u8,
            matched_pathspec: [:0]const u8,
            user_data_ptr: @TypeOf(user_data),
        ) void,
    ) !c_int {
        if (internal.trace_log) log.debug("Index.addAllWithUserData called", .{});

        if (callback_fn) |callback| {
            const UserDataType = @TypeOf(user_data);

            const cb = struct {
                pub fn cb(
                    path: [*:0]const u8,
                    matched_pathspec: [*:0]const u8,
                    payload: ?*anyopaque,
                ) callconv(.C) c_int {
                    return callback(
                        std.mem.sliceTo(path, 0),
                        std.mem.sliceTo(matched_pathspec, 0),
                        @as(UserDataType, @ptrCast(@alignCast(payload))),
                    );
                }
            }.cb;

            return try internal.wrapCallWithReturn("git_index_add_all", .{
                @as(*const c.git_index, @ptrCast(self)),
                @as(*const c.git_strarray, @ptrCast(pathspec)),
                @as(c_int, @bitCast(flags)),
                cb,
                user_data,
            });
        }

        _ = try internal.wrapCall("git_index_add_all", .{
            @as(*const c.git_index, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(pathspec)),
            @as(c_int, @bitCast(flags)),
            null,
            null,
        });

        return 0;
    }

    pub fn find(self: *Index, path: [:0]const u8) !usize {
        if (internal.trace_log) log.debug("Index.find called", .{});

        var position: usize = 0;

        try internal.wrapCall("git_index_find", .{ &position, @as(*c.git_index, @ptrCast(self)), path.ptr });

        return position;
    }

    pub fn findPrefix(self: *Index, prefix: [:0]const u8) !usize {
        if (internal.trace_log) log.debug("Index.find called", .{});

        var position: usize = 0;

        try internal.wrapCall("git_index_find_prefix", .{ &position, @as(*c.git_index, @ptrCast(self)), prefix.ptr });

        return position;
    }

    /// Add or update index entries to represent a conflict.  Any staged entries that exist at the given paths will be removed.
    ///
    /// The entries are the entries from the tree included in the merge.  Any entry may be null to indicate that that file was not
    /// present in the trees during the merge. For example, `ancestor_entry` may be `null` to indicate that a file was added in
    /// both branches and must be resolved.
    pub fn conflictAdd(
        self: *Index,
        ancestor_entry: ?*const IndexEntry,
        our_entry: ?*const IndexEntry,
        their_entry: ?*const IndexEntry,
    ) !void {
        if (internal.trace_log) log.debug("Index.conflictAdd called", .{});

        try internal.wrapCall("git_index_conflict_add", .{
            @as(*c.git_index, @ptrCast(self)),
            @as(?*const c.git_index_entry, @ptrCast(ancestor_entry)),
            @as(?*const c.git_index_entry, @ptrCast(our_entry)),
            @as(?*const c.git_index_entry, @ptrCast(their_entry)),
        });
    }

    /// Get the index entries that represent a conflict of a single file.
    ///
    /// *IMPORTANT*: These entries should *not* be freed.
    pub fn conflictGet(self: *Index, path: [:0]const u8) !Conflicts {
        if (internal.trace_log) log.debug("Index.conflictGet called", .{});

        var ancestor_out: *const IndexEntry = undefined;
        var our_out: *const IndexEntry = undefined;
        var their_out: *const IndexEntry = undefined;

        try internal.wrapCall("git_index_conflict_get", .{
            @as(*?*const c.git_index_entry, @ptrCast(&ancestor_out)),
            @as(*?*const c.git_index_entry, @ptrCast(&our_out)),
            @as(*?*const c.git_index_entry, @ptrCast(&their_out)),
            @as(*c.git_index, @ptrCast(self)),
            path.ptr,
        });

        return Conflicts{
            .ancestor = ancestor_out,
            .our = our_out,
            .their = their_out,
        };
    }

    pub fn conlfictRemove(self: *Index, path: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Index.conlfictRemove called", .{});

        try internal.wrapCall("git_index_conflict_remove", .{ @as(*c.git_index, @ptrCast(self)), path.ptr });
    }

    /// Remove all conflicts in the index
    pub fn conflictCleanup(self: *Index) !void {
        if (internal.trace_log) log.debug("Index.conflictCleanup called", .{});

        try internal.wrapCall("git_index_conflict_cleanup", .{@as(*c.git_index, @ptrCast(self))});
    }

    pub fn hasConflicts(self: *const Index) bool {
        if (internal.trace_log) log.debug("Index.hasConflicts called", .{});

        return c.git_index_has_conflicts(@as(*const c.git_index, @ptrCast(self))) == 1;
    }

    pub const IndexConflictIterator = opaque {
        pub fn next(self: *IndexConflictIterator) !?Conflicts {
            if (internal.trace_log) log.debug("IndexConflictIterator.next called", .{});

            var ancestor_out: *const IndexEntry = undefined;
            var our_out: *const IndexEntry = undefined;
            var their_out: *const IndexEntry = undefined;

            internal.wrapCall("git_index_conflict_next", .{
                @as(*?*const c.git_index_entry, @ptrCast(&ancestor_out)),
                @as(*?*const c.git_index_entry, @ptrCast(&our_out)),
                @as(*?*const c.git_index_entry, @ptrCast(&their_out)),
                @as(*c.git_index_conflict_iterator, @ptrCast(self)),
            }) catch |err| switch (err) {
                git.GitError.IterOver => return null,
                else => |e| return e,
            };

            return Conflicts{
                .ancestor = ancestor_out,
                .our = our_out,
                .their = their_out,
            };
        }

        pub fn deinit(self: *IndexConflictIterator) void {
            if (internal.trace_log) log.debug("IndexConflictIterator.deinit called", .{});

            c.git_index_conflict_iterator_free(@as(*c.git_index_conflict_iterator, @ptrCast(self)));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub const Conflicts = struct {
        ancestor: *const IndexEntry,
        our: *const IndexEntry,
        their: *const IndexEntry,
    };

    pub const IndexEntry = extern struct {
        ctime: IndexTime,
        mtime: IndexTime,
        dev: u32,
        ino: u32,
        mode: u32,
        uid: u32,
        gid: u32,
        file_size: u32,
        id: git.Oid,
        flags: Flags,
        flags_extended: ExtendedFlags,
        raw_path: [*:0]const u8,

        pub fn path(self: IndexEntry) [:0]const u8 {
            return std.mem.sliceTo(self.raw_path, 0);
        }

        pub fn stage(self: IndexEntry) c_int {
            return @as(c_int, @intCast(self.flags.stage.read()));
        }

        pub fn isConflict(self: IndexEntry) bool {
            return self.stage() > 0;
        }

        pub const IndexTime = extern struct {
            seconds: i32,
            nanoseconds: u32,

            test {
                try std.testing.expectEqual(@sizeOf(c.git_index_time), @sizeOf(IndexTime));
                try std.testing.expectEqual(@bitSizeOf(c.git_index_time), @bitSizeOf(IndexTime));
            }

            comptime {
                std.testing.refAllDecls(@This());
            }
        };

        pub const Flags = extern union {
            name: bitjuggle.Bitfield(u16, 0, 12),
            stage: bitjuggle.Bitfield(u16, 12, 2),
            extended: bitjuggle.Bit(u16, 14),
            valid: bitjuggle.Bit(u16, 15),

            test {
                try std.testing.expectEqual(@sizeOf(u16), @sizeOf(Flags));
                try std.testing.expectEqual(@bitSizeOf(u16), @bitSizeOf(Flags));
            }
        };

        pub const ExtendedFlags = extern union {
            intent_to_add: bitjuggle.Bit(u16, 13),
            skip_worktree: bitjuggle.Bit(u16, 14),
            uptodate: bitjuggle.Bit(u16, 2),

            test {
                try std.testing.expectEqual(@sizeOf(u16), @sizeOf(ExtendedFlags));
                try std.testing.expectEqual(@bitSizeOf(u16), @bitSizeOf(ExtendedFlags));
            }
        };

        test {
            try std.testing.expectEqual(@sizeOf(c.git_index_entry), @sizeOf(IndexEntry));
            try std.testing.expectEqual(@bitSizeOf(c.git_index_entry), @bitSizeOf(IndexEntry));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Match a pathspec against entries in an index.
    ///
    /// This matches the pathspec against the files in the repository index.
    ///
    /// NOTE: At the moment, the case sensitivity of this match is controlled by the current case-sensitivity of the index object
    /// itself and the `MatchOptions.use_case` and `MatchOptions.ignore_case` options will have no effect.
    /// This behavior will be corrected in a future release.
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
    pub fn pathspecMatch(
        self: *Index,
        pathspec: *git.Pathspec,
        options: git.PathspecMatchOptions,
        match_list: ?**git.PathspecMatchList,
    ) !bool {
        if (internal.trace_log) log.debug("Index.pathspecMatch called", .{});

        return (try internal.wrapCallWithReturn("git_pathspec_match_index", .{
            @as(?*?*c.git_pathspec_match_list, @ptrCast(match_list)),
            @as(*c.git_index, @ptrCast(self)),
            @as(c.git_pathspec_flag_t, @bitCast(options)),
            @as(*c.git_pathspec, @ptrCast(pathspec)),
        })) != 0;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const IndexAddFlags = packed struct {
    force: bool = false,
    disable_pathspec_match: bool = false,
    check_pathspec: bool = false,

    z_padding: u29 = 0,

    pub fn format(
        value: IndexAddFlags,
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
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(IndexAddFlags));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(IndexAddFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
