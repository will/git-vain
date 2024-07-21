const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Indexer = opaque {
    /// Add data to the indexer
    ///
    /// ## Parameters
    /// * `data` - The data to add
    /// * `stats` - Stat storage
    pub fn append(self: *Indexer, data: []const u8, stats: *IndexerProgress) !void {
        if (internal.trace_log) log.debug("Indexer.append called", .{});

        try internal.wrapCall("git_indexer_append", .{
            @as(*c.git_indexer, @ptrCast(self)),
            data.ptr,
            data.len,
            @as(*c.git_indexer_progress, @ptrCast(stats)),
        });
    }

    /// Finalize the pack and index
    ///
    /// Resolve any pending deltas and write out the index file
    ///
    /// ## Parameters
    /// * `data` - The data to add
    /// * `stats` - Stat storage
    pub fn commit(self: *Indexer, stats: *IndexerProgress) !void {
        if (internal.trace_log) log.debug("Indexer.commit called", .{});

        try internal.wrapCall("git_indexer_commit", .{
            @as(*c.git_indexer, @ptrCast(self)),
            @as(*c.git_indexer_progress, @ptrCast(stats)),
        });
    }

    /// Get the packfile's hash
    ///
    /// A packfile's name is derived from the sorted hashing of all object names. This is only correct after the index has been
    /// finalized.
    pub fn hash(self: *const Indexer) ?*const git.Oid {
        if (internal.trace_log) log.debug("Indexer.hash called", .{});

        return @as(
            ?*const git.Oid,
            @ptrCast(c.git_indexer_hash(@as(*const c.git_indexer, @ptrCast(self)))),
        );
    }

    pub fn deinit(self: *Indexer) void {
        if (internal.trace_log) log.debug("Indexer.deinit called", .{});

        c.git_indexer_free(@as(*c.git_indexer, @ptrCast(self)));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// This structure is used to provide callers information about the progress of indexing a packfile, either directly or part
/// of a fetch or clone that downloads a packfile.
pub const IndexerProgress = extern struct {
    /// number of objects in the packfile being indexed
    total_objects: c_int,

    /// received objects that have been hashed
    indexed_objects: c_int,

    /// received_objects: objects which have been downloaded
    received_objects: c_int,

    /// locally-available objects that have been injected in order to fix a thin pack
    local_objects: c_int,

    /// number of deltas in the packfile being indexed
    total_deltas: c_int,

    /// received deltas that have been indexed
    indexed_deltas: c_int,

    /// size of the packfile received up to now
    received_bytes: usize,

    test {
        try std.testing.expectEqual(@sizeOf(c.git_indexer_progress), @sizeOf(IndexerProgress));
        try std.testing.expectEqual(@bitSizeOf(c.git_indexer_progress), @bitSizeOf(IndexerProgress));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const IndexerOptions = struct {
    /// permissions to use creating packfile or 0 for defaults
    mode: c_uint = 0,

    /// do connectivity checks for the received pack
    verify: bool = false,
};

comptime {
    std.testing.refAllDecls(@This());
}
