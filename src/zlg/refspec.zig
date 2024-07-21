const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// A refspec specifies the mapping between remote and local reference names when fetch or pushing.
pub const Refspec = opaque {
    /// Free a refspec object which has been created by Refspec.parse.
    pub fn deinit(self: *Refspec) void {
        if (internal.trace_log) log.debug("Refspec.deinit called", .{});

        c.git_refspec_free(@as(*c.git_refspec, @ptrCast(self)));
    }

    /// Get the source specifier.
    pub fn source(self: *const Refspec) [:0]const u8 {
        if (internal.trace_log) log.debug("Refspec.source called", .{});

        return std.mem.sliceTo(
            c.git_refspec_src(@as(
                *const c.git_refspec,
                @ptrCast(self),
            )),
            0,
        );
    }

    /// Get the destination specifier.
    pub fn destination(self: *const Refspec) [:0]const u8 {
        if (internal.trace_log) log.debug("Refspec.destination called", .{});

        return std.mem.sliceTo(
            c.git_refspec_dst(@as(
                *const c.git_refspec,
                @ptrCast(self),
            )),
            0,
        );
    }

    /// Get the refspec's string.
    pub fn string(self: *const Refspec) [:0]const u8 {
        if (internal.trace_log) log.debug("Refspec.string called", .{});

        return std.mem.sliceTo(
            c.git_refspec_string(@as(
                *const c.git_refspec,
                @ptrCast(self),
            )),
            0,
        );
    }

    /// Get the force update setting.
    pub fn isForceUpdate(self: *const Refspec) bool {
        if (internal.trace_log) log.debug("Refspec.isForceUpdate called", .{});

        return c.git_refspec_force(@as(*const c.git_refspec, @ptrCast(self))) != 0;
    }

    /// Get the refspec's direction.
    pub fn direction(self: *const Refspec) git.Direction {
        if (internal.trace_log) log.debug("Refspec.direction called", .{});

        return @as(
            git.Direction,
            @enumFromInt(c.git_refspec_direction(@as(
                *const c.git_refspec,
                @ptrCast(self),
            ))),
        );
    }

    /// Check if a refspec's source descriptor matches a reference
    pub fn srcMatches(self: *const Refspec, refname: [:0]const u8) bool {
        if (internal.trace_log) log.debug("Refspec.srcMatches called", .{});

        return c.git_refspec_src_matches(
            @as(*const c.git_refspec, @ptrCast(self)),
            refname.ptr,
        ) != 0;
    }

    /// Check if a refspec's destination descriptor matches a reference
    pub fn destMatches(self: *const Refspec, refname: [:0]const u8) bool {
        if (internal.trace_log) log.debug("Refspec.destMatches called", .{});

        return c.git_refspec_dst_matches(
            @as(*const c.git_refspec, @ptrCast(self)),
            refname.ptr,
        ) != 0;
    }

    /// Transform a reference to its target following the refspec's rules
    ///
    /// # Parameters
    /// * `name` - The name of the reference to transform.
    pub fn transform(self: *const Refspec, name: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Refspec.transform called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_refspec_transform", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*const c.git_refspec, @ptrCast(self)),
            name.ptr,
        });

        return ret;
    }

    /// Transform a target reference to its source reference following the refspec's rules
    ///
    /// # Parameters
    /// * `name` - The name of the reference to transform.
    pub fn rtransform(self: *const Refspec, name: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Refspec.rtransform called", .{});

        var ret: git.Buf = .{};

        try internal.wrapCall("git_refspec_rtransform", .{
            @as(*c.git_buf, @ptrCast(&ret)),
            @as(*const c.git_refspec, @ptrCast(self)),
            name.ptr,
        });

        return ret;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
