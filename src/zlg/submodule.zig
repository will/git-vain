const std = @import("std");
const c = @import("internal/c.zig");
const internal = @import("internal/internal.zig");
const log = std.log.scoped(.git);

const git = @import("git.zig");

/// Submodule ignore values
///
/// These values represent settings for the `submodule.$name.ignore` configuration value which says how deeply to look at the
/// working directory when getting submodule status.
///
/// You can override this value in memory on a per-submodule basis with `Submodule.getIgnore` and can write the changed value to
/// disk with `Submodule.save`.
pub const SubmoduleIgnore = enum(c_int) {
    /// Use the submodule's configuration
    unspecified = -1,

    default = 0,

    /// Don't ignore any change - i.e. even an untracked file, will mark the submodule as dirty. Ignored files are still ignored,
    /// of course.
    none = 1,

    /// Ignore untracked files; only changes to tracked files, or the index or the HEAD commit will matter.
    untracked = 2,

    /// Ignore changes in the working directory, only considering changes if the HEAD of submodule has moved from the value in the
    /// superproject.
    dirty = 3,

    /// Never check if the submodule is dirty
    all = 4,
};

comptime {
    std.testing.refAllDecls(@This());
}
