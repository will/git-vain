const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Tree = opaque {
    pub fn deinit(self: *Tree) void {
        if (internal.trace_log) log.debug("Tree.deinit called", .{});

        c.git_tree_free(@as(*c.git_tree, @ptrCast(self)));
    }

    /// Get the id of a tree.
    pub fn getId(self: *const Tree) *const git.Oid {
        if (internal.trace_log) log.debug("Tree.id called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_tree_id(@as(*const c.git_tree, @ptrCast(self)))),
        );
    }

    /// Get the repository that contains the tree.
    pub fn owner(self: *const Tree) *git.Repository {
        if (internal.trace_log) log.debug("Tree.owner called", .{});

        return @as(
            *git.Repository,
            @ptrCast(c.git_tree_owner(@as(*const c.git_tree, @ptrCast(self)))),
        );
    }

    /// Get the number of entries listed in a tree
    pub fn entryCount(self: *const Tree) usize {
        if (internal.trace_log) log.debug("Tree.entryCount called", .{});

        return c.git_tree_entrycount(@as(*const c.git_tree, @ptrCast(self)));
    }

    /// Lookup a tree entry by its filename
    ///
    /// This returns a `git.TreeEntry` that is owned by the `git.Tree`.
    /// You don't have to free it, but you must not use it after the `git.Tree` is `deinit`ed.
    pub fn entryByName(self: *const Tree, name: [:0]const u8) ?*const TreeEntry {
        if (internal.trace_log) log.debug("Tree.entryByName called", .{});

        return @as(?*const TreeEntry, @ptrCast(c.git_tree_entry_byname(
            @as(*const c.git_tree, @ptrCast(self)),
            name.ptr,
        )));
    }

    /// Lookup a tree entry by its position in the tree
    ///
    /// This returns a `git.TreeEntry` that is owned by the `git.Tree`.
    /// You don't have to free it, but you must not use it after the `git.Tree` is `deinit`ed.
    pub fn entryByIndex(self: *const Tree, index: usize) ?*const TreeEntry {
        if (internal.trace_log) log.debug("Tree.entryByIndex called", .{});

        return @as(?*const TreeEntry, @ptrCast(c.git_tree_entry_byindex(
            @as(*const c.git_tree, @ptrCast(self)),
            index,
        )));
    }

    /// Duplicate a tree
    ///
    /// The returned tree is owned by the user and must be freed explicitly with `Tree.deinit`.
    pub fn duplicate(self: *Tree) !*Tree {
        if (internal.trace_log) log.debug("Tree.duplicate called", .{});

        var ret: *Tree = undefined;

        try internal.wrapCall("git_tree_dup", .{
            @as(*?*c.git_tree, @ptrCast(&ret)),
            @as(*c.git_tree, @ptrCast(self)),
        });

        return ret;
    }

    ///  * Lookup a tree entry by SHA value.
    ///
    /// This returns a `git.TreeEntry` that is owned by the `git.Tree`.
    /// You don't have to free it, but you must not use it after the `git.Tree` is `deinit`ed.
    ///
    /// Warning: this must examine every entry in the tree, so it is not fast.
    pub fn entryById(self: *const Tree, id: *const git.Oid) ?*const TreeEntry {
        if (internal.trace_log) log.debug("Tree.entryById called", .{});

        return @as(?*const TreeEntry, @ptrCast(c.git_tree_entry_byid(
            @as(*const c.git_tree, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        )));
    }

    /// Retrieve a tree entry contained in a tree or in any of its subtrees, given its relative path.
    ///
    /// Unlike the other lookup functions, the returned tree entry is owned by the user and must be freed explicitly with
    /// `TreeEntry.deinit`.
    pub fn entryByPath(self: *const Tree, path: [:0]const u8) !*TreeEntry {
        if (internal.trace_log) log.debug("Tree.entryByPath called", .{});

        var ret: *TreeEntry = undefined;

        try internal.wrapCall("git_tree_entry_bypath", .{
            @as(*?*c.git_tree_entry, @ptrCast(&ret)),
            @as(*const c.git_tree, @ptrCast(self)),
            path.ptr,
        });

        return ret;
    }

    /// Tree traversal modes
    pub const WalkMode = enum(c_uint) {
        pre = 0,
        post = 1,
    };

    /// Traverse the entries in a tree and its subtrees in post or pre order.
    ///
    /// The entries will be traversed in the specified order, children subtrees will be automatically loaded as required,
    /// and the `callback` will be called once per entry with the current (relative) root for the entry and the entry data itself.
    ///
    /// If the callback returns a positive value, the passed entry will be skipped on the traversal (in pre mode).
    /// A negative value stops the walk.
    ///
    /// ## Parameters
    /// * `modeTraversal mode (pre or post-order)
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `root` - The current (relative) root
    /// * `entry` - The entry
    /// * `user_data_ptr` - Pointer to user data
    pub fn walk(
        self: *const Tree,
        mode: WalkMode,
        comptime callback_fn: fn (
            root: [:0]const u8,
            entry: *const TreeEntry,
        ) c_int,
    ) !void {
        const cb = struct {
            pub fn cb(
                root: [:0]const u8,
                entry: *const TreeEntry,
                _: *u8,
            ) bool {
                return callback_fn(root, entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.walkWithUserData(&dummy_data, mode, cb);
    }

    /// Traverse the entries in a tree and its subtrees in post or pre order.
    ///
    /// The entries will be traversed in the specified order, children subtrees will be automatically loaded as required,
    /// and the `callback` will be called once per entry with the current (relative) root for the entry and the entry data itself.
    ///
    /// If the callback returns a positive value, the passed entry will be skipped on the traversal (in pre mode).
    /// A negative value stops the walk.
    ///
    /// ## Parameters
    /// * `mode` - Traversal mode (pre or post-order)
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `root` - The current (relative) root
    /// * `entry` - The entry
    /// * `user_data_ptr` - Pointer to user data
    pub fn walkWithUserData(
        self: *const Tree,
        mode: WalkMode,
        user_data: anytype,
        comptime callback_fn: fn (
            root: [:0]const u8,
            entry: *const TreeEntry,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                root: [*:0]const u8,
                entry: *const c.git_tree_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    std.mem.sliceTo(root, 0),
                    @as(*const TreeEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Tree.walkWithUserData called", .{});

        _ = try internal.wrapCallWithReturn("git_tree_walk", .{
            @as(*c.git_tree, @ptrCast(self)),
            @intFromEnum(mode),
            cb,
            user_data,
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const TreeEntry = opaque {
    pub fn deinit(self: *TreeEntry) void {
        if (internal.trace_log) log.debug("TreeEntry.deinit called", .{});

        c.git_tree_entry_free(@as(*c.git_tree_entry, @ptrCast(self)));
    }

    /// Get the filename of a tree entry
    pub fn filename(self: *const TreeEntry) [:0]const u8 {
        if (internal.trace_log) log.debug("TreeEntry.filename called", .{});

        return std.mem.sliceTo(
            c.git_tree_entry_name(@as(*const c.git_tree_entry, @ptrCast(self))),
            0,
        );
    }

    /// Get the id of the object pointed by the entry
    pub fn getId(self: *const TreeEntry) *const git.Oid {
        if (internal.trace_log) log.debug("TreeEntry.getId called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_tree_entry_id(@as(*const c.git_tree_entry, @ptrCast(self)))),
        );
    }

    /// Get the type of the object pointed by the entry
    pub fn getType(self: *const TreeEntry) git.ObjectType {
        if (internal.trace_log) log.debug("TreeEntry.getType called", .{});

        return @as(git.ObjectType, @enumFromInt(c.git_tree_entry_type(@as(*const c.git_tree_entry, @ptrCast(self)))));
    }

    /// Get the UNIX file attributes of a tree entry
    pub fn filemode(self: *const TreeEntry) git.FileMode {
        if (internal.trace_log) log.debug("TreeEntry.filemode called", .{});

        return @as(git.FileMode, @enumFromInt(c.git_tree_entry_filemode(@as(*const c.git_tree_entry, @ptrCast(self)))));
    }

    /// Get the raw UNIX file attributes of a tree entry
    ///
    /// This function does not perform any normalization and is only useful if you need to be able to recreate the
    /// original tree object.
    pub fn filemodeRaw(self: *const TreeEntry) c_uint {
        if (internal.trace_log) log.debug("TreeEntry.filemodeRaw called", .{});

        return c.git_tree_entry_filemode_raw(@as(*const c.git_tree_entry, @ptrCast(self)));
    }

    /// Compare two tree entries
    ///
    /// Returns <0 if `self` is before `other`, 0 if `self` == `other`, >0 if `self` is after `other`
    pub fn compare(self: *const TreeEntry, other: *const TreeEntry) c_int {
        if (internal.trace_log) log.debug("TreeEntry.compare called", .{});

        return c.git_tree_entry_cmp(
            @as(*const c.git_tree_entry, @ptrCast(self)),
            @as(*const c.git_tree_entry, @ptrCast(other)),
        );
    }

    /// Duplicate a tree entry
    ///
    /// The returned tree entry is owned by the user and must be freed explicitly with `TreeEntry.deinit`.
    pub fn duplicate(self: *TreeEntry) !*TreeEntry {
        if (internal.trace_log) log.debug("Tree.duplicate called", .{});

        var ret: *TreeEntry = undefined;

        try internal.wrapCall("git_tree_entry_dup", .{
            @as(*?*c.git_tree_entry, @ptrCast(&ret)),
            @as(*c.git_tree_entry, @ptrCast(self)),
        });

        return ret;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const TreeBuilder = opaque {
    /// Free a tree builder
    ///
    /// This will clear all the entries and free to builder.
    /// Failing to free the builder after you're done using it will result in a memory leak
    pub fn deinit(self: *TreeBuilder) void {
        if (internal.trace_log) log.debug("TreeBuilder.deinit called", .{});

        c.git_treebuilder_free(@as(*c.git_treebuilder, @ptrCast(self)));
    }

    /// Clear all the entires in the builder
    pub fn clear(self: *TreeBuilder) !void {
        if (internal.trace_log) log.debug("Tree.clear called", .{});

        try internal.wrapCall("git_treebuilder_clear", .{
            @as(*c.git_treebuilder, @ptrCast(self)),
        });
    }

    /// Get the number of entries listed in a treebuilder
    pub fn entryCount(self: *TreeBuilder) usize {
        if (internal.trace_log) log.debug("TreeBuilder.entryCount called", .{});

        return c.git_treebuilder_entrycount(@as(*c.git_treebuilder, @ptrCast(self)));
    }

    /// Get an entry from the builder from its filename
    ///
    /// The returned entry is owned by the builder and should not be freed manually.
    pub fn get(self: *TreeBuilder, filename: [:0]const u8) ?*const TreeEntry {
        if (internal.trace_log) log.debug("TreeBuilder.get called", .{});

        return @as(
            ?*const TreeEntry,
            @ptrCast(c.git_treebuilder_get(
                @as(*c.git_treebuilder, @ptrCast(self)),
                filename.ptr,
            )),
        );
    }

    /// Add or update an entry to the builder
    ///
    /// Insert a new entry for `filename` in the builder with the given attributes.
    ///
    /// If an entry named `filename` already exists, its attributes will be updated with the given ones.
    ///
    /// The returned pointer may not be valid past the next operation in this builder. Duplicate the entry if you want to keep it.
    ///
    /// By default the entry that you are inserting will be checked for validity; that it exists in the object database and
    /// is of the correct type. If you do not want this behavior, set `Handle.optionSetStrictObjectCreation` to false.
    pub fn insert(self: *TreeBuilder, filename: [:0]const u8, id: *const git.Oid, filemode: git.FileMode) !*const TreeEntry {
        if (internal.trace_log) log.debug("TreeBuilder.insert called", .{});

        var ret: *const TreeEntry = undefined;

        try internal.wrapCall("git_treebuilder_insert", .{
            @as(*?*const c.git_tree_entry, @ptrCast(&ret)),
            @as(*c.git_treebuilder, @ptrCast(self)),
            filename.ptr,
            @as(*const c.git_oid, @ptrCast(id)),
            @intFromEnum(filemode),
        });

        return ret;
    }

    /// Remove an entry from the builder by its filename
    pub fn remove(self: *TreeBuilder, filename: [:0]const u8) !void {
        if (internal.trace_log) log.debug("TreeBuilder.remove called", .{});

        try internal.wrapCall("git_treebuilder_remove", .{
            @as(*c.git_treebuilder, @ptrCast(self)),
            filename.ptr,
        });
    }

    /// Invoke `callback_fn` to selectively remove entries in the tree
    ///
    /// The `filter` callback will be called for each entry in the tree with a pointer to the entry;
    /// if the callback returns `true`, the entry will be filtered (removed from the builder).
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `entry` - The entry
    pub fn filter(
        self: *TreeBuilder,
        comptime callback_fn: fn (entry: *const TreeEntry) bool,
    ) !void {
        const cb = struct {
            pub fn cb(
                entry: *const TreeEntry,
                _: *u8,
            ) bool {
                return callback_fn(entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.filterWithUserData(&dummy_data, cb);
    }

    /// Invoke `callback_fn` to selectively remove entries in the tree
    ///
    /// The `filter` callback will be called for each entry in the tree with a pointer to the entry and the provided `payload`;
    /// if the callback returns `true`, the entry will be filtered (removed from the builder).
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function
    ///
    /// ## Callback Parameters
    /// * `entry` - The entry
    /// * `user_data_ptr` - Pointer to user data
    pub fn filterWithUserData(
        self: *TreeBuilder,
        user_data: anytype,
        comptime callback_fn: fn (
            entry: *const TreeEntry,
            user_data_ptr: @TypeOf(user_data),
        ) bool,
    ) !void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                entry: *const c.git_tree_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const TreeEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                ) != 0;
            }
        }.cb;

        if (internal.trace_log) log.debug("Repository.filterWithUserData called", .{});

        _ = try internal.wrapCallWithReturn("git_treebuilder_filter", .{
            @as(*c.git_treebuilder, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Write the contents of the tree builder as a tree object
    ///
    /// The tree builder will be written to the given `repo`, and its identifying SHA1 hash will be returned.
    pub fn write(self: *TreeBuilder) !git.Oid {
        if (internal.trace_log) log.debug("TreeBuilder.write called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_treebuilder_write", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_treebuilder, @ptrCast(self)),
        });

        return ret;
    }

    /// Match a pathspec against files in a tree.
    ///
    /// This matches the pathspec against the files in the given tree.
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
        self: *Tree,
        pathspec: *git.Pathspec,
        options: git.PathspecMatchOptions,
        match_list: ?**git.PathspecMatchList,
    ) !bool {
        if (internal.trace_log) log.debug("Tree.pathspecMatch called", .{});

        return (try internal.wrapCallWithReturn("git_pathspec_match_tree", .{
            @as(?*?*c.git_pathspec_match_list, @ptrCast(match_list)),
            @as(*c.git_tree, @ptrCast(self)),
            @as(c.git_pathspec_flag_t, @bitCast(options)),
            @as(*c.git_pathspec, @ptrCast(pathspec)),
        })) != 0;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
