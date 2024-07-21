const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// The diff object that contains all individual file deltas.
/// A `diff` represents the cumulative list of differences between two snapshots of a repository (possibly filtered by a set of
/// file name patterns).
///
/// Calculating diffs is generally done in two phases: building a list of diffs then traversing it. This makes is easier to share
/// logic across the various types of diffs (tree vs tree, workdir vs index, etc.), and also allows you to insert optional diff
/// post-processing phases, such as rename detection, in between the steps. When you are done with a diff object, it must be
/// freed.
pub const Diff = opaque {
    pub fn deinit(self: *Diff) void {
        if (internal.trace_log) log.debug("Diff.deinit called", .{});

        c.git_diff_free(@as(*c.git_diff, @ptrCast(self)));
    }

    /// Return a patch for an entry in the diff list.
    ///
    /// The patch is a newly created object contains the text diffs for the delta. You have to call `Patch.deinit` when you are
    /// done with it. You can use the patch object to loop over all the hunks and lines in the diff of the one delta.
    ///
    /// For an unchanged file or a binary file, no patch will be created, the output will be `null`, and the `binary` flag will be
    /// set true in the `Diff` structure.
    ///
    /// ## Parameters
    /// * `index` - Index into diff list
    pub fn toPatch(self: *Diff, index: usize) !?*git.Patch {
        if (internal.trace_log) log.debug("Diff.toPatch called", .{});

        var ret: ?*git.Patch = undefined;

        try internal.wrapCall("git_patch_from_diff", .{
            @as(*?*c.git_patch, @ptrCast(&ret)),
            @as(*c.git_diff, @ptrCast(self)),
            index,
        });

        return ret;
    }

    /// Match a pathspec against files in a diff list.
    ///
    /// This matches the pathspec against the files in the given diff list.
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
        self: *Diff,
        pathspec: *git.Pathspec,
        options: git.PathspecMatchOptions,
        match_list: ?**git.PathspecMatchList,
    ) !bool {
        if (internal.trace_log) log.debug("Diff.pathspecMatch called", .{});

        return (try internal.wrapCallWithReturn("git_pathspec_match_diff", .{
            @as(?*?*c.git_pathspec_match_list, @ptrCast(match_list)),
            @as(*c.git_diff, @ptrCast(self)),
            @as(c.git_pathspec_flag_t, @bitCast(options)),
            @as(*c.git_pathspec, @ptrCast(pathspec)),
        })) != 0;
    }

    /// Get performance data for a diff object.
    pub fn getPerfData(self: *const Diff) !DiffPerfData {
        if (internal.trace_log) log.debug("Diff.getPerfData called", .{});

        var c_ret = c.git_diff_perfdata{
            .version = c.GIT_DIFF_PERFDATA_VERSION,
            .stat_calls = 0,
            .oid_calculations = 0,
        };

        try internal.wrapCall("git_diff_get_perfdata", .{
            &c_ret,
            @as(*const c.git_diff, @ptrCast(self)),
        });

        return DiffPerfData{
            .stat_calls = c_ret.stat_calls,
            .oid_calculations = c_ret.oid_calculations,
        };
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Structure describing a line (or data span) of a diff.
///
/// A `line` is a range of characters inside a hunk. It could be a context line (i.e. in both old and new versions), an added line
/// (i.e. only in the new version), or a removed line (i.e. only in the old version). Unfortunately, we don't know anything about
/// the encoding of data in the file being diffed, so we cannot tell you much about the line content. Line data will not be
/// NUL-byte terminated, however, because it will be just a span of bytes inside the larger file.
pub const DiffLine = extern struct {
    origin: Origin,

    /// Line number in old file or -1 for added line
    old_lineno: c_int,

    /// Line number in new file or -1 for deleted line
    new_lineno: c_int,

    /// Number of newline characters in content
    num_lines: c_int,

    /// Number of bytes of data
    content_len: usize,

    /// Offset in the original file to the content
    content_offset: i64,

    /// Pointer to diff text
    content: [*]const u8,

    /// Line origin constants.
    ///
    /// These values describe where a line came from and will be passed to the git_diff_line_cb when iterating over a diff.
    /// There are some special origin constants at the end that are used for the text output callbacks to demarcate lines that
    /// are actually part of the file or hunk headers.
    pub const Origin = enum(u8) {
        CONTEXT = ' ',
        ADDITION = '+',
        DELETION = '-',
        /// Both files have no LF at end
        CONTEXT_EOFNL = '=',
        /// Old has no LF at end, new does
        ADD_EOFNL = '>',
        /// Old has LF at end, new does not
        DEL_EOFNL = '<',
        FILE_HDR = 'F',
        HUNK_HDR = 'H',
        /// For "Binary files x and y differ"
        BINARY = 'B',
    };

    pub fn getContent(self: DiffLine) []const u8 {
        return self.content[0..self.content_len];
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_diff_line), @sizeOf(DiffLine));
        try std.testing.expectEqual(@bitSizeOf(c.git_diff_line), @bitSizeOf(DiffLine));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Structure describing options about how the diff should be executed.
pub const DiffOptions = struct {
    flags: DiffOptions.Flags = .{},

    /// Overrides the submodule ignore setting for all submodules in the diff.
    ignore_submodules: git.SubmoduleIgnore = .default,

    /// An array of paths / fnmatch patterns to constrain diff. All paths are included by default.
    pathspec: git.StrArray = .{},

    /// An optional callback function, notifying the consumer of changes to the diff as new deltas are added.
    /// The callback will be called for each file, just before the `DiffDelta` gets inserted into the diff.
    ///
    /// When the callback:
    /// - returns < 0, the diff process will be aborted.
    /// - returns > 0, the delta will not be inserted into the diff, but the diff process continues.
    /// - returns 0, the delta is inserted into the diff, and the diff process continues.
    notify_cb: ?*const fn (
        diff_so_far: *const git.Diff,
        delta_to_add: *const git.DiffDelta,
        matched_pathspec: [*:0]const u8,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// An optional callback function, notifying the consumer of which files are being examined as the diff is generated.
    /// Called before each file comparison.
    ///
    /// Return non-zero to abort the diff.
    progress_cb: ?*const fn (
        /// The diff being generated.
        diff_so_far: *const git.Diff,
        /// The path to the old file or `null`.
        old_path: ?[*:0]const u8,
        /// The path to the new file or `null`.
        new_path: ?[*:0]const u8,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    payload: ?*anyopaque = null,

    /// The number of unchanged lines that define the boundary of a hunk (and to display before and after).
    context_lines: u32 = 3,

    /// The maximum number of unchanged lines between hunk boundaries before the hunks will be merged into one.
    interhunk_lines: u32 = 0,

    /// The abbreviation length to use when formatting object ids. Defaults to the value of 'core.abbrev' from the config.
    id_abbrev: u16 = 0,

    /// A size (in bytes) above which a blob will be marked as binary automatically; pass a negative value to disable.
    /// Defaults to 512MB.
    max_size: i64 = 0,

    /// The virtual "directory" prefix for old file names in hunk headers. Default is "a".
    old_prefix: ?[*:0]const u8 = null,

    /// The virtual "directory" prefix for new file names in hunk headers. Default is "b".
    new_prefix: ?[*:0]const u8 = null,

    pub const Flags = packed struct {
        /// Reverse the sides of the diff
        reverse: bool = false,

        /// Include ignored files in the diff
        include_ignored: bool = false,

        /// Even with include_ignored, an entire ignored directory will be marked with only a single entry in the diff; this flag
        /// adds all files under the directory as IGNORED entries, too.
        recurse_ignored_dirs: bool = false,

        /// Include untracked files in the diff
        include_untracked: bool = false,

        /// Even with include_untracked, an entire untracked directory will be marked with only a single entry in the diff
        /// (a la what core Git does in `git status`); this flag adds *all* files under untracked directories as UNTRACKED
        /// entries, too.
        recurse_untracked_dirs: bool = false,

        /// Include unmodified files in the diff
        include_unmodified: bool = false,

        /// Normally, a type change between files will be converted into a DELETED record for the old and an ADDED record for the
        /// new; this options enabled the generation of TYPECHANGE delta records.
        include_typechange: bool = false,

        /// Even with include_typechange, blob->tree changes still generally show as a DELETED blob. This flag tries to correctly
        /// label blob->tree transitions as TYPECHANGE records with new_file's mode set to tree. Note: the tree SHA will not be
        /// available.
        include_typechange_trees: bool = false,

        /// Ignore file mode changes
        ignore_filemode: bool = false,

        /// Treat all submodules as unmodified
        ignore_submodules: bool = false,

        /// Use case insensitive filename comparisons
        ignore_case: bool = false,

        /// May be combined with `ignore_case` to specify that a file that has changed case will be returned as an add/delete pair.
        include_casechange: bool = false,

        /// If the pathspec is set in the diff options, this flags indicates that the paths will be treated as literal paths
        /// instead of fnmatch patterns. Each path in the list must either be a full path to a file or a directory.
        /// (A trailing slash indicates that the path will _only_ match a directory). If a directory is specified, all children
        /// will be included.
        disable_pathspec_match: bool = false,

        /// Disable updating of the `binary` flag in delta records. This is useful when iterating over a diff if you don't need
        /// hunk and data callbacks and want to avoid having to load file completely.
        skip_binary_check: bool = false,

        /// When diff finds an untracked directory, to match the behavior of core Git, it scans the contents for IGNORED and
        /// UNTRACKED files. If *all* contents are IGNORED, then the directory is IGNORED; if any contents are not IGNORED, then
        /// the directory is UNTRACKED. This is extra work that may not matter in many cases. This flag turns off that scan and
        /// immediately labels an untracked directory as UNTRACKED (changing the behavior to not match core Git).
        enable_fast_untracked_dirs: bool = false,

        /// When diff finds a file in the working directory with stat information different from the index, but the OID ends up
        /// being the same, write the correct stat information into the index. Note: without this flag, diff will always leave the
        /// index untouched.
        update_index: bool = false,

        /// Include unreadable files in the diff
        include_unreadable: bool = false,

        /// Include unreadable files in the diff
        include_unreadable_as_untracked: bool = false,

        /// Use a heuristic that takes indentation and whitespace into account which generally can produce better diffs when
        /// dealing with ambiguous diff hunks.
        indent_heuristic: bool = false,

        z_padding1: u1 = 0,

        /// Treat all files as text, disabling binary attributes & detection
        force_text: bool = false,

        /// Treat all files as binary, disabling text diffs
        force_binary: bool = false,

        /// Ignore all whitespace
        ignore_whitespace: bool = false,

        /// Ignore changes in amount of whitespace
        ignore_whitespace_change: bool = false,

        /// Ignore whitespace at end of line
        ignore_whitespace_eol: bool = false,

        /// When generating patch text, include the content of untracked files. This automatically turns on INCLUDE_UNTRACKED but
        /// it does not turn on RECURSE_UNTRACKED_DIRS. Add that flag if you want the content of every single UNTRACKED file.
        show_untracked_content: bool = false,

        /// When generating output, include the names of unmodified files if they are included in the git_diff. Normally these are
        /// skipped in the formats that list files (e.g. name-only, name-status, raw). Even with this, these will not be included
        /// in patch format.
        show_unmodified: bool = false,

        z_padding2: u1 = 0,

        /// Use the "patience diff" algorithm
        patience: bool = false,

        /// Take extra time to find minimal diff
        minimal: bool = false,

        /// Include the necessary deflate / delta information so that `git-apply` can apply given diff information to binary files.
        show_binary: bool = false,

        /// Ignore blank lines
        ignore_blank_lines: bool = false,

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
                &.{ "z_padding1", "z_padding2" },
            );
        }

        test {
            try std.testing.expectEqual(@sizeOf(c.git_diff_option_t), @sizeOf(Flags));
            try std.testing.expectEqual(@bitSizeOf(c.git_diff_option_t), @bitSizeOf(Flags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Performance data from diffing
pub const DiffPerfData = struct {
    /// Number of stat() calls performed
    stat_calls: usize,

    /// Number of ID calculations
    oid_calculations: usize,

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Structure describing a hunk of a diff.
///
/// A `hunk` is a span of modified lines in a delta along with some stable surrounding context. You can configure the amount of
/// context and other properties of how hunks are generated. Each hunk also comes with a header that described where it starts and
/// ends in both the old and new versions in the delta.
pub const DiffHunk = extern struct {
    pub const header_size: usize = c.GIT_DIFF_HUNK_HEADER_SIZE;

    /// Starting line number in old_file
    old_start: c_int,
    /// Number of lines in old_file
    old_lines: c_int,
    /// Starting line number in new_file
    new_start: c_int,
    /// Number of lines in new_file
    new_lines: c_int,
    /// Number of bytes in header text
    header_len: usize,
    /// Use `header`
    z_header: [header_size]u8,

    pub fn header(self: DiffHunk) [:0]const u8 {
        return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&self.z_header)), 0);
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_diff_hunk), @sizeOf(DiffHunk));
        try std.testing.expectEqual(@bitSizeOf(c.git_diff_hunk), @bitSizeOf(DiffHunk));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Description of changes to one entry.
///
/// A `delta` is a file pair with an old and new revision. The old version may be absent if the file was just created and the new
/// version may be absent if the file was deleted. A diff is mostly just a list of deltas.
///
/// When iterating over a diff, this will be passed to most callbacks and you can use the contents to understand exactly what has
/// changed.
///
/// The `old_file` represents the "from" side of the diff and the `new_file` represents to "to" side of the diff.  What those
/// means depend on the function that was used to generate the diff. You can also use the `reverse` flag to flip it
/// around.
///
/// Although the two sides of the delta are named `old_file` and `new_file`, they actually may correspond to entries that
/// represent a file, a symbolic link, a submodule commit id, or even a tree (if you are tracking type changes or
/// ignored/untracked directories).
///
/// Under some circumstances, in the name of efficiency, not all fields will be filled in, but we generally try to fill in as much
/// as possible. One example is that the `flags` field may not have either the `binary` or the `not_binary` flag set to avoid
/// examining file contents if you do not pass in hunk and/or line callbacks to the diff foreach iteration function.  It will just
/// use the git attributes for those files.
///
/// The similarity score is zero unless you call `git_diff_find_similar()` which does a similarity analysis of files in the diff.
/// Use that function to do rename and copy detection, and to split heavily modified files in add/delete pairs. After that call,
/// deltas with a status of `renamed` or `copied` will have a similarity score between 0 and 100 indicating how
/// similar the old and new sides are.
///
/// If you ask `git_diff_find_similar` to find heavily modified files to break, but to not *actually* break the records, then
/// modified records may have a non-zero similarity score if the self-similarity is below the split threshold. To
/// display this value like core Git, invert the score (a la `printf("M%03d", 100 - delta->similarity)`).
pub const DiffDelta = extern struct {
    status: DeltaType,
    flags: DiffFlags,
    /// for renamed and copied, value 0-100
    similarity: u16,
    number_of_files: u16,
    old_file: DiffFile,
    new_file: DiffFile,

    /// What type of change is described by a git_diff_delta?
    ///
    /// `renamed` and `copied` will only show up if you run `git_diff_find_similar()` on the diff object.
    ///
    /// `typechange` only shows up given `GIT_DIFF_INCLUDE_typechange` in the option flags (otherwise type changes will
    /// be split into added / deleted pairs).
    pub const DeltaType = enum(c_uint) {
        /// no changes
        unmodified,
        /// entry does not exist in old version
        added,
        /// entry does not exist in new version
        deleted,
        /// entry content changed between old and new
        modified,
        /// entry was renamed between old and new
        renamed,
        /// entry was copied from another old entry
        copied,
        /// entry is ignored item in workdir
        ignored,
        /// entry is untracked item in workdir
        untracked,
        /// type of entry changed between old and new
        typechange,
        /// entry is unreadable
        unreadable,
        /// entry in the index is conflicted
        conflicted,
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_diff_delta), @sizeOf(DiffDelta));
        try std.testing.expectEqual(@bitSizeOf(c.git_diff_delta), @bitSizeOf(DiffDelta));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const ApplyOptions = struct {
    /// callback that will be made per delta (file)
    ///
    /// When the callback:
    ///   - returns < 0, the apply process will be aborted.
    ///   - returns > 0, the delta will not be applied, but the apply process continues
    ///   - returns 0, the delta is applied, and the apply process continues.
    delta_cb: ?*const fn (delta: *const git.DiffDelta) callconv(.C) c_int = null,

    /// callback that will be made per hunk
    ///
    /// When the callback:
    ///   - returns < 0, the apply process will be aborted.
    ///   - returns > 0, the hunk will not be applied, but the apply process continues
    ///   - returns 0, the hunk is applied, and the apply process continues.
    hunk_cb: ?*const fn (hunk: *const git.DiffHunk) callconv(.C) c_int = null,

    flags: ApplyOptionsFlags = .{},

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub fn ApplyOptionsWithUserData(comptime T: type) type {
    const ptr_info = @typeInfo(T);
    comptime std.debug.assert(ptr_info == .Pointer); // Must be a pointer

    return struct {
        /// callback that will be made per delta (file)
        ///
        /// When the callback:
        ///   - returns < 0, the apply process will be aborted.
        ///   - returns > 0, the delta will not be applied, but the apply process continues
        ///   - returns 0, the delta is applied, and the apply process continues.
        delta_cb: ?*const fn (delta: *const git.DiffDelta, user_data: T) callconv(.C) c_int = null,

        /// callback that will be made per hunk
        ///
        /// When the callback:
        ///   - returns < 0, the apply process will be aborted.
        ///   - returns > 0, the hunk will not be applied, but the apply process continues
        ///   - returns 0, the hunk is applied, and the apply process continues.
        hunk_cb: ?*const fn (hunk: *const git.DiffHunk, user_data: T) callconv(.C) c_int = null,

        payload: T,

        flags: git.ApplyOptionsFlags = .{},

        comptime {
            std.testing.refAllDecls(@This());
        }
    };
}

comptime {
    if (@import("builtin").is_test) _ = ApplyOptionsWithUserData(*u8);
}

pub const ApplyOptionsFlags = packed struct {
    /// Don't actually make changes, just test that the patch applies. This is the equivalent of `git apply --check`.
    check: bool = false,

    z_padding: u31 = 0,

    pub fn format(
        value: git.ApplyOptionsFlags,
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
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(ApplyOptionsFlags));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(ApplyOptionsFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const ApplyLocation = enum(c_uint) {
    /// Apply the patch to the workdir, leaving the index untouched.
    /// This is the equivalent of `git apply` with no location argument.
    workdir = 0,

    /// Apply the patch to the index, leaving the working directory
    /// untouched.  This is the equivalent of `git apply --cached`.
    index = 1,

    /// Apply the patch to both the working directory and the index.
    /// This is the equivalent of `git apply --index`.
    both = 2,
};

/// Description of one side of a delta.
///
/// Although this is called a "file", it could represent a file, a symbolic link, a submodule commit id, or even a tree
/// (although that only if you are tracking type changes or ignored/untracked directories).
pub const DiffFile = extern struct {
    /// The `git_oid` of the item.  If the entry represents an absent side of a diff (e.g. the `old_file` of a
    /// `GIT_DELTA_added` delta), then the oid will be zeroes.
    id: git.Oid,
    /// Path to the entry relative to the working directory of the repository.
    path: [*:0]const u8,
    /// The size of the entry in bytes.
    size: u64,
    flags: DiffFlags,
    /// Roughly, the stat() `st_mode` value for the item.
    mode: git.FileMode,
    /// Represents the known length of the `id` field, when converted to a hex string.  It is generally `git.Oid.hex_buffer_size`,
    /// unless this delta was created from reading a patch file, in which case it may be abbreviated to something reasonable,
    /// like 7 characters.
    id_abbrev: u16,

    test {
        try std.testing.expectEqual(@sizeOf(c.git_diff_file), @sizeOf(DiffFile));
        try std.testing.expectEqual(@bitSizeOf(c.git_diff_file), @bitSizeOf(DiffFile));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Flags for the delta object and the file objects on each side.
///
/// These flags are used for both the `flags` value of the `git_diff_delta` and the flags for the `git_diff_file` objects
/// representing the old and new sides of the delta.  Values outside of this public range should be considered reserved
/// for internal or future use.
pub const DiffFlags = packed struct {
    /// file(s) treated as binary data
    binary: bool = false,
    /// file(s) treated as text data
    not_binary: bool = false,
    /// `id` value is known correct
    valid_id: bool = false,
    /// file exists at this side of the delta
    exists: bool = false,

    z_padding1: u12 = 0,
    z_padding2: u16 = 0,

    pub fn format(
        value: DiffFlags,
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
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(DiffFlags));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(DiffFlags));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
