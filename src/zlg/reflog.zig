const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Representation of a reference log
pub const Reflog = opaque {
    /// Free the reflog
    pub fn deinit(self: *Reflog) void {
        if (internal.trace_log) log.debug("Reflog.deinit called", .{});

        c.git_reflog_free(@as(*c.git_reflog, @ptrCast(self)));
    }

    /// Write an existing in-memory reflog object back to disk using an atomic file lock.
    pub fn write(self: *Reflog) !void {
        if (internal.trace_log) log.debug("Reflog.write called", .{});

        try internal.wrapCall("git_reflog_write", .{
            @as(*c.git_reflog, @ptrCast(self)),
        });
    }

    /// Add a new entry to the in-memory reflog.
    ///
    /// ## Parameters
    /// * `id` - The OID the reference is now pointing to
    /// * `signature` - The signature of the committer
    /// * `msg` - The reflog message, optional
    pub fn append(
        self: *Reflog,
        id: *const git.Oid,
        signature: *const git.Signature,
        msg: ?[:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Reflog.append called", .{});

        const c_msg = if (msg) |s| s.ptr else null;

        try internal.wrapCall("git_reflog_append", .{
            @as(*c.git_reflog, @ptrCast(self)),
            @as(*const c.git_oid, @ptrCast(id)),
            @as(*const c.git_signature, @ptrCast(signature)),
            c_msg,
        });
    }

    /// Get the number of log entries in a reflog
    pub fn entryCount(self: *Reflog) usize {
        if (internal.trace_log) log.debug("Reflog.entryCount called", .{});

        return c.git_reflog_entrycount(
            @as(*c.git_reflog, @ptrCast(self)),
        );
    }

    /// Lookup an entry by its index
    ///
    /// Requesting the reflog entry with an index of 0 (zero) will return the most recently created entry.
    ///
    /// ## Parameters
    /// * `index` - The position of the entry to lookup. Should be less than `Reflog.entryCount()`
    pub fn getEntry(self: *const Reflog, index: usize) ?*const ReflogEntry {
        if (internal.trace_log) log.debug("Reflog.getEntry called", .{});

        return @as(
            ?*const ReflogEntry,
            @ptrCast(c.git_reflog_entry_byindex(
                @as(*const c.git_reflog, @ptrCast(self)),
                index,
            )),
        );
    }

    /// Remove an entry from the reflog by its index
    ///
    /// To ensure there's no gap in the log history, set `rewrite_previous_entry` param value to `true`.
    /// When deleting entry `n`, member old_oid of entry `n-1` (if any) will be updated with the value of member new_oid of entry
    /// `n+1`.
    ///
    /// ## Parameters
    /// * `index` - The position of the entry to lookup. Should be less than `Reflog.entryCount()`
    /// * `rewrite_previous_entry` - `true` to rewrite the history; `false` otherwise
    pub fn removeEntry(self: *Reflog, index: usize, rewrite_previous_entry: bool) !void {
        if (internal.trace_log) log.debug("Reflog.removeEntry called", .{});

        try internal.wrapCall("git_reflog_drop", .{
            @as(*c.git_reflog, @ptrCast(self)),
            index,
            @intFromBool(rewrite_previous_entry),
        });
    }

    /// Representation of a reference log entry
    pub const ReflogEntry = opaque {
        /// Get the old oid
        pub fn oldId(self: *const ReflogEntry) *const git.Oid {
            if (internal.trace_log) log.debug("ReflogEntry.oldId called", .{});

            return @as(*const git.Oid, @ptrCast(c.git_reflog_entry_id_old(
                @as(*const c.git_reflog_entry, @ptrCast(self)),
            )));
        }

        /// Get the new oid
        pub fn newId(self: *const ReflogEntry) *const git.Oid {
            if (internal.trace_log) log.debug("ReflogEntry.newId called", .{});

            return @as(*const git.Oid, @ptrCast(c.git_reflog_entry_id_new(
                @as(*const c.git_reflog_entry, @ptrCast(self)),
            )));
        }

        /// Get the committer of this entry
        pub fn commiter(self: *const ReflogEntry) *const git.Signature {
            if (internal.trace_log) log.debug("ReflogEntry.commiter called", .{});

            return @as(*const git.Signature, @ptrCast(c.git_reflog_entry_committer(
                @as(*const c.git_reflog_entry, @ptrCast(self)),
            )));
        }

        /// Get the log message
        pub fn message(self: *const ReflogEntry) ?[:0]const u8 {
            if (internal.trace_log) log.debug("ReflogEntry.message called", .{});

            const opt_ret = @as(?[*:0]const u8, @ptrCast(c.git_reflog_entry_message(
                @as(*const c.git_reflog_entry, @ptrCast(self)),
            )));

            return if (opt_ret) |ret| std.mem.sliceTo(ret, 0) else null;
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
