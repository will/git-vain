const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Commit = opaque {
    pub fn deinit(self: *Commit) void {
        if (internal.trace_log) log.debug("Commit.deinit called", .{});

        c.git_commit_free(@ptrCast(self));
    }

    pub fn noteIterator(self: *Commit) !*git.NoteIterator {
        if (internal.trace_log) log.debug("Commit.noteIterator called", .{});

        var ret: *git.NoteIterator = undefined;

        try internal.wrapCall("git_note_commit_iterator_new", .{
            @as(*?*c.git_note_iterator, @ptrCast(&ret)),
            @as(*c.git_commit, @ptrCast(self)),
        });

        return ret;
    }

    pub fn id(self: *const Commit) *const git.Oid {
        if (internal.trace_log) log.debug("Commit.id called", .{});

        return @ptrCast(c.git_commit_id(@ptrCast(self)));
    }

    pub fn getOwner(self: *const Commit) *git.Repository {
        if (internal.trace_log) log.debug("Commit.getOwner called", .{});

        return @ptrCast(c.git_commit_owner(@ptrCast(self)));
    }

    pub fn getMessageEncoding(self: *const Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getMessageEncoding called", .{});

        const ret = c.git_commit_message_encoding(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }
    /// Get the full message of a commit.
    ///
    /// The returned message will be slightly prettified by removing any potential leading newlines.
    pub fn getMessage(self: *const Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getMessage called", .{});

        const ret = c.git_commit_message(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }

    /// Get the full raw message of a commit.
    pub fn getMessageRaw(self: *const Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getMessageRaw called", .{});

        const ret = c.git_commit_message_raw(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }

    /// Get the full raw text of the commit header.
    pub fn getHeaderRaw(self: *const Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getHeaderRaw called", .{});

        const ret = c.git_commit_raw_header(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }

    /// Get the short "summary" of the git commit message.
    ///
    /// The returned message is the summary of the commit, comprising the first paragraph of the message with whitespace trimmed
    /// and squashed.
    pub fn getSummary(self: *Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getSummary called", .{});

        const ret = c.git_commit_summary(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }

    /// Get the long "body" of the git commit message.
    ///
    /// The returned message is the body of the commit, comprising everything but the first paragraph of the message. Leading and
    /// trailing whitespaces are trimmed.
    pub fn getBody(self: *Commit) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Commit.getBody called", .{});

        const ret = c.git_commit_body(@ptrCast(self));

        return if (ret) |c_str| std.mem.sliceTo(c_str, 0) else null;
    }

    /// Get the commit time (i.e. committer time) of a commit.
    pub fn getTime(self: *const Commit) i64 {
        if (internal.trace_log) log.debug("Commit.getTime called", .{});

        return c.git_commit_time(@ptrCast(self));
    }

    /// Get the commit timezone offset (i.e. committer's preferred timezone) of a commit.
    pub fn getTimeOffset(self: *const Commit) i32 {
        if (internal.trace_log) log.debug("Commit.getTimeOffset called", .{});

        return c.git_commit_time_offset(@ptrCast(self));
    }

    pub fn getCommitter(self: *const Commit) *const git.Signature {
        if (internal.trace_log) log.debug("Commit.getCommitter called", .{});

        return @as(
            *const git.Signature,
            @ptrCast(c.git_commit_committer(@ptrCast(self))),
        );
    }

    pub fn getAuthor(self: *const Commit) *const git.Signature {
        if (internal.trace_log) log.debug("Commit.getAuthor called", .{});

        return @as(
            *const git.Signature,
            @ptrCast(c.git_commit_author(@ptrCast(self))),
        );
    }

    pub fn committerWithMailmap(self: *const Commit, mail_map: ?*const git.Mailmap) !*git.Signature {
        if (internal.trace_log) log.debug("Commit.committerWithMailmap", .{});

        var signature: *git.Signature = undefined;

        try internal.wrapCall("git_commit_committer_with_mailmap", .{
            @as(*?*c.git_signature, @ptrCast(&signature)),
            @as(*const c.git_commit, @ptrCast(self)),
            @as(?*const c.git_mailmap, @ptrCast(mail_map)),
        });

        return signature;
    }

    pub fn authorWithMailmap(self: *const Commit, mail_map: ?*const git.Mailmap) !*git.Signature {
        if (internal.trace_log) log.debug("Commit.authorWithMailmap called", .{});

        var signature: *git.Signature = undefined;

        try internal.wrapCall("git_commit_author_with_mailmap", .{
            @as(*?*c.git_signature, @ptrCast(&signature)),
            @as(*const c.git_commit, @ptrCast(self)),
            @as(?*const c.git_mailmap, @ptrCast(mail_map)),
        });

        return signature;
    }

    pub fn getTree(self: *const Commit) !*git.Tree {
        if (internal.trace_log) log.debug("Commit.getTree called", .{});

        var tree: *git.Tree = undefined;

        try internal.wrapCall("git_commit_tree", .{
            @as(*?*c.git_tree, @ptrCast(&tree)),
            @as(*const c.git_commit, @ptrCast(self)),
        });

        return tree;
    }

    pub fn getTreeId(self: *const Commit) !*const git.Oid {
        if (internal.trace_log) log.debug("Commit.getTreeId called", .{});

        return @ptrCast(c.git_commit_tree_id(@ptrCast(self)));
    }

    pub fn getParentCount(self: *const Commit) u32 {
        if (internal.trace_log) log.debug("Commit.getParentCount called", .{});

        return c.git_commit_parentcount(@ptrCast(self));
    }

    pub fn getParent(self: *const Commit, parent_number: u32) !*Commit {
        if (internal.trace_log) log.debug("Commit.getParent called", .{});

        var commit: *Commit = undefined;

        try internal.wrapCall("git_commit_parent", .{
            @as(*?*c.git_commit, @ptrCast(&commit)),
            @as(*const c.git_commit, @ptrCast(self)),
            parent_number,
        });

        return commit;
    }

    pub fn getParentId(self: *const Commit, parent_number: u32) ?*const git.Oid {
        if (internal.trace_log) log.debug("Commit.getParentId called", .{});

        return @ptrCast(c.git_commit_parent_id(
            @ptrCast(self),
            parent_number,
        ));
    }

    pub fn getAncestor(self: *const Commit, ancestor_number: u32) !*Commit {
        if (internal.trace_log) log.debug("Commit.getAncestor called", .{});

        var commit: *Commit = undefined;

        try internal.wrapCall("git_commit_nth_gen_ancestor", .{
            @as(*?*c.git_commit, @ptrCast(&commit)),
            @as(*const c.git_commit, @ptrCast(self)),
            ancestor_number,
        });

        return commit;
    }

    pub fn getHeaderField(self: *const Commit, field: [:0]const u8) !git.Buf {
        if (internal.trace_log) log.debug("Commit.getHeaderField called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_commit_header_field", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*const c.git_commit, @ptrCast(self)),
            field.ptr,
        });

        return buf;
    }

    pub fn amend(
        self: *const Commit,
        update_ref: ?[:0]const u8,
        author: ?*const git.Signature,
        committer: ?*const git.Signature,
        message_encoding: ?[:0]const u8,
        message: ?[:0]const u8,
        tree: ?*const git.Tree,
    ) !git.Oid {
        if (internal.trace_log) log.debug("Commit.amend called", .{});

        var ret: git.Oid = undefined;

        const update_ref_temp = if (update_ref) |slice| slice.ptr else null;
        const encoding_temp = if (message_encoding) |slice| slice.ptr else null;
        const message_temp = if (message) |slice| slice.ptr else null;

        try internal.wrapCall("git_commit_amend", .{
            @as(*c.git_oid, @ptrCast(&ret)),
            @as(*const c.git_commit, @ptrCast(self)),
            update_ref_temp,
            @as(?*const c.git_signature, @ptrCast(author)),
            @as(?*const c.git_signature, @ptrCast(committer)),
            encoding_temp,
            message_temp,
            @as(?*const c.git_tree, @ptrCast(tree)),
        });

        return ret;
    }

    pub fn duplicate(self: *Commit) !*Commit {
        if (internal.trace_log) log.debug("Commit.duplicate called", .{});

        var commit: *Commit = undefined;

        try internal.wrapCall("git_commit_dup", .{
            @as(*?*c.git_commit, @ptrCast(&commit)),
            @as(*c.git_commit, @ptrCast(self)),
        });

        return commit;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Options for revert
pub const RevertOptions = struct {
    /// For merge commits, the "mainline" is treated as the parent.
    mainline: bool = false,
    /// Options for the merging
    merge_options: git.MergeOptions = .{},
    /// Options for the checkout
    checkout_options: git.CheckoutOptions = .{},

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
