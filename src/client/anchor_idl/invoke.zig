const std = @import("std");
const instructions_invoke = @import("../instructions_invoke.zig");
const invocation_spec_json = @import("../invocation_spec_json.zig");
const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");
const idl_types = @import("./types.zig");
const idl_encode = @import("./encode.zig");

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;
const ParseIdlError = @typeInfo(@typeInfo(@TypeOf(idl_types.parseJson)).@"fn".return_type.?).error_union.error_set;
const EncodeInstructionDataError = @typeInfo(@typeInfo(@TypeOf(idl_encode.encodeInstructionDataNamed)).@"fn".return_type.?).error_union.error_set;
const SignLegacyMessageError = @typeInfo(@typeInfo(@TypeOf(sdk.OwnedLegacyMessage.sign)).@"fn".return_type.?).error_union.error_set;
const SdkBuildVersionedMessageError = @typeInfo(@typeInfo(@TypeOf(sdk.buildVersionedMessageV0)).@"fn".return_type.?).error_union.error_set;
const SignVersionedMessageError = @typeInfo(@typeInfo(@TypeOf(sdk.OwnedVersionedMessageV0.sign)).@"fn".return_type.?).error_union.error_set;

pub const BuildError = Allocator.Error || ParseIdlError || EncodeInstructionDataError || error{
    MissingAnchorIdlProgramId,
    MissingAnchorIdlAccountBinding,
    InvalidAnchorIdlAccountSpec,
    InvalidInvocationSpec,
    UnsupportedAnchorIdlAccountFeature,
    WriteFailed,
};

pub const BuildLegacyTransactionError = BuildError || SignLegacyMessageError;
pub const BuildVersionedMessageError = BuildError || SdkBuildVersionedMessageError;
pub const BuildVersionedTransactionError = BuildVersionedMessageError || SignVersionedMessageError;

pub const AccountBinding = struct {
    path: []const u8,
    pubkey: sdk.Pubkey,
};

pub const BuildInstructionOptions = struct {
    program_id: ?sdk.Pubkey = null,
    args_json: ?[]const u8 = null,
    account_bindings: []const AccountBinding = &.{},
    account_bindings_json: ?[]const u8 = null,
    remaining_accounts: []const sdk.AccountMeta = &.{},
    remaining_accounts_json: ?[]const u8 = null,
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

const OwnedAccountBindings = struct {
    bindings: []AccountBinding,
    owned_paths: [][]u8,
    explicit_null_paths: []const []const u8,
    owned_explicit_null_paths: [][]u8,

    pub fn deinit(self: *OwnedAccountBindings, allocator: Allocator) void {
        for (self.owned_paths) |path| allocator.free(path);
        allocator.free(self.owned_paths);
        for (self.owned_explicit_null_paths) |path| allocator.free(path);
        allocator.free(self.owned_explicit_null_paths);
        allocator.free(self.explicit_null_paths);
        allocator.free(self.bindings);
        self.* = undefined;
    }
};

const OwnedRemainingAccounts = struct {
    metas: []sdk.AccountMeta,

    pub fn deinit(self: *OwnedRemainingAccounts, allocator: Allocator) void {
        allocator.free(self.metas);
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

fn jsonObjectField(object: std.json.ObjectMap, comptime keys: []const []const u8) ?std.json.Value {
    inline for (keys) |key| {
        if (findJsonObjectField(object, key)) |value| return value;
    }
    return null;
}

fn stringifyJsonValue(
    allocator: Allocator,
    value: std.json.Value,
) Allocator.Error![]u8 {
    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();
    std.json.Stringify.value(value, .{}, &json_buffer.writer) catch unreachable;
    return try allocator.dupe(u8, json_buffer.written());
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

fn hasExplicitNullBinding(explicit_null_paths: []const []const u8, full_name: []const u8, leaf_name: []const u8) bool {
    for (explicit_null_paths) |path| {
        if (fullPathMatches(path, full_name) or fullPathMatches(path, leaf_name)) return true;

        const normalized_path = normalizeAccountPath(path);
        if (!std.mem.eql(u8, normalized_path, path)) {
            if (fullPathMatches(normalized_path, full_name) or fullPathMatches(normalized_path, leaf_name)) {
                return true;
            }
        }
    }
    return false;
}

fn parseAccountBindingPubkeyValue(allocator: Allocator, value: std.json.Value) BuildError!?sdk.Pubkey {
    switch (value) {
        .null => return null,
        .string => return sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidAnchorIdlAccountSpec,
        .object => {
            inline for ([_][]const u8{
                "pubkey",
                "publicKey",
                "public_key",
                "address",
                "key",
                "programId",
                "program_id",
            }) |field_name| {
                if (findJsonObjectField(value.object, field_name)) |field_value| {
                    return switch (field_value) {
                        .null => null,
                        .string => sdk.Pubkey.fromBase58(allocator, field_value.string) catch return error.InvalidAnchorIdlAccountSpec,
                        else => return error.InvalidAnchorIdlAccountSpec,
                    };
                }
            }
            return null;
        },
        else => return null,
    }
}

fn parseBoolField(value: std.json.Value) BuildError!bool {
    return switch (value) {
        .bool => value.bool,
        else => error.InvalidAnchorIdlAccountSpec,
    };
}

fn parseRemainingAccountMeta(allocator: Allocator, value: std.json.Value) BuildError!sdk.AccountMeta {
    return switch (value) {
        .string => .{
            .pubkey = sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidAnchorIdlAccountSpec,
            .is_signer = false,
            .is_writable = false,
        },
        .object => blk: {
            const pubkey = if (try parseAccountBindingPubkeyValue(allocator, value)) |resolved|
                resolved
            else
                return error.InvalidAnchorIdlAccountSpec;

            var is_signer = false;
            inline for ([_][]const u8{ "isSigner", "is_signer", "signer" }) |field_name| {
                if (findJsonObjectField(value.object, field_name)) |field_value| {
                    is_signer = try parseBoolField(field_value);
                    break;
                }
            }

            var is_writable = false;
            inline for ([_][]const u8{ "isWritable", "is_writable", "writable" }) |field_name| {
                if (findJsonObjectField(value.object, field_name)) |field_value| {
                    is_writable = try parseBoolField(field_value);
                    break;
                }
            }

            break :blk .{
                .pubkey = pubkey,
                .is_signer = is_signer,
                .is_writable = is_writable,
            };
        },
        else => return error.InvalidAnchorIdlAccountSpec,
    };
}

fn appendJsonAccountBinding(
    allocator: Allocator,
    bindings: *std.ArrayListUnmanaged(AccountBinding),
    owned_paths: *std.ArrayListUnmanaged([]u8),
    path: []const u8,
    pubkey: sdk.Pubkey,
) BuildError!void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);

    try owned_paths.append(allocator, owned_path);
    errdefer _ = owned_paths.pop();

    try bindings.append(allocator, .{
        .path = owned_path,
        .pubkey = pubkey,
    });
}

fn appendExplicitNullPath(
    allocator: Allocator,
    explicit_null_paths: *std.ArrayListUnmanaged([]const u8),
    owned_explicit_null_paths: *std.ArrayListUnmanaged([]u8),
    path: []const u8,
) BuildError!void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);

    try owned_explicit_null_paths.append(allocator, owned_path);
    errdefer _ = owned_explicit_null_paths.pop();

    try explicit_null_paths.append(allocator, owned_path);
}

const ParsedJsonAccountBindingLiteral = struct {
    field_name: []const u8,
    pubkey: ?sdk.Pubkey = null,
};

fn parseAccountBindingLiteralObject(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!?ParsedJsonAccountBindingLiteral {
    if (value != .object) return null;

    inline for ([_][]const u8{
        "pubkey",
        "publicKey",
        "public_key",
        "address",
        "key",
        "programId",
        "program_id",
    }) |field_name| {
        if (findJsonObjectField(value.object, field_name)) |field_value| {
            return switch (field_value) {
                .null => .{
                    .field_name = field_name,
                    .pubkey = null,
                },
                .string => .{
                    .field_name = field_name,
                    .pubkey = sdk.Pubkey.fromBase58(allocator, field_value.string) catch return error.InvalidAnchorIdlAccountSpec,
                },
                else => return error.InvalidAnchorIdlAccountSpec,
            };
        }
    }

    return null;
}

fn appendAccountBindingsFromJsonValue(
    allocator: Allocator,
    bindings: *std.ArrayListUnmanaged(AccountBinding),
    owned_paths: *std.ArrayListUnmanaged([]u8),
    explicit_null_paths: *std.ArrayListUnmanaged([]const u8),
    owned_explicit_null_paths: *std.ArrayListUnmanaged([]u8),
    path: ?[]const u8,
    value: std.json.Value,
) BuildError!void {
    var consumed_literal_field_name: ?[]const u8 = null;

    if (path) |path_value| {
        if (value == .null) {
            try appendExplicitNullPath(allocator, explicit_null_paths, owned_explicit_null_paths, path_value);
            return;
        }
        if (value == .string) {
            if (sdk.Pubkey.fromBase58(allocator, value.string) catch null) |pubkey| {
                try appendJsonAccountBinding(allocator, bindings, owned_paths, path_value, pubkey);
            }
            return;
        } else if (try parseAccountBindingLiteralObject(allocator, value)) |literal| {
            consumed_literal_field_name = literal.field_name;
            if (literal.pubkey) |pubkey| {
                try appendJsonAccountBinding(allocator, bindings, owned_paths, path_value, pubkey);
            } else {
                try appendExplicitNullPath(allocator, explicit_null_paths, owned_explicit_null_paths, path_value);
            }
        } else if (try parseAccountBindingPubkeyValue(allocator, value)) |pubkey| {
            try appendJsonAccountBinding(allocator, bindings, owned_paths, path_value, pubkey);
            return;
        }
    } else if (value == .null) {
        return;
    }

    switch (value) {
        .object => {
            var iterator = value.object.iterator();
            while (iterator.next()) |entry| {
                if (consumed_literal_field_name) |field_name| {
                    if (pathSegmentMatches(field_name, entry.key_ptr.*)) continue;
                }

                const child_path = if (path) |path_value|
                    try std.fmt.allocPrint(allocator, "{s}.{s}", .{ path_value, entry.key_ptr.* })
                else
                    try allocator.dupe(u8, entry.key_ptr.*);
                defer allocator.free(child_path);

                try appendAccountBindingsFromJsonValue(
                    allocator,
                    bindings,
                    owned_paths,
                    explicit_null_paths,
                    owned_explicit_null_paths,
                    child_path,
                    entry.value_ptr.*,
                );
            }
        },
        .array => |items| {
            for (items.items, 0..) |item, index| {
                const child_path = if (path) |path_value|
                    try std.fmt.allocPrint(allocator, "{s}.{d}", .{ path_value, index })
                else
                    try std.fmt.allocPrint(allocator, "{d}", .{index});
                defer allocator.free(child_path);

                try appendAccountBindingsFromJsonValue(
                    allocator,
                    bindings,
                    owned_paths,
                    explicit_null_paths,
                    owned_explicit_null_paths,
                    child_path,
                    item,
                );
            }
        },
        .string => if (path == null) return error.InvalidAnchorIdlAccountSpec,
        else => {},
    }
}

fn parseAccountBindingsJson(allocator: Allocator, json_source: []const u8) BuildError!OwnedAccountBindings {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_source, .{}) catch return error.InvalidAnchorIdlAccountSpec;
    defer parsed.deinit();

    switch (parsed.value) {
        .object, .array, .null => {},
        else => return error.InvalidAnchorIdlAccountSpec,
    }

    var bindings: std.ArrayListUnmanaged(AccountBinding) = .{};
    errdefer bindings.deinit(allocator);
    var owned_paths: std.ArrayListUnmanaged([]u8) = .{};
    errdefer {
        for (owned_paths.items) |path| allocator.free(path);
        owned_paths.deinit(allocator);
    }
    var explicit_null_paths: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer explicit_null_paths.deinit(allocator);
    var owned_explicit_null_paths: std.ArrayListUnmanaged([]u8) = .{};
    errdefer {
        for (owned_explicit_null_paths.items) |path| allocator.free(path);
        owned_explicit_null_paths.deinit(allocator);
    }

    try appendAccountBindingsFromJsonValue(
        allocator,
        &bindings,
        &owned_paths,
        &explicit_null_paths,
        &owned_explicit_null_paths,
        null,
        parsed.value,
    );

    const owned_bindings = try bindings.toOwnedSlice(allocator);
    errdefer allocator.free(owned_bindings);
    const owned_paths_slice = try owned_paths.toOwnedSlice(allocator);
    errdefer {
        for (owned_paths_slice) |path| allocator.free(path);
        allocator.free(owned_paths_slice);
    }
    const explicit_null_paths_slice = try explicit_null_paths.toOwnedSlice(allocator);
    errdefer allocator.free(explicit_null_paths_slice);
    const owned_explicit_null_paths_slice = try owned_explicit_null_paths.toOwnedSlice(allocator);
    errdefer {
        for (owned_explicit_null_paths_slice) |path| allocator.free(path);
        allocator.free(owned_explicit_null_paths_slice);
    }

    return .{
        .bindings = owned_bindings,
        .owned_paths = owned_paths_slice,
        .explicit_null_paths = explicit_null_paths_slice,
        .owned_explicit_null_paths = owned_explicit_null_paths_slice,
    };
}

fn parseRemainingAccountsJson(allocator: Allocator, json_source: []const u8) BuildError!OwnedRemainingAccounts {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_source, .{}) catch return error.InvalidAnchorIdlAccountSpec;
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidAnchorIdlAccountSpec;

    const metas = try allocator.alloc(sdk.AccountMeta, parsed.value.array.items.len);
    errdefer allocator.free(metas);

    for (parsed.value.array.items, 0..) |item, index| {
        metas[index] = try parseRemainingAccountMeta(allocator, item);
    }

    return .{ .metas = metas };
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
        if (try decodePdaBytesValue(allocator, value)) |decoded| {
            defer allocator.free(decoded);
            try bytes.appendSlice(allocator, decoded);
            return;
        }
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

fn decodePdaBytesString(allocator: Allocator, value: []const u8) BuildError!?[]u8 {
    if (std.mem.startsWith(u8, value, "hex:")) {
        const hex_value = value[4..];
        if (hex_value.len % 2 != 0) return error.InvalidAnchorIdlAccountSpec;
        const decoded = try allocator.alloc(u8, hex_value.len / 2);
        errdefer allocator.free(decoded);
        _ = std.fmt.hexToBytes(decoded, hex_value) catch return error.InvalidAnchorIdlAccountSpec;
        return decoded;
    }
    if (std.mem.startsWith(u8, value, "0x")) {
        const hex_value = value[2..];
        if (hex_value.len % 2 != 0) return error.InvalidAnchorIdlAccountSpec;
        const decoded = try allocator.alloc(u8, hex_value.len / 2);
        errdefer allocator.free(decoded);
        _ = std.fmt.hexToBytes(decoded, hex_value) catch return error.InvalidAnchorIdlAccountSpec;
        return decoded;
    }
    if (std.mem.startsWith(u8, value, "base64:")) {
        const base64_value = value[7..];
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(base64_value) catch return error.InvalidAnchorIdlAccountSpec;
        const decoded = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(decoded);
        std.base64.standard.Decoder.decode(decoded, base64_value) catch return error.InvalidAnchorIdlAccountSpec;
        return decoded;
    }
    return null;
}

fn decodePdaBytesValue(allocator: Allocator, value: std.json.Value) BuildError!?[]u8 {
    switch (value) {
        .string => return try decodePdaBytesString(allocator, value.string),
        .object => {
            if (findJsonObjectField(value.object, "hex")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
                const wrapped = try std.mem.concat(allocator, u8, &.{ "hex:", field_value.string });
                defer allocator.free(wrapped);
                return try decodePdaBytesString(allocator, wrapped);
            }
            if (findJsonObjectField(value.object, "base64")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
                const wrapped = try std.mem.concat(allocator, u8, &.{ "base64:", field_value.string });
                defer allocator.free(wrapped);
                return try decodePdaBytesString(allocator, wrapped);
            }
            if (findJsonObjectField(value.object, "utf8")) |field_value| {
                if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
                return try allocator.dupe(u8, field_value.string);
            }
            return null;
        },
        else => return null,
    }
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

fn isPubkeySeedType(type_spec: std.json.Value) bool {
    return type_spec == .string and
        (std.mem.eql(u8, type_spec.string, "pubkey") or
            std.mem.eql(u8, type_spec.string, "publicKey") or
            std.mem.eql(u8, type_spec.string, "public_key"));
}

fn resolveBuiltinAccountAliasSeedType(account_name: []const u8, child_path: []const u8) ?std.json.Value {
    const field_name, const rest = if (std.mem.indexOfScalar(u8, child_path, '.')) |dot_index|
        .{ child_path[0..dot_index], child_path[dot_index + 1 ..] }
    else
        .{ child_path, "" };

    if (pathSegmentMatches(account_name, "tokenAccount")) {
        if (rest.len != 0 and pathSegmentMatches(field_name, "signers")) return null;
        if (pathSegmentMatches(field_name, "mint")) return .{ .string = "pubkey" };
        if (pathSegmentMatches(field_name, "owner")) return .{ .string = "pubkey" };
        if (pathSegmentMatches(field_name, "amount")) return .{ .string = "u64" };
        if (pathSegmentMatches(field_name, "delegate")) return .{ .string = "pubkey" };
        if (pathSegmentMatches(field_name, "state")) return .{ .string = "u8" };
        if (pathSegmentMatches(field_name, "isNative") or pathSegmentMatches(field_name, "is_native")) return .{ .string = "u64" };
        if (pathSegmentMatches(field_name, "delegatedAmount") or pathSegmentMatches(field_name, "delegated_amount")) return .{ .string = "u64" };
        if (pathSegmentMatches(field_name, "closeAuthority") or pathSegmentMatches(field_name, "close_authority")) return .{ .string = "pubkey" };
        return null;
    }

    if (pathSegmentMatches(account_name, "mint")) {
        if (pathSegmentMatches(field_name, "mintAuthority") or pathSegmentMatches(field_name, "mint_authority")) return .{ .string = "pubkey" };
        if (pathSegmentMatches(field_name, "supply")) return .{ .string = "u64" };
        if (pathSegmentMatches(field_name, "decimals")) return .{ .string = "u8" };
        if (pathSegmentMatches(field_name, "isInitialized") or pathSegmentMatches(field_name, "is_initialized")) return .{ .string = "bool" };
        if (pathSegmentMatches(field_name, "freezeAuthority") or pathSegmentMatches(field_name, "freeze_authority")) return .{ .string = "pubkey" };
        return null;
    }

    if (pathSegmentMatches(account_name, "multisig")) {
        if (pathSegmentMatches(field_name, "m")) return .{ .string = "u8" };
        if (pathSegmentMatches(field_name, "n")) return .{ .string = "u8" };
        if (pathSegmentMatches(field_name, "isInitialized") or pathSegmentMatches(field_name, "is_initialized")) return .{ .string = "bool" };
        if (pathSegmentMatches(field_name, "signers") and rest.len != 0) return .{ .string = "pubkey" };
        return null;
    }

    return null;
}

fn resolveAccountSeedType(
    idl: *const idl_types.Idl,
    seed_value: std.json.Value,
    path: []const u8,
) BuildError!?std.json.Value {
    if (seed_value != .object) return error.InvalidAnchorIdlAccountSpec;
    if (seed_value.object.get("type")) |type_spec| {
        return try resolvePdaSeedType(idl, type_spec, "");
    }

    const child_path = if (std.mem.indexOfScalar(u8, path, '.')) |dot_index|
        path[dot_index + 1 ..]
    else
        "";

    if (seed_value.object.get("account")) |account_value| {
        if (account_value != .string) return error.InvalidAnchorIdlAccountSpec;
        if (idl_types.findType(idl, account_value.string)) |type_def| {
            return try resolvePdaSeedType(idl, type_def.type, child_path);
        }
        if (resolveBuiltinAccountAliasSeedType(account_value.string, child_path)) |builtin_type| {
            return builtin_type;
        }
        return error.InvalidAnchorIdlAccountSpec;
    }

    const account_name = if (std.mem.indexOfScalar(u8, path, '.')) |dot_index|
        path[0..dot_index]
    else
        path;
    if (idl_types.findType(idl, account_name)) |type_def| {
        return try resolvePdaSeedType(idl, type_def.type, child_path);
    }

    return null;
}

fn encodePdaAccountSeed(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction: *const idl_types.Instruction,
    seed_value: std.json.Value,
    parsed_args: ?*const std.json.Value,
    account_bindings: []const AccountBinding,
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
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

    if (try resolveAccountSeedType(idl, seed_value, path_value.string)) |resolved_type_spec| {
        if (account_binding_values) |bindings_value| {
            if (findJsonValue(bindings_value, path_value.string)) |bound_value| {
                var bytes: std.ArrayListUnmanaged(u8) = .{};
                defer bytes.deinit(allocator);
                try appendPdaScalarSeed(allocator, &bytes, idl, resolved_type_spec, bound_value);
                return try allocator.dupe(u8, bytes.items);
            }
        }

        if (!isPubkeySeedType(resolved_type_spec)) {
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
        account_binding_values,
        explicit_null_paths,
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
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
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
                        account_binding_values,
                        explicit_null_paths,
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
                account_binding_values,
                explicit_null_paths,
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
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
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
            account_binding_values,
            explicit_null_paths,
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
            account_binding_values,
            explicit_null_paths,
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
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
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
        account_binding_values,
        explicit_null_paths,
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
            account_binding_values,
            explicit_null_paths,
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
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
    path: []const u8,
    program_id: sdk.Pubkey,
    default_signer_pubkey: ?sdk.Pubkey,
    resolution_stack: *std.ArrayListUnmanaged([]u8),
) BuildError!ResolvedAccountPubkey {
    const leaf_name = if (std.mem.lastIndexOfScalar(u8, path, '.')) |dot_index| path[dot_index + 1 ..] else path;
    if (findBoundPubkey(account_bindings, path, leaf_name)) |pubkey| {
        return .{ .pubkey = pubkey };
    }
    if (resolutionStackContains(resolution_stack, path)) return error.InvalidAnchorIdlAccountSpec;
    const owned_path = try allocator.dupe(u8, path);
    try resolution_stack.append(allocator, owned_path);
    defer allocator.free(resolution_stack.pop().?);

    const account_value = findAccountValue(accounts, path) orelse return error.MissingAnchorIdlAccountBinding;
    if (account_value != .object or account_value.object.get("accounts") != null) return error.InvalidAnchorIdlAccountSpec;
    const is_optional = try isOptionalAccount(account_value);
    if (hasExplicitNullBinding(explicit_null_paths, path, leaf_name)) {
        if (is_optional) return .{ .pubkey = program_id, .missing_optional = true };
        return error.MissingAnchorIdlAccountBinding;
    }
    if (try findLiteralPubkey(allocator, account_value)) |pubkey| return .{ .pubkey = pubkey };
    if (account_value.object.get("pda")) |pda_value| {
        return .{ .pubkey = try derivePda(allocator, idl, instruction, pda_value, parsed_args, account_bindings, account_binding_values, explicit_null_paths, program_id, default_signer_pubkey, resolution_stack) };
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
                    account_binding_values,
                    explicit_null_paths,
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
                account_binding_values,
                explicit_null_paths,
                relation_path,
                program_id,
                default_signer_pubkey,
                resolution_stack,
            )) |resolved| return resolved;
        }
    }

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
    else if (std.mem.eql(u8, account_name, "recentBlockhashes") or
        std.mem.eql(u8, account_name, "recent_blockhashes") or
        std.mem.eql(u8, account_name, "recentBlockhashesSysvar") or
        std.mem.eql(u8, account_name, "recent_blockhashes_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_recent_blockhashes") or
        std.mem.eql(u8, account_name, "recentBlockhashesSysvarId") or
        std.mem.eql(u8, account_name, "recent_blockhashes_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_recent_blockhashes_id"))
        "SysvarRecentB1ockHashes11111111111111111111"
    else if (std.mem.eql(u8, account_name, "slotHashes") or
        std.mem.eql(u8, account_name, "slot_hashes") or
        std.mem.eql(u8, account_name, "slotHashesSysvar") or
        std.mem.eql(u8, account_name, "slot_hashes_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_slot_hashes") or
        std.mem.eql(u8, account_name, "slotHashesSysvarId") or
        std.mem.eql(u8, account_name, "slot_hashes_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_slot_hashes_id"))
        "SysvarS1otHashes111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "epochSchedule") or
        std.mem.eql(u8, account_name, "epoch_schedule") or
        std.mem.eql(u8, account_name, "epochScheduleSysvar") or
        std.mem.eql(u8, account_name, "epoch_schedule_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_epoch_schedule") or
        std.mem.eql(u8, account_name, "epochScheduleSysvarId") or
        std.mem.eql(u8, account_name, "epoch_schedule_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_epoch_schedule_id"))
        "SysvarEpochSchedu1e111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "epochRewards") or
        std.mem.eql(u8, account_name, "epoch_rewards") or
        std.mem.eql(u8, account_name, "epochRewardsSysvar") or
        std.mem.eql(u8, account_name, "epoch_rewards_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_epoch_rewards") or
        std.mem.eql(u8, account_name, "epochRewardsSysvarId") or
        std.mem.eql(u8, account_name, "epoch_rewards_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_epoch_rewards_id"))
        "SysvarEpochRewards1111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "stakeHistory") or
        std.mem.eql(u8, account_name, "stake_history") or
        std.mem.eql(u8, account_name, "stakeHistorySysvar") or
        std.mem.eql(u8, account_name, "stake_history_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_stake_history") or
        std.mem.eql(u8, account_name, "stakeHistorySysvarId") or
        std.mem.eql(u8, account_name, "stake_history_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_stake_history_id"))
        "SysvarStakeHistory1111111111111111111111111"
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
    account_binding_values: ?*const std.json.Value,
    explicit_null_paths: []const []const u8,
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
                account_binding_values,
                explicit_null_paths,
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
            account_binding_values,
            explicit_null_paths,
            full_name,
            program_id,
            default_signer,
            resolution_stack,
        );

        appendOrUpgradeAccountMeta(
            metas,
            next_index,
            resolved.pubkey,
            if (resolved.missing_optional) false else is_signer,
            if (resolved.missing_optional) false else is_writable,
        );
    }
}

fn appendOrUpgradeAccountMeta(
    accounts: []sdk.AccountMeta,
    next_index: *usize,
    pubkey: sdk.Pubkey,
    is_signer: bool,
    is_writable: bool,
) void {
    for (accounts[0..next_index.*]) |*account| {
        if (account.pubkey.eql(pubkey)) {
            account.is_signer = account.is_signer or is_signer;
            account.is_writable = account.is_writable or is_writable;
            return;
        }
    }

    accounts[next_index.*] = .{
        .pubkey = pubkey,
        .is_signer = is_signer,
        .is_writable = is_writable,
    };
    next_index.* += 1;
}

fn dedupeSigners(allocator: Allocator, signers: []const sdk.Keypair) ![]sdk.Keypair {
    var deduped = std.ArrayListUnmanaged(sdk.Keypair){};
    try deduped.ensureTotalCapacity(allocator, signers.len);

    for (signers) |signer| {
        for (deduped.items) |existing_signer| {
            if (existing_signer.public_key.eql(signer.public_key)) break;
        } else {
            try deduped.append(allocator, signer);
        }
    }

    return try deduped.toOwnedSlice(allocator);
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
    const parsed_account_binding_values = if (options.account_bindings_json) |value|
        try std.json.parseFromSlice(std.json.Value, allocator, value, .{})
    else
        null;
    defer if (parsed_account_binding_values) |*value| value.deinit();

    var json_account_bindings = if (options.account_bindings_json) |value|
        try parseAccountBindingsJson(allocator, value)
    else
        null;
    defer if (json_account_bindings) |*value| value.deinit(allocator);

    var merged_account_bindings: ?[]AccountBinding = null;
    defer if (merged_account_bindings) |value| allocator.free(value);
    const resolved_account_bindings = if (json_account_bindings) |value| blk: {
        if (options.account_bindings.len == 0) break :blk value.bindings;
        if (value.bindings.len == 0) break :blk options.account_bindings;

        const merged = try allocator.alloc(AccountBinding, options.account_bindings.len + value.bindings.len);
        merged_account_bindings = merged;
        @memcpy(merged[0..options.account_bindings.len], options.account_bindings);
        @memcpy(merged[options.account_bindings.len..], value.bindings);
        break :blk merged;
    } else options.account_bindings;
    const resolved_explicit_null_paths: []const []const u8 = if (json_account_bindings) |value|
        value.explicit_null_paths
    else
        &.{};

    var json_remaining_accounts = if (options.remaining_accounts_json) |value|
        try parseRemainingAccountsJson(allocator, value)
    else
        null;
    defer if (json_remaining_accounts) |*value| value.deinit(allocator);

    var merged_remaining_accounts: ?[]sdk.AccountMeta = null;
    defer if (merged_remaining_accounts) |value| allocator.free(value);
    const resolved_remaining_accounts = if (json_remaining_accounts) |value| blk: {
        if (options.remaining_accounts.len == 0) break :blk value.metas;
        if (value.metas.len == 0) break :blk options.remaining_accounts;

        const merged = try allocator.alloc(sdk.AccountMeta, value.metas.len + options.remaining_accounts.len);
        merged_remaining_accounts = merged;
        @memcpy(merged[0..value.metas.len], value.metas);
        @memcpy(merged[value.metas.len..], options.remaining_accounts);
        break :blk merged;
    } else options.remaining_accounts;

    const leaf_account_count = try countLeafAccounts(instruction.accounts);
    const accounts = try allocator.alloc(sdk.AccountMeta, leaf_account_count + resolved_remaining_accounts.len);
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
        resolved_account_bindings,
        if (parsed_account_binding_values) |value| &value.value else null,
        resolved_explicit_null_paths,
        options.default_signer,
        program_id,
        accounts,
        &next_index,
        &resolution_stack,
        null,
    );
    for (resolved_remaining_accounts) |remaining_account| {
        appendOrUpgradeAccountMeta(
            accounts,
            &next_index,
            remaining_account.pubkey,
            remaining_account.is_signer,
            remaining_account.is_writable,
        );
    }

    const final_accounts = if (next_index == accounts.len)
        accounts[0..next_index]
    else
        try allocator.dupe(sdk.AccountMeta, accounts[0..next_index]);

    if (next_index != accounts.len) {
        allocator.free(accounts);
    }

    return .{
        .instruction = .{
            .program_id = program_id,
            .accounts = final_accounts,
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

pub const BuildLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    signers: []const sdk.Keypair,
    instruction_options: BuildInstructionOptions = .{},
};

pub const BuildVersionedMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction_options: BuildInstructionOptions = .{},
};

pub const BuildLegacyMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instruction_options: BuildInstructionOptions = .{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction_options: BuildInstructionOptions = .{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction_options: BuildInstructionOptions = .{},
};

pub const BuildLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction_options: BuildInstructionOptions = .{},
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction_options: BuildInstructionOptions = .{},
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction_options: BuildInstructionOptions = .{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction_options: BuildInstructionOptions = .{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const SendOptions = struct {
    transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateOptions = struct {
    transaction_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmOptions = struct {
    transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = true,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const AnchorIdlInvocationSpecRpcOptions = struct {
    anchor_idl_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const SendAnchorIdlInvocationSpecRpcOptions = struct {
    anchor_idl_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateAnchorIdlInvocationSpecRpcOptions = struct {
    anchor_idl_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmAnchorIdlInvocationSpecRpcOptions = struct {
    anchor_idl_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = true,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const GetFeeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
};

pub fn buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
    allocator: Allocator,
    anchor_idl_invocation_spec_json: []const u8,
) BuildError![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, anchor_idl_invocation_spec_json, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    const object = switch (parsed.value) {
        .object => parsed.value.object,
        else => return error.InvalidInvocationSpec,
    };

    const payer_secret_key_value = jsonObjectField(object, &.{ "payer_secret_key", "payerSecretKey" }) orelse
        return error.InvalidInvocationSpec;
    if (payer_secret_key_value != .string) return error.InvalidInvocationSpec;
    const payer_keypair = sdk.Keypair.fromBase58SecretKey(allocator, payer_secret_key_value.string) catch {
        return error.InvalidInvocationSpec;
    };

    const default_signer_secret_key_value = jsonObjectField(object, &.{ "default_signer_secret_key", "defaultSignerSecretKey" });
    const default_signer_keypair = if (default_signer_secret_key_value) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk sdk.Keypair.fromBase58SecretKey(allocator, value.string) catch return error.InvalidInvocationSpec;
    } else payer_keypair;
    const default_signer_secret_key = if (default_signer_secret_key_value) |value| value.string else payer_secret_key_value.string;

    const idl_value = jsonObjectField(object, &.{ "idl", "idl_json", "idlJson" }) orelse
        return error.InvalidInvocationSpec;
    var owned_idl_json_source: ?[]u8 = null;
    defer if (owned_idl_json_source) |value| allocator.free(value);
    const idl_json_source = switch (idl_value) {
        .string => idl_value.string,
        else => blk: {
            const encoded = try stringifyJsonValue(allocator, idl_value);
            owned_idl_json_source = encoded;
            break :blk encoded;
        },
    };

    const instruction_name_value = jsonObjectField(object, &.{ "instruction_name", "instructionName" }) orelse
        return error.InvalidInvocationSpec;
    if (instruction_name_value != .string) return error.InvalidInvocationSpec;

    const program_id = if (jsonObjectField(object, &.{ "program_id", "programId" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidInvocationSpec;
    } else null;

    var owned_args_json: ?[]u8 = null;
    defer if (owned_args_json) |value| allocator.free(value);
    const args_json = if (jsonObjectField(object, &.{ "args_json", "argsJson" })) |value| blk: {
        break :blk switch (value) {
            .string => value.string,
            else => source: {
                const encoded = try stringifyJsonValue(allocator, value);
                owned_args_json = encoded;
                break :source encoded;
            },
        };
    } else if (jsonObjectField(object, &.{"args"})) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_args_json = encoded;
        break :blk encoded;
    } else null;

    var owned_account_bindings_json: ?[]u8 = null;
    defer if (owned_account_bindings_json) |value| allocator.free(value);
    const account_bindings_json = if (jsonObjectField(object, &.{ "account_bindings_json", "accountBindingsJson" })) |value| blk: {
        break :blk switch (value) {
            .string => value.string,
            else => source: {
                const encoded = try stringifyJsonValue(allocator, value);
                owned_account_bindings_json = encoded;
                break :source encoded;
            },
        };
    } else if (jsonObjectField(object, &.{ "account_bindings", "accountBindings" })) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_account_bindings_json = encoded;
        break :blk encoded;
    } else null;

    var owned_remaining_accounts_json: ?[]u8 = null;
    defer if (owned_remaining_accounts_json) |value| allocator.free(value);
    const remaining_accounts_json = if (jsonObjectField(object, &.{ "remaining_accounts_json", "remainingAccountsJson" })) |value| blk: {
        break :blk switch (value) {
            .string => value.string,
            else => source: {
                const encoded = try stringifyJsonValue(allocator, value);
                owned_remaining_accounts_json = encoded;
                break :source encoded;
            },
        };
    } else if (jsonObjectField(object, &.{ "remaining_accounts", "remainingAccounts" })) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_remaining_accounts_json = encoded;
        break :blk encoded;
    } else null;

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        idl_json_source,
        instruction_name_value.string,
        .{
            .program_id = program_id,
            .args_json = args_json,
            .account_bindings_json = account_bindings_json,
            .remaining_accounts_json = remaining_accounts_json,
            .default_signer = default_signer_keypair.public_key,
        },
    );
    defer owned_instruction.deinit(allocator);

    const instruction_program_id = try owned_instruction.instruction.program_id.toBase58(allocator);
    defer allocator.free(instruction_program_id);
    const instruction_data_base64 = try sdk.encodeBase64(allocator, owned_instruction.instruction.data);
    defer allocator.free(instruction_data_base64);

    const additional_signers_value = jsonObjectField(object, &.{ "additional_signer_secret_keys", "additionalSignerSecretKeys" });
    const include_default_signer = !std.mem.eql(u8, default_signer_secret_key, payer_secret_key_value.string);
    var owned_additional_signers_json: ?[]u8 = null;
    defer if (owned_additional_signers_json) |value| allocator.free(value);
    const additional_signer_secret_keys_json = if (include_default_signer or additional_signers_value != null) blk: {
        var json_buffer: std.io.Writer.Allocating = .init(allocator);
        defer json_buffer.deinit();
        try json_buffer.writer.writeByte('[');
        var wrote_signer = false;
        if (include_default_signer) {
            try std.json.Stringify.value(default_signer_secret_key, .{}, &json_buffer.writer);
            wrote_signer = true;
        }
        if (additional_signers_value) |value| {
            if (value != .array) return error.InvalidInvocationSpec;
            for (value.array.items) |secret_key_value| {
                if (secret_key_value != .string) return error.InvalidInvocationSpec;
                if (std.mem.eql(u8, secret_key_value.string, payer_secret_key_value.string)) continue;
                if (std.mem.eql(u8, secret_key_value.string, default_signer_secret_key)) continue;
                if (wrote_signer) try json_buffer.writer.writeByte(',');
                try std.json.Stringify.value(secret_key_value.string, .{}, &json_buffer.writer);
                wrote_signer = true;
            }
        }
        try json_buffer.writer.writeByte(']');
        const encoded = try allocator.dupe(u8, json_buffer.written());
        owned_additional_signers_json = encoded;
        break :blk encoded;
    } else null;

    var owned_lookup_tables_json: ?[]u8 = null;
    defer if (owned_lookup_tables_json) |value| allocator.free(value);
    const address_lookup_tables_json = if (jsonObjectField(object, &.{ "address_lookup_tables", "addressLookupTables" })) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_lookup_tables_json = encoded;
        break :blk encoded;
    } else null;

    const recent_blockhash = if (jsonObjectField(object, &.{ "recent_blockhash", "recentBlockhash" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk value.string;
    } else null;
    const nonce_account = if (jsonObjectField(object, &.{ "nonce_account", "nonceAccount" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk value.string;
    } else null;
    const nonce_authority_secret_key = if (jsonObjectField(object, &.{ "nonce_authority_secret_key", "nonceAuthoritySecretKey" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk value.string;
    } else null;

    var accounts_json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer accounts_json_buffer.deinit();
    try accounts_json_buffer.writer.writeByte('[');
    for (owned_instruction.instruction.accounts, 0..) |account, index| {
        if (index != 0) try accounts_json_buffer.writer.writeByte(',');
        const account_pubkey = try account.pubkey.toBase58(allocator);
        defer allocator.free(account_pubkey);

        try accounts_json_buffer.writer.writeByte('{');
        var has_account_field = false;
        try invocation_spec_json.writeFieldName(&accounts_json_buffer, &has_account_field, "pubkey");
        try std.json.Stringify.value(account_pubkey, .{}, &accounts_json_buffer.writer);
        try invocation_spec_json.writeFieldName(&accounts_json_buffer, &has_account_field, "is_signer");
        try std.json.Stringify.value(account.is_signer, .{}, &accounts_json_buffer.writer);
        try invocation_spec_json.writeFieldName(&accounts_json_buffer, &has_account_field, "is_writable");
        try std.json.Stringify.value(account.is_writable, .{}, &accounts_json_buffer.writer);
        try accounts_json_buffer.writer.writeByte('}');
    }
    try accounts_json_buffer.writer.writeByte(']');
    const accounts_json = try allocator.dupe(u8, accounts_json_buffer.written());
    defer allocator.free(accounts_json);

    return try invocation_spec_json.buildInstructionInvocationSpecJson(allocator, .{
        .payer_secret_key = payer_secret_key_value.string,
        .additional_signer_secret_keys_json = additional_signer_secret_keys_json,
        .address_lookup_tables_json = address_lookup_tables_json,
        .recent_blockhash = recent_blockhash,
        .nonce_account = nonce_account,
        .nonce_authority_secret_key = nonce_authority_secret_key,
        .instruction = .{
            .program_id = instruction_program_id,
            .accounts_json = accounts_json,
            .data = instruction_data_base64,
            .data_encoding = "base64",
        },
    });
}

pub fn sendLegacyTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) !sdk.OwnedLegacyMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBytesFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBase64FromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) !sdk.SignedLegacyTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn simulateLegacyTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SimulateAnchorIdlInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAndConfirmAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAndConfirmAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForLegacyMessageFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.getFeeForLegacyMessageFromInvocationSpecJson(
        rpc,
        .{
            .instruction_spec_json = instruction_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        },
        .{ .commitment = fee_options.commitment },
    );
}

pub fn sendVersionedTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBytesFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBase64FromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) !sdk.SignedVersionedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn simulateVersionedTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SimulateAnchorIdlInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAndConfirmAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: SendAndConfirmAnchorIdlInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForVersionedMessageFromInvocationSpecJson(
    rpc: anytype,
    allocator: Allocator,
    options: AnchorIdlInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
        allocator,
        options.anchor_idl_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try instructions_invoke.getFeeForVersionedMessageFromInvocationSpecJson(
        rpc,
        .{
            .instruction_spec_json = instruction_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        },
        .{ .commitment = fee_options.commitment },
    );
}

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

pub fn buildOwnedLegacyMessageWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.buildOwnedLegacyMessageWithBlockhashQuery(
        options.payer,
        &.{owned_instruction.instruction},
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildOwnedLegacyMessageWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) !sdk.OwnedLegacyMessage {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedLegacyMessageWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn buildLegacyMessageBytesWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned = try buildOwnedLegacyMessageWithBlockhashQuery(
        rpc,
        allocator,
        idl,
        instruction_name,
        options,
    );
    defer owned.deinit(allocator);

    return try owned.serialize(allocator);
}

pub fn buildLegacyMessageBytesWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildLegacyMessageBytesWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn buildLegacyMessageBase64WithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.buildLegacyMessageBase64WithBlockhashQuery(
        options.payer,
        &.{owned_instruction.instruction},
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildLegacyMessageBase64WithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildLegacyMessageBase64WithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn getFeeForLegacyMessageWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyMessageWithBlockhashQueryOptions,
    options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        build_options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.getFeeForLegacyInstructionsWithBlockhashQuery(
        build_options.payer,
        &.{owned_instruction.instruction},
        build_options.blockhash_query,
        build_options.nonce_authority,
        options.commitment,
    );
}

pub fn getFeeForLegacyMessageWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyMessageWithBlockhashQueryOptions,
    options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try getFeeForLegacyMessageWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn buildSignedLegacyTransaction(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyTransactionOptions,
) BuildLegacyTransactionError!sdk.SignedLegacyTransaction {
    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    var owned_message = try buildOwnedLegacyMessage(
        allocator,
        idl,
        instruction_name,
        .{
            .payer = options.payer,
            .recent_blockhash = options.recent_blockhash,
            .instruction_options = options.instruction_options,
        },
    );
    defer owned_message.deinit(allocator);

    return try owned_message.sign(allocator, signers);
}

pub fn buildSignedLegacyTransactionFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyTransactionOptions,
) BuildLegacyTransactionError!sdk.SignedLegacyTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildSignedLegacyTransaction(allocator, &parsed_idl.value, instruction_name, options);
}

pub fn buildLegacyTransactionBase64(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildLegacyTransactionOptions,
) BuildLegacyTransactionError![]u8 {
    var signed = try buildSignedLegacyTransaction(allocator, idl, instruction_name, options);
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildLegacyTransactionBase64FromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildLegacyTransactionOptions,
) BuildLegacyTransactionError![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildLegacyTransactionBase64(allocator, &parsed_idl.value, instruction_name, options);
}

pub fn buildOwnedVersionedMessage(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedMessageOptions,
) BuildVersionedMessageError!sdk.OwnedVersionedMessageV0 {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try sdk.buildVersionedMessageV0(
        allocator,
        options.payer,
        options.recent_blockhash,
        &.{owned_instruction.instruction},
        options.address_lookup_tables,
    );
}

pub fn buildOwnedVersionedMessageFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedMessageOptions,
) BuildVersionedMessageError!sdk.OwnedVersionedMessageV0 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedVersionedMessage(allocator, &parsed_idl.value, instruction_name, options);
}

pub fn buildOwnedVersionedMessageWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.buildOwnedVersionedMessageWithBlockhashQuery(
        options.payer,
        &.{owned_instruction.instruction},
        options.address_lookup_tables,
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildOwnedVersionedMessageWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) !sdk.OwnedVersionedMessageV0 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedVersionedMessageWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn buildVersionedMessageBytesWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned = try buildOwnedVersionedMessageWithBlockhashQuery(
        rpc,
        allocator,
        idl,
        instruction_name,
        options,
    );
    defer owned.deinit(allocator);

    return try owned.serialize(allocator);
}

pub fn buildVersionedMessageBytesWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildVersionedMessageBytesWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn buildVersionedMessageBase64WithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.buildVersionedMessageBase64WithBlockhashQuery(
        options.payer,
        &.{owned_instruction.instruction},
        options.address_lookup_tables,
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildVersionedMessageBase64WithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildVersionedMessageBase64WithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        options,
    );
}

pub fn getFeeForVersionedMessageWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedMessageWithBlockhashQueryOptions,
    options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        idl,
        instruction_name,
        build_options.instruction_options,
    );
    defer owned_instruction.deinit(allocator);

    return try rpc.getFeeForVersionedInstructionsWithBlockhashQuery(
        build_options.payer,
        &.{owned_instruction.instruction},
        build_options.address_lookup_tables,
        build_options.blockhash_query,
        build_options.nonce_authority,
        options.commitment,
    );
}

pub fn getFeeForVersionedMessageWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedMessageWithBlockhashQueryOptions,
    options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try getFeeForVersionedMessageWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn buildSignedVersionedTransaction(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedTransactionOptions,
) BuildVersionedTransactionError!sdk.SignedVersionedTransaction {
    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    var owned_message = try buildOwnedVersionedMessage(
        allocator,
        idl,
        instruction_name,
        .{
            .payer = options.payer,
            .recent_blockhash = options.recent_blockhash,
            .address_lookup_tables = options.address_lookup_tables,
            .instruction_options = options.instruction_options,
        },
    );
    defer owned_message.deinit(allocator);

    return try owned_message.sign(allocator, signers);
}

pub fn buildSignedVersionedTransactionFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedTransactionOptions,
) BuildVersionedTransactionError!sdk.SignedVersionedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildSignedVersionedTransaction(allocator, &parsed_idl.value, instruction_name, options);
}

pub fn buildVersionedTransactionBase64(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildVersionedTransactionOptions,
) BuildVersionedTransactionError![]u8 {
    var signed = try buildSignedVersionedTransaction(allocator, idl, instruction_name, options);
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildVersionedTransactionBase64FromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildVersionedTransactionOptions,
) BuildVersionedTransactionError![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildVersionedTransactionBase64(allocator, &parsed_idl.value, instruction_name, options);
}

pub fn sendLegacyTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendOptions,
) ![]const u8 {
    var signed = try buildSignedLegacyTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendTransactionTyped(signed, options.transaction_options);
}

pub fn sendLegacyTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendLegacyTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn simulateLegacyTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    var signed = try buildSignedLegacyTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.simulateTransactionTyped(signed, options.transaction_options);
}

pub fn simulateLegacyTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateLegacyTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmLegacyTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    var signed = try buildSignedLegacyTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendTransactionAndConfirmTyped(
        signed,
        options.transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmLegacyTransactionWithSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    var signed = try buildSignedLegacyTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendTransactionAndConfirmTypedWithSpinner(
        signed,
        options.transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransactionWithSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendVersionedTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendOptions,
) ![]const u8 {
    var signed = try buildSignedVersionedTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendVersionedTransactionTyped(signed, options.transaction_options);
}

pub fn sendVersionedTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendVersionedTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn simulateVersionedTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    var signed = try buildSignedVersionedTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.simulateVersionedTransactionTyped(signed, options.transaction_options);
}

pub fn simulateVersionedTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateVersionedTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmVersionedTransaction(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    var signed = try buildSignedVersionedTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendAndConfirmVersionedTransactionTyped(
        signed,
        options.transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransaction(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmVersionedTransactionWithSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    var signed = try buildSignedVersionedTransaction(allocator, idl, instruction_name, build_options);
    defer signed.deinit(allocator);

    return try rpc.sendAndConfirmVersionedTransactionTypedWithSpinner(
        signed,
        options.transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransactionWithSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn buildSignedLegacyTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
) !sdk.SignedLegacyTransaction {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.buildSignedLegacyTransactionWithBlockhashQuery(
        build_options.payer,
        instructions[0..],
        signers,
        build_options.blockhash_query,
        build_options.nonce_authority,
    );
}

pub fn buildSignedLegacyTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
) !sdk.SignedLegacyTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildSignedLegacyTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
    );
}

pub fn buildLegacyTransactionBase64WithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
) ![]u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.buildLegacyTransactionBase64WithBlockhashQuery(
        build_options.payer,
        instructions[0..],
        signers,
        build_options.blockhash_query,
        build_options.nonce_authority,
    );
}

pub fn buildLegacyTransactionBase64WithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildLegacyTransactionBase64WithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
    );
}

pub fn buildSignedVersionedTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
) !sdk.SignedVersionedTransaction {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.buildSignedVersionedTransactionWithBlockhashQuery(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        build_options.blockhash_query,
        build_options.nonce_authority,
    );
}

pub fn buildSignedVersionedTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
) !sdk.SignedVersionedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildSignedVersionedTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
    );
}

pub fn buildVersionedTransactionBase64WithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
) ![]u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.buildVersionedTransactionBase64WithBlockhashQuery(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        build_options.blockhash_query,
        build_options.nonce_authority,
    );
}

pub fn buildVersionedTransactionBase64WithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
) ![]u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildVersionedTransactionBase64WithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
    );
}

pub fn sendLegacyTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendLegacyInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
        },
    );
}

pub fn sendLegacyTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendLegacyTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn simulateLegacyTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.simulateLegacyInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
        },
        options.transaction_options,
    );
}

pub fn simulateLegacyTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateLegacyTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendAndConfirmLegacyInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        build_options.payer,
        instructions[0..],
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendVersionedTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendVersionedInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
        },
    );
}

pub fn sendVersionedTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendVersionedTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn simulateVersionedTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.simulateVersionedInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
        },
        options.transaction_options,
    );
}

pub fn simulateVersionedTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateVersionedTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQuery(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendAndConfirmVersionedInstructionsWithOptions(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransactionWithBlockhashQuery(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const signers = try dedupeSigners(allocator, build_options.signers);
    defer allocator.free(signers);

    var owned_instruction = try buildOwnedInstruction(allocator, idl, instruction_name, build_options.instruction_options);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try rpc.sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
        build_options.payer,
        instructions[0..],
        build_options.address_lookup_tables,
        signers,
        .{
            .blockhash_query = build_options.blockhash_query,
            .nonce_authority = build_options.nonce_authority,
            .send_transaction_options = options.transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithBlockhashQueryOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

fn resolveLatestBlockhash(rpc: anytype, allocator: Allocator, commitment: ?rpc_types.Commitment) !sdk.Hash {
    const latest = try rpc.getLatestBlockhash(commitment);
    defer rpc.allocator.free(latest.blockhash);
    return try sdk.Hash.fromBase58(allocator, latest.blockhash);
}

fn buildLegacyTransactionOptionsWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) !BuildLegacyTransactionOptions {
    return .{
        .payer = options.payer,
        .recent_blockhash = try resolveLatestBlockhash(rpc, allocator, options.blockhash_commitment),
        .signers = options.signers,
        .instruction_options = options.instruction_options,
    };
}

fn buildVersionedTransactionOptionsWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) !BuildVersionedTransactionOptions {
    return .{
        .payer = options.payer,
        .recent_blockhash = try resolveLatestBlockhash(rpc, allocator, options.blockhash_commitment),
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .instruction_options = options.instruction_options,
    };
}

pub fn sendLegacyTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendOptions,
) ![]const u8 {
    return try sendLegacyTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildLegacyTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendLegacyTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendLegacyTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn simulateLegacyTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildLegacyTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn simulateLegacyTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateLegacyTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildLegacyTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithSpinner(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildLegacyTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildLegacyTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

pub fn sendVersionedTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendOptions,
) ![]const u8 {
    return try sendVersionedTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildVersionedTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendVersionedTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendVersionedTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn simulateVersionedTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildVersionedTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn simulateVersionedTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SimulateOptions,
) !rpc_types.SimulatedTransaction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try simulateVersionedTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhash(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransaction(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildVersionedTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransactionWithLatestBlockhash(rpc, allocator, &parsed_idl.value, instruction_name, build_options, options);
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(
    rpc: anytype,
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithSpinner(
        rpc,
        allocator,
        idl,
        instruction_name,
        try buildVersionedTransactionOptionsWithLatestBlockhash(rpc, allocator, build_options),
        options,
    );
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinnerFromJson(
    rpc: anytype,
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    build_options: BuildVersionedTransactionWithLatestBlockhashOptions,
    options: SendAndConfirmOptions,
) ![]const u8 {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(
        rpc,
        allocator,
        &parsed_idl.value,
        instruction_name,
        build_options,
        options,
    );
}

test "anchor_idl_invoke.buildOwnedInstructionFromJson resolves flat dotted account binding values for typed account seeds" {
    const allocator = std.testing.allocator;

    const state = sdk.Pubkey.fromBytes(.{71} ** 32);
    const state_base58 = try state.toBase58(allocator);
    defer allocator.free(state_base58);
    const program_id = sdk.Pubkey.fromBytes(.{72} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"init","discriminator":[1,1,1,1,1,1,1,1],"accounts":[{{"name":"state"}},{{"name":"vault","writable":true,"pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}},{{"kind":"account","path":"state.counter","type":"u64"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"state\":\"{s}\",\"state.counter\":\"18446744073709551615\"}}",
        .{state_base58},
    );
    defer allocator.free(account_bindings_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "init",
        .{ .account_bindings_json = account_bindings_json },
    );
    defer owned_instruction.deinit(allocator);

    var counter_seed: [8]u8 = undefined;
    std.mem.writeInt(u64, &counter_seed, std.math.maxInt(u64), .little);
    const expected_pda = try findProgramAddress(allocator, &.{ "vault", &counter_seed }, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(state));
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(expected_pda));
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
}

test "anchor_idl_invoke.buildOwnedInstructionFromJson infers tokenAccount alias seed types" {
    const allocator = std.testing.allocator;

    const token = sdk.Pubkey.fromBytes(.{73} ** 32);
    const token_base58 = try token.toBase58(allocator);
    defer allocator.free(token_base58);
    const program_id = sdk.Pubkey.fromBytes(.{74} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"init","discriminator":[2,2,2,2,2,2,2,2],"accounts":[{{"name":"token"}},{{"name":"vault","writable":true,"pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}},{{"kind":"account","path":"token.amount","account":"tokenAccount"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"token\":{{\"address\":\"{s}\",\"amount\":\"18446744073709551615\"}}}}",
        .{token_base58},
    );
    defer allocator.free(account_bindings_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "init",
        .{ .account_bindings_json = account_bindings_json },
    );
    defer owned_instruction.deinit(allocator);

    var amount_seed: [8]u8 = undefined;
    std.mem.writeInt(u64, &amount_seed, std.math.maxInt(u64), .little);
    const expected_pda = try findProgramAddress(allocator, &.{ "vault", &amount_seed }, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(token));
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(expected_pda));
}

test "anchor_idl_invoke.buildOwnedInstructionFromJson infers mint alias seed types" {
    const allocator = std.testing.allocator;

    const mint = sdk.Pubkey.fromBytes(.{75} ** 32);
    const mint_base58 = try mint.toBase58(allocator);
    defer allocator.free(mint_base58);
    const program_id = sdk.Pubkey.fromBytes(.{76} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"init","discriminator":[3,3,3,3,3,3,3,3],"accounts":[{{"name":"mint"}},{{"name":"vault","writable":true,"pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}},{{"kind":"account","path":"mint.is_initialized","account":"Mint"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"mint\":{{\"address\":\"{s}\",\"is_initialized\":true}}}}",
        .{mint_base58},
    );
    defer allocator.free(account_bindings_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "init",
        .{ .account_bindings_json = account_bindings_json },
    );
    defer owned_instruction.deinit(allocator);

    const expected_pda = try findProgramAddress(allocator, &.{ "vault", &.{1} }, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(mint));
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(expected_pda));
}

test "anchor_idl_invoke.buildOwnedInstructionFromJson infers multisig alias seed types" {
    const allocator = std.testing.allocator;

    const multisig = sdk.Pubkey.fromBytes(.{77} ** 32);
    const multisig_base58 = try multisig.toBase58(allocator);
    defer allocator.free(multisig_base58);
    const signer_one = sdk.Pubkey.fromBytes(.{78} ** 32);
    const signer_one_base58 = try signer_one.toBase58(allocator);
    defer allocator.free(signer_one_base58);
    const signer_two = sdk.Pubkey.fromBytes(.{79} ** 32);
    const signer_two_base58 = try signer_two.toBase58(allocator);
    defer allocator.free(signer_two_base58);
    const program_id = sdk.Pubkey.fromBytes(.{80} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"init","discriminator":[4,4,4,4,4,4,4,4],"accounts":[{{"name":"multisig"}},{{"name":"vault","writable":true,"pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}},{{"kind":"account","path":"multisig.signers.1","account":"Multisig"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"multisig\":{{\"address\":\"{s}\",\"signers\":[\"{s}\",\"{s}\"]}}}}",
        .{ multisig_base58, signer_one_base58, signer_two_base58 },
    );
    defer allocator.free(account_bindings_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "init",
        .{ .account_bindings_json = account_bindings_json },
    );
    defer owned_instruction.deinit(allocator);

    const expected_pda = try findProgramAddress(allocator, &.{ "vault", signer_two.bytes[0..] }, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(multisig));
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(expected_pda));
}
