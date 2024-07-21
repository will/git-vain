const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Remote = opaque {
    /// Free the memory associated with a remote.
    pub fn deinit(self: *Remote) !void {
        if (internal.trace_log) log.debug("Remote.deinit called", .{});

        c.git_remote_free(@as(*c.git_remote, @ptrCast(self)));
    }

    /// Create a copy of an existing remote. All internal strings are also duplicated. Callbacks are not duplicated.
    pub fn duplicate(self: *Remote) !*Remote {
        if (internal.trace_log) log.debug("Remote.duplicate called", .{});

        var remote: *Remote = undefined;

        try internal.wrapCall("git_remote_dup", .{
            @as(*?*c.git_remote, @ptrCast(&remote)),
            @as(*c.git_remote, @ptrCast(self)),
        });

        return remote;
    }

    /// Get the remote's repository.
    pub fn getOwner(self: *const Remote) ?*git.Repository {
        if (internal.trace_log) log.debug("Remote.getOwner called", .{});

        return @as(
            ?*git.Repository,
            @ptrCast(c.git_remote_owner(@as(*const c.git_remote, @ptrCast(self)))),
        );
    }

    /// Get the remote's name.
    pub fn getName(self: *const Remote) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Remote.getName called", .{});

        return if (c.git_remote_name(@as(*const c.git_remote, @ptrCast(self)))) |r|
            std.mem.sliceTo(r, 0)
        else
            null;
    }

    /// Get the remote's url
    ///
    /// If url.*.insteadOf has been configured for this URL, it will return the modified URL.
    pub fn getUrl(self: *const Remote) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Remote.getUrl called", .{});

        return if (c.git_remote_url(@as(*const c.git_remote, @ptrCast(self)))) |r|
            std.mem.sliceTo(r, 0)
        else
            null;
    }

    /// Get the remote's url for pushing.
    pub fn getPushUrl(self: *const Remote) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Remote.getPushUrl called", .{});

        return if (c.git_remote_pushurl(@as(*const c.git_remote, @ptrCast(self)))) |r|
            std.mem.sliceTo(r, 0)
        else
            null;
    }

    /// Get the remote's list of fetch refspecs.
    ///
    /// The memory is owned by the caller and should be free with StrArray.deinit.
    pub fn getFetchRefspecs(self: *const Remote) !git.StrArray {
        if (internal.trace_log) log.debug("Remote.getFetchRefspecs called", .{});

        var ret: git.StrArray = .{};

        try internal.wrapCall("git_remote_get_fetch_refspecs", .{
            @as(*c.git_strarray, @ptrCast(&ret)),
            @as(*const c.git_remote, @ptrCast(self)),
        });

        return ret;
    }

    /// Get the remote's list of push refspecs.
    ///
    /// The memory is owned by the caller and should be free with StrArray.deinit.
    pub fn getPushRefspecs(self: *const Remote) !git.StrArray {
        if (internal.trace_log) log.debug("Remote.getPushRefspecs called", .{});

        var ret: git.StrArray = .{};

        try internal.wrapCall("git_remote_get_push_refspecs", .{
            @as(*c.git_strarray, @ptrCast(&ret)),
            @as(*const c.git_remote, @ptrCast(self)),
        });

        return ret;
    }

    /// Get the number of refspecs for a remote.
    pub fn getRefspecCount(self: *const Remote) usize {
        if (internal.trace_log) log.debug("Remote.getRefspecsCount called", .{});

        return c.git_remote_refspec_count(@as(*const c.git_remote, @ptrCast(self)));
    }

    /// Get a refspec from the remote
    ///
    /// ## Parameters
    /// * `n` - The refspec to get.
    pub fn getRefspec(self: *const Remote, n: usize) ?*const git.Refspec {
        if (internal.trace_log) log.debug("Remote.getRefspec called", .{});

        return @as(
            ?*const git.Refspec,
            @ptrCast(c.git_remote_get_refspec(@as(*const c.git_remote, @ptrCast(self)), n)),
        );
    }

    /// Open a connection to a remote.
    ///
    /// ## Parameters
    /// * `direction` - Fetch if you want to fetch or push if you want to push.
    /// * `callbacks` - The callbacks to use for this connection.
    /// * `proxy_opts` - Proxy settings.
    /// * `custom_headers` - Extra HTTP headers to use in this connection.
    pub fn connect(
        self: *Remote,
        direction: git.Direction,
        callbacks: git.RemoteCallbacks,
        proxy_opts: git.ProxyOptions,
        custom_headers: git.StrArray,
    ) !void {
        if (internal.trace_log) log.debug("Remote.connect called", .{});

        const c_proxy_opts = internal.make_c_option.proxyOptions(proxy_opts);

        try internal.wrapCall("git_remote_connect", .{
            @as(*c.git_remote, @ptrCast(self)),
            @intFromEnum(direction),
            @as(*const c.git_remote_callbacks, @ptrCast(&callbacks)),
            &c_proxy_opts,
            @as(*const c.git_strarray, @ptrCast(&custom_headers)),
        });
    }

    /// Get the remote repository's reference advertisement list
    ///
    /// Get the list of references with which the server responds to a new connection.
    ///
    /// The remote (or more exactly its transport) must have connected to the remote repository. This list is available
    /// as soon as the connection to the remote is initiated and it remains available after disconnecting.
    ///
    /// The memory belongs to the remote. The pointer will be valid as long as a new connection is not initiated, but
    /// it is recommended that you make a copy in order to make use of the data.
    pub fn ls(self: *Remote) ![]*const Head {
        if (internal.trace_log) log.debug("Remote.ls called", .{});

        var head_ptr: [*]*const Head = undefined;
        var head_n: usize = undefined;

        try internal.wrapCall("git_remote_ls", .{
            @as(*?[*]?*const c.git_remote_head, @ptrCast(&head_ptr)),
            &head_n,
            @as(*c.git_remote, @ptrCast(self)),
        });

        return head_ptr[0..head_n];
    }

    /// Description of a reference advertised by a remote server, given out on `ls` calls.
    pub const Head = extern struct {
        /// use `isLocal()`
        z_local: c_int,
        oid: git.Oid,
        loid: git.Oid,
        /// use `getName()`
        z_name: [*:0]u8,
        /// use `getSymrefTarget()`
        z_symref_target: ?[*:0]u8,

        // is available locally
        pub fn isLocal(self: Head) bool {
            return self.z_local != 0;
        }

        pub fn getName(self: Head) [:0]const u8 {
            return std.mem.sliceTo(self.z_name, 0);
        }

        /// If the server send a symref mapping for this ref, this will point to the target.
        pub fn getSymrefTarget(self: Head) ?[:0]const u8 {
            if (internal.trace_log) log.debug("Remote.getUrl called", .{});

            return if (self.z_symref_target) |s|
                std.mem.sliceTo(s, 0)
            else
                null;
        }

        test {
            try std.testing.expectEqual(@sizeOf(c.git_remote_head), @sizeOf(Head));
            try std.testing.expectEqual(@bitSizeOf(c.git_remote_head), @bitSizeOf(Head));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Check whether the remote is connected.
    ///
    /// Check whether the remote's underlying transport is connected to the remote host.
    pub fn connected(self: *const Remote) bool {
        if (internal.trace_log) log.debug("Remote.connected called", .{});

        return c.git_remote_connected(@as(*const c.git_remote, @ptrCast(self))) != 0;
    }

    /// Cancel the operation.
    ///
    /// At certain points in its operation, the network code checks whether the operation has been cancelled and if so
    /// stops the operation.
    pub fn stop(self: *Remote) !void {
        if (internal.trace_log) log.debug("Remote.stop called", .{});

        try internal.wrapCall("git_remote_stop", .{
            @as(*c.git_remote, @ptrCast(self)),
        });
    }

    /// Disconnect from the remote
    ///
    /// Close the connection to the remote.
    pub fn disconnect(self: *Remote) !void {
        if (internal.trace_log) log.debug("Remote.diconnect called", .{});

        try internal.wrapCall("git_remote_disconnect", .{
            @as(*c.git_remote, @ptrCast(self)),
        });
    }

    /// Download and index the packfile
    ///
    /// Connect to the remote if it hasn't been done yet, negotiate with the remote git which objects are missing,
    /// download and index the packfile.
    ///
    /// The .idx file will be created and both it and the packfile with be renamed to their final name.
    ///
    /// ## Parameters
    /// * `refspecs` - The refspecs to use for this negotiation and download. Use an empty array to use the base refspecs
    /// * `options` - The options to use for this fetch
    pub fn download(self: *Remote, refspecs: git.StrArray, options: FetchOptions) !void {
        if (internal.trace_log) log.debug("Remote.download called", .{});

        const c_options = internal.make_c_option.fetchOptions(options);

        try internal.wrapCall("git_remote_download", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(&refspecs)),
            &c_options,
        });
    }

    /// Create a packfile and send it to the server
    ///
    /// Connect to the remote if it hasn't been done yet, negotiate with the remote git which objects are missing, create a
    /// packfile with the missing objects and send it.
    ///
    /// ## Parameters
    /// * refspecs - the refspecs to use for this negotiation and upload. Use an empty array to use the base refspecs.
    /// * options - the options to use for this push.
    pub fn upload(self: *Remote, refspecs: git.StrArray, options: PushOptions) !void {
        if (internal.trace_log) log.debug("Remote.upload called", .{});

        const c_options = internal.make_c_option.pushOptions(options);

        try internal.wrapCall("git_remote_upload", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(&refspecs)),
            &c_options,
        });
    }

    /// Update the tips to the new state.
    ///
    /// ## Parameters
    /// * `callbacks` - The callback structure to use
    /// * `update_fetchhead` - Whether to write to FETCH_HEAD. Pass true to behave like git.
    /// * `download_tags` - What the behaviour for downloading tags is for this fetch.
    ///                     This is ignored for push.
    ///                     This must be the same value passed to `Remote.download()`.
    /// * `reflog_message` - The message to insert into the reflogs.
    ///                      If `null` and fetching, the default is "fetch <name>", where <name> is the name of the remote
    ///                      (or its url, for in-memory remotes).
    ///                      This parameter is ignored when pushing.
    pub fn updateTips(
        self: *Remote,
        callbacks: RemoteCallbacks,
        update_fetchead: bool,
        download_tags: RemoteAutoTagOption,
        reflog_message: ?[:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Remote.updateTips called", .{});

        const c_reflog_message = if (reflog_message) |s| s.ptr else null;

        try internal.wrapCall("git_remote_update_tips", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_remote_callbacks, @ptrCast(&callbacks)),
            @intFromBool(update_fetchead),
            @intFromEnum(download_tags),
            c_reflog_message,
        });
    }

    /// Download new data and update tips.
    ///
    /// ## Parameters
    /// * `refspecs` - The refspecs to use for this fetch. Pass an empty array to use the base refspecs.
    /// * `options` - Options to use for this fetch.
    /// * `reflog_message` - The message to insert into the reflogs. If `null`, the default is "fetch".
    pub fn fetch(
        self: *Remote,
        refspecs: git.StrArray,
        options: FetchOptions,
        reflog_message: ?[:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Remote.fetch called", .{});

        const c_reflog_message = if (reflog_message) |s| s.ptr else null;
        const c_options = internal.make_c_option.fetchOptions(options);

        try internal.wrapCall("git_remote_fetch", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(&refspecs)),
            &c_options,
            c_reflog_message,
        });
    }

    /// Prune tracking refs that are no longer present on remote.
    ///
    /// ## Parameters
    /// * `callbacks` - Callbacks to use for this prune.
    pub fn prune(self: *Remote, callbacks: RemoteCallbacks) !void {
        if (internal.trace_log) log.debug("Remote.prune called", .{});

        try internal.wrapCall("git_remote_prune", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_remote_callbacks, @ptrCast(&callbacks)),
        });
    }

    /// Preform a push.
    ///
    /// ## Parameters
    /// * `refspecs` - The refspecs to use for pushing. If an empty array is provided, the configured refspecs will be used.
    /// * `options` - The options to use for this push.
    pub fn push(self: *Remote, refspecs: git.StrArray, options: PushOptions) !void {
        if (internal.trace_log) log.debug("Remote.push called", .{});

        const c_options = internal.make_c_option.pushOptions(options);

        try internal.wrapCall("git_remote_push", .{
            @as(*c.git_remote, @ptrCast(self)),
            @as(*const c.git_strarray, @ptrCast(&refspecs)),
            &c_options,
        });
    }

    /// Get the statistics structure that is filled in by the fetch operation.
    pub fn getStats(self: *Remote) *const git.IndexerProgress {
        if (internal.trace_log) log.debug("Remote.getStats called", .{});

        return @as(
            *const git.IndexerProgress,
            @ptrCast(c.git_remote_stats(@as(*c.git_remote, @ptrCast(self)))),
        );
    }

    /// Retrieve the tag auto-follow setting.
    pub fn getAutotag(self: *const Remote) RemoteAutoTagOption {
        if (internal.trace_log) log.debug("Remote.getAutotag called", .{});

        return @as(
            RemoteAutoTagOption,
            @enumFromInt(c.git_remote_autotag(@as(*const c.git_remote, @ptrCast(self)))),
        );
    }

    /// Retrieve the ref-prune setting.
    pub fn getPruneRefSetting(self: *const Remote) bool {
        if (internal.trace_log) log.debug("Remote.getPruneRefSetting called", .{});

        return c.git_remote_prune_refs(@as(*const c.git_remote, @ptrCast(self))) != 0;
    }

    /// Retrieve the name of the remote's default branch
    ///
    /// The default branch of a repository is the branch which HEAD points to. If the remote does not support reporting this
    /// information directly, it performs the guess as git does; that is, if there are multiple branches which point to the
    /// same commit, the first one is chosen. If the master branch is a candidate, it wins.
    ///
    /// This function must only be called after connecting.
    pub fn defaultBranch(self: *Remote) !git.Buf {
        if (internal.trace_log) log.debug("Remote.defaultBranch called", .{});

        var buf = git.Buf{};

        try internal.wrapCall("git_remote_default_branch", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*c.git_remote, @ptrCast(self)),
        });

        return buf;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Automatic tag following option.
pub const RemoteAutoTagOption = enum(c_uint) {
    /// Use the setting from the configuration.
    unspecified = 0,

    /// Ask the server for tags pointing to objects we're already downloading.
    auto,

    /// Don't ask for any tags beyond the refspecs.
    none,

    /// Ask for all the tags.
    all,
};

/// Remote creation options structure.
pub const RemoteCreateOptions = struct {
    /// The repository that should own the remote.
    /// Setting this to `null` results in a detached remote.
    repository: ?*git.Repository = null,

    /// The remote's name.
    /// Setting this to `null` results in an in-memory/anonymous remote.
    name: ?[:0]const u8 = null,

    /// The fetchspec the remote should use.
    fetchspec: ?[:0]const u8 = null,

    /// Additional flags for the remote
    flags: RemoteCreateFlags = .{},

    /// Remote creation options flags.
    pub const RemoteCreateFlags = packed struct {
        /// Ignore the repository apply.insteadOf configuration.
        skip_insteadof: bool = false,

        /// Don't build a fetchspec from the name if none is set.
        skip_default_fetchspec: bool = false,

        z_padding: u30 = 0,

        pub fn format(
            value: RemoteCreateFlags,
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
            try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(RemoteCreateFlags));
            try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(RemoteCreateFlags));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Fetch options structure.
pub const FetchOptions = struct {
    /// Callbacks to use for this fetch operation.
    callbacks: RemoteCallbacks = .{},

    /// Whether to perform a prune after the fetch.
    prune: FetchPrune = .unspecified,

    /// Whether to write the results to FETCH_HEAD. Defaults to on. Leave this default to behave like git.
    update_fetchhead: bool = true,

    /// Determines how to behave regarding tags on the remote, such as auto-dowloading tags for objects we're
    /// downloading or downloading all of them. The default is to auto-follow tags.
    download_tags: RemoteAutoTagOption = .unspecified,

    /// Proxy options to use, bu default no proxy is used.
    proxy_opts: git.ProxyOptions = .{},

    /// Extra headers for this fetch operation.
    custom_headers: git.StrArray = .{},

    /// Acceptable prune settings from the configuration.
    pub const FetchPrune = enum(c_uint) {
        /// Use the setting from the configuration.
        unspecified = 0,

        /// Force pruning on.
        prune,

        /// Force pruning off.
        no_prune,
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const PushOptions = struct {
    /// If the transport being used to push to the remote requires the creation of a pack file, this controls the
    /// number of worker threads used by the packbuilder when creating that pack file to be sent to the remote.
    /// If set to 0, the packbuilder will auto-detect the number of threads to create. The default value is 1.
    pb_parallelism: c_uint = 1,

    ///Callbacks to use for this push operation
    callbacks: RemoteCallbacks = .{},

    ///Proxy options to use, by default no proxy is used.
    proxy_opts: git.ProxyOptions = .{},

    ///Extra headers for this push operation
    custom_headers: git.StrArray = .{},
};

/// Set the callbacks to be called by the remote when informing the user about the progress of the network operations.
pub const RemoteCallbacks = extern struct {
    version: c_uint = c.GIT_CHECKOUT_OPTIONS_VERSION,

    /// Textual progress from the remote. Text send over the progress side-band will be passed to this function (this is
    /// the 'counting objects' output).
    ///
    /// Return a negative value to cancel the network operation.
    ///
    /// ## Parameters
    /// * `str` - The message from the transport
    /// * `len` - The length of the message
    /// * `payload` - Payload provided by the caller
    sideband_progress: ?*const fn (str: [*:0]const u8, len: c_uint, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// Completion is called when different parts of the download process are done (currently unused).
    completion: ?*const fn (completion_type: RemoteCompletion, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// This will be called if the remote host requires authentication in order to connect to it.
    ///
    /// Return 0 for success, < 0 to indicate an error, > 0 to indicate no credential was acquired
    /// Returning `errorToCInt(GitError.Passthrough)` will make libgit2 behave as though this field isn't set.
    ///
    /// ## Parameters
    /// * `out` - The newly created credential object.
    /// * `url` - The resource for which we are demanding a credential.
    /// * `username_from_url` - The username that was embedded in a "user\@host" remote url, or `null` if not included.
    /// * `allowed_types` - A bitmask stating which credential types are OK to return.
    /// * `payload` - The payload provided when specifying this callback.
    credentials: ?*const fn (
        out: **git.Credential,
        url: [*:0]const u8,
        username_from_url: [*:0]const u8,
        allowed_types: git.CredentialType,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// If cert verification fails, this will be called to let the user make the final decision of whether to allow the
    /// connection to proceed. Returns 0 to allow the connection or a negative value to indicate an error.
    ///
    /// Return 0 to proceed with the connection, < 0 to fail the connection or > 0 to indicate that the callback refused
    /// to act and that the existing validity determination should be honored
    ///
    /// ## Parameters
    /// * `cert` - The host certificate
    /// * `valid` - Whether the libgit2 checks (OpenSSL or WinHTTP) think this certificate is valid.
    /// * `host` - Hostname of the host libgit2 connected to
    /// * `payload` - Payload provided by the caller
    certificate_check: ?*const fn (
        cert: *git.Certificate,
        valid: bool,
        host: [*:0]const u8,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// During the download of new data, this will be regularly called with the current count of progress done by the
    /// indexer.
    ///
    /// Return a value less than 0 to cancel the indexing or download.
    ///
    /// ## Parameters
    /// * `stats` - Structure containing information about the state of the transfer
    /// * `payload` - Payload provided by the caller
    transfer_progress: ?*const fn (stats: *const git.IndexerProgress, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// Each time a reference is updated locally, this function will be called with information about it.
    update_tips: ?*const fn (
        refname: [*:0]const u8,
        a: *const git.Oid,
        b: *const git.Oid,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// Function to call with progress information during pack building. Be aware that this is called inline with pack
    /// building operations, so perfomance may be affected.
    pack_progress: ?*const fn (stage: git.PackbuilderStage, current: u32, total: u32, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// Function to call with progress information during the upload portion nof a push. Be aware that this is called
    /// inline with pack building operations, so performance may be affected.
    push_transfer_progress: ?*const fn (current: c_uint, total: c_uint, size: usize, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// Callback used to inform of the update status from the remote.
    ///
    /// Called for each updated reference on push. If `status` is not `null`, the update was rejected by the remote server
    /// and `status` contains the reason given.
    ///
    /// 0 on success, otherwise an error
    ///
    /// ## Parameters
    /// * `refname` - Refname specifying to the remote ref
    /// * `status` - Status message sent from the remote
    /// * `data` - Data provided by the caller
    push_update_reference: ?*const fn (
        refname: [*:0]const u8,
        status: ?[*:0]const u8,
        data: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// Called once between the negotiation step and the upload. It provides information about what updates will be
    /// performed.
    /// Callback used to inform of upcoming updates.
    ///
    /// ## Parameters
    /// * `updates` - An array containing the updates which will be sent as commands to the destination.
    /// * `len` - Number of elements in `updates`
    /// * `payload` - Payload provided by the caller
    push_negotiation: ?*const fn (updates: [*]*const PushUpdate, len: usize, payload: ?*anyopaque) callconv(.C) c_int = null,

    /// Create the transport to use for this operation. Leave `null` to auto-detect.
    transport: ?*const fn (out: **git.Transport, owner: *Remote, param: ?*anyopaque) callconv(.C) c_int = null,

    // This will be passed to each of the callbacks in this sruct as the last parameter.
    payload: ?*anyopaque = null,

    /// Resolve URL before connecting to remote. The returned URL will be used to connect to the remote instead.
    /// This callback is deprecated; users should use git_remote_ready_cb and configure the instance URL instead.
    ///
    /// Return 0 on success, `errorToCInt(GitError.Passthrough)` or an error
    /// If you return `errorToCInt(GitError.Passthrough)`, you don't need to write anything to url_resolved.
    ///
    /// ## Parameters
    /// * `url_resolved` - The buffer to write the resolved URL to
    /// * `url` - The URL to resolve
    /// * `direction` - Direction of the resolution
    /// * `payload` - Payload provided by the caller
    resolve_url: ?*const fn (
        url_resolved: *git.Buf,
        url: [*:0]const u8,
        direction: git.Direction,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// Argument to the completion callback which tells it which operation finished.
    pub const RemoteCompletion = enum(c_uint) {
        download,
        indexing,
        @"error",
    };

    /// Represents an update which will be performed on the remote during push
    pub const PushUpdate = extern struct {
        /// The source name of the reference
        src_refname: [*:0]const u8,

        /// The name of the reference to update on the server
        dst_refname: [*:0]const u8,

        /// The current target of the reference
        src: git.Oid,

        /// The new target for the reference
        dst: git.Oid,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_push_update), @sizeOf(PushUpdate));
            try std.testing.expectEqual(@bitSizeOf(c.git_push_update), @bitSizeOf(PushUpdate));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_remote_callbacks), @sizeOf(RemoteCallbacks));
        try std.testing.expectEqual(@bitSizeOf(c.git_remote_callbacks), @bitSizeOf(RemoteCallbacks));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
