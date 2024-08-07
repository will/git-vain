pub const GitSha = @import("lib/gitSha.zig");
pub const Target = @import("lib/target.zig");
pub const FoundFlag = @import("lib/foundFlag.zig");
pub const Git = @import("lib/git.zig");

pub const Cpu = switch (@import("builtin").os.tag) {
    .macos => @import("lib/cpu_macos.zig"),
    else => @import("lib/cpu_other.zig"),
};

comptime {
    @import("std").testing.refAllDecls(@This());
}
