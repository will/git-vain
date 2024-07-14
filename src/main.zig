const std = @import("std");
const print = std.debug.print;

const GitSha = @import("gitSha.zig");
const Target = @import("target.zig");
const FoundFlag = @import("foundFlag.zig");
test "make sure to run imported tests" {
    _ = FoundFlag{};
    _ = Target{};
    _ = GitSha{};
}

const Cpu = switch (@import("builtin").os.tag) {
    .macos => @import("cpu_macos.zig"),
    else => @import("cpu_other.zig"),
};

var GlobalFoundFlag = FoundFlag{};

pub fn main() !void {
    var sha = GitSha.init();
    const target = try Target.init("cafe");

    const thread_count = Cpu.getPerfCores();
    for (0..thread_count) |i| {
        const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha, target });
        handle.detach();
    }

    GlobalFoundFlag.wait();

    const final = sha.trySha("");

    print("All your {s} are belong to {x}.\n", .{ "stuff", final });
}

fn search(start: u64, step: u8, sha: *GitSha, target: Target) !void {
    var i = start;

    while (true) : (i += step) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = sha.trySha(numAsString);
        if (target.match(&result)) {
            if (GlobalFoundFlag.setFound()) {
                print("{d}: {x}\n", .{ i, result });
            }
            break;
        }
    }
}
