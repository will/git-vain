const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Blame = opaque {
    pub fn deinit(self: *Blame) void {
        if (internal.trace_log) log.debug("Blame.deinit called", .{});

        c.git_blame_free(@ptrCast(self));
    }

    pub fn hunkCount(self: *Blame) u32 {
        if (internal.trace_log) log.debug("Blame.hunkCount called", .{});

        return c.git_blame_get_hunk_count(@ptrCast(self));
    }

    pub fn hunkByIndex(self: *Blame, index: u32) ?*const BlameHunk {
        if (internal.trace_log) log.debug("Blame.hunkByIndex called", .{});

        return @ptrCast(c.git_blame_get_hunk_byindex(@ptrCast(self), index));
    }

    pub fn hunkByLine(self: *Blame, line: usize) ?*const BlameHunk {
        if (internal.trace_log) log.debug("Blame.hunkByLine called", .{});

        return @ptrCast(c.git_blame_get_hunk_byline(@ptrCast(self), line));
    }

    /// Get blame data for a file that has been modified in memory. The `reference` parameter is a pre-calculated blame for the
    /// in-odb history of the file. This means that once a file blame is completed (which can be expensive), updating the buffer
    /// blame is very fast.
    ///
    /// Lines that differ between the buffer and the committed version are marked as having a zero OID for their final_commit_id.
    pub fn blameBuffer(self: *Blame, buffer: [:0]const u8) !*git.Blame {
        if (internal.trace_log) log.debug("Blame.blameBuffer called", .{});

        var blame: *git.Blame = undefined;

        try internal.wrapCall("git_blame_buffer", .{
            @as(*?*c.git_blame, @ptrCast(&blame)),
            @as(*c.git_blame, @ptrCast(self)),
            buffer.ptr,
            buffer.len,
        });

        return blame;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const BlameHunk = extern struct {
    /// The number of lines in this hunk.
    lines_in_hunk: usize,

    /// The OID of the commit where this line was last changed.
    final_commit_id: git.Oid,

    /// The 1-based line number where this hunk begins, in the final version
    /// of the file.
    final_start_line_number: usize,

    /// The author of `final_commit_id`. If `use_mailmap` has been
    /// specified, it will contain the canonical real name and email address.
    final_signature: *git.Signature,

    /// The OID of the commit where this hunk was found.
    /// This will usually be the same as `final_commit_id`, except when
    /// `any_commit_copies` has been specified.
    orig_commit_id: git.Oid,

    /// The path to the file where this hunk originated, as of the commit
    /// specified by `orig_commit_id`.
    /// Use `origPath`
    z_orig_path: [*:0]const u8,

    /// The 1-based line number where this hunk begins in the file named by
    /// `orig_path` in the commit specified by `orig_commit_id`.
    orig_start_line_number: usize,

    /// The author of `orig_commit_id`. If `use_mailmap` has been
    /// specified, it will contain the canonical real name and email address.
    orig_signature: *git.Signature,

    /// The 1 iff the hunk has been tracked to a boundary commit (the root,
    /// or the commit specified in git_blame_options.oldest_commit)
    boundary: u8,

    pub fn origPath(self: BlameHunk) [:0]const u8 {
        return std.mem.sliceTo(self.z_orig_path, 0);
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_blame_hunk), @sizeOf(BlameHunk));
        try std.testing.expectEqual(@bitSizeOf(c.git_blame_hunk), @bitSizeOf(BlameHunk));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const BlameOptions = struct {
    flags: BlameFlags = .{},

    /// The lower bound on the number of alphanumeric characters that must be detected as moving/copying within a file for it
    /// to associate those lines with the parent commit. The default value is 20.
    ///
    /// This value only takes effect if any of the `BlameFlags.track_copies_*` flags are specified.
    min_match_characters: u16 = 0,

    /// The id of the newest commit to consider. The default is HEAD.
    newest_commit: git.Oid = git.Oid.zero,

    /// The id of the oldest commit to consider. The default is the first commit encountered with a `null` parent.
    oldest_commit: git.Oid = git.Oid.zero,

    /// The first line in the file to blame. The default is 1 (line numbers start with 1).
    min_line: usize = 0,

    /// The last line in the file to blame. The default is the last line of the file.
    max_line: usize = 0,

    pub const BlameFlags = packed struct {
        normal: bool = false,

        /// Track lines that have moved within a file (like `git blame -M`).
        ///
        /// This is not yet implemented and reserved for future use.
        track_copies_same_file: bool = false,

        /// Track lines that have moved across files in the same commit (like `git blame -C`).
        ///
        /// This is not yet implemented and reserved for future use.
        track_copies_same_commit_moves: bool = false,

        /// Track lines that have been copied from another file that exists in the same commit (like `git blame -CC`).
        /// Implies same_file.
        ///
        /// This is not yet implemented and reserved for future use.
        track_copies_same_commit_copies: bool = false,

        /// Track lines that have been copied from another file that exists in *any* commit (like `git blame -CCC`). Implies
        /// same_commit_copies.
        ///
        /// This is not yet implemented and reserved for future use.
        track_copies_any_commit_copies: bool = false,

        /// Restrict the search of commits to those reachable following only the first parents.
        first_parent: bool = false,

        /// Use mailmap file to map author and committer names and email addresses to canonical real names and email
        /// addresses. The mailmap will be read from the working directory, or HEAD in a bare repository.
        use_mailmap: bool = false,

        /// Ignore whitespace differences
        ignore_whitespace: bool = false,

        z_padding1: u8 = 0,
        z_padding2: u16 = 0,

        pub fn format(
            value: BlameFlags,
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
            try std.testing.expectEqual(@sizeOf(c.git_blame_flag_t), @sizeOf(BlameFlags));
            try std.testing.expectEqual(@bitSizeOf(c.git_blame_flag_t), @bitSizeOf(BlameFlags));
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
