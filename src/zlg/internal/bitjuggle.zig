const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

/// Returns `true` is the the bit at index `bit` is set (equals 1).
/// Note: that index 0 is the least significant bit, while index `length() - 1` is the most significant bit.
///
/// ```zig
/// const a: u8 = 0b00000010;
///
/// try testing.expect(!isBitSet(a, 0));
/// try testing.expect(isBitSet(a, 1));
/// ```
pub fn isBitSet(target: anytype, comptime bit: comptime_int) bool {
    const TargetType = @TypeOf(target);

    const MaskType = std.meta.Int(.unsigned, bit + 1);

    const mask: MaskType = comptime blk: {
        var temp: MaskType = std.math.maxInt(MaskType);
        temp <<= bit;
        break :blk temp;
    };

    comptime {
        if (@typeInfo(TargetType) == .Int) {
            if (@typeInfo(TargetType).Int.signedness != .unsigned) {
                @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
            }
            if (bit >= @bitSizeOf(TargetType)) {
                @compileError("bit index is out of bounds of the bit field");
            }
        } else if (@typeInfo(TargetType) == .ComptimeInt) {
            if (target < 0) {
                @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
            }
        } else {
            @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
        }
    }

    return @as(MaskType, @truncate(target)) & mask != 0;
}

test "isBitSet" {
    const a: u8 = 0b00000000;
    try testing.expect(!isBitSet(a, 0));
    try testing.expect(!isBitSet(a, 1));

    const b: u8 = 0b11111111;
    try testing.expect(isBitSet(b, 0));
    try testing.expect(isBitSet(b, 1));

    const c: u8 = 0b00000010;
    try testing.expect(!isBitSet(c, 0));
    try testing.expect(isBitSet(c, 1));
}

test "isBitSet - comptime_int" {
    const a = 0b00000000;
    try testing.expect(!isBitSet(a, 0));
    try testing.expect(!isBitSet(a, 1));

    const b = 0b11111111;
    try testing.expect(isBitSet(b, 0));
    try testing.expect(isBitSet(b, 1));

    const c = 0b00000010;
    try testing.expect(!isBitSet(c, 0));
    try testing.expect(isBitSet(c, 1));
}

/// Get the value of the bit at index `bit`.
/// Note: that index 0 is the least significant bit, while index `length() - 1` is the most significant bit.
///
/// ```zig
/// const a: u8 = 0b00000010;
///
/// try testing.expect(getBit(a, 0) == 0);
/// try testing.expect(getBit(a, 1) == 1);
/// ```
pub fn getBit(target: anytype, comptime bit: comptime_int) u1 {
    return @intFromBool(isBitSet(target, bit));
}

test "getBit" {
    const a: u8 = 0b00000000;
    try testing.expectEqual(@as(u1, 0), getBit(a, 0));
    try testing.expectEqual(@as(u1, 0), getBit(a, 1));

    const b: u8 = 0b11111111;
    try testing.expectEqual(@as(u1, 1), getBit(b, 0));
    try testing.expectEqual(@as(u1, 1), getBit(b, 1));

    const c: u8 = 0b00000010;
    try testing.expectEqual(@as(u1, 0), getBit(c, 0));
    try testing.expectEqual(@as(u1, 1), getBit(c, 1));
}

test "getBit - comptime_int" {
    const a = 0b00000000;
    try testing.expectEqual(@as(u1, 0), getBit(a, 0));
    try testing.expectEqual(@as(u1, 0), getBit(a, 1));

    const b = 0b11111111;
    try testing.expectEqual(@as(u1, 1), getBit(b, 0));
    try testing.expectEqual(@as(u1, 1), getBit(b, 1));

    const c = 0b00000010;
    try testing.expectEqual(@as(u1, 0), getBit(c, 0));
    try testing.expectEqual(@as(u1, 1), getBit(c, 1));
}

/// Obtains the `number_of_bits` bits starting at `start_bit`
/// Where `start_bit` is the lowest significant bit to fetch
///
/// ```zig
/// const a: u8 = 0b01101100;
/// const b = getBits(a, 2, 4);
/// try testing.expectEqual(@as(u4,0b1011), b);
/// ```
pub fn getBits(target: anytype, comptime start_bit: comptime_int, comptime number_of_bits: comptime_int) std.meta.Int(.unsigned, number_of_bits) {
    const TargetType = @TypeOf(target);

    comptime {
        if (number_of_bits == 0) @compileError("non-zero number_of_bits must be provided");

        if (@typeInfo(TargetType) == .Int) {
            if (@typeInfo(TargetType).Int.signedness != .unsigned) {
                @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
            }
            if (start_bit >= @bitSizeOf(TargetType)) {
                @compileError("start_bit index is out of bounds of the bit field");
            }
            if (start_bit + number_of_bits > @bitSizeOf(TargetType)) {
                @compileError("start_bit + number_of_bits is out of bounds of the bit field");
            }
        } else if (@typeInfo(TargetType) == .ComptimeInt) {
            if (target < 0) {
                @compileError("requires an positive integer, found a negative");
            }
        } else {
            @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
        }
    }

    return @truncate(target >> start_bit);
}

test "getBits" {
    const a: u8 = 0b01101100;
    const b = getBits(a, 2, 4);
    try testing.expectEqual(@as(u4, 0b1011), b);
}

test "getBits - comptime_int" {
    const a = 0b01101100;
    const b = getBits(a, 2, 4);
    try testing.expectEqual(@as(u4, 0b1011), b);
}

/// Sets the bit at the index `bit` to the value `value` (where true means a value of '1' and false means a value of '0')
/// Note: that index 0 is the least significant bit, while index `length() - 1` is the most significant bit.
///
/// ```zig
/// var val: u8 = 0b00000000;
/// try testing.expect(!getBit(val, 0));
/// setBit( &val, 0, true);
/// try testing.expect(getBit(val, 0));
/// ```
pub fn setBit(target: anytype, comptime bit: comptime_int, value: bool) void {
    const ptr_type_info: std.builtin.Type = @typeInfo(@TypeOf(target));
    comptime {
        if (ptr_type_info != .Pointer) @compileError("not a pointer");
    }

    const TargetType = ptr_type_info.Pointer.child;

    comptime {
        if (@typeInfo(TargetType) == .Int) {
            if (@typeInfo(TargetType).Int.signedness != .unsigned) {
                @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
            }
            if (bit >= @bitSizeOf(TargetType)) {
                @compileError("bit index is out of bounds of the bit field");
            }
        } else if (@typeInfo(TargetType) == .ComptimeInt) {
            @compileError("comptime_int is unsupported");
        } else {
            @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
        }
    }

    const MaskType = std.meta.Int(.unsigned, bit + 1);

    const mask: MaskType = comptime blk: {
        var temp: MaskType = 1;
        temp <<= bit;
        break :blk temp;
    };

    if (value) {
        target.* |= mask;
    } else {
        target.* &= ~(mask);
    }
}

test "setBit" {
    var val: u8 = 0b00000000;
    try testing.expect(!isBitSet(val, 0));
    setBit(&val, 0, true);
    try testing.expect(isBitSet(val, 0));
    setBit(&val, 0, false);
    try testing.expect(!isBitSet(val, 0));
}

/// Sets the range of bits starting at `start_bit` upto and excluding `start_bit` + `number_of_bits`.
/// To be specific, if the range is N bits long, the N lower bits of `value` will be used; if any of
/// the other bits in `value` are set to 1, this function will panic.
///
/// ```zig
/// var val: u8 = 0b10000000;
/// setBits(&val, 2, 4, 0b00001101);
/// try testing.expectEqual(@as(u8, 0b10110100), val);
/// ```
///
/// ## Panics
/// This method will panic if the `value` exceeds the bit range of the type of `target`
pub fn setBits(target: anytype, comptime start_bit: comptime_int, comptime number_of_bits: comptime_int, value: anytype) void {
    const ptr_type_info: std.builtin.Type = @typeInfo(@TypeOf(target));
    comptime {
        if (ptr_type_info != .Pointer) @compileError("not a pointer");
    }

    const TargetType = ptr_type_info.Pointer.child;
    const end_bit = start_bit + number_of_bits;

    comptime {
        if (number_of_bits == 0) @compileError("non-zero number_of_bits must be provided");

        if (@typeInfo(TargetType) == .Int) {
            if (@typeInfo(TargetType).Int.signedness != .unsigned) {
                @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
            }
            if (start_bit >= @bitSizeOf(TargetType)) {
                @compileError("start_bit index is out of bounds of the bit field");
            }
            if (end_bit > @bitSizeOf(TargetType)) {
                @compileError("start_bit + number_of_bits is out of bounds of the bit field");
            }
        } else if (@typeInfo(TargetType) == .ComptimeInt) {
            @compileError("comptime_int is unsupported");
        } else {
            @compileError("requires an unsigned integer, found " ++ @typeName(TargetType));
        }
    }

    const peer_value = @as(TargetType, value);

    if (std.debug.runtime_safety) {
        if (getBits(peer_value, 0, (end_bit - start_bit)) != peer_value) @panic("value exceeds bit range");
    }

    const bitmask: TargetType = comptime blk: {
        var bitmask = ~@as(TargetType, 0);
        bitmask <<= (@bitSizeOf(TargetType) - end_bit);
        bitmask >>= (@bitSizeOf(TargetType) - end_bit);
        bitmask >>= start_bit;
        bitmask <<= start_bit;
        break :blk ~bitmask;
    };

    target.* = (target.* & bitmask) | (peer_value << start_bit);
}

test "setBits" {
    var val: u8 = 0b10000000;
    setBits(&val, 2, 4, 0b00001101);
    try testing.expectEqual(@as(u8, 0b10110100), val);
}

inline fn PtrCastPreserveCV(comptime T: type, comptime PtrToT: type, comptime NewT: type) type {
    return switch (PtrToT) {
        *T => *NewT,
        *const T => *const NewT,
        *volatile T => *volatile NewT,
        *const volatile T => *const volatile NewT,
        else => @compileError("invalid type " ++ @typeName(PtrToT) ++ " given to PtrCastPreserveCV"),
    };
}

pub fn Bitfield(comptime FieldType: type, comptime shift_amount: usize, comptime num_bits: usize) type {
    if (shift_amount + num_bits > @bitSizeOf(FieldType)) {
        @compileError("bitfield doesn't fit");
    }

    const self_mask: FieldType = ((1 << num_bits) - 1) << shift_amount;

    const ValueType = std.meta.Int(.unsigned, num_bits);

    return extern struct {
        dummy: FieldType,

        const Self = @This();

        // This function uses `anytype` inorder to support both const and non-const pointers
        inline fn field(self: anytype) PtrCastPreserveCV(Self, @TypeOf(self), FieldType) {
            return @ptrCast(self);
        }

        pub fn write(self: *Self, val: ValueType) void {
            self.field().* &= ~self_mask;
            self.field().* |= @as(FieldType, @intCast(val)) << shift_amount;
        }

        pub fn read(self: Self) ValueType {
            const val: FieldType = self.field().*;
            return @intCast((val & self_mask) >> shift_amount);
        }
    };
}

test "bitfield" {
    const S = extern union {
        low: Bitfield(u32, 0, 16),
        high: Bitfield(u32, 16, 16),
        val: u32,
    };

    try std.testing.expect(@sizeOf(S) == 4);
    try std.testing.expect(@bitSizeOf(S) == 32);

    var s: S = .{ .val = 0x13376969 };

    try std.testing.expect(s.low.read() == 0x6969);
    try std.testing.expect(s.high.read() == 0x1337);

    s.low.write(0x1337);
    s.high.write(0x6969);

    try std.testing.expect(s.val == 0x69691337);
}

fn BitType(comptime FieldType: type, comptime shift_amount: usize, comptime ValueType: type) type {
    const self_bit: FieldType = (1 << shift_amount);

    return extern struct {
        bits: Bitfield(FieldType, shift_amount, 1),

        const Self = @This();

        fn set(self: *Self) void {
            self.bits.field().* |= self_bit;
        }

        fn unset(self: *Self) void {
            self.bits.field().* &= ~self_bit;
        }

        pub fn read(self: Self) ValueType {
            return @bitCast(@as(u1, @truncate(self.bits.field().* >> shift_amount)));
        }

        // Since these are mostly used with MMIO, I want to avoid
        // reading the memory just to write it again, also races
        pub fn write(self: *Self, val: ValueType) void {
            if (@as(bool, @bitCast(val))) {
                self.set();
            } else {
                self.unset();
            }
        }

        comptime {
            std.testing.refAllDecls(@This());
        }
    };
}

pub fn Bit(comptime FieldType: type, comptime shift_amount: usize) type {
    return BitType(FieldType, shift_amount, u1);
}

pub fn Boolean(comptime FieldType: type, comptime shift_amount: usize) type {
    return BitType(FieldType, shift_amount, bool);
}

test "bit" {
    const S = extern union {
        low: Bit(u32, 0),
        high: Bit(u32, 1),
        val: u32,
    };

    try std.testing.expect(@sizeOf(S) == 4);
    try std.testing.expect(@bitSizeOf(S) == 32);

    var s: S = .{ .val = 1 };

    try std.testing.expect(s.low.read() == 1);
    try std.testing.expect(s.high.read() == 0);

    s.low.write(0);
    s.high.write(1);

    try std.testing.expect(s.val == 2);
}

test "boolean" {
    const S = extern union {
        low: Boolean(u32, 0),
        high: Boolean(u32, 1),
        val: u32,
    };

    try std.testing.expect(@sizeOf(S) == 4);
    try std.testing.expect(@bitSizeOf(S) == 32);

    var s: S = .{ .val = 2 };

    try std.testing.expect(s.low.read() == false);
    try std.testing.expect(s.high.read() == true);

    s.low.write(true);
    s.high.write(false);

    try std.testing.expect(s.val == 1);
}

comptime {
    std.testing.refAllDecls(@This());
}
