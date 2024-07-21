const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Filters are applied in one of two directions: smudging - which is exporting a file from the Git object database to the working
/// directory, and cleaning - which is importing a file from the working directory to the Git object database. These values
/// control which direction of change is being applied.
pub const FilterMode = enum(c_uint) {
    to_worktree = 0,
    to_odb = 1,

    pub const smudge = FilterMode.to_worktree;
    pub const clean = FilterMode.to_odb;
};

pub const FilterFlags = packed struct {
    /// Don't error for `safecrlf` violations, allow them to continue.
    allow_unsafe: bool = false,

    /// Don't load `/etc/gitattributes` (or the system equivalent)
    no_system_attributes: bool = false,

    /// Load attributes from `.gitattributes` in the root of HEAD
    attributes_from_head: bool = false,

    /// Load attributes from `.gitattributes` in a given commit. This can only be specified in a `FilterOptions`
    attributes_from_commit: bool = false,

    z_padding: u28 = 0,

    pub fn format(
        value: FilterFlags,
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
        try std.testing.expectEqual(@sizeOf(c.git_filter_flag_t), @sizeOf(FilterFlags));
        try std.testing.expectEqual(@bitSizeOf(c.git_filter_flag_t), @bitSizeOf(FilterFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const FilterOptions = struct {
    flags: FilterFlags = .{},

    /// The commit to load attributes from, when `FilterFlags.attributes_from_commit` is specified.
    commit_id: ?*git.Oid = null,

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A filter that can transform file data
///
/// This represents a filter that can be used to transform or even replace file data.
/// Libgit2 includes one built in filter and it is possible to write your own (see git2/sys/filter.h for information on that).
///
/// The two builtin filters are:
///
/// - "crlf" which uses the complex rules with the "text", "eol", and "crlf" file attributes to decide how to convert between LF
///   and CRLF line endings
/// - "ident" which replaces "$Id$" in a blob with "$Id: <blob OID>$" upon checkout and replaced "$Id: <anything>$" with "$Id$" on
///   checkin.
pub const Filter = opaque {
    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// List of filters to be applied
///
/// This represents a list of filters to be applied to a file / blob. You can build the list with one call, apply it with another,
/// and dispose it with a third. In typical usage, there are not many occasions where a `FilterList` is needed directly since the
/// library will generally handle conversions for you, but it can be convenient to be able to build and apply the list sometimes.
pub const FilterList = opaque {
    /// Query the filter list to see if a given filter (by name) will run.
    /// The built-in filters "crlf" and "ident" can be queried, otherwise this is the name of the filter specified by the filter
    /// attribute.
    ///
    /// ## Parameters
    /// * `name` - The name of the filter to query
    pub fn contains(self: *FilterList, name: [:0]const u8) bool {
        if (internal.trace_log) log.debug("FilterList.contains called", .{});

        return c.git_filter_list_contains(@as(*c.git_filter_list, @ptrCast(self)), name.ptr) != 0;
    }

    /// Apply a filter list to the contents of a file on disk
    ///
    /// ## Parameters
    /// * `repo` - The repository in which to perform the filtering
    /// * `path` - The path of the file to filter, a relative path will be taken as relative to the workdir
    pub fn applyToFile(self: *FilterList, repo: *git.Repository, path: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("FilterList.applyToFile called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_filter_list_apply_to_file", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*c.git_filter_list, @ptrCast(self)),
            @as(*c.git_repository, @ptrCast(repo)),
            path.ptr,
        });

        return ret;
    }

    /// Apply a filter list to the contents of a blob
    ///
    /// ## Parameters
    /// * `blob` - The blob to filter
    pub fn applyToBlob(self: *FilterList, blob: *git.Blob) !git.Buf {
        if (internal.trace_log) log.debug("FilterList.applyToBlob called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_filter_list_apply_to_blob", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*c.git_filter_list, @ptrCast(self)),
            @as(*c.git_blob, @ptrCast(blob)),
        });

        return ret;
    }

    /// Apply a filter list to a file as a stream
    ///
    /// ## Parameters
    /// * `repo` - The repository in which to perform the filtering
    /// * `path` - The path of the file to filter, a relative path will be taken as relative to the workdir
    /// * `target` - The stream into which the data will be written
    pub fn applyToFileToStream(
        self: *FilterList,
        repo: *git.Repository,
        path: [:0]const u8,
        target: *git.WriteStream,
    ) !void {
        if (internal.trace_log) log.debug("FilterList.applyToFileToStream called", .{});

        try internal.wrapCall("git_filter_list_stream_file", .{
            @as(*c.git_filter_list, @ptrCast(self)),
            @as(*c.git_repository, @ptrCast(repo)),
            path.ptr,
            @as(*c.git_writestream, @ptrCast(target)),
        });
    }

    /// Apply a filter list to a blob as a stream
    ///
    /// ## Parameters
    /// * `blob` - The blob to filter
    /// * `target` - The stream into which the data will be written
    pub fn applyToBlobToStream(self: *FilterList, blob: *git.Blob, target: *git.WriteStream) !void {
        if (internal.trace_log) log.debug("FilterList.applyToBlobToStream called", .{});

        try internal.wrapCall("git_filter_list_stream_blob", .{
            @as(*c.git_filter_list, @ptrCast(self)),
            @as(*c.git_blob, @ptrCast(blob)),
            @as(*c.git_writestream, @ptrCast(target)),
        });
    }

    pub fn deinit(self: *FilterList) void {
        if (internal.trace_log) log.debug("FilterList.deinit called", .{});

        c.git_filter_list_free(@as(*c.git_filter_list, @ptrCast(self)));
    }

    /// Apply filter list to a data buffer.
    ///
    /// ## Parameters
    /// * `name` - Buffer containing the data to filter
    pub fn applyToBuffer(self: *FilterList, in: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("FilterList.applyToBuffer called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_filter_list_apply_to_buffer", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*c.git_filter_list, @ptrCast(self)),
            in.ptr,
            in.len,
        });

        return ret;
    }

    /// Apply a filter list to an arbitrary buffer as a stream
    ///
    /// ## Parameters
    /// * `buffer` - The buffer to filter
    /// * `target` - The stream into which the data will be written
    pub fn applyToBufferToStream(self: *FilterList, buffer: [:0]const u8, target: *git.WriteStream) !void {
        if (internal.trace_log) log.debug("FilterList.applyToBufferToStream called", .{});

        try internal.wrapCall("git_filter_list_stream_buffer", .{
            @as(*c.git_filter_list, @ptrCast(self)),
            buffer.ptr,
            buffer.len,
            @as(*c.git_writestream, @ptrCast(target)),
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
