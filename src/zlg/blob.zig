const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Blob = opaque {
    pub fn deinit(self: *Blob) void {
        if (internal.trace_log) log.debug("Blob.deinit called", .{});

        c.git_blob_free(@ptrCast(self));
    }

    pub fn id(self: *const Blob) *const git.Oid {
        if (internal.trace_log) log.debug("Blame.id called", .{});

        return @ptrCast(c.git_blob_id(@ptrCast(self)));
    }

    /// Directly generate a patch from the difference between two blobs.
    ///
    /// This is just like `Diff.blobs` except it generates a patch object for the difference instead of directly making callbacks.
    /// You can use the standard `Patch` accessor functions to read the patch data, and you must call `Patch.deinit on the patch
    /// when done.
    ///
    /// ## Parameters
    /// * `old` - Blob for old side of diff, or `null` for empty blob
    /// * `old_as_path` - Treat old blob as if it had this filename; can be `null`
    /// * `new` - Blob for new side of diff, or `null` for empty blob
    /// * `new_as_path` - Treat new blob as if it had this filename; can be `null`
    /// * `options` - Options for diff.
    pub fn toPatch(
        old: ?*const Blob,
        old_as_path: ?[:0]const u8,
        new: ?*const Blob,
        new_as_path: ?[:0]const u8,
        options: git.DiffOptions,
    ) !*git.Patch {
        if (internal.trace_log) log.debug("Blob.toPatch called", .{});

        var ret: *git.Patch = undefined;

        const c_old_as_path = if (old_as_path) |s| s.ptr else null;
        const c_new_as_path = if (new_as_path) |s| s.ptr else null;
        const c_options = internal.make_c_option.diffOptions(options);

        try internal.wrapCall("git_patch_from_blobs", .{
            @as(*?*c.git_patch, @ptrCast(&ret)),
            @as(?*const c.git_blob, @ptrCast(old)),
            c_old_as_path,
            @as(?*const c.git_blob, @ptrCast(new)),
            c_new_as_path,
            &c_options,
        });

        return ret;
    }

    /// Directly generate a patch from the difference between a blob and a buffer.
    ///
    /// This is just like `Diff.blobs` except it generates a patch object for the difference instead of directly making callbacks.
    /// You can use the standard `Patch` accessor functions to read the patch data, and you must call `Patch.deinit on the patch
    /// when done.
    ///
    /// ## Parameters
    /// * `old` - Blob for old side of diff, or `null` for empty blob
    /// * `old_as_path` - Treat old blob as if it had this filename; can be `null`
    /// * `buffer` - Raw data for new side of diff, or `null` for empty
    /// * `buffer_as_path` - Treat buffer as if it had this filename; can be `null`
    /// * `options` - Options for diff.
    pub fn patchFromBuffer(
        old: ?*const git.Blob,
        old_as_path: ?[:0]const u8,
        buffer: ?[]const u8,
        buffer_as_path: ?[:0]const u8,
        options: git.DiffOptions,
    ) !*git.Patch {
        if (internal.trace_log) log.debug("Blob.patchFromBuffer called", .{});

        var ret: *git.Patch = undefined;

        const c_old_as_path = if (old_as_path) |s| s.ptr else null;
        const c_buffer_as_path = if (buffer_as_path) |s| s.ptr else null;
        const c_options = internal.make_c_option.diffOptions(options);

        var buffer_ptr: ?[*]const u8 = null;
        var buffer_len: usize = 0;

        if (buffer) |b| {
            buffer_ptr = b.ptr;
            buffer_len = b.len;
        }

        try internal.wrapCall("git_patch_from_blob_and_buffer", .{
            @as(*?*c.git_patch, @ptrCast(&ret)),
            @as(?*const c.git_blob, @ptrCast(old)),
            c_old_as_path,
            buffer_ptr,
            buffer_len,
            c_buffer_as_path,
            &c_options,
        });

        return ret;
    }

    pub fn owner(self: *const Blob) *git.Repository {
        if (internal.trace_log) log.debug("Blame.owner called", .{});

        return @ptrCast(c.git_blob_owner(@ptrCast(self)));
    }

    pub fn rawContent(self: *const Blob) ?*const anyopaque {
        if (internal.trace_log) log.debug("Blame.rawContent called", .{});

        return c.git_blob_rawcontent(@ptrCast(self));
    }

    pub fn rawContentLength(self: *const Blob) u64 {
        if (internal.trace_log) log.debug("Blame.rawContentLength called", .{});

        return c.git_blob_rawsize(@ptrCast(self));
    }

    pub fn isBinary(self: *const Blob) bool {
        if (internal.trace_log) log.debug("Blame.isBinary called", .{});

        return c.git_blob_is_binary(@ptrCast(self)) == 1;
    }

    pub fn copy(self: *Blob) !*Blob {
        if (internal.trace_log) log.debug("Blame.copy called", .{});

        var new_blob: *Blob = undefined;

        const ret = c.git_blob_dup(@ptrCast(&new_blob), @ptrCast(self));
        // This always returns 0
        std.debug.assert(ret == 0);

        return new_blob;
    }

    pub fn filter(self: *Blob, as_path: [:0]const u8, options: BlobFilterOptions) !git.Buf {
        if (internal.trace_log) log.debug("Blob.filter called", .{});

        var buf: git.Buf = .{};

        var c_options = internal.make_c_option.blobFilterOptions(options);

        try internal.wrapCall("git_blob_filter", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_blob, @ptrCast(self)),
            as_path.ptr,
            &c_options,
        });

        return buf;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const BlobFilterOptions = struct {
    flags: BlobFilterFlags = .{},
    /// The commit to load attributes from, when `FilterFlags.attributes_from_commit` is specified.
    commit_id: ?*git.Oid = null,

    pub const BlobFilterFlags = packed struct {
        /// When set, filters will not be applied to binary files.
        check_for_binary: bool = false,

        /// When set, filters will not load configuration from the system-wide `gitattributes` in `/etc` (or system equivalent).
        no_system_attributes: bool = false,

        /// When set, filters will be loaded from a `.gitattributes` file in the HEAD commit.
        attributes_from_head: bool = false,

        /// When set, filters will be loaded from a `.gitattributes` file in the specified commit.
        attributes_from_commit: bool = false,

        z_padding: u28 = 0,

        pub fn format(
            value: BlobFilterFlags,
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
            try std.testing.expectEqual(@sizeOf(c.git_blob_filter_flag_t), @sizeOf(BlobFilterFlags));
            try std.testing.expectEqual(@bitSizeOf(c.git_blob_filter_flag_t), @bitSizeOf(BlobFilterFlags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
