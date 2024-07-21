const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Credential = extern struct {
    credtype: CredentialType,
    free: *const fn (*Credential) callconv(.C) void,

    pub fn deinit(self: *Credential) void {
        if (internal.trace_log) log.debug("Credential.deinit called", .{});

        if (internal.has_credential) {
            c.git_credential_free(@as(*internal.RawCredentialType, @ptrCast(self)));
        } else {
            c.git_cred_free(@as(*internal.RawCredentialType, @ptrCast(self)));
        }
    }

    pub fn hasUsername(self: *Credential) bool {
        if (internal.trace_log) log.debug("Credential.hasUsername called", .{});

        return if (internal.has_credential)
            c.git_credential_has_username(@as(*internal.RawCredentialType, @ptrCast(self))) != 0
        else
            c.git_cred_has_username(@as(*internal.RawCredentialType, @ptrCast(self))) != 0;
    }

    pub fn getUsername(self: *Credential) ?[:0]const u8 {
        if (internal.trace_log) log.debug("Credential.getUsername called", .{});

        const opt_username = if (internal.has_credential)
            c.git_credential_get_username(@as(*internal.RawCredentialType, @ptrCast(self)))
        else
            c.git_cred_get_username(@as(*internal.RawCredentialType, @ptrCast(self)));

        return if (opt_username) |username| std.mem.sliceTo(username, 0) else null;
    }

    /// A plaintext username and password
    pub const CredentialUserpassPlaintext = extern struct {
        /// The parent credential
        parent: Credential,
        /// The username to authenticate as
        username: [*:0]const u8,
        /// The password to use
        password: [*:0]const u8,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_credential_userpass_plaintext), @sizeOf(CredentialUserpassPlaintext));
            try std.testing.expectEqual(@bitSizeOf(c.git_credential_userpass_plaintext), @bitSizeOf(CredentialUserpassPlaintext));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// Username-only credential information
    pub const CredentialUsername = extern struct {
        /// The parent credential
        parent: Credential,
        /// Use `username()`
        z_username: [1]u8,

        /// The username to authenticate as
        pub fn username(self: CredentialUsername) [:0]const u8 {
            return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&self.z_username)), 0);
        }

        test {
            try std.testing.expectEqual(@sizeOf(c.git_credential_username), @sizeOf(CredentialUsername));
            try std.testing.expectEqual(@bitSizeOf(c.git_credential_username), @bitSizeOf(CredentialUsername));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// A ssh key from disk
    pub const CredentialSshKey = extern struct {
        /// The parent credential
        parent: Credential,
        /// The username to authenticate as
        username: [*:0]const u8,
        /// The path to a public key
        publickey: [*:0]const u8,
        /// The path to a private key
        privatekey: [*:0]const u8,
        /// Passphrase to decrypt the private key
        passphrase: ?[*:0]const u8,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_credential_ssh_key), @sizeOf(CredentialSshKey));
            try std.testing.expectEqual(@bitSizeOf(c.git_credential_ssh_key), @bitSizeOf(CredentialSshKey));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    usingnamespace if (internal.has_libssh2) struct {
        /// A plaintext username and password
        pub const CredentialSshInteractive = extern struct {
            /// The parent credential
            parent: Credential,
            /// The username to authenticate as
            username: [*:0]const u8,

            /// Callback used for authentication.
            prompt_callback: *const fn (
                name: [*]const u8,
                name_len: c_int,
                instruction: [*]const u8,
                instruction_len: c_int,
                num_prompts: c_int,
                prompts: ?*const c.LIBSSH2_USERAUTH_KBDINT_PROMPT,
                responses: ?*c.LIBSSH2_USERAUTH_KBDINT_RESPONSE,
                abstract: ?*?*anyopaque,
            ) callconv(.C) void,

            /// Payload passed to prompt_callback
            payload: ?*anyopaque,

            test {
                try std.testing.expectEqual(@sizeOf(c.git_credential_ssh_interactive), @sizeOf(CredentialSshInteractive));
                try std.testing.expectEqual(@bitSizeOf(c.git_credential_ssh_interactive), @bitSizeOf(CredentialSshInteractive));
            }

            comptime {
                std.testing.refAllDecls(@This());
            }
        };

        /// A ssh key from disk
        pub const CredentialSshCustom = extern struct {
            /// The parent credential
            parent: Credential,
            /// The username to authenticate as
            username: [*:0]const u8,
            /// The public key data
            publickey: [*:0]const u8,
            /// Length of the public key
            publickey_len: usize,

            sign_callback: *const fn (
                session: ?*c.LIBSSH2_SESSION,
                sig: *[*:0]u8,
                sig_len: *usize,
                data: [*]const u8,
                data_len: usize,
                abstract: ?*?*anyopaque,
            ) callconv(.C) c_int,

            payload: ?*anyopaque,

            test {
                try std.testing.expectEqual(@sizeOf(c.git_credential_ssh_custom), @sizeOf(CredentialSshCustom));
                try std.testing.expectEqual(@bitSizeOf(c.git_credential_ssh_custom), @bitSizeOf(CredentialSshCustom));
            }

            comptime {
                std.testing.refAllDecls(@This());
            }
        };

        comptime {
            std.testing.refAllDecls(@This());
        }
    } else struct {};

    test {
        try std.testing.expectEqual(@sizeOf(c.git_cred), @sizeOf(Credential));
        try std.testing.expectEqual(@bitSizeOf(c.git_cred), @bitSizeOf(Credential));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const CredentialType = packed struct {
    /// A vanilla user/password request
    userpass_plaintext: bool = false,

    /// An SSH key-based authentication request
    ssh_key: bool = false,

    /// An SSH key-based authentication request, with a custom signature
    ssh_custom: bool = false,

    /// An NTLM/Negotiate-based authentication request.
    default: bool = false,

    /// An SSH interactive authentication request
    ssh_interactive: bool = false,

    /// Username-only authentication request
    ///
    /// Used as a pre-authentication step if the underlying transport (eg. SSH, with no username in its URL) does not know
    /// which username to use.
    username: bool = false,

    /// An SSH key-based authentication request
    ///
    /// Allows credentials to be read from memory instead of files.
    /// Note that because of differences in crypto backend support, it might not be functional.
    ssh_memory: bool = false,

    z_padding: u25 = 0,

    pub fn format(
        value: CredentialType,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        return internal.formatWithoutFields(
            value,
            options,
            writer,
            &.{"z_padding"},
        );
    }

    test {
        try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(CredentialType));
        try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(CredentialType));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
