const std = @import("std");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const SchemaEncoding = enum {
    borsh,
};

pub const EncodeError = Allocator.Error || error{
    InvalidInstructionSchema,
    InvalidHexData,
    InvalidBase64Data,
};

fn isBuiltinSchemaType(name: []const u8) bool {
    return std.mem.eql(u8, name, "bool") or
        std.mem.eql(u8, name, "u8") or
        std.mem.eql(u8, name, "u16") or
        std.mem.eql(u8, name, "u32") or
        std.mem.eql(u8, name, "u64") or
        std.mem.eql(u8, name, "u128") or
        std.mem.eql(u8, name, "i8") or
        std.mem.eql(u8, name, "i16") or
        std.mem.eql(u8, name, "i32") or
        std.mem.eql(u8, name, "i64") or
        std.mem.eql(u8, name, "i128") or
        std.mem.eql(u8, name, "f32") or
        std.mem.eql(u8, name, "f64") or
        std.mem.eql(u8, name, "string") or
        std.mem.eql(u8, name, "bytes") or
        std.mem.eql(u8, name, "pubkey") or
        std.mem.eql(u8, name, "option") or
        std.mem.eql(u8, name, "array") or
        std.mem.eql(u8, name, "vec") or
        std.mem.eql(u8, name, "tuple") or
        std.mem.eql(u8, name, "struct") or
        std.mem.eql(u8, name, "enum");
}

fn findJsonObjectField(object: std.json.ObjectMap, comptime names: []const []const u8) ?std.json.Value {
    inline for (names) |name| {
        if (object.get(name)) |value| return value;
    }
    return null;
}

fn parseJsonBool(value: std.json.Value) EncodeError!bool {
    return switch (value) {
        .bool => value.bool,
        else => error.InvalidInstructionSchema,
    };
}

fn parseJsonPubkey(allocator: Allocator, value: std.json.Value) EncodeError!sdk.Pubkey {
    return switch (value) {
        .string => sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidInstructionSchema,
        else => error.InvalidInstructionSchema,
    };
}

fn decodeInstructionData(
    allocator: Allocator,
    encoded: []const u8,
    comptime encoding: enum { base64, hex, utf8 },
) EncodeError![]u8 {
    return switch (encoding) {
        .utf8 => try allocator.dupe(u8, encoded),
        .base64 => blk: {
            const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.InvalidBase64Data;
            const decoded = try allocator.alloc(u8, decoded_len);
            errdefer allocator.free(decoded);
            std.base64.standard.Decoder.decode(decoded, encoded) catch return error.InvalidBase64Data;
            break :blk decoded;
        },
        .hex => blk: {
            const hex_value = if (std.mem.startsWith(u8, encoded, "0x") or std.mem.startsWith(u8, encoded, "0X"))
                encoded[2..]
            else
                encoded;
            if (hex_value.len % 2 != 0) return error.InvalidHexData;
            const decoded = try allocator.alloc(u8, hex_value.len / 2);
            errdefer allocator.free(decoded);
            _ = std.fmt.hexToBytes(decoded, hex_value) catch return error.InvalidHexData;
            break :blk decoded;
        },
    };
}

pub fn parseSchemaEncoding(value: []const u8) EncodeError!SchemaEncoding {
    if (std.mem.eql(u8, value, "borsh")) return .borsh;
    return error.InvalidInstructionSchema;
}

fn parseSchemaUnsigned(comptime T: type, value: std.json.Value) EncodeError!T {
    return switch (value) {
        .integer => {
            if (value.integer < 0) return error.InvalidInstructionSchema;
            return std.math.cast(T, value.integer) orelse return error.InvalidInstructionSchema;
        },
        .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidInstructionSchema,
        else => error.InvalidInstructionSchema,
    };
}

fn parseSchemaSigned(comptime T: type, value: std.json.Value) EncodeError!T {
    return switch (value) {
        .integer => std.math.cast(T, value.integer) orelse return error.InvalidInstructionSchema,
        .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidInstructionSchema,
        else => error.InvalidInstructionSchema,
    };
}

fn parseSchemaFloat(comptime T: type, value: std.json.Value) EncodeError!T {
    return switch (value) {
        .integer => @as(T, @floatFromInt(value.integer)),
        .float => @as(T, @floatCast(value.float)),
        .string => std.fmt.parseFloat(T, value.string) catch return error.InvalidInstructionSchema,
        else => error.InvalidInstructionSchema,
    };
}

fn appendLittleEndianInt(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    comptime T: type,
    value: T,
) EncodeError!void {
    var buffer: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buffer, value, .little);
    try output.appendSlice(allocator, &buffer);
}

fn appendLengthPrefixedBytes(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    bytes: []const u8,
) EncodeError!void {
    const len = std.math.cast(u32, bytes.len) orelse return error.InvalidInstructionSchema;
    try appendLittleEndianInt(allocator, output, u32, len);
    try output.appendSlice(allocator, bytes);
}

fn decodeSchemaBytesValue(
    allocator: Allocator,
    value: std.json.Value,
) EncodeError![]u8 {
    return switch (value) {
        .array => blk: {
            const decoded = try allocator.alloc(u8, value.array.items.len);
            errdefer allocator.free(decoded);
            for (value.array.items, 0..) |item, index| {
                decoded[index] = try parseSchemaUnsigned(u8, item);
            }
            break :blk decoded;
        },
        .string => blk: {
            if (std.mem.startsWith(u8, value.string, "base64:")) {
                break :blk try decodeInstructionData(allocator, value.string["base64:".len..], .base64);
            }
            if (std.mem.startsWith(u8, value.string, "hex:")) {
                break :blk try decodeInstructionData(allocator, value.string["hex:".len..], .hex);
            }
            if (std.mem.startsWith(u8, value.string, "0x") or std.mem.startsWith(u8, value.string, "0X")) {
                break :blk try decodeInstructionData(allocator, value.string, .hex);
            }
            if (std.mem.startsWith(u8, value.string, "utf8:")) {
                break :blk try decodeInstructionData(allocator, value.string["utf8:".len..], .utf8);
            }
            break :blk try allocator.dupe(u8, value.string);
        },
        .object => blk: {
            if (findJsonObjectField(value.object, &.{"bytes"})) |field| {
                break :blk try decodeSchemaBytesValue(allocator, field);
            }
            if (findJsonObjectField(value.object, &.{"base64"})) |field| {
                if (field != .string) return error.InvalidInstructionSchema;
                break :blk try decodeInstructionData(allocator, field.string, .base64);
            }
            if (findJsonObjectField(value.object, &.{"hex"})) |field| {
                if (field != .string) return error.InvalidInstructionSchema;
                break :blk try decodeInstructionData(allocator, field.string, .hex);
            }
            if (findJsonObjectField(value.object, &.{"utf8"})) |field| {
                if (field != .string) return error.InvalidInstructionSchema;
                break :blk try decodeInstructionData(allocator, field.string, .utf8);
            }
            return error.InvalidInstructionSchema;
        },
        else => error.InvalidInstructionSchema,
    };
}

fn schemaTypeName(schema: std.json.Value) ?[]const u8 {
    return switch (schema) {
        .string => schema.string,
        .object => if (findJsonObjectField(schema.object, &.{"type"})) |value|
            switch (value) {
                .string => value.string,
                else => null,
            }
        else if (findJsonObjectField(schema.object, &.{"fields"})) |_|
            "struct"
        else
            null,
        else => null,
    };
}

fn lookupSchemaDefinition(
    scope: std.json.Value,
    name: []const u8,
) ?std.json.Value {
    if (scope != .object) return null;

    const definitions_value = findJsonObjectField(scope.object, &.{ "definitions", "defs", "types" }) orelse return null;
    return switch (definitions_value) {
        .object => definitions_value.object.get(name),
        .array => blk: {
            for (definitions_value.array.items) |item| {
                if (item != .object) continue;
                const item_name_value = findJsonObjectField(item.object, &.{"name"}) orelse continue;
                if (item_name_value != .string) continue;
                if (!std.mem.eql(u8, item_name_value.string, name)) continue;
                break :blk findJsonObjectField(item.object, &.{"type"}) orelse item;
            }
            break :blk null;
        },
        else => null,
    };
}

fn resolveSchemaValue(
    root_schema: std.json.Value,
    schema: std.json.Value,
) EncodeError!std.json.Value {
    var current = schema;
    var depth: usize = 0;
    while (depth < 32) : (depth += 1) {
        switch (current) {
            .string => {
                if (isBuiltinSchemaType(current.string)) return current;
                current = lookupSchemaDefinition(root_schema, current.string) orelse return error.InvalidInstructionSchema;
            },
            .object => {
                if (findJsonObjectField(current.object, &.{ "defined", "ref" })) |definition_name_value| {
                    if (definition_name_value != .string) return error.InvalidInstructionSchema;
                    current = lookupSchemaDefinition(current, definition_name_value.string) orelse
                        lookupSchemaDefinition(root_schema, definition_name_value.string) orelse
                        return error.InvalidInstructionSchema;
                    continue;
                }

                if (findJsonObjectField(current.object, &.{"type"})) |type_value| {
                    if (type_value == .string and !isBuiltinSchemaType(type_value.string)) {
                        current = lookupSchemaDefinition(current, type_value.string) orelse
                            lookupSchemaDefinition(root_schema, type_value.string) orelse
                            return error.InvalidInstructionSchema;
                        continue;
                    }
                }

                return current;
            },
            else => return current,
        }
    }

    return error.InvalidInstructionSchema;
}

fn parseEnumInput(
    value: std.json.Value,
) EncodeError!struct {
    name: []const u8,
    payload: ?std.json.Value,
} {
    return switch (value) {
        .string => .{ .name = value.string, .payload = null },
        .object => blk: {
            if (findJsonObjectField(value.object, &.{"variant"})) |variant_value| {
                if (variant_value != .string) return error.InvalidInstructionSchema;
                break :blk .{
                    .name = variant_value.string,
                    .payload = value.object.get("value"),
                };
            }

            if (value.object.count() != 1) return error.InvalidInstructionSchema;
            var iterator = value.object.iterator();
            const entry = iterator.next() orelse return error.InvalidInstructionSchema;
            break :blk .{
                .name = entry.key_ptr.*,
                .payload = entry.value_ptr.*,
            };
        },
        else => error.InvalidInstructionSchema,
    };
}

fn isNamedStructField(field_value: std.json.Value) bool {
    return switch (field_value) {
        .object => findJsonObjectField(field_value.object, &.{"name"}) != null,
        else => false,
    };
}

fn schemaIsU8(root_schema: std.json.Value, schema: std.json.Value) EncodeError!bool {
    const resolved_schema = try resolveSchemaValue(root_schema, schema);
    const type_name = schemaTypeName(resolved_schema) orelse return error.InvalidInstructionSchema;
    return std.mem.eql(u8, type_name, "u8");
}

fn maybeDecodeByteSequenceValue(
    allocator: Allocator,
    root_schema: std.json.Value,
    schema: std.json.Value,
    value: std.json.Value,
) EncodeError!?[]u8 {
    if (!(try schemaIsU8(root_schema, schema))) return null;
    return switch (value) {
        .array => null,
        else => try decodeSchemaBytesValue(allocator, value),
    };
}

fn encodeBorshSchemaValue(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    root_schema: std.json.Value,
    schema: std.json.Value,
    value: std.json.Value,
) EncodeError!void {
    const resolved_schema = try resolveSchemaValue(root_schema, schema);
    const type_name = schemaTypeName(resolved_schema) orelse return error.InvalidInstructionSchema;

    if (std.mem.eql(u8, type_name, "bool")) {
        try output.append(allocator, if (try parseJsonBool(value)) 1 else 0);
        return;
    }
    if (std.mem.eql(u8, type_name, "u8")) {
        try output.append(allocator, try parseSchemaUnsigned(u8, value));
        return;
    }
    if (std.mem.eql(u8, type_name, "u16")) {
        try appendLittleEndianInt(allocator, output, u16, try parseSchemaUnsigned(u16, value));
        return;
    }
    if (std.mem.eql(u8, type_name, "u32")) {
        try appendLittleEndianInt(allocator, output, u32, try parseSchemaUnsigned(u32, value));
        return;
    }
    if (std.mem.eql(u8, type_name, "u64")) {
        try appendLittleEndianInt(allocator, output, u64, try parseSchemaUnsigned(u64, value));
        return;
    }
    if (std.mem.eql(u8, type_name, "u128")) {
        try appendLittleEndianInt(allocator, output, u128, try parseSchemaUnsigned(u128, value));
        return;
    }
    if (std.mem.eql(u8, type_name, "i8")) {
        const signed_value = try parseSchemaSigned(i8, value);
        try output.append(allocator, @as(u8, @bitCast(signed_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "i16")) {
        const signed_value = try parseSchemaSigned(i16, value);
        try appendLittleEndianInt(allocator, output, u16, @as(u16, @bitCast(signed_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "i32")) {
        const signed_value = try parseSchemaSigned(i32, value);
        try appendLittleEndianInt(allocator, output, u32, @as(u32, @bitCast(signed_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "i64")) {
        const signed_value = try parseSchemaSigned(i64, value);
        try appendLittleEndianInt(allocator, output, u64, @as(u64, @bitCast(signed_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "i128")) {
        const signed_value = try parseSchemaSigned(i128, value);
        try appendLittleEndianInt(allocator, output, u128, @as(u128, @bitCast(signed_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "f32")) {
        const float_value = try parseSchemaFloat(f32, value);
        try appendLittleEndianInt(allocator, output, u32, @as(u32, @bitCast(float_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "f64")) {
        const float_value = try parseSchemaFloat(f64, value);
        try appendLittleEndianInt(allocator, output, u64, @as(u64, @bitCast(float_value)));
        return;
    }
    if (std.mem.eql(u8, type_name, "string")) {
        if (value != .string) return error.InvalidInstructionSchema;
        try appendLengthPrefixedBytes(allocator, output, value.string);
        return;
    }
    if (std.mem.eql(u8, type_name, "bytes")) {
        const bytes = try decodeSchemaBytesValue(allocator, value);
        defer allocator.free(bytes);
        try appendLengthPrefixedBytes(allocator, output, bytes);
        return;
    }
    if (std.mem.eql(u8, type_name, "pubkey")) {
        const pubkey = try parseJsonPubkey(allocator, value);
        try output.appendSlice(allocator, &pubkey.bytes);
        return;
    }

    if (resolved_schema != .object) return error.InvalidInstructionSchema;

    if (std.mem.eql(u8, type_name, "option")) {
        const item_schema = findJsonObjectField(resolved_schema.object, &.{"item"}) orelse return error.InvalidInstructionSchema;
        if (value == .null) {
            try output.append(allocator, 0);
            return;
        }
        try output.append(allocator, 1);
        try encodeBorshSchemaValue(allocator, output, root_schema, item_schema, value);
        return;
    }

    if (std.mem.eql(u8, type_name, "array")) {
        const item_schema = findJsonObjectField(resolved_schema.object, &.{"item"}) orelse return error.InvalidInstructionSchema;
        const len_value = findJsonObjectField(resolved_schema.object, &.{"len"}) orelse return error.InvalidInstructionSchema;
        const expected_len = try parseSchemaUnsigned(usize, len_value);
        if (try maybeDecodeByteSequenceValue(allocator, root_schema, item_schema, value)) |bytes| {
            defer allocator.free(bytes);
            if (bytes.len != expected_len) return error.InvalidInstructionSchema;
            try output.appendSlice(allocator, bytes);
            return;
        }
        if (value != .array) return error.InvalidInstructionSchema;
        if (value.array.items.len != expected_len) return error.InvalidInstructionSchema;
        for (value.array.items) |item| {
            try encodeBorshSchemaValue(allocator, output, root_schema, item_schema, item);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "vec")) {
        const item_schema = findJsonObjectField(resolved_schema.object, &.{"item"}) orelse return error.InvalidInstructionSchema;
        if (try maybeDecodeByteSequenceValue(allocator, root_schema, item_schema, value)) |bytes| {
            defer allocator.free(bytes);
            try appendLengthPrefixedBytes(allocator, output, bytes);
            return;
        }
        if (value != .array) return error.InvalidInstructionSchema;
        const item_len = std.math.cast(u32, value.array.items.len) orelse return error.InvalidInstructionSchema;
        try appendLittleEndianInt(allocator, output, u32, item_len);
        for (value.array.items) |item| {
            try encodeBorshSchemaValue(allocator, output, root_schema, item_schema, item);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "tuple")) {
        const items_value = findJsonObjectField(resolved_schema.object, &.{"items"}) orelse return error.InvalidInstructionSchema;
        if (items_value != .array or value != .array) return error.InvalidInstructionSchema;
        if (items_value.array.items.len != value.array.items.len) return error.InvalidInstructionSchema;
        for (items_value.array.items, value.array.items) |item_schema, item_value| {
            try encodeBorshSchemaValue(allocator, output, root_schema, item_schema, item_value);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "struct")) {
        const fields_value = findJsonObjectField(resolved_schema.object, &.{"fields"}) orelse return error.InvalidInstructionSchema;
        if (fields_value != .array) return error.InvalidInstructionSchema;

        const uses_named_fields = for (fields_value.array.items) |field_value| {
            break isNamedStructField(field_value);
        } else false;

        if (uses_named_fields) {
            if (value != .object) return error.InvalidInstructionSchema;
            for (fields_value.array.items) |field_value| {
                if (field_value != .object) return error.InvalidInstructionSchema;
                const field_name_value = findJsonObjectField(field_value.object, &.{"name"}) orelse return error.InvalidInstructionSchema;
                if (field_name_value != .string) return error.InvalidInstructionSchema;
                const field_schema = findJsonObjectField(field_value.object, &.{"type"}) orelse field_value;
                const field_arg = value.object.get(field_name_value.string) orelse return error.InvalidInstructionSchema;
                try encodeBorshSchemaValue(allocator, output, root_schema, field_schema, field_arg);
            }
            return;
        }

        if (value != .array or value.array.items.len != fields_value.array.items.len) return error.InvalidInstructionSchema;
        for (fields_value.array.items, value.array.items) |field_schema, field_arg| {
            try encodeBorshSchemaValue(allocator, output, root_schema, field_schema, field_arg);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "enum")) {
        const variants_value = findJsonObjectField(resolved_schema.object, &.{"variants"}) orelse return error.InvalidInstructionSchema;
        if (variants_value != .array) return error.InvalidInstructionSchema;

        const input = try parseEnumInput(value);
        for (variants_value.array.items, 0..) |variant_value, index| {
            if (variant_value != .object) return error.InvalidInstructionSchema;
            const variant_name_value = findJsonObjectField(variant_value.object, &.{"name"}) orelse return error.InvalidInstructionSchema;
            if (variant_name_value != .string) return error.InvalidInstructionSchema;
            if (!std.mem.eql(u8, variant_name_value.string, input.name)) continue;

            const discriminant = std.math.cast(u8, index) orelse return error.InvalidInstructionSchema;
            try output.append(allocator, discriminant);

            const inline_schema = findJsonObjectField(variant_value.object, &.{"type"});
            const fields_schema = findJsonObjectField(variant_value.object, &.{"fields"});
            if (inline_schema == null and fields_schema == null) {
                if (input.payload) |payload| {
                    if (payload != .null) return error.InvalidInstructionSchema;
                }
                return;
            }

            const payload = input.payload orelse return error.InvalidInstructionSchema;
            try encodeBorshSchemaValue(allocator, output, root_schema, inline_schema orelse variant_value, payload);
            return;
        }

        return error.InvalidInstructionSchema;
    }

    return error.InvalidInstructionSchema;
}

pub fn encodeInstructionDataFromSchemaValue(
    allocator: Allocator,
    schema: std.json.Value,
    args: std.json.Value,
    schema_encoding: SchemaEncoding,
) EncodeError![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    switch (schema_encoding) {
        .borsh => try encodeBorshSchemaValue(allocator, &output, schema, schema, args),
    }

    return try output.toOwnedSlice(allocator);
}

pub fn encodeInstructionDataFromSchemaJson(
    allocator: Allocator,
    schema_json: []const u8,
    args_json: []const u8,
    schema_encoding: SchemaEncoding,
) EncodeError![]u8 {
    const parsed_schema = std.json.parseFromSlice(std.json.Value, allocator, schema_json, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInstructionSchema;
    defer parsed_schema.deinit();

    const parsed_args = std.json.parseFromSlice(std.json.Value, allocator, args_json, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInstructionSchema;
    defer parsed_args.deinit();

    return try encodeInstructionDataFromSchemaValue(
        allocator,
        parsed_schema.value,
        parsed_args.value,
        schema_encoding,
    );
}

test "instruction_schema encodes named borsh definitions with u128 payloads" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "definitions": {
        \\    "Payload": {
        \\      "type": "struct",
        \\      "fields": [
        \\        { "name": "owner", "type": "pubkey" },
        \\        { "name": "amount", "type": "u128" },
        \\        { "name": "memo", "type": { "type": "option", "item": "string" } }
        \\      ]
        \\    }
        \\  },
        \\  "type": "enum",
        \\  "variants": [
        \\    { "name": "Set", "type": { "defined": "Payload" } }
        \\  ]
        \\}
    ;
    const args_json =
        \\{
        \\  "variant": "Set",
        \\  "value": {
        \\    "owner": "11111111111111111111111111111111",
        \\    "amount": "340282366920938463463374607431768211455",
        \\    "memo": "hi"
        \\  }
        \\}
    ;

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(usize, 55), encoded.len);
    try std.testing.expectEqual(@as(u8, 0), encoded[0]);
    try std.testing.expect(std.mem.allEqual(u8, encoded[1..33], 0));
    try std.testing.expect(std.mem.allEqual(u8, encoded[33..49], 0xff));
    try std.testing.expectEqual(@as(u8, 1), encoded[49]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 2, 0, 0, 0, 'h', 'i' }, encoded[50..]);
}

test "instruction_schema encodes tuple values from array type definitions" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "types": [
        \\    {
        \\      "name": "Pair",
        \\      "type": {
        \\        "type": "tuple",
        \\        "items": [
        \\          "u8",
        \\          "i128"
        \\        ]
        \\      }
        \\    }
        \\  ],
        \\  "type": "Pair"
        \\}
    ;
    const args_json = "[7,\"-1\"]";

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(usize, 17), encoded.len);
    try std.testing.expectEqual(@as(u8, 7), encoded[0]);
    try std.testing.expect(std.mem.allEqual(u8, encoded[1..], 0xff));
}

test "instruction_schema encodes tuple struct payloads with floats" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "type": "struct",
        \\  "fields": [
        \\    "u8",
        \\    "f32",
        \\    "f64"
        \\  ]
        \\}
    ;
    const args_json = "[5,\"1.5\",\"-2.25\"]";

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(usize, 13), encoded.len);
    try std.testing.expectEqual(@as(u8, 5), encoded[0]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0xc0, 0x3f }, encoded[1..5]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xc0 }, encoded[5..13]);
}

test "instruction_schema encodes enum tuple payload variants" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "type": "enum",
        \\  "variants": [
        \\    {
        \\      "name": "SetPair",
        \\      "fields": [
        \\        "u16",
        \\        "string"
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    const args_json = "{\"variant\":\"SetPair\",\"value\":[513,\"ok\"]}";

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, &[_]u8{
        0x00,
        0x01,
        0x02,
        0x02,
        0x00,
        0x00,
        0x00,
        'o',
        'k',
    }, encoded);
}

test "instruction_schema encodes vec u8 from hex string input" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "type": "vec",
        \\  "item": "u8"
        \\}
    ;
    const args_json = "\"hex:deadbeef\"";

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, &[_]u8{
        0x04,
        0x00,
        0x00,
        0x00,
        0xde,
        0xad,
        0xbe,
        0xef,
    }, encoded);
}

test "instruction_schema encodes fixed u8 array from base64 string input" {
    const allocator = std.testing.allocator;
    const schema_json =
        \\{
        \\  "type": "array",
        \\  "item": "u8",
        \\  "len": 4
        \\}
    ;
    const args_json = "\"base64:3q2+7w==\"";

    const encoded = try encodeInstructionDataFromSchemaJson(allocator, schema_json, args_json, .borsh);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, &[_]u8{
        0xde,
        0xad,
        0xbe,
        0xef,
    }, encoded);
}
