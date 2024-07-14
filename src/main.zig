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

    const thread_count = Cpu.getPerfCores();
    for (0..thread_count) |i| {
        const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha });
        handle.detach();
    }

    GlobalFoundFlag.wait();

    const final = sha.trySha("");

    print("All your {s} are belong to {x}.\n", .{ "stuff", final });
}

fn search(start: u64, step: u8, sha: *GitSha) !void {
    var i = start;

    while (true) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = sha.trySha(numAsString);
        if (result[0] == 0 and result[1] == 0 and result[2] == 0 and result[3] != 0) {
            if (GlobalFoundFlag.setFound()) {
                print("{d}: {x}\n", .{ i, result });
            }
            break;
        }

        i += step;
    }
}
