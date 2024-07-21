const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// This type bundles all functionality that does not act on an instance of an object
pub const Handle = struct {
    /// De-initialize the libraries global state.
    /// *NOTE*: should be called as many times as `init` was called.
    pub fn deinit(self: Handle) void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.deinit called", .{});

        const number = internal.wrapCallWithReturn("git_libgit2_shutdown", .{}) catch unreachable;

        if (number > 0) {
            if (internal.trace_log) log.debug("{} initializations have not been shutdown (after this one)", .{number});
        }
    }

    /// Create a new bare Git index object as a memory representation of the Git index file in `path`, without a repository to
    /// back it.
    ///
    /// ## Parameters
    /// * `path` - The path to the index
    pub fn indexOpen(self: Handle, path: [:0]const u8) !*git.Index {
        _ = self;

        if (internal.trace_log) log.debug("Handle.indexOpen called", .{});

        var index: *git.Index = undefined;

        try internal.wrapCall("git_index_open", .{
            @as(*?*c.git_index, @ptrCast(&index)),
            path.ptr,
        });

        return index;
    }

    /// Create an in-memory index object.
    ///
    /// This index object cannot be read/written to the filesystem, but may be used to perform in-memory index operations.
    pub fn indexNew(self: Handle) !*git.Index {
        _ = self;

        if (internal.trace_log) log.debug("Handle.indexInit called", .{});

        var index: *git.Index = undefined;

        try internal.wrapCall("git_index_new", .{
            @as(*?*c.git_index, @ptrCast(&index)),
        });

        return index;
    }

    /// Create a new repository in the given directory.
    ///
    /// ## Parameters
    /// * `path` - The path to the repository
    /// * `is_bare` - If true, a Git repository without a working directory is created at the pointed path.
    ///               If false, provided path will be considered as the working directory into which the .git directory will be
    ///               created.
    pub fn repositoryInit(self: Handle, path: [:0]const u8, is_bare: bool) !*git.Repository {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryInit called", .{});

        var repo: *git.Repository = undefined;

        try internal.wrapCall("git_repository_init", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            path.ptr,
            @intFromBool(is_bare),
        });

        return repo;
    }

    /// Create a new repository in the given directory with extended options.
    ///
    /// ## Parameters
    /// * `path` - The path to the repository
    /// * `options` - The options to use during the creation of the repository
    pub fn repositoryInitExtended(self: Handle, path: [:0]const u8, options: git.RepositoryInitOptions) !*git.Repository {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryInitExtended called", .{});

        var repo: *git.Repository = undefined;

        var c_options = internal.make_c_option.repositoryInitOptions(options);

        try internal.wrapCall("git_repository_init_ext", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            path.ptr,
            &c_options,
        });

        return repo;
    }

    /// Open a repository.
    ///
    /// ## Parameters
    /// * `path` - The path to the repository
    pub fn repositoryOpen(self: Handle, path: [:0]const u8) !*git.Repository {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryOpen called", .{});

        var repo: *git.Repository = undefined;

        try internal.wrapCall("git_repository_open", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            path.ptr,
        });

        return repo;
    }

    /// Find and open a repository with extended options.
    ///
    /// *NOTE*: `path` can only be null if the `open_from_env` option is used.
    ///
    /// ## Parameters
    /// * `path` - The path to the repository
    /// * `flags` - Options controlling how the repository is opened
    /// * `ceiling_dirs` - A `path_list_separator` delimited list of path prefixes at which the search for a containing
    ///                    repository should terminate.
    pub fn repositoryOpenExtended(
        self: Handle,
        path: ?[:0]const u8,
        flags: git.RepositoryOpenOptions,
        ceiling_dirs: ?[:0]const u8,
    ) !*git.Repository {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryOpenExtended called", .{});

        var repo: *git.Repository = undefined;

        const path_temp = if (path) |slice| slice.ptr else null;
        const ceiling_dirs_temp = if (ceiling_dirs) |slice| slice.ptr else null;

        try internal.wrapCall("git_repository_open_ext", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            path_temp,
            flags.toInt(),
            ceiling_dirs_temp,
        });

        return repo;
    }

    /// Open a bare repository.
    ///
    /// ## Parameters
    /// * `path` - The path to the repository
    pub fn repositoryOpenBare(self: Handle, path: [:0]const u8) !*git.Repository {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryOpenBare called", .{});

        var repo: *git.Repository = undefined;

        try internal.wrapCall("git_repository_open_bare", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            path.ptr,
        });

        return repo;
    }

    /// Look for a git repository and return its path.
    ///
    /// The lookup starts from `start_path` and walks the directory tree until the first repository is found, or when reaching a
    /// directory referenced in `ceiling_dirs` or when the filesystem changes (when `across_fs` is false).
    ///
    /// ## Parameters
    /// * `start_path` - The path where the lookup starts.
    /// * `across_fs` - If true, then the lookup will not stop when a filesystem device change is encountered.
    /// * `ceiling_dirs` - A `path_list_separator` separated list of absolute symbolic link free paths. The lookup will stop
    ///                    when any of this paths is reached.
    pub fn repositoryDiscover(self: Handle, start_path: [:0]const u8, across_fs: bool, ceiling_dirs: ?[:0]const u8) !git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.repositoryDiscover called", .{});

        var buf: git.Buf = .{};

        const ceiling_dirs_temp = if (ceiling_dirs) |slice| slice.ptr else null;

        try internal.wrapCall("git_repository_discover", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            start_path.ptr,
            @intFromBool(across_fs),
            ceiling_dirs_temp,
        });

        return buf;
    }

    /// Clone a remote repository.
    ///
    /// By default this creates its repository and initial remote to match git's defaults.
    /// You can use the options in the callback to customize how these are created.
    ///
    /// ## Parameters
    /// * `url` - URL of the remote repository to clone.
    /// * `local_path` - Directory to clone the repository into.
    /// * `options` - Customize how the repository is created.
    // BUG: removed due to bitcast error
    // pub fn clone(self: Handle, url: [:0]const u8, local_path: [:0]const u8, options: CloneOptions) !*git.Repository {
    //     _ = self;
    //
    //     if (internal.trace_log) log.debug("Handle.clone called", .{});
    //
    //     var repo: *git.Repository = undefined;
    //
    //     const c_options = internal.make_c_option.cloneOptions(options);
    //
    //     try internal.wrapCall("git_clone", .{
    //         @as(*?*c.git_repository, @ptrCast(&repo)),
    //         url.ptr,
    //         local_path.ptr,
    //         &c_options,
    //     });
    //
    //     return repo;
    // }

    pub fn optionGetMaximumMmapWindowSize(self: Handle) !usize {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetMmapWindowSize called", .{});

        var result: usize = undefined;
        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_MWINDOW_SIZE, &result });

        return result;
    }

    pub fn optionSetMaximumMmapWindowSize(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetMaximumMmapWindowSize called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_MWINDOW_SIZE, value });
    }

    pub fn optionGetMaximumMmapLimit(self: Handle) !usize {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetMaximumMmapLimit called", .{});

        var result: usize = undefined;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_MWINDOW_MAPPED_LIMIT, &result });

        return result;
    }

    pub fn optionSetMaximumMmapLimit(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetMaximumMmapLimit called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_MWINDOW_MAPPED_LIMIT, value });
    }

    /// zero means unlimited
    pub fn optionGetMaximumMappedFiles(self: Handle) !usize {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetMaximumMappedFiles called", .{});

        var result: usize = undefined;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_MWINDOW_FILE_LIMIT, &result });

        return result;
    }

    /// zero means unlimited
    pub fn optionSetMaximumMmapFiles(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetMaximumMmapFiles called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_MWINDOW_FILE_LIMIT, value });
    }

    pub fn optionGetSearchPath(self: Handle, level: git.ConfigLevel) !git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetSearchPath called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_libgit2_opts", .{
            c.GIT_OPT_GET_SEARCH_PATH,
            @intFromEnum(level),
            @as(*c.git_buf, @ptrCast(&buf)),
        });

        return buf;
    }

    /// `path` should be a list of directories delimited by path_list_separator.
    /// Pass `null` to reset to the default (generally based on environment variables). Use magic path `$PATH` to include the old
    /// value of the path (if you want to prepend or append, for instance).
    pub fn optionSetSearchPath(self: Handle, level: git.ConfigLevel, path: ?[:0]const u8) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetSearchPath called", .{});

        const path_c = if (path) |slice| slice.ptr else null;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_SEARCH_PATH, @intFromEnum(level), path_c });
    }

    pub fn optionSetCacheObjectLimit(self: Handle, object_type: git.ObjectType, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetCacheObjectLimit called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_CACHE_OBJECT_LIMIT, @intFromEnum(object_type), value });
    }

    pub fn optionSetMaximumCacheSize(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetCacheMaximumSize called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_CACHE_MAX_SIZE, value });
    }

    pub fn optionSetCaching(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetCaching called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_CACHING, enabled });
    }

    pub fn optionGetCachedMemory(self: Handle) !CachedMemory {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetCachedMemory called", .{});

        var result: CachedMemory = undefined;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_CACHED_MEMORY, &result.current, &result.allowed });

        return result;
    }

    pub const CachedMemory = struct {
        current: usize,
        allowed: usize,
    };

    pub fn optionGetTemplatePath(self: Handle) !git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetTemplatePath called", .{});

        var result: git.Buf = .{};
        try internal.wrapCall("git_libgit2_opts", .{
            c.GIT_OPT_GET_TEMPLATE_PATH,
            @as(*c.git_buf, @ptrCast(&result)),
        });

        return result;
    }

    pub fn optionSetTemplatePath(self: Handle, path: [:0]const u8) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetTemplatePath called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_TEMPLATE_PATH, path.ptr });
    }

    /// Either parameter may be `null`, but not both.
    pub fn optionSetSslCertLocations(self: Handle, file: ?[:0]const u8, path: ?[:0]const u8) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetSslCertLocations called", .{});

        const file_c = if (file) |ptr| ptr.ptr else null;
        const path_c = if (path) |ptr| ptr.ptr else null;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_SSL_CERT_LOCATIONS, file_c, path_c });
    }

    pub fn optionSetUserAgent(self: Handle, user_agent: [:0]const u8) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetUserAgent called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_USER_AGENT, user_agent.ptr });
    }

    pub fn optionGetUserAgent(self: Handle) !git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetUserAgent called", .{});

        var result: git.Buf = .{};

        try internal.wrapCall("git_libgit2_opts", .{
            c.GIT_OPT_GET_USER_AGENT,
            @as(*c.git_buf, @ptrCast(&result)),
        });

        return result;
    }

    pub fn optionSetWindowsSharemode(self: Handle, value: c_uint) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetWindowsSharemode called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_WINDOWS_SHAREMODE, value });
    }

    pub fn optionGetWindowSharemode(self: Handle) !c_uint {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetWindowSharemode called", .{});

        var result: c_uint = undefined;
        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_WINDOWS_SHAREMODE, &result });

        return result;
    }

    pub fn optionSetStrictObjectCreation(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetStrictObjectCreation called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_STRICT_OBJECT_CREATION, internal.boolToCInt(enabled) });
    }

    pub fn optionSetStrictSymbolicRefCreations(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetStrictSymbolicRefCreations called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_STRICT_SYMBOLIC_REF_CREATION, internal.boolToCInt(enabled) });
    }

    pub fn optionSetSslCiphers(self: Handle, ciphers: [:0]const u8) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetSslCiphers called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_SSL_CIPHERS, ciphers.ptr });
    }

    pub fn optionSetOffsetDeltas(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetOffsetDeltas called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_OFS_DELTA, internal.boolToCInt(enabled) });
    }

    pub fn optionSetFsyncDir(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetFsyncDir called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_FSYNC_GITDIR, internal.boolToCInt(enabled) });
    }

    pub fn optionSetStrictHashVerification(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetStrictHashVerification called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_STRICT_HASH_VERIFICATION, internal.boolToCInt(enabled) });
    }

    /// If the given `allocator` is `null`, then the system default will be restored.
    pub fn optionSetAllocator(self: Handle, allocator: ?*git.GitAllocator) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetAllocator called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_ALLOCATOR, allocator });
    }

    pub fn optionSetUnsafedIndexSafety(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetUnsafedIndexSafety called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_UNSAVED_INDEX_SAFETY, internal.boolToCInt(enabled) });
    }

    pub fn optionGetMaximumPackObjects(self: Handle) !usize {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionGetMaximumPackObjects called", .{});

        var result: usize = undefined;

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_GET_PACK_MAX_OBJECTS, &result });

        return result;
    }

    pub fn optionSetMaximumPackObjects(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetMaximumPackObjects called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_PACK_MAX_OBJECTS, value });
    }

    pub fn optionSetDisablePackKeepFileChecks(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetDisablePackKeepFileChecks called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_DISABLE_PACK_KEEP_FILE_CHECKS, internal.boolToCInt(enabled) });
    }

    pub fn optionSetHTTPExpectContinue(self: Handle, enabled: bool) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetHTTPExpectContinue called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_ENABLE_HTTP_EXPECT_CONTINUE, internal.boolToCInt(enabled) });
    }

    pub fn branchNameIsValid(self: Handle, name: [:0]const u8) !bool {
        _ = self;

        if (internal.trace_log) log.debug("Handle.branchNameIsValid, name: {s}", .{name});

        var valid: c_int = undefined;

        try internal.wrapCall("git_branch_name_is_valid", .{ &valid, name.ptr });

        return valid != 0;
    }

    pub fn optionSetOdbPackedPriority(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetOdbPackedPriority called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_ODB_PACKED_PRIORITY, value });
    }

    pub fn optionSetOdbLoosePriority(self: Handle, value: usize) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.optionSetOdbLoosePriority called", .{});

        try internal.wrapCall("git_libgit2_opts", .{ c.GIT_OPT_SET_ODB_LOOSE_PRIORITY, value });
    }

    /// Clean up excess whitespace and make sure there is a trailing newline in the message.
    ///
    /// Optionally, it can remove lines which start with the comment character.
    ///
    /// ## Parameters
    /// * `message` - The message to be prettified.
    /// * `strip_comment_char` - If non-`null` lines starting with this character are considered to be comments and removed
    pub fn messagePrettify(self: Handle, message: [:0]const u8, strip_comment_char: ?u8) !git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.messagePrettify called", .{});

        var ret: git.Buf = .{};

        if (strip_comment_char) |char| {
            try internal.wrapCall("git_message_prettify", .{
                @as(*c.git_buf, @ptrCast(&ret)),
                message.ptr,
                1,
                char,
            });
        } else {
            try internal.wrapCall("git_message_prettify", .{
                @as(*c.git_buf, @ptrCast(&ret)),
                message.ptr,
                0,
                0,
            });
        }

        return ret;
    }

    /// Parse trailers out of a message
    ///
    /// Trailers are key/value pairs in the last paragraph of a message, not including any patches or conflicts that may
    /// be present.
    pub fn messageParseTrailers(self: Handle, message: [:0]const u8) !git.MessageTrailerArray {
        _ = self;

        if (internal.trace_log) log.debug("Handle.messageParseTrailers called", .{});

        var ret: git.MessageTrailerArray = undefined;

        try internal.wrapCall("git_message_trailers", .{
            @as(*c.git_message_trailer_array, @ptrCast(&ret)),
            message.ptr,
        });

        return ret;
    }

    /// Available tracing levels.
    /// When tracing is set to a particular level, callers will be provided tracing at the given level and all lower levels.
    pub const TraceLevel = enum(c_uint) {
        /// No tracing will be performed.
        none = 0,
        /// Severe errors that may impact the program's execution
        fatal = 1,
        /// Errors that do not impact the program's execution
        err = 2,
        /// Warnings that suggest abnormal data
        warn = 3,
        /// Informational messages about program execution
        info = 4,
        /// Detailed data that allows for debugging
        debug = 5,
        /// Exceptionally detailed debugging data
        trace = 6,
    };

    /// Sets the system tracing configuration to the specified level with the specified callback.
    /// When system events occur at a level equal to, or lower than, the given level they will be reported to the given callback.
    ///
    /// ## Parameters
    /// * `level` - Level to set tracing to
    /// * `callback_fn` - The callback function to call with trace data
    ///
    /// ## Callback Parameters
    /// * `level` - The trace level
    /// * `message` - The message
    pub fn traceSet(
        self: Handle,
        level: TraceLevel,
        comptime callback_fn: fn (level: TraceLevel, message: [:0]const u8) void,
    ) !void {
        _ = self;

        if (internal.trace_log) log.debug("Handle.traceSet called", .{});

        const cb = struct {
            pub fn cb(
                c_level: c.git_trace_level_t,
                msg: ?[*:0]const u8,
            ) callconv(.C) void {
                callback_fn(
                    @as(TraceLevel, @enumFromInt(c_level)),
                    std.mem.sliceTo(msg.?, 0),
                );
            }
        }.cb;

        try internal.wrapCall("git_trace_set", .{
            @intFromEnum(level),
            cb,
        });
    }

    /// The kinds of git-specific files we know about.
    pub const GitFile = enum(c_uint) {
        /// Check for the .gitignore file
        gitignore = 0,
        /// Check for the .gitmodules file
        gitmodules,
        /// Check for the .gitattributes file
        gitattributes,
    };

    /// The kinds of checks to perform according to which filesystem we are trying to protect.
    pub const FileSystem = enum(c_uint) {
        /// Do both NTFS- and HFS-specific checks
        generic = 0,
        /// Do NTFS-specific checks only
        ntfs,
        /// Do HFS-specific checks only
        hfs,
    };

    /// Check whether a path component corresponds to a .git$SUFFIX file.
    ///
    /// As some filesystems do special things to filenames when writing files to disk, you cannot always do a plain string
    /// comparison to verify whether a file name matches an expected path or not. This function can do the comparison for you,
    /// depending on the filesystem you're on.
    ///
    /// ## Parameters
    /// * `path` - The path to check
    /// * `gitfile` - Which file to check against
    /// * `fs` - Which filesystem-specific checks to use
    pub fn pathIsGitfile(self: Handle, path: []const u8, gitfile: GitFile, fs: FileSystem) !bool {
        _ = self;

        if (internal.trace_log) log.debug("Handle.pathIsGitfile called", .{});

        return (try internal.wrapCallWithReturn("git_path_is_gitfile", .{
            path.ptr,
            path.len,
            @intFromEnum(gitfile),
            @intFromEnum(fs),
        })) != 0;
    }

    pub fn configNew(self: Handle) !*git.Config {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configNew called", .{});

        var config: *git.Config = undefined;

        try internal.wrapCall("git_config_new", .{
            @as(*?*c.git_config, @ptrCast(&config)),
        });

        return config;
    }

    pub fn configOpenOnDisk(self: Handle, path: [:0]const u8) !*git.Config {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configOpenOnDisk called", .{});

        var config: *git.Config = undefined;

        try internal.wrapCall("git_config_open_ondisk", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            path.ptr,
        });

        return config;
    }

    pub fn configOpenDefault(self: Handle) !*git.Config {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configOpenDefault called", .{});

        var config: *git.Config = undefined;

        try internal.wrapCall("git_config_open_default", .{
            @as(*?*c.git_config, @ptrCast(&config)),
        });

        return config;
    }

    pub fn configFindGlobal(self: Handle) ?git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configFindGlobal called", .{});

        var buf: git.Buf = .{};

        if (c.git_config_find_global(@as(*c.git_buf, @ptrCast(&buf))) == 0) return null;

        return buf;
    }

    pub fn configFindXdg(self: Handle) ?git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configFindXdg called", .{});

        var buf: git.Buf = .{};

        if (c.git_config_find_xdg(@as(*c.git_buf, @ptrCast(&buf))) == 0) return null;

        return buf;
    }

    pub fn configFindSystem(self: Handle) ?git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configFindSystem called", .{});

        var buf: git.Buf = .{};

        if (c.git_config_find_system(@as(*c.git_buf, @ptrCast(&buf))) == 0) return null;

        return buf;
    }

    pub fn configFindProgramdata(self: Handle) ?git.Buf {
        _ = self;

        if (internal.trace_log) log.debug("Handle.configFindProgramdata called", .{});

        var buf: git.Buf = .{};

        if (c.git_config_find_programdata(@as(*c.git_buf, @ptrCast(&buf))) == 0) return null;

        return buf;
    }

    pub fn credentialInitUserPassPlaintext(self: Handle, username: [:0]const u8, password: [:0]const u8) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitUserPassPlaintext called", .{});

        var cred: *git.Credential = undefined;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_userpass_plaintext_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                password.ptr,
            });
        } else {
            try internal.wrapCall("git_cred_userpass_plaintext_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                password.ptr,
            });
        }

        return cred;
    }

    /// Create a "default" credential usable for Negotiate mechanisms like NTLM or Kerberos authentication.
    pub fn credentialInitDefault(self: Handle) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitDefault", .{});

        var cred: *git.Credential = undefined;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_default_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
            });
        } else {
            try internal.wrapCall("git_cred_default_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
            });
        }

        return cred;
    }

    /// Create a credential to specify a username.
    ///
    /// This is used with ssh authentication to query for the username if none is specified in the url.
    pub fn credentialInitUsername(self: Handle, username: [:0]const u8) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitUsername called", .{});

        var cred: *git.Credential = undefined;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_username_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
            });
        } else {
            try internal.wrapCall("git_cred_username_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
            });
        }

        return cred;
    }

    /// Create a new passphrase-protected ssh key credential object.
    ///
    /// ## Parameters
    /// * `username` - Username to use to authenticate
    /// * `publickey` - The path to the public key of the credential.
    /// * `privatekey` - The path to the private key of the credential.
    /// * `passphrase` - The passphrase of the credential.
    pub fn credentialInitSshKey(
        self: Handle,
        username: [:0]const u8,
        publickey: ?[:0]const u8,
        privatekey: [:0]const u8,
        passphrase: ?[:0]const u8,
    ) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitSshKey called", .{});

        var cred: *git.Credential = undefined;

        const publickey_c = if (publickey) |str| str.ptr else null;
        const passphrase_c = if (passphrase) |str| str.ptr else null;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_ssh_key_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                publickey_c,
                privatekey.ptr,
                passphrase_c,
            });
        } else {
            try internal.wrapCall("git_cred_ssh_key_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                publickey_c,
                privatekey.ptr,
                passphrase_c,
            });
        }

        return cred;
    }

    /// Create a new ssh key credential object reading the keys from memory.
    ///
    /// ## Parameters
    /// * `username` - Username to use to authenticate
    /// * `publickey` - The public key of the credential.
    /// * `privatekey` - The private key of the credential.
    /// * `passphrase` - The passphrase of the credential.
    pub fn credentialInitSshKeyMemory(
        self: Handle,
        username: [:0]const u8,
        publickey: ?[:0]const u8,
        privatekey: [:0]const u8,
        passphrase: ?[:0]const u8,
    ) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitSshKeyMemory called", .{});

        var cred: *git.Credential = undefined;

        const publickey_c = if (publickey) |str| str.ptr else null;
        const passphrase_c = if (passphrase) |str| str.ptr else null;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_ssh_key_memory_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                publickey_c,
                privatekey.ptr,
                passphrase_c,
            });
        } else {
            try internal.wrapCall("git_cred_ssh_key_memory_new", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
                publickey_c,
                privatekey.ptr,
                passphrase_c,
            });
        }

        return cred;
    }

    pub fn credentialInitSshKeyFromAgent(self: Handle, username: [:0]const u8) !*git.Credential {
        _ = self;

        if (internal.trace_log) log.debug("Handle.credentialInitSshKeyFromAgent called", .{});

        var cred: *git.Credential = undefined;

        if (internal.has_credential) {
            try internal.wrapCall("git_credential_ssh_key_from_agent", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
            });
        } else {
            try internal.wrapCall("git_cred_ssh_key_from_agent", .{
                @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                username.ptr,
            });
        }

        return cred;
    }

    /// Get detailed information regarding the last error that occured on *this* thread.
    pub fn getDetailedLastError(self: Handle) ?*const git.DetailedError {
        _ = self;
        return @as(?*const git.DetailedError, @ptrCast(c.git_error_last()));
    }

    /// Clear the last error that occured on *this* thread.
    pub fn clearLastError(self: Handle) void {
        _ = self;
        c.git_error_clear();
    }

    /// Create a new indexer instance
    ///
    /// ## Parameters
    /// * `path` - To the directory where the packfile should be stored
    /// * `odb` - Object database from which to read base objects when fixing thin packs. Pass `null` if no thin pack is expected
    ///           (an error will be returned if there are bases missing)
    /// * `options` - Options
    /// * `callback_fn` - The callback function; a value less than zero to cancel the indexing or download
    ///
    /// ## Callback Parameters
    /// * `stats` - State of the transfer
    pub fn indexerInit(
        self: Handle,
        path: [:0]const u8,
        odb: ?*git.Odb,
        options: git.IndexerOptions,
        comptime callback_fn: fn (stats: *const git.IndexerProgress) c_int,
    ) !*git.Indexer {
        const cb = struct {
            pub fn cb(
                stats: *const git.IndexerProgress,
                _: *u8,
            ) c_int {
                return callback_fn(stats);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.indexerInitWithUserData(path, odb, options, &dummy_data, cb);
    }

    /// Create a new indexer instance
    ///
    /// ## Parameters
    /// * `path` - To the directory where the packfile should be stored
    /// * `odb` - Object database from which to read base objects when fixing thin packs. Pass `null` if no thin pack is expected
    ///           (an error will be returned if there are bases missing)
    /// * `options` - Options
    /// * `user_data` - Pointer to user data to be passed to the callback
    /// * `callback_fn` - The callback function; a value less than zero to cancel the indexing or download
    ///
    /// ## Callback Parameters
    /// * `stats` - State of the transfer
    /// * `user_data_ptr` - The user data
    pub fn indexerInitWithUserData(
        self: Handle,
        path: [:0]const u8,
        odb: ?*git.Odb,
        options: git.IndexerOptions,
        user_data: anytype,
        comptime callback_fn: fn (
            stats: *const git.IndexerProgress,
            user_data_ptr: @TypeOf(user_data),
        ) c_int,
    ) !*git.Indexer {
        _ = self;

        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                stats: *const c.git_indexer_progress,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const git.IndexerProgress, @ptrCast(stats)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Handle.indexerInitWithUserData called", .{});

        var c_opts = c.git_indexer_options{
            .version = c.GIT_INDEXER_OPTIONS_VERSION,
            .progress_cb = cb,
            .progress_cb_payload = user_data,
            .verify = @intFromBool(options.verify),
        };

        var ret: *git.Indexer = undefined;

        try internal.wrapCall("git_indexer_new", .{
            @as(*c.git_indexer, @ptrCast(&ret)),
            path.ptr,
            options.mode,
            @as(?*c.git_oid, @ptrCast(odb)),
            &c_opts,
        });

        return ret;
    }

    /// Allocate a new mailmap object.
    ///
    /// This object is empty, so you'll have to add a mailmap file before you can do anything with it.
    /// The mailmap must be freed with 'deinit'.
    pub fn mailmapInit(self: Handle) !*git.Mailmap {
        _ = self;

        if (internal.trace_log) log.debug("Handle.mailmapInit called", .{});

        var mailmap: *git.Mailmap = undefined;

        try internal.wrapCall("git_mailmap_new", .{
            @as(*?*c.git_mailmap, @ptrCast(&mailmap)),
        });

        return mailmap;
    }

    /// Compile a pathspec
    ///
    /// ## Parameters
    /// * `pathspec` - A `git.StrArray` of the paths to match
    pub fn pathspecInit(self: Handle, pathspec: *const git.StrArray) !*git.Pathspec {
        _ = self;

        if (internal.trace_log) log.debug("Handle.pathspecInit called", .{});

        var ret: *git.Pathspec = undefined;

        try internal.wrapCall("git_pathspec_new", .{
            @as(*?*c.git_pathspec, @ptrCast(&ret)),
            @as(*const c.git_strarray, @ptrCast(pathspec)),
        });

        return ret;
    }

    /// Parse a given refspec string.
    ///
    /// ## Parameters
    /// * `input` - The refspec string
    /// * `is_fetch` - Is this a refspec for a fetch
    pub fn refspecParse(self: Handle, input: [:0]const u8, is_fetch: bool) !*git.Refspec {
        _ = self;

        if (internal.trace_log) log.debug("Handle.refspecParse called", .{});

        var ret: *git.Refspec = undefined;

        try internal.wrapCall("git_refspec_parse", .{
            @as(*?*c.git_refspec, @ptrCast(&ret)),
            input.ptr,
            @intFromBool(is_fetch),
        });

        return ret;
    }

    /// Create a remote, with options.
    ///
    /// This function allows more fine-grained control over the remote creation.
    ///
    /// ## Parameters
    /// * `url` - The remote's url.
    /// * `options` - The remote creation options.
    // BUG: removed due to bitcast error
    // pub fn remoteCreateWithOptions(self: Handle, url: [:0]const u8, options: git.RemoteCreateOptions) !*git.Remote {
    //     _ = self;
    //
    //     if (internal.trace_log) log.debug("Handle.remoteCreateWithOptions called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     const c_opts = internal.make_c_option.createOptions(options);
    //
    //     try internal.wrapCall("git_remote_create_with_opts", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         url.ptr,
    //         &c_opts,
    //     });
    //
    //     return remote;
    // }

    /// Create a remote without a connected local repo.
    ///
    /// Create a remote with the given url in-memory. You can use this when you have a URL instead of a remote's name.
    ///
    /// Contrasted with `Repository.remoteCreateAnonymous`, a detached remote will not consider any repo configuration values
    /// (such as insteadof url substitutions).
    ///
    /// ## Parameters
    /// * `url` - The remote's url.
    // BUG: removed due to bitcast error
    // pub fn remoreCreateDetached(self: Handle, url: [:0]const u8) !*git.Remote {
    //     _ = self;
    //
    //     if (internal.trace_log) log.debug("Handle.remoreCreateDetached called", .{});
    //
    //     var remote: *git.Remote = undefined;
    //
    //     try internal.wrapCall("git_remote_create_detached", .{
    //         @as(*?*c.git_remote, @ptrCast(&remote)),
    //         url.ptr,
    //     });
    //
    //     return remote;
    // }

    /// `min_length` is the minimal length for all identifiers, which will be used even if shorter OIDs would still be unique.
    pub fn oidShortenerInit(self: Handle, min_length: usize) !*git.OidShortener {
        _ = self;

        if (internal.trace_log) log.debug("Handle.oidShortenerInit called", .{});

        if (c.git_oid_shorten_new(min_length)) |ret| {
            return @as(*git.OidShortener, @ptrCast(ret));
        }

        return error.OutOfMemory;
    }

    pub fn oidTryParse(self: Handle, str: [:0]const u8) ?git.Oid {
        return self.oidTryParsePtr(str.ptr);
    }

    pub fn oidTryParsePtr(self: Handle, str: [*:0]const u8) ?git.Oid {
        _ = self;

        if (internal.trace_log) log.debug("Handle.oidTryParsePtr called", .{});

        var result: git.Oid = undefined;

        internal.wrapCall("git_oid_fromstrp", .{ @as(*c.git_oid, @ptrCast(&result)), str }) catch {
            return null;
        };

        return result;
    }

    /// Parse `length` characters of a hex formatted object id into a `Oid`
    ///
    /// If `length` is odd, the last byte's high nibble will be read in and the low nibble set to zero.
    pub fn oidParseCount(self: Handle, buf: []const u8, length: usize) !git.Oid {
        _ = self;

        if (buf.len < length) return error.BufferTooShort;

        var result: git.Oid = undefined;
        try internal.wrapCall("git_oid_fromstrn", .{ @as(*c.git_oid, @ptrCast(&result)), buf.ptr, length });
        return result;
    }

    /// Create a new action signature.
    ///
    /// Note: angle brackets ('<' and '>') characters are not allowed to be used in either the `name` or the `email` parameter.
    ///
    /// ## Parameters
    /// * `name` - Name of the person
    /// * `email` - Email of the person
    /// * `time` - Time (in seconds from epoch) when the action happened
    /// * `offset` - Timezone offset (in minutes) for the time
    pub fn signatureInit(
        self: Handle,
        name: [:0]const u8,
        email: [:0]const u8,
        time: git.Time.SystemTime,
        offset: c_int,
    ) !*git.Signature {
        _ = self;

        if (internal.trace_log) log.debug("Handle.signatureInit called", .{});

        var ret: *git.Signature = undefined;

        try internal.wrapCall("git_signature_new", .{
            @as(*?*c.git_signature, @ptrCast(&ret)),
            name.ptr,
            email.ptr,
            time,
            offset,
        });

        return ret;
    }

    /// Create a new action signature with a timestamp of 'now'.
    ///
    /// Note: angle brackets ('<' and '>') characters are not allowed to be used in either the `name` or the `email` parameter.
    ///
    /// ## Parameters
    /// * `name` - Name of the person
    /// * `email` - Email of the person
    pub fn signatureInitNow(
        self: Handle,
        name: [:0]const u8,
        email: [:0]const u8,
    ) !*git.Signature {
        _ = self;

        if (internal.trace_log) log.debug("Handle.signatureInitNow called", .{});

        var ret: *git.Signature = undefined;

        try internal.wrapCall("git_signature_now", .{
            @as(*?*c.git_signature, @ptrCast(&ret)),
            name.ptr,
            email.ptr,
        });

        return ret;
    }

    /// Compute a similarity signature for a text buffer
    ///
    /// If you have passed the option `ignore_whitespace`, then the whitespace will be removed from the buffer while it is being
    /// processed, modifying the buffer in place. Sorry about that!
    ///
    /// ## Parameters
    /// * `buf` - The input buffer.
    /// * `options` - The signature computation options
    pub fn hashsigInit(self: Handle, buf: []u8, options: git.HashsigOptions) !*git.Hashsig {
        _ = self;

        if (internal.trace_log) log.debug("Handle.hashsigInit called", .{});

        var ret: *git.Hashsig = undefined;

        try internal.wrapCall("git_hashsig_create", .{
            @as(*?*c.git_hashsig, @ptrCast(&ret)),
            buf.ptr,
            buf.len,
            internal.make_c_option.hashsigOptions(options),
        });

        return ret;
    }

    /// Compute a similarity signature for a text file
    ///
    /// This walks through the file, only loading a maximum of 4K of file data at a time. Otherwise, it acts just like
    /// `Handle.hashsigInit`.
    ///
    /// ## Parameters
    /// * `buf` - The input buffer.
    /// * `options` - The signature computation options
    pub fn hashsigInitFromFile(self: Handle, path: [:0]const u8, options: git.HashsigOptions) !*git.Hashsig {
        _ = self;

        if (internal.trace_log) log.debug("Handle.hashsigInitFromFile called", .{});

        var ret: *git.Hashsig = undefined;

        try internal.wrapCall("git_hashsig_create_fromfile", .{
            @as(*?*c.git_hashsig, @ptrCast(&ret)),
            path.ptr,
            internal.make_c_option.hashsigOptions(options),
        });

        return ret;
    }

    /// Directly generate a patch from the difference between two buffers.
    ///
    /// This is just like `Diff.buffers` except it generates a patch object for the difference instead of directly making callbacks.
    /// You can use the standard `Patch` accessor functions to read the patch data, and you must call `Patch.deinit on the patch
    /// when done.
    ///
    /// ## Parameters
    /// * `old_buffer` - Raw data for old side of diff, or `null` for empty
    /// * `old_as_path` - Treat old buffer as if it had this filename; can be `null`
    /// * `new_buffer` - Raw data for new side of diff, or `null` for empty
    /// * `new_as_path` - Treat buffer as if it had this filename; can be `null`
    /// * `options` - Options for diff.
    pub fn patchFromBuffers(
        self: Handle,
        old_buffer: ?[]const u8,
        old_as_path: ?[:0]const u8,
        new_buffer: ?[]const u8,
        new_as_path: ?[:0]const u8,
        options: git.DiffOptions,
    ) !*git.Patch {
        _ = self;
        if (internal.trace_log) log.debug("Handle.patchFromBuffers called", .{});

        var ret: *git.Patch = undefined;

        const c_old_as_path = if (old_as_path) |s| s.ptr else null;
        const c_new_as_path = if (new_as_path) |s| s.ptr else null;
        const c_options = internal.make_c_option.diffOptions(options);

        var old_buffer_ptr: ?[*]const u8 = null;
        var old_buffer_len: usize = 0;

        if (old_buffer) |b| {
            old_buffer_ptr = b.ptr;
            old_buffer_len = b.len;
        }

        var new_buffer_ptr: ?[*]const u8 = null;
        var new_buffer_len: usize = 0;

        if (new_buffer) |b| {
            new_buffer_ptr = b.ptr;
            new_buffer_len = b.len;
        }

        try internal.wrapCall("git_patch_from_buffers", .{
            @as(*?*c.git_patch, @ptrCast(&ret)),
            old_buffer_ptr,
            old_buffer_len,
            c_old_as_path,
            new_buffer_ptr,
            new_buffer_len,
            c_new_as_path,
            &c_options,
        });

        return ret;
    }

    /// Determine whether a tag name is valid, meaning that (when prefixed with `refs/tags/`) that it is a valid reference name,
    /// and that any additional tag name restrictions are imposed (eg, it cannot start with a `-`).
    ///
    /// ## Parameters
    /// * `name` - Aa tag name to test
    pub fn tagNameValid(self: Handle, name: [:0]const u8) !bool {
        _ = self;
        if (internal.trace_log) log.debug("Handle.tagNameValid called", .{});

        var valid: c_int = undefined;

        try internal.wrapCall("git_tag_name_is_valid", .{
            &valid,
            name.ptr,
        });

        return valid != 0;
    }

    usingnamespace if (internal.has_libssh2) struct {
        /// Create a new ssh keyboard-interactive based credential object.
        ///
        /// ## Parameters
        /// * `username` - Username to use to authenticate.
        /// * `user_data` - Pointer to user data to be passed to the callback
        /// * `callback_fn` - The callback function
        pub fn credentialInitSshKeyInteractive(
            self: Handle,
            username: [:0]const u8,
            user_data: anytype,
            comptime callback_fn: fn (
                name: []const u8,
                instruction: []const u8,
                prompts: []*const c.LIBSSH2_USERAUTH_KBDINT_PROMPT,
                responses: []*c.LIBSSH2_USERAUTH_KBDINT_RESPONSE,
                abstract: ?*?*anyopaque,
            ) void,
        ) !*git.Credential {
            _ = self;

            const cb = struct {
                pub fn cb(
                    name: [*]const u8,
                    name_len: c_int,
                    instruction: [*]const u8,
                    instruction_len: c_int,
                    num_prompts: c_int,
                    prompts: ?*const c.LIBSSH2_USERAUTH_KBDINT_PROMPT,
                    responses: ?*c.LIBSSH2_USERAUTH_KBDINT_RESPONSE,
                    abstract: ?*?*anyopaque,
                ) callconv(.C) void {
                    callback_fn(
                        name[0..name_len],
                        instruction[0..instruction_len],
                        prompts[0..num_prompts],
                        responses[0..num_prompts],
                        abstract,
                    );
                }
            }.cb;

            if (internal.trace_log) log.debug("Handle.credentialInitSshKeyInteractive called", .{});

            var cred: *git.Credential = undefined;

            if (internal.has_credential) {
                try internal.wrapCall("git_credential_ssh_interactive_new", .{
                    @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                    username.ptr,
                    cb,
                    user_data,
                });
            } else {
                try internal.wrapCall("git_cred_ssh_interactive_new", .{
                    @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                    username.ptr,
                    cb,
                    user_data,
                });
            }

            return cred;
        }

        pub fn credentialInitSshKeyCustom(
            self: Handle,
            username: [:0]const u8,
            publickey: []const u8,
            user_data: anytype,
            comptime callback_fn: fn (
                session: *c.LIBSSH2_SESSION,
                out_signature: *[]const u8,
                data: []const u8,
                abstract: ?*?*anyopaque,
            ) c_int,
        ) !*git.Credential {
            _ = self;

            const cb = struct {
                pub fn cb(
                    session: ?*c.LIBSSH2_SESSION,
                    sig: *[*:0]u8,
                    sig_len: *usize,
                    data: [*]const u8,
                    data_len: usize,
                    abstract: ?*?*anyopaque,
                ) callconv(.C) c_int {
                    var out_sig: []const u8 = undefined;

                    const result = callback_fn(
                        session,
                        &out_sig,
                        data[0..data_len],
                        abstract,
                    );

                    sig.* = out_sig.ptr;
                    sig_len.* = out_sig.len;

                    return result;
                }
            }.cb;

            if (internal.trace_log) log.debug("Handle.credentialInitSshKeyCustom called", .{});

            var cred: *git.Credential = undefined;

            if (internal.has_credential) {
                try internal.wrapCall("git_credential_ssh_custom_new", .{
                    @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                    username.ptr,
                    publickey.ptr,
                    publickey.len,
                    cb,
                    user_data,
                });
            } else {
                try internal.wrapCall("git_cred_ssh_custom_new", .{
                    @as(*?*internal.RawCredentialType, @ptrCast(&cred)),
                    username.ptr,
                    publickey.ptr,
                    publickey.len,
                    cb,
                    user_data,
                });
            }

            return cred;
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    } else struct {};

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const CloneOptions = struct {
    /// Options to pass to the checkout step.
    checkout_options: git.CheckoutOptions = .{},

    // Options which control the fetch, including callbacks. Callbacks are for reporting fetch progress, and for
    // acquiring credentials in the event they are needed.
    // BUG: removed due to bitcast error
    //fetch_options: git.FetchOptions = .{},

    /// Set false (default) to create a standard repo or true for a bare repo.
    bare: bool = false,

    /// Whether to use a fetch or a copy of the object database.
    local: LocalType = .local_auto,

    /// Branch of the remote repository to checkout. `null` means the default.
    checkout_branch: ?[:0]const u8 = null,

    /// A callback used to create the new repository into which to clone. If `null` the `bare` field will be used to
    /// determine whether to create a bare repository.
    ///
    /// Return 0, or a negative value to indicate error
    ///
    /// ## Parameters
    /// * `out` - The resulting repository
    /// * `path` - Path in which to create the repository
    /// * `bare` - Whether the repository is bare. This is the value from the clone options
    /// * `payload` - Payload specified by the options
    repository_cb: ?*const fn (
        out: **git.Repository,
        path: [*:0]const u8,
        bare: bool,
        payload: *anyopaque,
    ) callconv(.C) void = null,

    /// An opaque payload to pass to the `repository_cb` creation callback.
    /// This parameter is ignored unless repository_cb is non-`null`.
    repository_cb_payload: ?*anyopaque = null,

    /// A callback used to create the git remote, prior to its being used to perform the clone option.
    /// This parameter may be `null`, indicating that `Handle.clone` should provide default behavior.
    ///
    /// Return 0, or an error code
    ///
    /// ## Parameters
    /// * `out` - The resulting remote
    /// * `repo` - The repository in which to create the remote
    /// * `name` - The remote's name
    /// * `url` - The remote's url
    /// * `payload` - An opaque payload
    // BUG: removed due to bitcast error
    // remote_cb: ?*const fn (
    //     out: **git.Remote,
    //     repo: *git.Repository,
    //     name: [*:0]const u8,
    //     url: [*:0]const u8,
    //     payload: ?*anyopaque,
    // ) callconv(.C) void = null,

    remote_cb_payload: ?*anyopaque = null,

    /// Options for bypassing the git-aware transport on clone. Bypassing it means that instead of a fetch,
    /// libgit2 will copy the object database directory instead of figuring out what it needs, which is faster.
    pub const LocalType = enum(c_uint) {
        /// Auto-detect (default), libgit2 will bypass the git-aware transport for local paths, but use a normal fetch for
        /// `file://` urls.
        local_auto,
        /// Bypass the git-aware transport even for a `file://` url.
        local,
        /// Do no bypass the git-aware transport
        no_local,
        /// Bypass the git-aware transport, but do not try to use hardlinks.
        local_no_links,
    };
};

comptime {
    std.testing.refAllDecls(@This());
}
