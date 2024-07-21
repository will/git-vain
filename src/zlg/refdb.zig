const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Refdb = opaque {
    pub fn deinit(self: *Refdb) void {
        if (internal.trace_log) log.debug("Refdb.deinit called", .{});

        c.git_refdb_free(@as(*c.git_refdb, @ptrCast(self)));
    }

    /// Suggests that the given refdb compress or optimize its references.
    ///
    /// This mechanism is implementation specific. For on-disk reference databases, for example, this may pack all loose
    /// references.
    pub fn compress(self: *Refdb) !void {
        if (internal.trace_log) log.debug("Refdb.compress called", .{});

        try internal.wrapCall("git_refdb_compress", .{
            @as(*c.git_refdb, @ptrCast(self)),
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
