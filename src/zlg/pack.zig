const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const PackBuilder = opaque {
    pub fn deinit(self: *PackBuilder) void {
        if (internal.trace_log) log.debug("PackBuilder.deinit called", .{});

        c.git_packbuilder_free(@as(*c.git_packbuilder, @ptrCast(self)));
    }

    /// Set number of threads to spawn
    ///
    /// By default, libgit2 won't spawn any threads at all; when set to 0, libgit2 will autodetect the number of CPUs.
    pub fn setThreads(self: *PackBuilder, n: c_uint) c_uint {
        if (internal.trace_log) log.debug("PackBuilder.setThreads called", .{});

        return c.git_packbuilder_set_threads(
            @as(*c.git_packbuilder, @ptrCast(self)),
            n,
        );
    }

    /// Get the total number of objects the packbuilder will write out
    pub fn objectCount(self: *PackBuilder) usize {
        if (internal.trace_log) log.debug("PackBuilder.objectCount called", .{});

        return c.git_packbuilder_object_count(@as(*c.git_packbuilder, @ptrCast(self)));
    }

    /// Get the number of objects the packbuilder has already written out
    pub fn writtenCount(self: *PackBuilder) usize {
        if (internal.trace_log) log.debug("PackBuilder.writtenCount called", .{});

        return c.git_packbuilder_written(@as(*c.git_packbuilder, @ptrCast(self)));
    }

    /// Insert a single object
    ///
    /// For an optimal pack it's mandatory to insert objects in recency order, commits followed by trees and blobs.
    pub fn insert(self: *PackBuilder, id: *const git.Oid, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("PackBuilder.insert called", .{});

        try internal.wrapCall("git_packbuilder_insert", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            name.ptr,
        });
    }

    /// Recursively insert an object and its referenced objects
    ///
    /// Insert the object as well as any object it references.
    pub fn insertRecursive(self: *PackBuilder, id: *const git.Oid, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("PackBuilder.insertRecursive called", .{});

        try internal.wrapCall("git_packbuilder_insert_recur", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            name.ptr,
        });
    }

    /// Insert a root tree object
    ///
    /// This will add the tree as well as all referenced trees and blobs.
    pub fn insertTree(self: *PackBuilder, id: *const git.Oid) !void {
        if (internal.trace_log) log.debug("PackBuilder.insertTree called", .{});

        try internal.wrapCall("git_packbuilder_insert_tree", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });
    }

    /// Insert a commit object
    ///
    /// This will add a commit as well as the completed referenced tree.
    pub fn insertCommit(self: *PackBuilder, id: *const git.Oid) !void {
        if (internal.trace_log) log.debug("PackBuilder.insertCommit called", .{});

        try internal.wrapCall("git_packbuilder_insert_commit", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
        });
    }

    /// Insert objects as given by the walk
    ///
    /// Those commits and all objects they reference will be inserted into the packbuilder.
    pub fn insertWalk(self: *PackBuilder, walk: *git.RevWalk) !void {
        if (internal.trace_log) log.debug("PackBuilder.insertWalk called", .{});

        try internal.wrapCall("git_packbuilder_insert_walk", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            @as(*c.git_revwalk, @ptrCast(walk)),
        });
    }

    /// Write the contents of the packfile to an in-memory buffer
    ///
    /// The contents of the buffer will become a valid packfile, even though there will be no attached index
    pub fn writeToBuffer(self: *PackBuilder) !git.Buf {
        if (internal.trace_log) log.debug("PackBuilder.writeToBuffer called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_packbuilder_write_buf", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_packbuilder, @ptrCast(self)),
        });

        return buf;
    }

    /// Write the new pack and corresponding index file to path.
    ///
    /// ## Parameters
    /// * `path` - Path to the directory where the packfile and index should be stored, or `null` for default location
    /// * `mode` - Permissions to use creating a packfile or 0 for defaults
    pub fn writeToFile(self: *PackBuilder, path: ?[:0]const u8, mode: c_uint) !void {
        if (internal.trace_log) log.debug("PackBuilder.writeToFile called", .{});

        const path_c = if (path) |str| str.ptr else null;

        try internal.wrapCall("git_packbuilder_write", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            path_c,
            mode,
            null,
            null,
        });
    }

    /// Write the new pack and corresponding index file to path.
    ///
    /// ## Parameters
    /// * `path` - Path to the directory where the packfile and index should be stored, or `null` for default location
    /// * `mode` - Permissions to use creating a packfile or 0 for defaults
    /// * `callback_fn` - Function to call with progress information from the indexer
    ///
    /// ## Callback Parameters
    /// * `stats` - State of the transfer
    pub fn writeToFileCallback(
        self: *PackBuilder,
        path: ?[:0]const u8,
        mode: c_uint,
        comptime callback_fn: fn (stats: *const git.IndexerProgress) c_int,
    ) !void {
        const cb = struct {
            pub fn cb(
                stats: *const git.IndexerProgress,
                _: *u8,
            ) c_int {
                return callback_fn(stats);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.writeToFileCallbackWithUserData(path, mode, &dummy_data, cb);
    }

    /// Write the new pack and corresponding index file to path.
    ///
    /// ## Parameters
    /// * `path` - Path to the directory where the packfile and index should be stored, or `null` for default location
    /// * `mode` - Permissions to use creating a packfile or 0 for defaults
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - Function to call with progress information from the indexer
    ///
    /// ## Callback Parameters
    /// * `stats` - State of the transfer
    /// * `user_data_ptr` - The user data
    pub fn writeToFileCallbackWithUserData(
        self: *PackBuilder,
        path: ?[:0]const u8,
        mode: c_uint,
        user_data: anytype,
        comptime callback_fn: fn (
            stats: *const git.IndexerProgress,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                stats: *const c.git_indexer_progress,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.IndexerProgress, @ptrCast(stats)),
                    @as(UserDataType, @ptrCast(@alignCast( payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("PackBuilder.writeToFileCallbackWithUserData called", .{});

        const path_c = if (path) |str| str.ptr else null;

        try internal.wrapCall("git_packbuilder_write", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            path_c,
            mode,
            cb,
            user_data,
        });
    }

    /// Get the packfile's hash
    ///
    /// A packfile's name is derived from the sorted hashing of all object names.
    /// This is only correct after the packfile has been written.
    pub fn hash(self: *PackBuilder) *const git.Oid {
        if (internal.trace_log) log.debug("PackBuilder.hash called", .{});

        const ret = @as(
            *const git.Oid,
            @ptrCast(c.git_packbuilder_hash(@as(*c.git_packbuilder, @ptrCast(self)))),
        );

        return ret;
    }

    /// Create the new pack and pass each object to the callback
    ///
    /// Return non-zero from the callback to terminate the iteration
    ///
    /// ## Parameters
    /// * `callback_fn` - The callback to call with each packed object's buffer
    ///
    /// ## Callback Parameters
    /// * `object_data` - Slice of the objects data
    pub fn foreach(
        self: *PackBuilder,
        comptime callback_fn: fn (object_data: []u8) c_int,
    ) !void {
        const cb = struct {
            pub fn cb(
                object_data: []u8,
                _: *u8,
            ) c_int {
                return callback_fn(object_data);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachWithUserData(&dummy_data, cb);
    }

    /// Create the new pack and pass each object to the callback
    ///
    /// Return non-zero from the callback to terminate the iteration
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback to call with each packed object's buffer
    ///
    /// ## Callback Parameters
    /// * `object_data` - Slice of the objects data
    /// * `user_data_ptr` - The user data
    pub fn foreachWithUserData(
        self: *PackBuilder,
        user_data: anytype,
        comptime callback_fn: fn (
            object_data: []u8,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                ptr: ?*anyopaque,
                len: usize,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as([*]u8, @ptrCast(ptr))[0..len],
                    @as(UserDataType, @ptrCast(@alignCast( payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("PackBuilder.foreachWithUserData called", .{});

        try internal.wrapCall("git_packbuilder_foreach", .{
            @as(*c.git_packbuilder, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Set the callbacks for a packbuilder
    ///
    /// ## Parameters
    /// * `callback_fn` - Function to call with progress information during pack building.
    ///                   Be aware that this is called inline with pack building operations, so performance may be affected.
    pub fn setCallbacks(
        self: *PackBuilder,
        comptime callback_fn: fn (
            stage: PackbuilderStage,
            current: u32,
            total: u32,
        ) void,
    ) void {
        const cb = struct {
            pub fn cb(
                stage: PackbuilderStage,
                current: u32,
                total: u32,
                _: *u8,
            ) void {
                callback_fn(stage, current, total);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.setCallbacksWithUserData(&dummy_data, cb);
    }

    /// Set the callbacks for a packbuilder
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - Function to call with progress information during pack building.
    ///                   Be aware that this is called inline with pack building operations, so performance may be affected.
    pub fn setCallbacksWithUserData(
        self: *PackBuilder,
        user_data: anytype,
        comptime callback_fn: fn (
            stage: PackbuilderStage,
            current: u32,
            total: u32,
            user_data_ptr: @TypeOf(user_data),
        ) void,
    ) void {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                stage: c_int,
                current: u32,
                total: u32,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                callback_fn(
                    @as(PackbuilderStage, @enumFromInt(stage)),
                    current,
                    total,
                    @as(UserDataType, @ptrCast(@alignCast( payload))),
                );
                return 0;
            }
        }.cb;

        if (internal.trace_log) log.debug("PackBuilder.setCallbacksWithUserData called", .{});

        _ = c.git_packbuilder_set_callbacks(
            @as(*c.git_packbuilder, @ptrCast(self)),
            cb,
            user_data,
        );
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Stages that are reported by the packbuilder progress callback.
pub const PackbuilderStage = enum(c_uint) {
    adding_objects = 0,
    deltafication = 1,
};

comptime {
    std.testing.refAllDecls(@This());
}
