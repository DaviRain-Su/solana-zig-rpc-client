const std = @import("std");
const instructions_invoke = @import("./instructions_invoke.zig");
const rpc_types = @import("./rpc_types.zig");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const InstructionDataEncoding = enum {
    base64,
    hex,
    utf8,
};

pub const BuildError = Allocator.Error || error{
    InvalidProgramInvokeSpec,
    InvalidHexData,
};

pub const BuildInstructionOptions = struct {
    accounts: []const sdk.AccountMeta = &.{},
    accounts_json: ?[]const u8 = null,
    data: ?[]const u8 = null,
    data_bytes: ?[]const u8 = null,
    data_encoding: InstructionDataEncoding = .base64,
};

pub const BuildLegacyMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
};

pub const SendLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    rpc: ?rpc_types.SendLegacyInstructionsOptions = null,
};

pub const SimulateLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    rpc: ?rpc_types.LegacyInstructionsOptions = null,
};

pub const SendVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    rpc: ?rpc_types.SendVersionedInstructionsOptions = null,
};

pub const SimulateVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    rpc: ?rpc_types.VersionedInstructionsOptions = null,
};

pub const BuildLegacyMessageRpcOptions = struct {
    payer: sdk.Pubkey,
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildLegacyTransactionRpcOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildVersionedMessageRpcOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const BuildVersionedTransactionRpcOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    instruction: BuildInstructionOptions = .{},
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const GetFeeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
};

pub const BuildLegacyMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
};

pub const SendLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const BuildLegacyMessageWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedMessageWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
};

pub const BuildVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
};

pub const SendLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    instruction: BuildInstructionOptions = .{},
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const ProgramInvocationSpecRpcOptions = struct {
    program_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const SendProgramInvocationSpecRpcOptions = struct {
    program_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateProgramInvocationSpecRpcOptions = struct {
    program_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmProgramInvocationSpecRpcOptions = struct {
    program_invocation_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const OwnedInstruction = struct {
    instruction: sdk.Instruction,

    pub fn deinit(self: *OwnedInstruction, allocator: Allocator) void {
        allocator.free(self.instruction.accounts);
        allocator.free(self.instruction.data);
        self.* = undefined;
    }
};

const OwnedAccounts = struct {
    metas: []sdk.AccountMeta,

    fn deinit(self: *OwnedAccounts, allocator: Allocator) void {
        allocator.free(self.metas);
        self.* = undefined;
    }
};

fn findJsonObjectField(object: std.json.ObjectMap, comptime names: []const []const u8) ?std.json.Value {
    inline for (names) |name| {
        if (object.get(name)) |value| return value;
    }
    return null;
}

fn parseJsonBool(value: std.json.Value) BuildError!bool {
    return switch (value) {
        .bool => value.bool,
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseJsonPubkey(allocator: Allocator, value: std.json.Value) BuildError!sdk.Pubkey {
    return switch (value) {
        .string => sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidProgramInvokeSpec,
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseJsonAccountMeta(allocator: Allocator, value: std.json.Value) BuildError!sdk.AccountMeta {
    return switch (value) {
        .string => .{
            .pubkey = sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidProgramInvokeSpec,
            .is_signer = false,
            .is_writable = false,
        },
        .object => blk: {
            const pubkey_value = findJsonObjectField(value.object, &.{
                "pubkey",
                "publicKey",
                "public_key",
                "address",
                "key",
            }) orelse return error.InvalidProgramInvokeSpec;

            var is_signer = false;
            if (findJsonObjectField(value.object, &.{ "isSigner", "is_signer", "signer" })) |field| {
                is_signer = try parseJsonBool(field);
            }

            var is_writable = false;
            if (findJsonObjectField(value.object, &.{ "isWritable", "is_writable", "writable" })) |field| {
                is_writable = try parseJsonBool(field);
            }

            break :blk .{
                .pubkey = try parseJsonPubkey(allocator, pubkey_value),
                .is_signer = is_signer,
                .is_writable = is_writable,
            };
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseAccountsJson(allocator: Allocator, json_source: []const u8) BuildError!OwnedAccounts {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidProgramInvokeSpec;
    defer parsed.deinit();

    const items = switch (parsed.value) {
        .array => parsed.value.array.items,
        else => return error.InvalidProgramInvokeSpec,
    };

    const metas = try allocator.alloc(sdk.AccountMeta, items.len);
    errdefer allocator.free(metas);

    for (items, 0..) |account, index| {
        metas[index] = try parseJsonAccountMeta(allocator, account);
    }

    return .{ .metas = metas };
}

fn parseProgramId(allocator: Allocator, program_id: []const u8) BuildError!sdk.Pubkey {
    return sdk.Pubkey.fromBase58(allocator, program_id) catch return error.InvalidProgramInvokeSpec;
}

fn latestBlockhashQuery(commitment: ?rpc_types.Commitment) rpc_types.BlockhashQuery {
    return .{ .cluster = .{ .commitment = commitment } };
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

fn buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) BuildError![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, program_invocation_spec_json, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidProgramInvokeSpec;
    defer parsed.deinit();

    const object = switch (parsed.value) {
        .object => parsed.value.object,
        else => return error.InvalidProgramInvokeSpec,
    };

    const payer_secret_key_value = findJsonObjectField(object, &.{ "payer_secret_key", "payerSecretKey" }) orelse
        return error.InvalidProgramInvokeSpec;
    if (payer_secret_key_value != .string) return error.InvalidProgramInvokeSpec;

    const program_id_value = findJsonObjectField(object, &.{ "program_id", "programId" }) orelse
        return error.InvalidProgramInvokeSpec;
    if (program_id_value != .string) return error.InvalidProgramInvokeSpec;

    const accounts_value = findJsonObjectField(object, &.{ "accounts", "accounts_json", "accountsJson" });
    const data_value = findJsonObjectField(object, &.{"data"});
    const data_bytes_value = findJsonObjectField(object, &.{ "data_bytes", "dataBytes" });
    if (data_value != null and data_bytes_value != null) return error.InvalidProgramInvokeSpec;

    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('{');
    var has_field = false;
    const Writer = struct {
        fn writeFieldName(
            buffer: *std.io.Writer.Allocating,
            has_field_ptr: *bool,
            name: []const u8,
        ) !void {
            if (has_field_ptr.*) try buffer.writer.writeByte(',');
            try std.json.Stringify.value(name, .{}, &buffer.writer);
            try buffer.writer.writeByte(':');
            has_field_ptr.* = true;
        }
    };

    try Writer.writeFieldName(&json_buffer, &has_field, "payer_secret_key");
    try std.json.Stringify.value(payer_secret_key_value.string, .{}, &json_buffer.writer);

    if (findJsonObjectField(object, &.{ "additional_signer_secret_keys", "additionalSignerSecretKeys" })) |value| {
        try Writer.writeFieldName(&json_buffer, &has_field, "additional_signer_secret_keys");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (findJsonObjectField(object, &.{ "address_lookup_tables", "addressLookupTables" })) |value| {
        try Writer.writeFieldName(&json_buffer, &has_field, "address_lookup_tables");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (findJsonObjectField(object, &.{ "recent_blockhash", "recentBlockhash" })) |value| {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        try Writer.writeFieldName(&json_buffer, &has_field, "recent_blockhash");
        try std.json.Stringify.value(value.string, .{}, &json_buffer.writer);
    }
    if (findJsonObjectField(object, &.{ "nonce_account", "nonceAccount" })) |value| {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        try Writer.writeFieldName(&json_buffer, &has_field, "nonce_account");
        try std.json.Stringify.value(value.string, .{}, &json_buffer.writer);
    }
    if (findJsonObjectField(object, &.{ "nonce_authority_secret_key", "nonceAuthoritySecretKey" })) |value| {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        try Writer.writeFieldName(&json_buffer, &has_field, "nonce_authority_secret_key");
        try std.json.Stringify.value(value.string, .{}, &json_buffer.writer);
    }

    try Writer.writeFieldName(&json_buffer, &has_field, "instructions");
    try json_buffer.writer.writeByte('[');
    var has_instruction_field = false;
    const InstructionWriter = struct {
        fn writeFieldName(
            buffer: *std.io.Writer.Allocating,
            has_field_ptr: *bool,
            name: []const u8,
        ) !void {
            if (has_field_ptr.*) try buffer.writer.writeByte(',');
            try std.json.Stringify.value(name, .{}, &buffer.writer);
            try buffer.writer.writeByte(':');
            has_field_ptr.* = true;
        }
    };
    try json_buffer.writer.writeByte('{');
    try InstructionWriter.writeFieldName(&json_buffer, &has_instruction_field, "program_id");
    try std.json.Stringify.value(program_id_value.string, .{}, &json_buffer.writer);
    if (accounts_value) |value| {
        try InstructionWriter.writeFieldName(&json_buffer, &has_instruction_field, "accounts");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    if (data_value) |value| {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        try InstructionWriter.writeFieldName(&json_buffer, &has_instruction_field, "data");
        try std.json.Stringify.value(value.string, .{}, &json_buffer.writer);
        if (findJsonObjectField(object, &.{ "data_encoding", "dataEncoding", "encoding" })) |encoding_value| {
            if (encoding_value != .string) return error.InvalidProgramInvokeSpec;
            try InstructionWriter.writeFieldName(&json_buffer, &has_instruction_field, "data_encoding");
            try std.json.Stringify.value(encoding_value.string, .{}, &json_buffer.writer);
        }
    } else if (data_bytes_value) |value| {
        try InstructionWriter.writeFieldName(&json_buffer, &has_instruction_field, "data_bytes");
        try std.json.Stringify.value(value, .{}, &json_buffer.writer);
    }
    try json_buffer.writer.writeByte('}');
    try json_buffer.writer.writeByte(']');
    try json_buffer.writer.writeByte('}');

    return try allocator.dupe(u8, json_buffer.written());
}

fn decodeInstructionData(
    allocator: Allocator,
    encoded: ?[]const u8,
    encoding: InstructionDataEncoding,
) BuildError![]u8 {
    const value = encoded orelse return try allocator.alloc(u8, 0);

    return switch (encoding) {
        .utf8 => try allocator.dupe(u8, value),
        .base64 => blk: {
            const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(value) catch return error.InvalidProgramInvokeSpec;
            const decoded = try allocator.alloc(u8, decoded_len);
            errdefer allocator.free(decoded);
            std.base64.standard.Decoder.decode(decoded, value) catch return error.InvalidProgramInvokeSpec;
            break :blk decoded;
        },
        .hex => blk: {
            const hex_value = if (std.mem.startsWith(u8, value, "0x") or std.mem.startsWith(u8, value, "0X"))
                value[2..]
            else
                value;
            if (hex_value.len % 2 != 0) return error.InvalidHexData;
            const decoded = try allocator.alloc(u8, hex_value.len / 2);
            errdefer allocator.free(decoded);
            _ = std.fmt.hexToBytes(decoded, hex_value) catch return error.InvalidHexData;
            break :blk decoded;
        },
    };
}

pub fn buildOwnedInstruction(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    if (options.data != null and options.data_bytes != null) return error.InvalidProgramInvokeSpec;

    var json_accounts = if (options.accounts_json) |value|
        try parseAccountsJson(allocator, value)
    else
        null;
    defer if (json_accounts) |*value| value.deinit(allocator);

    var merged_accounts: ?[]sdk.AccountMeta = null;
    defer if (merged_accounts) |value| allocator.free(value);
    const resolved_accounts = if (json_accounts) |value| blk: {
        if (options.accounts.len == 0) break :blk value.metas;
        if (value.metas.len == 0) break :blk options.accounts;

        const merged = try allocator.alloc(sdk.AccountMeta, options.accounts.len + value.metas.len);
        merged_accounts = merged;
        @memcpy(merged[0..options.accounts.len], options.accounts);
        @memcpy(merged[options.accounts.len..], value.metas);
        break :blk merged;
    } else options.accounts;

    const accounts = try allocator.dupe(sdk.AccountMeta, resolved_accounts);
    errdefer allocator.free(accounts);

    const data = if (options.data_bytes) |value|
        try allocator.dupe(u8, value)
    else
        try decodeInstructionData(allocator, options.data, options.data_encoding);
    errdefer allocator.free(data);

    return .{
        .instruction = .{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
        },
    };
}

pub fn buildOwnedInstructionFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    return try buildOwnedInstruction(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildOwnedLegacyMessage(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildOwnedLegacyMessage(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
    );
}

pub fn buildOwnedLegacyMessageFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildLegacyMessageOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessage(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildLegacyMessageBytes(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildLegacyMessageBytes(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
    );
}

pub fn buildLegacyMessageBytesFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    return try buildLegacyMessageBytes(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildLegacyMessageBase64(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildLegacyMessageBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
    );
}

pub fn buildLegacyMessageBase64FromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    return try buildLegacyMessageBase64(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildSignedLegacyTransaction(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionOptions,
) !sdk.SignedLegacyTransaction {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildSignedLegacyTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.signers,
    );
}

pub fn buildSignedLegacyTransactionFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildLegacyTransactionOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransaction(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildLegacyTransactionBase64(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildLegacyTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.signers,
    );
}

pub fn buildLegacyTransactionBase64FromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildLegacyTransactionOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildOwnedVersionedMessage(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildOwnedVersionedMessage(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
    );
}

pub fn buildOwnedVersionedMessageFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildVersionedMessageOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessage(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildVersionedMessageBytes(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildVersionedMessageBytes(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
    );
}

pub fn buildVersionedMessageBytesFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    return try buildVersionedMessageBytes(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildVersionedMessageBase64(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildVersionedMessageBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
    );
}

pub fn buildVersionedMessageBase64FromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    return try buildVersionedMessageBase64(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildSignedVersionedTransaction(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionOptions,
) !sdk.SignedVersionedTransaction {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildSignedVersionedTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
    );
}

pub fn buildSignedVersionedTransactionFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildVersionedTransactionOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransaction(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn buildVersionedTransactionBase64(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionOptions,
) ![]u8 {
    var owned_instruction = try buildOwnedInstruction(allocator, program_id, options.instruction);
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildVersionedTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
    );
}

pub fn buildVersionedTransactionBase64FromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildVersionedTransactionOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64(allocator, try parseProgramId(allocator, program_id), options);
}

pub fn sendLegacyTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendLegacyTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.signers,
        options.rpc,
    );
}

pub fn sendLegacyTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendLegacyTransactionOptions,
) ![]const u8 {
    return try sendLegacyTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateLegacyTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateLegacyTransactionOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.signers,
        options.build,
        options.rpc,
    );
}

pub fn simulateLegacyTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateLegacyTransactionOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.signers,
        options.rpc,
    );
}

pub fn sendAndConfirmLegacyTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendVersionedTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendVersionedTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn sendVersionedTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendVersionedTransactionOptions,
) ![]const u8 {
    return try sendVersionedTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateVersionedTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateVersionedTransactionOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.build,
        options.rpc,
    );
}

pub fn simulateVersionedTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateVersionedTransactionOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SimulateProgramInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn sendAndConfirmVersionedTransactionFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransaction(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: SimulateProgramInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn buildOwnedLegacyMessageWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageRpcOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildOwnedLegacyMessageWithOptions(
        options.payer,
        instructions[0..],
        options.build,
    );
}

pub fn buildOwnedLegacyMessageWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageRpcOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBytesWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    var owned_message = try buildOwnedLegacyMessageWithOptions(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.serialize(self.allocator);
}

pub fn buildLegacyMessageBytesWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBase64WithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    var owned_message = try buildOwnedLegacyMessageWithOptions(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.toBase64(self.allocator);
}

pub fn buildLegacyMessageBase64WithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedLegacyTransactionWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionRpcOptions,
) !sdk.SignedLegacyTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedLegacyTransactionWithOptions(
        options.payer,
        instructions[0..],
        options.signers,
        options.build,
    );
}

pub fn buildSignedLegacyTransactionWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionRpcOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyTransactionBase64WithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionRpcOptions,
) ![]u8 {
    var signed = try buildSignedLegacyTransactionWithOptions(self, program_id, options);
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildLegacyTransactionBase64WithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionRpcOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildOwnedVersionedMessageWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildOwnedVersionedMessageWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.build,
    );
}

pub fn buildOwnedVersionedMessageWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBytesWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    var owned_message = try buildOwnedVersionedMessageWithOptions(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.serialize(self.allocator);
}

pub fn buildVersionedMessageBytesWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBase64WithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    var owned_message = try buildOwnedVersionedMessageWithOptions(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.toBase64(self.allocator);
}

pub fn buildVersionedMessageBase64WithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedVersionedTransactionWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionRpcOptions,
) !sdk.SignedVersionedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedVersionedTransactionWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.build,
    );
}

pub fn buildSignedVersionedTransactionWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionRpcOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedTransactionBase64WithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionRpcOptions,
) ![]u8 {
    var signed = try buildSignedVersionedTransactionWithOptions(self, program_id, options);
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransactionBase64WithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionRpcOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithOptions(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionWithSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        options.payer,
        instructions[0..],
        options.signers,
        options.rpc,
    );
}

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmVersionedTransactionWithSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn getFeeForLegacyMessageWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildLegacyMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const encoded = try buildLegacyMessageBase64WithOptions(self, program_id, message_options);
    defer self.allocator.free(encoded);
    return try self.getFeeForMessage(encoded, fee_options.commitment);
}

pub fn getFeeForLegacyMessageWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildLegacyMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithOptions(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

pub fn getFeeForVersionedMessageWithOptions(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildVersionedMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const encoded = try buildVersionedMessageBase64WithOptions(self, program_id, message_options);
    defer self.allocator.free(encoded);
    return try self.getFeeForMessage(encoded, fee_options.commitment);
}

pub fn getFeeForVersionedMessageWithOptionsFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildVersionedMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithOptions(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

pub fn buildOwnedLegacyMessageWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildOwnedLegacyMessageWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildOwnedLegacyMessageWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBase64WithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_message = try buildOwnedLegacyMessageWithBlockhashQuery(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.toBase64(self.allocator);
}

pub fn buildLegacyMessageBase64WithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBytesWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_message = try buildOwnedLegacyMessageWithBlockhashQuery(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.serialize(self.allocator);
}

pub fn buildLegacyMessageBytesWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedLegacyTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) !sdk.SignedLegacyTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedLegacyTransactionWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildSignedLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyTransactionBase64WithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) ![]u8 {
    var signed = try buildSignedLegacyTransactionWithBlockhashQuery(self, program_id, options);
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildLegacyTransactionBase64WithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildOwnedVersionedMessageWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildOwnedVersionedMessageWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildOwnedVersionedMessageWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBase64WithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_message = try buildOwnedVersionedMessageWithBlockhashQuery(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.toBase64(self.allocator);
}

pub fn buildVersionedMessageBase64WithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBytesWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    var owned_message = try buildOwnedVersionedMessageWithBlockhashQuery(self, program_id, options);
    defer owned_message.deinit(self.allocator);
    return try owned_message.serialize(self.allocator);
}

pub fn buildVersionedMessageBytesWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedVersionedTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) !sdk.SignedVersionedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedVersionedTransactionWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
    );
}

pub fn buildSignedVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedTransactionBase64WithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) ![]u8 {
    var signed = try buildSignedVersionedTransactionWithBlockhashQuery(self, program_id, options);
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransactionBase64WithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendLegacyTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.send_transaction_options,
    );
}

pub fn sendLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendLegacyTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateLegacyTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateLegacyTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.simulate_options,
    );
}

pub fn simulateLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateLegacyTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryWithSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner(
        options.payer,
        instructions[0..],
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryWithSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithBlockhashQueryWithSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendVersionedTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        .{ .send_transaction_options = options.send_transaction_options },
    );
}

pub fn sendVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendVersionedTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateVersionedTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateVersionedTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.simulate_options,
    );
}

pub fn simulateVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateVersionedTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        .{
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithBlockhashQueryWithSpinner(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        options.signers,
        options.blockhash_query,
        options.nonce_authority,
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn getFeeForLegacyMessageWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildLegacyMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const encoded = try buildLegacyMessageBase64WithBlockhashQuery(self, program_id, message_options);
    defer self.allocator.free(encoded);
    return try self.getFeeForMessage(encoded, fee_options.commitment);
}

pub fn getFeeForLegacyMessageWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildLegacyMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

pub fn getFeeForVersionedMessageWithBlockhashQuery(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildVersionedMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const encoded = try buildVersionedMessageBase64WithBlockhashQuery(self, program_id, message_options);
    defer self.allocator.free(encoded);
    return try self.getFeeForMessage(encoded, fee_options.commitment);
}

pub fn getFeeForVersionedMessageWithBlockhashQueryFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildVersionedMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithBlockhashQuery(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

pub fn buildOwnedLegacyMessageWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildOwnedLegacyMessageWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBase64WithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildLegacyMessageBase64WithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyMessageBytesWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildLegacyMessageBytesWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedLegacyTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildSignedLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildLegacyTransactionBase64WithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildLegacyTransactionBase64WithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildOwnedVersionedMessageWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildOwnedVersionedMessageWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBase64WithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildVersionedMessageBase64WithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedMessageBytesWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildVersionedMessageBytesWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildSignedVersionedTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildSignedVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn buildVersionedTransactionBase64WithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
        },
    );
}

pub fn buildVersionedTransactionBase64WithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendLegacyTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendLegacyTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
        },
    );
}

pub fn sendLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendLegacyTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateLegacyTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateLegacyTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .simulate_options = options.simulate_options,
        },
    );
}

pub fn simulateLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateLegacyTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithBlockhashQueryWithSpinner(
        self,
        program_id,
        .{
            .payer = options.payer,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendVersionedTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendVersionedTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
        },
    );
}

pub fn sendVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendVersionedTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn simulateVersionedTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateVersionedTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .simulate_options = options.simulate_options,
        },
    );
}

pub fn simulateVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SimulateVersionedTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinner(
        self,
        program_id,
        .{
            .payer = options.payer,
            .address_lookup_tables = options.address_lookup_tables,
            .signers = options.signers,
            .blockhash_query = latestBlockhashQuery(options.blockhash_commitment),
            .instruction = options.instruction,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinnerFromJson(
    self: anytype,
    program_id: []const u8,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(self, try parseProgramId(self.allocator, program_id), options);
}

pub fn getFeeForLegacyMessageWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildLegacyMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = message_options.payer,
            .blockhash_query = latestBlockhashQuery(message_options.blockhash_commitment),
            .instruction = message_options.instruction,
        },
        fee_options,
    );
}

pub fn getFeeForLegacyMessageWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildLegacyMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

pub fn getFeeForVersionedMessageWithLatestBlockhash(
    self: anytype,
    program_id: sdk.Pubkey,
    message_options: BuildVersionedMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithBlockhashQuery(
        self,
        program_id,
        .{
            .payer = message_options.payer,
            .address_lookup_tables = message_options.address_lookup_tables,
            .blockhash_query = latestBlockhashQuery(message_options.blockhash_commitment),
            .instruction = message_options.instruction,
        },
        fee_options,
    );
}

pub fn getFeeForVersionedMessageWithLatestBlockhashFromJson(
    self: anytype,
    program_id: []const u8,
    message_options: BuildVersionedMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithLatestBlockhash(self, try parseProgramId(self.allocator, program_id), message_options, fee_options);
}

test "program_invoke.buildOwnedInstructionFromJson builds utf8 instruction from accounts json" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{81} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const signer = sdk.Pubkey.fromBytes(.{82} ** 32);
    const signer_base58 = try signer.toBase58(allocator);
    defer allocator.free(signer_base58);
    const writable = sdk.Pubkey.fromBytes(.{83} ** 32);
    const writable_base58 = try writable.toBase58(allocator);
    defer allocator.free(writable_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":true,\"is_writable\":false}},{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":true}}]",
        .{ signer_base58, writable_base58 },
    );
    defer allocator.free(accounts_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        program_id_base58,
        .{
            .accounts_json = accounts_json,
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expect(owned_instruction.instruction.program_id.eql(program_id));
    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(signer));
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(!owned_instruction.instruction.accounts[0].is_writable);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(writable));
    try std.testing.expect(!owned_instruction.instruction.accounts[1].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction merges typed accounts before json accounts" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{84} ** 32);
    const typed = sdk.Pubkey.fromBytes(.{85} ** 32);
    const json = sdk.Pubkey.fromBytes(.{86} ** 32);
    const json_base58 = try json.toBase58(allocator);
    defer allocator.free(json_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":true}}]",
        .{json_base58},
    );
    defer allocator.free(accounts_json);

    const typed_accounts = [_]sdk.AccountMeta{
        sdk.AccountMeta.init(typed, true, false),
    };

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .accounts = &typed_accounts,
            .accounts_json = accounts_json,
            .data = "70696e67",
            .data_encoding = .hex,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(typed));
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(json));
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction decodes base64 data" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{87} ** 32);
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "cGluZw==",
            .data_encoding = .base64,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), owned_instruction.instruction.accounts.len);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction accepts flexible json account forms" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{108} ** 32);
    const readonly = sdk.Pubkey.fromBytes(.{109} ** 32);
    const readonly_base58 = try readonly.toBase58(allocator);
    defer allocator.free(readonly_base58);
    const signer = sdk.Pubkey.fromBytes(.{110} ** 32);
    const signer_base58 = try signer.toBase58(allocator);
    defer allocator.free(signer_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[\"{s}\",{{\"address\":\"{s}\",\"signer\":true,\"writable\":true}}]",
        .{ readonly_base58, signer_base58 },
    );
    defer allocator.free(accounts_json);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .accounts_json = accounts_json,
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(readonly));
    try std.testing.expect(!owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(!owned_instruction.instruction.accounts[0].is_writable);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(signer));
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
}

test "program_invoke.buildOwnedLegacyMessage builds reusable legacy message" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{88} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{89} ** 32);
    const account = sdk.Pubkey.fromBytes(.{90} ** 32);
    const account_base58 = try account.toBase58(allocator);
    defer allocator.free(account_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":true}}]",
        .{account_base58},
    );
    defer allocator.free(accounts_json);

    var owned_message = try buildOwnedLegacyMessage(
        allocator,
        program_id,
        .{
            .payer = payer,
            .recent_blockhash = sdk.Hash.fromBytes(.{91} ** 32),
            .instruction = .{
                .accounts_json = accounts_json,
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer owned_message.deinit(allocator);

    try std.testing.expect(owned_message.message.payer.eql(payer));
    try std.testing.expectEqual(@as(usize, 1), owned_message.message.instructions.len);
    try std.testing.expect(owned_message.message.instructions[0].program_id.eql(program_id));
    try std.testing.expectEqual(@as(usize, 1), owned_message.message.instructions[0].accounts.len);
    try std.testing.expect(owned_message.message.instructions[0].accounts[0].pubkey.eql(account));
    try std.testing.expect(owned_message.message.instructions[0].accounts[0].is_writable);
    try std.testing.expectEqualStrings("ping", owned_message.message.instructions[0].data);
}

test "program_invoke.buildVersionedMessageBase64 matches sdk helper" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{92} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{93} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{94} ** 32);

    const actual = try buildVersionedMessageBase64(
        allocator,
        program_id,
        .{
            .payer = payer,
            .recent_blockhash = recent_blockhash,
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer allocator.free(actual);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    const expected = try sdk.buildVersionedMessageBase64(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "program_invoke.sendLegacyTransaction delegates built instruction to rpc client" {
    const allocator = std.testing.allocator;

    const MockLegacyClient = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_program_id: ?sdk.Pubkey = null,
        captured_account_count: usize = 0,
        captured_data: ?[]u8 = null,
        captured_signer_count: usize = 0,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expect(options != null);
            self.captured_payer = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_account_count = instructions[0].accounts.len;
            self.captured_signer_count = signers.len;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return "mock-signature";
        }
    };

    var mock = MockLegacyClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{95} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{96} ** 32);
    const account = sdk.Pubkey.fromBytes(.{97} ** 32);
    const account_base58 = try account.toBase58(allocator);
    defer allocator.free(account_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":false}}]",
        .{account_base58},
    );
    defer allocator.free(accounts_json);

    const signature = try sendLegacyTransaction(
        &mock,
        program_id,
        .{
            .payer = payer,
            .signers = &.{},
            .instruction = .{
                .accounts_json = accounts_json,
                .data = "70696e67",
                .data_encoding = .hex,
            },
            .rpc = .{ .recent_blockhash = "ignored-by-mock" },
        },
    );

    try std.testing.expectEqualStrings("mock-signature", signature);
    try std.testing.expect(mock.captured_payer.?.eql(payer));
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(@as(usize, 1), mock.captured_account_count);
    try std.testing.expectEqual(@as(usize, 0), mock.captured_signer_count);
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
}

test "program_invoke.sendLegacyTransactionFromJson parses program id string" {
    const allocator = std.testing.allocator;

    const MockLegacyClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = self.allocator;
            _ = payer;
            _ = signers;
            _ = options;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            self.captured_program_id = instructions[0].program_id;
            return "mock-signature-from-json";
        }
    };

    var mock = MockLegacyClient{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{111} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = sdk.Pubkey.fromBytes(.{112} ** 32);

    const signature = try sendLegacyTransactionFromJson(
        &mock,
        program_id_base58,
        .{
            .payer = payer,
            .signers = &.{},
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
            .rpc = .{ .recent_blockhash = "ignored-by-mock" },
        },
    );

    try std.testing.expectEqualStrings("mock-signature-from-json", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
}

test "program_invoke.sendLegacyTransactionFromInvocationSpecJson forwards recent blockhash and signers" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_account_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_recent_blockhash: ?[]const u8 = null,

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = self.allocator;
            _ = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_account_count = instructions[0].accounts.len;
            self.captured_signer_count = signers.len;
            self.captured_recent_blockhash = options.?.recent_blockhash.?;
            return "mock-program-invoke-spec-legacy-signature";
        }
    };

    var mock = MockLegacyInvocationClient{ .allocator = allocator };
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{140} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{141} ** 32);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{142} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const account = sdk.Pubkey.fromBytes(.{143} ** 32);
    const account_base58 = try account.toBase58(allocator);
    defer allocator.free(account_base58);
    const recent_blockhash = sdk.Hash.fromBytes(.{144} ** 32);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "program_id":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],
        \\  "data":"ping",
        \\  "data_encoding":"utf8",
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            program_id_base58,
            account_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const signature = try sendLegacyTransactionFromInvocationSpecJson(&mock, .{
        .program_invocation_spec_json = spec_json,
    });

    try std.testing.expectEqualStrings("mock-program-invoke-spec-legacy-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(@as(usize, 1), mock.captured_account_count);
    try std.testing.expectEqual(@as(usize, 2), mock.captured_signer_count);
    try std.testing.expectEqualStrings(recent_blockhash_base58, mock.captured_recent_blockhash.?);
}

test "program_invoke.simulateLegacyTransactionFromInvocationSpecJson forwards nonce query" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationSimulateClient = struct {
        captured_signer_count: usize = 0,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_sig_verify: bool = false,

        pub fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            build: ?rpc_types.LegacyInstructionsBuildOptions,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = payer;
            _ = instructions;
            self.captured_signer_count = signers.len;
            self.captured_query = build.?.blockhash_query.?;
            self.captured_nonce_authority = build.?.nonce_authority.?;
            self.captured_sig_verify = options.?.sig_verify;
            return .{ .context = .{ .slot = 1 }, .value = .{} };
        }
    };

    var mock = MockLegacyInvocationSimulateClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{145} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes(.{146} ** 32);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{147} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account = sdk.Pubkey.fromBytes(.{148} ** 32);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7],
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
        },
    );
    defer allocator.free(spec_json);

    _ = try simulateLegacyTransactionFromInvocationSpecJson(&mock, .{
        .program_invocation_spec_json = spec_json,
        .blockhash_commitment = .confirmed,
        .simulate_options = .{ .sig_verify = true },
    });

    try std.testing.expectEqual(@as(usize, 2), mock.captured_signer_count);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{
            .pubkey = nonce_account_base58,
            .commitment = .confirmed,
        } },
        mock.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, mock.captured_nonce_authority.?);
    try std.testing.expect(mock.captured_sig_verify);
}

test "program_invoke.buildLegacyMessageBase64WithBlockhashQuery bridges query-aware builder" {
    const allocator = std.testing.allocator;

    const MockLegacyQueryBuilder = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_query: ?rpc_types.BlockhashQuery = null,

        pub fn buildOwnedLegacyMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedLegacyMessage {
            _ = nonce_authority;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            self.captured_program_id = instructions[0].program_id;
            self.captured_query = blockhash_query;
            return try sdk.buildOwnedLegacyMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{113} ** 32),
                instructions,
            );
        }
    };

    var mock = MockLegacyQueryBuilder{ .allocator = allocator };

    const program_id = sdk.Pubkey.fromBytes(.{114} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{115} ** 32);
    const encoded = try buildLegacyMessageBase64WithBlockhashQuery(
        &mock,
        program_id,
        .{
            .payer = payer,
            .blockhash_query = .{ .fixed = "fixed-blockhash" },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer allocator.free(encoded);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);
    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    const expected = try sdk.buildLegacyMessageBase64(
        allocator,
        payer,
        sdk.Hash.fromBytes(.{113} ** 32),
        instructions[0..],
    );
    defer allocator.free(expected);

    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqualStrings("fixed-blockhash", mock.captured_query.?.fixed);
    try std.testing.expectEqualStrings(expected, encoded);
}

test "program_invoke.sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinner delegates query path" {
    const allocator = std.testing.allocator;

    const MockVersionedSpinnerClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_data: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn sendAndConfirmVersionedInstructionsWithBlockhashQueryWithSpinner(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
            send_transaction_options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = payer;
            _ = address_lookup_tables;
            _ = signers;
            _ = nonce_authority;
            _ = send_transaction_options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            self.captured_program_id = instructions[0].program_id;
            self.captured_query = blockhash_query;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return "mock-versioned-spinner-signature";
        }
    };

    var mock = MockVersionedSpinnerClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{116} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{117} ** 32);
    const signature = try sendAndConfirmVersionedTransactionWithBlockhashQueryWithSpinner(
        &mock,
        program_id,
        .{
            .payer = payer,
            .address_lookup_tables = &.{},
            .signers = &.{},
            .blockhash_query = .{ .cluster = .{ .commitment = .confirmed } },
            .instruction = .{
                .data = "70696e67",
                .data_encoding = .hex,
            },
            .commitment = .confirmed,
        },
    );

    try std.testing.expectEqualStrings("mock-versioned-spinner-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_query.?.cluster.commitment.?);
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
}

test "program_invoke.getFeeForLegacyMessageWithBlockhashQuery builds message then queries fee" {
    const allocator = std.testing.allocator;

    const MockLegacyFeeClient = struct {
        allocator: Allocator,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_commitment: ?rpc_types.Commitment = null,
        captured_message: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_message) |value| self.allocator.free(value);
        }

        pub fn buildOwnedLegacyMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedLegacyMessage {
            _ = nonce_authority;
            self.captured_query = blockhash_query;
            return try sdk.buildOwnedLegacyMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{118} ** 32),
                instructions,
            );
        }

        pub fn getFeeForMessage(
            self: *@This(),
            encoded_message: []const u8,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            self.captured_commitment = commitment;
            self.captured_message = try self.allocator.dupe(u8, encoded_message);
            return .{ .context_slot = 5, .value = 999 };
        }
    };

    var mock = MockLegacyFeeClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{119} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{120} ** 32);
    const fee = try getFeeForLegacyMessageWithBlockhashQuery(
        &mock,
        program_id,
        .{
            .payer = payer,
            .blockhash_query = .{ .fixed = "fee-fixed-blockhash" },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
        .{ .commitment = .finalized },
    );

    try std.testing.expectEqualStrings("fee-fixed-blockhash", mock.captured_query.?.fixed);
    try std.testing.expectEqual(rpc_types.Commitment.finalized, mock.captured_commitment.?);
    try std.testing.expect(mock.captured_message.?.len > 0);
    try std.testing.expectEqual(@as(u64, 5), fee.context_slot);
    try std.testing.expectEqual(@as(?u64, 999), fee.value);
}

test "program_invoke.buildVersionedMessageBase64WithLatestBlockhash uses cluster query" {
    const allocator = std.testing.allocator;

    const MockVersionedLatestBuilder = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_query: ?rpc_types.BlockhashQuery = null,

        pub fn buildOwnedVersionedMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedVersionedMessageV0 {
            _ = nonce_authority;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expectEqual(@as(usize, 0), address_lookup_tables.len);
            self.captured_program_id = instructions[0].program_id;
            self.captured_query = blockhash_query;
            return try sdk.buildOwnedVersionedMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{121} ** 32),
                instructions,
                address_lookup_tables,
            );
        }
    };

    var mock = MockVersionedLatestBuilder{ .allocator = allocator };

    const program_id = sdk.Pubkey.fromBytes(.{122} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{123} ** 32);
    const encoded = try buildVersionedMessageBase64WithLatestBlockhash(
        &mock,
        program_id,
        .{
            .payer = payer,
            .blockhash_commitment = .processed,
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer allocator.free(encoded);

    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(rpc_types.Commitment.processed, mock.captured_query.?.cluster.commitment.?);
}

test "program_invoke.sendLegacyTransactionWithLatestBlockhash delegates latest cluster path" {
    const allocator = std.testing.allocator;

    const MockLegacyLatestClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_data: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn sendLegacyInstructionsWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = payer;
            _ = signers;
            _ = nonce_authority;
            _ = options;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            self.captured_program_id = instructions[0].program_id;
            self.captured_query = blockhash_query;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return "mock-latest-legacy-signature";
        }
    };

    var mock = MockLegacyLatestClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{124} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{125} ** 32);
    const signature = try sendLegacyTransactionWithLatestBlockhash(
        &mock,
        program_id,
        .{
            .payer = payer,
            .signers = &.{},
            .blockhash_commitment = .finalized,
            .instruction = .{
                .data = "70696e67",
                .data_encoding = .hex,
            },
        },
    );

    try std.testing.expectEqualStrings("mock-latest-legacy-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(rpc_types.Commitment.finalized, mock.captured_query.?.cluster.commitment.?);
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
}

test "program_invoke.getFeeForVersionedMessageWithLatestBlockhash uses latest cluster query" {
    const allocator = std.testing.allocator;

    const MockVersionedLatestFeeClient = struct {
        allocator: Allocator,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn buildOwnedVersionedMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedVersionedMessageV0 {
            _ = nonce_authority;
            self.captured_query = blockhash_query;
            return try sdk.buildOwnedVersionedMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{126} ** 32),
                instructions,
                address_lookup_tables,
            );
        }

        pub fn getFeeForMessage(
            self: *@This(),
            encoded_message: []const u8,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = encoded_message;
            self.captured_commitment = commitment;
            return .{ .context_slot = 8, .value = 555 };
        }
    };

    var mock = MockVersionedLatestFeeClient{ .allocator = allocator };

    const program_id = sdk.Pubkey.fromBytes(.{127} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{128} ** 32);
    const fee = try getFeeForVersionedMessageWithLatestBlockhash(
        &mock,
        program_id,
        .{
            .payer = payer,
            .blockhash_commitment = .confirmed,
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
        .{ .commitment = .processed },
    );

    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_query.?.cluster.commitment.?);
    try std.testing.expectEqual(rpc_types.Commitment.processed, mock.captured_commitment.?);
    try std.testing.expectEqual(@as(u64, 8), fee.context_slot);
    try std.testing.expectEqual(@as(?u64, 555), fee.value);
}

test "program_invoke.buildLegacyTransactionBase64WithBlockhashQuery matches sdk encoding" {
    const allocator = std.testing.allocator;

    const MockLegacyQueryTxBuilder = struct {
        allocator: Allocator,
        captured_query: ?rpc_types.BlockhashQuery = null,

        pub fn buildSignedLegacyTransactionWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.SignedLegacyTransaction {
            _ = nonce_authority;
            self.captured_query = blockhash_query;
            return try sdk.buildSignedLegacyTransaction(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{129} ** 32),
                instructions,
                signers,
            );
        }
    };

    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic(.{130} ** 32);
    const payer_secret = payer_raw.secret_key.toBytes();
    const payer_signer = try sdk.Keypair.fromSecretKeyBytes(payer_secret);
    const payer = sdk.Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const signers = [_]sdk.Keypair{payer_signer};

    var mock = MockLegacyQueryTxBuilder{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{131} ** 32);
    const actual = try buildLegacyTransactionBase64WithBlockhashQuery(
        &mock,
        program_id,
        .{
            .payer = payer,
            .signers = &signers,
            .blockhash_query = .{ .fixed = "legacy-fixed-blockhash" },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer allocator.free(actual);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);
    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    const expected = try sdk.buildLegacyTransactionBase64(
        allocator,
        payer,
        sdk.Hash.fromBytes(.{129} ** 32),
        instructions[0..],
        &signers,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings("legacy-fixed-blockhash", mock.captured_query.?.fixed);
    try std.testing.expectEqualStrings(expected, actual);
}

test "program_invoke.buildVersionedMessageBytesWithLatestBlockhash matches sdk serialization" {
    const allocator = std.testing.allocator;

    const MockVersionedLatestBytesBuilder = struct {
        allocator: Allocator,
        captured_query: ?rpc_types.BlockhashQuery = null,

        pub fn buildOwnedVersionedMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedVersionedMessageV0 {
            _ = nonce_authority;
            self.captured_query = blockhash_query;
            return try sdk.buildOwnedVersionedMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{132} ** 32),
                instructions,
                address_lookup_tables,
            );
        }
    };

    var mock = MockVersionedLatestBytesBuilder{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{133} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{134} ** 32);
    const actual = try buildVersionedMessageBytesWithLatestBlockhash(
        &mock,
        program_id,
        .{
            .payer = payer,
            .blockhash_commitment = .confirmed,
            .instruction = .{
                .data = "70696e67",
                .data_encoding = .hex,
            },
        },
    );
    defer allocator.free(actual);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "70696e67",
            .data_encoding = .hex,
        },
    );
    defer owned_instruction.deinit(allocator);
    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    const expected = try sdk.buildVersionedMessageBytes(
        allocator,
        payer,
        sdk.Hash.fromBytes(.{132} ** 32),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_query.?.cluster.commitment.?);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "program_invoke.buildLegacyMessageBytesWithBlockhashQueryFromJson parses program id string" {
    const allocator = std.testing.allocator;

    const MockLegacyQueryBytesBuilder = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,

        pub fn buildOwnedLegacyMessageWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
        ) !sdk.OwnedLegacyMessage {
            _ = blockhash_query;
            _ = nonce_authority;
            self.captured_program_id = instructions[0].program_id;
            return try sdk.buildOwnedLegacyMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{135} ** 32),
                instructions,
            );
        }
    };

    var mock = MockLegacyQueryBytesBuilder{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{136} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = sdk.Pubkey.fromBytes(.{137} ** 32);

    const bytes = try buildLegacyMessageBytesWithBlockhashQueryFromJson(
        &mock,
        program_id_base58,
        .{
            .payer = payer,
            .blockhash_query = .{ .fixed = "fixed-blockhash-json" },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer allocator.free(bytes);

    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expect(bytes.len > 0);
}

test "program_invoke.sendVersionedTransactionWithLatestBlockhashFromJson parses program id string" {
    const allocator = std.testing.allocator;

    const MockVersionedLatestClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,

        pub fn sendVersionedInstructionsWithBlockhashQuery(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            blockhash_query: rpc_types.BlockhashQuery,
            nonce_authority: ?sdk.Pubkey,
            options: ?rpc_types.SendVersionedInstructionsOptions,
        ) ![]const u8 {
            _ = self.allocator;
            _ = payer;
            _ = address_lookup_tables;
            _ = signers;
            _ = blockhash_query;
            _ = nonce_authority;
            _ = options;
            self.captured_program_id = instructions[0].program_id;
            return "mock-versioned-latest-json-signature";
        }
    };

    var mock = MockVersionedLatestClient{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{138} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = sdk.Pubkey.fromBytes(.{139} ** 32);

    const signature = try sendVersionedTransactionWithLatestBlockhashFromJson(
        &mock,
        program_id_base58,
        .{
            .payer = payer,
            .address_lookup_tables = &.{},
            .signers = &.{},
            .blockhash_commitment = .processed,
            .instruction = .{
                .data = "70696e67",
                .data_encoding = .hex,
            },
        },
    );

    try std.testing.expectEqualStrings("mock-versioned-latest-json-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
}

test "program_invoke.sendVersionedTransactionFromInvocationSpecJson forwards latest blockhash options and lookup tables" {
    const allocator = std.testing.allocator;

    const MockVersionedInvocationClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_blockhash_commitment: ?rpc_types.Commitment = null,
        captured_skip_preflight: bool = false,

        pub fn sendVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendVersionedInstructionsOptions,
        ) ![]const u8 {
            _ = self.allocator;
            _ = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_lookup_count = address_lookup_tables.len;
            self.captured_signer_count = signers.len;
            self.captured_blockhash_commitment = options.?.blockhash_commitment.?;
            self.captured_skip_preflight = options.?.send_transaction_options.?.skip_preflight;
            return "mock-program-invoke-spec-versioned-signature";
        }
    };

    var mock = MockVersionedInvocationClient{ .allocator = allocator };
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{149} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{150} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{151} ** 32);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{152} ** 32);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "data":"AQ==",
        \\  "data_encoding":"base64"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
        },
    );
    defer allocator.free(spec_json);

    const signature = try sendVersionedTransactionFromInvocationSpecJson(&mock, .{
        .program_invocation_spec_json = spec_json,
        .blockhash_commitment = .processed,
        .send_transaction_options = .{ .skip_preflight = true },
    });

    try std.testing.expectEqualStrings("mock-program-invoke-spec-versioned-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(@as(usize, 1), mock.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
    try std.testing.expectEqual(rpc_types.Commitment.processed, mock.captured_blockhash_commitment.?);
    try std.testing.expect(mock.captured_skip_preflight);
}

test "program_invoke.simulateVersionedTransaction delegates instruction and options" {
    const allocator = std.testing.allocator;

    const MockVersionedClient = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_program_id: ?sdk.Pubkey = null,
        captured_lookup_table_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_data: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn simulateVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            build_options: ?rpc_types.VersionedInstructionsBuildOptions,
            simulate_options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expect(build_options != null);
            try std.testing.expect(simulate_options != null);
            self.captured_payer = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_lookup_table_count = address_lookup_tables.len;
            self.captured_signer_count = signers.len;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return .{ .units_consumed = 7 };
        }
    };

    var mock = MockVersionedClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{98} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{99} ** 32);

    const simulated = try simulateVersionedTransaction(
        &mock,
        program_id,
        .{
            .payer = payer,
            .address_lookup_tables = &.{},
            .signers = &.{},
            .instruction = .{
                .data = "cGluZw==",
                .data_encoding = .base64,
            },
            .build = .{ .recent_blockhash = "ignored-by-mock" },
            .rpc = .{ .inner_instructions = true },
        },
    );

    try std.testing.expect(mock.captured_payer.?.eql(payer));
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(@as(usize, 0), mock.captured_lookup_table_count);
    try std.testing.expectEqual(@as(usize, 0), mock.captured_signer_count);
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
    try std.testing.expectEqual(@as(?u64, 7), simulated.units_consumed);
}

test "program_invoke.buildLegacyMessageBase64WithOptions bridges blockhash-aware builder" {
    const allocator = std.testing.allocator;

    const MockLegacyBuilder = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_program_id: ?sdk.Pubkey = null,
        captured_recent_blockhash: ?[]const u8 = null,
        captured_data: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn buildOwnedLegacyMessageWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            build_options: ?rpc_types.LegacyInstructionsBuildOptions,
        ) !sdk.OwnedLegacyMessage {
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expect(build_options != null);
            self.captured_payer = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_recent_blockhash = build_options.?.recent_blockhash;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return try sdk.buildOwnedLegacyMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{100} ** 32),
                instructions,
            );
        }
    };

    var mock = MockLegacyBuilder{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{101} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{102} ** 32);

    const encoded = try buildLegacyMessageBase64WithOptions(
        &mock,
        program_id,
        .{
            .payer = payer,
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
            .build = .{ .recent_blockhash = "mock-blockhash" },
        },
    );
    defer allocator.free(encoded);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    const expected = try sdk.buildLegacyMessageBase64(
        allocator,
        payer,
        sdk.Hash.fromBytes(.{100} ** 32),
        instructions[0..],
    );
    defer allocator.free(expected);

    try std.testing.expect(mock.captured_payer.?.eql(payer));
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqualStrings("mock-blockhash", mock.captured_recent_blockhash.?);
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
    try std.testing.expectEqualStrings(expected, encoded);
}

test "program_invoke.sendAndConfirmLegacyTransactionWithSpinner delegates spinner path" {
    const allocator = std.testing.allocator;

    const MockLegacySpinnerClient = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_program_id: ?sdk.Pubkey = null,
        captured_data: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_data) |value| self.allocator.free(value);
        }

        pub fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expectEqual(@as(usize, 0), signers.len);
            try std.testing.expect(options != null);
            self.captured_payer = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_data = try self.allocator.dupe(u8, instructions[0].data);
            return "mock-spinner-signature";
        }
    };

    var mock = MockLegacySpinnerClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{103} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{104} ** 32);

    const signature = try sendAndConfirmLegacyTransactionWithSpinner(
        &mock,
        program_id,
        .{
            .payer = payer,
            .signers = &.{},
            .instruction = .{
                .data = "cGluZw==",
                .data_encoding = .base64,
            },
            .rpc = .{ .recent_blockhash = "mock-blockhash" },
        },
    );

    try std.testing.expectEqualStrings("mock-spinner-signature", signature);
    try std.testing.expect(mock.captured_payer.?.eql(payer));
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqualStrings("ping", mock.captured_data.?);
}

test "program_invoke.getFeeForVersionedMessageWithOptions builds message then queries fee" {
    const allocator = std.testing.allocator;

    const MockVersionedFeeClient = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_program_id: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,
        captured_message: ?[]u8 = null,

        fn deinit(self: *@This()) void {
            if (self.captured_message) |value| self.allocator.free(value);
        }

        pub fn buildOwnedVersionedMessageWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            build_options: ?rpc_types.VersionedInstructionsBuildOptions,
        ) !sdk.OwnedVersionedMessageV0 {
            _ = build_options;
            try std.testing.expectEqual(@as(usize, 1), instructions.len);
            try std.testing.expectEqual(@as(usize, 0), address_lookup_tables.len);
            self.captured_payer = payer;
            self.captured_program_id = instructions[0].program_id;
            return try sdk.buildOwnedVersionedMessage(
                self.allocator,
                payer,
                sdk.Hash.fromBytes(.{105} ** 32),
                instructions,
                address_lookup_tables,
            );
        }

        pub fn getFeeForMessage(
            self: *@This(),
            encoded_message: []const u8,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            self.captured_commitment = commitment;
            self.captured_message = try self.allocator.dupe(u8, encoded_message);
            return .{ .context_slot = 9, .value = 1234 };
        }
    };

    var mock = MockVersionedFeeClient{ .allocator = allocator };
    defer mock.deinit();

    const program_id = sdk.Pubkey.fromBytes(.{106} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{107} ** 32);

    const fee = try getFeeForVersionedMessageWithOptions(
        &mock,
        program_id,
        .{
            .payer = payer,
            .instruction = .{
                .data = "70696e67",
                .data_encoding = .hex,
            },
            .build = .{ .recent_blockhash = "ignored-by-mock" },
        },
        .{ .commitment = .confirmed },
    );

    try std.testing.expect(mock.captured_payer.?.eql(payer));
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_commitment.?);
    try std.testing.expect(mock.captured_message.?.len > 0);
    try std.testing.expectEqual(@as(u64, 9), fee.context_slot);
    try std.testing.expectEqual(@as(?u64, 1234), fee.value);
}
