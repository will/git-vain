const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Represents an array of git message trailers.
pub const MessageTrailerArray = extern struct {
    trailers: [*]MessageTrailer,
    count: usize,

    /// private
    _trailer_block: *u8,

    pub fn getTrailers(self: MessageTrailerArray) []MessageTrailer {
        return self.trailers[0..self.count];
    }

    pub fn deinit(self: *MessageTrailerArray) void {
        if (internal.trace_log) log.debug("MessageTrailerArray.deinit called", .{});

        c.git_message_trailer_array_free(@as(*c.git_message_trailer_array, @ptrCast(self)));
    }

    /// Represents a single git message trailer.
    pub const MessageTrailer = extern struct {
        key: [*:0]const u8,
        value: [*:0]const u8,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_message_trailer), @sizeOf(MessageTrailer));
            try std.testing.expectEqual(@bitSizeOf(c.git_message_trailer), @bitSizeOf(MessageTrailer));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_message_trailer_array), @sizeOf(MessageTrailerArray));
        try std.testing.expectEqual(@bitSizeOf(c.git_message_trailer_array), @bitSizeOf(MessageTrailerArray));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
