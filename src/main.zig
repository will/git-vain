const std = @import("std");
const print = std.debug.print;

const lib = @import("lib.zig");
const GitSha = lib.GitSha;
const Target = lib.Target;

var GlobalFoundFlag = lib.FoundFlag{};

pub fn main() !void {
    const target = try lib.Target.init();

    const thread_count = lib.Cpu.getPerfCores();
    var sha = GitSha.init();
    for (0..thread_count) |i| {
        const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha, target });
        handle.detach();
    }

    GlobalFoundFlag.wait();
    print("done\n", .{}); // TODO: too lazy to figure out how to flush stderr
}

fn search(start: u64, step: u8, sha: *GitSha, target: Target) !void {
    var i = start;

    while (true) : (i += step) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = sha.trySha(numAsString);
        if (target.match(&result) and GlobalFoundFlag.setFound()) {
            print("{d}: {x}\n", .{ i, result });
            break;
        }
    }
}

comptime {
    std.testing.refAllDecls(@This());
}
