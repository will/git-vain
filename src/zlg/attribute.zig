const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

pub const Attribute = struct {
    z_attr: ?[*:0]const u8,

    /// Check if an attribute is set on. In core git parlance, this the value for "Set" attributes.
    ///
    /// For example, if the attribute file contains:
    ///    *.c foo
    ///
    /// Then for file `xyz.c` looking up attribute "foo" gives a value for which this is true.
    pub fn isTrue(self: Attribute) bool {
        return self.getValue() == .true;
    }

    /// Checks if an attribute is set off. In core git parlance, this is the value for attributes that are "Unset" (not to be
    /// confused with values that a "Unspecified").
    ///
    /// For example, if the attribute file contains:
    ///    *.h -foo
    ///
    /// Then for file `zyx.h` looking up attribute "foo" gives a value for which this is true.
    pub fn isFalse(self: Attribute) bool {
        return self.getValue() == .false;
    }

    /// Checks if an attribute is unspecified. This may be due to the attribute not being mentioned at all or because the
    /// attribute was explicitly set unspecified via the `!` operator.
    ///
    /// For example, if the attribute file contains:
    ///    *.c foo
    ///    *.h -foo
    ///    onefile.c !foo
    ///
    /// Then for `onefile.c` looking up attribute "foo" yields a value with of true. Also, looking up "foo" on file `onefile.rb`
    /// or looking up "bar" on any file will all give a value of true.
    pub fn isUnspecified(self: Attribute) bool {
        return self.getValue() == .unspecified;
    }

    /// Checks if an attribute is set to a value (as opposed to @"true", @"false" or unspecified). This would be the case if for a file
    /// with something like:
    ///    *.txt eol=lf
    ///
    /// Given this, looking up "eol" for `onefile.txt` will give back the string "lf" and will return true.
    pub fn hasValue(self: Attribute) bool {
        return self.getValue() == .string;
    }

    pub fn getValue(self: Attribute) AttributeValue {
        return @enumFromInt(c.git_attr_value(self.z_attr));
    }

    pub const AttributeValue = enum(c_uint) {
        /// The attribute has been left unspecified
        unspecified = 0,
        /// The attribute has been set
        true,
        /// The attribute has been unset
        false,
        /// This attribute has a value
        string,
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const AttributeOptions = struct {
    flags: git.AttributeFlags,
    commit_id: *git.Oid,

    comptime {
        std.testing.refAllDecls(@This());
    }
};

pub const AttributeFlags = struct {
    location: Location = .file_then_index,

    /// Controls extended attribute behavior
    extended: Extended = .{},

    pub const Location = enum(u32) {
        file_then_index = 0,
        index_then_file = 1,
        index_only = 2,
    };

    pub const Extended = packed struct {
        z_padding1: u2 = 0,

        /// Normally, attribute checks include looking in the /etc (or system equivalent) directory for a `gitattributes`
        /// file. Passing this flag will cause attribute checks to ignore that file. Setting the `no_system` flag will cause
        /// attribute checks to ignore that file.
        no_system: bool = false,

        /// Passing the `include_head` flag will use attributes from a `.gitattributes` file in the repository
        /// at the HEAD revision.
        include_head: bool = false,

        /// Passing the `include_commit` flag will use attributes from a `.gitattributes` file in a specific
        /// commit.
        include_commit: if (HAS_INCLUDE_COMMIT) bool else void = if (HAS_INCLUDE_COMMIT) false else {},

        z_padding2: if (HAS_INCLUDE_COMMIT) u27 else u28 = 0,

        const HAS_INCLUDE_COMMIT = @hasDecl(c, "GIT_ATTR_CHECK_INCLUDE_COMMIT");

        pub fn format(
            value: Extended,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            return internal.formatWithoutFields(
                value,
                options,
                writer,
                &.{ "z_padding1", "z_padding2" },
            );
        }

        test {
            try std.testing.expectEqual(@sizeOf(u32), @sizeOf(Extended));
            try std.testing.expectEqual(@bitSizeOf(u32), @bitSizeOf(Extended));
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

comptime {
    std.testing.refAllDecls(@This());
}
