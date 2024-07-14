const std = @import("std");
const Sha1 = std.crypto.hash.Sha1;
const print = std.debug.print;

var GlobalSem = std.Thread.Semaphore{};
pub fn main() !void {
    var sha = Sha1.init(.{});

    {
        const thread_count = 8;
        inline for (0..thread_count) |i| {
            const handle = try std.Thread.spawn(.{}, search, .{ i, thread_count, &sha });
            handle.detach();
        }
    }
    //print("non threaded:\n", .{});
    //try search(0, 1, &sha);

    GlobalSem.wait();

    const final = finalSha(&sha, "");

    print("All your {s} are belong to {x}.\n", .{ "codebase", final });
}

fn search(start: u64, step: u8, sha: *Sha1) !void {
    var i = start;

    while (true) {
        if (GlobalFoundFlag.found) break;

        var buf: [20]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{i});
        const result = finalSha(sha, numAsString);
        if (result[0] == 0 and result[1] == 0 and result[2] == 0 and result[3] == 0) {
            if (GlobalFoundFlag.setFound()) {
                print("{d}: {x}\n", .{ i, result });
                GlobalSem.post();
            }
            break;
        }

        i += step;
    }
}

var GlobalFoundFlag = FoundFlag{};

const FoundFlag = struct {
    const Self = @This();

    found: bool = false,
    lock: std.Thread.Mutex = .{},

    // returns true if was able to set from false to true,
    // returns false if it was already found
    pub fn setFound(self: *Self) bool {
        self.lock.lock();
        defer self.lock.unlock();
        if (self.found) {
            return false;
        }

        self.found = true;
        return true;
    }

    test "setFound" {
        var ff = Self{};

        try std.testing.expect(!ff.found);

        var result = ff.setFound();
        try std.testing.expect(result);
        try std.testing.expect(ff.found);

        result = ff.setFound();
        try std.testing.expect(!result);
        try std.testing.expect(ff.found);
    }
};

test "FoundFlag" {
    const ff = FoundFlag{};
    try std.testing.expect(!ff.found);
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
