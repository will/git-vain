const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const Child = std.process.Child;
const ArrayList = std.ArrayList;

allocator: Allocator = undefined,

pub fn init(allocator: Allocator) !Self {
    return Self{ .allocator = allocator };
}

fn runGitCmd(self: *Self, argv: []const []const u8) ![]const u8 {
    var child = Child.init(argv, self.allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var stdout = ArrayList(u8).init(self.allocator);
    var stderr = ArrayList(u8).init(self.allocator);
    defer {
        stdout.deinit();
        stderr.deinit();
    }

    try child.spawn();
    try child.collectOutput(&stdout, &stderr, 1024);
    const term = try child.wait();

    if (term.Exited == 0) {
        const rawRet = stdout.items[0 .. stdout.items.len - 1];
        const ret = try self.allocator.alloc(u8, rawRet.len);
        std.mem.copyForwards(u8, ret, rawRet);
        return ret;
    } else return error.NonZeroExitGit;
}

pub fn getDefault(self: *Self) []const u8 {
    const argv = [_][]const u8{ "git", "config", "vain.default" };
    if (self.runGitCmd(&argv)) |git| {
        return git;
    } else |err| {
        std.debug.print("error getting git config vain.default: {!}\n", .{err});
        return "1234";
    }
}

test "getDefault" {
    var buffer: [20_000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var git = try init(fba.allocator());

    const d = git.getDefault();
    try std.testing.expect(d[0] != 0);
}

comptime {
    std.testing.refAllDecls(Self);
}
