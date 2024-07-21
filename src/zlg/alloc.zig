const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// An instance for a custom memory allocator
///
/// Setting the pointers of this structure allows the developer to implement custom memory allocators.
/// The global memory allocator can be set by using `Handle.optionSetAllocator` function.
/// Keep in mind that all fields need to be set to a proper function.
pub const GitAllocator = extern struct {
    /// Allocate `n` bytes of memory
    malloc: *const fn (n: usize, file: [*:0]const u8, line: c_int) callconv(.C) ?*anyopaque,

    /// Allocate memory for an array of `nelem` elements, where each element has a size of `elsize`.
    /// Returned memory shall be initialized to all-zeroes
    calloc: *const fn (nelem: usize, elsize: usize, file: [*:0]const u8, line: c_int) callconv(.C) ?*anyopaque,

    /// Allocate memory for the string `str` and duplicate its contents.
    strdup: *const fn (str: [*:0]const u8, file: [*:0]const u8, line: c_int) callconv(.C) [*:0]const u8,

    /// Equivalent to the `gstrdup` function, but only duplicating at most `n + 1` bytes
    strndup: *const fn (str: [*:0]const u8, n: usize, file: [*:0]const u8, line: c_int) callconv(.C) [*:0]const u8,

    /// Equivalent to `gstrndup`, but will always duplicate exactly `n` bytes of `str`. Thus, out of bounds reads at `str`
    /// may happen.
    substrdup: *const fn (str: [*:0]const u8, n: usize, file: [*:0]const u8, line: c_int) callconv(.C) [*:0]const u8,

    /// This function shall deallocate the old object `ptr` and return a pointer to a new object that has the size specified by
    /// size`. In case `ptr` is `null`, a new array shall be allocated.
    realloc: *const fn (ptr: ?*anyopaque, size: usize, file: [*:0]const u8, line: c_int) callconv(.C) ?*anyopaque,

    /// This function shall be equivalent to `grealloc`, but allocating `neleme * elsize` bytes.
    reallocarray: *const fn (ptr: ?*anyopaque, nelem: usize, elsize: usize, file: [*:0]const u8, line: c_int) callconv(.C) ?*anyopaque,

    /// This function shall allocate a new array of `nelem` elements, where each element has a size of `elsize` bytes.
    mallocarray: *const fn (nelem: usize, elsize: usize, file: [*:0]const u8, line: c_int) callconv(.C) ?*anyopaque,

    /// This function shall free the memory pointed to by `ptr`. In case `ptr` is `null`, this shall be a no-op.
    free: *const fn (ptr: ?*anyopaque) callconv(.C) void,

    test {
        // BUG: idk doesnt work
        //    try std.testing.expectEqual(@sizeOf(c.git_allocator), @sizeOf(GitAllocator));
        //   try std.testing.expectEqual(@bitSizeOf(c.git_allocator), @bitSizeOf(GitAllocator));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
