const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Config = opaque {
    pub fn deinit(self: *Config) void {
        if (internal.trace_log) log.debug("Config.deinit called", .{});

        c.git_config_free(@as(*c.git_config, @ptrCast(self)));
    }

    pub fn getEntry(self: *const Config, name: [:0]const u8) !*ConfigEntry {
        if (internal.trace_log) log.debug("Config.getEntry called", .{});

        var entry: *ConfigEntry = undefined;

        try internal.wrapCall("git_config_get_entry", .{
            @as(*?*c.git_config_entry, @ptrCast(&entry)),
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
        });

        return entry;
    }

    pub fn getInt(self: *const Config, name: [:0]const u8) !i32 {
        if (internal.trace_log) log.debug("Config.getInt called", .{});

        var value: i32 = undefined;

        try internal.wrapCall("git_config_get_int32", .{ &value, @as(*const c.git_config, @ptrCast(self)), name.ptr });

        return value;
    }

    pub fn setInt(self: *Config, name: [:0]const u8, value: i32) !void {
        if (internal.trace_log) log.debug("Config.setInt called", .{});

        try internal.wrapCall("git_config_set_int32", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, value });
    }

    pub fn getInt64(self: *const Config, name: [:0]const u8) !i64 {
        if (internal.trace_log) log.debug("Config.getInt64 called", .{});

        var value: i64 = undefined;

        try internal.wrapCall("git_config_get_int64", .{ &value, @as(*const c.git_config, @ptrCast(self)), name.ptr });

        return value;
    }

    pub fn setInt64(self: *Config, name: [:0]const u8, value: i64) !void {
        if (internal.trace_log) log.debug("Config.setInt64 called", .{});

        try internal.wrapCall("git_config_set_int64", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, value });
    }

    pub fn getBool(self: *const Config, name: [:0]const u8) !bool {
        if (internal.trace_log) log.debug("Config.getBool called", .{});

        var value: c_int = undefined;

        try internal.wrapCall("git_config_get_bool", .{ &value, @as(*const c.git_config, @ptrCast(self)), name.ptr });

        return value != 0;
    }

    pub fn setBool(self: *Config, name: [:0]const u8, value: bool) !void {
        if (internal.trace_log) log.debug("Config.setBool called", .{});

        try internal.wrapCall("git_config_set_bool", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, @intFromBool(value) });
    }

    pub fn getPath(self: *const Config, name: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Config.getPath called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_config_get_path", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
        });

        return buf;
    }

    pub fn getString(self: *const Config, name: [:0]const u8) ![:0]const u8 {
        if (internal.trace_log) log.debug("Config.getString called", .{});

        var str: ?[*:0]const u8 = undefined;

        try internal.wrapCall("git_config_get_string", .{
            &str,
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
        });

        return std.mem.sliceTo(str.?, 0);
    }

    pub fn setString(self: *Config, name: [:0]const u8, value: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Config.setString called", .{});

        try internal.wrapCall("git_config_set_string", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, value.ptr });
    }

    pub fn setMultivar(self: *Config, name: [:0]const u8, regex: [:0]const u8, value: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Config.setMultivar called", .{});

        try internal.wrapCall("git_config_set_multivar", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, regex.ptr, value.ptr });
    }

    pub fn getStringBuf(self: *const Config, name: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Config.getStringBuf called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_config_get_string_buf", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
        });

        return buf;
    }

    pub fn foreachMultivar(
        self: *const Config,
        name: [:0]const u8,
        regex: ?[:0]const u8,
        comptime callback_fn: fn (entry: *const ConfigEntry) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                entry: *const ConfigEntry,
                _: *u8,
            ) c_int {
                return callback_fn(entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachMultivarWithUserData(name, regex, &dummy_data, cb);
    }

    pub fn foreachMultivarWithUserData(
        self: *const Config,
        name: [:0]const u8,
        regex: ?[:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (entry: *const ConfigEntry, user_data_ptr: @TypeOf(user_data)) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                entry: *const c.git_config_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const ConfigEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Config.foreachMultivar called", .{});

        const regex_c = if (regex) |str| str.ptr else null;

        return try internal.wrapCallWithReturn("git_config_get_multivar_foreach", .{
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
            regex_c,
            cb,
            user_data,
        });
    }

    pub fn foreachConfig(
        self: *const Config,
        comptime callback_fn: fn (entry: *const ConfigEntry) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                entry: *const ConfigEntry,
                _: *u8,
            ) c_int {
                return callback_fn(entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachConfigWithUserData(&dummy_data, cb);
    }

    pub fn foreachConfigWithUserData(
        self: *const Config,
        user_data: anytype,
        comptime callback_fn: fn (entry: *const ConfigEntry, user_data_ptr: @TypeOf(user_data)) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                entry: *const c.git_config_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const ConfigEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Config.foreachConfig called", .{});

        return try internal.wrapCallWithReturn("git_config_foreach", .{
            @as(*const c.git_config, @ptrCast(self)),
            cb,
            user_data,
        });
    }

    pub fn foreachConfigMatch(
        self: *const Config,
        regex: [:0]const u8,
        comptime callback_fn: fn (entry: *const ConfigEntry) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                entry: *const ConfigEntry,
                _: *u8,
            ) c_int {
                return callback_fn(entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachConfigMatchWithUserData(regex, &dummy_data, cb);
    }

    pub fn foreachConfigMatchWithUserData(
        self: *const Config,
        regex: [:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (entry: *const ConfigEntry, user_data_ptr: @TypeOf(user_data)) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                entry: *const c.git_config_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const ConfigEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Config.foreachConfigMatch called", .{});

        return try internal.wrapCallWithReturn("git_config_foreach_match", .{
            @as(*const c.git_config, @ptrCast(self)),
            regex.ptr,
            cb,
            user_data,
        });
    }

    pub fn deleteEntry(self: *Config, name: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Config.deleteEntry called", .{});

        try internal.wrapCall("git_config_delete_entry", .{ @as(*c.git_config, @ptrCast(self)), name.ptr });
    }

    pub fn deleteMultivar(self: *Config, name: [:0]const u8, regex: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Config.deleteMultivar called", .{});

        try internal.wrapCall("git_config_delete_multivar", .{ @as(*c.git_config, @ptrCast(self)), name.ptr, regex.ptr });
    }

    pub fn addFileOnDisk(self: *Config, path: [:0]const u8, level: ConfigLevel, repo: *const git.Repository, force: bool) !void {
        if (internal.trace_log) log.debug("Config.addFileOnDisk called", .{});

        try internal.wrapCall("git_config_add_file_ondisk", .{
            @as(*c.git_config, @ptrCast(self)),
            path.ptr,
            @intFromEnum(level),
            @as(*const c.git_repository, @ptrCast(repo)),
            @intFromBool(force),
        });
    }

    pub fn openLevel(self: *const Config, level: ConfigLevel) !*Config {
        if (internal.trace_log) log.debug("Config.openLevel called", .{});

        var config: *Config = undefined;

        try internal.wrapCall("git_config_open_level", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            @as(*const c.git_config, @ptrCast(self)),
            @intFromEnum(level),
        });

        return config;
    }

    pub fn openGlobal(self: *git.Config) !*Config {
        if (internal.trace_log) log.debug("Config.openGlobal called", .{});

        var config: *Config = undefined;

        try internal.wrapCall("git_config_open_global", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            @as(*c.git_config, @ptrCast(self)),
        });

        return config;
    }

    pub fn snapshot(self: *git.Config) !*Config {
        if (internal.trace_log) log.debug("Config.snapshot called", .{});

        var config: *Config = undefined;

        try internal.wrapCall("git_config_snapshot", .{
            @as(*?*c.git_config, @ptrCast(&config)),
            @as(*c.git_config, @ptrCast(self)),
        });

        return config;
    }

    pub fn lock(self: *Config) !*git.Transaction {
        if (internal.trace_log) log.debug("Config.lock called", .{});

        var transaction: *git.Transaction = undefined;

        try internal.wrapCall("git_config_lock", .{
            @as(*?*c.git_transaction, @ptrCast(&transaction)),
            @as(*c.git_config, @ptrCast(self)),
        });

        return transaction;
    }

    pub fn iterateMultivar(self: *const Config, name: [:0]const u8, regex: ?[:0]const u8) !*ConfigIterator {
        if (internal.trace_log) log.debug("Config.iterateMultivar called", .{});

        var iterator: *ConfigIterator = undefined;

        const regex_c = if (regex) |str| str.ptr else null;

        try internal.wrapCall("git_config_multivar_iterator_new", .{
            @as(*?*c.git_config_iterator, @ptrCast(&iterator)),
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
            regex_c,
        });

        return iterator;
    }

    pub fn iterate(self: *const Config) !*ConfigIterator {
        if (internal.trace_log) log.debug("Config.iterate called", .{});

        var iterator: *ConfigIterator = undefined;

        try internal.wrapCall("git_config_iterator_new", .{
            @as(*?*c.git_config_iterator, @ptrCast(&iterator)),
            @as(*const c.git_config, @ptrCast(self)),
        });

        return iterator;
    }

    pub fn iterateGlob(self: *const Config, regex: [:0]const u8) !*ConfigIterator {
        if (internal.trace_log) log.debug("Config.iterateGlob called", .{});

        var iterator: *ConfigIterator = undefined;

        try internal.wrapCall("git_config_iterator_glob_new", .{
            @as(*?*c.git_config_iterator, @ptrCast(&iterator)),
            @as(*const c.git_config, @ptrCast(self)),
            regex.ptr,
        });

        return iterator;
    }

    pub const ConfigIterator = opaque {
        pub fn next(self: *ConfigIterator) !?*ConfigEntry {
            if (internal.trace_log) log.debug("ConfigIterator.next called", .{});

            var entry: *ConfigEntry = undefined;

            internal.wrapCall("git_config_next", .{
                @as(*?*c.git_config_entry, @ptrCast(&entry)),
                @as(*c.git_config_iterator, @ptrCast(self)),
            }) catch |err| switch (err) {
                git.GitError.IterOver => return null,
                else => |e| return e,
            };

            return entry;
        }

        pub fn deinit(self: *ConfigIterator) void {
            if (internal.trace_log) log.debug("ConfigIterator.deinit called", .{});

            c.git_config_iterator_free(@as(*c.git_config_iterator, @ptrCast(self)));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub fn getMapped(self: *const Config, name: [:0]const u8, maps: []const ConfigMap) !c_int {
        if (internal.trace_log) log.debug("Config.getMapped called", .{});

        var value: c_int = undefined;

        try internal.wrapCall("git_config_get_mapped", .{
            &value,
            @as(*const c.git_config, @ptrCast(self)),
            name.ptr,
            @as([*]const c.git_configmap, @ptrCast(maps.ptr)),
            maps.len,
        });

        return value;
    }

    pub fn parseBool(value: [:0]const u8) !bool {
        if (internal.trace_log) log.debug("Config.parseBool called", .{});

        var res: c_int = undefined;
        try internal.wrapCall("git_config_parse_bool", .{ &res, value.ptr });
        return res != 0;
    }

    pub fn parseInt(value: [:0]const u8) !i32 {
        if (internal.trace_log) log.debug("Config.parseInt called", .{});

        var res: i32 = undefined;
        try internal.wrapCall("git_config_parse_int32", .{ &res, value.ptr });
        return res;
    }

    pub fn parseInt64(value: [:0]const u8) !i64 {
        if (internal.trace_log) log.debug("Config.parseInt64 called", .{});

        var res: i64 = undefined;
        try internal.wrapCall("git_config_parse_int64", .{ &res, value.ptr });
        return res;
    }

    pub fn parsePath(value: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Config.parsePath called", .{});

        var buf: git.Buf = .{};
        try internal.wrapCall("git_config_parse_path", .{ @as(*c.git_buf, @ptrCast(&buf)), value.ptr });
        return buf;
    }

    pub const ConfigMap = extern struct {
        map_type: MapType,
        str_match: [*:0]const u8,
        map_value: c_int,

        pub const MapType = enum(c_int) {
            false = 0,
            true = 1,
            int32 = 2,
            string = 3,
        };

        pub fn lookupMapValue(maps: []const ConfigMap, value: [:0]const u8) !c_int {
            if (internal.trace_log) log.debug("ConfigMap.lookupMapValue called", .{});

            var result: c_int = undefined;

            try internal.wrapCall("git_config_lookup_map_value", .{
                &result,
                @as([*]const c.git_configmap, @ptrCast(maps.ptr)),
                maps.len,
                value.ptr,
            });

            return result;
        }

        test {
            try std.testing.expectEqual(@sizeOf(c.git_configmap), @sizeOf(ConfigMap));
            try std.testing.expectEqual(@bitSizeOf(c.git_configmap), @bitSizeOf(ConfigMap));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    pub const ConfigEntry = extern struct {
        /// Name of the entry (normalised)
        name: [*:0]const u8,
        /// String value of the entry
        value: [*:0]const u8,
        /// Depth of includes where this variable was found
        include_depth: u32,
        /// Which config file this was found in
        level: ConfigLevel,
        /// Free function for this entry
        free_fn: ?*const fn (?*ConfigEntry) callconv(.C) void,
        /// Opaque value for the free function. Do not read or write
        payload: *anyopaque,

        pub fn deinit(self: *ConfigEntry) void {
            if (internal.trace_log) log.debug("ConfigEntry.deinit called", .{});

            c.git_config_entry_free(@as(*c.git_config_entry, @ptrCast(self)));
        }

        test {
            try std.testing.expectEqual(@sizeOf(c.git_config_entry), @sizeOf(ConfigEntry));
            try std.testing.expectEqual(@bitSizeOf(c.git_config_entry), @bitSizeOf(ConfigEntry));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const ConfigBackend = opaque {
    pub fn foreachConfigBackendMatch(
        self: *const ConfigBackend,
        regex: [:0]const u8,
        comptime callback_fn: fn (entry: *const Config.ConfigEntry) c_int,
    ) !c_int {
        const cb = struct {
            pub fn cb(
                entry: *const Config.ConfigEntry,
                _: *u8,
            ) c_int {
                return callback_fn(entry);
            }
        }.cb;

        var dummy_data: u8 = undefined;
        return self.foreachConfigBackendMatchWithUserData(regex, &dummy_data, cb);
    }

    pub fn foreachConfigBackendMatchWithUserData(
        self: *const ConfigBackend,
        regex: [:0]const u8,
        user_data: anytype,
        comptime callback_fn: fn (entry: *const Config.ConfigEntry, user_data_ptr: @TypeOf(user_data)) c_int,
    ) !c_int {
        const UserDataType = @TypeOf(user_data);

        const cb = struct {
            pub fn cb(
                entry: *const c.git_config_entry,
                payload: ?*anyopaque,
            ) callconv(.C) c_int {
                return callback_fn(
                    @as(*const Config.ConfigEntry, @ptrCast(entry)),
                    @as(UserDataType, @ptrCast(@alignCast(payload))),
                );
            }
        }.cb;

        if (internal.trace_log) log.debug("Config.foreachConfigBackendMatch called", .{});

        return try internal.wrapCallWithReturn("git_config_backend_foreach_match", .{
            @as(*const c.git_config_backend, @ptrCast(self)),
            regex.ptr,
            cb,
            user_data,
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Priority level of a config file.
pub const ConfigLevel = enum(c_int) {
    /// System-wide on Windows, for compatibility with portable git
    programdata = 1,
    /// System-wide configuration file; /etc/gitconfig on Linux systems
    system = 2,
    /// XDG compatible configuration file; typically ~/.config/git/config
    xdg = 3,
    /// User-specific configuration file (also called Global configuration file); typically ~/.gitconfig
    global = 4,
    /// Repository specific configuration file; $WORK_DIR/.git/config on non-bare repos
    local = 5,
    /// Application specific configuration file; freely defined by applications
    app = 6,
    /// Represents the highest level available config file (i.e. the most specific config file available that actually is
    /// loaded)
    highest = -1,
};

comptime {
    std.testing.refAllDecls(@This());
}
