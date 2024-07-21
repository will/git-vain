const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Rebase = opaque {
    pub fn deinit(self: *Rebase) void {
        if (internal.trace_log) log.debug("Rebase.deinit called", .{});

        c.git_rebase_free(@as(*c.git_rebase, @ptrCast(self)));
    }

    /// Gets the original `HEAD` ref name for merge rebases.
    pub fn originalHeadName(self: *Rebase) [:0]const u8 {
        if (internal.trace_log) log.debug("Rebase.originalHeadName called", .{});

        return std.mem.sliceTo(c.git_rebase_orig_head_name(@as(*c.git_rebase, @ptrCast(self))), 0);
    }

    /// Gets the original `HEAD` id for merge rebases.
    pub fn originalHeadId(self: *Rebase) *const git.Oid {
        if (internal.trace_log) log.debug("Rebase.originalHeadId called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_rebase_orig_head_id(@as(*c.git_rebase, @ptrCast(self)))),
        );
    }

    /// Gets the `onto` ref name for merge rebases.
    pub fn originalOntoName(self: *Rebase) [:0]const u8 {
        if (internal.trace_log) log.debug("Rebase.originalOntoName called", .{});

        return std.mem.sliceTo(c.git_rebase_onto_name(@as(*c.git_rebase, @ptrCast(self))), 0);
    }

    /// Gets the `onto` id for merge rebases.
    pub fn originalOntoId(self: *Rebase) *const git.Oid {
        if (internal.trace_log) log.debug("Rebase.originalOntoId called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_rebase_onto_id(@as(*c.git_rebase, @ptrCast(self)))),
        );
    }

    /// Gets the count of rebase operations that are to be applied.
    pub fn operationEntryCount(self: *Rebase) usize {
        if (internal.trace_log) log.debug("Rebase.operationEntryCount called", .{});

        return c.git_rebase_operation_entrycount(@as(*c.git_rebase, @ptrCast(self)));
    }

    /// Gets the index of the rebase operation that is currently being applied. If the first operation has not yet been applied
    /// (because you have called `init` but not yet `next`) then this returns `null`.
    pub fn currentOperation(self: *Rebase) ?usize {
        if (internal.trace_log) log.debug("Rebase.currentOperation called", .{});

        const ret = c.git_rebase_operation_current(@as(*c.git_rebase, @ptrCast(self)));

        if (ret == c.GIT_REBASE_NO_OPERATION) return null;

        return ret;
    }

    /// Gets the rebase operation specified by the given index.
    ///
    /// ## Parameters
    /// * `index` - The index of the rebase operation to retrieve.
    pub fn getOperation(self: *Rebase, index: usize) ?*RebaseOperation {
        if (internal.trace_log) log.debug("Rebase.getOperation called", .{});

        return @as(
            ?*RebaseOperation,
            @ptrCast(c.git_rebase_operation_byindex(
                @as(*c.git_rebase, @ptrCast(self)),
                index,
            )),
        );
    }

    /// Performs the next rebase operation and returns the information about it. If the operation is one that applies a patch
    /// (which is any operation except `OperationType.exec`) then the patch will be applied and the index and working directory
    /// will be updated with the changes. If there are conflicts, you will need to address those before committing the changes.
    pub fn next(self: *Rebase) !*RebaseOperation {
        if (internal.trace_log) log.debug("Rebase.next called", .{});

        var ret: *RebaseOperation = undefined;

        try internal.wrapCall("git_rebase_next", .{
            @as(*?*c.git_rebase_operation, @ptrCast(&ret)),
            @as(*c.git_rebase, @ptrCast(self)),
        });

        return ret;
    }

    /// Gets the index produced by the last operation, which is the result of `Rebase.next` and which will be committed by the
    /// next invocation of `Rebase.commit`. This is useful for resolving conflicts in an in-memory rebase before committing them.
    /// You must call `Index.deinit` when you are finished with this.
    ///
    /// This is only applicable for in-memory rebases; for rebases within a working directory, the changes were applied to the
    /// repository's index.
    pub fn inMemoryIndex(self: *Rebase) !*git.Index {
        if (internal.trace_log) log.debug("Rebase.inMemoryIndex called", .{});

        var ret: *git.Index = undefined;

        try internal.wrapCall("git_rebase_inmemory_index", .{
            @as(*?*c.git_index, @ptrCast(&ret)),
            @as(*c.git_rebase, @ptrCast(self)),
        });

        return ret;
    }

    /// Commits the current patch. You must have resolved any conflicts that were introduced during the patch application from the
    /// `Rebase.next` invocation.
    ///
    /// ## Parameters
    /// * `author` - The author of the updated commit, or `null` to keep the author from the original commit.
    /// * `committer` - The committer of the rebase.
    /// * `message_encoding` - The encoding for the message in the commit, represented with a standard encoding name. If message
    ///                        is `null`, this should also be `null`, and the encoding from the original commit will be maintained.
    ///                        If message is specified, this may be `null` to indicate that "UTF-8" is to be used.
    /// * `message` - he message for this commit, or NULL to use the message from the original commit.
    pub fn commit(
        self: *Rebase,
        author: ?*const git.Signature,
        committer: *const git.Signature,
        message_encoding: ?[:0]const u8,
        message: ?[:0]const u8,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Rebase.commit called", .{});

        var ret: git.Oid = undefined;

        const c_message_encoding = if (message_encoding) |s| s.ptr else null;
        const c_message = if (message) |s| s.ptr else null;

        try internal.wrapCall("git_rebase_commit", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*c.git_rebase, @ptrCast(self)),
            @as(?*const c.git_signature, @ptrCast(author)),
            @as(*const c.git_signature, @ptrCast(committer)),
            c_message_encoding,
            c_message,
        });

        return ret;
    }

    /// Aborts a rebase that is currently in progress, resetting the repository and working directory to their state before rebase
    /// began.
    pub fn abort(self: *Rebase) !void {
        if (internal.trace_log) log.debug("Rebase.abort called", .{});

        try internal.wrapCall("git_rebase_abort", .{
            @as(*c.git_rebase, @ptrCast(self)),
        });
    }

    /// Finishes a rebase that is currently in progress once all patches have been applied.
    pub fn finish(self: *Rebase, signature: ?*const git.Signature) !void {
        if (internal.trace_log) log.debug("Rebase.finish called", .{});

        try internal.wrapCall("git_rebase_finish", .{
            @as(*c.git_rebase, @ptrCast(self)),
            @as(?*const c.git_signature, @ptrCast(signature)),
        });
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// A rebase operation
///
/// Describes a single instruction/operation to be performed during the rebase.
pub const RebaseOperation = extern struct {
    /// The type of rebase operation.
    operation_type: OperationType,

    /// The commit ID being cherry-picked.  This will be populated for all operations except those of type `OperationType.exec`.
    id: git.Oid,

    /// The executable the user has requested be run. This will only be populated for operations of type `OperationType.exec`.
    exec: [*:0]const u8,

    /// Type of rebase operation in-progress after calling `Rebase.next`.
    pub const OperationType = enum(c_uint) {
        /// The given commit is to be cherry-picked. The client should commit the changes and continue if there are no conflicts.
        pick = 0,

        /// The given commit is to be cherry-picked, but the client should prompt the user to provide an updated commit message.
        reword,

        /// The given commit is to be cherry-picked, but the client should stop to allow the user to edit the changes before
        /// committing them.
        edit,

        /// The given commit is to be squashed into the previous commit. The commit message will be merged with the previous
        /// message.
        squash,

        /// The given commit is to be squashed into the previous commit. The commit message from this commit will be discarded.
        fixup,

        /// No commit will be cherry-picked. The client should run the given command and (if successful) continue.
        exec,
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_rebase_operation), @sizeOf(RebaseOperation));
        try std.testing.expectEqual(@bitSizeOf(c.git_rebase_operation), @bitSizeOf(RebaseOperation));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Use to tell the rebase machinery how to operate.
pub const RebaseOptions = struct {
    /// Used by `Repository.rebaseInit`, this will instruct other clients working on this rebase that you want a quiet rebase
    /// experience, which they may choose to provide in an application-specific manner. This has no effect upon libgit2 directly,
    /// but is provided for interoperability between Git tools.
    quiet: bool = false,

    /// Used by `Repository.rebaseInit`, this will begin an in-memory rebase, which will allow callers to step through the rebase
    /// operations andcommit the rebased changes, but will not rewind HEAD or update the repository to be in a rebasing state.
    /// This will not interfere with the working directory (if there is one).
    in_memory: bool = false,

    /// Used by `Rebase.finish`, this is the name of the notes reference used to rewrite notes for rebased commits when finishing
    /// the rebase; if `null`, the contents of the configuration option `notes.rewriteRef` is examined, unless the configuration
    /// option `notes.rewrite.rebase` is set to false. If `notes.rewriteRef` is also `null`, notes will not be rewritten.
    rewrite_notes_ref: ?[:0]const u8 = null,

    /// Options to control how trees are merged during `Rebase.next`.
    merge_options: git.MergeOptions = .{},

    /// Options to control how files are written during `Repository.rebaseInit`, `Rebase.next` and `Rebase.abort`. Note that a
    /// minimum strategy of `safe` is defaulted in `init` and `next`, and a minimum strategy of `force` is defaulted in `abort` to
    /// match git semantics.
    checkout_options: git.CheckoutOptions = .{},

    /// If provided, this will be called with the commit content, allowing a signature to be added to the rebase commit. Can be
    /// skipped with GitError.Passthrough. If `errorToCInt(GitError.Passthrough)` is returned, a commit will be made without a
    /// signature. This field is only used when performing `Rebase.commit`.
    ///
    /// The callback will be called with the commit content, giving a user an opportunity to sign the commit content.
    /// The signature_field buf may be left empty to specify the default field "gpgsig".
    ///
    /// Signatures can take the form of any string, and can be created on an arbitrary header field. Signatures are most commonly
    /// used for verifying authorship of a commit using GPG or a similar cryptographically secure signing algorithm.
    /// See https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work for more details.
    ///
    /// When the callback:
    /// - returns `errorToCInt(GitError.Passthrough)`, no signature will be added to the commit.
    /// - returns < 0, commit creation will be aborted.
    /// - returns 0, the signature parameter is expected to be filled.
    signing_cb: ?*const fn (
        signature: *git.Buf,
        signature_field: *git.Buf,
        commit_content: [*:0]const u8,
        payload: ?*anyopaque,
    ) callconv(.C) c_int = null,

    /// This will be passed to each of the callbacks in this struct as the last parameter.
    payload: ?*anyopaque = null,

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
