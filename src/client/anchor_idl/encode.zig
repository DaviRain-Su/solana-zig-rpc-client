const std = @import("std");
const sdk = @import("../sdk.zig");
const idl_types = @import("./types.zig");

const Allocator = std.mem.Allocator;

pub const EncodeError = error{
    InvalidAnchorIdlArgsJson,
    MissingAnchorIdlArg,
    MissingAnchorIdlInstruction,
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

fn parseUnsignedAnchorIdlIntValue(comptime T: type, value: std.json.Value) !T {
    switch (value) {
        .integer => return std.math.cast(T, value.integer) orelse error.InvalidAnchorIdlArgValue,
        .string => return std.fmt.parseInt(T, value.string, 10) catch return error.InvalidAnchorIdlArgValue,
        else => return error.InvalidAnchorIdlArgValue,
    }
}

fn parseSignedAnchorIdlIntValue(comptime T: type, value: std.json.Value) !T {
    switch (value) {
        .integer => return std.math.cast(T, value.integer) orelse error.InvalidAnchorIdlArgValue,
        .string => return std.fmt.parseInt(T, value.string, 10) catch return error.InvalidAnchorIdlArgValue,
        else => return error.InvalidAnchorIdlArgValue,
    }
}

fn parseAnchorIdlFloatValue(comptime T: type, value: std.json.Value) !T {
    switch (value) {
        .integer => return @floatFromInt(value.integer),
        .float => return std.math.lossyCast(T, value.float),
        .string => return std.fmt.parseFloat(T, value.string) catch return error.InvalidAnchorIdlArgValue,
        else => return error.InvalidAnchorIdlArgValue,
    }
}

fn parseAnchorIdlPubkeyValue(value: std.json.Value) ![]const u8 {
    switch (value) {
        .string => return value.string,
        .object => {
            inline for (.{ "address", "publicKey", "public_key", "pubkey", "key", "programId", "program_id" }) |field_name| {
                if (value.object.get(field_name)) |field_value| {
                    if (field_value != .string) return error.InvalidAnchorIdlArgValue;
                    return field_value.string;
                }
            }
            return error.InvalidAnchorIdlArgValue;
        },
        else => return error.InvalidAnchorIdlArgValue,
    }
}

fn anchorJsonFieldNameMatches(expected_name: []const u8, provided_name: []const u8) bool {
    if (std.mem.eql(u8, expected_name, provided_name)) return true;
    if (expected_name.len == 0 or provided_name.len == 0) return false;

    if (expected_name.len == provided_name.len) {
        if (std.ascii.toLower(expected_name[0]) == std.ascii.toLower(provided_name[0]) and
            std.mem.eql(u8, expected_name[1..], provided_name[1..]))
        {
            return true;
        }
    }

    var expected_index: usize = 0;
    var provided_index: usize = 0;
    while (true) {
        while (expected_index < expected_name.len and expected_name[expected_index] == '_') {
            expected_index += 1;
        }
        while (provided_index < provided_name.len and provided_name[provided_index] == '_') {
            provided_index += 1;
        }

        if (expected_index == expected_name.len or provided_index == provided_name.len) break;
        if (std.ascii.toLower(expected_name[expected_index]) != std.ascii.toLower(provided_name[provided_index])) {
            return false;
        }

        expected_index += 1;
        provided_index += 1;
    }

    while (expected_index < expected_name.len and expected_name[expected_index] == '_') {
        expected_index += 1;
    }
    while (provided_index < provided_name.len and provided_name[provided_index] == '_') {
        provided_index += 1;
    }

    return expected_index == expected_name.len and provided_index == provided_name.len;
}

fn findAnchorJsonObjectField(object: std.json.ObjectMap, field_name: []const u8) ?std.json.Value {
    if (object.get(field_name)) |field_value| return field_value;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        if (!anchorJsonFieldNameMatches(field_name, entry.key_ptr.*)) continue;
        return entry.value_ptr.*;
    }

    return null;
}

fn decodeAnchorIdlBytesString(allocator: Allocator, value: []const u8) !?[]u8 {
    if (std.mem.startsWith(u8, value, "hex:")) {
        const hex_value = value[4..];
        if (hex_value.len % 2 != 0) return error.InvalidAnchorIdlArgValue;
        const decoded = try allocator.alloc(u8, hex_value.len / 2);
        _ = std.fmt.hexToBytes(decoded, hex_value) catch {
            allocator.free(decoded);
            return error.InvalidAnchorIdlArgValue;
        };
        return decoded;
    }
    if (std.mem.startsWith(u8, value, "0x")) {
        const hex_value = value[2..];
        if (hex_value.len % 2 != 0) return error.InvalidAnchorIdlArgValue;
        const decoded = try allocator.alloc(u8, hex_value.len / 2);
        _ = std.fmt.hexToBytes(decoded, hex_value) catch {
            allocator.free(decoded);
            return error.InvalidAnchorIdlArgValue;
        };
        return decoded;
    }
    if (std.mem.startsWith(u8, value, "base64:")) {
        const base64_value = value[7..];
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(base64_value) catch return error.InvalidAnchorIdlArgValue;
        const decoded = try allocator.alloc(u8, decoded_len);
        std.base64.standard.Decoder.decode(decoded, base64_value) catch {
            allocator.free(decoded);
            return error.InvalidAnchorIdlArgValue;
        };
        return decoded;
    }
    return null;
}

fn decodeAnchorIdlBytesValue(allocator: Allocator, value: std.json.Value) !?[]u8 {
    switch (value) {
        .string => return try decodeAnchorIdlBytesString(allocator, value.string),
        .object => {
            if (value.object.get("hex")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlArgValue;
                const wrapped = try std.mem.concat(allocator, u8, &.{ "hex:", field_value.string });
                defer allocator.free(wrapped);
                return try decodeAnchorIdlBytesString(allocator, wrapped);
            }
            if (value.object.get("base64")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlArgValue;
                const wrapped = try std.mem.concat(allocator, u8, &.{ "base64:", field_value.string });
                defer allocator.free(wrapped);
                return try decodeAnchorIdlBytesString(allocator, wrapped);
            }
            if (value.object.get("utf8")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlArgValue;
                return try allocator.dupe(u8, field_value.string);
            }
            return null;
        },
        else => return null,
    }
}

fn resolveAnchorIdlFieldType(field_value: std.json.Value) !std.json.Value {
    if (field_value == .object) {
        if (field_value.object.get("type")) |field_type| return field_type;
    }
    return field_value;
}

fn anchorEnumVariantNameMatches(idl_variant_name: []const u8, selected_variant_name: []const u8) bool {
    if (std.mem.eql(u8, idl_variant_name, selected_variant_name)) return true;
    if (idl_variant_name.len == 0 or selected_variant_name.len == 0) return false;

    var idl_index: usize = 0;
    var selected_index: usize = 0;
    while (true) {
        while (idl_index < idl_variant_name.len and idl_variant_name[idl_index] == '_') {
            idl_index += 1;
        }
        while (selected_index < selected_variant_name.len and selected_variant_name[selected_index] == '_') {
            selected_index += 1;
        }

        if (idl_index == idl_variant_name.len or selected_index == selected_variant_name.len) break;
        if (std.ascii.toLower(idl_variant_name[idl_index]) != std.ascii.toLower(selected_variant_name[selected_index])) {
            return false;
        }

        idl_index += 1;
        selected_index += 1;
    }

    while (idl_index < idl_variant_name.len and idl_variant_name[idl_index] == '_') {
        idl_index += 1;
    }
    while (selected_index < selected_variant_name.len and selected_variant_name[selected_index] == '_') {
        selected_index += 1;
    }

    return idl_index == idl_variant_name.len and selected_index == selected_variant_name.len;
}

fn encodeArgValue(
    allocator: Allocator,
    bytes: *std.ArrayListUnmanaged(u8),
    idl: *const idl_types.Idl,
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
            try encodeArgValue(allocator, bytes, idl, child_type, value);
            return;
        }
        if (type_spec.object.get("vec")) |child_type| {
            if (value != .array) return error.InvalidAnchorIdlArgValue;
            if (value.array.items.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
            try appendIntLittle(u32, bytes, allocator, @intCast(value.array.items.len));
            for (value.array.items) |item| {
                try encodeArgValue(allocator, bytes, idl, child_type, item);
            }
            return;
        }
        if (type_spec.object.get("defined")) |defined_value| {
            const defined_name = switch (defined_value) {
                .string => defined_value.string,
                .object => blk: {
                    const name_value = defined_value.object.get("name") orelse return error.UnsupportedAnchorIdlType;
                    if (name_value != .string) return error.UnsupportedAnchorIdlType;
                    break :blk name_value.string;
                },
                else => return error.UnsupportedAnchorIdlType,
            };
            const type_def = idl_types.findType(idl, defined_name) orelse return error.UnsupportedAnchorIdlType;
            if (type_def.type != .object) {
                try encodeArgValue(allocator, bytes, idl, type_def.type, value);
                return;
            }
            const kind_value = type_def.type.object.get("kind") orelse {
                try encodeArgValue(allocator, bytes, idl, type_def.type, value);
                return;
            };
            if (kind_value != .string) return error.UnsupportedAnchorIdlType;

            if (std.mem.eql(u8, kind_value.string, "struct")) {
                const fields_value = type_def.type.object.get("fields") orelse return error.UnsupportedAnchorIdlType;
                if (fields_value != .array) return error.UnsupportedAnchorIdlType;
                if (fields_value.array.items.len == 0) {
                    if (value != .object and value != .array) return error.InvalidAnchorIdlArgValue;
                    return;
                }

                const first_field = fields_value.array.items[0];
                if (!(first_field == .object and first_field.object.get("name") != null)) {
                    if (value != .array or value.array.items.len != fields_value.array.items.len) {
                        return error.InvalidAnchorIdlArgValue;
                    }
                    for (fields_value.array.items, value.array.items) |field_value, payload_value| {
                        try encodeArgValue(
                            allocator,
                            bytes,
                            idl,
                            try resolveAnchorIdlFieldType(field_value),
                            payload_value,
                        );
                    }
                    return;
                }

                if (value != .object) return error.InvalidAnchorIdlArgValue;
                for (fields_value.array.items) |field_value| {
                    if (field_value != .object) return error.UnsupportedAnchorIdlType;
                    const field_name = field_value.object.get("name") orelse return error.UnsupportedAnchorIdlType;
                    const field_type = field_value.object.get("type") orelse return error.UnsupportedAnchorIdlType;
                    if (field_name != .string) return error.UnsupportedAnchorIdlType;
                    const field_arg_value = findAnchorJsonObjectField(value.object, field_name.string) orelse return error.MissingAnchorIdlArg;
                    try encodeArgValue(allocator, bytes, idl, field_type, field_arg_value);
                }
                return;
            }

            if (std.mem.eql(u8, kind_value.string, "enum")) {
                const variants_value = type_def.type.object.get("variants") orelse return error.UnsupportedAnchorIdlType;
                if (variants_value != .array) return error.UnsupportedAnchorIdlType;

                var selected_variant_name: []const u8 = undefined;
                var selected_variant_payload: ?std.json.Value = null;
                switch (value) {
                    .string => selected_variant_name = value.string,
                    .object => {
                        var iterator = value.object.iterator();
                        const entry = iterator.next() orelse return error.InvalidAnchorIdlArgValue;
                        if (iterator.next() != null) return error.InvalidAnchorIdlArgValue;
                        selected_variant_name = entry.key_ptr.*;
                        selected_variant_payload = entry.value_ptr.*;
                    },
                    else => return error.InvalidAnchorIdlArgValue,
                }

                for (variants_value.array.items, 0..) |variant_value, index| {
                    if (variant_value != .object) return error.UnsupportedAnchorIdlType;
                    const variant_name = variant_value.object.get("name") orelse return error.UnsupportedAnchorIdlType;
                    if (variant_name != .string) return error.UnsupportedAnchorIdlType;
                    if (!anchorEnumVariantNameMatches(variant_name.string, selected_variant_name)) continue;

                    if (index > std.math.maxInt(u8)) return error.UnsupportedAnchorIdlType;
                    try bytes.append(allocator, @intCast(index));

                    const fields_value = variant_value.object.get("fields") orelse return;
                    if (fields_value == .null) return;
                    if (fields_value != .array) return error.UnsupportedAnchorIdlType;

                    const payload = selected_variant_payload orelse return error.InvalidAnchorIdlArgValue;
                    if (fields_value.array.items.len == 0) return;

                    const first_field = fields_value.array.items[0];
                    if (first_field == .object and first_field.object.get("name") != null) {
                        if (payload != .object) return error.InvalidAnchorIdlArgValue;
                        for (fields_value.array.items) |field_value| {
                            if (field_value != .object) return error.UnsupportedAnchorIdlType;
                            const field_name = field_value.object.get("name") orelse return error.UnsupportedAnchorIdlType;
                            const field_type = field_value.object.get("type") orelse return error.UnsupportedAnchorIdlType;
                            if (field_name != .string) return error.UnsupportedAnchorIdlType;
                            const field_arg_value = findAnchorJsonObjectField(payload.object, field_name.string) orelse return error.MissingAnchorIdlArg;
                            try encodeArgValue(allocator, bytes, idl, field_type, field_arg_value);
                        }
                        return;
                    }

                    if (payload != .array or payload.array.items.len != fields_value.array.items.len) {
                        return error.InvalidAnchorIdlArgValue;
                    }
                    for (fields_value.array.items, payload.array.items) |field_type, payload_value| {
                        try encodeArgValue(
                            allocator,
                            bytes,
                            idl,
                            try resolveAnchorIdlFieldType(field_type),
                            payload_value,
                        );
                    }
                    return;
                }

                return error.InvalidAnchorIdlArgValue;
            }

            if (std.mem.eql(u8, kind_value.string, "alias")) {
                const alias_value = type_def.type.object.get("value") orelse return error.UnsupportedAnchorIdlType;
                try encodeArgValue(allocator, bytes, idl, alias_value, value);
                return;
            }

            return error.UnsupportedAnchorIdlType;
        }

        if (type_spec.object.get("array")) |array_value| {
            const element_type, const expected_len: usize = switch (array_value) {
                .array => |items| blk: {
                    if (items.items.len != 2) return error.UnsupportedAnchorIdlType;
                    const element_type = items.items[0];
                    const len_value = items.items[1];
                    if (len_value != .integer or len_value.integer < 0) return error.InvalidAnchorIdlArgValue;
                    const len: usize = @intCast(len_value.integer);
                    break :blk .{ element_type, len };
                },
                .object => |object_value| blk: {
                    const element_type = object_value.get("type") orelse return error.UnsupportedAnchorIdlType;
                    const len_value = object_value.get("len") orelse return error.UnsupportedAnchorIdlType;
                    if (len_value != .integer or len_value.integer < 0) return error.InvalidAnchorIdlArgValue;
                    break :blk .{ element_type, @as(usize, @intCast(len_value.integer)) };
                },
                else => return error.UnsupportedAnchorIdlType,
            };

            if (value != .array) return error.InvalidAnchorIdlArgValue;
            if (value.array.items.len != expected_len) return error.InvalidAnchorIdlArgValue;

            for (value.array.items) |item| {
                try encodeArgValue(allocator, bytes, idl, element_type, item);
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
        try bytes.append(allocator, try parseUnsignedAnchorIdlIntValue(u8, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u16")) {
        try appendIntLittle(u16, bytes, allocator, try parseUnsignedAnchorIdlIntValue(u16, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u32")) {
        try appendIntLittle(u32, bytes, allocator, try parseUnsignedAnchorIdlIntValue(u32, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u64")) {
        try appendIntLittle(u64, bytes, allocator, try parseUnsignedAnchorIdlIntValue(u64, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u128")) {
        try appendIntLittle(u128, bytes, allocator, try parseUnsignedAnchorIdlIntValue(u128, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "u256")) {
        try appendIntLittle(u256, bytes, allocator, try parseUnsignedAnchorIdlIntValue(u256, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i8")) {
        try appendIntLittle(i8, bytes, allocator, try parseSignedAnchorIdlIntValue(i8, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i16")) {
        try appendIntLittle(i16, bytes, allocator, try parseSignedAnchorIdlIntValue(i16, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i32")) {
        try appendIntLittle(i32, bytes, allocator, try parseSignedAnchorIdlIntValue(i32, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i64")) {
        try appendIntLittle(i64, bytes, allocator, try parseSignedAnchorIdlIntValue(i64, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i128")) {
        try appendIntLittle(i128, bytes, allocator, try parseSignedAnchorIdlIntValue(i128, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "i256")) {
        try appendIntLittle(i256, bytes, allocator, try parseSignedAnchorIdlIntValue(i256, value));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "f32")) {
        const float_value = try parseAnchorIdlFloatValue(f32, value);
        try appendIntLittle(u32, bytes, allocator, @as(u32, @bitCast(float_value)));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "f64")) {
        const float_value = try parseAnchorIdlFloatValue(f64, value);
        try appendIntLittle(u64, bytes, allocator, @as(u64, @bitCast(float_value)));
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "string")) {
        if (value != .string) return error.InvalidAnchorIdlArgValue;
        if (value.string.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
        try appendIntLittle(u32, bytes, allocator, @intCast(value.string.len));
        try bytes.appendSlice(allocator, value.string);
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "bytes")) {
        switch (value) {
            .string => {
                if (try decodeAnchorIdlBytesValue(allocator, value)) |decoded| {
                    defer allocator.free(decoded);
                    if (decoded.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
                    try appendIntLittle(u32, bytes, allocator, @intCast(decoded.len));
                    try bytes.appendSlice(allocator, decoded);
                    return;
                }
                if (value.string.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
                try appendIntLittle(u32, bytes, allocator, @intCast(value.string.len));
                try bytes.appendSlice(allocator, value.string);
            },
            .object => {
                const decoded = try decodeAnchorIdlBytesValue(allocator, value) orelse return error.InvalidAnchorIdlArgValue;
                defer allocator.free(decoded);
                if (decoded.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
                try appendIntLittle(u32, bytes, allocator, @intCast(decoded.len));
                try bytes.appendSlice(allocator, decoded);
            },
            .array => {
                if (value.array.items.len > std.math.maxInt(u32)) return error.InvalidAnchorIdlArgValue;
                try appendIntLittle(u32, bytes, allocator, @intCast(value.array.items.len));
                for (value.array.items) |byte_value| {
                    if (byte_value != .integer or byte_value.integer < 0 or byte_value.integer > 255) return error.InvalidAnchorIdlArgValue;
                    try bytes.append(allocator, @intCast(byte_value.integer));
                }
            },
            else => return error.InvalidAnchorIdlArgValue,
        }
        return;
    }
    if (std.mem.eql(u8, type_spec.string, "pubkey") or
        std.mem.eql(u8, type_spec.string, "publicKey") or
        std.mem.eql(u8, type_spec.string, "public_key"))
    {
        const pubkey_value = try parseAnchorIdlPubkeyValue(value);
        const pubkey = sdk.Pubkey.fromBase58(allocator, pubkey_value) catch return error.InvalidAnchorIdlArgValue;
        try bytes.appendSlice(allocator, &pubkey.bytes);
        return;
    }

    return error.UnsupportedAnchorIdlType;
}

pub fn encodeInstructionDataNamed(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    args_json_source: ?[]const u8,
) ![]u8 {
    const instruction = idl_types.findInstruction(idl, instruction_name) orelse return error.MissingAnchorIdlInstruction;
    return try encodeInstructionData(allocator, idl, &instruction, args_json_source);
}

pub fn encodeInstructionDataFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    args_json_source: ?[]const u8,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try encodeInstructionDataNamed(allocator, &parsed_idl.value, instruction_name, args_json_source);
}

pub fn encodeInstructionData(
    allocator: Allocator,
    idl: *const idl_types.Idl,
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
        const arg_value = findAnchorJsonObjectField(parsed_args.value.object, arg.name) orelse return error.MissingAnchorIdlArg;
        try encodeArgValue(allocator, &bytes, idl, arg.type, arg_value);
    }

    return try allocator.dupe(u8, bytes.items);
}

test "anchor idl encodeInstructionData encodes scalar args" {
    const allocator = std.testing.allocator;
    const instruction = idl_types.Instruction{
        .name = "setConfig",
        .discriminator = &.{ 1, 2, 3, 4, 5, 6, 7, 8 },
        .args = &.{
            .{ .name = "enabled", .type = .{ .string = "bool" } },
            .{ .name = "count", .type = .{ .string = "u16" } },
            .{ .name = "label", .type = .{ .string = "string" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"enabled\":true,\"count\":513,\"label\":\"hi\"}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        1,   2,    3,    4,    5,    6,    7,    8,
        1,   0x01, 0x02, 0x02, 0x00, 0x00, 0x00, 'h',
        'i',
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
            .{ .name = "authority", .type = .{ .string = "pubkey" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(allocator, &idl, &instruction, args_json);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &pubkey.bytes, encoded[8..]);
}

test "anchor idl encodeInstructionData encodes publicKey args" {
    const allocator = std.testing.allocator;
    const pubkey = sdk.Pubkey.fromBytes(.{10} ** 32);
    const pubkey_base58 = try pubkey.toBase58(allocator);
    defer allocator.free(pubkey_base58);
    const args_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{pubkey_base58});
    defer allocator.free(args_json);

    const instruction = idl_types.Instruction{
        .name = "setAuthority",
        .discriminator = &.{ 19, 19, 19, 19, 19, 19, 19, 19 },
        .args = &.{
            .{ .name = "authority", .type = .{ .string = "publicKey" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(allocator, &idl, &instruction, args_json);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &pubkey.bytes, encoded[8..]);
}

test "anchor idl encodeInstructionData encodes public_key args" {
    const allocator = std.testing.allocator;
    const pubkey = sdk.Pubkey.fromBytes(.{11} ** 32);
    const pubkey_base58 = try pubkey.toBase58(allocator);
    defer allocator.free(pubkey_base58);
    const args_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{pubkey_base58});
    defer allocator.free(args_json);

    const instruction = idl_types.Instruction{
        .name = "setAuthority",
        .discriminator = &.{ 23, 23, 23, 23, 23, 23, 23, 23 },
        .args = &.{
            .{ .name = "authority", .type = .{ .string = "public_key" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(allocator, &idl, &instruction, args_json);
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
        .{ .name = "label", .type = option_type.value },
        .{ .name = "counts", .type = vec_type.value },
    };
    const instruction = idl_types.Instruction{
        .name = "setValues",
        .discriminator = &.{ 7, 7, 7, 7, 7, 7, 7, 7 },
        .args = &args,
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"label\":\"hi\",\"counts\":[1,513]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        7,    7,    7,    7,    7,    7,    7,    7,
        1,    0x02, 0x00, 0x00, 0x00, 'h',  'i',  0x02,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x02,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes fixed array args" {
    const allocator = std.testing.allocator;
    const array_type = try std.json.parseFromSlice(std.json.Value, allocator, "[\"u16\", 3]", .{});
    defer array_type.deinit();
    const args = [_]idl_types.IdlArg{
        .{ .name = "weights", .type = array_type.value },
    };
    const instruction = idl_types.Instruction{
        .name = "setWeights",
        .discriminator = &.{ 2, 2, 2, 2, 2, 2, 2, 2 },
        .args = &args,
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"weights\":[10,11,12]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        2,    2,    2,    2,    2,    2,    2, 2,
        0x0a, 0x00, 0x0b, 0x00, 0x0c, 0x00,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes bytes args" {
    const allocator = std.testing.allocator;
    const instruction = idl_types.Instruction{
        .name = "setBytes",
        .discriminator = &.{ 3, 3, 3, 3, 3, 3, 3, 3 },
        .args = &.{
            .{ .name = "payload", .type = .{ .string = "bytes" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"payload\":[1, 2, 3]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        3,    3,    3,    3,    3,    3,    3,    3,
        0x03, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes null option args" {
    const allocator = std.testing.allocator;
    const option_type = try std.json.parseFromSlice(std.json.Value, allocator, "{\"option\":\"u64\"}", .{});
    defer option_type.deinit();

    const args = [_]idl_types.IdlArg{
        .{ .name = "maybe_amount", .type = option_type.value },
    };
    const instruction = idl_types.Instruction{
        .name = "setAmount",
        .discriminator = &.{ 4, 4, 4, 4, 4, 4, 4, 4 },
        .args = &args,
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
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

test "anchor idl encodeInstructionData encodes string-backed u64 args" {
    const allocator = std.testing.allocator;

    const instruction = idl_types.Instruction{
        .name = "setAmount",
        .discriminator = &.{ 10, 10, 10, 10, 10, 10, 10, 10 },
        .args = &.{
            .{ .name = "amount", .type = .{ .string = "u64" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"amount\":\"18446744073709551615\"}",
    );
    defer allocator.free(encoded);

    var expected_amount: [8]u8 = undefined;
    std.mem.writeInt(u64, &expected_amount, std.math.maxInt(u64), .little);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &expected_amount, encoded[8..16]);
}

test "anchor idl encodeInstructionData encodes 128-bit integer args" {
    const allocator = std.testing.allocator;

    const big: u128 = (@as(u128, 1) << 100) + 1234;
    const delta: i128 = -((@as(i128, 1) << 100) + 4321);
    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"big\":\"{d}\",\"delta\":\"{d}\"}}",
        .{ big, delta },
    );
    defer allocator.free(args_json);

    const instruction = idl_types.Instruction{
        .name = "setWide",
        .discriminator = &.{ 11, 11, 11, 11, 11, 11, 11, 11 },
        .args = &.{
            .{ .name = "big", .type = .{ .string = "u128" } },
            .{ .name = "delta", .type = .{ .string = "i128" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(allocator, &idl, &instruction, args_json);
    defer allocator.free(encoded);

    var expected_big: [16]u8 = undefined;
    std.mem.writeInt(u128, &expected_big, big, .little);
    var expected_delta: [16]u8 = undefined;
    std.mem.writeInt(i128, &expected_delta, delta, .little);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &expected_big, encoded[8..24]);
    try std.testing.expectEqualSlices(u8, &expected_delta, encoded[24..40]);
}

test "anchor idl encodeInstructionData encodes 256-bit integer args" {
    const allocator = std.testing.allocator;

    const huge: u256 = (@as(u256, 1) << 200) + 55;
    const offset: i256 = -((@as(i256, 1) << 180) + 77);
    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"huge\":\"{d}\",\"offset\":\"{d}\"}}",
        .{ huge, offset },
    );
    defer allocator.free(args_json);

    const instruction = idl_types.Instruction{
        .name = "setHuge",
        .discriminator = &.{ 12, 12, 12, 12, 12, 12, 12, 12 },
        .args = &.{
            .{ .name = "huge", .type = .{ .string = "u256" } },
            .{ .name = "offset", .type = .{ .string = "i256" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(allocator, &idl, &instruction, args_json);
    defer allocator.free(encoded);

    var expected_huge: [32]u8 = undefined;
    std.mem.writeInt(u256, &expected_huge, huge, .little);
    var expected_offset: [32]u8 = undefined;
    std.mem.writeInt(i256, &expected_offset, offset, .little);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &expected_huge, encoded[8..40]);
    try std.testing.expectEqualSlices(u8, &expected_offset, encoded[40..72]);
}

test "anchor idl encodeInstructionData encodes float args" {
    const allocator = std.testing.allocator;

    const instruction = idl_types.Instruction{
        .name = "setFloat",
        .discriminator = &.{ 13, 13, 13, 13, 13, 13, 13, 13 },
        .args = &.{
            .{ .name = "price", .type = .{ .string = "f32" } },
            .{ .name = "ratio", .type = .{ .string = "f64" } },
        },
    };
    const idl = idl_types.Idl{
        .instructions = &.{instruction},
    };

    const encoded = try encodeInstructionData(
        allocator,
        &idl,
        &instruction,
        "{\"price\":1.5,\"ratio\":-2.25}",
    );
    defer allocator.free(encoded);

    var expected_price: [4]u8 = undefined;
    std.mem.writeInt(u32, &expected_price, @as(u32, @bitCast(@as(f32, 1.5))), .little);
    var expected_ratio: [8]u8 = undefined;
    std.mem.writeInt(u64, &expected_ratio, @as(u64, @bitCast(@as(f64, -2.25))), .little);

    try std.testing.expectEqualSlices(u8, instruction.discriminator, encoded[0..8]);
    try std.testing.expectEqualSlices(u8, &expected_price, encoded[8..12]);
    try std.testing.expectEqualSlices(u8, &expected_ratio, encoded[12..20]);
}

test "anchor idl encodeInstructionData encodes defined alias args" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setAlias","discriminator":[15,15,15,15,15,15,15,15],"args":[{"name":"weights","type":{"defined":{"name":"U8Pair"}}}]}],"types":[{"name":"U8Pair","type":{"kind":"alias","value":{"array":["u8",2]}}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setAlias").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"weights\":[7,9]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        15, 15, 15, 15, 15, 15, 15, 15,
        7,  9,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes defined tuple struct args" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setTuple","discriminator":[16,16,16,16,16,16,16,16],"args":[{"name":"pair","type":{"defined":{"name":"Pair"}}}]}],"types":[{"name":"Pair","type":{"kind":"struct","fields":["u8","u16"]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setTuple").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"pair\":[7,1025]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        16, 16,   16,   16, 16, 16, 16, 16,
        7,  0x01, 0x04,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes defined legacy alias args" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setAlias","discriminator":[18,18,18,18,18,18,18,18],"args":[{"name":"count","type":{"defined":{"name":"Counter"}}},{"name":"pair","type":{"defined":{"name":"Pair"}}}]}],"types":[{"name":"Counter","type":"u64"},{"name":"Pair","type":{"array":["u8",2]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setAlias").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"count\":\"99\",\"pair\":[7,9]}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        18, 18, 18, 18, 18, 18, 18, 18,
        99, 0,  0,  0,  0,  0,  0,  0,
        7,  9,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes defined struct args" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setConfig","discriminator":[6,6,6,6,6,6,6,6],"args":[{"name":"config","type":{"defined":{"name":"Config"}}}]}],"types":[{"name":"Config","type":{"kind":"struct","fields":[{"name":"enabled","type":"bool"},{"name":"count","type":"u16"}]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setConfig").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"config\":{\"enabled\":true,\"count\":513}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        6, 6,    6,    6, 6, 6, 6, 6,
        1, 0x01, 0x02,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes defined enum args" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setMode","discriminator":[8,8,8,8,8,8,8,8],"args":[{"name":"state","type":{"defined":{"name":"State"}}},{"name":"threshold","type":{"defined":{"name":"Threshold"}}},{"name":"pair","type":{"defined":{"name":"Pair"}}}]}],"types":[{"name":"State","type":{"kind":"enum","variants":[{"name":"Ready"},{"name":"Paused"}]}},{"name":"Threshold","type":{"kind":"enum","variants":[{"name":"Fixed","fields":[{"name":"value","type":"u16"}]},{"name":"Open"}]}},{"name":"Pair","type":{"kind":"enum","variants":[{"name":"Values","fields":["u8","u16"]}]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setMode").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"state\":\"Paused\",\"threshold\":{\"Fixed\":{\"value\":513}},\"pair\":{\"Values\":[7,1025]}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        8, 8, 8,    8,    8, 8, 8,    8,
        1, 0, 0x01, 0x02, 0, 7, 0x01, 0x04,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData accepts lowerCamel enum variants" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setMode","discriminator":[14,14,14,14,14,14,14,14],"args":[{"name":"state","type":{"defined":{"name":"State"}}},{"name":"threshold","type":{"defined":{"name":"Threshold"}}},{"name":"pair","type":{"defined":{"name":"Pair"}}}]}],"types":[{"name":"State","type":{"kind":"enum","variants":[{"name":"Ready"},{"name":"Paused"}]}},{"name":"Threshold","type":{"kind":"enum","variants":[{"name":"Fixed","fields":[{"name":"value","type":"u16"}]},{"name":"Open"}]}},{"name":"Pair","type":{"kind":"enum","variants":[{"name":"Values","fields":["u8","u16"]}]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setMode").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"state\":{\"paused\":{}},\"threshold\":{\"fixed\":{\"value\":513}},\"pair\":{\"values\":[7,1025]}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        14, 14, 14,   14,   14, 14, 14,   14,
        1,  0,  0x01, 0x02, 0,  7,  0x01, 0x04,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData accepts snake_case enum variants" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setMode","discriminator":[17,17,17,17,17,17,17,17],"args":[{"name":"mode","type":{"defined":{"name":"Mode"}}}]}],"types":[{"name":"Mode","type":{"kind":"enum","variants":[{"name":"FixedValue","fields":[{"name":"value","type":"u16"}]},{"name":"OpenValue"}]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setMode").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"mode\":{\"fixed_value\":{\"value\":513}}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{ 17, 17, 17, 17, 17, 17, 17, 17, 0, 1, 2 };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes tuple enum variant field objects" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setMode","discriminator":[17,17,17,17,17,17,17,17],"args":[{"name":"pair","type":{"defined":{"name":"Pair"}}}]}],"types":[{"name":"Pair","type":{"kind":"enum","variants":[{"name":"Values","fields":[{"type":"u8"},{"type":"u16"}]}]}}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setMode").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"pair\":{\"Values\":[7,1025]}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        17, 17, 17,   17,   17, 17, 17, 17,
        0,  7,  0x01, 0x04,
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData encodes bytes object wrappers" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setDigest","discriminator":[19,19,19,19,19,19,19,19],"args":[{"name":"hexDigest","type":"bytes"},{"name":"base64Digest","type":"bytes"},{"name":"utf8Digest","type":"bytes"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setDigest").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        "{\"hexDigest\":{\"hex\":\"010203\"},\"base64Digest\":{\"base64\":\"BAUG\"},\"utf8Digest\":{\"utf8\":\"hi\"}}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{
        19, 19, 19,  19,  19, 19, 19, 19,
        3,  0,  0,   0,   1,  2,  3,  3,
        0,  0,  0,   4,   5,  6,  2,  0,
        0,  0,  'h', 'i',
    };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "anchor idl encodeInstructionData accepts pubkey object wrappers" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setAuthority","discriminator":[20,20,20,20,20,20,20,20],"args":[{"name":"authority","type":"publicKey"},{"name":"program","type":"publicKey"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const authority = sdk.Pubkey.fromBytes(.{11} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const program = sdk.Pubkey.fromBytes(.{12} ** 32);
    const program_base58 = try program.toBase58(allocator);
    defer allocator.free(program_base58);
    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":{{\"address\":\"{s}\"}},\"program\":{{\"programId\":\"{s}\"}}}}",
        .{ authority_base58, program_base58 },
    );
    defer allocator.free(args_json);

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setAuthority").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        args_json,
    );
    defer allocator.free(encoded);

    var expected = std.ArrayListUnmanaged(u8){};
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, &.{ 20, 20, 20, 20, 20, 20, 20, 20 });
    try expected.appendSlice(allocator, &authority.bytes);
    try expected.appendSlice(allocator, &program.bytes);

    try std.testing.expectEqualSlices(u8, expected.items, encoded);
}

test "anchor idl encodeInstructionData accepts public_key object wrapper" {
    const allocator = std.testing.allocator;
    const parsed_idl = try std.json.parseFromSlice(
        idl_types.Idl,
        allocator,
        \\{"instructions":[{"name":"setAuthority","discriminator":[21,21,21,21,21,21,21,21],"args":[{"name":"authority","type":"publicKey"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed_idl.deinit();

    const authority = sdk.Pubkey.fromBytes(.{13} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":{{\"public_key\":\"{s}\"}}}}",
        .{authority_base58},
    );
    defer allocator.free(args_json);

    const instruction = idl_types.findInstruction(&parsed_idl.value, "setAuthority").?;
    const encoded = try encodeInstructionData(
        allocator,
        &parsed_idl.value,
        &instruction,
        args_json,
    );
    defer allocator.free(encoded);

    var expected = std.ArrayListUnmanaged(u8){};
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, &.{ 21, 21, 21, 21, 21, 21, 21, 21 });
    try expected.appendSlice(allocator, &authority.bytes);

    try std.testing.expectEqualSlices(u8, expected.items, encoded);
}
