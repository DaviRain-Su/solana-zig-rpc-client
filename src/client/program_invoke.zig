const std = @import("std");
const instruction_schema = @import("./instruction_schema.zig");
const instructions_invoke = @import("./instructions_invoke.zig");
const invoke = @import("./invoke.zig");
const invocation_spec_json = @import("./invocation_spec_json.zig");
const rpc_types = @import("./rpc_types.zig");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const InstructionDataEncoding = enum {
    base64,
    hex,
    utf8,
};

pub const SchemaEncoding = instruction_schema.SchemaEncoding;

pub const BuildError = Allocator.Error || error{
    InvalidProgramInvokeSpec,
    InvalidHexData,
    WriteFailed,
};

pub const BuildInstructionOptions = struct {
    accounts: []const sdk.AccountMeta = &.{},
    accounts_json: ?[]const u8 = null,
    data: ?[]const u8 = null,
    data_bytes: ?[]const u8 = null,
    data_encoding: InstructionDataEncoding = .base64,
    data_schema_json: ?[]const u8 = null,
    args_json: ?[]const u8 = null,
    schema_encoding: SchemaEncoding = .borsh,
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

fn appendOrUpgradeAccountMeta(
    allocator: Allocator,
    accounts: *std.ArrayListUnmanaged(sdk.AccountMeta),
    pubkey: sdk.Pubkey,
    is_signer: bool,
    is_writable: bool,
) !void {
    for (accounts.items) |*account| {
        if (std.meta.eql(account.pubkey, pubkey)) {
            account.is_signer = account.is_signer or is_signer;
            account.is_writable = account.is_writable or is_writable;
            return;
        }
    }

    try accounts.append(allocator, .{
        .pubkey = pubkey,
        .is_signer = is_signer,
        .is_writable = is_writable,
    });
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

fn appendUniqueSignerFromKeypair(
    allocator: Allocator,
    signers: *std.ArrayListUnmanaged(sdk.Keypair),
    signer: sdk.Keypair,
) !void {
    for (signers.items) |existing_signer| {
        if (existing_signer.public_key.eql(signer.public_key)) return;
    }

    try signers.append(allocator, signer);
}

fn parseJsonSecretKeyBytes(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
    return switch (value) {
        .array => |array| blk: {
            const bytes = try allocator.alloc(u8, array.items.len);
            errdefer allocator.free(bytes);

            for (array.items, 0..) |item, index| {
                if (item != .integer or item.integer < 0 or item.integer > 255) {
                    return error.InvalidProgramInvokeSpec;
                }
                bytes[index] = @intCast(item.integer);
            }

            break :blk bytes;
        },
        .object => |object| blk: {
            if (findJsonObjectField(object, &.{ "bytes", "secretKeyBytes", "secret_key_bytes" })) |field| {
                break :blk try parseJsonSecretKeyBytes(allocator, field);
            }
            return error.InvalidProgramInvokeSpec;
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseJsonSecretKeypair(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!sdk.Keypair {
    return switch (value) {
        .string => sdk.Keypair.fromBase58SecretKey(allocator, value.string) catch return error.InvalidProgramInvokeSpec,
        .array => blk: {
            const bytes = try parseJsonSecretKeyBytes(allocator, value);
            defer allocator.free(bytes);
            break :blk sdk.Keypair.fromSecretKeySlice(bytes) catch return error.InvalidProgramInvokeSpec;
        },
        .object => |object| blk: {
            if (findJsonObjectField(object, &.{
                "base58",
                "secretKey",
                "secret_key",
                "privateKey",
                "private_key",
            })) |field| {
                break :blk try parseJsonSecretKeypair(allocator, field);
            }
            if (findJsonObjectField(object, &.{ "bytes", "secretKeyBytes", "secret_key_bytes" })) |field| {
                break :blk try parseJsonSecretKeypair(allocator, field);
            }
            return error.InvalidProgramInvokeSpec;
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

fn buildAdditionalSignerSecretKeysJsonFromProgramInvokeSpec(
    allocator: Allocator,
    payer_keypair: sdk.Keypair,
    additional_signers_value: std.json.Value,
) BuildError!?[]u8 {
    if (additional_signers_value != .array) return error.InvalidProgramInvokeSpec;

    var signers = std.ArrayListUnmanaged(sdk.Keypair){};
    defer signers.deinit(allocator);
    try appendUniqueSignerFromKeypair(allocator, &signers, payer_keypair);

    for (additional_signers_value.array.items) |additional_signer| {
        const signer = try parseJsonSecretKeypair(allocator, additional_signer);
        try appendUniqueSignerFromKeypair(allocator, &signers, signer);
    }

    if (signers.items.len <= 1) return null;

    var json_buffer: std.ArrayListUnmanaged(u8) = .{};
    errdefer json_buffer.deinit(allocator);

    try json_buffer.append(allocator, '[');
    for (signers.items[1..], 0..) |signer, index| {
        const encoded_signer = try sdk.encodeBase58(allocator, &signer.secret_key);
        defer allocator.free(encoded_signer);

        if (index != 0) {
            try json_buffer.append(allocator, ',');
        }

        try json_buffer.append(allocator, '"');
        try json_buffer.appendSlice(allocator, encoded_signer);
        try json_buffer.append(allocator, '"');
    }
    try json_buffer.append(allocator, ']');

    return try json_buffer.toOwnedSlice(allocator);
}

fn findJsonObjectField(object: std.json.ObjectMap, comptime names: []const []const u8) ?std.json.Value {
    inline for (names) |name| {
        if (object.get(name)) |value| return value;
    }
    return null;
}

fn parseJsonBool(value: std.json.Value) BuildError!bool {
    return switch (value) {
        .bool => value.bool,
        .string => {
            if (std.ascii.eqlIgnoreCase(value.string, "true")) return true;
            if (std.ascii.eqlIgnoreCase(value.string, "false")) return false;
            return error.InvalidProgramInvokeSpec;
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseJsonPubkey(allocator: Allocator, value: std.json.Value) BuildError!sdk.Pubkey {
    return switch (value) {
        .string => sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidProgramInvokeSpec,
        .object => blk: {
            const field = findJsonObjectField(value.object, &.{
                "pubkey",
                "publicKey",
                "public_key",
                "address",
                "key",
                "base58",
                "programId",
                "program_id",
            }) orelse return error.InvalidProgramInvokeSpec;
            if (field != .string) return error.InvalidProgramInvokeSpec;
            break :blk sdk.Pubkey.fromBase58(allocator, field.string) catch return error.InvalidProgramInvokeSpec;
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

const ParsedAccountMetaString = struct {
    pubkey: []const u8,
    is_signer: bool = false,
    is_writable: bool = false,
};

fn parseAccountMetaString(value: []const u8) BuildError!ParsedAccountMetaString {
    const colon_index = std.mem.lastIndexOfScalar(u8, value, ':') orelse return .{ .pubkey = value };
    if (colon_index == 0 or colon_index + 1 >= value.len) return error.InvalidProgramInvokeSpec;

    var parsed: ParsedAccountMetaString = .{
        .pubkey = value[0..colon_index],
    };
    for (value[colon_index + 1 ..]) |flag| {
        switch (std.ascii.toLower(flag)) {
            's' => parsed.is_signer = true,
            'w' => parsed.is_writable = true,
            else => return error.InvalidProgramInvokeSpec,
        }
    }
    return parsed;
}

fn parseJsonAccountMeta(allocator: Allocator, value: std.json.Value) BuildError!sdk.AccountMeta {
    return switch (value) {
        .string => blk: {
            const parsed = try parseAccountMetaString(value.string);
            break :blk .{
                .pubkey = sdk.Pubkey.fromBase58(allocator, parsed.pubkey) catch return error.InvalidProgramInvokeSpec,
                .is_signer = parsed.is_signer,
                .is_writable = parsed.is_writable,
            };
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

    return try parseAccountsValue(allocator, parsed.value);
}

fn parseAccountsValue(allocator: Allocator, value: std.json.Value) BuildError!OwnedAccounts {
    const items = switch (value) {
        .array => value.array.items,
        else => return error.InvalidProgramInvokeSpec,
    };

    var metas = std.ArrayListUnmanaged(sdk.AccountMeta){};
    defer metas.deinit(allocator);
    try metas.ensureTotalCapacity(allocator, items.len);

    for (items) |account| {
        const parsed_account = try parseJsonAccountMeta(allocator, account);
        try appendOrUpgradeAccountMeta(
            allocator,
            &metas,
            parsed_account.pubkey,
            parsed_account.is_signer,
            parsed_account.is_writable,
        );
    }

    return .{ .metas = try metas.toOwnedSlice(allocator) };
}

fn parseProgramId(allocator: Allocator, program_id: []const u8) BuildError!sdk.Pubkey {
    return sdk.Pubkey.fromBase58(allocator, program_id) catch return error.InvalidProgramInvokeSpec;
}

fn stringifyCanonicalAccountsJson(
    allocator: Allocator,
    metas: []const sdk.AccountMeta,
) Allocator.Error![]u8 {
    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    json_buffer.writer.writeByte('[') catch unreachable;
    for (metas, 0..) |meta, index| {
        if (index != 0) json_buffer.writer.writeByte(',') catch unreachable;

        const pubkey_base58 = try meta.pubkey.toBase58(allocator);
        defer allocator.free(pubkey_base58);

        json_buffer.writer.print(
            "{{\"pubkey\":\"{s}\",\"is_signer\":{s},\"is_writable\":{s}}}",
            .{
                pubkey_base58,
                if (meta.is_signer) "true" else "false",
                if (meta.is_writable) "true" else "false",
            },
        ) catch unreachable;
    }
    json_buffer.writer.writeByte(']') catch unreachable;

    return try allocator.dupe(u8, json_buffer.written());
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

pub fn buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
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
    const payer_keypair = try parseJsonSecretKeypair(allocator, payer_secret_key_value);
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_keypair.secret_key);
    defer allocator.free(payer_secret_key_base58);

    const program_id_value = findJsonObjectField(object, &.{ "program_id", "programId" }) orelse
        return error.InvalidProgramInvokeSpec;
    const program_id = try parseJsonPubkey(allocator, program_id_value);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const accounts_value = findJsonObjectField(object, &.{ "accounts", "accounts_json", "accountsJson" });
    const data_value = findJsonObjectField(object, &.{"data"});
    const data_bytes_value = findJsonObjectField(object, &.{ "data_bytes", "dataBytes" });
    const data_schema_value = findJsonObjectField(object, &.{ "data_schema", "dataSchema" });
    const args_value = findJsonObjectField(object, &.{"args"});
    if (data_value != null and data_bytes_value != null) return error.InvalidProgramInvokeSpec;
    if ((data_value != null or data_bytes_value != null) and
        (data_schema_value != null or args_value != null))
    {
        return error.InvalidProgramInvokeSpec;
    }
    if ((data_schema_value == null) != (args_value == null)) return error.InvalidProgramInvokeSpec;

    var owned_additional_signers_json: ?[]u8 = null;
    defer if (owned_additional_signers_json) |value| allocator.free(value);
    const additional_signer_secret_keys_json = if (findJsonObjectField(object, &.{ "additional_signer_secret_keys", "additionalSignerSecretKeys" })) |value| blk: {
        const encoded = try buildAdditionalSignerSecretKeysJsonFromProgramInvokeSpec(
            allocator,
            payer_keypair,
            value,
        );
        if (encoded) |deduped| {
            owned_additional_signers_json = deduped;
            break :blk deduped;
        }

        break :blk null;
    } else null;

    var owned_lookup_tables_json: ?[]u8 = null;
    defer if (owned_lookup_tables_json) |value| allocator.free(value);
    const address_lookup_tables_json = if (findJsonObjectField(object, &.{ "address_lookup_tables", "addressLookupTables" })) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_lookup_tables_json = encoded;
        break :blk encoded;
    } else null;

    const recent_blockhash = if (findJsonObjectField(object, &.{ "recent_blockhash", "recentBlockhash" })) |value| blk: {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        break :blk value.string;
    } else null;
    var owned_nonce_account: ?[]u8 = null;
    defer if (owned_nonce_account) |value| allocator.free(value);
    const nonce_account = if (findJsonObjectField(object, &.{ "nonce_account", "nonceAccount" })) |value| blk: {
        const pubkey = try parseJsonPubkey(allocator, value);
        const encoded = try pubkey.toBase58(allocator);
        owned_nonce_account = encoded;
        break :blk encoded;
    } else null;
    var owned_nonce_authority_secret_key: ?[]u8 = null;
    defer if (owned_nonce_authority_secret_key) |value| allocator.free(value);
    const nonce_authority_secret_key = if (findJsonObjectField(object, &.{ "nonce_authority_secret_key", "nonceAuthoritySecretKey" })) |value| blk: {
        const keypair = try parseJsonSecretKeypair(allocator, value);
        const encoded = try sdk.encodeBase58(allocator, &keypair.secret_key);
        owned_nonce_authority_secret_key = encoded;
        break :blk encoded;
    } else null;

    var owned_accounts_json: ?[]u8 = null;
    defer if (owned_accounts_json) |value| allocator.free(value);
    const accounts_json = if (accounts_value) |value| blk: {
        var parsed_accounts = try parseAccountsValue(allocator, value);
        defer parsed_accounts.deinit(allocator);
        const encoded = try stringifyCanonicalAccountsJson(allocator, parsed_accounts.metas);
        owned_accounts_json = encoded;
        break :blk encoded;
    } else null;

    const data = if (data_value) |value| blk: {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        break :blk value.string;
    } else null;
    const data_encoding = if (findJsonObjectField(object, &.{ "data_encoding", "dataEncoding", "encoding" })) |value| blk: {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        break :blk value.string;
    } else null;
    const schema_encoding = if (findJsonObjectField(object, &.{ "schema_encoding", "schemaEncoding" })) |value| blk: {
        if (value != .string) return error.InvalidProgramInvokeSpec;
        break :blk try parseSchemaEncoding(value.string);
    } else .borsh;
    if (data_schema_value != null and data_encoding != null) return error.InvalidProgramInvokeSpec;
    if (data_schema_value == null and findJsonObjectField(object, &.{ "schema_encoding", "schemaEncoding" }) != null) {
        return error.InvalidProgramInvokeSpec;
    }

    var owned_data_bytes_json: ?[]u8 = null;
    defer if (owned_data_bytes_json) |value| allocator.free(value);
    const data_bytes_json = if (data_schema_value) |schema| blk: {
        const encoded_instruction_data = instruction_schema.encodeInstructionDataFromSchemaValue(
            allocator,
            schema,
            args_value.?,
            schema_encoding,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidHexData => return error.InvalidHexData,
            error.InvalidBase64Data, error.InvalidInstructionSchema => return error.InvalidProgramInvokeSpec,
        };
        defer allocator.free(encoded_instruction_data);

        const encoded = try stringifyByteArrayJson(allocator, encoded_instruction_data);
        owned_data_bytes_json = encoded;
        break :blk encoded;
    } else if (data_bytes_value) |value| blk: {
        const encoded = try stringifyJsonValue(allocator, value);
        owned_data_bytes_json = encoded;
        break :blk encoded;
    } else null;
    const resolved_data = if (data_schema_value != null) null else data;
    const resolved_data_encoding = if (data_schema_value != null) null else data_encoding;

    return invocation_spec_json.buildInstructionInvocationSpecJson(allocator, .{
        .payer_secret_key = payer_secret_key_base58,
        .additional_signer_secret_keys_json = additional_signer_secret_keys_json,
        .address_lookup_tables_json = address_lookup_tables_json,
        .recent_blockhash = recent_blockhash,
        .nonce_account = nonce_account,
        .nonce_authority_secret_key = nonce_authority_secret_key,
        .instruction = .{
            .program_id = program_id_base58,
            .accounts_json = accounts_json,
            .data = resolved_data,
            .data_encoding = resolved_data_encoding,
            .data_bytes_json = data_bytes_json,
        },
    }) catch |err| switch (err) {
        error.InvalidInvocationSpec => return error.InvalidProgramInvokeSpec,
        error.OutOfMemory => return error.OutOfMemory,
        error.WriteFailed => return error.WriteFailed,
    };
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

fn parseSchemaEncoding(value: []const u8) BuildError!SchemaEncoding {
    return instruction_schema.parseSchemaEncoding(value) catch return error.InvalidProgramInvokeSpec;
}

fn parseSchemaUnsigned(comptime T: type, value: std.json.Value) BuildError!T {
    return switch (value) {
        .integer => {
            if (value.integer < 0) return error.InvalidProgramInvokeSpec;
            return std.math.cast(T, value.integer) orelse return error.InvalidProgramInvokeSpec;
        },
        .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidProgramInvokeSpec,
        else => error.InvalidProgramInvokeSpec,
    };
}

fn parseSchemaSigned(comptime T: type, value: std.json.Value) BuildError!T {
    return switch (value) {
        .integer => std.math.cast(T, value.integer) orelse return error.InvalidProgramInvokeSpec,
        .string => std.fmt.parseInt(T, value.string, 10) catch return error.InvalidProgramInvokeSpec,
        else => error.InvalidProgramInvokeSpec,
    };
}

fn appendLittleEndianInt(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    comptime T: type,
    value: T,
) BuildError!void {
    var buffer: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buffer, value, .little);
    try output.appendSlice(allocator, &buffer);
}

fn appendLengthPrefixedBytes(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    bytes: []const u8,
) BuildError!void {
    const len = std.math.cast(u32, bytes.len) orelse return error.InvalidProgramInvokeSpec;
    try appendLittleEndianInt(allocator, output, u32, len);
    try output.appendSlice(allocator, bytes);
}

fn stringifyByteArrayJson(
    allocator: Allocator,
    bytes: []const u8,
) BuildError![]u8 {
    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('[');
    for (bytes, 0..) |byte, index| {
        if (index != 0) try json_buffer.writer.writeByte(',');
        try json_buffer.writer.print("{d}", .{byte});
    }
    try json_buffer.writer.writeByte(']');
    return try allocator.dupe(u8, json_buffer.written());
}

fn decodeSchemaBytesValue(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
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
                if (field != .string) return error.InvalidProgramInvokeSpec;
                break :blk try decodeInstructionData(allocator, field.string, .base64);
            }
            if (findJsonObjectField(value.object, &.{"hex"})) |field| {
                if (field != .string) return error.InvalidProgramInvokeSpec;
                break :blk try decodeInstructionData(allocator, field.string, .hex);
            }
            if (findJsonObjectField(value.object, &.{"utf8"})) |field| {
                if (field != .string) return error.InvalidProgramInvokeSpec;
                break :blk try decodeInstructionData(allocator, field.string, .utf8);
            }
            return error.InvalidProgramInvokeSpec;
        },
        else => error.InvalidProgramInvokeSpec,
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

fn parseEnumInput(
    value: std.json.Value,
) BuildError!struct {
    name: []const u8,
    payload: ?std.json.Value,
} {
    return switch (value) {
        .string => .{ .name = value.string, .payload = null },
        .object => blk: {
            if (findJsonObjectField(value.object, &.{"variant"})) |variant_value| {
                if (variant_value != .string) return error.InvalidProgramInvokeSpec;
                break :blk .{
                    .name = variant_value.string,
                    .payload = value.object.get("value"),
                };
            }

            if (value.object.count() != 1) return error.InvalidProgramInvokeSpec;
            var iterator = value.object.iterator();
            const entry = iterator.next() orelse return error.InvalidProgramInvokeSpec;
            break :blk .{
                .name = entry.key_ptr.*,
                .payload = entry.value_ptr.*,
            };
        },
        else => error.InvalidProgramInvokeSpec,
    };
}

fn encodeBorshSchemaValue(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    schema: std.json.Value,
    value: std.json.Value,
) BuildError!void {
    const type_name = schemaTypeName(schema) orelse return error.InvalidProgramInvokeSpec;

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
    if (std.mem.eql(u8, type_name, "string")) {
        if (value != .string) return error.InvalidProgramInvokeSpec;
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

    if (schema != .object) return error.InvalidProgramInvokeSpec;

    if (std.mem.eql(u8, type_name, "option")) {
        const item_schema = findJsonObjectField(schema.object, &.{"item"}) orelse return error.InvalidProgramInvokeSpec;
        if (value == .null) {
            try output.append(allocator, 0);
            return;
        }
        try output.append(allocator, 1);
        try encodeBorshSchemaValue(allocator, output, item_schema, value);
        return;
    }

    if (std.mem.eql(u8, type_name, "array")) {
        const item_schema = findJsonObjectField(schema.object, &.{"item"}) orelse return error.InvalidProgramInvokeSpec;
        const len_value = findJsonObjectField(schema.object, &.{"len"}) orelse return error.InvalidProgramInvokeSpec;
        if (value != .array) return error.InvalidProgramInvokeSpec;
        const expected_len = try parseSchemaUnsigned(usize, len_value);
        if (value.array.items.len != expected_len) return error.InvalidProgramInvokeSpec;
        for (value.array.items) |item| {
            try encodeBorshSchemaValue(allocator, output, item_schema, item);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "vec")) {
        const item_schema = findJsonObjectField(schema.object, &.{"item"}) orelse return error.InvalidProgramInvokeSpec;
        if (value != .array) return error.InvalidProgramInvokeSpec;
        const item_len = std.math.cast(u32, value.array.items.len) orelse return error.InvalidProgramInvokeSpec;
        try appendLittleEndianInt(allocator, output, u32, item_len);
        for (value.array.items) |item| {
            try encodeBorshSchemaValue(allocator, output, item_schema, item);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "struct")) {
        const fields_value = findJsonObjectField(schema.object, &.{"fields"}) orelse return error.InvalidProgramInvokeSpec;
        if (fields_value != .array or value != .object) return error.InvalidProgramInvokeSpec;
        for (fields_value.array.items) |field_value| {
            if (field_value != .object) return error.InvalidProgramInvokeSpec;
            const field_name_value = findJsonObjectField(field_value.object, &.{"name"}) orelse return error.InvalidProgramInvokeSpec;
            const field_schema = findJsonObjectField(field_value.object, &.{"type"}) orelse return error.InvalidProgramInvokeSpec;
            if (field_name_value != .string) return error.InvalidProgramInvokeSpec;
            const field_arg = value.object.get(field_name_value.string) orelse return error.InvalidProgramInvokeSpec;
            try encodeBorshSchemaValue(allocator, output, field_schema, field_arg);
        }
        return;
    }

    if (std.mem.eql(u8, type_name, "enum")) {
        const variants_value = findJsonObjectField(schema.object, &.{"variants"}) orelse return error.InvalidProgramInvokeSpec;
        if (variants_value != .array) return error.InvalidProgramInvokeSpec;

        const input = try parseEnumInput(value);
        for (variants_value.array.items, 0..) |variant_value, index| {
            if (variant_value != .object) return error.InvalidProgramInvokeSpec;
            const variant_name_value = findJsonObjectField(variant_value.object, &.{"name"}) orelse return error.InvalidProgramInvokeSpec;
            if (variant_name_value != .string) return error.InvalidProgramInvokeSpec;
            if (!std.mem.eql(u8, variant_name_value.string, input.name)) continue;

            const discriminant = std.math.cast(u8, index) orelse return error.InvalidProgramInvokeSpec;
            try output.append(allocator, discriminant);

            const inline_schema = findJsonObjectField(variant_value.object, &.{"type"});
            const fields_schema = findJsonObjectField(variant_value.object, &.{"fields"});
            if (inline_schema == null and fields_schema == null) {
                if (input.payload) |payload| {
                    if (payload != .null) return error.InvalidProgramInvokeSpec;
                }
                return;
            }

            const payload = input.payload orelse return error.InvalidProgramInvokeSpec;
            try encodeBorshSchemaValue(
                allocator,
                output,
                inline_schema orelse variant_value,
                payload,
            );
            return;
        }

        return error.InvalidProgramInvokeSpec;
    }

    return error.InvalidProgramInvokeSpec;
}

fn encodeInstructionDataFromSchemaValue(
    allocator: Allocator,
    schema: std.json.Value,
    args: std.json.Value,
    schema_encoding: SchemaEncoding,
) BuildError![]u8 {
    return instruction_schema.encodeInstructionDataFromSchemaValue(
        allocator,
        schema,
        args,
        schema_encoding,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidHexData => return error.InvalidHexData,
        error.InvalidBase64Data, error.InvalidInstructionSchema => return error.InvalidProgramInvokeSpec,
    };
}

pub fn encodeInstructionDataFromSchemaJson(
    allocator: Allocator,
    schema_json: []const u8,
    args_json: []const u8,
    schema_encoding: SchemaEncoding,
) BuildError![]u8 {
    return instruction_schema.encodeInstructionDataFromSchemaJson(
        allocator,
        schema_json,
        args_json,
        schema_encoding,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidHexData => return error.InvalidHexData,
        error.InvalidBase64Data, error.InvalidInstructionSchema => return error.InvalidProgramInvokeSpec,
    };
}

pub fn buildOwnedInstruction(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    if (options.data != null and options.data_bytes != null) return error.InvalidProgramInvokeSpec;
    if ((options.data != null or options.data_bytes != null) and
        (options.data_schema_json != null or options.args_json != null))
    {
        return error.InvalidProgramInvokeSpec;
    }
    if ((options.data_schema_json == null) != (options.args_json == null)) return error.InvalidProgramInvokeSpec;

    var json_accounts = if (options.accounts_json) |value|
        try parseAccountsJson(allocator, value)
    else
        null;
    defer if (json_accounts) |*value| value.deinit(allocator);

    var resolved_accounts = std.ArrayListUnmanaged(sdk.AccountMeta){};
    defer resolved_accounts.deinit(allocator);
    try resolved_accounts.ensureTotalCapacity(allocator, options.accounts.len + if (json_accounts) |value| value.metas.len else 0);

    for (options.accounts) |account| {
        try appendOrUpgradeAccountMeta(
            allocator,
            &resolved_accounts,
            account.pubkey,
            account.is_signer,
            account.is_writable,
        );
    }
    if (json_accounts) |value| {
        for (value.metas) |account| {
            try appendOrUpgradeAccountMeta(
                allocator,
                &resolved_accounts,
                account.pubkey,
                account.is_signer,
                account.is_writable,
            );
        }
    }

    const accounts = try resolved_accounts.toOwnedSlice(allocator);
    errdefer allocator.free(accounts);

    const data = if (options.data_bytes) |value|
        try allocator.dupe(u8, value)
    else if (options.data_schema_json) |schema_json|
        try encodeInstructionDataFromSchemaJson(
            allocator,
            schema_json,
            options.args_json.?,
            options.schema_encoding,
        )
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

    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildSignedLegacyTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildLegacyTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildSignedVersionedTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(allocator, options.signers);
    defer allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try sdk.buildVersionedTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithOptions(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

pub fn buildPreparedInvocationFromProgramInvokeSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildInvocationSpecOptions,
) !invoke.PreparedInvocation {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        .instructions,
        versioned,
        instruction_spec_json,
        options,
    );
}

pub fn buildPreferredPreparedInvocationFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !invoke.PreferredPreparedInvocation {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildPreferredPreparedInvocationFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn buildPreferredPreparedSignedTransactionFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !invoke.PreferredPreparedSignedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn buildPreferredInvocationAnalysisFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !invoke.PreferredInvocationAnalysis {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildPreferredInvocationAnalysisFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn buildPreferredResolvedInvocationExecutionResultFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !invoke.PreferredResolvedInvocationExecutionResult {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !invoke.OwnedResolvedInvocation {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
}

pub fn writeInvocationInspectionTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writeInvocationInspectionTextFromOwnedResolvedInvocationRef(
        writer,
        allocator,
        &resolved,
    );
}

pub fn allocInvocationInspectionJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocInvocationInspectionJsonFromOwnedResolvedInvocationRef(
        allocator,
        &resolved,
    );
}

pub fn writePreferredInvocationInspectionTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writePreferredInvocationInspectionTextFromOwnedResolvedInvocationRef(
        writer,
        allocator,
        rpc,
        &resolved,
        options,
    );
}

pub fn allocPreferredInvocationInspectionJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocPreferredInvocationInspectionJsonFromOwnedResolvedInvocationRef(
        allocator,
        rpc,
        &resolved,
        options,
    );
}

pub fn writeInvocationDiagnosticsTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writeInvocationDiagnosticsTextFromOwnedResolvedInvocationRef(
        writer,
        allocator,
        &resolved,
    );
}

pub fn allocInvocationDiagnosticsJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocInvocationDiagnosticsJsonFromOwnedResolvedInvocationRef(
        allocator,
        &resolved,
    );
}

pub fn writePreferredInvocationDiagnosticsTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writePreferredInvocationDiagnosticsTextFromOwnedResolvedInvocation(
        writer,
        allocator,
        rpc,
        &resolved,
        options,
    );
}

pub fn allocPreferredInvocationDiagnosticsJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocPreferredInvocationDiagnosticsJsonFromOwnedResolvedInvocation(
        allocator,
        rpc,
        &resolved,
        options,
    );
}

pub fn writeInvocationModeReportTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    build_options: invoke.BuildInvocationSpecOptions,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writeInvocationModeReportTextFromOwnedResolvedInvocation(
        writer,
        allocator,
        rpc,
        &resolved,
        build_options,
    );
}

pub fn allocInvocationModeReportJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    build_options: invoke.BuildInvocationSpecOptions,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocInvocationModeReportJsonFromOwnedResolvedInvocation(
        allocator,
        rpc,
        &resolved,
        build_options,
    );
}

pub fn writePreferredInvocationModeResolutionTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    build_options: invoke.BuildInvocationSpecOptions,
    mode_options: invoke.PreferredInvocationModeOptions,
) !void {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    try invoke.writePreferredInvocationModeResolutionTextFromOwnedResolvedInvocation(
        writer,
        allocator,
        rpc,
        &resolved,
        build_options,
        mode_options,
    );
}

pub fn allocPreferredInvocationModeResolutionJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    build_options: invoke.BuildInvocationSpecOptions,
    mode_options: invoke.PreferredInvocationModeOptions,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromProgramInvokeSpecJson(
        allocator,
        program_invocation_spec_json,
    );
    defer resolved.deinit(allocator);
    return try invoke.allocPreferredInvocationModeResolutionJsonFromOwnedResolvedInvocation(
        allocator,
        rpc,
        &resolved,
        build_options,
        mode_options,
    );
}

pub fn writeInvocationReportTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationReportTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationReportJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationReportJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationAccountsTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationAccountsTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationAccountsJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationAccountsJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationSignerPubkeysTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationSignerPubkeysTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationSignerPubkeysJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationSignerPubkeysJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationSummaryTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationSummaryTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationSummaryJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationSummaryJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationPlanTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationPlanTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationPlanJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationPlanJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationPreflightTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationPreflightTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationPreflightJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationPreflightJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationValidationTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationValidationTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationValidationJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationValidationJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn writeInvocationLookupCoverageTextFromProgramInvokeSpecJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !void {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    try instructions_invoke.writeInvocationLookupCoverageTextFromInvocationSpecJson(
        writer,
        allocator,
        instruction_spec_json,
    );
}

pub fn allocInvocationLookupCoverageJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try instructions_invoke.allocInvocationLookupCoverageJsonFromInvocationSpecJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn allocPreparedInvocationJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildInvocationSpecOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.allocPreparedInvocationJsonFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        versioned,
        instruction_spec_json,
        options,
    );
}

pub fn allocPreferredPreparedInvocationJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.allocPreferredPreparedInvocationJsonFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn allocPreferredPreparedSignedTransactionJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.allocPreferredPreparedSignedTransactionJsonFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn allocPreferredInvocationAnalysisJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.allocPreferredInvocationAnalysisJsonFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn allocPreferredResolvedInvocationExecutionResultJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.allocPreferredResolvedInvocationExecutionResultJsonFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn buildInstructionsJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildInstructionsJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
}

pub fn buildResolvedInvocationJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildResolvedInvocationJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
}

pub fn buildAddressLookupTablesJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    program_invocation_spec_json: []const u8,
) !?[]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.buildAddressLookupTablesJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
}

pub fn sendPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SendPreferredInvocationSpecOptions,
) !invoke.PreferredSignatureExecutionResult {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.sendPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn simulatePreferredTransactionExecutionResultFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SimulatePreferredInvocationSpecOptions,
) !invoke.PreferredSimulationExecutionResult {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.simulatePreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn sendAndConfirmPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SendAndConfirmPreferredInvocationSpecOptions,
) !invoke.PreferredSignatureExecutionResult {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.sendAndConfirmPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn getFeeForPreferredInvocationExecutionResultFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.GetFeeForPreferredInvocationSpecOptions,
) !invoke.PreferredFeeExecutionResult {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        program_invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);
    return try invoke.getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        rpc,
        .instructions,
        instruction_spec_json,
        options,
    );
}

pub fn allocPreferredSendExecutionResultJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SendPreferredInvocationSpecOptions,
) ![]u8 {
    var result = try sendPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        rpc,
        program_invocation_spec_json,
        options,
    );
    defer result.deinit(allocator);
    return try invoke.allocPreferredSignatureExecutionResultJson(allocator, &result);
}

pub fn allocPreferredSendAndConfirmExecutionResultJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SendAndConfirmPreferredInvocationSpecOptions,
) ![]u8 {
    var result = try sendAndConfirmPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        rpc,
        program_invocation_spec_json,
        options,
    );
    defer result.deinit(allocator);
    return try invoke.allocPreferredSignatureExecutionResultJson(allocator, &result);
}

pub fn allocPreferredSimulationExecutionResultJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.SimulatePreferredInvocationSpecOptions,
) ![]u8 {
    var result = try simulatePreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        rpc,
        program_invocation_spec_json,
        options,
    );
    defer result.deinit(allocator);
    return try invoke.allocPreferredSimulationExecutionResultJson(allocator, &result);
}

pub fn allocPreferredFeeExecutionResultJsonFromProgramInvokeSpecJson(
    allocator: Allocator,
    rpc: anytype,
    program_invocation_spec_json: []const u8,
    options: invoke.GetFeeForPreferredInvocationSpecOptions,
) ![]u8 {
    var result = try getFeeForPreferredInvocationExecutionResultFromProgramInvokeSpecJson(
        allocator,
        rpc,
        program_invocation_spec_json,
        options,
    );
    defer result.deinit(allocator);
    return try invoke.allocPreferredFeeExecutionResultJson(allocator, &result);
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

pub fn buildOwnedLegacyMessageFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) !sdk.OwnedLegacyMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBytesFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildLegacyMessageBytesFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBase64FromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildLegacyMessageBase64FromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) !sdk.SignedLegacyTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn simulateVersionedTransaction(
    self: anytype,
    program_id: sdk.Pubkey,
    options: SimulateVersionedTransactionOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instruction = try buildOwnedInstruction(self.allocator, program_id, options.instruction);
    defer owned_instruction.deinit(self.allocator);

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(self, .{
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
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.getFeeForLegacyMessageFromInvocationSpecJson(
        self,
        .{
            .instruction_spec_json = instruction_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        },
        .{ .commitment = fee_options.commitment },
    );
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

pub fn buildOwnedVersionedMessageFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBytesFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBase64FromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildVersionedMessageBase64FromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) !sdk.SignedVersionedTransaction {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJson(
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
) ![]u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(self, .{
        .instruction_spec_json = instruction_spec_json,
        .blockhash_commitment = options.blockhash_commitment,
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

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmProgramInvocationSpecRpcOptions,
) ![]const u8 {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(self, .{
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
    self: anytype,
    options: ProgramInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        self.allocator,
        options.program_invocation_spec_json,
    );
    defer self.allocator.free(instruction_spec_json);
    return try instructions_invoke.getFeeForVersionedMessageFromInvocationSpecJson(
        self,
        .{
            .instruction_spec_json = instruction_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        },
        .{ .commitment = fee_options.commitment },
    );
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedLegacyTransactionWithOptions(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedVersionedTransactionWithOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedLegacyTransactionWithBlockhashQuery(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.buildSignedVersionedTransactionWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner(
        options.payer,
        instructions[0..],
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.simulateVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithBlockhashQuery(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

    const signers = try dedupeSigners(self.allocator, options.signers);
    defer self.allocator.free(signers);

    const instructions = [_]sdk.Instruction{owned_instruction.instruction};
    return try self.sendAndConfirmVersionedInstructionsWithBlockhashQueryWithSpinner(
        options.payer,
        instructions[0..],
        options.address_lookup_tables,
        signers,
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

test "program_invoke.buildOwnedInstruction merges duplicate account metas across typed and json" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{84} ** 32);
    const typed_signer = sdk.Pubkey.fromBytes(.{85} ** 32);
    const json_only = sdk.Pubkey.fromBytes(.{86} ** 32);
    const json_only_base58 = try json_only.toBase58(allocator);
    defer allocator.free(json_only_base58);
    const typed_base58 = try typed_signer.toBase58(allocator);
    defer allocator.free(typed_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":true,\"is_writable\":true}},\"{s}\",{{\"pubkey\":\"{s}\",\"signer\":true,\"writable\":false}}]",
        .{ typed_base58, json_only_base58, typed_base58 },
    );
    defer allocator.free(accounts_json);

    const typed_accounts = [_]sdk.AccountMeta{
        sdk.AccountMeta.init(typed_signer, false, false),
    };

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .accounts = &typed_accounts,
            .accounts_json = accounts_json,
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(typed_signer));
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_writable);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(json_only));
    try std.testing.expect(!owned_instruction.instruction.accounts[1].is_signer);
    try std.testing.expect(!owned_instruction.instruction.accounts[1].is_writable);
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

test "program_invoke.encodeInstructionDataFromSchemaJson encodes borsh struct fields" {
    const allocator = std.testing.allocator;

    const encoded = try encodeInstructionDataFromSchemaJson(
        allocator,
        \\{"type":"struct","fields":[{"name":"amount","type":"u64"},{"name":"enabled","type":"bool"},{"name":"memo","type":"string"},{"name":"maybe_count","type":{"type":"option","item":"u16"}}]}
    ,
        \\{"amount":"42","enabled":true,"memo":"hi","maybe_count":7}
    ,
        .borsh,
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, &.{
        42, 0, 0, 0, 0, 0,   0,   0,
        1,  2, 0, 0, 0, 'h', 'i', 1,
        7,  0,
    }, encoded);
}

test "program_invoke.encodeInstructionDataFromSchemaJson encodes borsh enum variants" {
    const allocator = std.testing.allocator;

    const unit_encoded = try encodeInstructionDataFromSchemaJson(
        allocator,
        \\{"type":"enum","variants":[{"name":"Ping"},{"name":"SetAmount","type":"u16"}]}
    ,
        \\{"variant":"Ping"}
    ,
        .borsh,
    );
    defer allocator.free(unit_encoded);
    try std.testing.expectEqualSlices(u8, &.{0}, unit_encoded);

    const payload_encoded = try encodeInstructionDataFromSchemaJson(
        allocator,
        \\{"type":"enum","variants":[{"name":"Ping"},{"name":"SetAmount","type":"u16"},{"name":"Configure","fields":[{"name":"enabled","type":"bool"},{"name":"count","type":"u8"}]}]}
    ,
        \\{"variant":"Configure","value":{"enabled":true,"count":9}}
    ,
        .borsh,
    );
    defer allocator.free(payload_encoded);
    try std.testing.expectEqualSlices(u8, &.{ 2, 1, 9 }, payload_encoded);
}

test "program_invoke.buildOwnedInstruction encodes schema-driven instruction data" {
    const allocator = std.testing.allocator;

    const authority = sdk.Pubkey.fromBytes(.{127} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":\"{s}\",\"payload\":\"hex:010203\",\"items\":[5,6]}}",
        .{authority_base58},
    );
    defer allocator.free(args_json);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        sdk.Pubkey.fromBytes(.{128} ** 32),
        .{
            .data_schema_json = "{\"type\":\"struct\",\"fields\":[{\"name\":\"authority\",\"type\":\"pubkey\"},{\"name\":\"payload\",\"type\":\"bytes\"},{\"name\":\"items\",\"type\":{\"type\":\"vec\",\"item\":\"u16\"}}]}",
            .args_json = args_json,
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected = [_]u8{
        authority.bytes[0],  authority.bytes[1],  authority.bytes[2],  authority.bytes[3],  authority.bytes[4],  authority.bytes[5],  authority.bytes[6],  authority.bytes[7],
        authority.bytes[8],  authority.bytes[9],  authority.bytes[10], authority.bytes[11], authority.bytes[12], authority.bytes[13], authority.bytes[14], authority.bytes[15],
        authority.bytes[16], authority.bytes[17], authority.bytes[18], authority.bytes[19], authority.bytes[20], authority.bytes[21], authority.bytes[22], authority.bytes[23],
        authority.bytes[24], authority.bytes[25], authority.bytes[26], authority.bytes[27], authority.bytes[28], authority.bytes[29], authority.bytes[30], authority.bytes[31],
        3,                   0,                   0,                   0,                   1,                   2,                   3,                   2,
        0,                   0,                   0,                   5,                   0,                   6,                   0,
    };

    try std.testing.expectEqual(@as(usize, 0), owned_instruction.instruction.accounts.len);
    try std.testing.expectEqualSlices(u8, &expected, owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction accepts builtin schema type aliases" {
    const allocator = std.testing.allocator;

    const authority = sdk.Pubkey.fromBytes(.{129} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":\"{s}\",\"enabled\":\"true\",\"count\":\"0x0201\"}}",
        .{authority_base58},
    );
    defer allocator.free(args_json);

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        sdk.Pubkey.fromBytes(.{130} ** 32),
        .{
            .data_schema_json = "{\"type\":\"struct\",\"fields\":[{\"name\":\"authority\",\"type\":\"publicKey\"},{\"name\":\"enabled\",\"type\":\"boolean\"},{\"name\":\"count\",\"type\":\"uint16\"}]}",
            .args_json = args_json,
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected = [_]u8{
        authority.bytes[0],  authority.bytes[1],  authority.bytes[2],  authority.bytes[3],  authority.bytes[4],  authority.bytes[5],  authority.bytes[6],  authority.bytes[7],
        authority.bytes[8],  authority.bytes[9],  authority.bytes[10], authority.bytes[11], authority.bytes[12], authority.bytes[13], authority.bytes[14], authority.bytes[15],
        authority.bytes[16], authority.bytes[17], authority.bytes[18], authority.bytes[19], authority.bytes[20], authority.bytes[21], authority.bytes[22], authority.bytes[23],
        authority.bytes[24], authority.bytes[25], authority.bytes[26], authority.bytes[27], authority.bytes[28], authority.bytes[29], authority.bytes[30], authority.bytes[31],
        1,                   1,                   2,
    };

    try std.testing.expectEqual(@as(usize, 0), owned_instruction.instruction.accounts.len);
    try std.testing.expectEqualSlices(u8, &expected, owned_instruction.instruction.data);
}

test "program_invoke.buildInstructionInvocationSpecJsonFromProgramInvokeSpec encodes schema args into data bytes" {
    const allocator = std.testing.allocator;

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        \\{
        \\  "payer_secret_key":"payer-secret",
        \\  "program_id":"program-id",
        \\  "data_schema":{"type":"struct","fields":[{"name":"amount","type":"u16"}]},
        \\  "args":{"amount":513},
        \\  "schema_encoding":"borsh"
        \\}
        ,
    );
    defer allocator.free(instruction_spec_json);

    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"data_bytes\":[1,2]") != null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"data_schema\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"args\"") == null);
}

test "program_invoke.buildInstructionInvocationSpecJsonFromProgramInvokeSpec deduplicates additional signers" {
    const allocator = std.testing.allocator;

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{170} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);

    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{171} ** 32);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const extra_secret_key_bytes_json = try stringifyByteArrayJson(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_bytes_json);

    const program_id = sdk.Pubkey.fromBytes(.{172} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instruction_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":{{"base58":"{s}"}},
        \\  "program_id":"{s}",
        \\  "additional_signer_secret_keys":[{{"secretKey":"{s}"}},{{"bytes":{s}}},{{"base58":"{s}"}}],
        \\  "data":"ping",
        \\  "data_encoding":"utf8"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            extra_secret_key_base58,
            extra_secret_key_bytes_json,
            payer_secret_key_base58,
        },
    );
    defer allocator.free(instruction_spec_json);

    const result_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        instruction_spec_json,
    );
    defer allocator.free(result_json);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result_json, .{});
    defer parsed.deinit();

    const additional_signers = parsed.value.object.get("additional_signer_secret_keys").?.array;
    try std.testing.expectEqual(@as(usize, 1), additional_signers.items.len);
    try std.testing.expectEqualStrings(extra_secret_key_base58, additional_signers.items[0].string);
}

test "program_invoke.buildInstructionInvocationSpecJsonFromProgramInvokeSpec canonicalizes wrapped pubkeys and accounts" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{173} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account = sdk.Pubkey.fromBytes(.{174} ** 32);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const account_pubkey = sdk.Pubkey.fromBytes(.{175} ** 32);
    const account_pubkey_base58 = try account_pubkey.toBase58(allocator);
    defer allocator.free(account_pubkey_base58);

    const instruction_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"payer-secret",
        \\  "program_id":{{"address":"{s}"}},
        \\  "nonce_account":{{"publicKey":"{s}"}},
        \\  "accounts":[{{"publicKey":"{s}","signer":"true","writable":"false"}}],
        \\  "data":"ping",
        \\  "data_encoding":"utf8"
        \\}}
    ,
        .{
            program_id_base58,
            nonce_account_base58,
            account_pubkey_base58,
        },
    );
    defer allocator.free(instruction_spec_json);

    const result_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        instruction_spec_json,
    );
    defer allocator.free(result_json);

    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"program_id\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, program_id_base58) != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"nonce_account\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, nonce_account_base58) != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"pubkey\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, account_pubkey_base58) != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"is_signer\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"is_writable\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, result_json, "\"publicKey\"") == null);
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

test "program_invoke.buildOwnedInstruction accepts account aliases and string booleans" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{176} ** 32);
    const readonly = sdk.Pubkey.fromBytes(.{177} ** 32);
    const readonly_base58 = try readonly.toBase58(allocator);
    defer allocator.free(readonly_base58);
    const signer = sdk.Pubkey.fromBytes(.{178} ** 32);
    const signer_base58 = try signer.toBase58(allocator);
    defer allocator.free(signer_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"publicKey\":\"{s}\",\"isSigner\":\"false\",\"isWritable\":\"false\"}},{{\"key\":\"{s}\",\"signer\":\"true\",\"writable\":\"true\"}}]",
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

test "program_invoke.buildOwnedInstruction accepts account string shorthands" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{179} ** 32);
    const writable = sdk.Pubkey.fromBytes(.{180} ** 32);
    const writable_base58 = try writable.toBase58(allocator);
    defer allocator.free(writable_base58);
    const signer_writable = sdk.Pubkey.fromBytes(.{181} ** 32);
    const signer_writable_base58 = try signer_writable.toBase58(allocator);
    defer allocator.free(signer_writable_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[\"{s}:w\",\"{s}:sw\"]",
        .{ writable_base58, signer_writable_base58 },
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
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(writable));
    try std.testing.expect(!owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_writable);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(signer_writable));
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

test "program_invoke.sendLegacyTransaction deduplicates duplicate signers" {
    const allocator = std.testing.allocator;
    const MockLegacyClient = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = instructions;
            _ = options;
            self.captured_signer_count = signers.len;
            return "mock-signature";
        }
    };

    var mock = MockLegacyClient{ .allocator = allocator };

    const program_id = sdk.Pubkey.fromBytes(.{165} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{166} ** 32);
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes(.{167} ** 32);

    const signature = try sendLegacyTransaction(
        &mock,
        program_id,
        .{
            .payer = payer,
            .signers = &.{ duplicate_signer, duplicate_signer },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );

    try std.testing.expectEqualStrings("mock-signature", signature);
    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
}

test "program_invoke.simulateVersionedTransaction deduplicates duplicate signers" {
    const MockVersionedClient = struct {
        captured_signer_count: usize = 0,

        pub fn simulateVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            build_options: ?rpc_types.VersionedInstructionsBuildOptions,
            simulate_options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = payer;
            _ = instructions;
            _ = address_lookup_tables;
            _ = build_options;
            _ = simulate_options;
            self.captured_signer_count = signers.len;
            return .{ .units_consumed = 42 };
        }
    };

    var mock = MockVersionedClient{};
    const program_id = sdk.Pubkey.fromBytes(.{165} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{166} ** 32);
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes(.{167} ** 32);

    const simulated = try simulateVersionedTransaction(
        &mock,
        program_id,
        .{
            .payer = payer,
            .address_lookup_tables = &.{},
            .signers = &.{ duplicate_signer, duplicate_signer },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );

    try std.testing.expectEqualStrings("ping", duplicate_signer.public_key.toBytes());
    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
    try std.testing.expectEqual(@as(?u64, 42), simulated.units_consumed);
}

test "program_invoke.buildSignedLegacyTransactionWithOptions deduplicates duplicate signers" {
    const allocator = std.testing.allocator;

    const MockLegacyBuilder = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,

        pub fn buildSignedLegacyTransactionWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            build_options: ?rpc_types.LegacyInstructionsBuildOptions,
        ) !sdk.SignedLegacyTransaction {
            _ = payer;
            _ = build_options;
            self.captured_signer_count = signers.len;

            return try sdk.buildSignedLegacyTransaction(
                self.allocator,
                signers[0].public_key,
                sdk.Hash.fromBytes(.{210} ** 32),
                instructions,
                signers,
            );
        }

        fn deinit(self: *@This()) void {
            _ = self;
        }
    };

    var mock = MockLegacyBuilder{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{171} ** 32);
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes(.{172} ** 32);

    const signed = try buildSignedLegacyTransactionWithOptions(
        &mock,
        program_id,
        .{
            .payer = duplicate_signer.public_key,
            .signers = &.{ duplicate_signer, duplicate_signer },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
}

test "program_invoke.buildSignedVersionedTransactionWithOptions deduplicates duplicate signers" {
    const allocator = std.testing.allocator;

    const MockVersionedBuilder = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,

        pub fn buildSignedVersionedTransactionWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            build_options: ?rpc_types.VersionedInstructionsBuildOptions,
        ) !sdk.SignedVersionedTransaction {
            _ = payer;
            _ = build_options;
            self.captured_signer_count = signers.len;

            return try sdk.buildSignedVersionedTransaction(
                self.allocator,
                signers[0].public_key,
                sdk.Hash.fromBytes(.{220} ** 32),
                instructions,
                address_lookup_tables,
                signers,
            );
        }
    };

    var mock = MockVersionedBuilder{ .allocator = allocator };
    const program_id = sdk.Pubkey.fromBytes(.{221} ** 32);
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes(.{222} ** 32);

    const signed = try buildSignedVersionedTransactionWithOptions(
        &mock,
        program_id,
        .{
            .payer = duplicate_signer.public_key,
            .address_lookup_tables = &.{},
            .signers = &.{ duplicate_signer, duplicate_signer },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
        },
    );
    defer signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
}

test "program_invoke.sendAndConfirmVersionedTransactionWithSpinner deduplicates duplicate signers" {
    const MockVersionedSpinnerClient = struct {
        captured_signer_count: usize = 0,

        pub fn sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            options: ?rpc_types.VersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = instructions;
            _ = address_lookup_tables;
            _ = options;
            self.captured_signer_count = signers.len;
            return "mock-versioned-spinner-signature";
        }
    };

    var mock = MockVersionedSpinnerClient{};
    const program_id = sdk.Pubkey.fromBytes(.{223} ** 32);
    const payer = sdk.Pubkey.fromBytes(.{224} ** 32);
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes(.{225} ** 32);

    const signature = try sendAndConfirmVersionedTransactionWithSpinner(
        &mock,
        program_id,
        .{
            .payer = payer,
            .address_lookup_tables = &.{},
            .signers = &.{ duplicate_signer, duplicate_signer },
            .instruction = .{
                .data = "ping",
                .data_encoding = .utf8,
            },
            .rpc = .{ .recent_blockhash = "mock-blockhash" },
        },
    );

    try std.testing.expectEqualStrings("mock-versioned-spinner-signature", signature);
    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
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
    const nonce_authority_secret_key_bytes_json = try stringifyByteArrayJson(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_bytes_json);
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
        \\  "nonce_authority_secret_key":{{"bytes":{s}}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            nonce_account_base58,
            nonce_authority_secret_key_bytes_json,
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

test "program_invoke.buildLegacyTransactionBase64FromInvocationSpecJson matches direct builder" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{153} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{154} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{155} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{156} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const expected = try buildLegacyTransactionBase64(
        allocator,
        program_id,
        .{
            .payer = payer_raw.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{ payer_raw, extra_raw },
            .instruction = .{
                .data_bytes = &.{ 1, 2, 3 },
            },
        },
    );
    defer allocator.free(expected);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const actual = try buildLegacyTransactionBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "program_invoke.buildPreparedInvocationFromProgramInvokeSpecJsonWithOptions matches invoke bridge" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{166} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{167} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{168} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{169} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        spec_json,
    );
    defer allocator.free(instruction_spec_json);

    var via_program = try buildPreparedInvocationFromProgramInvokeSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        false,
        spec_json,
        .{},
    );
    defer via_program.deinit(allocator);

    var via_invoke = try invoke.buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        instruction_spec_json,
        .{},
    );
    defer via_invoke.deinit(allocator);

    const program_json = try via_program.allocResolvedInvocationJson(allocator);
    defer allocator.free(program_json);
    const invoke_json = try via_invoke.allocResolvedInvocationJson(allocator);
    defer allocator.free(invoke_json);

    try std.testing.expectEqualStrings(invoke_json, program_json);
}

test "program_invoke.buildPreferredInvocationAnalysisFromProgramInvokeSpecJson matches invoke bridge" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{170} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{171} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes(.{173} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes(.{174} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "dataBytes":[1]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        spec_json,
    );
    defer allocator.free(instruction_spec_json);

    var via_program = try buildPreferredInvocationAnalysisFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer via_program.deinit(allocator);

    var via_invoke = try invoke.buildPreferredInvocationAnalysisFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer via_invoke.deinit(allocator);

    const program_accounts_json = try via_program.allocAccountsJson(allocator);
    defer allocator.free(program_accounts_json);
    const invoke_accounts_json = try via_invoke.allocAccountsJson(allocator);
    defer allocator.free(invoke_accounts_json);

    try std.testing.expectEqualStrings(invoke_accounts_json, program_accounts_json);
    try std.testing.expectEqual(via_invoke.execution_report.selected_mode, via_program.execution_report.selected_mode);
}

test "program_invoke.buildPreferredResolvedInvocationExecutionResultFromProgramInvokeSpecJson matches invoke bridge" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{175} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes(.{176} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{177} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes(.{178} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "dataBytes":[4,5]
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

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        spec_json,
    );
    defer allocator.free(instruction_spec_json);

    var via_program = try buildPreferredResolvedInvocationExecutionResultFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        .{},
    );
    defer via_program.deinit(allocator);

    var via_invoke = try invoke.buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        .{},
    );
    defer via_invoke.deinit(allocator);

    const program_json = try via_program.allocResolvedInvocationJson(allocator);
    defer allocator.free(program_json);
    const invoke_json = try via_invoke.allocResolvedInvocationJson(allocator);
    defer allocator.free(invoke_json);

    try std.testing.expectEqualStrings(invoke_json, program_json);
    try std.testing.expectEqual(via_invoke.execution_report.selected_mode, via_program.execution_report.selected_mode);
}

test "program_invoke alloc json helpers match invoke bridge" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{207} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{208} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{209} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{210} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        spec_json,
    );
    defer allocator.free(instruction_spec_json);

    const preferred_options = invoke.BuildPreferredInvocationSpecOptions{
        .mode = .{
            .preferred_mode = .legacy,
            .allow_fallback = true,
        },
    };

    const prepared_json = try allocPreparedInvocationJsonFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        false,
        spec_json,
        .{},
    );
    defer allocator.free(prepared_json);
    const expected_prepared_json = try invoke.allocPreparedInvocationJsonFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        instruction_spec_json,
        .{},
    );
    defer allocator.free(expected_prepared_json);

    const preferred_prepared_json = try allocPreferredPreparedInvocationJsonFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        preferred_options,
    );
    defer allocator.free(preferred_prepared_json);
    const expected_preferred_prepared_json = try invoke.allocPreferredPreparedInvocationJsonFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        preferred_options,
    );
    defer allocator.free(expected_preferred_prepared_json);

    const preferred_signed_json = try allocPreferredPreparedSignedTransactionJsonFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        preferred_options,
    );
    defer allocator.free(preferred_signed_json);
    const expected_preferred_signed_json = try invoke.allocPreferredPreparedSignedTransactionJsonFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        preferred_options,
    );
    defer allocator.free(expected_preferred_signed_json);

    const analysis_json = try allocPreferredInvocationAnalysisJsonFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        preferred_options,
    );
    defer allocator.free(analysis_json);
    const expected_analysis_json = try invoke.allocPreferredInvocationAnalysisJsonFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        preferred_options,
    );
    defer allocator.free(expected_analysis_json);

    const resolved_json = try allocPreferredResolvedInvocationExecutionResultJsonFromProgramInvokeSpecJson(
        allocator,
        DummyRpc{},
        spec_json,
        preferred_options,
    );
    defer allocator.free(resolved_json);
    const expected_resolved_json = try invoke.allocPreferredResolvedInvocationExecutionResultJsonFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        instruction_spec_json,
        preferred_options,
    );
    defer allocator.free(expected_resolved_json);

    try std.testing.expectEqualStrings(expected_prepared_json, prepared_json);
    try std.testing.expectEqualStrings(expected_preferred_prepared_json, preferred_prepared_json);
    try std.testing.expectEqualStrings(expected_preferred_signed_json, preferred_signed_json);
    try std.testing.expectEqualStrings(expected_analysis_json, analysis_json);
    try std.testing.expectEqualStrings(expected_resolved_json, resolved_json);
}

test "program_invoke preferred execution result helpers match invoke bridge" {
    const allocator = std.testing.allocator;

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{219} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{220} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes(.{221} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes(.{222} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);

    const send_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(send_spec_json);

    const fee_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[4],
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
    defer allocator.free(fee_spec_json);

    const send_instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        send_spec_json,
    );
    defer allocator.free(send_instruction_spec_json);
    const fee_instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        fee_spec_json,
    );
    defer allocator.free(fee_instruction_spec_json);

    const MockSendRpc = struct {
        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = options;
            return "program-send";
        }
    };

    const MockSimRpc = struct {
        fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            build: ?rpc_types.LegacyInstructionsBuildOptions,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = build;
            _ = options;
            return .{ .context = .{ .slot = 34 }, .value = .{ .units_consumed = 45, .fee = 56 } };
        }
    };

    const MockConfirmRpc = struct {
        allocator: Allocator,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = options;
            return try self.allocator.dupe(u8, "program-confirm");
        }
    };

    const MockFeeRpc = struct {
        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            build: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = address_lookup_tables;
            _ = build;
            _ = commitment;
            return .{ .value = 8765 };
        }
    };

    var send_rpc_a = MockSendRpc{};
    var send_result_a = try sendPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        &send_rpc_a,
        send_spec_json,
        .{},
    );
    defer send_result_a.deinit(allocator);
    var send_rpc_b = MockSendRpc{};
    var send_result_b = try invoke.sendPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &send_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer send_result_b.deinit(allocator);

    var sim_rpc_a = MockSimRpc{};
    var sim_result_a = try simulatePreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        &sim_rpc_a,
        send_spec_json,
        .{},
    );
    defer sim_result_a.deinit(allocator);
    var sim_rpc_b = MockSimRpc{};
    var sim_result_b = try invoke.simulatePreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &sim_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer sim_result_b.deinit(allocator);

    var confirm_rpc_a = MockConfirmRpc{ .allocator = allocator };
    var confirm_result_a = try sendAndConfirmPreferredTransactionExecutionResultFromProgramInvokeSpecJson(
        allocator,
        &confirm_rpc_a,
        send_spec_json,
        .{},
    );
    defer confirm_result_a.deinit(allocator);
    var confirm_rpc_b = MockConfirmRpc{ .allocator = allocator };
    var confirm_result_b = try invoke.sendAndConfirmPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &confirm_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer confirm_result_b.deinit(allocator);

    var fee_rpc_a = MockFeeRpc{};
    var fee_result_a = try getFeeForPreferredInvocationExecutionResultFromProgramInvokeSpecJson(
        allocator,
        &fee_rpc_a,
        fee_spec_json,
        .{
            .mode = .{
                .preferred_mode = .versioned,
                .allow_fallback = false,
            },
        },
    );
    defer fee_result_a.deinit(allocator);
    var fee_rpc_b = MockFeeRpc{};
    var fee_result_b = try invoke.getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        &fee_rpc_b,
        .instructions,
        fee_instruction_spec_json,
        .{
            .mode = .{
                .preferred_mode = .versioned,
                .allow_fallback = false,
            },
        },
    );
    defer fee_result_b.deinit(allocator);

    const send_json_a = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &send_result_a);
    defer allocator.free(send_json_a);
    const send_json_b = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &send_result_b);
    defer allocator.free(send_json_b);
    const sim_json_a = try invoke.allocPreferredSimulationExecutionResultJson(allocator, &sim_result_a);
    defer allocator.free(sim_json_a);
    const sim_json_b = try invoke.allocPreferredSimulationExecutionResultJson(allocator, &sim_result_b);
    defer allocator.free(sim_json_b);
    const confirm_json_a = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &confirm_result_a);
    defer allocator.free(confirm_json_a);
    const confirm_json_b = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &confirm_result_b);
    defer allocator.free(confirm_json_b);
    const fee_json_a = try invoke.allocPreferredFeeExecutionResultJson(allocator, &fee_result_a);
    defer allocator.free(fee_json_a);
    const fee_json_b = try invoke.allocPreferredFeeExecutionResultJson(allocator, &fee_result_b);
    defer allocator.free(fee_json_b);

    try std.testing.expectEqualStrings(send_json_b, send_json_a);
    try std.testing.expectEqualStrings(sim_json_b, sim_json_a);
    try std.testing.expectEqualStrings(confirm_json_b, confirm_json_a);
    try std.testing.expectEqualStrings(fee_json_b, fee_json_a);
}

test "program_invoke alloc preferred execution result json helpers match invoke bridge" {
    const allocator = std.testing.allocator;

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{231} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{232} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes(.{233} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes(.{234} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);

    const send_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3]
        \\}}
    ,
        .{ payer_secret_key_base58, program_id_base58 },
    );
    defer allocator.free(send_spec_json);

    const fee_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[4],
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
    defer allocator.free(fee_spec_json);

    const send_instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        send_spec_json,
    );
    defer allocator.free(send_instruction_spec_json);
    const fee_instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        fee_spec_json,
    );
    defer allocator.free(fee_instruction_spec_json);

    const MockSendRpc = struct {
        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = options;
            return "program-send-json";
        }
    };

    const MockSimRpc = struct {
        fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            build: ?rpc_types.LegacyInstructionsBuildOptions,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = build;
            _ = options;
            return .{ .context = .{ .slot = 37 }, .value = .{ .units_consumed = 48, .fee = 59 } };
        }
    };

    const MockConfirmRpc = struct {
        allocator: Allocator,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = options;
            return try self.allocator.dupe(u8, "program-confirm-json");
        }
    };

    const MockFeeRpc = struct {
        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            build: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = address_lookup_tables;
            _ = build;
            _ = commitment;
            return .{ .value = 5432 };
        }
    };

    var send_rpc_a = MockSendRpc{};
    const send_json_a = try allocPreferredSendExecutionResultJsonFromProgramInvokeSpecJson(
        allocator,
        &send_rpc_a,
        send_spec_json,
        .{},
    );
    defer allocator.free(send_json_a);
    var send_rpc_b = MockSendRpc{};
    var send_result_b = try invoke.sendPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &send_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer send_result_b.deinit(allocator);
    const send_json_b = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &send_result_b);
    defer allocator.free(send_json_b);

    var sim_rpc_a = MockSimRpc{};
    const sim_json_a = try allocPreferredSimulationExecutionResultJsonFromProgramInvokeSpecJson(
        allocator,
        &sim_rpc_a,
        send_spec_json,
        .{},
    );
    defer allocator.free(sim_json_a);
    var sim_rpc_b = MockSimRpc{};
    var sim_result_b = try invoke.simulatePreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &sim_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer sim_result_b.deinit(allocator);
    const sim_json_b = try invoke.allocPreferredSimulationExecutionResultJson(allocator, &sim_result_b);
    defer allocator.free(sim_json_b);

    var confirm_rpc_a = MockConfirmRpc{ .allocator = allocator };
    const confirm_json_a = try allocPreferredSendAndConfirmExecutionResultJsonFromProgramInvokeSpecJson(
        allocator,
        &confirm_rpc_a,
        send_spec_json,
        .{},
    );
    defer allocator.free(confirm_json_a);
    var confirm_rpc_b = MockConfirmRpc{ .allocator = allocator };
    var confirm_result_b = try invoke.sendAndConfirmPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &confirm_rpc_b,
        .instructions,
        send_instruction_spec_json,
        .{},
    );
    defer confirm_result_b.deinit(allocator);
    const confirm_json_b = try invoke.allocPreferredSignatureExecutionResultJson(allocator, &confirm_result_b);
    defer allocator.free(confirm_json_b);

    var fee_rpc_a = MockFeeRpc{};
    const fee_json_a = try allocPreferredFeeExecutionResultJsonFromProgramInvokeSpecJson(
        allocator,
        &fee_rpc_a,
        fee_spec_json,
        .{
            .mode = .{
                .preferred_mode = .versioned,
                .allow_fallback = false,
            },
        },
    );
    defer allocator.free(fee_json_a);
    var fee_rpc_b = MockFeeRpc{};
    var fee_result_b = try invoke.getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        &fee_rpc_b,
        .instructions,
        fee_instruction_spec_json,
        .{
            .mode = .{
                .preferred_mode = .versioned,
                .allow_fallback = false,
            },
        },
    );
    defer fee_result_b.deinit(allocator);
    const fee_json_b = try invoke.allocPreferredFeeExecutionResultJson(allocator, &fee_result_b);
    defer allocator.free(fee_json_b);

    try std.testing.expectEqualStrings(send_json_b, send_json_a);
    try std.testing.expectEqualStrings(sim_json_b, sim_json_a);
    try std.testing.expectEqualStrings(confirm_json_b, confirm_json_a);
    try std.testing.expectEqualStrings(fee_json_b, fee_json_a);
}

test "program_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson forwards latest blockhash options and lookup tables" {
    const allocator = std.testing.allocator;

    const MockVersionedSpinnerInvocationClient = struct {
        allocator: Allocator,
        captured_program_id: ?sdk.Pubkey = null,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_blockhash_commitment: ?rpc_types.Commitment = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            address_lookup_tables: []const sdk.AddressLookupTableAccount,
            signers: []const sdk.Keypair,
            options: ?rpc_types.VersionedInstructionsOptions,
        ) ![]const u8 {
            _ = self.allocator;
            _ = payer;
            self.captured_program_id = instructions[0].program_id;
            self.captured_lookup_count = address_lookup_tables.len;
            self.captured_signer_count = signers.len;
            self.captured_blockhash_commitment = options.?.blockhash_commitment.?;
            self.captured_commitment = options.?.commitment.?;
            return "mock-program-invoke-spinner-versioned-signature";
        }
    };

    var mock = MockVersionedSpinnerInvocationClient{ .allocator = allocator };
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{157} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{158} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{159} ** 32);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{160} ** 32);
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

    const signature = try sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(&mock, .{
        .program_invocation_spec_json = spec_json,
        .blockhash_commitment = .processed,
        .commitment = .confirmed,
        .timeout_ms = 123,
    });

    try std.testing.expectEqualStrings("mock-program-invoke-spinner-versioned-signature", signature);
    try std.testing.expect(mock.captured_program_id.?.eql(program_id));
    try std.testing.expectEqual(@as(usize, 1), mock.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), mock.captured_signer_count);
    try std.testing.expectEqual(rpc_types.Commitment.processed, mock.captured_blockhash_commitment.?);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_commitment.?);
}

test "program_invoke.getFeeForLegacyMessageFromInvocationSpecJson forwards nonce query" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn getFeeForLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            options: ?rpc_types.LegacyInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer;
            _ = instructions;
            self.captured_query = options.?.blockhash_query.?;
            self.captured_nonce_authority = options.?.nonce_authority.?;
            self.captured_commitment = commitment;
            return .{ .value = 2468 };
        }
    };

    var mock = MockLegacyInvocationFeeClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{161} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes(.{162} ** 32);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{163} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account = sdk.Pubkey.fromBytes(.{164} ** 32);
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

    const fee = try getFeeForLegacyMessageFromInvocationSpecJson(&mock, .{
        .program_invocation_spec_json = spec_json,
        .blockhash_commitment = .finalized,
    }, .{
        .commitment = .confirmed,
    });

    try std.testing.expectEqual(@as(?u64, 2468), fee.value);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{
            .pubkey = nonce_account_base58,
            .commitment = .finalized,
        } },
        mock.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, mock.captured_nonce_authority.?);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_commitment.?);
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

test "program_invoke alloc inspect export helpers match invoke bridge" {
    const allocator = std.testing.allocator;

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{227} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes(.{228} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{229} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes(.{230} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes(.{231} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{232} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "program_id":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","is_writable":true}}],
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            program_id_base58,
            lookup_address_base58,
            lookup_table_base58,
            lookup_address_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
        allocator,
        spec_json,
    );
    defer allocator.free(instruction_spec_json);

    const report_json = try allocInvocationReportJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(report_json);
    const expected_report_json = try invoke.allocInvocationReportJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_report_json);

    const accounts_json = try allocInvocationAccountsJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(accounts_json);
    const expected_accounts_json = try invoke.allocInvocationAccountsJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_accounts_json);

    const signers_json = try allocInvocationSignerPubkeysJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(signers_json);
    const expected_signers_json = try invoke.allocInvocationSignerPubkeysJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_signers_json);

    const summary_json = try allocInvocationSummaryJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(summary_json);
    const expected_summary_json = try invoke.allocInvocationSummaryJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_summary_json);

    const plan_json = try allocInvocationPlanJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(plan_json);
    const expected_plan_json = try invoke.allocInvocationPlanJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_plan_json);

    const preflight_json = try allocInvocationPreflightJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(preflight_json);
    const expected_preflight_json = try invoke.allocInvocationPreflightJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_preflight_json);

    const validation_json = try allocInvocationValidationJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(validation_json);
    const expected_validation_json = try invoke.allocInvocationValidationJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_validation_json);

    const lookup_coverage_json = try allocInvocationLookupCoverageJsonFromProgramInvokeSpecJson(allocator, spec_json);
    defer allocator.free(lookup_coverage_json);
    const expected_lookup_coverage_json = try invoke.allocInvocationLookupCoverageJsonFromInvocationSpecJson(
        allocator,
        .instructions,
        instruction_spec_json,
    );
    defer allocator.free(expected_lookup_coverage_json);

    try std.testing.expectEqualStrings(expected_report_json, report_json);
    try std.testing.expectEqualStrings(expected_accounts_json, accounts_json);
    try std.testing.expectEqualStrings(expected_signers_json, signers_json);
    try std.testing.expectEqualStrings(expected_summary_json, summary_json);
    try std.testing.expectEqualStrings(expected_plan_json, plan_json);
    try std.testing.expectEqualStrings(expected_preflight_json, preflight_json);
    try std.testing.expectEqualStrings(expected_validation_json, validation_json);
    try std.testing.expectEqualStrings(expected_lookup_coverage_json, lookup_coverage_json);
}
