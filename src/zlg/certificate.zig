const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Certificate = extern struct {
    /// Type of certificate
    cert_type: CertificateType,

    pub const CertificateType = enum(c_uint) {
        ///  No information about the certificate is available. This may happen when using curl.
        none = 0,
        ///  The `data` argument to the callback will be a pointer to the DER-encoded data.
        x509,
        ///  The `data` argument to the callback will be a pointer to a `HostkeyCertificate` structure.
        hostkey_libssh2,
        ///  The `data` argument to the callback will be a pointer to a `git.StrArray` with `name:content` strings containing
        ///  information about the certificate. This is used when using  curl.
        strarray,
    };

    /// Hostkey information taken from libssh2
    pub const HostkeyCertificate = extern struct {
        /// The parent cert
        parent: Certificate,

        available: HostkeyAvailableFields,

        /// Hostkey hash. If `available` has `md5` set, this will have the MD5 hash of the hostkey.
        hash_md5: [16]u8,

        /// Hostkey hash. If `available` has `sha1` set, this will have the SHA1 hash of the hostkey.
        hash_sha1: [20]u8,

        /// Hostkey hash. If `available` has `sha256` set, this will have the SHA256 hash of the hostkey.
        hash_sha256: [32]u8,

        /// Raw hostkey type. If `available` has `raw` set, this will have the type of the raw hostkey.
        raw_type: RawType,

        /// Pointer to the raw hostkey. If `available` has `raw` set, this will be the raw contents of the hostkey.
        hostkey: [*]const u8,

        /// Length of the raw hostkey. If `available` has `raw` set, this will have the length of the raw contents of the hostkey.
        hostkey_len: usize,

        /// A bitmask containing the available fields.
        pub const HostkeyAvailableFields = packed struct {
            /// MD5 is available
            md5: bool,
            /// SHA-1 is available
            sha1: bool,
            /// SHA-256 is available
            sha256: bool,
            /// Raw hostkey is available
            raw: bool,

            z_padding: u28 = 0,

            pub fn format(
                value: HostkeyAvailableFields,
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
                try std.testing.expectEqual(@sizeOf(c_uint), @sizeOf(HostkeyAvailableFields));
                try std.testing.expectEqual(@bitSizeOf(c_uint), @bitSizeOf(HostkeyAvailableFields));
            }

            comptime {
                std.testing.refAllDecls(@This());
            }
        };

        pub const RawType = enum(c_uint) {
            /// The raw key is of an unknown type.
            unknown = 0,
            /// The raw key is an RSA key.
            rsa = 1,
            /// The raw key is a DSS key.
            dss = 2,
            /// The raw key is a ECDSA 256 key.
            key_ecdsa_256 = 3,
            /// The raw key is a ECDSA 384 key.
            key_ecdsa_384 = 4,
            /// The raw key is a ECDSA 521 key.
            key_ecdsa_521 = 5,
            /// The raw key is a ED25519 key.
            key_ed25519 = 6,
        };

        test {
            try std.testing.expectEqual(@sizeOf(c.git_cert_hostkey), @sizeOf(HostkeyCertificate));
            try std.testing.expectEqual(@bitSizeOf(c.git_cert_hostkey), @bitSizeOf(HostkeyCertificate));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    /// X.509 certificate information
    pub const x509Certificate = extern struct {
        parent: Certificate,

        /// Pointer to the X.509 certificate data
        data: *anyopaque,

        /// Length of the memory block pointed to by `data`.
        length: usize,

        test {
            try std.testing.expectEqual(@sizeOf(c.git_cert_x509), @sizeOf(x509Certificate));
            try std.testing.expectEqual(@bitSizeOf(c.git_cert_x509), @bitSizeOf(x509Certificate));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    test {
        try std.testing.expectEqual(@sizeOf(c.git_cert), @sizeOf(Certificate));
        try std.testing.expectEqual(@bitSizeOf(c.git_cert), @bitSizeOf(Certificate));
    }

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
