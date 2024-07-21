const std = @import("std");
const c = @import("internal/c.zig");
const git = @import("git.zig");

/// Direction of the connection.
///
/// We need this because we need to know whether we should call git-upload-pack or git-receive-pack on the remote
/// end when get_refs gets called.
pub const Direction = enum(c_uint) {
    fetch = 0,
    push = 1,
};

comptime {
    std.testing.refAllDecls(@This());
}
