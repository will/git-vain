const std = @import("std");
const c = @import("internal/c.zig");
const git = @import("git.zig");

pub const Transport = opaque {
    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
