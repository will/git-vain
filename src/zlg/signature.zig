const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// An action signature (e.g. for committers, taggers, etc)
pub const Signature = extern struct {
    /// Use `name`
    z_name: [*:0]const u8,
    /// Use `email`
    z_email: [*:0]const u8,
    /// Time when the action happened
    when: Time,

    /// Full name of the author
    pub fn name(self: Signature) [:0]const u8 {
        return std.mem.sliceTo(self.z_name, 0);
    }

    /// Email of the author
    pub fn email(self: Signature) [:0]const u8 {
        return std.mem.sliceTo(self.z_email, 0);
    }

    /// Free an existing signature.
    pub fn deinit(self: *Signature) void {
        if (internal.trace_log) log.debug("Signature.deinit called", .{});

        c.git_signature_free(@as(*c.git_signature, @ptrCast(self)));
    }

    /// Create a new signature by parsing the given buffer, which is expected to be in the format
    /// "Real Name <email> timestamp tzoffset", where `timestamp` is the number of seconds since the Unix epoch and `tzoffset` is
    /// the timezone offset in `hhmm` format (note the lack of a colon separator).
    ///
    /// ## Parameters
    /// * `buf` - Signature string
    pub fn fromSlice(buf: [:0]const u8) !*Signature {
        if (internal.trace_log) log.debug("Signature.fromSlice called", .{});

        var ret: *git.Signature = undefined;

        try internal.wrapCall("git_signature_from_buffer", .{
            @as(*?*c.git_signature, @ptrCast(&ret)),
            buf.ptr,
        });

        return ret;
    }

    /// Create a copy of an existing signature. All internal strings are also duplicated.
    pub fn duplicate(self: *const git.Signature) !*git.Signature {
        if (internal.trace_log) log.debug("Signature.duplicate called", .{});

        var ret: *git.Signature = undefined;

        try internal.wrapCall("git_signature_dup", .{
            @as(*?*c.git_signature, @ptrCast(&ret)),
            @as(*const c.git_signature, @ptrCast(self)),
        });

        return ret;
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_signature), @sizeOf(Signature));
        try std.testing.expectEqual(@bitSizeOf(c.git_signature), @bitSizeOf(Signature));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const Time = extern struct {
    /// time in seconds from epoch
    time: SystemTime,
    /// timezone offset, in minutes
    offset: c_int,
    /// indicator for questionable '-0000' offsets in signature
    sign: u8,

    pub const SystemTime = c.git_time_t;

    test {
        try std.testing.expectEqual(@sizeOf(c.git_time), @sizeOf(Time));
        try std.testing.expectEqual(@bitSizeOf(c.git_time), @bitSizeOf(Time));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
