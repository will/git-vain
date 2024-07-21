const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Note = opaque {
    pub fn deinit(self: *Note) void {
        if (internal.trace_log) log.debug("Note.deinit called", .{});

        c.git_note_free(@as(*c.git_note, @ptrCast(self)));
    }

    /// Get the note author
    pub fn author(self: *const Note) *const git.Signature {
        if (internal.trace_log) log.debug("Note.author called", .{});

        return @as(
            *const git.Signature,
            @ptrCast(c.git_note_author(@as(*const c.git_note, @ptrCast(self)))),
        );
    }

    /// Get the note committer
    pub fn committer(self: *const Note) *const git.Signature {
        if (internal.trace_log) log.debug("Note.committer called", .{});

        return @as(
            *const git.Signature,
            @ptrCast(c.git_note_committer(@as(*const c.git_note, @ptrCast(self)))),
        );
    }

    /// Get the note message
    pub fn message(self: *const Note) [:0]const u8 {
        if (internal.trace_log) log.debug("Note.message called", .{});

        return std.mem.sliceTo(
            c.git_note_message(@as(*const c.git_note, @ptrCast(self))),
            0,
        );
    }

    /// Get the note id
    pub fn id(self: *const Note) *const git.Oid {
        if (internal.trace_log) log.debug("Note.id called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_note_id(@as(*const c.git_note, @ptrCast(self)))),
        );
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const NoteIterator = opaque {
    /// Return the current item and advance the iterator internally to the next value
    pub fn next(self: *NoteIterator) !?NextItem {
        if (internal.trace_log) log.debug("NoteIterator.next called", .{});

        var ret: NextItem = undefined;

        internal.wrapCall("git_note_next", .{
            @as(*c.git_oid, @ptrCast(&ret.note_id)),
            @as(*c.git_oid, @ptrCast(&ret.annotated_id)),
            @as(*c.git_note_iterator, @ptrCast(self)),
        }) catch |err| switch (err) {
            git.GitError.IterOver => return null,
            else => |e| return e,
        };

        return ret;
    }

    pub fn deinit(self: *NoteIterator) void {
        if (internal.trace_log) log.debug("NoteIterator.deinit called", .{});

        c.git_note_iterator_free(@as(*c.git_note_iterator, @ptrCast(self)));
    }

    pub const NextItem = struct {
        note_id: git.Oid,
        annotated_id: git.Oid,
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
