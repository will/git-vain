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
        printSha(sha.startingSha, target.buf_len);
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
        const handle = try std.Thread.spawn(.{}, display, .{ &counts, target });
        handle.detach();
    }

    GlobalFoundFlag.wait();
    std.debug.print("found: {d}, ", .{GlobalFoundFlag.value});

    const oid = try sha.amend(GlobalFoundFlag.value);
    printSha(oid.id, target.buf_len);
}

fn printSha(sha: [20]u8, bold_len: u8) void {
    // TODO: hilight odd search targets properly
    std.debug.print("\x1b[1;4m", .{});
    for (sha[0..bold_len]) |c| std.debug.print("{x}", .{c});
    std.debug.print("\x1b[0m", .{});
    for (sha[bold_len..]) |c| std.debug.print("{x}", .{c});
    std.debug.print("\n", .{});
}

fn display(counts: *[]i32, target: Target) void {
    var last: u64 = 0;
    while (!GlobalFoundFlag.found) {
        var sum: u64 = 0;
        for (counts.*) |c| sum += @intCast(c);
        const mhash = @as(f64, @floatFromInt(sum - last)) / 1_000_000;
        std.debug.print("{any}: {d}khash, {d:.1} Mh/s\r", .{ target, sum / 1000, mhash });
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
