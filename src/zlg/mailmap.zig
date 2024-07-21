const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Mailmap = opaque {
    /// Free the mailmap and its associated memory.
    pub fn deinit(self: *Mailmap) void {
        if (internal.trace_log) log.debug("Mailmap.deinit called", .{});

        c.git_mailmap_free(@as(*c.git_mailmap, @ptrCast(self)));
    }

    /// Add a single entry to the given mailmap object. If the entry already exists, it will be replaced with the new entry.
    ///
    /// ## Parameters
    /// * `real_name` - The real name to use, or `null`
    /// * `real_email` - The real email to use, or `null`
    /// * `replace_name` - The name to replace, or `null
    /// * `replace_email` - The email to replace
    pub fn addEntry(
        self: *Mailmap,
        real_name: ?[:0]const u8,
        real_email: ?[:0]const u8,
        replace_name: ?[:0]const u8,
        replace_email: [:0]const u8,
    ) !void {
        if (internal.trace_log) log.debug("Mailmap.addEntry called", .{});

        const c_real_name = if (real_name) |ptr| ptr.ptr else null;
        const c_real_email = if (real_email) |ptr| ptr.ptr else null;
        const c_replace_name = if (replace_name) |ptr| ptr.ptr else null;

        try internal.wrapCall("git_mailmap_add_entry", .{
            @as(*c.git_mailmap, @ptrCast(self)),
            c_real_name,
            c_real_email,
            c_replace_name,
            replace_email.ptr,
        });
    }

    pub const ResolveResult = struct {
        real_name: [:0]const u8,
        real_email: [:0]const u8,
    };

    /// Resolve a name and email to the corresponding real name and email.
    ///
    /// The lifetime of the strings are tied to `self`, `name`, and `email` parameters.
    ///
    /// ## Parameters
    /// * `self` - The mailmap to perform a lookup with (may be `null`)
    /// * `name` - The name to look up
    /// * `email` - The email to look up
    pub fn resolve(self: ?*const Mailmap, name: [:0]const u8, email: [:0]const u8) !ResolveResult {
        if (internal.trace_log) log.debug("Mailmap.resolve called", .{});

        var real_name: ?[*:0]const u8 = undefined;
        var real_email: ?[*:0]const u8 = undefined;

        try internal.wrapCall("git_mailmap_resolve", .{
            &real_name,
            &real_email,
            @as(*const c.git_mailmap, @ptrCast(self)),
            name.ptr,
            email.ptr,
        });

        return ResolveResult{
            .real_name = std.mem.sliceTo(real_name.?, 0),
            .real_email = std.mem.sliceTo(real_email.?, 0),
        };
    }

    /// Resolve a signature to use real names and emails with a mailmap.
    ///
    /// Call `git.Signature.deinit` to free the data.
    ///
    /// ## Parameters
    /// * `signature` - Signature to resolve
    pub fn resolveSignature(self: *const Mailmap, signature: *const git.Signature) !*git.Signature {
        if (internal.trace_log) log.debug("Mailmap.resolveSignature called", .{});

        var sig: *git.Signature = undefined;

        try internal.wrapCall("git_mailmap_resolve_signature", .{
            @as(*?*c.git_signature, @ptrCast(&sig)),
            @as(*const c.git_mailmap, @ptrCast(self)),
            @as(*const c.git_signature, @ptrCast(signature)),
        });

        return sig;
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
