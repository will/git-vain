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

    if (target.match(&sha.startingSha)) {
        std.debug.print("already at target: ", .{});
        for (sha.startingSha) |c| std.debug.print("{x}", .{c});
        std.debug.print("\n", .{});
        std.process.exit(0);
    }

    const thread_count = lib.Cpu.getPerfCores();
    var counts = try allocator.alloc(i32, thread_count);
    for (0..thread_count) |i| {
        const start: i32 = @intCast(i + 1);
        counts[i] = 0;
        const handle = try std.Thread.spawn(.{}, search, .{ start, thread_count, &sha, target, &(counts[i]) });
        handle.detach();
    }

    {
        const handle = try std.Thread.spawn(.{}, display, .{&counts});
        handle.detach();
    }

    GlobalFoundFlag.wait();
    std.debug.print("found: {d}, ", .{GlobalFoundFlag.value});

    const oid = try sha.amend(GlobalFoundFlag.value);
    for (oid.id) |c| std.debug.print("{x}", .{c});
    std.debug.print("\n", .{});
}

fn display(counts: *[]i32) void {
    var last: u64 = 0;
    while (!GlobalFoundFlag.found) {
        var sum: u64 = 0;
        for (counts.*) |c| sum += @intCast(c);
        const diff: f64 = @floatFromInt(sum - last);
        const mhash: f64 = diff / 1_000_000;
        std.debug.print("khash: {d}, {d:.1} Mh/s\r", .{ sum / 1000, mhash });
        last = sum;
        std.time.sleep(std.time.ns_per_s);
    }
}

fn search(start: i32, step: u8, sha: *const GitSha, target: Target, counter: *i32) !void {
    var i = start;
    var next_count_write: i32 = 0;

    while (!GlobalFoundFlag.found) : (i += step) {
        const result = try sha.trySpiral(i);
        if (i > next_count_write) {
            counter.* = @divTrunc(i - start, step);
            next_count_write += 100_000;
        }
        if (target.match(&result) and GlobalFoundFlag.setFound(i)) break;
    }
}

comptime {
    std.testing.refAllDecls(@This());
}
