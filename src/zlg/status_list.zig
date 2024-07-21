const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const StatusList = opaque {
    pub fn deinit(self: *StatusList) void {
        if (internal.trace_log) log.debug("StatusList.deinit called", .{});

        c.git_status_list_free(@as(*c.git_status_list, @ptrCast(self)));
    }

    pub fn entryCount(self: *StatusList) usize {
        if (internal.trace_log) log.debug("StatusList.entryCount called", .{});

        return c.git_status_list_entrycount(@as(*c.git_status_list, @ptrCast(self)));
    }

    pub fn statusByIndex(self: *StatusList, index: usize) ?*const StatusEntry {
        if (internal.trace_log) log.debug("StatusList.statusByIndex called", .{});

        return @as(
            ?*const StatusEntry,
            @ptrCast(c.git_status_byindex(@as(*c.git_status_list, @ptrCast(self)), index)),
        );
    }

    /// Get performance data for diffs from a StatusList
    pub fn getPerfData(self: *const StatusList) !git.DiffPerfData {
        if (internal.trace_log) log.debug("StatusList.getPerfData called", .{});

        var c_ret = c.git_diff_perfdata{
            .version = c.GIT_DIFF_PERFDATA_VERSION,
            .stat_calls = 0,
            .oid_calculations = 0,
        };

        try internal.wrapCall("git_status_list_get_perfdata", .{
            &c_ret,
            @as(*const c.git_status_list, @ptrCast(self)),
        });

        return git.DiffPerfData{
            .stat_calls = c_ret.stat_calls,
            .oid_calculations = c_ret.oid_calculations,
        };
    }

    /// A status entry, providing the differences between the file as it exists in HEAD and the index, and providing the
    /// differences between the index and the working directory.
    pub const StatusEntry = extern struct {
        /// The status for this file
        status: git.FileStatus,

        /// information about the differences between the file in HEAD and the file in the index.
        head_to_index: *git.DiffDelta,

        /// information about the differences between the file in the index and the file in the working directory.
        index_to_workdir: *git.DiffDelta,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_status_entry), @sizeOf(StatusEntry));
            try std.testing.expectEqual(@bitSizeOf(c.git_status_entry), @bitSizeOf(StatusEntry));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
