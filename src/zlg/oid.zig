const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Unique identity of any object (commit, tree, blob, tag).
pub const Oid = extern struct {
    id: [20]u8,

    /// Minimum length (in number of hex characters, i.e. packets of 4 bits) of an oid prefix
    pub const min_prefix_len = c.GIT_OID_MINPREFIXLEN;

    /// Size (in bytes) of a hex formatted oid
    pub const hex_buffer_size = c.GIT_OID_HEXSZ;

    pub const zero: Oid = .{ .id = [_]u8{0} ** 20 };

    pub fn formatHexAlloc(self: Oid, allocator: *std.mem.Allocator) ![]const u8 {
        const buf = try allocator.alloc(u8, hex_buffer_size);
        errdefer allocator.free(buf);
        return try self.formatHex(buf);
    }

    /// `buf` must be atleast `hex_buffer_size` long.
    pub fn formatHex(self: *const Oid, buf: []u8) ![]const u8 {
        if (buf.len < hex_buffer_size) return error.BufferTooShort;

        try internal.wrapCall("git_oid_fmt", .{ buf.ptr, @as(*const c.git_oid, @ptrCast(self)) });

        return buf[0..hex_buffer_size];
    }

    pub fn formatHexAllocZ(self: *const Oid, allocator: *std.mem.Allocator) ![:0]const u8 {
        const buf = try allocator.allocSentinel(u8, hex_buffer_size, 0);
        errdefer allocator.free(buf);
        return (try self.formatHex(buf))[0.. :0];
    }

    /// `buf` must be atleast `hex_buffer_size + 1` long.
    pub fn formatHexZ(self: *const Oid, buf: []u8) ![:0]const u8 {
        if (buf.len < (hex_buffer_size + 1)) return error.BufferTooShort;

        try internal.wrapCall("git_oid_fmt", .{ buf.ptr, @as(*const c.git_oid, @ptrCast(&self)) });
        buf[hex_buffer_size] = 0;

        return buf[0..hex_buffer_size :0];
    }

    /// Allows partial output
    pub fn formatHexCountAlloc(self: Oid, allocator: *std.mem.Allocator, length: usize) ![]const u8 {
        const buf = try allocator.alloc(u8, length);
        errdefer allocator.free(buf);
        return try self.formatHexCount(buf, length);
    }

    /// Allows partial output
    pub fn formatHexCount(self: *const Oid, buf: []u8, length: usize) ![]const u8 {
        if (buf.len < length) return error.BufferTooShort;

        try internal.wrapCall("git_oid_nfmt", .{ buf.ptr, length, @as(*const c.git_oid, @ptrCast(self)) });

        return buf[0..length];
    }

    /// Allows partial output
    pub fn formatHexCountAllocZ(self: Oid, allocator: *std.mem.Allocator, length: usize) ![:0]const u8 {
        const buf = try allocator.allocSentinel(u8, length, 0);
        errdefer allocator.free(buf);
        return (try self.formatHexCount(buf, length))[0.. :0];
    }

    /// Allows partial output
    pub fn formatHexCountZ(self: *const Oid, buf: []u8, length: usize) ![:0]const u8 {
        if (buf.len < (length + 1)) return error.BufferTooShort;

        try internal.wrapCall("git_oid_nfmt", .{ buf.ptr, length, @as(*const c.git_oid, @ptrCast(self)) });
        buf[length] = 0;

        return buf[0..length :0];
    }

    pub fn formatHexPathAlloc(self: Oid, allocator: *std.mem.Allocator) ![]const u8 {
        const buf = try allocator.alloc(u8, hex_buffer_size + 1);
        errdefer allocator.free(buf);
        return try self.formatHexPath(buf);
    }

    /// `buf` must be atleast `hex_buffer_size + 1` long.
    pub fn formatHexPath(self: *const Oid, buf: []u8) ![]const u8 {
        if (buf.len < hex_buffer_size + 1) return error.BufferTooShort;

        try internal.wrapCall("git_oid_pathfmt", .{ buf.ptr, @as(*const c.git_oid, @ptrCast(self)) });

        return buf[0..hex_buffer_size];
    }

    pub fn formatHexPathAllocZ(self: Oid, allocator: *std.mem.Allocator) ![:0]const u8 {
        const buf = try allocator.allocSentinel(u8, hex_buffer_size + 1, 0);
        errdefer allocator.free(buf);
        return (try self.formatHexPath(buf))[0.. :0];
    }

    /// `buf` must be atleast `hex_buffer_size + 2` long.
    pub fn formatHexPathZ(self: *const Oid, buf: []u8) ![:0]const u8 {
        if (buf.len < (hex_buffer_size + 2)) return error.BufferTooShort;

        try internal.wrapCall("git_oid_pathfmt", .{ buf.ptr, @as(*const c.git_oid, @ptrCast(self)) });
        buf[hex_buffer_size] = 0;

        return buf[0..hex_buffer_size :0];
    }

    /// <0 if a < b; 0 if a == b; >0 if a > b
    pub fn compare(a: *const Oid, b: *const Oid) c_int {
        return c.git_oid_cmp(@as(*const c.git_oid, @ptrCast(a)), @as(*const c.git_oid, @ptrCast(b)));
    }

    pub fn equal(self: *const Oid, other: *const Oid) bool {
        return c.git_oid_equal(@as(*const c.git_oid, @ptrCast(self)), @as(*const c.git_oid, @ptrCast(other))) == 1;
    }

    pub fn compareCount(self: *const Oid, other: *const Oid, count: usize) bool {
        return c.git_oid_ncmp(@as(*const c.git_oid, @ptrCast(self)), @as(*const c.git_oid, @ptrCast(other)), count) == 0;
    }

    pub fn equalStr(self: *const Oid, str: [:0]const u8) bool {
        return c.git_oid_streq(@as(*const c.git_oid, @ptrCast(self)), str.ptr) == 0;
    }

    /// <0 if a < str; 0 if a == str; >0 if a > str
    pub fn compareStr(a: *const Oid, str: [:0]const u8) c_int {
        return c.git_oid_strcmp(@as(*const c.git_oid, @ptrCast(a)), str.ptr);
    }

    pub fn allZeros(self: Oid) bool {
        for (self.id) |i| if (i != 0) return false;
        return true;
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_oid), @sizeOf(Oid));
        try std.testing.expectEqual(@bitSizeOf(c.git_oid), @bitSizeOf(Oid));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// The OID shortener is used to process a list of OIDs in text form and return the shortest length that would uniquely identify
/// all of them.
///
/// E.g. look at the result of `git log --abbrev-commit`.
pub const OidShortener = opaque {
    pub fn add(self: *OidShortener, str: []const u8) !c_uint {
        if (internal.trace_log) log.debug("OidShortener.add called", .{});

        if (str.len < Oid.hex_buffer_size) return error.BufferTooShort;

        const ret = try internal.wrapCallWithReturn("git_oid_shorten_add", .{
            @as(*c.git_oid_shorten, @ptrCast(self)),
            str.ptr,
        });

        return @as(c_uint, @bitCast(ret));
    }

    pub fn deinit(self: *OidShortener) void {
        if (internal.trace_log) log.debug("OidShortener.deinit called", .{});

        c.git_oid_shorten_free(@as(*c.git_oid_shorten, @ptrCast(self)));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
