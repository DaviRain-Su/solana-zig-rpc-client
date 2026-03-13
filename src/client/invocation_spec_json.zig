const std = @import("std");

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
};

pub const InvocationContextJsonOptions = struct {
    payer_secret_key: []const u8,
    additional_signer_secret_keys_json: ?[]const u8 = null,
    address_lookup_tables_json: ?[]const u8 = null,
    recent_blockhash: ?[]const u8 = null,
    nonce_account: ?[]const u8 = null,
    nonce_authority_secret_key: ?[]const u8 = null,
};

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
        try buffer.writer.writeAll(value);
    }
    if (options.address_lookup_tables_json) |value| {
        try writeFieldName(buffer, has_field_ptr, "address_lookup_tables");
        try buffer.writer.writeAll(value);
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

    var instruction_buffer: std.io.Writer.Allocating = .init(allocator);
    defer instruction_buffer.deinit();
    try instruction_buffer.writer.writeByte('[');
    try instruction_buffer.writer.writeByte('{');
    var has_instruction_field = false;

    try writeFieldName(&instruction_buffer, &has_instruction_field, "program_id");
    try std.json.Stringify.value(options.instruction.program_id, .{}, &instruction_buffer.writer);

    if (options.instruction.accounts_json) |value| {
        try writeFieldName(&instruction_buffer, &has_instruction_field, "accounts");
        try instruction_buffer.writer.writeAll(value);
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
        try instruction_buffer.writer.writeAll(value);
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
    if (options.data_encoding != null and options.data == null) {
        return error.InvalidInvocationSpec;
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
        try json_buffer.writer.writeAll(value);
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
        try json_buffer.writer.writeAll(value);
    }

    try json_buffer.writer.writeByte('}');
    return try allocator.dupe(u8, json_buffer.written());
}

pub fn buildInvocationSpecJson(
    allocator: Allocator,
    options: BuildInvocationSpecJsonOptions,
) BuildError![]u8 {
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
    try json_buffer.writer.writeAll(options.instructions_json);
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
