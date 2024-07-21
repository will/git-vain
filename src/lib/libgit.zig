const std = @import("std");

pub const libgit2 = @cImport({
    @cInclude("git2.h");
    @cInclude("git2/sys/repository.h");
    @cInclude("git2/sys/config.h");
});

pub fn printLastError() void {
    std.debug.print("libgit2 error: {s}\n", .{getDetailedLastError().?.message()});
}

pub const DetailedError = extern struct {
    raw_message: [*:0]const u8,
    class: c_int,

    pub fn message(self: DetailedError) [:0]const u8 {
        return std.mem.sliceTo(self.raw_message, 0);
    }
};

pub fn getDetailedLastError() ?*const DetailedError {
    return @as(?*const DetailedError, @ptrCast(libgit2.git_error_last()));
}

pub inline fn wrapCall(comptime name: []const u8, args: anytype) GitError!void {
    const result = @call(.auto, @field(libgit2, name), args);

    if (result >= 0) return;

    const err = switch (result) {
        libgit2.GIT_ERROR => GitError.GenericError,
        libgit2.GIT_ENOTFOUND => GitError.NotFound,
        libgit2.GIT_EEXISTS => GitError.Exists,
        libgit2.GIT_EAMBIGUOUS => GitError.Ambiguous,
        libgit2.GIT_EBUFS => GitError.BufferTooShort,
        libgit2.GIT_EUSER => GitError.User,
        libgit2.GIT_EBAREREPO => GitError.BareRepo,
        libgit2.GIT_EUNBORNBRANCH => GitError.UnbornBranch,
        libgit2.GIT_EUNMERGED => GitError.Unmerged,
        libgit2.GIT_ENONFASTFORWARD => GitError.NonFastForwardable,
        libgit2.GIT_EINVALIDSPEC => GitError.InvalidSpec,
        libgit2.GIT_ECONFLICT => GitError.Conflict,
        libgit2.GIT_ELOCKED => GitError.Locked,
        libgit2.GIT_EMODIFIED => GitError.Modifed,
        libgit2.GIT_EAUTH => GitError.Auth,
        libgit2.GIT_ECERTIFICATE => GitError.Certificate,
        libgit2.GIT_EAPPLIED => GitError.Applied,
        libgit2.GIT_EPEEL => GitError.Peel,
        libgit2.GIT_EEOF => GitError.EndOfFile,
        libgit2.GIT_EINVALID => GitError.Invalid,
        libgit2.GIT_EUNCOMMITTED => GitError.Uncommited,
        libgit2.GIT_EDIRECTORY => GitError.Directory,
        libgit2.GIT_EMERGECONFLICT => GitError.MergeConflict,
        libgit2.GIT_PASSTHROUGH => GitError.Passthrough,
        libgit2.GIT_ITEROVER => GitError.IterOver,
        libgit2.GIT_RETRY => GitError.Retry,
        libgit2.GIT_EMISMATCH => GitError.Mismatch,
        libgit2.GIT_EINDEXDIRTY => GitError.IndexDirty,
        libgit2.GIT_EAPPLYFAIL => GitError.ApplyFail,
        else => {
            // log.err("encountered unknown libgit2 error: {}", .{value});
            unreachable;
        },
    };

    return err;

    // std.debug.print("retval: {d}\n", .{result});
    // const err = getDetailedLastError();
    // std.debug.print("err: {s}\n", .{err.?.message()});
    // return error.nonZero;
}

pub const GitError = error{
    /// Generic error
    GenericError,
    /// Requested object could not be found
    NotFound,
    /// Object exists preventing operation
    Exists,
    /// More than one object matches
    Ambiguous,
    /// Output buffer too short to hold data
    BufferTooShort,
    /// A special error that is never generated by libgit2 code.  You can return it from a callback (e.g to stop an iteration)
    /// to know that it was generated by the callback and not by libgit2.
    User,
    /// Operation not allowed on bare repository
    BareRepo,
    /// HEAD refers to branch with no commits
    UnbornBranch,
    /// Merge in progress prevented operation
    Unmerged,
    /// Reference was not fast-forwardable
    NonFastForwardable,
    /// Name/ref spec was not in a valid format
    InvalidSpec,
    /// Checkout conflicts prevented operation
    Conflict,
    /// Lock file prevented operation
    Locked,
    /// Reference value does not match expected
    Modifed,
    /// Authentication error
    Auth,
    /// Server certificate is invalid
    Certificate,
    /// Patch/merge has already been applied
    Applied,
    /// The requested peel operation is not possible
    Peel,
    /// Unexpected EOF
    EndOfFile,
    /// Invalid operation or input
    Invalid,
    /// Uncommitted changes in index prevented operation
    Uncommited,
    /// The operation is not valid for a directory
    Directory,
    /// A merge conflict exists and cannot continue
    MergeConflict,
    /// A user-configured callback refused to act
    Passthrough,
    /// Signals end of iteration with iterator
    IterOver,
    /// Internal only
    Retry,
    /// Hashsum mismatch in object
    Mismatch,
    /// Unsaved changes in the index would be overwritten
    IndexDirty,
    /// Patch application failed
    ApplyFail,
};

// Modified from https://github.com/leecannon/zig-libgit2
//
// MIT License
//
// Copyright (c) 2021-2023 Lee Cannon
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
