const std = @import("std");
const sdk = @import("../sdk.zig");
const idl_types = @import("./types.zig");
const idl_encode = @import("./encode.zig");

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;
const ParseIdlError = @typeInfo(@typeInfo(@TypeOf(idl_types.parseJson)).@"fn".return_type.?).error_union.error_set;
const EncodeInstructionDataError = @typeInfo(@typeInfo(@TypeOf(idl_encode.encodeInstructionDataNamed)).@"fn".return_type.?).error_union.error_set;

pub const BuildError = Allocator.Error || ParseIdlError || EncodeInstructionDataError || error{
    MissingAnchorIdlProgramId,
    MissingAnchorIdlAccountBinding,
    InvalidAnchorIdlAccountSpec,
    UnsupportedAnchorIdlAccountFeature,
};

pub const AccountBinding = struct {
    path: []const u8,
    pubkey: sdk.Pubkey,
};

pub const BuildInstructionOptions = struct {
    program_id: ?sdk.Pubkey = null,
    args_json: ?[]const u8 = null,
    account_bindings: []const AccountBinding = &.{},
    remaining_accounts: []const sdk.AccountMeta = &.{},
    default_signer: ?sdk.Pubkey = null,
};

pub const OwnedInstruction = struct {
    instruction: sdk.Instruction,

    pub fn deinit(self: *OwnedInstruction, allocator: Allocator) void {
        allocator.free(self.instruction.accounts);
        allocator.free(self.instruction.data);
        self.* = undefined;
    }
};

fn pathSegmentMatches(expected_name: []const u8, provided_name: []const u8) bool {
    if (std.mem.eql(u8, expected_name, provided_name)) return true;
    if (expected_name.len == 0 or provided_name.len == 0) return false;

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

fn fullPathMatches(expected_path: []const u8, provided_path: []const u8) bool {
    var expected_rest = expected_path;
    var provided_rest = provided_path;

    while (true) {
        const expected_dot = std.mem.indexOfScalar(u8, expected_rest, '.');
        const provided_dot = std.mem.indexOfScalar(u8, provided_rest, '.');

        const expected_segment = expected_rest[0 .. expected_dot orelse expected_rest.len];
        const provided_segment = provided_rest[0 .. provided_dot orelse provided_rest.len];
        if (!pathSegmentMatches(expected_segment, provided_segment)) return false;

        if (expected_dot == null or provided_dot == null) {
            return expected_dot == null and provided_dot == null;
        }

        expected_rest = expected_rest[expected_dot.? + 1 ..];
        provided_rest = provided_rest[provided_dot.? + 1 ..];
    }
}

fn normalizeAccountPath(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".key")) return path[0 .. path.len - 4];
    if (std.mem.endsWith(u8, path, ".pubkey")) return path[0 .. path.len - 7];
    if (std.mem.endsWith(u8, path, ".publicKey")) return path[0 .. path.len - 10];
    if (std.mem.endsWith(u8, path, ".public_key")) return path[0 .. path.len - 11];
    if (std.mem.endsWith(u8, path, ".address")) return path[0 .. path.len - 8];
    if (std.mem.endsWith(u8, path, ".programId")) return path[0 .. path.len - 10];
    if (std.mem.endsWith(u8, path, ".program_id")) return path[0 .. path.len - 11];
    return path;
}

fn findJsonObjectField(object: std.json.ObjectMap, key: []const u8) ?std.json.Value {
    if (object.get(key)) |binding| return binding;
    if (key.len == 0) return null;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        if (pathSegmentMatches(entry.key_ptr.*, key)) return entry.value_ptr.*;
    }

    return null;
}

fn findJsonValue(value: *const std.json.Value, path: []const u8) ?std.json.Value {
    switch (value.*) {
        .object => {
            if (findJsonObjectField(value.object, path)) |binding| return binding;
            if (std.mem.indexOfScalar(u8, path, '.')) |dot_index| {
                const head = path[0..dot_index];
                const tail = path[dot_index + 1 ..];
                const nested_value = findJsonObjectField(value.object, head) orelse return null;
                return findJsonValue(&nested_value, tail);
            }
            return null;
        },
        .array => {
            if (std.mem.indexOfScalar(u8, path, '.')) |dot_index| {
                const head = path[0..dot_index];
                const tail = path[dot_index + 1 ..];
                const index = std.fmt.parseInt(usize, head, 10) catch return null;
                if (index >= value.array.items.len) return null;
                const nested_value = value.array.items[index];
                return findJsonValue(&nested_value, tail);
            }

            const index = std.fmt.parseInt(usize, path, 10) catch return null;
            if (index >= value.array.items.len) return null;
            return value.array.items[index];
        },
        else => return null,
    }
}

fn findBoundPubkey(bindings: []const AccountBinding, full_name: []const u8, leaf_name: []const u8) ?sdk.Pubkey {
    for (bindings) |binding| {
        if (fullPathMatches(binding.path, full_name) or fullPathMatches(binding.path, leaf_name)) return binding.pubkey;

        const normalized_path = normalizeAccountPath(binding.path);
        if (!std.mem.eql(u8, normalized_path, binding.path)) {
            if (fullPathMatches(normalized_path, full_name) or fullPathMatches(normalized_path, leaf_name)) {
                return binding.pubkey;
            }
        }
    }
    return null;
}

fn parsePathIndex(path_segment: []const u8) BuildError!usize {
    if (path_segment.len == 0) return error.InvalidAnchorIdlAccountSpec;
    return std.fmt.parseInt(usize, path_segment, 10) catch return error.InvalidAnchorIdlAccountSpec;
}

fn resolveFieldTypeSpec(field_value: std.json.Value) BuildError!std.json.Value {
    if (field_value == .object) {
        if (field_value.object.get("type")) |field_type| return field_type;
    }
    return field_value;
}

fn resolveArrayElementType(type_spec: std.json.Value) BuildError!std.json.Value {
    if (type_spec != .object) return error.InvalidAnchorIdlAccountSpec;
    const array_value = type_spec.object.get("array") orelse return error.InvalidAnchorIdlAccountSpec;
    return switch (array_value) {
        .array => |items| blk: {
            if (items.items.len != 2) return error.InvalidAnchorIdlAccountSpec;
            break :blk items.items[0];
        },
        .object => |object_value| object_value.get("type") orelse return error.InvalidAnchorIdlAccountSpec,
        else => return error.InvalidAnchorIdlAccountSpec,
    };
}

fn enumVariantNameMatches(idl_variant_name: []const u8, selected_variant_name: []const u8) bool {
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

fn resolvePdaConcreteType(idl: *const idl_types.Idl, type_spec: std.json.Value) BuildError!std.json.Value {
    if (type_spec != .object) return type_spec;

    if (type_spec.object.get("defined")) |defined_value| {
        const defined_name = switch (defined_value) {
            .string => defined_value.string,
            .object => blk: {
                const name_value = defined_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
                if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;
                break :blk name_value.string;
            },
            else => return error.InvalidAnchorIdlAccountSpec,
        };
        const type_def = idl_types.findType(idl, defined_name) orelse return error.InvalidAnchorIdlAccountSpec;
        return try resolvePdaConcreteType(idl, type_def.type);
    }

    if (type_spec.object.get("kind")) |kind_value| {
        if (kind_value != .string) return error.InvalidAnchorIdlAccountSpec;
        if (std.mem.eql(u8, kind_value.string, "alias")) {
            const alias_value = type_spec.object.get("value") orelse return error.InvalidAnchorIdlAccountSpec;
            return try resolvePdaConcreteType(idl, alias_value);
        }
    }

    return type_spec;
}

fn resolvePdaSeedType(idl: *const idl_types.Idl, type_spec: std.json.Value, path: []const u8) BuildError!std.json.Value {
    const concrete_type = try resolvePdaConcreteType(idl, type_spec);
    if (path.len == 0) return concrete_type;
    if (concrete_type != .object) return error.InvalidAnchorIdlAccountSpec;

    const field_name, const child_path = if (std.mem.indexOfScalar(u8, path, '.')) |dot_index|
        .{ path[0..dot_index], path[dot_index + 1 ..] }
    else
        .{ path, "" };

    if (concrete_type.object.get("option")) |child_type| {
        return try resolvePdaSeedType(idl, child_type, path);
    }
    if (concrete_type.object.get("vec")) |child_type| {
        _ = try parsePathIndex(field_name);
        return try resolvePdaSeedType(idl, child_type, child_path);
    }
    if (concrete_type.object.get("array") != null) {
        const child_type = try resolveArrayElementType(concrete_type);
        _ = try parsePathIndex(field_name);
        return try resolvePdaSeedType(idl, child_type, child_path);
    }

    const kind_value = concrete_type.object.get("kind") orelse return error.InvalidAnchorIdlAccountSpec;
    if (kind_value != .string) return error.InvalidAnchorIdlAccountSpec;

    if (std.mem.eql(u8, kind_value.string, "struct")) {
        const fields_value = concrete_type.object.get("fields") orelse return error.InvalidAnchorIdlAccountSpec;
        if (fields_value != .array) return error.InvalidAnchorIdlAccountSpec;

        if (fields_value.array.items.len == 0) return error.InvalidAnchorIdlAccountSpec;
        const first_field = fields_value.array.items[0];
        if (!(first_field == .object and first_field.object.get("name") != null)) {
            const field_index = try parsePathIndex(field_name);
            if (field_index >= fields_value.array.items.len) return error.InvalidAnchorIdlAccountSpec;
            return try resolvePdaSeedType(idl, try resolveFieldTypeSpec(fields_value.array.items[field_index]), child_path);
        }

        for (fields_value.array.items) |field_value| {
            if (field_value != .object) return error.InvalidAnchorIdlAccountSpec;
            const name_value = field_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
            const field_type = field_value.object.get("type") orelse return error.InvalidAnchorIdlAccountSpec;
            if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;
            if (!pathSegmentMatches(name_value.string, field_name)) continue;
            return try resolvePdaSeedType(idl, field_type, child_path);
        }
        return error.InvalidAnchorIdlAccountSpec;
    }

    if (std.mem.eql(u8, kind_value.string, "enum")) {
        const variants_value = concrete_type.object.get("variants") orelse return error.InvalidAnchorIdlAccountSpec;
        if (variants_value != .array) return error.InvalidAnchorIdlAccountSpec;
        const nested_field_name, const nested_child_path = if (std.mem.indexOfScalar(u8, child_path, '.')) |dot_index|
            .{ child_path[0..dot_index], child_path[dot_index + 1 ..] }
        else
            .{ child_path, "" };

        for (variants_value.array.items) |variant_value| {
            if (variant_value != .object) return error.InvalidAnchorIdlAccountSpec;
            const variant_name = variant_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
            if (variant_name != .string) return error.InvalidAnchorIdlAccountSpec;
            if (!enumVariantNameMatches(variant_name.string, field_name)) continue;

            const fields_value = variant_value.object.get("fields") orelse return error.InvalidAnchorIdlAccountSpec;
            if (fields_value == .null or fields_value != .array) return error.InvalidAnchorIdlAccountSpec;
            if (child_path.len == 0 or fields_value.array.items.len == 0) return error.InvalidAnchorIdlAccountSpec;

            const first_field = fields_value.array.items[0];
            if (!(first_field == .object and first_field.object.get("name") != null)) {
                const field_index = try parsePathIndex(nested_field_name);
                if (field_index >= fields_value.array.items.len) return error.InvalidAnchorIdlAccountSpec;
                return try resolvePdaSeedType(idl, try resolveFieldTypeSpec(fields_value.array.items[field_index]), nested_child_path);
            }

            for (fields_value.array.items) |field_value| {
                if (field_value != .object) return error.InvalidAnchorIdlAccountSpec;
                const name_value = field_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
                const field_type = field_value.object.get("type") orelse return error.InvalidAnchorIdlAccountSpec;
                if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;
                if (!pathSegmentMatches(name_value.string, nested_field_name)) continue;
                return try resolvePdaSeedType(idl, field_type, nested_child_path);
            }
            return error.InvalidAnchorIdlAccountSpec;
        }
        return error.InvalidAnchorIdlAccountSpec;
    }

    return error.InvalidAnchorIdlAccountSpec;
}

fn appendPdaScalarSeed(
    allocator: Allocator,
    bytes: *std.ArrayListUnmanaged(u8),
    idl: *const idl_types.Idl,
    type_spec: std.json.Value,
    value: std.json.Value,
) BuildError!void {
    const concrete_type = try resolvePdaConcreteType(idl, type_spec);

    if (concrete_type == .object) {
        if (concrete_type.object.get("option")) |child_type| {
            if (value == .null) {
                try bytes.append(allocator, 0);
                return;
            }
            try bytes.append(allocator, 1);
            try appendPdaScalarSeed(allocator, bytes, idl, child_type, value);
            return;
        }
        if (concrete_type.object.get("vec")) |child_type| {
            if (value != .array) return error.InvalidAnchorIdlAccountSpec;
            var encoded_len: [4]u8 = undefined;
            std.mem.writeInt(u32, &encoded_len, @intCast(value.array.items.len), .little);
            try bytes.appendSlice(allocator, &encoded_len);
            for (value.array.items) |item| {
                try appendPdaScalarSeed(allocator, bytes, idl, child_type, item);
            }
            return;
        }
        if (concrete_type.object.get("array")) |array_value| {
            const element_type, const expected_len: usize = switch (array_value) {
                .array => |items| blk: {
                    if (items.items.len != 2) return error.InvalidAnchorIdlAccountSpec;
                    const len_value = items.items[1];
                    if (len_value != .integer or len_value.integer < 0) return error.InvalidAnchorIdlAccountSpec;
                    break :blk .{ items.items[0], @as(usize, @intCast(len_value.integer)) };
                },
                .object => |object_value| blk: {
                    const element_type = object_value.get("type") orelse return error.InvalidAnchorIdlAccountSpec;
                    const len_value = object_value.get("len") orelse return error.InvalidAnchorIdlAccountSpec;
                    if (len_value != .integer or len_value.integer < 0) return error.InvalidAnchorIdlAccountSpec;
                    break :blk .{ element_type, @as(usize, @intCast(len_value.integer)) };
                },
                else => return error.InvalidAnchorIdlAccountSpec,
            };
            if (value != .array or value.array.items.len != expected_len) return error.InvalidAnchorIdlAccountSpec;
            for (value.array.items) |item| {
                try appendPdaScalarSeed(allocator, bytes, idl, element_type, item);
            }
            return;
        }
        if (concrete_type.object.get("kind")) |kind_value| {
            if (kind_value != .string) return error.InvalidAnchorIdlAccountSpec;

            if (std.mem.eql(u8, kind_value.string, "struct")) {
                const fields_value = concrete_type.object.get("fields") orelse return error.InvalidAnchorIdlAccountSpec;
                if (fields_value != .array) return error.InvalidAnchorIdlAccountSpec;
                if (fields_value.array.items.len == 0) {
                    if (value != .object and value != .array) return error.InvalidAnchorIdlAccountSpec;
                    return;
                }

                const first_field = fields_value.array.items[0];
                if (!(first_field == .object and first_field.object.get("name") != null)) {
                    if (value != .array or value.array.items.len != fields_value.array.items.len) return error.InvalidAnchorIdlAccountSpec;
                    for (fields_value.array.items, value.array.items) |field_value, payload_value| {
                        try appendPdaScalarSeed(allocator, bytes, idl, try resolveFieldTypeSpec(field_value), payload_value);
                    }
                    return;
                }

                if (value != .object) return error.InvalidAnchorIdlAccountSpec;
                for (fields_value.array.items) |field_value| {
                    if (field_value != .object) return error.InvalidAnchorIdlAccountSpec;
                    const field_name = field_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
                    const field_type = field_value.object.get("type") orelse return error.InvalidAnchorIdlAccountSpec;
                    if (field_name != .string) return error.InvalidAnchorIdlAccountSpec;
                    const field_arg_value = findJsonObjectField(value.object, field_name.string) orelse return error.InvalidAnchorIdlAccountSpec;
                    try appendPdaScalarSeed(allocator, bytes, idl, field_type, field_arg_value);
                }
                return;
            }

            if (std.mem.eql(u8, kind_value.string, "enum")) {
                const variants_value = concrete_type.object.get("variants") orelse return error.InvalidAnchorIdlAccountSpec;
                if (variants_value != .array) return error.InvalidAnchorIdlAccountSpec;

                var selected_variant_name: []const u8 = undefined;
                var selected_variant_payload: ?std.json.Value = null;
                switch (value) {
                    .string => selected_variant_name = value.string,
                    .object => {
                        var iterator = value.object.iterator();
                        const entry = iterator.next() orelse return error.InvalidAnchorIdlAccountSpec;
                        if (iterator.next() != null) return error.InvalidAnchorIdlAccountSpec;
                        selected_variant_name = entry.key_ptr.*;
                        selected_variant_payload = entry.value_ptr.*;
                    },
                    else => return error.InvalidAnchorIdlAccountSpec,
                }

                for (variants_value.array.items, 0..) |variant_value, index| {
                    if (variant_value != .object) return error.InvalidAnchorIdlAccountSpec;
                    const variant_name = variant_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
                    if (variant_name != .string) return error.InvalidAnchorIdlAccountSpec;
                    if (!enumVariantNameMatches(variant_name.string, selected_variant_name)) continue;

                    if (index > std.math.maxInt(u8)) return error.InvalidAnchorIdlAccountSpec;
                    try bytes.append(allocator, @intCast(index));

                    const fields_value = variant_value.object.get("fields") orelse return;
                    if (fields_value == .null) return;
                    if (fields_value != .array) return error.InvalidAnchorIdlAccountSpec;

                    const payload = selected_variant_payload orelse return error.InvalidAnchorIdlAccountSpec;
                    if (fields_value.array.items.len == 0) return;

                    const first_field = fields_value.array.items[0];
                    if (first_field == .object and first_field.object.get("name") != null) {
                        if (payload != .object) return error.InvalidAnchorIdlAccountSpec;
                        for (fields_value.array.items) |field_value| {
                            if (field_value != .object) return error.InvalidAnchorIdlAccountSpec;
                            const field_name = field_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
                            const field_type = field_value.object.get("type") orelse return error.InvalidAnchorIdlAccountSpec;
                            if (field_name != .string) return error.InvalidAnchorIdlAccountSpec;
                            const field_arg_value = findJsonObjectField(payload.object, field_name.string) orelse return error.InvalidAnchorIdlAccountSpec;
                            try appendPdaScalarSeed(allocator, bytes, idl, field_type, field_arg_value);
                        }
                        return;
                    }

                    if (payload != .array or payload.array.items.len != fields_value.array.items.len) return error.InvalidAnchorIdlAccountSpec;
                    for (fields_value.array.items, payload.array.items) |field_type, payload_value| {
                        try appendPdaScalarSeed(allocator, bytes, idl, try resolveFieldTypeSpec(field_type), payload_value);
                    }
                    return;
                }

                return error.InvalidAnchorIdlAccountSpec;
            }
        }

        return error.InvalidAnchorIdlAccountSpec;
    }

    if (concrete_type != .string) return error.InvalidAnchorIdlAccountSpec;

    if (std.mem.eql(u8, concrete_type.string, "bool")) {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        try bytes.append(allocator, if (value.bool) 1 else 0);
        return;
    }
    if (std.mem.eql(u8, concrete_type.string, "u8")) {
        const parsed = switch (value) {
            .integer => std.math.cast(u8, value.integer) orelse return error.InvalidAnchorIdlAccountSpec,
            .string => std.fmt.parseInt(u8, value.string, 10) catch return error.InvalidAnchorIdlAccountSpec,
            else => return error.InvalidAnchorIdlAccountSpec,
        };
        try bytes.append(allocator, parsed);
        return;
    }
    inline for (.{ .{ "u16", u16 }, .{ "u32", u32 }, .{ "u64", u64 }, .{ "u128", u128 }, .{ "u256", u256 } }) |entry| {
        if (std.mem.eql(u8, concrete_type.string, entry[0])) {
            const T = entry[1];
            const parsed: T = switch (value) {
                .integer => std.math.cast(T, value.integer) orelse return error.InvalidAnchorIdlAccountSpec,
                .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidAnchorIdlAccountSpec,
                else => return error.InvalidAnchorIdlAccountSpec,
            };
            var encoded: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &encoded, parsed, .little);
            try bytes.appendSlice(allocator, &encoded);
            return;
        }
    }
    inline for (.{ .{ "i8", i8 }, .{ "i16", i16 }, .{ "i32", i32 }, .{ "i64", i64 }, .{ "i128", i128 }, .{ "i256", i256 } }) |entry| {
        if (std.mem.eql(u8, concrete_type.string, entry[0])) {
            const T = entry[1];
            const parsed: T = switch (value) {
                .integer => std.math.cast(T, value.integer) orelse return error.InvalidAnchorIdlAccountSpec,
                .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidAnchorIdlAccountSpec,
                else => return error.InvalidAnchorIdlAccountSpec,
            };
            var encoded: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &encoded, parsed, .little);
            try bytes.appendSlice(allocator, &encoded);
            return;
        }
    }
    if (std.mem.eql(u8, concrete_type.string, "f32")) {
        const parsed: f32 = switch (value) {
            .integer => @floatFromInt(value.integer),
            .float => std.math.lossyCast(f32, value.float),
            .string => std.fmt.parseFloat(f32, value.string) catch return error.InvalidAnchorIdlAccountSpec,
            else => return error.InvalidAnchorIdlAccountSpec,
        };
        var encoded: [4]u8 = undefined;
        std.mem.writeInt(u32, &encoded, @as(u32, @bitCast(parsed)), .little);
        try bytes.appendSlice(allocator, &encoded);
        return;
    }
    if (std.mem.eql(u8, concrete_type.string, "f64")) {
        const parsed: f64 = switch (value) {
            .integer => @floatFromInt(value.integer),
            .float => std.math.lossyCast(f64, value.float),
            .string => std.fmt.parseFloat(f64, value.string) catch return error.InvalidAnchorIdlAccountSpec,
            else => return error.InvalidAnchorIdlAccountSpec,
        };
        var encoded: [8]u8 = undefined;
        std.mem.writeInt(u64, &encoded, @as(u64, @bitCast(parsed)), .little);
        try bytes.appendSlice(allocator, &encoded);
        return;
    }
    if (std.mem.eql(u8, concrete_type.string, "string")) {
        if (value != .string) return error.InvalidAnchorIdlAccountSpec;
        try bytes.appendSlice(allocator, value.string);
        return;
    }
    if (std.mem.eql(u8, concrete_type.string, "bytes")) {
        switch (value) {
            .string => try bytes.appendSlice(allocator, value.string),
            .array => for (value.array.items) |byte_value| {
                if (byte_value != .integer or byte_value.integer < 0 or byte_value.integer > 255) return error.InvalidAnchorIdlAccountSpec;
                try bytes.append(allocator, @intCast(byte_value.integer));
            },
            else => return error.InvalidAnchorIdlAccountSpec,
        }
        return;
    }
    if (std.mem.eql(u8, concrete_type.string, "pubkey") or
        std.mem.eql(u8, concrete_type.string, "publicKey") or
        std.mem.eql(u8, concrete_type.string, "public_key"))
    {
        const pubkey_value = switch (value) {
            .string => value.string,
            .object => blk: {
                inline for (.{ "address", "publicKey", "public_key", "pubkey", "key", "programId", "program_id" }) |field_name| {
                    if (value.object.get(field_name)) |field_value| {
                        if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
                        break :blk field_value.string;
                    }
                }
                return error.InvalidAnchorIdlAccountSpec;
            },
            else => return error.InvalidAnchorIdlAccountSpec,
        };
        const pubkey = sdk.Pubkey.fromBase58(allocator, pubkey_value) catch return error.InvalidAnchorIdlAccountSpec;
        try bytes.appendSlice(allocator, &pubkey.bytes);
        return;
    }

    return error.InvalidAnchorIdlAccountSpec;
}

fn encodePdaArgSeed(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    parsed_args: ?*const std.json.Value,
    path: []const u8,
) BuildError![]u8 {
    const args_value = parsed_args orelse return error.InvalidAnchorIdlAccountSpec;
    const arg_value = findJsonValue(args_value, path) orelse return error.InvalidAnchorIdlAccountSpec;

    const arg_name, const child_path = if (std.mem.indexOfScalar(u8, path, '.')) |dot_index|
        .{ path[0..dot_index], path[dot_index + 1 ..] }
    else
        .{ path, "" };

    var arg_type: ?std.json.Value = null;
    for (instruction.args) |arg| {
        if (pathSegmentMatches(arg.name, arg_name)) {
            arg_type = arg.type;
            break;
        }
    }

    const type_spec = try resolvePdaSeedType(idl, arg_type orelse return error.InvalidAnchorIdlAccountSpec, child_path);
    var bytes: std.ArrayListUnmanaged(u8) = .{};
    defer bytes.deinit(allocator);
    try appendPdaScalarSeed(allocator, &bytes, idl, type_spec, arg_value);
    return try allocator.dupe(u8, bytes.items);
}

fn encodePdaConstSeed(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    seed_value: std.json.Value,
) BuildError![]u8 {
    if (seed_value != .object) return error.InvalidAnchorIdlAccountSpec;
    const value = seed_value.object.get("value") orelse return error.InvalidAnchorIdlAccountSpec;

    if (seed_value.object.get("type")) |type_spec| {
        const resolved_type_spec = try resolvePdaSeedType(idl, type_spec, "");
        var bytes: std.ArrayListUnmanaged(u8) = .{};
        defer bytes.deinit(allocator);
        try appendPdaScalarSeed(allocator, &bytes, idl, resolved_type_spec, value);
        return try allocator.dupe(u8, bytes.items);
    }

    switch (value) {
        .string => return try allocator.dupe(u8, value.string),
        .array => {
            const seed = try allocator.alloc(u8, value.array.items.len);
            for (value.array.items, 0..) |item, byte_index| {
                if (item != .integer or item.integer < 0 or item.integer > 255) return error.InvalidAnchorIdlAccountSpec;
                seed[byte_index] = @intCast(item.integer);
            }
            return seed;
        },
        else => return error.InvalidAnchorIdlAccountSpec,
    }
}

const ResolvedAccountPubkey = struct {
    pubkey: sdk.Pubkey,
    missing_optional: bool = false,
};

const AccountContext = struct {
    account_value: std.json.Value,
    siblings: []const std.json.Value,
    account_index: usize,
};

fn findAccountValue(accounts: []const std.json.Value, path: []const u8) ?std.json.Value {
    if (std.mem.indexOfScalar(u8, path, '.')) |dot_index| {
        const head = path[0..dot_index];
        const tail = path[dot_index + 1 ..];
        for (accounts) |account_value| {
            if (account_value != .object) continue;
            const name_value = account_value.object.get("name") orelse continue;
            if (name_value != .string) continue;
            if (!pathSegmentMatches(name_value.string, head)) continue;
            const nested_value = account_value.object.get("accounts") orelse return null;
            if (nested_value != .array) return null;
            return findAccountValue(nested_value.array.items, tail);
        }
        return null;
    }

    for (accounts) |account_value| {
        if (account_value != .object) continue;
        const name_value = account_value.object.get("name") orelse continue;
        if (name_value != .string) continue;
        if (pathSegmentMatches(name_value.string, path)) return account_value;
        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) continue;
            if (findAccountValue(nested_value.array.items, path)) |found| return found;
        }
    }
    return null;
}

fn findAccountContext(accounts: []const std.json.Value, path: []const u8) BuildError!?AccountContext {
    if (std.mem.indexOfScalar(u8, path, '.')) |dot_index| {
        const head = path[0..dot_index];
        const tail = path[dot_index + 1 ..];
        for (accounts) |account_value| {
            if (account_value != .object) continue;
            const name_value = account_value.object.get("name") orelse continue;
            if (name_value != .string) continue;
            if (!pathSegmentMatches(name_value.string, head)) continue;
            const nested_value = account_value.object.get("accounts") orelse return null;
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            return try findAccountContext(nested_value.array.items, tail);
        }
        return null;
    }

    for (accounts, 0..) |account_value, account_index| {
        if (account_value != .object) continue;
        const name_value = account_value.object.get("name") orelse continue;
        if (name_value != .string) continue;
        if (!pathSegmentMatches(name_value.string, path)) continue;
        return .{ .account_value = account_value, .siblings = accounts, .account_index = account_index };
    }
    return null;
}

fn findAccountFullPath(
    allocator: Allocator,
    accounts: []const std.json.Value,
    path: []const u8,
    parent_path: ?[]const u8,
) BuildError!?[]u8 {
    if (std.mem.indexOfScalar(u8, path, '.')) |dot_index| {
        const head = path[0..dot_index];
        const tail = path[dot_index + 1 ..];
        for (accounts) |account_value| {
            if (account_value != .object) continue;
            const name_value = account_value.object.get("name") orelse continue;
            if (name_value != .string) continue;
            if (!pathSegmentMatches(name_value.string, head)) continue;
            const nested_value = account_value.object.get("accounts") orelse return null;
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            const full_name = if (parent_path) |value|
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ value, name_value.string })
            else
                try allocator.dupe(u8, name_value.string);
            defer allocator.free(full_name);
            return try findAccountFullPath(allocator, nested_value.array.items, tail, full_name);
        }
        return null;
    }

    for (accounts) |account_value| {
        if (account_value != .object) continue;
        const name_value = account_value.object.get("name") orelse continue;
        if (name_value != .string) continue;
        if (pathSegmentMatches(name_value.string, path)) {
            return if (parent_path) |value|
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ value, name_value.string })
            else
                try allocator.dupe(u8, name_value.string);
        }
        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            const full_name = if (parent_path) |value|
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ value, name_value.string })
            else
                try allocator.dupe(u8, name_value.string);
            defer allocator.free(full_name);
            if (try findAccountFullPath(allocator, nested_value.array.items, path, full_name)) |found| return found;
        }
    }
    return null;
}

fn resolutionStackContains(resolution_stack: *const std.ArrayListUnmanaged([]u8), path: []const u8) bool {
    for (resolution_stack.items) |value| {
        if (std.mem.eql(u8, value, path)) return true;
    }
    return false;
}

fn encodePdaAccountSeed(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    seed_value: std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError![]u8 {
    if (seed_value != .object) return error.InvalidAnchorIdlAccountSpec;
    const path_value = if (seed_value.object.get("path")) |value|
        value
    else
        seed_value.object.get("account") orelse return error.InvalidAnchorIdlAccountSpec;
    if (path_value != .string) return error.InvalidAnchorIdlAccountSpec;

    if (seed_value.object.get("type")) |type_spec| {
        const resolved_type_spec = try resolvePdaSeedType(idl, type_spec, "");
        if (!(resolved_type_spec == .string and
            (std.mem.eql(u8, resolved_type_spec.string, "pubkey") or
                std.mem.eql(u8, resolved_type_spec.string, "publicKey") or
                std.mem.eql(u8, resolved_type_spec.string, "public_key"))))
        {
            return error.UnsupportedAnchorIdlAccountFeature;
        }
    }

    const resolved = try resolveNamedAccountPubkeyFromAccounts(
        allocator,
        idl,
        instruction,
        instruction.accounts,
        parsed_args,
        account_bindings,
        path_value.string,
        program_id,
        default_signer_pubkey,
        resolution_stack,
    );
    return try allocator.dupe(u8, &resolved.pubkey.bytes);
}

fn derivePda(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    pda_value: std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError!sdk.Pubkey {
    if (pda_value != .object) return error.InvalidAnchorIdlAccountSpec;
    const seeds_value = pda_value.object.get("seeds") orelse return error.InvalidAnchorIdlAccountSpec;
    if (seeds_value != .array) return error.InvalidAnchorIdlAccountSpec;

    const pda_program = if (pda_value.object.get("program")) |program_value| blk: {
        switch (program_value) {
            .string => break :blk sdk.Pubkey.fromBase58(allocator, program_value.string) catch return error.InvalidAnchorIdlAccountSpec,
            .object => {
                const kind_value = program_value.object.get("kind") orelse return error.InvalidAnchorIdlAccountSpec;
                if (kind_value != .string) return error.InvalidAnchorIdlAccountSpec;
                if (std.mem.eql(u8, kind_value.string, "const")) {
                    const bytes = try encodePdaConstSeed(allocator, idl, program_value);
                    defer allocator.free(bytes);
                    break :blk sdk.Pubkey.fromSlice(bytes) catch return error.InvalidAnchorIdlAccountSpec;
                }
                if (std.mem.eql(u8, kind_value.string, "arg")) {
                    const path_value = program_value.object.get("path") orelse return error.InvalidAnchorIdlAccountSpec;
                    if (path_value != .string) return error.InvalidAnchorIdlAccountSpec;
                    const seed = try encodePdaArgSeed(allocator, idl, instruction, parsed_args, path_value.string);
                    defer allocator.free(seed);
                    break :blk sdk.Pubkey.fromSlice(seed) catch return error.InvalidAnchorIdlAccountSpec;
                }
                if (std.mem.eql(u8, kind_value.string, "account")) {
                    const seed = try encodePdaAccountSeed(
                        allocator,
                        idl,
                        instruction,
                        program_value,
                        parsed_args,
                        account_bindings,
                        program_id,
                        default_signer_pubkey,
                        resolution_stack,
                    );
                    defer allocator.free(seed);
                    break :blk sdk.Pubkey.fromSlice(seed) catch return error.InvalidAnchorIdlAccountSpec;
                }
                return error.UnsupportedAnchorIdlAccountFeature;
            },
            else => return error.InvalidAnchorIdlAccountSpec,
        }
    } else program_id;

    const owned_seeds = try allocator.alloc([]u8, seeds_value.array.items.len);
    var owned_seed_count: usize = 0;
    defer {
        for (owned_seeds[0..owned_seed_count]) |seed| allocator.free(seed);
        allocator.free(owned_seeds);
    }
    const seed_slices = try allocator.alloc([]const u8, seeds_value.array.items.len);
    defer allocator.free(seed_slices);

    for (seeds_value.array.items, 0..) |seed_value, index| {
        if (seed_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const kind_value = seed_value.object.get("kind") orelse return error.InvalidAnchorIdlAccountSpec;
        if (kind_value != .string) return error.InvalidAnchorIdlAccountSpec;

        const seed = if (std.mem.eql(u8, kind_value.string, "const"))
            try encodePdaConstSeed(allocator, idl, seed_value)
        else if (std.mem.eql(u8, kind_value.string, "arg")) blk: {
            const path_value = seed_value.object.get("path") orelse return error.InvalidAnchorIdlAccountSpec;
            if (path_value != .string) return error.InvalidAnchorIdlAccountSpec;
            break :blk try encodePdaArgSeed(allocator, idl, instruction, parsed_args, path_value.string);
        } else if (std.mem.eql(u8, kind_value.string, "account"))
            try encodePdaAccountSeed(
                allocator,
                idl,
                instruction,
                seed_value,
                parsed_args,
                account_bindings,
                program_id,
                default_signer_pubkey,
                resolution_stack,
            )
        else
            return error.UnsupportedAnchorIdlAccountFeature;

        owned_seeds[index] = seed;
        owned_seed_count += 1;
        seed_slices[index] = seed;
    }

    return try findProgramAddress(allocator, seed_slices, pda_program);
}

fn tryResolveNamedAccountPubkeyFromAccounts(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    accounts: []const std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    path: []const u8,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError!?ResolvedAccountPubkey {
    const leaf_name = if (std.mem.lastIndexOfScalar(u8, path, '.')) |dot_index| path[dot_index + 1 ..] else path;
    if (findBoundPubkey(account_bindings, path, leaf_name)) |pubkey| {
        return .{ .pubkey = pubkey };
    }

    const full_path = try findAccountFullPath(allocator, accounts, path, null);
    defer if (full_path) |value| allocator.free(value);
    if (full_path) |account_path| {
        return try resolveNamedAccountPubkeyAtPath(
            allocator,
            idl,
            instruction,
            accounts,
            parsed_args,
            account_bindings,
            account_path,
            program_id,
            default_signer_pubkey,
            resolution_stack,
        );
    }
    if (findAccountValue(accounts, path) != null) {
        return try resolveNamedAccountPubkeyAtPath(
            allocator,
            idl,
            instruction,
            accounts,
            parsed_args,
            account_bindings,
            path,
            program_id,
            default_signer_pubkey,
            resolution_stack,
        );
    }
    return null;
}

fn resolveNamedAccountPubkeyFromAccounts(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    accounts: []const std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    path: []const u8,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError!ResolvedAccountPubkey {
    if (try tryResolveNamedAccountPubkeyFromAccounts(
        allocator,
        idl,
        instruction,
        accounts,
        parsed_args,
        account_bindings,
        path,
        program_id,
        default_signer_pubkey,
        resolution_stack,
    )) |resolved| return resolved;

    const normalized_path = normalizeAccountPath(path);
    if (!std.mem.eql(u8, normalized_path, path)) {
        if (try tryResolveNamedAccountPubkeyFromAccounts(
            allocator,
            idl,
            instruction,
            accounts,
            parsed_args,
            account_bindings,
            normalized_path,
            program_id,
            default_signer_pubkey,
            resolution_stack,
        )) |resolved| return resolved;
    }

    return error.MissingAnchorIdlAccountBinding;
}

fn resolveNamedAccountPubkeyAtPath(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    accounts: []const std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    path: []const u8,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError!ResolvedAccountPubkey {
    const leaf_name = if (std.mem.lastIndexOfScalar(u8, path, '.')) |dot_index| path[dot_index + 1 ..] else path;
    if (resolutionStackContains(resolution_stack, path)) return error.InvalidAnchorIdlAccountSpec;
    const owned_path = try allocator.dupe(u8, path);
    try resolution_stack.append(allocator, owned_path);
    defer allocator.free(resolution_stack.pop().?);

    const account_value = findAccountValue(accounts, path) orelse return error.MissingAnchorIdlAccountBinding;
    if (account_value != .object or account_value.object.get("accounts") != null) return error.InvalidAnchorIdlAccountSpec;
    if (try findLiteralPubkey(allocator, account_value)) |pubkey| return .{ .pubkey = pubkey };
    if (account_value.object.get("pda")) |pda_value| {
        return .{ .pubkey = try derivePda(allocator, idl, instruction, pda_value, parsed_args, account_bindings, program_id, default_signer_pubkey, resolution_stack) };
    }

    const parent_path = if (std.mem.lastIndexOfScalar(u8, path, '.')) |dot_index| path[0..dot_index] else null;
    if (account_value.object.get("relations")) |relations_value| {
        if (relations_value != .array) return error.InvalidAnchorIdlAccountSpec;
        for (relations_value.array.items) |relation_value| {
            if (relation_value != .string) return error.InvalidAnchorIdlAccountSpec;

            if (parent_path) |parent| {
                const nested_relation_path = try std.fmt.allocPrint(allocator, "{s}.{s}.{s}", .{ parent, relation_value.string, leaf_name });
                defer allocator.free(nested_relation_path);
                if (try tryResolveNamedAccountPubkeyFromAccounts(
                    allocator,
                    idl,
                    instruction,
                    accounts,
                    parsed_args,
                    account_bindings,
                    nested_relation_path,
                    program_id,
                    default_signer_pubkey,
                    resolution_stack,
                )) |resolved| return resolved;
            }

            const relation_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ relation_value.string, leaf_name });
            defer allocator.free(relation_path);
            if (try tryResolveNamedAccountPubkeyFromAccounts(
                allocator,
                idl,
                instruction,
                accounts,
                parsed_args,
                account_bindings,
                relation_path,
                program_id,
                default_signer_pubkey,
                resolution_stack,
            )) |resolved| return resolved;
        }
    }

    const is_optional = try isOptionalAccount(account_value);
    const is_signer = try isSignerAccount(account_value);
    if (try findAccountContext(accounts, path)) |context| {
        if (try isEventCpiAccount(context.siblings, context.account_index, "eventAuthority")) {
            return .{ .pubkey = try findProgramAddress(allocator, &.{"__event_authority"}, program_id) };
        }
        if (try isEventCpiAccount(context.siblings, context.account_index, "program")) {
            return .{ .pubkey = program_id };
        }
    }
    if (default_signer_pubkey) |value| {
        if (is_signer and !is_optional) return .{ .pubkey = value };
    }
    if (try resolveBuiltinAccountPubkey(allocator, leaf_name)) |builtin_pubkey| {
        return .{ .pubkey = builtin_pubkey };
    }
    if (is_optional) return .{ .pubkey = program_id, .missing_optional = true };
    return error.MissingAnchorIdlAccountBinding;
}

fn countLeafAccounts(accounts: []const std.json.Value) BuildError!usize {
    var count: usize = 0;
    for (accounts) |account_value| {
        if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
        _ = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            count += try countLeafAccounts(nested_value.array.items);
        } else {
            count += 1;
        }
    }
    return count;
}

fn findLiteralPubkey(allocator: Allocator, account_value: std.json.Value) BuildError!?sdk.Pubkey {
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    inline for (.{ "address", "publicKey", "public_key", "pubkey", "key", "programId", "program_id" }) |field_name| {
        if (account_value.object.get(field_name)) |field_value| {
            if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
            return sdk.Pubkey.fromBase58(allocator, field_value.string) catch return error.InvalidAnchorIdlAccountSpec;
        }
    }
    return null;
}

fn parseAccountBoolFlag(
    account_value: std.json.Value,
    primary_field: []const u8,
    alias_field: []const u8,
    snake_alias_field: []const u8,
) BuildError!bool {
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    if (account_value.object.get(primary_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    if (account_value.object.get(alias_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    if (account_value.object.get(snake_alias_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    return false;
}

fn isWritableAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "writable", "isMut", "is_mut");
}

fn isSignerAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "signer", "isSigner", "is_signer");
}

fn isOptionalAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "optional", "isOptional", "is_optional");
}

fn isEventCpiAccount(accounts: []const std.json.Value, account_index: usize, expected_name: []const u8) BuildError!bool {
    if (account_index >= accounts.len) return false;
    const account_value = accounts[account_index];
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    const name_value = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
    if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;

    const matches_expected = if (std.mem.eql(u8, expected_name, "eventAuthority"))
        std.mem.eql(u8, name_value.string, "eventAuthority") or std.mem.eql(u8, name_value.string, "event_authority")
    else
        std.mem.eql(u8, name_value.string, expected_name);
    if (!matches_expected) return false;

    if (std.mem.eql(u8, expected_name, "eventAuthority")) {
        if (account_index + 1 >= accounts.len) return false;
        const next_value = accounts[account_index + 1];
        if (next_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const next_name = next_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (next_name != .string) return error.InvalidAnchorIdlAccountSpec;
        return std.mem.eql(u8, next_name.string, "program");
    }

    if (std.mem.eql(u8, expected_name, "program")) {
        if (account_index == 0) return false;
        const prev_value = accounts[account_index - 1];
        if (prev_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const prev_name = prev_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (prev_name != .string) return error.InvalidAnchorIdlAccountSpec;
        return std.mem.eql(u8, prev_name.string, "eventAuthority") or std.mem.eql(u8, prev_name.string, "event_authority");
    }

    return false;
}

fn createProgramAddress(seeds: []const []const u8, program_id: sdk.Pubkey) BuildError!sdk.Pubkey {
    for (seeds) |seed| {
        if (seed.len > 32) return error.InvalidAnchorIdlAccountSpec;
    }

    var hasher = Sha256.init(.{});
    for (seeds) |seed| hasher.update(seed);
    hasher.update(&program_id.bytes);
    hasher.update("ProgramDerivedAddress");

    var hash: [32]u8 = undefined;
    hasher.final(&hash);
    if (std.crypto.ecc.Edwards25519.fromBytes(hash)) |_| {
        return error.InvalidAnchorIdlAccountSpec;
    } else |_| {}
    return sdk.Pubkey.fromBytes(hash);
}

fn findProgramAddress(allocator: Allocator, seeds: []const []const u8, program_id: sdk.Pubkey) BuildError!sdk.Pubkey {
    const search_seeds = try allocator.alloc([]const u8, seeds.len + 1);
    defer allocator.free(search_seeds);
    @memcpy(search_seeds[0..seeds.len], seeds);

    var bump_seed: [1]u8 = undefined;
    search_seeds[seeds.len] = bump_seed[0..];

    var bump: i16 = 255;
    while (bump >= 0) : (bump -= 1) {
        bump_seed[0] = @intCast(bump);
        const candidate = createProgramAddress(search_seeds, program_id) catch continue;
        return candidate;
    }
    return error.InvalidAnchorIdlAccountSpec;
}

fn resolveBuiltinAccountPubkey(allocator: Allocator, account_name: []const u8) BuildError!?sdk.Pubkey {
    const builtin_base58: ?[]const u8 = if (std.mem.eql(u8, account_name, "systemProgram") or
        std.mem.eql(u8, account_name, "system_program") or
        std.mem.eql(u8, account_name, "systemProgramId") or
        std.mem.eql(u8, account_name, "system_program_id"))
        "11111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "tokenProgram") or
        std.mem.eql(u8, account_name, "token_program") or
        std.mem.eql(u8, account_name, "tokenProgramId") or
        std.mem.eql(u8, account_name, "token_program_id"))
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    else if (std.mem.eql(u8, account_name, "associatedTokenProgram") or
        std.mem.eql(u8, account_name, "associated_token_program") or
        std.mem.eql(u8, account_name, "associatedTokenProgramId") or
        std.mem.eql(u8, account_name, "associated_token_program_id"))
        "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    else if (std.mem.eql(u8, account_name, "token2022Program") or
        std.mem.eql(u8, account_name, "token_2022_program") or
        std.mem.eql(u8, account_name, "token2022_program") or
        std.mem.eql(u8, account_name, "token_program_2022") or
        std.mem.eql(u8, account_name, "token2022ProgramId") or
        std.mem.eql(u8, account_name, "token_2022_program_id") or
        std.mem.eql(u8, account_name, "token2022_program_id") or
        std.mem.eql(u8, account_name, "token_program_2022_id"))
        "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    else if (std.mem.eql(u8, account_name, "rent") or
        std.mem.eql(u8, account_name, "rentSysvar") or
        std.mem.eql(u8, account_name, "rent_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_rent") or
        std.mem.eql(u8, account_name, "rentSysvarId") or
        std.mem.eql(u8, account_name, "rent_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_rent_id"))
        "SysvarRent111111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "clock") or
        std.mem.eql(u8, account_name, "clockSysvar") or
        std.mem.eql(u8, account_name, "clock_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_clock") or
        std.mem.eql(u8, account_name, "clockSysvarId") or
        std.mem.eql(u8, account_name, "clock_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_clock_id"))
        "SysvarC1ock11111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "instructions") or
        std.mem.eql(u8, account_name, "instructionsSysvar") or
        std.mem.eql(u8, account_name, "instructions_sysvar") or
        std.mem.eql(u8, account_name, "instructionSysvar") or
        std.mem.eql(u8, account_name, "instruction_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_instructions") or
        std.mem.eql(u8, account_name, "instructionsSysvarId") or
        std.mem.eql(u8, account_name, "instructions_sysvar_id") or
        std.mem.eql(u8, account_name, "instructionSysvarId") or
        std.mem.eql(u8, account_name, "instruction_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_instructions_id"))
        "Sysvar1nstructions1111111111111111111111111"
    else
        null;

    if (builtin_base58) |value| {
        return sdk.Pubkey.fromBase58(allocator, value) catch return error.InvalidAnchorIdlAccountSpec;
    }
    return null;
}

fn appendInstructionAccounts(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    accounts: []const std.json.Value,
    parsed_args: ?*const std.json.Value,
    bindings: []const AccountBinding,
    default_signer: ?sdk.Pubkey,
    program_id: sdk.Pubkey,
    metas: []sdk.AccountMeta,
    next_index: *usize,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
    parent_path: ?[]const u8,
) BuildError!void {
    for (accounts) |account_value| {
        if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const name_value = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;

        const full_name = if (parent_path) |value|
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ value, name_value.string })
        else
            try allocator.dupe(u8, name_value.string);
        defer allocator.free(full_name);

        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            try appendInstructionAccounts(
                allocator,
                idl,
                instruction,
                nested_value.array.items,
                parsed_args,
                bindings,
                default_signer,
                program_id,
                metas,
                next_index,
                resolution_stack,
                full_name,
            );
            continue;
        }

        const is_signer = try isSignerAccount(account_value);
        const is_writable = try isWritableAccount(account_value);
        const resolved = try resolveNamedAccountPubkeyFromAccounts(
            allocator,
            idl,
            instruction,
            instruction.accounts,
            parsed_args,
            bindings,
            full_name,
            program_id,
            default_signer,
            resolution_stack,
        );

        metas[next_index.*] = .{
            .pubkey = resolved.pubkey,
            .is_signer = if (resolved.missing_optional) false else is_signer,
            .is_writable = if (resolved.missing_optional) false else is_writable,
        };
        next_index.* += 1;
    }
}

pub fn buildOwnedInstruction(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    const instruction = idl_types.findInstruction(idl, instruction_name) orelse return error.MissingAnchorIdlInstruction;
    const program_id = if (options.program_id) |value|
        value
    else if (idl_types.programAddress(idl)) |value|
        sdk.Pubkey.fromBase58(allocator, value) catch return error.InvalidAnchorIdlAccountSpec
    else
        return error.MissingAnchorIdlProgramId;

    const data = try idl_encode.encodeInstructionDataNamed(allocator, idl, instruction_name, options.args_json);
    errdefer allocator.free(data);
    const parsed_args = if (options.args_json) |value|
        try std.json.parseFromSlice(std.json.Value, allocator, value, .{})
    else
        null;
    defer if (parsed_args) |*value| value.deinit();

    const leaf_account_count = try countLeafAccounts(instruction.accounts);
    const accounts = try allocator.alloc(sdk.AccountMeta, leaf_account_count + options.remaining_accounts.len);
    errdefer allocator.free(accounts);

    var next_index: usize = 0;
    var resolution_stack: std.ArrayListUnmanaged([]u8) = .{};
    defer {
        for (resolution_stack.items) |value| allocator.free(value);
        resolution_stack.deinit(allocator);
    }
    try appendInstructionAccounts(
        allocator,
        idl,
        &instruction,
        instruction.accounts,
        if (parsed_args) |value| &value.value else null,
        options.account_bindings,
        options.default_signer,
        program_id,
        accounts,
        &next_index,
        &resolution_stack,
        null,
    );
    @memcpy(accounts[next_index .. next_index + options.remaining_accounts.len], options.remaining_accounts);
    next_index += options.remaining_accounts.len;

    return .{
        .instruction = .{
            .program_id = program_id,
            .accounts = accounts[0..next_index],
            .data = data,
        },
    };
}

pub fn buildOwnedInstructionFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedInstruction(allocator, &parsed_idl.value, instruction_name, options);
}

pub const BuildLegacyMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instruction_options: BuildInstructionOptions = .{},
};

pub fn buildOwnedLegacyMessage(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyMessageOptions,
) BuildError!sdk.OwnedLegacyMessage {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try sdk.buildOwnedLegacyMessage(
        allocator,
        options.payer,
        options.recent_blockhash,
        &.{owned_instruction.instruction},
    );
}

pub fn buildOwnedLegacyMessageFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyMessageOptions,
) BuildError!sdk.OwnedLegacyMessage {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedLegacyMessage(allocator, &parsed_idl.value, instruction_name, options);
}
