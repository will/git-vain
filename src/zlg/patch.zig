const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Stores all the text diffs for a delta.
///
/// You can easily loop over the content of patches and get information about them.
pub const Patch = opaque {
    pub fn deinit(self: *Patch) void {
        if (internal.trace_log) log.debug("Patch.deinit called", .{});

        c.git_patch_free(@as(*c.git_patch, @ptrCast(self)));
    }

    /// Get the delta associated with a patch. This delta points to internal data and you do not have to release it when you are
    /// done with it.
    pub fn getDelta(self: *const git.Patch) *const git.DiffDelta {
        if (internal.trace_log) log.debug("Patch.getDelta called", .{});

        return @as(
            *const git.DiffDelta,
            @ptrCast(c.git_patch_get_delta(@as(*const c.git_patch, @ptrCast(self)))),
        );
    }

    /// Get the number of hunks in a patch
    pub fn numberOfHunks(self: *const git.Patch) usize {
        if (internal.trace_log) log.debug("Patch.numberOfHunks called", .{});

        return c.git_patch_num_hunks(@as(*const c.git_patch, @ptrCast(self)));
    }

    /// Get line counts of each type in a patch.
    ///
    /// This helps imitate a diff --numstat type of output. For that purpose, you only need the `total_additions` and
    /// `total_deletions` values, but we include the `total_context` line count in case you want the total number of lines of diff
    /// output that will be generated.
    ///
    /// All outputs are optional. Pass `nuull` if you don't need a particular count.
    ///
    /// ## Parameters
    /// * `total_context` - Count of context lines in output, can be `null`.
    /// * `total_additions` - Count of addition lines in output, can be `null`.
    /// * `total_deletions` - Count of deletion lines in output, can be `null`.
    pub fn lineStats(self: *const git.Patch, total_context: ?*usize, total_additions: ?*usize, total_deletions: ?*usize) !void {
        if (internal.trace_log) log.debug("Blob.lineStats called", .{});

        try internal.wrapCall("git_patch_line_stats", .{
            total_context,
            total_additions,
            total_deletions,
            @as(*const c.git_patch, @ptrCast(self)),
        });
    }

    /// Get the information about a hunk in a patch
    ///
    /// Given a patch and a hunk index into the patch, this returns detailed information about that hunk.
    ///
    /// ## Parameters
    /// * `index` - Input index of hunk to get information about.
    pub fn getHunk(self: *git.Patch, index: usize) !GetHunkResult {
        if (internal.trace_log) log.debug("Blob.getHunk called", .{});

        var ret: GetHunkResult = undefined;

        try internal.wrapCall("git_patch_get_hunk", .{
            @as(*?*c.git_diff_hunk, @ptrCast(&ret.diff_hunk)),
            &ret.lines_in_hunk,
            @as(*c.git_patch, @ptrCast(self)),
            index,
        });

        return ret;
    }

    pub const GetHunkResult = struct {
        diff_hunk: *git.DiffHunk,
        /// Output count of total lines in this hunk.
        lines_in_hunk: usize,
    };

    /// Get the number of lines in a hunk.
    ///
    /// ## Parameters
    /// * `index` - Index of the hunk.
    pub fn linesInHunk(self: *const git.Patch, index: usize) !usize {
        if (internal.trace_log) log.debug("Patch.linesInHunk called", .{});

        const ret = try internal.wrapCallWithReturn("git_patch_num_lines_in_hunk", .{
            @as(*const c.git_patch, @ptrCast(self)),
            index,
        });

        return @as(usize, @intCast(ret));
    }

    /// Get data about a line in a hunk of a patch.
    ///
    /// Given a patch, a hunk index, and a line index in the hunk, this will return a lot of details about that line.
    ///
    /// ## Parameters
    /// * `hunk_index` - The index of the hunk.
    /// * `line` - The index of the line in the hunk.
    pub fn getLineInHunk(self: *Patch, hunk_index: usize, line: usize) !*git.DiffLine {
        if (internal.trace_log) log.debug("Patch.getLineInHunk called", .{});

        var ret: *git.DiffLine = undefined;

        try internal.wrapCall("git_patch_get_line_in_hunk", .{
            @as(*?*c.git_diff_line, @ptrCast(&ret)),
            @as(*c.git_patch, @ptrCast(self)),
            hunk_index,
            line,
        });

        return ret;
    }

    /// Look up size of patch diff data in bytes
    ///
    /// This returns the raw size of the patch data.This only includes the actual data from the lines of the diff, not the file or
    /// hunk headers.
    ///
    /// If you pass `include_context` as true, this will be the size of all of the diff output; if you pass it as false, this will
    /// only include the actual changed lines.
    ///
    /// ## Parameters
    /// * `include_context` - Include context lines in size.
    /// * `include_hunk_headers` - Include hunk header lines.
    /// * `include_file_header` - Include file header lines.
    pub fn size(self: *Patch, include_context: bool, include_hunk_headers: bool, include_file_header: bool) !usize {
        if (internal.trace_log) log.debug("Patch.size called", .{});

        const ret = c.git_patch_size(
            @as(*c.git_patch, @ptrCast(self)),
            @intFromBool(include_context),
            @intFromBool(include_hunk_headers),
            @intFromBool(include_file_header),
        );

        return ret;
    }

    /// Serialize the patch to text via callback.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `callback_fn` - Callback function to output lines of the patch. Will be called for file headers, hunk headers, and diff
    ///                   lines.
    ///
    /// ## Callback Parameters
    /// * `delta` - Delta that contains this data
    /// * `hunk` - Hunk containing this data
    /// * `line` - Line data
    pub fn print(
        self: *Patch,
        comptime callback_fn: fn (
            delta: *const git.DiffDelta,
            hunk: *const git.DiffHunk,
            line: *const git.DiffLine,
        ) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                delta: *const git.DiffDelta,
                hunk: *const git.DiffHunk,
                line: *const git.DiffLine,
                _: *u8,
            ) c_int {
                return callback_fn(delta, hunk, line);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.printWithUserData(&dummy_data, cb);
    }

    /// Serialize the patch to text via callback.
    ///
    /// Return a non-zero value from the callback to stop the loop. This non-zero value is returned by the function.
    ///
    /// ## Parameters
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - Callback function to output lines of the patch. Will be called for file headers, hunk headers, and diff
    ///                   lines.
    ///
    /// ## Callback Parameters
    /// * `delta` - Delta that contains this data
    /// * `hunk` - Hunk containing this data
    /// * `line` - Line data
    /// * `user_data_ptr` - Pointer to user data
    pub fn printWithUserData(
        self: *Patch,
        user_data: anytype,
        comptime callback_fn: fn (
            delta: *const git.DiffDelta,
            hunk: *const git.DiffHunk,
            line: *const git.DiffLine,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                delta: ?*const c.git_diff_delta,
                hunk: ?*const c.git_diff_hunk,
                line: ?*const c.git_diff_line,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.DiffDelta, @ptrCast(delta)),
                    @as(*const git.DiffHunk, @ptrCast(hunk)),
                    @as(*const git.DiffLine, @ptrCast(line)),
                    @as(UserDataType, @ptrCast(@alignCast( payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Patch.printWithUserData called", .{});

        return try internal.wrapCallWithReturn("git_patch_print", .{
            @as(*c.git_patch, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    /// Get the content of a patch as a single diff text.
    pub fn toBuf(self: *Patch) !git.Buf {
        if (internal.trace_log) log.debug("Patch.toBuf called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_patch_to_buf", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_patch, @ptrCast(self)),
        });

        return buf;
    }

    /// Get the repository associated with this patch.
    pub fn getOwner(self: *const Patch) ?*git.Repository {
        if (internal.trace_log) log.debug("Patch.getOwner called", .{});

        return @as(
            ?*git.Repository,
            @ptrCast(c.git_patch_owner(@as(*const c.git_patch, @ptrCast(self)))),
        );
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
