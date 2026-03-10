const std = @import("std");
const sdk = @import("../sdk.zig");
const idl_types = @import("./types.zig");

const Allocator = std.mem.Allocator;

pub const EncodeError = error{
    InvalidAnchorIdlArgsJson,
    MissingAnchorIdlArg,
    UnsupportedAnchorIdlType,
    InvalidAnchorIdlArgValue,
};

fn appendIntLittle(
    comptime T: type,
    bytes: *std.ArrayListUnmanaged(u8),
    allocator: Allocator,
    value: T,
) !void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, value, .little);
    try bytes.appendSlice(allocator, &encoded);
}

fn encodeArgValue(
    allocator: Allocator,
    bytes: *std.ArrayListUnmanaged(u8),
    type_spec: std.json.Value,
    value: std.json.Value,
) !void {
    if (type_spec == .object) {
        if (type_spec.object.get("option")) |child_type| {
            if (value == .null) {
                try bytes.append(allocator, 0);
                return;
            }
            try bytes.append(allocator, 1);
            try encodeArgValue(allocator, bytes, child_type, value);
            return;
        }
        if (type_spec.object.get("vec")) |child_type| {
            if (value != .array) return error.InvalidAnchorIdlArgValue;
            if (value.array.items.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
            try appendIntLittle(u32, bytes, allocator, @intCast(value.array.items.len));
            for (value.array.items) |item| {
                try encodeArgValue(allocator, bytes, child_type, item);
            }
            return;
        }
    }

    if (type_spec != .string) return error.UnsupportedAnchorIdlType;

    if (std.mem.eql(u8, type_spec.string, "bool")) {
        if (value != .bool) return error.InvalidAnchorIdlArgValue;
        try bytes.append(allocator, if (value.bool) 1 else 0);
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u8")) {
        if (value != .integer or value.integer < 0 or value.integer > std.math.maxInt(u8)) return error.InvalidAnchorIdlArgValue;
        try bytes.append(allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u16")) {
        if (value != .integer or value.integer < 0 or value.integer > std.math.maxInt(u16)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(u16, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u32")) {
        if (value != .integer or value.integer < 0 or value.integer > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(u32, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u64")) {
        if (value != .integer or value.integer < 0) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(u64, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i8")) {
        if (value != .integer or value.integer < std.math.minInt(i8) or value.integer > std.math.maxInt(i8)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(i8, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i16")) {
        if (value != .integer or value.integer < std.math.minInt(i16) or value.integer > std.math.maxInt(i16)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(i16, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i32")) {
        if (value != .integer or value.integer < std.math.minInt(i32) or value.integer > std.math.maxInt(i32)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(i32, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i64")) {
        if (value != .integer) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(i64, bytes, allocator, @intCast(value.integer));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "string")) {
        if (value != .string) return error.InvalidAnchorIdlArgValue;
        if (value.string.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(u32, bytes, allocator, @intCast(value.string.len));
        try bytes.appendSlice(allocator, value.string);
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "pubkey")) {
        if (value != .string) return error.InvalidAnchorIdlArgValue;
        const pubkey = sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidAnchorIdlArgValue;
        try bytes.appendSlice(allocator, &pubkey.bytes);
        return;
    }

    return error.UnsupportedAnchorIdlType;
}

pub fn encodeInstructionData(
    allocator: Allocator,
    instruction: *const idl_types.Instruction,
    args_json_source: ?[]const u8,
) ![]u8 {
    var bytes: std.ArrayListUnmanaged(u8) = .{};
    defer bytes.deinit(allocator);

    try bytes.appendSlice(allocator, instruction.discriminator);
    if (instruction.args.len == 0) return try allocator.dupe(u8, bytes.items);

    const source = args_json_source orelse return error.MissingAnchorIdlArg;
    const parsed_args = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return error.InvalidAnchorIdlArgsJson;
    defer parsed_args.deinit();
    if (parsed_args.value != .object) return error.InvalidAnchorIdlArgsJson;

    for (instruction.args) |arg| {
        const arg_value = parsed_args.value.object.get(arg.name) orelse return error.MissingAnchorIdlArg;
        try encodeArgValue(allocator, &bytes, arg.@"type", arg_value);
    }

    return try allocator.dupe(u8, bytes.items);
}

test "anchor idl encodeInstructionData encodes scalar args" {
    const allocator = std.testing.allocator;
    const instruction = idl_types.Instruction{
        .name = "setConfig",
        .discriminator = &.{ 1, 2, 3, 4, 5, 6, 7, 8 },
        .args = &.{
            .{ .name = "enabled", .@"type" = .{ .string = "bool" } },
            .{ .name = "count", .@"type" = .{ .string = "u16" } },
            .{ .name = "label", .@"type" = .{ .string = "string" } },
        },
    };

    const encoded = try encodeInstructionData(
        allocator,
        &instruction,
        "{\"enabled\":true,\"count\":513,\"label\":\"hi\"}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        1, 2, 3, 4, 5, 6, 7, 8,
        1,
        0x01, 0x02,
        0x02, 0x00, 0x00, 0x00,
        'h', 'i',
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes pubkey args" {
    const allocator = std.testing.allocator;
    const pubkey = sdk.Pubkey.fromBytes(.{9} ** 32);
    const pubkey_base58 = try pubkey.toBase58(allocator);
    defer allocator.free(pubkey_base58);
    const args_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{pubkey_base58});
    defer allocator.free(args_json);

    const instruction = idl_types.Instruction{
        .name = "setAuthority",
        .discriminator = &.{ 9, 8, 7, 6, 5, 4, 3, 2 },
        .args = &.{
            .{ .name = "authority", .@"type" = .{ .string = "pubkey" } },
        },
    };

    const encoded = try encodeInstructionData(allocator, &instruction, args_json);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &pubkey.bytes, encoded[8..]);
}

test "anchor idl encodeInstructionData encodes option and vec args" {
    const allocator = std.testing.allocator;
    const option_type = try std.json.parseFromSlice(std.json.Value, allocator, "{\"option\":\"string\"}", .{});
    defer option_type.deinit();
    const vec_type = try std.json.parseFromSlice(std.json.Value, allocator, "{\"vec\":\"u16\"}", .{});
    defer vec_type.deinit();

    const args = [_]idl_types.IdlArg{
        .{ .name = "label", .@"type" = option_type.value },
        .{ .name = "counts", .@"type" = vec_type.value },
    };
    const instruction = idl_types.Instruction{
        .name = "setValues",
        .discriminator = &.{ 7, 7, 7, 7, 7, 7, 7, 7 },
        .args = &args,
    };

    const encoded = try encodeInstructionData(
        allocator,
        &instruction,
        "{\"label\":\"hi\",\"counts\":[1,513]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        7, 7, 7, 7, 7, 7, 7, 7,
        1,
        0x02, 0x00, 0x00, 0x00,
        'h', 'i',
        0x02, 0x00, 0x00, 0x00,
        0x01, 0x00,
        0x01, 0x02,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes null option args" {
    const allocator = std.testing.allocator;
    const option_type = try std.json.parseFromSlice(std.json.Value, allocator, "{\"option\":\"u64\"}", .{});
    defer option_type.deinit();

    const args = [_]idl_types.IdlArg{
        .{ .name = "maybe_amount", .@"type" = option_type.value },
    };
    const instruction = idl_types.Instruction{
        .name = "setAmount",
        .discriminator = &.{ 4, 4, 4, 4, 4, 4, 4, 4 },
        .args = &args,
    };

    const encoded = try encodeInstructionData(
        allocator,
        &instruction,
        "{\"maybe_amount\":null}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        4, 4, 4, 4, 4, 4, 4, 4,
        0,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}
