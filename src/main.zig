const std = @import("std");

const lib = @import("lib.zig");
const GitSha = lib.GitSha;
const Target = lib.Target;
const Git = lib.Git;

var GlobalFoundFlag = lib.FoundFlag{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var git = try Git.init();
    const target = try Target.init(&git);
    const sha = try GitSha.init(&git, allocator);

    std.debug.print("try {x}\nreal {x}\n", .{ try sha.tryOffset(0, 0), sha.startingSha });

    if (target.match(&sha.startingSha)) {
        std.debug.print("already at target\n", .{});
        std.process.exit(0);
    }

    const thread_count = lib.Cpu.getPerfCores();
    for (0..thread_count) |i| {
        const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha, target });
        handle.detach();
    }

    GlobalFoundFlag.wait();
    std.debug.print("done\n", .{}); // TODO: too lazy to figure out how to flush stderr
}

fn search(start: u64, step: u8, sha: *const GitSha, target: Target) !void {
    var i = start;

    while (true) : (i += step) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = sha.trySha(numAsString);
        if (target.match(&result) and GlobalFoundFlag.setFound()) {
            std.debug.print("{d}: {x}\n", .{ i, result });
            break;
        }
    }
}

comptime {
    std.testing.refAllDecls(@This());
}
