const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// A data buffer for exporting data from libgit2
pub const Buf = extern struct {
    ptr: ?[*]u8 = null,
    asize: usize = 0,
    size: usize = 0,

    const zero_array = [_]u8{0};
    const zero_slice = zero_array[0..0 :0];

    pub fn toSlice(self: Buf) [:0]const u8 {
        return if (self.size == 0)
            zero_slice
        else
            self.ptr.?[0..self.size :0];
    }

    /// Free the memory referred to by the `Buf`
    ///
    /// *Note*: This will not free the memory if it looks like it was not allocated by libgit2, but it will clear the buffer back
    /// to the empty state.
    pub fn deinit(self: *Buf) void {
        if (internal.trace_log) log.debug("Buf.deinit called", .{});

        c.git_buf_dispose(@ptrCast(self));
    }

    /// Resize the buffer allocation to make more space.
    ///
    /// If the buffer refers to memory that was not allocated by libgit2, then `ptr` will be replaced with a newly allocated block
    /// of data.  Be careful so that memory allocated by the caller is not lost.
    /// If you pass `target_size` = 0 and the memory is not allocated by libgit2, this will allocate a new buffer of size `size`
    /// and copy the external data into it.
    ///
    /// Currently, this will never shrink a buffer, only expand it.
    ///
    /// If the allocation fails, this will return an error and the buffer will be marked as invalid for future operations,
    /// invaliding the contents.
    pub fn grow(self: *Buf, target_size: usize) !void {
        if (internal.trace_log) log.debug("Buf.grow called", .{});

        try internal.wrapCall("git_buf_grow", .{ @as(*c.git_buf, @ptrCast(self)), target_size });
    }

    pub fn isBinary(self: *const Buf) bool {
        if (internal.trace_log) log.debug("Buf.isBinary called", .{});

        return c.git_buf_is_binary(@ptrCast(self)) == 1;
    }

    pub fn containsNull(self: Buf) bool {
        if (internal.trace_log) log.debug("Buf.containsNull called", .{});

        return std.mem.indexOfScalar(u8, self.toSlice(), 0) != null;
    }

    test {
        try std.testing.expectEqual(@sizeOf(c.git_buf), @sizeOf(Buf));
        try std.testing.expectEqual(@bitSizeOf(c.git_buf), @bitSizeOf(Buf));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
