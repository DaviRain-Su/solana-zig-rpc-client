const std = @import("std");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const BuildError = Allocator.Error || error{
    InvalidInvocationSpec,
    WriteFailed,
};

pub const InstructionJson = struct {
    program_id: []const u8,
    accounts_json: ?[]const u8 = null,
    data: ?[]const u8 = null,
    data_encoding: ?[]const u8 = null,
    data_bytes_json: ?[]const u8 = null,
};

pub const BuildInstructionInvocationSpecJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
    instruction: InstructionJson,
};

pub const BuildInvocationSpecJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
    instructions_json: []const u8,
};

pub const BuildProgramInvocationSpecJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
    program_id: []const u8,
    accounts_json: ?[]const u8 = null,
    data: ?[]const u8 = null,
    data_encoding: ?[]const u8 = null,
    data_bytes_json: ?[]const u8 = null,
    data_schema_json: ?[]const u8 = null,
    args_json: ?[]const u8 = null,
    schema_encoding: ?[]const u8 = null,
};

pub const BuildAnchorIdlInvocationSpecJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
    idl_json: []const u8,
    instruction_name: []const u8,
    program_id: ?[]const u8 = null,
    args_json: ?[]const u8 = null,
    account_bindings_json: ?[]const u8 = null,
    remaining_accounts_json: ?[]const u8 = null,
};

pub const InvocationContextJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
};

const JsonFragmentKind = enum {
    any,
    object,
    array,
};

fn validateJsonFragment(
    allocator: Allocator,
    source: []const u8,
    comptime expected_kind: JsonFragmentKind,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    switch (expected_kind) {
        .any => {},
        .object => if (parsed.value != .object) return error.InvalidInvocationSpec,
        .array => if (parsed.value != .array) return error.InvalidInvocationSpec,
    }
}

fn validateJsonStringArray(
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidInvocationSpec;
    for (parsed.value.array.items) |item| {
        if (item != .string) return error.InvalidInvocationSpec;
    }
}

fn parseCanonicalJsonSecretKeyBytes(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
    return switch (value) {
        .array => |array| blk: {
            const bytes = try allocator.alloc(u8, array.items.len);
            errdefer allocator.free(bytes);

            for (array.items, 0..) |item, index| {
                if (item != .integer or item.integer < 0 or item.integer > 255) {
                    return error.InvalidInvocationSpec;
                }
                bytes[index] = @intCast(item.integer);
            }

            break :blk bytes;
        },
        .object => |object| blk: {
            if (jsonObjectField(&object, &.{ "bytes", "secretKeyBytes", "secret_key_bytes" })) |field| {
                break :blk try parseCanonicalJsonSecretKeyBytes(allocator, field);
            }
            return error.InvalidInvocationSpec;
        },
        else => error.InvalidInvocationSpec,
    };
}

fn parseCanonicalSignerSecretKeyString(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
    return switch (value) {
        .string => try allocator.dupe(u8, value.string),
        .array => blk: {
            const bytes = try parseCanonicalJsonSecretKeyBytes(allocator, value);
            defer allocator.free(bytes);
            break :blk try sdk.encodeBase58(allocator, bytes);
        },
        .object => |object| blk: {
            if (jsonObjectField(&object, &.{
                "base58",
                "secretKey",
                "secret_key",
                "privateKey",
                "private_key",
            })) |field| {
                break :blk try parseCanonicalSignerSecretKeyString(allocator, field);
            }
            if (jsonObjectField(&object, &.{ "bytes", "secretKeyBytes", "secret_key_bytes" })) |field| {
                break :blk try parseCanonicalSignerSecretKeyString(allocator, field);
            }
            return error.InvalidInvocationSpec;
        },
        else => error.InvalidInvocationSpec,
    };
}

fn validateJsonObjectArray(
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidInvocationSpec;
    for (parsed.value.array.items) |item| {
        if (item != .object) return error.InvalidInvocationSpec;
    }
}

fn validateJsonSignerSecretKeyArray(
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidInvocationSpec;
    for (parsed.value.array.items) |item| {
        const canonical = try parseCanonicalSignerSecretKeyString(allocator, item);
        defer allocator.free(canonical);
    }
}

fn validateJsonObjectOrStringArray(
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidInvocationSpec;
    for (parsed.value.array.items) |item| {
        switch (item) {
            .object, .string => {},
            else => return error.InvalidInvocationSpec,
        }
    }
}

fn validateJsonByteFragment(
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    const decoded = try parseCanonicalJsonByteArray(allocator, parsed.value);
    defer allocator.free(decoded);
}

fn writeCanonicalJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
    comptime expected_kind: JsonFragmentKind,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();

    switch (expected_kind) {
        .any => {},
        .object => if (parsed.value != .object) return error.InvalidInvocationSpec,
        .array => if (parsed.value != .array) return error.InvalidInvocationSpec,
    }

    try std.json.Stringify.value(parsed.value, .{}, &buffer.writer);
}

fn writeCanonicalSignerSecretKeysJsonValue(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    value: std.json.Value,
) BuildError!void {
    if (value != .array) return error.InvalidInvocationSpec;

    try buffer.writer.writeByte('[');
    for (value.array.items, 0..) |item, index| {
        if (index != 0) try buffer.writer.writeByte(',');

        const canonical = try parseCanonicalSignerSecretKeyString(allocator, item);
        defer allocator.free(canonical);
        try std.json.Stringify.value(canonical, .{}, &buffer.writer);
    }
    try buffer.writer.writeByte(']');
}

fn writeCanonicalSignerSecretKeysJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalSignerSecretKeysJsonValue(buffer, allocator, parsed.value);
}

fn jsonObjectField(
    object: *const std.json.ObjectMap,
    comptime names: []const []const u8,
) ?std.json.Value {
    inline for (names) |name| {
        if (object.get(name)) |value| return value;
    }
    return null;
}

fn parseRelaxedJsonBool(value: std.json.Value) BuildError!bool {
    return switch (value) {
        .bool => value.bool,
        .string => {
            if (std.ascii.eqlIgnoreCase(value.string, "true")) return true;
            if (std.ascii.eqlIgnoreCase(value.string, "false")) return false;
            return error.InvalidInvocationSpec;
        },
        else => error.InvalidInvocationSpec,
    };
}

fn parseRelaxedJsonPubkeyString(value: std.json.Value) BuildError![]const u8 {
    return switch (value) {
        .string => value.string,
        .object => {
            const field = jsonObjectField(&value.object, &.{
                "pubkey",
                "publicKey",
                "public_key",
                "address",
                "key",
                "base58",
                "programId",
                "program_id",
                "accountKey",
                "account_key",
            }) orelse return error.InvalidInvocationSpec;
            if (field != .string) return error.InvalidInvocationSpec;
            return field.string;
        },
        else => error.InvalidInvocationSpec,
    };
}

fn parseHexByteData(
    allocator: Allocator,
    encoded: []const u8,
) BuildError![]u8 {
    const trimmed = if (std.mem.startsWith(u8, encoded, "0x") or std.mem.startsWith(u8, encoded, "0X"))
        encoded[2..]
    else
        encoded;
    if (trimmed.len % 2 != 0) return error.InvalidInvocationSpec;

    const decoded = try allocator.alloc(u8, trimmed.len / 2);
    errdefer allocator.free(decoded);
    _ = std.fmt.hexToBytes(decoded, trimmed) catch return error.InvalidInvocationSpec;
    return decoded;
}

fn parseBase64ByteData(
    allocator: Allocator,
    encoded: []const u8,
) BuildError![]u8 {
    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(encoded) catch return error.InvalidInvocationSpec;
    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    decoder.decode(decoded, encoded) catch return error.InvalidInvocationSpec;
    return decoded;
}

fn parseJsonByteString(
    allocator: Allocator,
    string: []const u8,
) BuildError!?[]u8 {
    if (std.mem.startsWith(u8, string, "hex:")) {
        return try parseHexByteData(allocator, string["hex:".len..]);
    }
    if (std.mem.startsWith(u8, string, "base64:")) {
        return try parseBase64ByteData(allocator, string["base64:".len..]);
    }
    if (std.mem.startsWith(u8, string, "utf8:")) {
        return try allocator.dupe(u8, string["utf8:".len..]);
    }
    if (std.mem.startsWith(u8, string, "0x") or std.mem.startsWith(u8, string, "0X")) {
        return try parseHexByteData(allocator, string);
    }
    return null;
}

fn parseCanonicalJsonByteArray(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
    return switch (value) {
        .array => |array| blk: {
            const bytes = try allocator.alloc(u8, array.items.len);
            errdefer allocator.free(bytes);

            for (array.items, 0..) |item, index| {
                if (item != .integer or item.integer < 0 or item.integer > 255) {
                    return error.InvalidInvocationSpec;
                }
                bytes[index] = @intCast(item.integer);
            }

            break :blk bytes;
        },
        .string => |string| try parseJsonByteString(allocator, string) orelse error.InvalidInvocationSpec,
        .object => |object| blk: {
            if (jsonObjectField(&object, &.{"bytes"})) |field| {
                break :blk try parseCanonicalJsonByteArray(allocator, field);
            }
            if (jsonObjectField(&object, &.{"hex"})) |field| {
                if (field != .string) return error.InvalidInvocationSpec;
                break :blk try parseHexByteData(allocator, field.string);
            }
            if (jsonObjectField(&object, &.{"base64"})) |field| {
                if (field != .string) return error.InvalidInvocationSpec;
                break :blk try parseBase64ByteData(allocator, field.string);
            }
            if (jsonObjectField(&object, &.{"utf8"})) |field| {
                if (field != .string) return error.InvalidInvocationSpec;
                break :blk try allocator.dupe(u8, field.string);
            }
            return error.InvalidInvocationSpec;
        },
        else => error.InvalidInvocationSpec,
    };
}

fn writeCanonicalDataBytesJsonValue(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    value: std.json.Value,
) BuildError!void {
    const bytes = try parseCanonicalJsonByteArray(allocator, value);
    defer allocator.free(bytes);

    try buffer.writer.writeByte('[');
    for (bytes, 0..) |byte, index| {
        if (index != 0) try buffer.writer.writeByte(',');
        try std.json.Stringify.value(byte, .{}, &buffer.writer);
    }
    try buffer.writer.writeByte(']');
}

fn writeCanonicalDataBytesJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalDataBytesJsonValue(buffer, allocator, parsed.value);
}

const ParsedAccountMetaString = struct {
    pubkey: []const u8,
    is_signer: bool = false,
    is_writable: bool = false,
};

fn parseAccountMetaString(value: []const u8) BuildError!ParsedAccountMetaString {
    const colon_index = std.mem.lastIndexOfScalar(u8, value, ':') orelse return .{ .pubkey = value };
    if (colon_index == 0 or colon_index + 1 >= value.len) return error.InvalidInvocationSpec;

    var parsed: ParsedAccountMetaString = .{
        .pubkey = value[0..colon_index],
    };
    for (value[colon_index + 1 ..]) |flag| {
        switch (std.ascii.toLower(flag)) {
            's' => parsed.is_signer = true,
            'w' => parsed.is_writable = true,
            else => return error.InvalidInvocationSpec,
        }
    }
    return parsed;
}

fn writeCanonicalAccountsJsonValue(
    buffer: *std.io.Writer.Allocating,
    value: std.json.Value,
) BuildError!void {
    if (value != .array) return error.InvalidInvocationSpec;

    try buffer.writer.writeByte('[');
    for (value.array.items, 0..) |item, index| {
        if (index != 0) try buffer.writer.writeByte(',');

        const pubkey, const is_signer, const is_writable = switch (item) {
            .string => blk: {
                const parsed = try parseAccountMetaString(item.string);
                break :blk .{ parsed.pubkey, parsed.is_signer, parsed.is_writable };
            },
            .object => .{
                try parseRelaxedJsonPubkeyString(
                    jsonObjectField(&item.object, &.{
                        "pubkey",
                        "publicKey",
                        "public_key",
                        "address",
                        "key",
                    }) orelse return error.InvalidInvocationSpec,
                ),
                if (jsonObjectField(&item.object, &.{ "isSigner", "is_signer", "signer" })) |field|
                    try parseRelaxedJsonBool(field)
                else
                    false,
                if (jsonObjectField(&item.object, &.{ "isWritable", "is_writable", "writable" })) |field|
                    try parseRelaxedJsonBool(field)
                else
                    false,
            },
            else => return error.InvalidInvocationSpec,
        };

        try buffer.writer.writeByte('{');
        try std.json.Stringify.value("pubkey", .{}, &buffer.writer);
        try buffer.writer.writeByte(':');
        try std.json.Stringify.value(pubkey, .{}, &buffer.writer);
        try buffer.writer.writeByte(',');
        try std.json.Stringify.value("is_signer", .{}, &buffer.writer);
        try buffer.writer.writeByte(':');
        try buffer.writer.writeAll(if (is_signer) "true" else "false");
        try buffer.writer.writeByte(',');
        try std.json.Stringify.value("is_writable", .{}, &buffer.writer);
        try buffer.writer.writeByte(':');
        try buffer.writer.writeAll(if (is_writable) "true" else "false");
        try buffer.writer.writeByte('}');
    }
    try buffer.writer.writeByte(']');
}

fn writeCanonicalAccountsJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalAccountsJsonValue(buffer, parsed.value);
}

fn canonicalAccountBindingFieldName(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "key")) return "pubkey";
    if (std.mem.eql(u8, name, "pubkey")) return "pubkey";
    if (std.mem.eql(u8, name, "publicKey")) return "pubkey";
    if (std.mem.eql(u8, name, "public_key")) return "pubkey";
    if (std.mem.eql(u8, name, "address")) return "pubkey";
    if (std.mem.eql(u8, name, "programId")) return "pubkey";
    if (std.mem.eql(u8, name, "program_id")) return "pubkey";

    if (std.mem.endsWith(u8, name, ".key")) return name[0 .. name.len - 4];
    if (std.mem.endsWith(u8, name, ".pubkey")) return name[0 .. name.len - 7];
    if (std.mem.endsWith(u8, name, ".publicKey")) return name[0 .. name.len - 10];
    if (std.mem.endsWith(u8, name, ".public_key")) return name[0 .. name.len - 11];
    if (std.mem.endsWith(u8, name, ".address")) return name[0 .. name.len - 8];
    if (std.mem.endsWith(u8, name, ".programId")) return name[0 .. name.len - 10];
    if (std.mem.endsWith(u8, name, ".program_id")) return name[0 .. name.len - 11];
    return name;
}

fn writeCanonicalAccountBindingsJsonValue(
    buffer: *std.io.Writer.Allocating,
    value: std.json.Value,
) BuildError!void {
    switch (value) {
        .object => |object| {
            try buffer.writer.writeByte('{');
            var iterator = object.iterator();
            var first = true;
            while (iterator.next()) |entry| {
                if (!first) try buffer.writer.writeByte(',');
                first = false;
                try std.json.Stringify.value(
                    canonicalAccountBindingFieldName(entry.key_ptr.*),
                    .{},
                    &buffer.writer,
                );
                try buffer.writer.writeByte(':');
                try writeCanonicalAccountBindingsJsonValue(buffer, entry.value_ptr.*);
            }
            try buffer.writer.writeByte('}');
        },
        .array => |array| {
            try buffer.writer.writeByte('[');
            for (array.items, 0..) |item, index| {
                if (index != 0) try buffer.writer.writeByte(',');
                try writeCanonicalAccountBindingsJsonValue(buffer, item);
            }
            try buffer.writer.writeByte(']');
        },
        else => try std.json.Stringify.value(value, .{}, &buffer.writer),
    }
}

fn writeCanonicalAccountBindingsJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalAccountBindingsJsonValue(buffer, parsed.value);
}

fn writeCanonicalAddressLookupTablesJsonValue(
    buffer: *std.io.Writer.Allocating,
    value: std.json.Value,
) BuildError!void {
    if (value != .array) return error.InvalidInvocationSpec;

    try buffer.writer.writeByte('[');
    for (value.array.items, 0..) |item, index| {
        if (index != 0) try buffer.writer.writeByte(',');
        if (item != .object) return error.InvalidInvocationSpec;

        const account_key = try parseRelaxedJsonPubkeyString(
            jsonObjectField(&item.object, &.{ "account_key", "accountKey" }) orelse return error.InvalidInvocationSpec,
        );
        const addresses_value = jsonObjectField(&item.object, &.{"addresses"}) orelse return error.InvalidInvocationSpec;
        if (addresses_value != .array) return error.InvalidInvocationSpec;

        try buffer.writer.writeByte('{');
        try std.json.Stringify.value("account_key", .{}, &buffer.writer);
        try buffer.writer.writeByte(':');
        try std.json.Stringify.value(account_key, .{}, &buffer.writer);
        try buffer.writer.writeByte(',');
        try std.json.Stringify.value("addresses", .{}, &buffer.writer);
        try buffer.writer.writeByte(':');
        try buffer.writer.writeByte('[');
        for (addresses_value.array.items, 0..) |address_value, address_index| {
            if (address_index != 0) try buffer.writer.writeByte(',');
            try std.json.Stringify.value(try parseRelaxedJsonPubkeyString(address_value), .{}, &buffer.writer);
        }
        try buffer.writer.writeByte(']');
        try buffer.writer.writeByte('}');
    }
    try buffer.writer.writeByte(']');
}

fn writeCanonicalAddressLookupTablesJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalAddressLookupTablesJsonValue(buffer, parsed.value);
}

fn writeCanonicalInstructionsJsonValue(
    buffer: *std.io.Writer.Allocating,
    value: std.json.Value,
) BuildError!void {
    if (value != .array) return error.InvalidInvocationSpec;

    try buffer.writer.writeByte('[');
    for (value.array.items, 0..) |item, index| {
        if (index != 0) try buffer.writer.writeByte(',');
        if (item != .object) return error.InvalidInvocationSpec;

        const program_id = try parseRelaxedJsonPubkeyString(
            jsonObjectField(&item.object, &.{ "program_id", "programId" }) orelse return error.InvalidInvocationSpec,
        );
        const data = jsonObjectField(&item.object, &.{"data"});
        const data_encoding = jsonObjectField(&item.object, &.{ "data_encoding", "dataEncoding", "encoding" });
        const data_bytes = jsonObjectField(&item.object, &.{ "data_bytes", "dataBytes" });

        if (data != null and data_bytes != null) return error.InvalidInvocationSpec;
        if (data_encoding != null and data == null) return error.InvalidInvocationSpec;

        try buffer.writer.writeByte('{');
        var has_field = false;

        try writeFieldName(buffer, &has_field, "program_id");
        try std.json.Stringify.value(program_id, .{}, &buffer.writer);

        if (jsonObjectField(&item.object, &.{"accounts"})) |accounts_value| {
            try writeFieldName(buffer, &has_field, "accounts");
            try writeCanonicalAccountsJsonValue(buffer, accounts_value);
        }
        if (data) |data_value| {
            if (data_value != .string) return error.InvalidInvocationSpec;
            try writeFieldName(buffer, &has_field, "data");
            try std.json.Stringify.value(data_value.string, .{}, &buffer.writer);
        }
        if (data_encoding) |encoding_value| {
            if (encoding_value != .string) return error.InvalidInvocationSpec;
            try writeFieldName(buffer, &has_field, "data_encoding");
            try std.json.Stringify.value(encoding_value.string, .{}, &buffer.writer);
        }
        if (data_bytes) |data_bytes_value| {
            try writeFieldName(buffer, &has_field, "data_bytes");
            try writeCanonicalDataBytesJsonValue(buffer, buffer.allocator, data_bytes_value);
        }

        try buffer.writer.writeByte('}');
    }
    try buffer.writer.writeByte(']');
}

fn writeCanonicalInstructionsJsonFragment(
    buffer: *std.io.Writer.Allocating,
    allocator: Allocator,
    source: []const u8,
) BuildError!void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidInvocationSpec;
    defer parsed.deinit();
    try writeCanonicalInstructionsJsonValue(buffer, parsed.value);
}

fn validateInvocationContextOptions(
    allocator: Allocator,
    options: InvocationContextJsonOptions,
) BuildError!void {
    if (options.recent_blockhash != null and options.nonce_account != null) {
        return error.InvalidInvocationSpec;
    }
    if (options.nonce_authority_secret_key != null and options.nonce_account == null) {
        return error.InvalidInvocationSpec;
    }
    if (options.additional_signer_secret_keys_json) |value| {
        try validateJsonSignerSecretKeyArray(allocator, value);
    }
    if (options.address_lookup_tables_json) |value| {
        try validateJsonObjectArray(allocator, value);
    }
}

pub fn writeFieldName(
    buffer: *std.io.Writer.Allocating,
    has_field_ptr: *bool,
    name: []const u8,
) !void {
    if (has_field_ptr.*) try buffer.writer.writeByte(',');
    try std.json.Stringify.value(name, .{}, &buffer.writer);
    try buffer.writer.writeByte(':');
    has_field_ptr.* = true;
}

pub fn writeInvocationContextFields(
    buffer: *std.io.Writer.Allocating,
    has_field_ptr: *bool,
    options: InvocationContextJsonOptions,
) !void {
    try writeFieldName(buffer, has_field_ptr, "payer_secret_key");
    try std.json.Stringify.value(options.payer_secret_key, .{}, &buffer.writer);

    if (options.additional_signer_secret_keys_json) |value| {
        try writeFieldName(buffer, has_field_ptr, "additional_signer_secret_keys");
        try writeCanonicalSignerSecretKeysJsonFragment(buffer, buffer.allocator, value);
    }
    if (options.address_lookup_tables_json) |value| {
        try writeFieldName(buffer, has_field_ptr, "address_lookup_tables");
        try writeCanonicalAddressLookupTablesJsonFragment(buffer, buffer.allocator, value);
    }
    if (options.recent_blockhash) |value| {
        try writeFieldName(buffer, has_field_ptr, "recent_blockhash");
        try std.json.Stringify.value(value, .{}, &buffer.writer);
    }
    if (options.nonce_account) |value| {
        try writeFieldName(buffer, has_field_ptr, "nonce_account");
        try std.json.Stringify.value(value, .{}, &buffer.writer);
    }
    if (options.nonce_authority_secret_key) |value| {
        try writeFieldName(buffer, has_field_ptr, "nonce_authority_secret_key");
        try std.json.Stringify.value(value, .{}, &buffer.writer);
    }
}

pub fn buildInstructionInvocationSpecJson(
    allocator: Allocator,
    options: BuildInstructionInvocationSpecJsonOptions,
) BuildError![]u8 {
    if (options.instruction.data != null and options.instruction.data_bytes_json != null) {
        return error.InvalidInvocationSpec;
    }
    if (options.instruction.data_encoding != null and options.instruction.data == null) {
        return error.InvalidInvocationSpec;
    }
    try validateInvocationContextOptions(allocator, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });
    if (options.instruction.accounts_json) |value| {
        try validateJsonObjectOrStringArray(allocator, value);
    }
    if (options.instruction.data_bytes_json) |value| {
        try validateJsonByteFragment(allocator, value);
    }

    var instruction_buffer: std.io.Writer.Allocating = .init(allocator);
    defer instruction_buffer.deinit();
    try instruction_buffer.writer.writeByte('[');
    try instruction_buffer.writer.writeByte('{');
    var has_instruction_field = false;

    try writeFieldName(&instruction_buffer, &has_instruction_field, "program_id");
    try std.json.Stringify.value(options.instruction.program_id, .{}, &instruction_buffer.writer);

    if (options.instruction.accounts_json) |value| {
        try writeFieldName(&instruction_buffer, &has_instruction_field, "accounts");
        try writeCanonicalAccountsJsonFragment(&instruction_buffer, allocator, value);
    }
    if (options.instruction.data) |value| {
        try writeFieldName(&instruction_buffer, &has_instruction_field, "data");
        try std.json.Stringify.value(value, .{}, &instruction_buffer.writer);
    }
    if (options.instruction.data_encoding) |value| {
        try writeFieldName(&instruction_buffer, &has_instruction_field, "data_encoding");
        try std.json.Stringify.value(value, .{}, &instruction_buffer.writer);
    }
    if (options.instruction.data_bytes_json) |value| {
        try writeFieldName(&instruction_buffer, &has_instruction_field, "data_bytes");
        try writeCanonicalDataBytesJsonFragment(&instruction_buffer, allocator, value);
    }

    try instruction_buffer.writer.writeByte('}');
    try instruction_buffer.writer.writeByte(']');

    return try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
        .instructions_json = instruction_buffer.written(),
    });
}

pub fn buildProgramInvocationSpecJson(
    allocator: Allocator,
    options: BuildProgramInvocationSpecJsonOptions,
) BuildError![]u8 {
    if (options.data != null and options.data_bytes_json != null) {
        return error.InvalidInvocationSpec;
    }
    if ((options.data != null or options.data_bytes_json != null) and
        (options.data_schema_json != null or options.args_json != null))
    {
        return error.InvalidInvocationSpec;
    }
    if (options.data_encoding != null and options.data == null) {
        return error.InvalidInvocationSpec;
    }
    if ((options.data_schema_json == null) != (options.args_json == null)) {
        return error.InvalidInvocationSpec;
    }
    if (options.schema_encoding != null and options.data_schema_json == null) {
        return error.InvalidInvocationSpec;
    }
    try validateInvocationContextOptions(allocator, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });
    if (options.accounts_json) |value| {
        try validateJsonObjectOrStringArray(allocator, value);
    }
    if (options.data_bytes_json) |value| {
        try validateJsonByteFragment(allocator, value);
    }
    if (options.data_schema_json) |value| {
        try validateJsonFragment(allocator, value, .any);
    }
    if (options.args_json) |value| {
        try validateJsonFragment(allocator, value, .any);
    }

    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('{');
    var has_field = false;
    try writeInvocationContextFields(&json_buffer, &has_field, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });

    try writeFieldName(&json_buffer, &has_field, "program_id");
    try std.json.Stringify.value(options.program_id, .{}, &json_buffer.writer);

    if (options.accounts_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "accounts");
        try writeCanonicalAccountsJsonFragment(&json_buffer, allocator, value);
    }
    if (options.data) |value| {
        try writeFieldName(&json_buffer, &has_field, "data");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (options.data_encoding) |value| {
        try writeFieldName(&json_buffer, &has_field, "data_encoding");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (options.data_bytes_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "data_bytes");
        try writeCanonicalDataBytesJsonFragment(&json_buffer, allocator, value);
    }
    if (options.data_schema_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "data_schema");
        try writeCanonicalJsonFragment(&json_buffer, allocator, value, .any);
    }
    if (options.args_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "args");
        try writeCanonicalJsonFragment(&json_buffer, allocator, value, .any);
    }
    if (options.schema_encoding) |value| {
        try writeFieldName(&json_buffer, &has_field, "schema_encoding");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }

    try json_buffer.writer.writeByte('}');
    return try allocator.dupe(u8, json_buffer.written());
}

pub fn buildAnchorIdlInvocationSpecJson(
    allocator: Allocator,
    options: BuildAnchorIdlInvocationSpecJsonOptions,
) BuildError![]u8 {
    try validateInvocationContextOptions(allocator, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });
    try validateJsonFragment(allocator, options.idl_json, .object);
    if (options.args_json) |value| {
        try validateJsonFragment(allocator, value, .any);
    }
    if (options.account_bindings_json) |value| {
        try validateJsonFragment(allocator, value, .any);
    }
    if (options.remaining_accounts_json) |value| {
        try validateJsonFragment(allocator, value, .array);
    }

    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('{');
    var has_field = false;
    try writeInvocationContextFields(&json_buffer, &has_field, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });

    try writeFieldName(&json_buffer, &has_field, "idl");
    try writeCanonicalJsonFragment(&json_buffer, allocator, options.idl_json, .object);

    try writeFieldName(&json_buffer, &has_field, "instruction_name");
    try std.json.Stringify.value(options.instruction_name, .{}, &json_buffer.writer);

    if (options.program_id) |value| {
        try writeFieldName(&json_buffer, &has_field, "program_id");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (options.args_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "args");
        try writeCanonicalJsonFragment(&json_buffer, allocator, value, .any);
    }
    if (options.account_bindings_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "account_bindings");
        try writeCanonicalAccountBindingsJsonFragment(&json_buffer, allocator, value);
    }
    if (options.remaining_accounts_json) |value| {
        try writeFieldName(&json_buffer, &has_field, "remaining_accounts");
        try writeCanonicalAccountsJsonFragment(&json_buffer, allocator, value);
    }

    try json_buffer.writer.writeByte('}');
    return try allocator.dupe(u8, json_buffer.written());
}

pub fn buildInvocationSpecJson(
    allocator: Allocator,
    options: BuildInvocationSpecJsonOptions,
) BuildError![]u8 {
    try validateInvocationContextOptions(allocator, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });
    try validateJsonFragment(allocator, options.instructions_json, .array);
    try validateJsonObjectArray(allocator, options.instructions_json);

    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('{');
    var has_field = false;
    try writeInvocationContextFields(&json_buffer, &has_field, .{
        .payer_secret_key = options.payer_secret_key,
        .additional_signer_secret_keys_json = options.additional_signer_secret_keys_json,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .recent_blockhash = options.recent_blockhash,
        .nonce_account = options.nonce_account,
        .nonce_authority_secret_key = options.nonce_authority_secret_key,
    });

    try writeFieldName(&json_buffer, &has_field, "instructions");
    try writeCanonicalInstructionsJsonFragment(&json_buffer, allocator, options.instructions_json);
    try json_buffer.writer.writeByte('}');

    return try allocator.dupe(u8, json_buffer.written());
}

test "invocation_spec_json.buildInstructionInvocationSpecJson writes canonical outer and instruction fields" {
    const allocator = std.testing.allocator;

    const encoded = try buildInstructionInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = "[\"extra-signer\"]",
        .address_lookup_tables_json = "[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]",
        .recent_blockhash = "recent-blockhash",
        .instruction = .{
            .program_id = "program-id",
            .accounts_json = "[{\"pubkey\":\"acct\",\"is_signer\":true,\"is_writable\":false}]",
            .data = "AQ==",
            .data_encoding = "base64",
        },
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"payer_secret_key\":\"payer-secret\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"extra-signer\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"address_lookup_tables\":[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"recent_blockhash\":\"recent-blockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accounts\":[{\"pubkey\":\"acct\",\"is_signer\":true,\"is_writable\":false}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data\":\"AQ==\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data_encoding\":\"base64\"") != null);
}

test "invocation_spec_json.buildInstructionInvocationSpecJson rejects conflicting data inputs" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildInstructionInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .instruction = .{
                .program_id = "program-id",
                .data = "AQ==",
                .data_bytes_json = "[1,2,3]",
            },
        }),
    );
}

test "invocation_spec_json.buildInstructionInvocationSpecJson rejects malformed accounts json" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildInstructionInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .instruction = .{
                .program_id = "program-id",
                .accounts_json = "{\"pubkey\":\"acct\"}",
            },
        }),
    );
}

test "invocation_spec_json.buildInstructionInvocationSpecJson rejects scalar data_bytes json" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildInstructionInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .instruction = .{
                .program_id = "program-id",
                .data_bytes_json = "123",
            },
        }),
    );
}

test "invocation_spec_json.buildInstructionInvocationSpecJson canonicalizes data_bytes wrappers" {
    const allocator = std.testing.allocator;

    const encoded = try buildInstructionInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .instruction = .{
            .program_id = "program-id",
            .data_bytes_json =
            \\{
            \\  "base64": "AQI="
            \\}
            ,
        },
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\",\"data_bytes\":[1,2]}]") != null);
}

test "invocation_spec_json.buildInvocationSpecJson writes canonical outer fields for instruction arrays" {
    const allocator = std.testing.allocator;

    const encoded = try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = "[\"extra-signer\"]",
        .recent_blockhash = "recent-blockhash",
        .instructions_json = "[{\"program_id\":\"program-id\",\"data\":\"AQ==\",\"data_encoding\":\"base64\"}]",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"payer_secret_key\":\"payer-secret\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"extra-signer\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"recent_blockhash\":\"recent-blockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\",\"data\":\"AQ==\",\"data_encoding\":\"base64\"}]") != null);
}

test "invocation_spec_json.buildInvocationSpecJson rejects conflicting recent blockhash and nonce" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .recent_blockhash = "recent-blockhash",
            .nonce_account = "nonce-account",
            .instructions_json = "[]",
        }),
    );
}

test "invocation_spec_json.buildInvocationSpecJson rejects non-object instruction entries" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .instructions_json = "[1]",
        }),
    );
}

test "invocation_spec_json.buildInvocationSpecJson canonicalizes instruction json fragments" {
    const allocator = std.testing.allocator;

    const encoded = try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .instructions_json =
        \\[
        \\  {
        \\    "program_id": "program-id",
        \\    "accounts": [ { "pubkey": "acct" } ]
        \\  }
        \\]
        ,
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "  ") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\",\"accounts\":[{\"pubkey\":\"acct\",\"is_signer\":false,\"is_writable\":false}]}]") != null);
}

test "invocation_spec_json.buildInvocationSpecJson canonicalizes instruction aliases and account shorthands" {
    const allocator = std.testing.allocator;

    const encoded = try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .instructions_json =
        \\[
        \\  {
        \\    "programId": {"address":"program-id"},
        \\    "accounts": [
        \\      "acct-a",
        \\      {"publicKey":"acct-b","signer":"true","writable":"false"}
        \\    ],
        \\    "data": "AQ==",
        \\    "encoding": "base64"
        \\  }
        \\]
        ,
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\",\"accounts\":[{\"pubkey\":\"acct-a\",\"is_signer\":false,\"is_writable\":false},{\"pubkey\":\"acct-b\",\"is_signer\":true,\"is_writable\":false}],\"data\":\"AQ==\",\"data_encoding\":\"base64\"}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"programId\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"encoding\"") == null);
}

test "invocation_spec_json.buildInvocationSpecJson canonicalizes instruction data_bytes wrappers" {
    const allocator = std.testing.allocator;

    const encoded = try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .instructions_json =
        \\[
        \\  {
        \\    "programId": "program-id",
        \\    "dataBytes": "utf8:hi"
        \\  }
        \\]
        ,
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instructions\":[{\"program_id\":\"program-id\",\"data_bytes\":[104,105]}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"dataBytes\"") == null);
}

test "invocation_spec_json.buildInvocationSpecJson canonicalizes relaxed additional signer wrappers" {
    const allocator = std.testing.allocator;

    const extra_signer = try sdk.Keypair.fromSecretKeyBytes(.{44} ** 32);
    const extra_signer_secret_key = extra_signer.secret_key.toBytes();
    const extra_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_signer_secret_key);
    defer allocator.free(extra_signer_secret_key_base58);

    var bytes_buffer: std.io.Writer.Allocating = .init(allocator);
    defer bytes_buffer.deinit();
    try bytes_buffer.writer.writeByte('[');
    for (extra_signer_secret_key, 0..) |byte, index| {
        if (index != 0) try bytes_buffer.writer.writeByte(',');
        try bytes_buffer.writer.print("{d}", .{byte});
    }
    try bytes_buffer.writer.writeByte(']');

    const additional_signers_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"secretKey\":\"{s}\"}},{{\"bytes\":{s}}}]",
        .{ extra_signer_secret_key_base58, bytes_buffer.written() },
    );
    defer allocator.free(additional_signers_json);

    const encoded = try buildInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = additional_signers_json,
        .instructions_json = "[{\"program_id\":\"program-id\"}]",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"") != null);
    const expected = try std.fmt.allocPrint(
        allocator,
        "\"additional_signer_secret_keys\":[\"{s}\",\"{s}\"]",
        .{ extra_signer_secret_key_base58, extra_signer_secret_key_base58 },
    );
    defer allocator.free(expected);
    try std.testing.expect(std.mem.indexOf(u8, encoded, expected) != null);
}

test "invocation_spec_json.buildAnchorIdlInvocationSpecJson writes canonical anchor invocation fields" {
    const allocator = std.testing.allocator;

    const encoded = try buildAnchorIdlInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = "[\"extra-signer\"]",
        .address_lookup_tables_json = "[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]",
        .recent_blockhash = "recent-blockhash",
        .idl_json = "{\"address\":\"program-id\"}",
        .instruction_name = "initialize",
        .program_id = "override-program-id",
        .args_json = "{\"amount\":42}",
        .account_bindings_json = "{\"payer\":\"payer-pubkey\"}",
        .remaining_accounts_json = "[{\"pubkey\":\"extra\",\"is_signer\":false,\"is_writable\":true}]",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"payer_secret_key\":\"payer-secret\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"extra-signer\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"address_lookup_tables\":[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"recent_blockhash\":\"recent-blockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"idl\":{\"address\":\"program-id\"}") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"instruction_name\":\"initialize\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"program_id\":\"override-program-id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"args\":{\"amount\":42}") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"account_bindings\":{\"payer\":\"payer-pubkey\"}") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"remaining_accounts\":[{\"pubkey\":\"extra\",\"is_signer\":false,\"is_writable\":true}]") != null);
}

test "invocation_spec_json.buildAnchorIdlInvocationSpecJson rejects non-object idl json" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildAnchorIdlInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .idl_json = "[]",
            .instruction_name = "initialize",
        }),
    );
}

test "invocation_spec_json.buildAnchorIdlInvocationSpecJson canonicalizes account binding aliases and path suffixes" {
    const allocator = std.testing.allocator;

    const encoded = try buildAnchorIdlInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .idl_json = "{\"address\":\"program-id\"}",
        .instruction_name = "initialize",
        .account_bindings_json =
        \\{
        \\  "authority.publicKey":"authority-pubkey",
        \\  "payer":{"publicKey":"payer-pubkey"},
        \\  "vault":{"address":"vault-pubkey","amount":"42"},
        \\  "program":{"programId":"program-pubkey"},
        \\  "nullable":{"key":null}
        \\}
        ,
    });
    defer allocator.free(encoded);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, encoded, .{});
    defer parsed.deinit();

    const invocation_spec = switch (parsed.value) {
        .object => |object| object,
        else => unreachable,
    };
    const account_bindings = jsonObjectField(&invocation_spec, &.{"account_bindings"}) orelse unreachable;
    try std.testing.expect(account_bindings == .object);

    try std.testing.expectEqualStrings(
        "authority-pubkey",
        account_bindings.object.get("authority").?.string,
    );
    try std.testing.expect(account_bindings.object.get("authority.publicKey") == null);

    const payer_binding = account_bindings.object.get("payer").?;
    try std.testing.expectEqualStrings("payer-pubkey", payer_binding.object.get("pubkey").?.string);
    try std.testing.expect(payer_binding.object.get("publicKey") == null);

    const vault_binding = account_bindings.object.get("vault").?;
    try std.testing.expectEqualStrings("vault-pubkey", vault_binding.object.get("pubkey").?.string);
    try std.testing.expectEqualStrings("42", vault_binding.object.get("amount").?.string);
    try std.testing.expect(vault_binding.object.get("address") == null);

    const program_binding = account_bindings.object.get("program").?;
    try std.testing.expectEqualStrings("program-pubkey", program_binding.object.get("pubkey").?.string);
    try std.testing.expect(program_binding.object.get("programId") == null);

    const nullable_binding = account_bindings.object.get("nullable").?;
    try std.testing.expect(nullable_binding.object.get("pubkey").? == .null);
    try std.testing.expect(nullable_binding.object.get("key") == null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson writes canonical program invocation fields" {
    const allocator = std.testing.allocator;

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = "[\"extra-signer\"]",
        .recent_blockhash = "recent-blockhash",
        .program_id = "program-id",
        .accounts_json = "[]",
        .data = "AQ==",
        .data_encoding = "base64",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"payer_secret_key\":\"payer-secret\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"extra-signer\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"recent_blockhash\":\"recent-blockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"program_id\":\"program-id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accounts\":[]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data\":\"AQ==\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data_encoding\":\"base64\"") != null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson rejects nonce authority without nonce account" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildProgramInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .nonce_authority_secret_key = "nonce-authority-secret",
            .program_id = "program-id",
            .data = "AQ==",
        }),
    );
}

test "invocation_spec_json.buildProgramInvocationSpecJson rejects non-string additional signers" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        error.InvalidInvocationSpec,
        buildProgramInvocationSpecJson(allocator, .{
            .payer_secret_key = "payer-secret",
            .additional_signer_secret_keys_json = "[1]",
            .program_id = "program-id",
            .data = "AQ==",
        }),
    );
}

test "invocation_spec_json.buildProgramInvocationSpecJson canonicalizes relaxed additional signer wrappers" {
    const allocator = std.testing.allocator;

    const extra_signer = try sdk.Keypair.fromSecretKeyBytes(.{45} ** 32);
    const extra_signer_secret_key = extra_signer.secret_key.toBytes();
    const extra_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_signer_secret_key);
    defer allocator.free(extra_signer_secret_key_base58);

    var bytes_buffer: std.io.Writer.Allocating = .init(allocator);
    defer bytes_buffer.deinit();
    try bytes_buffer.writer.writeByte('[');
    for (extra_signer_secret_key, 0..) |byte, index| {
        if (index != 0) try bytes_buffer.writer.writeByte(',');
        try bytes_buffer.writer.print("{d}", .{byte});
    }
    try bytes_buffer.writer.writeByte(']');

    const additional_signers_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"secretKey\":\"{s}\"}},{{\"bytes\":{s}}}]",
        .{ extra_signer_secret_key_base58, bytes_buffer.written() },
    );
    defer allocator.free(additional_signers_json);

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json = additional_signers_json,
        .program_id = "program-id",
        .data = "AQ==",
    });
    defer allocator.free(encoded);

    const expected = try std.fmt.allocPrint(
        allocator,
        "\"additional_signer_secret_keys\":[\"{s}\",\"{s}\"]",
        .{ extra_signer_secret_key_base58, extra_signer_secret_key_base58 },
    );
    defer allocator.free(expected);
    try std.testing.expect(std.mem.indexOf(u8, encoded, expected) != null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson canonicalizes nested json fragments" {
    const allocator = std.testing.allocator;

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .additional_signer_secret_keys_json =
        \\[
        \\  "extra-signer"
        \\]
        ,
        .address_lookup_tables_json =
        \\[
        \\  { "account_key": "lookup", "addresses": [ "addr" ] }
        \\]
        ,
        .program_id = "program-id",
        .accounts_json =
        \\[
        \\  { "pubkey": "acct", "is_signer": true, "is_writable": false }
        \\]
        ,
        .data_bytes_json =
        \\{
        \\  "hex": "0102"
        \\}
        ,
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"additional_signer_secret_keys\":[\"extra-signer\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"address_lookup_tables\":[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accounts\":[{\"pubkey\":\"acct\",\"is_signer\":true,\"is_writable\":false}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data_bytes\":[1,2]") != null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson canonicalizes wrapped lookup and account aliases" {
    const allocator = std.testing.allocator;

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .address_lookup_tables_json =
        \\[
        \\  {
        \\    "accountKey": {"address":"lookup"},
        \\    "addresses": [ {"publicKey":"addr"} ]
        \\  }
        \\]
        ,
        .program_id = "program-id",
        .accounts_json =
        \\[
        \\  "acct-a",
        \\  {"publicKey":"acct-b","signer":"true","writable":"true"}
        \\]
        ,
        .data = "AQ==",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"address_lookup_tables\":[{\"account_key\":\"lookup\",\"addresses\":[\"addr\"]}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accounts\":[{\"pubkey\":\"acct-a\",\"is_signer\":false,\"is_writable\":false},{\"pubkey\":\"acct-b\",\"is_signer\":true,\"is_writable\":true}]") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accountKey\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"publicKey\"") == null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson canonicalizes account string shorthands" {
    const allocator = std.testing.allocator;

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .program_id = "program-id",
        .accounts_json =
        \\[
        \\  "acct-a:sw",
        \\  "acct-b:w",
        \\  "acct-c:s",
        \\  "acct-d"
        \\]
        ,
        .data = "AQ==",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"accounts\":[{\"pubkey\":\"acct-a\",\"is_signer\":true,\"is_writable\":true},{\"pubkey\":\"acct-b\",\"is_signer\":false,\"is_writable\":true},{\"pubkey\":\"acct-c\",\"is_signer\":true,\"is_writable\":false},{\"pubkey\":\"acct-d\",\"is_signer\":false,\"is_writable\":false}]") != null);
}

test "invocation_spec_json.buildProgramInvocationSpecJson writes canonical schema-driven program invocation fields" {
    const allocator = std.testing.allocator;

    const encoded = try buildProgramInvocationSpecJson(allocator, .{
        .payer_secret_key = "payer-secret",
        .program_id = "program-id",
        .data_schema_json = "{\"type\":\"struct\",\"fields\":[{\"name\":\"amount\",\"type\":\"u64\"}]}",
        .args_json = "{\"amount\":\"42\"}",
        .schema_encoding = "borsh",
    });
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"program_id\":\"program-id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"data_schema\":{\"type\":\"struct\",\"fields\":[{\"name\":\"amount\",\"type\":\"u64\"}]}") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"args\":{\"amount\":\"42\"}") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"schema_encoding\":\"borsh\"") != null);
}
