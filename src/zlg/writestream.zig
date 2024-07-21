const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const WriteStream = extern struct {
    /// if this returns non-zero this will be counted as an error
    write: *const fn (self: *WriteStream, buffer: [*:0]const u8, len: usize) callconv(.C) c_int,
    /// if this returns non-zero this will be counted as an error
    close: *const fn (self: *WriteStream) callconv(.C) c_int,
    free: *const fn (self: *WriteStream) callconv(.C) void,

    pub fn commit(self: *WriteStream) !git.Oid {
        if (internal.trace_log) log.debug("WriteStream.commit called", .{});

        var ret: git.Oid = undefined;

        try internal.wrapCall("git_blob_create_from_stream_commit", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_writestream, @ptrCast(self)),
        });

        return ret;
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_writestream), @sizeOf(WriteStream));
        try std.testing.expectEqual(@bitSizeOf(c.git_writestream), @bitSizeOf(WriteStream));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
