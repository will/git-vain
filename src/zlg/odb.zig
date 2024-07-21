const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Odb = opaque {
    pub fn deinit(self: *Odb) void {
        if (internal.trace_log) log.debug("Odb.deinit called", .{});

        c.git_odb_free(@as(*c.git_odb, @ptrCast(self)));
    }

    pub fn repositoryOpen(self: *Odb) !*git.Repository {
        if (internal.trace_log) log.debug("Odb.repositoryOpen called", .{});

        var repo: *git.Repository = undefined;

        try internal.wrapCall("git_repository_wrap_odb", .{
            @as(*?*c.git_repository, @ptrCast(&repo)),
            @as(*c.git_odb, @ptrCast(self)),
        });

        return repo;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
