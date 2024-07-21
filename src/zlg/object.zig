const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Object = opaque {
    /// Close an open object
    ///
    /// This method instructs the library to close an existing object; note that `git.Object`s are owned and cached by
    /// the repository so the object may or may not be freed after this library call, depending on how aggressive is the
    /// caching mechanism used by the repository.
    ///
    /// IMPORTANT:
    /// It *is* necessary to call this method when you stop using an object. Failure to do so will cause a memory leak.
    pub fn deinit(self: *Object) void {
        if (internal.trace_log) log.debug("Object.deinit called", .{});

        c.git_object_free(@as(*c.git_object, @ptrCast(self)));
    }

    /// Get the id (SHA1) of a repository object
    pub fn id(self: *const Object) *const git.Oid {
        if (internal.trace_log) log.debug("Object.id called", .{});

        return @as(
            *const git.Oid,
            @ptrCast(c.git_object_id(@as(*const c.git_object, @ptrCast(self)))),
        );
    }

    /// Get a short abbreviated OID string for the object
    ///
    /// This starts at the "core.abbrev" length (default 7 characters) and iteratively extends to a longer string if that length
    /// is ambiguous.
    /// The result will be unambiguous (at least until new objects are added to the repository).
    pub fn shortId(self: *const Object) !git.Buf {
        if (internal.trace_log) log.debug("Object.shortId called", .{});

        var buf: git.Buf = .{};

        try internal.wrapCall("git_object_short_id", .{
            @as(*c.git_buf, @ptrCast(&buf)),
            @as(*const c.git_object, @ptrCast(self)),
        });

        return buf;
    }

    /// Get the object type of an object
    pub fn objectType(self: *const Object) ObjectType {
        if (internal.trace_log) log.debug("Object.objectType called", .{});

        return @as(
            ObjectType,
            @enumFromInt(c.git_object_type(@as(*const c.git_object, @ptrCast(self)))),
        );
    }

    /// Get the repository that owns this object
    pub fn objectOwner(self: *const Object) *const git.Repository {
        if (internal.trace_log) log.debug("Object.objectOwner called", .{});

        return @as(
            *const git.Repository,
            @ptrCast(c.git_object_owner(@as(*const c.git_object, @ptrCast(self)))),
        );
    }

    /// Describe a commit
    ///
    /// Perform the describe operation on the given committish object.
    pub fn describe(self: *Object, options: git.DescribeOptions) !*git.DescribeResult {
        if (internal.trace_log) log.debug("Object.describe called", .{});

        var result: *git.DescribeResult = undefined;

        var c_options = internal.make_c_option.describeOptions(options);

        try internal.wrapCall("git_describe_commit", .{
            @as(*?*c.git_describe_result, @ptrCast(&result)),
            @as(*c.git_object, @ptrCast(self)),
            &c_options,
        });

        return result;
    }

    /// Lookup an object that represents a tree entry.
    ///
    /// ## Parameters
    /// * `self` - Root object that can be peeled to a tree
    /// * `path` - Relative path from the root object to the desired object
    /// * `object_type` - Type of object desired
    pub fn lookupByPath(self: *const Object, path: [:0]const u8, object_type: ObjectType) !*Object {
        if (internal.trace_log) log.debug("Object.lookupByPath called", .{});

        var ret: *Object = undefined;

        try internal.wrapCall("git_object_lookup_bypath", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*const c.git_object, @ptrCast(self)),
            path.ptr,
            @intFromEnum(object_type),
        });

        return ret;
    }

    /// Recursively peel an object until an object of the specified type is met.
    ///
    /// If the query cannot be satisfied due to the object model, `error.InvalidSpec` will be returned (e.g. trying to peel a blob
    /// to a tree).
    ///
    /// If you pass `ObjectType.any` as the target type, then the object will be peeled until the type changes.
    /// A tag will be peeled until the referenced object is no longer a tag, and a commit will be peeled to a tree.
    /// Any other object type will return `error.InvalidSpec`.
    ///
    /// If peeling a tag we discover an object which cannot be peeled to the target type due to the object model, `error.Peel`
    /// will be returned.
    ///
    /// You must `deinit` the returned object.
    ///
    /// ## Parameters
    /// * `target_type` - The type of the requested object
    pub fn peel(self: *const Object, target_type: ObjectType) !*git.Object {
        if (internal.trace_log) log.debug("Object.peel called", .{});

        var ret: *Object = undefined;

        try internal.wrapCall("git_object_peel", .{
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*const c.git_object, @ptrCast(self)),
            @intFromEnum(target_type),
        });

        return ret;
    }

    /// Create an in-memory copy of a Git object. The copy must be explicitly `deinit`'d or it will leak.
    pub fn duplicate(self: *Object) *Object {
        if (internal.trace_log) log.debug("Object.duplicate called", .{});

        var ret: *Object = undefined;

        _ = c.git_object_dup(
            @as(*?*c.git_object, @ptrCast(&ret)),
            @as(*c.git_object, @ptrCast(self)),
        );

        return ret;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

/// Basic type (loose or packed) of any Git object.
pub const ObjectType = enum(c_int) {
    /// Object can be any of the following
    any = -2,
    /// Object is invalid.
    invalid = -1,
    /// A commit object.
    commit = 1,
    /// A tree (directory listing) object.
    tree = 2,
    /// A file revision object.
    blob = 3,
    /// An annotated tag object.
    tag = 4,
    /// A delta, base is given by an offset.
    ofs_delta = 6,
    /// A delta, base is given by object id.
    ref_delta = 7,

    /// Convert an object type to its string representation.
    pub fn toString(self: ObjectType) [:0]const u8 {
        return std.mem.sliceTo(
            c.git_object_type2string(@intFromEnum(self)),
            0,
        );
    }

    /// Convert a string object type representation to it's `ObjectType`.
    ///
    /// If the given string is not a valid object type `.invalid` is returned.
    pub fn fromString(str: [:0]const u8) ObjectType {
        return @as(ObjectType, @enumFromInt(c.git_object_string2type(str.ptr)));
    }

    /// Determine if the given `ObjectType` is a valid loose object type.
    pub fn validLoose(self: ObjectType) bool {
        return c.git_object_typeisloose(@intFromEnum(self)) != 0;
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
