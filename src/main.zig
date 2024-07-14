const std = @import("std");
const Sha1 = std.crypto.hash.Sha1;
const print = std.debug.print;

const Target = @import("target.zig");
const FoundFlag = @import("foundFlag.zig");
test "make sure to run imported tests" {
    _ = FoundFlag{};
    _ = Target{};
}

const Cpu = switch (@import("builtin").os.tag) {
    .macos => @import("cpu_macos.zig"),
    else => @import("cpu_other.zig"),
};

var GlobalFoundFlag = FoundFlag{};

pub fn main() !void {
    var sha = Sha1.init(.{});

    const thread_count = Cpu.getPerfCores();
    for (0..thread_count) |i| {
        const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha });
        handle.detach();
    }

    GlobalFoundFlag.wait();

    const final = finalSha(&sha, "");

    print("All your {s} are belong to {x}.\n", .{ "stuff", final });
}

fn search(start: u64, step: u8, sha: *Sha1) !void {
    var i = start;

    while (true) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = finalSha(sha, numAsString);
        if (result[0] == 0 and result[1] == 0 and result[2] == 0 and result[3] != 0) {
            if (GlobalFoundFlag.setFound()) {
                print("{d}: {x}\n", .{ i, result });
            }
            break;
        }

        i += step;
    }
}

fn finalSha(original: *Sha1, str: []const u8) [20]u8 {
    var dupe_hash = Sha1{ .s = original.s, .buf = original.buf, .buf_len = original.buf_len };
    var result: [20]u8 = undefined;

    dupe_hash.update(str);
    dupe_hash.final(&result);

    return result;
}

test "finalSha" {
    var sha = Sha1.init(.{});
    sha.update("abc");

    const original_state = sha.s;
    // can call several times without updating original
    const result1 = finalSha(&sha, "def");
    const result2 = finalSha(&sha, "def");
    try std.testing.expectEqual(result1, result2);
    try std.testing.expectEqual(original_state, sha.s);
}
