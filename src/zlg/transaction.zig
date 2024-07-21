const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Transaction = opaque {
    /// Free the resources allocated by this transaction
    ///
    /// If any references remain locked, they will be unlocked without any changes made to them.
    pub fn deinit(self: *Transaction) !void {
        if (internal.trace_log) log.debug("Transaction.deinit called", .{});

        c.git_transaction_free(@as(*c.git_transaction, @ptrCast(self)));
    }

    /// Lock a reference
    ///
    /// Lock the specified reference. This is the first step to updating a reference
    ///
    /// ## Parameters
    /// * `refname` - The reference to lock
    pub fn lockReference(self: *Transaction, refname: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Transaction.lockReference called", .{});

        try internal.wrapCall("git_transaction_lock_ref", .{
            @as(*c.git_transaction, @ptrCast(self)),
            refname.ptr,
        });
    }

    /// Set the target of a reference
    ///
    /// Set the target of the specified reference. This reference must be locked.
    ///
    /// ## Parameters
    /// * `refname` - The reference to lock
    /// * `target` - Target to set the reference to
    /// * `signature` - Signature to use in the reflog; pass `null` to read the identity from the config
    /// * `message` - Message to use in the reflog
    pub fn setTarget(
        self: *Transaction,
        refname: [:0]const u8,
        target: *const git.Oid,
        signature: ?*const git.Signature,
        message: [:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Transaction.setTarget called", .{});

        try internal.wrapCall("git_transaction_set_target", .{
            @as(*c.git_transaction, @ptrCast(self)),
            refname.ptr,
            @as(*const c.git_oid, @ptrCast(target)),
            @as(?*const c.git_signature, @ptrCast(signature)),
            message.ptr,
        });
    }

    /// Set the target of a reference
    ///
    /// Set the target of the specified reference. This reference must be locked.
    ///
    /// ## Parameters
    /// * `refname` - The reference to lock
    /// * `target` - Target to set the reference to
    /// * `signature` - Signature to use in the reflog; pass `null` to read the identity from the config
    /// * `message` - Message to use in the reflog
    pub fn setSymbolicTarget(
        self: *Transaction,
        refname: [:0]const u8,
        target: [:0]const u8,
        signature: ?*const git.Signature,
        message: [:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Transaction.setSymbolicTarget called", .{});

        try internal.wrapCall("git_transaction_set_symbolic_target", .{
            @as(*c.git_transaction, @ptrCast(self)),
            refname.ptr,
            target.ptr,
            @as(?*const c.git_signature, @ptrCast(signature)),
            message.ptr,
        });
    }

    /// Set the reflog of a reference
    ///
    /// Set the specified reference's reflog. If this is combined with setting the target, that update won't be written to the
    /// reflog.
    ///
    /// ## Parameters
    /// * `refname` - The reference to lock
    /// * `reflog` - The reflog as it should be written out
    pub fn setReflog(self: *Transaction, refname: [:0]const u8, reflog: *const git.Reflog) !void {
        if (internal.trace_log) log.debug("Transaction.setReflog called", .{});

        try internal.wrapCall("git_transaction_set_reflog", .{
            @as(*c.git_transaction, @ptrCast(self)),
            refname.ptr,
            @as(?*const c.git_reflog, @ptrCast(reflog)),
        });
    }

    /// Remove a reference
    ///
    /// ## Parameters
    /// * `refname` - The reference to remove
    pub fn remove(self: *Transaction, refname: [:0]const u8) !void {
        if (internal.trace_log) log.debug("Transaction.remove called", .{});

        try internal.wrapCall("git_transaction_remove", .{
            @as(*c.git_transaction, @ptrCast(self)),
            refname.ptr,
        });
    }

    /// Commit the changes from the transaction
    ///
    /// Perform the changes that have been queued. The updates will be made one by one, and the first failure will stop the
    /// processing.
    pub fn commit(self: *Transaction) !void {
        if (internal.trace_log) log.debug("Transaction.commit called", .{});

        try internal.wrapCall("git_transaction_commit", .{
            @as(*c.git_transaction, @ptrCast(self)),
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
