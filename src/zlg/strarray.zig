const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const StrArray = extern struct {
    strings: ?[*][*:0]u8 = null,
    count: usize = 0,

    pub fn fromSlice(slice: [][*:0]u8) StrArray {
        return .{
            .strings = slice.ptr,
            .count = slice.len,
        };
    }

    pub fn toSlice(self: StrArray) []const [*:0]const u8 {
        if (self.count == 0) return &[_][*:0]const u8{};
        return @as([*]const [*:0]const u8, @ptrCast(self.strings))[0..self.count];
    }

    /// This should be called only on `StrArray`'s provided by the library
    pub fn deinit(self: *StrArray) void {
        if (internal.trace_log) log.debug("StrArray.deinit called", .{});

        if (@hasDecl(c, "git_strarray_dispose")) {
            c.git_strarray_dispose(@as(*c.git_strarray, @ptrCast(self)));
        } else {
            c.git_strarray_free(@as(*c.git_strarray, @ptrCast(self)));
        }
    }

    pub fn copy(self: StrArray) !StrArray {
        if (internal.trace_log) log.debug("StrArray.copy called", .{});

        var result: StrArray = undefined;
        try internal.wrapCall("git_strarray_copy", .{
            @as(*c.git_strarray, @ptrCast(&result)),
            @as(*const c.git_strarray, @ptrCast(&self)),
        });

        return result;
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_strarray), @sizeOf(StrArray));
        try std.testing.expectEqual(@bitSizeOf(c.git_strarray), @bitSizeOf(StrArray));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
