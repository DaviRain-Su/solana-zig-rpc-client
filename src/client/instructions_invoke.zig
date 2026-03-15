const std = @import("std");
const instruction_schema = @import("./instruction_schema.zig");
const rpc_types = @import("./rpc_types.zig");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const InstructionDataEncoding = enum {
    base64,
    hex,
    utf8,
};

pub const BuildError = Allocator.Error || error{
    InvalidInstructionSpec,
    InvalidInvocationSpec,
    InvalidHexData,
    InvalidBase64Data,
};

pub const BuildLegacyMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions: []const sdk.Instruction,
};

pub const BuildLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
};

pub const BuildVersionedMessageOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
};

pub const BuildVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
};

pub const BuildLegacyMessageFromJsonOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions_json: []const u8,
};

pub const BuildLegacyTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
};

pub const BuildVersionedMessageFromJsonOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
};

pub const BuildVersionedTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    recent_blockhash: sdk.Hash,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
};

pub const BuildLegacyMessageRpcFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildLegacyTransactionRpcFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildVersionedMessageRpcFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const BuildVersionedTransactionRpcFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const SendLegacyTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.SendLegacyInstructionsOptions = null,
};

pub const SimulateLegacyTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.LegacyInstructionsOptions = null,
};

pub const SendVersionedTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.SendVersionedInstructionsOptions = null,
};

pub const SimulateVersionedTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.VersionedInstructionsOptions = null,
};

pub const BuildLegacyMessageWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildLegacyTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedMessageWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const SendLegacyTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithBlockhashQueryFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const BuildLegacyMessageWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildLegacyTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildVersionedMessageWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildVersionedTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const SendLegacyTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithLatestBlockhashFromJsonOptions = struct {
    payer: sdk.Pubkey,
    instructions_json: []const u8,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    address_lookup_tables_json: ?[]const u8 = null,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const TransactionInvocationSpecRpcOptions = struct {
    instruction_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const SendTransactionInvocationSpecRpcOptions = struct {
    instruction_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateTransactionInvocationSpecRpcOptions = struct {
    instruction_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmTransactionInvocationSpecRpcOptions = struct {
    instruction_spec_json: []const u8,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.SendLegacyInstructionsOptions = null,
};

pub const SimulateLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.LegacyInstructionsOptions = null,
};

pub const SendVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.SendVersionedInstructionsOptions = null,
};

pub const SimulateVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
    rpc: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    rpc: ?rpc_types.VersionedInstructionsOptions = null,
};

fn freeInstructionClones(
    allocator: Allocator,
    instructions: []sdk.Instruction,
    initialized_len: usize,
) void {
    for (instructions[0..initialized_len]) |instruction| {
        allocator.free(instruction.accounts);
        allocator.free(instruction.data);
    }
    allocator.free(instructions);
}

const OwnedAddressLookupTables = struct {
    tables: []sdk.AddressLookupTableAccount,

    fn deinit(self: *OwnedAddressLookupTables, allocator: Allocator) void {
        for (self.tables) |table| allocator.free(table.addresses);
        allocator.free(self.tables);
        self.* = undefined;
    }
};

fn jsonObjectField(
    object: *const std.json.ObjectMap,
    comptime names: []const []const u8,
) ?std.json.Value {
    inline for (names) |name| {
        if (object.get(name)) |value| return value;
    }
    return null;
}

fn parseInstructionDataEncoding(value: ?std.json.Value) BuildError!InstructionDataEncoding {
    const raw = switch (value orelse return .base64) {
        .string => |string| string,
        else => return error.InvalidInstructionSpec,
    };

    if (std.mem.eql(u8, raw, "base64")) return .base64;
    if (std.mem.eql(u8, raw, "hex")) return .hex;
    if (std.mem.eql(u8, raw, "utf8")) return .utf8;
    return error.InvalidInstructionSpec;
}

fn parseJsonBool(value: std.json.Value) BuildError!bool {
    return switch (value) {
        .bool => |boolean| boolean,
        else => error.InvalidInstructionSpec,
    };
}

fn parseJsonPubkey(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!sdk.Pubkey {
    return switch (value) {
        .string => |string| sdk.Pubkey.fromBase58(allocator, string) catch return error.InvalidInstructionSpec,
        else => error.InvalidInstructionSpec,
    };
}

fn parseHexData(
    allocator: Allocator,
    encoded: []const u8,
) BuildError![]u8 {
    const trimmed = if (std.mem.startsWith(u8, encoded, "0x") or std.mem.startsWith(u8, encoded, "0X"))
        encoded[2..]
    else
        encoded;
    if (trimmed.len % 2 != 0) return error.InvalidHexData;

    const decoded = try allocator.alloc(u8, trimmed.len / 2);
    errdefer allocator.free(decoded);
    _ = std.fmt.hexToBytes(decoded, trimmed) catch return error.InvalidHexData;
    return decoded;
}

fn parseBase64Data(
    allocator: Allocator,
    encoded: []const u8,
) BuildError![]u8 {
    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(encoded) catch return error.InvalidBase64Data;
    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    decoder.decode(decoded, encoded) catch return error.InvalidBase64Data;
    return decoded;
}

fn parseJsonByteArray(
    allocator: Allocator,
    value: std.json.Value,
) BuildError![]u8 {
    const items = switch (value) {
        .array => |array| array.items,
        else => return error.InvalidInstructionSpec,
    };

    const bytes = try allocator.alloc(u8, items.len);
    errdefer allocator.free(bytes);

    for (items, 0..) |item, index| {
        const integer = switch (item) {
            .integer => |raw| raw,
            else => return error.InvalidInstructionSpec,
        };
        if (integer < 0 or integer > 255) return error.InvalidInstructionSpec;
        bytes[index] = @intCast(integer);
    }

    return bytes;
}

fn parseInstructionDataFromJsonObject(
    allocator: Allocator,
    object: *const std.json.ObjectMap,
) BuildError![]u8 {
    const data_bytes_value = jsonObjectField(object, &.{ "dataBytes", "data_bytes" });
    const encoded_value = jsonObjectField(object, &.{"data"});
    const data_schema_value = jsonObjectField(object, &.{ "dataSchema", "data_schema" });
    const args_value = jsonObjectField(object, &.{"args"});
    const schema_encoding_value = jsonObjectField(object, &.{ "schemaEncoding", "schema_encoding" });

    if (data_bytes_value != null and encoded_value != null) return error.InvalidInstructionSpec;
    if ((data_bytes_value != null or encoded_value != null) and
        (data_schema_value != null or args_value != null))
    {
        return error.InvalidInstructionSpec;
    }
    if ((data_schema_value == null) != (args_value == null)) return error.InvalidInstructionSpec;
    if (data_schema_value == null and schema_encoding_value != null) return error.InvalidInstructionSpec;

    if (data_schema_value) |schema| {
        const schema_encoding = if (schema_encoding_value) |encoding_value|
            switch (encoding_value) {
                .string => instruction_schema.parseSchemaEncoding(encoding_value.string) catch return error.InvalidInstructionSpec,
                else => return error.InvalidInstructionSpec,
            }
        else
            instruction_schema.SchemaEncoding.borsh;
        return instruction_schema.encodeInstructionDataFromSchemaValue(
            allocator,
            schema,
            args_value.?,
            schema_encoding,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidHexData => return error.InvalidHexData,
            error.InvalidBase64Data => return error.InvalidBase64Data,
            error.InvalidInstructionSchema => return error.InvalidInstructionSpec,
        };
    }

    if (data_bytes_value) |value| {
        return try parseJsonByteArray(allocator, value);
    }

    const resolved_encoded_value = encoded_value orelse return allocator.alloc(u8, 0);
    const encoding = try parseInstructionDataEncoding(jsonObjectField(
        object,
        &.{ "dataEncoding", "data_encoding", "encoding" },
    ));

    const encoded = switch (resolved_encoded_value) {
        .string => |string| string,
        else => return error.InvalidInstructionSpec,
    };

    return switch (encoding) {
        .utf8 => try allocator.dupe(u8, encoded),
        .hex => try parseHexData(allocator, encoded),
        .base64 => try parseBase64Data(allocator, encoded),
    };
}

fn parseAccountMetaFromJsonValue(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!sdk.AccountMeta {
    switch (value) {
        .string => |string| {
            const pubkey = sdk.Pubkey.fromBase58(allocator, string) catch return error.InvalidInstructionSpec;
            return sdk.AccountMeta.init(pubkey, false, false);
        },
        .object => |object| {
            const pubkey = try parseJsonPubkey(
                allocator,
                jsonObjectField(&object, &.{ "pubkey", "publicKey", "public_key", "address", "key" }) orelse
                    return error.InvalidInstructionSpec,
            );
            const is_signer = if (jsonObjectField(&object, &.{ "isSigner", "is_signer", "signer" })) |bool_value|
                try parseJsonBool(bool_value)
            else
                false;
            const is_writable = if (jsonObjectField(&object, &.{ "isWritable", "is_writable", "writable" })) |bool_value|
                try parseJsonBool(bool_value)
            else
                false;

            return sdk.AccountMeta.init(pubkey, is_signer, is_writable);
        },
        else => return error.InvalidInstructionSpec,
    }
}

fn appendOrUpgradeInstructionAccountMeta(
    allocator: Allocator,
    accounts: *std.ArrayListUnmanaged(sdk.AccountMeta),
    account: sdk.AccountMeta,
) !void {
    for (accounts.items) |*existing| {
        if (std.meta.eql(existing.pubkey, account.pubkey)) {
            existing.is_signer = existing.is_signer or account.is_signer;
            existing.is_writable = existing.is_writable or account.is_writable;
            return;
        }
    }

    try accounts.append(allocator, account);
}

fn parseInstructionFromJsonValue(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!sdk.Instruction {
    const object = switch (value) {
        .object => |object| object,
        else => return error.InvalidInstructionSpec,
    };

    const program_id = try parseJsonPubkey(
        allocator,
        jsonObjectField(&object, &.{ "programId", "program_id" }) orelse return error.InvalidInstructionSpec,
    );

    const accounts = if (jsonObjectField(&object, &.{"accounts"})) |accounts_value| blk: {
        const account_values = switch (accounts_value) {
            .array => |array| array.items,
            else => return error.InvalidInstructionSpec,
        };
        var parsed_accounts = std.ArrayListUnmanaged(sdk.AccountMeta){};
        errdefer parsed_accounts.deinit(allocator);
        for (account_values) |account_value| {
            try appendOrUpgradeInstructionAccountMeta(
                allocator,
                &parsed_accounts,
                try parseAccountMetaFromJsonValue(allocator, account_value),
            );
        }
        break :blk try parsed_accounts.toOwnedSlice(allocator);
    } else try allocator.alloc(sdk.AccountMeta, 0);
    errdefer allocator.free(accounts);

    const data = try parseInstructionDataFromJsonObject(allocator, &object);
    errdefer allocator.free(data);

    return .{
        .program_id = program_id,
        .accounts = accounts,
        .data = data,
    };
}

fn parseAddressLookupTableFromJsonValue(
    allocator: Allocator,
    value: std.json.Value,
) BuildError!sdk.AddressLookupTableAccount {
    const object = switch (value) {
        .object => |object| object,
        else => return error.InvalidInstructionSpec,
    };

    const account_key = try parseJsonPubkey(
        allocator,
        jsonObjectField(&object, &.{ "accountKey", "account_key", "key", "pubkey", "address" }) orelse
            return error.InvalidInstructionSpec,
    );

    const addresses_value = jsonObjectField(&object, &.{"addresses"}) orelse return error.InvalidInstructionSpec;
    const address_items = switch (addresses_value) {
        .array => |array| array.items,
        else => return error.InvalidInstructionSpec,
    };

    const addresses = try allocator.alloc(sdk.Pubkey, address_items.len);
    errdefer allocator.free(addresses);

    for (address_items, 0..) |address_value, index| {
        addresses[index] = try parseJsonPubkey(allocator, address_value);
    }

    return .{
        .account_key = account_key,
        .addresses = addresses,
    };
}

fn buildOwnedAddressLookupTablesFromJson(
    allocator: Allocator,
    address_lookup_tables_json: []const u8,
) BuildError!OwnedAddressLookupTables {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, address_lookup_tables_json, .{}) catch {
        return error.InvalidInstructionSpec;
    };
    defer parsed.deinit();

    const table_values = switch (parsed.value) {
        .array => |array| array.items,
        .object => |object| blk: {
            _ = object;
            break :blk @as([]const std.json.Value, &.{parsed.value});
        },
        else => return error.InvalidInstructionSpec,
    };

    const tables = try allocator.alloc(sdk.AddressLookupTableAccount, table_values.len);
    var initialized_len: usize = 0;
    errdefer {
        for (tables[0..initialized_len]) |table| allocator.free(table.addresses);
        allocator.free(tables);
    }

    for (table_values, 0..) |table_value, index| {
        tables[index] = try parseAddressLookupTableFromJsonValue(allocator, table_value);
        initialized_len += 1;
    }

    return .{ .tables = tables };
}

fn appendAddressLookupTableAddress(
    allocator: Allocator,
    addresses: *std.ArrayListUnmanaged(sdk.Pubkey),
    address: sdk.Pubkey,
) !void {
    for (addresses.items) |value| {
        if (std.meta.eql(value, address)) return;
    }
    try addresses.append(allocator, address);
}

fn appendOrUpgradeAddressLookupTable(
    allocator: Allocator,
    tables: *std.ArrayListUnmanaged(sdk.AddressLookupTableAccount),
    table: sdk.AddressLookupTableAccount,
) !void {
    for (tables.items) |*existing| {
        if (std.meta.eql(existing.account_key, table.account_key)) {
            var merged_addresses = std.ArrayListUnmanaged(sdk.Pubkey){};
            errdefer merged_addresses.deinit(allocator);
            try merged_addresses.ensureTotalCapacity(allocator, existing.addresses.len + table.addresses.len);
            for (existing.addresses) |address| {
                try appendAddressLookupTableAddress(allocator, &merged_addresses, address);
            }
            for (table.addresses) |address| {
                try appendAddressLookupTableAddress(allocator, &merged_addresses, address);
            }

            allocator.free(existing.addresses);
            existing.addresses = try merged_addresses.toOwnedSlice(allocator);
            return;
        }
    }

    try tables.append(allocator, .{
        .account_key = table.account_key,
        .addresses = try allocator.dupe(sdk.Pubkey, table.addresses),
    });
}

fn cloneAddressLookupTables(
    allocator: Allocator,
    address_lookup_tables: []const sdk.AddressLookupTableAccount,
) BuildError!OwnedAddressLookupTables {
    const tables = try allocator.alloc(sdk.AddressLookupTableAccount, address_lookup_tables.len);
    var initialized_len: usize = 0;
    errdefer {
        for (tables[0..initialized_len]) |table| allocator.free(table.addresses);
        allocator.free(tables);
    }

    for (address_lookup_tables, 0..) |table, index| {
        tables[index] = .{
            .account_key = table.account_key,
            .addresses = try allocator.dupe(sdk.Pubkey, table.addresses),
        };
        initialized_len += 1;
    }

    return .{ .tables = tables };
}

fn buildMergedAddressLookupTables(
    allocator: Allocator,
    address_lookup_tables: []const sdk.AddressLookupTableAccount,
    address_lookup_tables_json: ?[]const u8,
) BuildError!OwnedAddressLookupTables {
    var parsed_tables: ?OwnedAddressLookupTables = null;
    defer if (parsed_tables) |*tables| tables.deinit(allocator);

    if (address_lookup_tables_json) |value| {
        parsed_tables = try buildOwnedAddressLookupTablesFromJson(allocator, value);
    }

    var merged = std.ArrayListUnmanaged(sdk.AddressLookupTableAccount){};
    errdefer {
        for (merged.items) |table| allocator.free(table.addresses);
        merged.deinit(allocator);
    }

    if (parsed_tables) |tables| {
        for (tables.tables) |table| {
            try appendOrUpgradeAddressLookupTable(allocator, &merged, table);
        }
    }
    for (address_lookup_tables) |table| {
        try appendOrUpgradeAddressLookupTable(allocator, &merged, table);
    }

    return .{ .tables = try merged.toOwnedSlice(allocator) };
}

pub fn buildOwnedInstructionsFromJson(
    allocator: Allocator,
    instructions_json: []const u8,
) BuildError!sdk.OwnedInstructions {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, instructions_json, .{}) catch {
        return error.InvalidInstructionSpec;
    };
    defer parsed.deinit();

    const instruction_values = switch (parsed.value) {
        .array => |array| array.items,
        .object => |object| blk: {
            _ = object;
            break :blk @as([]const std.json.Value, &.{parsed.value});
        },
        else => return error.InvalidInstructionSpec,
    };

    const instructions = try allocator.alloc(sdk.Instruction, instruction_values.len);
    var initialized_len: usize = 0;
    errdefer freeInstructionClones(allocator, instructions, initialized_len);

    for (instruction_values, 0..) |instruction_value, index| {
        instructions[index] = try parseInstructionFromJsonValue(allocator, instruction_value);
        initialized_len += 1;
    }

    return .{ .instructions = instructions };
}

pub const OwnedInvocationSpec = struct {
    payer: sdk.Pubkey,
    signers: []sdk.Keypair,
    owned_instructions: sdk.OwnedInstructions,
    address_lookup_tables: []sdk.AddressLookupTableAccount,
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,

    pub fn deinit(self: *OwnedInvocationSpec, allocator: Allocator) void {
        allocator.free(self.signers);
        self.owned_instructions.deinit(allocator);
        for (self.address_lookup_tables) |table| allocator.free(table.addresses);
        allocator.free(self.address_lookup_tables);
        self.* = undefined;
    }
};

fn stringifyJsonValue(
    allocator: Allocator,
    value: std.json.Value,
) Allocator.Error![]u8 {
    var json_buffer: std.io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();
    std.json.Stringify.value(value, .{}, &json_buffer.writer) catch unreachable;
    return try allocator.dupe(u8, json_buffer.written());
}

fn appendUniqueSignerFromPubkey(
    allocator: Allocator,
    signers: *std.ArrayListUnmanaged(sdk.Keypair),
    signer: sdk.Keypair,
) !void {
    for (signers.items) |existing| {
        if (std.meta.eql(existing.public_key, signer.public_key)) return;
    }
    try signers.append(allocator, signer);
}

pub fn buildOwnedInvocationSpecFromJson(
    allocator: Allocator,
    instruction_spec_json: []const u8,
) BuildError!OwnedInvocationSpec {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, instruction_spec_json, .{}) catch {
        return error.InvalidInvocationSpec;
    };
    defer parsed.deinit();

    const object = switch (parsed.value) {
        .object => |value| value,
        else => return error.InvalidInvocationSpec,
    };

    const payer_secret_key_value = jsonObjectField(&object, &.{ "payer_secret_key", "payerSecretKey" }) orelse
        return error.InvalidInvocationSpec;
    if (payer_secret_key_value != .string) return error.InvalidInvocationSpec;
    const payer_keypair = sdk.Keypair.fromBase58SecretKey(allocator, payer_secret_key_value.string) catch {
        return error.InvalidInvocationSpec;
    };

    const recent_blockhash = if (jsonObjectField(&object, &.{ "recent_blockhash", "recentBlockhash" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk sdk.Hash.fromBase58(allocator, value.string) catch return error.InvalidInvocationSpec;
    } else null;
    const nonce_account = if (jsonObjectField(&object, &.{ "nonce_account", "nonceAccount" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk sdk.Pubkey.fromBase58(allocator, value.string) catch return error.InvalidInvocationSpec;
    } else null;
    if (recent_blockhash != null and nonce_account != null) return error.InvalidInvocationSpec;

    const nonce_authority_keypair = if (jsonObjectField(&object, &.{ "nonce_authority_secret_key", "nonceAuthoritySecretKey" })) |value| blk: {
        if (value != .string) return error.InvalidInvocationSpec;
        break :blk sdk.Keypair.fromBase58SecretKey(allocator, value.string) catch return error.InvalidInvocationSpec;
    } else null;
    if (nonce_account == null and nonce_authority_keypair != null) return error.InvalidInvocationSpec;

    const instructions_value = jsonObjectField(&object, &.{"instructions"}) orelse return error.InvalidInvocationSpec;
    const instructions_json = try stringifyJsonValue(allocator, instructions_value);
    defer allocator.free(instructions_json);

    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, instructions_json);
    errdefer owned_instructions.deinit(allocator);

    const address_lookup_tables_json = if (jsonObjectField(&object, &.{ "address_lookup_tables", "addressLookupTables" })) |value|
        try stringifyJsonValue(allocator, value)
    else
        null;
    defer if (address_lookup_tables_json) |value| allocator.free(value);

    var owned_lookup_tables = try buildMergedAddressLookupTables(allocator, &.{}, address_lookup_tables_json);
    errdefer owned_lookup_tables.deinit(allocator);

    const additional_signers_value = jsonObjectField(&object, &.{ "additional_signer_secret_keys", "additionalSignerSecretKeys" });
    if (additional_signers_value) |value| {
        if (value != .array) return error.InvalidInvocationSpec;
    }

    var signers = std.ArrayListUnmanaged(sdk.Keypair){};
    defer signers.deinit(allocator);
    try appendUniqueSignerFromPubkey(allocator, &signers, payer_keypair);
    if (additional_signers_value) |value| {
        for (value.array.items) |secret_key_value| {
            if (secret_key_value != .string) return error.InvalidInvocationSpec;
            const signer = sdk.Keypair.fromBase58SecretKey(allocator, secret_key_value.string) catch {
                return error.InvalidInvocationSpec;
            };
            try appendUniqueSignerFromPubkey(allocator, &signers, signer);
        }
    }
    if (nonce_authority_keypair) |value| {
        try appendUniqueSignerFromPubkey(allocator, &signers, value);
    }
    const signer_slice = try signers.toOwnedSlice(allocator);

    return .{
        .payer = payer_keypair.public_key,
        .signers = signer_slice,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .recent_blockhash = recent_blockhash,
        .nonce_account = nonce_account,
        .nonce_authority = if (nonce_account != null)
            if (nonce_authority_keypair) |value| value.public_key else payer_keypair.public_key
        else
            null,
    };
}

pub const BuildLegacyMessageRpcOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildLegacyTransactionRpcOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    build: ?rpc_types.LegacyInstructionsBuildOptions = null,
};

pub const BuildVersionedMessageRpcOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const BuildVersionedTransactionRpcOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    build: ?rpc_types.VersionedInstructionsBuildOptions = null,
};

pub const GetFeeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
};

pub const BuildLegacyMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedMessageWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BuildVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const SendLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithBlockhashQueryOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_query: rpc_types.BlockhashQuery,
    nonce_authority: ?sdk.Pubkey = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const BuildLegacyMessageWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildVersionedMessageWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const BuildVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
};

pub const SendLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmLegacyTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const SendVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
};

pub const SimulateVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    simulate_options: ?rpc_types.SimulateTransactionOptions = null,
};

pub const SendAndConfirmVersionedTransactionWithLatestBlockhashOptions = struct {
    payer: sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    signers: []const sdk.Keypair,
    blockhash_commitment: ?rpc_types.Commitment = null,
    send_transaction_options: ?rpc_types.SendTransactionOptions = null,
    commitment: ?rpc_types.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub fn buildOwnedLegacyMessage(
    allocator: Allocator,
    options: BuildLegacyMessageOptions,
) !sdk.OwnedLegacyMessage {
    return try sdk.buildOwnedLegacyMessage(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
    );
}

pub fn buildLegacyMessageBytes(
    allocator: Allocator,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    return try sdk.buildLegacyMessageBytes(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
    );
}

pub fn buildLegacyMessageBase64(
    allocator: Allocator,
    options: BuildLegacyMessageOptions,
) ![]u8 {
    return try sdk.buildLegacyMessageBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
    );
}

pub fn buildSignedLegacyTransaction(
    allocator: Allocator,
    options: BuildLegacyTransactionOptions,
) !sdk.SignedLegacyTransaction {
    return try sdk.buildSignedLegacyTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.signers,
    );
}

pub fn buildLegacyTransactionBase64(
    allocator: Allocator,
    options: BuildLegacyTransactionOptions,
) ![]u8 {
    return try sdk.buildLegacyTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.signers,
    );
}

pub fn buildOwnedVersionedMessage(
    allocator: Allocator,
    options: BuildVersionedMessageOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try sdk.buildOwnedVersionedMessage(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.address_lookup_tables,
    );
}

pub fn buildVersionedMessageBytes(
    allocator: Allocator,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    return try sdk.buildVersionedMessageBytes(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.address_lookup_tables,
    );
}

pub fn buildVersionedMessageBase64(
    allocator: Allocator,
    options: BuildVersionedMessageOptions,
) ![]u8 {
    return try sdk.buildVersionedMessageBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.address_lookup_tables,
    );
}

pub fn buildSignedVersionedTransaction(
    allocator: Allocator,
    options: BuildVersionedTransactionOptions,
) !sdk.SignedVersionedTransaction {
    return try sdk.buildSignedVersionedTransaction(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
    );
}

pub fn buildVersionedTransactionBase64(
    allocator: Allocator,
    options: BuildVersionedTransactionOptions,
) ![]u8 {
    return try sdk.buildVersionedTransactionBase64(
        allocator,
        options.payer,
        options.recent_blockhash,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
    );
}

pub fn buildOwnedLegacyMessageFromJson(
    allocator: Allocator,
    options: BuildLegacyMessageFromJsonOptions,
) BuildError!sdk.OwnedLegacyMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);

    return try buildOwnedLegacyMessage(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
    });
}

pub fn buildLegacyMessageBytesFromJson(
    allocator: Allocator,
    options: BuildLegacyMessageFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);

    return try buildLegacyMessageBytes(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
    });
}

pub fn buildLegacyMessageBase64FromJson(
    allocator: Allocator,
    options: BuildLegacyMessageFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);

    return try buildLegacyMessageBase64(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
    });
}

pub fn buildSignedLegacyTransactionFromJson(
    allocator: Allocator,
    options: BuildLegacyTransactionFromJsonOptions,
) BuildError!sdk.SignedLegacyTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);

    return try buildSignedLegacyTransaction(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
    });
}

pub fn buildLegacyTransactionBase64FromJson(
    allocator: Allocator,
    options: BuildLegacyTransactionFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);

    return try buildLegacyTransactionBase64(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
    });
}

pub fn buildOwnedVersionedMessageFromJson(
    allocator: Allocator,
    options: BuildVersionedMessageFromJsonOptions,
) BuildError!sdk.OwnedVersionedMessageV0 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(allocator);

    return try buildOwnedVersionedMessage(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
    });
}

pub fn buildVersionedMessageBytesFromJson(
    allocator: Allocator,
    options: BuildVersionedMessageFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(allocator);

    return try buildVersionedMessageBytes(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
    });
}

pub fn buildVersionedMessageBase64FromJson(
    allocator: Allocator,
    options: BuildVersionedMessageFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(allocator);

    return try buildVersionedMessageBase64(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
    });
}

pub fn buildSignedVersionedTransactionFromJson(
    allocator: Allocator,
    options: BuildVersionedTransactionFromJsonOptions,
) BuildError!sdk.SignedVersionedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(allocator);

    return try buildSignedVersionedTransaction(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
    });
}

pub fn buildVersionedTransactionBase64FromJson(
    allocator: Allocator,
    options: BuildVersionedTransactionFromJsonOptions,
) BuildError![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(allocator, options.instructions_json);
    defer owned_instructions.deinit(allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(allocator);

    return try buildVersionedTransactionBase64(allocator, .{
        .payer = options.payer,
        .recent_blockhash = options.recent_blockhash,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
    });
}

pub fn buildOwnedLegacyMessageWithOptionsFromJson(
    self: anytype,
    options: BuildLegacyMessageRpcFromJsonOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildOwnedLegacyMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .build = options.build,
    });
}

pub fn buildLegacyMessageBytesWithOptionsFromJson(
    self: anytype,
    options: BuildLegacyMessageRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .build = options.build,
    });
}

pub fn buildLegacyMessageBase64WithOptionsFromJson(
    self: anytype,
    options: BuildLegacyMessageRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .build = options.build,
    });
}

pub fn buildSignedLegacyTransactionWithOptionsFromJson(
    self: anytype,
    options: BuildLegacyTransactionRpcFromJsonOptions,
) !sdk.SignedLegacyTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildSignedLegacyTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .build = options.build,
    });
}

pub fn buildLegacyTransactionBase64WithOptionsFromJson(
    self: anytype,
    options: BuildLegacyTransactionRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .build = options.build,
    });
}

pub fn buildOwnedVersionedMessageWithOptionsFromJson(
    self: anytype,
    options: BuildVersionedMessageRpcFromJsonOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildOwnedVersionedMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .build = options.build,
    });
}

pub fn buildVersionedMessageBytesWithOptionsFromJson(
    self: anytype,
    options: BuildVersionedMessageRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .build = options.build,
    });
}

pub fn buildVersionedMessageBase64WithOptionsFromJson(
    self: anytype,
    options: BuildVersionedMessageRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .build = options.build,
    });
}

pub fn buildSignedVersionedTransactionWithOptionsFromJson(
    self: anytype,
    options: BuildVersionedTransactionRpcFromJsonOptions,
) !sdk.SignedVersionedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildSignedVersionedTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .build = options.build,
    });
}

pub fn buildVersionedTransactionBase64WithOptionsFromJson(
    self: anytype,
    options: BuildVersionedTransactionRpcFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .build = options.build,
    });
}

pub fn sendLegacyTransactionFromJson(
    self: anytype,
    options: SendLegacyTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn simulateLegacyTransactionFromJson(
    self: anytype,
    options: SimulateLegacyTransactionFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try simulateLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .build = options.build,
        .rpc = options.rpc,
    });
}

pub fn sendAndConfirmLegacyTransactionFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn sendVersionedTransactionFromJson(
    self: anytype,
    options: SendVersionedTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn simulateVersionedTransactionFromJson(
    self: anytype,
    options: SimulateVersionedTransactionFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try simulateVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .build = options.build,
        .rpc = options.rpc,
    });
}

pub fn sendAndConfirmVersionedTransactionFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .rpc = options.rpc,
    });
}

pub fn getFeeForLegacyMessageWithOptionsFromJson(
    self: anytype,
    message_options: BuildLegacyMessageRpcFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, message_options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try getFeeForLegacyMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = owned_instructions.instructions,
        .build = message_options.build,
    }, fee_options);
}

pub fn getFeeForVersionedMessageWithOptionsFromJson(
    self: anytype,
    message_options: BuildVersionedMessageRpcFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, message_options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        message_options.address_lookup_tables,
        message_options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try getFeeForVersionedMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .build = message_options.build,
    }, fee_options);
}

pub fn buildOwnedLegacyMessageWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryFromJsonOptions,
) !sdk.OwnedLegacyMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildOwnedLegacyMessageWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildLegacyMessageBytesWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyMessageBytesWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildLegacyMessageBase64WithBlockhashQueryFromJson(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyMessageBase64WithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildSignedLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildLegacyTransactionWithBlockhashQueryFromJsonOptions,
) !sdk.SignedLegacyTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildSignedLegacyTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildLegacyTransactionBase64WithBlockhashQueryFromJson(
    self: anytype,
    options: BuildLegacyTransactionWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try buildLegacyTransactionBase64WithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn sendLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SendLegacyTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendLegacyTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SimulateLegacyTransactionWithBlockhashQueryFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try simulateLegacyTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForLegacyMessageWithBlockhashQueryFromJson(
    self: anytype,
    message_options: BuildLegacyMessageWithBlockhashQueryFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, message_options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try getFeeForLegacyMessageWithBlockhashQuery(self, .{
        .payer = message_options.payer,
        .instructions = owned_instructions.instructions,
        .blockhash_query = message_options.blockhash_query,
        .nonce_authority = message_options.nonce_authority,
    }, fee_options);
}

pub fn buildOwnedVersionedMessageWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryFromJsonOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildOwnedVersionedMessageWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildVersionedMessageBytesWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedMessageBytesWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildVersionedMessageBase64WithBlockhashQueryFromJson(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedMessageBase64WithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildSignedVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: BuildVersionedTransactionWithBlockhashQueryFromJsonOptions,
) !sdk.SignedVersionedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildSignedVersionedTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn buildVersionedTransactionBase64WithBlockhashQueryFromJson(
    self: anytype,
    options: BuildVersionedTransactionWithBlockhashQueryFromJsonOptions,
) ![]u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try buildVersionedTransactionBase64WithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
    });
}

pub fn sendVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SendVersionedTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendVersionedTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SimulateVersionedTransactionWithBlockhashQueryFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try simulateVersionedTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransactionWithBlockhashQuery(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_query = options.blockhash_query,
        .nonce_authority = options.nonce_authority,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForVersionedMessageWithBlockhashQueryFromJson(
    self: anytype,
    message_options: BuildVersionedMessageWithBlockhashQueryFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, message_options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        message_options.address_lookup_tables,
        message_options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try getFeeForVersionedMessageWithBlockhashQuery(self, .{
        .payer = message_options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .blockhash_query = message_options.blockhash_query,
        .nonce_authority = message_options.nonce_authority,
    }, fee_options);
}

pub fn buildOwnedLegacyMessageWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashFromJsonOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyMessageBytesWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyMessageBase64WithLatestBlockhashFromJson(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildSignedLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildLegacyTransactionWithLatestBlockhashFromJsonOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyTransactionBase64WithLatestBlockhashFromJson(
    self: anytype,
    options: BuildLegacyTransactionWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn sendLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SendLegacyTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendLegacyTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SimulateLegacyTransactionWithLatestBlockhashFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try simulateLegacyTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);

    return try sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForLegacyMessageWithLatestBlockhashFromJson(
    self: anytype,
    message_options: BuildLegacyMessageWithLatestBlockhashFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithOptionsFromJson(self, .{
        .payer = message_options.payer,
        .instructions_json = message_options.instructions_json,
        .build = .{ .blockhash_commitment = message_options.blockhash_commitment },
    }, fee_options);
}

pub fn buildOwnedVersionedMessageWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashFromJsonOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .address_lookup_tables = options.address_lookup_tables,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedMessageBytesWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .address_lookup_tables = options.address_lookup_tables,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedMessageBase64WithLatestBlockhashFromJson(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .address_lookup_tables = options.address_lookup_tables,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildSignedVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: BuildVersionedTransactionWithLatestBlockhashFromJsonOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .address_lookup_tables = options.address_lookup_tables,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedTransactionBase64WithLatestBlockhashFromJson(
    self: anytype,
    options: BuildVersionedTransactionWithLatestBlockhashFromJsonOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithOptionsFromJson(self, .{
        .payer = options.payer,
        .instructions_json = options.instructions_json,
        .address_lookup_tables = options.address_lookup_tables,
        .address_lookup_tables_json = options.address_lookup_tables_json,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn sendVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SendVersionedTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendVersionedTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn simulateVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SimulateVersionedTransactionWithLatestBlockhashFromJsonOptions,
) !rpc_types.SimulatedTransaction {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try simulateVersionedTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransactionWithLatestBlockhash(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinnerFromJson(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashFromJsonOptions,
) ![]const u8 {
    var owned_instructions = try buildOwnedInstructionsFromJson(self.allocator, options.instructions_json);
    defer owned_instructions.deinit(self.allocator);
    var owned_lookup_tables = try buildMergedAddressLookupTables(
        self.allocator,
        options.address_lookup_tables,
        options.address_lookup_tables_json,
    );
    defer owned_lookup_tables.deinit(self.allocator);

    return try sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(self, .{
        .payer = options.payer,
        .instructions = owned_instructions.instructions,
        .address_lookup_tables = owned_lookup_tables.tables,
        .signers = options.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn getFeeForVersionedMessageWithLatestBlockhashFromJson(
    self: anytype,
    message_options: BuildVersionedMessageWithLatestBlockhashFromJsonOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithOptionsFromJson(self, .{
        .payer = message_options.payer,
        .instructions_json = message_options.instructions_json,
        .address_lookup_tables = message_options.address_lookup_tables,
        .address_lookup_tables_json = message_options.address_lookup_tables_json,
        .build = .{ .blockhash_commitment = message_options.blockhash_commitment },
    }, fee_options);
}

pub fn sendLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendLegacyTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendLegacyTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
        });
    }
    return try sendLegacyTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) !sdk.OwnedLegacyMessage {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildOwnedLegacyMessage(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildOwnedLegacyMessageWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildOwnedLegacyMessageWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBytesFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildLegacyMessageBytes(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildLegacyMessageBytesWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildLegacyMessageBytesWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyMessageBase64FromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildLegacyMessageBase64(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildLegacyMessageBase64WithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildLegacyMessageBase64WithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) !sdk.SignedLegacyTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildSignedLegacyTransaction(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildSignedLegacyTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildSignedLegacyTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildLegacyTransactionBase64(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildLegacyTransactionBase64WithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildLegacyTransactionBase64WithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendAndConfirmLegacyTransactionWithSpinner(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinner(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        });
    }
    return try sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
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
    options: TransactionInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try getFeeForLegacyMessageWithOptions(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .build = .{ .recent_blockhash = recent_blockhash_base58 },
        }, fee_options);
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try getFeeForLegacyMessageWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        }, fee_options);
    }
    return try getFeeForLegacyMessageWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .blockhash_commitment = options.blockhash_commitment,
    }, fee_options);
}

pub fn simulateLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SimulateTransactionInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try simulateLegacyTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .build = .{ .recent_blockhash = recent_blockhash_base58 },
            .rpc = options.simulate_options,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try simulateLegacyTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .simulate_options = options.simulate_options,
        });
    }
    return try simulateLegacyTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendAndConfirmLegacyTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendAndConfirmLegacyTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        });
    }
    return try sendAndConfirmLegacyTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .signers = owned_spec.signers,
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
    options: SendTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendVersionedTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendVersionedTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
        });
    }
    return try sendVersionedTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
    });
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildOwnedVersionedMessage(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildOwnedVersionedMessageWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildOwnedVersionedMessageWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBytesFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildVersionedMessageBytes(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildVersionedMessageBytesWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildVersionedMessageBytesWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedMessageBase64FromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildVersionedMessageBase64(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildVersionedMessageBase64WithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildVersionedMessageBase64WithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) !sdk.SignedVersionedTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildSignedVersionedTransaction(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildSignedVersionedTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildSignedVersionedTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJson(
    self: anytype,
    options: TransactionInvocationSpecRpcOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        return try buildVersionedTransactionBase64(self.allocator, .{
            .payer = owned_spec.payer,
            .recent_blockhash = value,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try buildVersionedTransactionBase64WithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        });
    }
    return try buildVersionedTransactionBase64WithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
    });
}

pub fn sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendAndConfirmVersionedTransactionWithSpinner(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinner(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        });
    }
    return try sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
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
    options: TransactionInvocationSpecRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try getFeeForVersionedMessageWithOptions(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .build = .{ .recent_blockhash = recent_blockhash_base58 },
        }, fee_options);
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try getFeeForVersionedMessageWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
        }, fee_options);
    }
    return try getFeeForVersionedMessageWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .blockhash_commitment = options.blockhash_commitment,
    }, fee_options);
}

pub fn simulateVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: SimulateTransactionInvocationSpecRpcOptions,
) !rpc_types.SimulatedTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try simulateVersionedTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .build = .{ .recent_blockhash = recent_blockhash_base58 },
            .rpc = options.simulate_options,
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try simulateVersionedTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .simulate_options = options.simulate_options,
        });
    }
    return try simulateVersionedTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .simulate_options = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionFromInvocationSpecJson(
    self: anytype,
    options: SendAndConfirmTransactionInvocationSpecRpcOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromJson(self.allocator, options.instruction_spec_json);
    defer owned_spec.deinit(self.allocator);

    if (owned_spec.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(recent_blockhash_base58);
        return try sendAndConfirmVersionedTransaction(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .rpc = .{
                .recent_blockhash = recent_blockhash_base58,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            },
        });
    }
    if (owned_spec.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(self.allocator);
        defer self.allocator.free(nonce_account_base58);
        return try sendAndConfirmVersionedTransactionWithBlockhashQuery(self, .{
            .payer = owned_spec.payer,
            .instructions = owned_spec.owned_instructions.instructions,
            .address_lookup_tables = owned_spec.address_lookup_tables,
            .signers = owned_spec.signers,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = owned_spec.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        });
    }
    return try sendAndConfirmVersionedTransactionWithLatestBlockhash(self, .{
        .payer = owned_spec.payer,
        .instructions = owned_spec.owned_instructions.instructions,
        .address_lookup_tables = owned_spec.address_lookup_tables,
        .signers = owned_spec.signers,
        .blockhash_commitment = options.blockhash_commitment,
        .send_transaction_options = options.send_transaction_options,
        .commitment = options.commitment,
        .search_transaction_history = options.search_transaction_history,
        .timeout_ms = options.timeout_ms,
        .poll_interval_ms = options.poll_interval_ms,
    });
}

pub fn sendLegacyTransaction(
    self: anytype,
    options: SendLegacyTransactionOptions,
) ![]const u8 {
    return try self.sendLegacyInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.rpc,
    );
}

pub fn simulateLegacyTransaction(
    self: anytype,
    options: SimulateLegacyTransactionOptions,
) !rpc_types.SimulatedTransaction {
    return try self.simulateLegacyInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.build,
        options.rpc,
    );
}

pub fn sendAndConfirmLegacyTransaction(
    self: anytype,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.rpc,
    );
}

pub fn sendVersionedTransaction(
    self: anytype,
    options: SendVersionedTransactionOptions,
) ![]const u8 {
    return try self.sendVersionedInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn simulateVersionedTransaction(
    self: anytype,
    options: SimulateVersionedTransactionOptions,
) !rpc_types.SimulatedTransaction {
    return try self.simulateVersionedInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.build,
        options.rpc,
    );
}

pub fn sendAndConfirmVersionedTransaction(
    self: anytype,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmVersionedInstructionsWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn buildOwnedLegacyMessageWithOptions(
    self: anytype,
    options: BuildLegacyMessageRpcOptions,
) !sdk.OwnedLegacyMessage {
    return try self.buildOwnedLegacyMessageWithOptions(
        options.payer,
        options.instructions,
        options.build,
    );
}

pub fn buildLegacyMessageBytesWithOptions(
    self: anytype,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    return try self.buildLegacyMessageBytesWithOptions(
        options.payer,
        options.instructions,
        options.build,
    );
}

pub fn buildLegacyMessageBase64WithOptions(
    self: anytype,
    options: BuildLegacyMessageRpcOptions,
) ![]u8 {
    return try self.buildLegacyMessageBase64WithOptions(
        options.payer,
        options.instructions,
        options.build,
    );
}

pub fn buildSignedLegacyTransactionWithOptions(
    self: anytype,
    options: BuildLegacyTransactionRpcOptions,
) !sdk.SignedLegacyTransaction {
    return try self.buildSignedLegacyTransactionWithOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.build,
    );
}

pub fn buildLegacyTransactionBase64WithOptions(
    self: anytype,
    options: BuildLegacyTransactionRpcOptions,
) ![]u8 {
    return try self.buildLegacyTransactionBase64WithOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.build,
    );
}

pub fn buildOwnedVersionedMessageWithOptions(
    self: anytype,
    options: BuildVersionedMessageRpcOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try self.buildOwnedVersionedMessageWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.build,
    );
}

pub fn buildVersionedMessageBytesWithOptions(
    self: anytype,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    return try self.buildVersionedMessageBytesWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.build,
    );
}

pub fn buildVersionedMessageBase64WithOptions(
    self: anytype,
    options: BuildVersionedMessageRpcOptions,
) ![]u8 {
    return try self.buildVersionedMessageBase64WithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.build,
    );
}

pub fn buildSignedVersionedTransactionWithOptions(
    self: anytype,
    options: BuildVersionedTransactionRpcOptions,
) !sdk.SignedVersionedTransaction {
    return try self.buildSignedVersionedTransactionWithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.build,
    );
}

pub fn buildVersionedTransactionBase64WithOptions(
    self: anytype,
    options: BuildVersionedTransactionRpcOptions,
) ![]u8 {
    return try self.buildVersionedTransactionBase64WithOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.build,
    );
}

pub fn sendAndConfirmLegacyTransactionWithSpinner(
    self: anytype,
    options: SendAndConfirmLegacyTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        options.payer,
        options.instructions,
        options.signers,
        options.rpc,
    );
}

pub fn sendAndConfirmVersionedTransactionWithSpinner(
    self: anytype,
    options: SendAndConfirmVersionedTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
        options.payer,
        options.instructions,
        options.address_lookup_tables,
        options.signers,
        options.rpc,
    );
}

pub fn getFeeForLegacyMessageWithOptions(
    self: anytype,
    message_options: BuildLegacyMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try self.getFeeForLegacyInstructionsWithOptions(
        message_options.payer,
        message_options.instructions,
        message_options.build,
        fee_options.commitment,
    );
}

pub fn getFeeForVersionedMessageWithOptions(
    self: anytype,
    message_options: BuildVersionedMessageRpcOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try self.getFeeForVersionedInstructionsWithOptions(
        message_options.payer,
        message_options.instructions,
        message_options.address_lookup_tables,
        message_options.build,
        fee_options.commitment,
    );
}

pub fn buildOwnedLegacyMessageWithBlockhashQuery(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildLegacyMessageBytesWithBlockhashQuery(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildLegacyMessageBase64WithBlockhashQuery(
    self: anytype,
    options: BuildLegacyMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildSignedLegacyTransactionWithBlockhashQuery(
    self: anytype,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildLegacyTransactionBase64WithBlockhashQuery(
    self: anytype,
    options: BuildLegacyTransactionWithBlockhashQueryOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn sendLegacyTransactionWithBlockhashQuery(
    self: anytype,
    options: SendLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
        },
    });
}

pub fn simulateLegacyTransactionWithBlockhashQuery(
    self: anytype,
    options: SimulateLegacyTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
        .rpc = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQuery(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn sendAndConfirmLegacyTransactionWithBlockhashQueryAndSpinner(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn buildOwnedVersionedMessageWithBlockhashQuery(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildVersionedMessageBytesWithBlockhashQuery(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildVersionedMessageBase64WithBlockhashQuery(
    self: anytype,
    options: BuildVersionedMessageWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildSignedVersionedTransactionWithBlockhashQuery(
    self: anytype,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn buildVersionedTransactionBase64WithBlockhashQuery(
    self: anytype,
    options: BuildVersionedTransactionWithBlockhashQueryOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
    });
}

pub fn sendVersionedTransactionWithBlockhashQuery(
    self: anytype,
    options: SendVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
        },
    });
}

pub fn simulateVersionedTransactionWithBlockhashQuery(
    self: anytype,
    options: SimulateVersionedTransactionWithBlockhashQueryOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
        },
        .rpc = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQuery(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinner(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithBlockhashQueryOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_query = options.blockhash_query,
            .nonce_authority = options.nonce_authority,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn getFeeForLegacyMessageWithBlockhashQuery(
    self: anytype,
    message_options: BuildLegacyMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = message_options.instructions,
        .build = .{
            .blockhash_query = message_options.blockhash_query,
            .nonce_authority = message_options.nonce_authority,
        },
    }, fee_options);
}

pub fn getFeeForVersionedMessageWithBlockhashQuery(
    self: anytype,
    message_options: BuildVersionedMessageWithBlockhashQueryOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = message_options.instructions,
        .address_lookup_tables = message_options.address_lookup_tables,
        .build = .{
            .blockhash_query = message_options.blockhash_query,
            .nonce_authority = message_options.nonce_authority,
        },
    }, fee_options);
}

pub fn buildOwnedLegacyMessageWithLatestBlockhash(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) !sdk.OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyMessageBytesWithLatestBlockhash(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyMessageBase64WithLatestBlockhash(
    self: anytype,
    options: BuildLegacyMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildSignedLegacyTransactionWithLatestBlockhash(
    self: anytype,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) !sdk.SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildLegacyTransactionBase64WithLatestBlockhash(
    self: anytype,
    options: BuildLegacyTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildLegacyTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn sendLegacyTransactionWithLatestBlockhash(
    self: anytype,
    options: SendLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
        },
    });
}

pub fn simulateLegacyTransactionWithLatestBlockhash(
    self: anytype,
    options: SimulateLegacyTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
        .rpc = options.simulate_options,
    });
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhash(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinner(
    self: anytype,
    options: SendAndConfirmLegacyTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmLegacyTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn buildOwnedVersionedMessageWithLatestBlockhash(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) !sdk.OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedMessageBytesWithLatestBlockhash(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBytesWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedMessageBase64WithLatestBlockhash(
    self: anytype,
    options: BuildVersionedMessageWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedMessageBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildSignedVersionedTransactionWithLatestBlockhash(
    self: anytype,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) !sdk.SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn buildVersionedTransactionBase64WithLatestBlockhash(
    self: anytype,
    options: BuildVersionedTransactionWithLatestBlockhashOptions,
) ![]u8 {
    return try buildVersionedTransactionBase64WithOptions(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
    });
}

pub fn sendVersionedTransactionWithLatestBlockhash(
    self: anytype,
    options: SendVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
        },
    });
}

pub fn simulateVersionedTransactionWithLatestBlockhash(
    self: anytype,
    options: SimulateVersionedTransactionWithLatestBlockhashOptions,
) !rpc_types.SimulatedTransaction {
    return try simulateVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .build = .{ .blockhash_commitment = options.blockhash_commitment },
        .rpc = options.simulate_options,
    });
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhash(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransaction(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinner(
    self: anytype,
    options: SendAndConfirmVersionedTransactionWithLatestBlockhashOptions,
) ![]const u8 {
    return try sendAndConfirmVersionedTransactionWithSpinner(self, .{
        .payer = options.payer,
        .instructions = options.instructions,
        .address_lookup_tables = options.address_lookup_tables,
        .signers = options.signers,
        .rpc = .{
            .blockhash_commitment = options.blockhash_commitment,
            .send_transaction_options = options.send_transaction_options,
            .commitment = options.commitment,
            .search_transaction_history = options.search_transaction_history,
            .timeout_ms = options.timeout_ms,
            .poll_interval_ms = options.poll_interval_ms,
        },
    });
}

pub fn getFeeForLegacyMessageWithLatestBlockhash(
    self: anytype,
    message_options: BuildLegacyMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForLegacyMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = message_options.instructions,
        .build = .{ .blockhash_commitment = message_options.blockhash_commitment },
    }, fee_options);
}

pub fn getFeeForVersionedMessageWithLatestBlockhash(
    self: anytype,
    message_options: BuildVersionedMessageWithLatestBlockhashOptions,
    fee_options: GetFeeOptions,
) !rpc_types.FeeForMessage {
    return try getFeeForVersionedMessageWithOptions(self, .{
        .payer = message_options.payer,
        .instructions = message_options.instructions,
        .address_lookup_tables = message_options.address_lookup_tables,
        .build = .{ .blockhash_commitment = message_options.blockhash_commitment },
    }, fee_options);
}

test "instructions_invoke.buildOwnedLegacyMessage clones generic instruction sets" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{1} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{2} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{3} ** 32);
    const signer = sdk.Pubkey.fromBytes([_]u8{4} ** 32);
    const account = sdk.Pubkey.fromBytes([_]u8{5} ** 32);
    const instruction_data = [_]u8{ 0xaa, 0xbb, 0xcc };
    const instruction_accounts = [_]sdk.AccountMeta{
        sdk.AccountMeta.init(signer, true, true),
        sdk.AccountMeta.init(account, false, false),
    };
    const instructions = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = instruction_accounts[0..],
            .data = instruction_data[0..],
        },
    };

    var owned = try buildOwnedLegacyMessage(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions[0..],
    });
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned.owned_instructions.len);
    try std.testing.expect(owned.message.instructions.ptr == owned.owned_instructions.ptr);
    try std.testing.expect(owned.owned_instructions[0].accounts.ptr != instruction_accounts[0..].ptr);
    try std.testing.expect(owned.owned_instructions[0].data.ptr != instruction_data[0..].ptr);
    try std.testing.expectEqualSlices(sdk.AccountMeta, instruction_accounts[0..], owned.owned_instructions[0].accounts);
    try std.testing.expectEqualSlices(u8, instruction_data[0..], owned.owned_instructions[0].data);
}

test "instructions_invoke.buildOwnedInstructionsFromJson parses flexible instruction json" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{23} ** 32);
    const readonly_account = sdk.Pubkey.fromBytes([_]u8{24} ** 32);
    const signer_account = sdk.Pubkey.fromBytes([_]u8{25} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const readonly_base58 = try readonly_account.toBase58(allocator);
    defer allocator.free(readonly_base58);
    const signer_base58 = try signer_account.toBase58(allocator);
    defer allocator.free(signer_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[
        \\  {{
        \\    "programId": "{s}",
        \\    "accounts": [
        \\      "{s}",
        \\      {{"address":"{s}","isSigner":true,"writable":true}}
        \\    ],
        \\    "data": "6869",
        \\    "dataEncoding": "hex"
        \\  }},
        \\  {{
        \\    "program_id": "{s}",
        \\    "data_bytes": [1,2,3]
        \\  }}
        \\]
    ,
        .{ program_id_base58, readonly_base58, signer_base58, program_id_base58 },
    );
    defer allocator.free(instructions_json);

    var owned = try buildOwnedInstructionsFromJson(allocator, instructions_json);
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instructions.len);
    try std.testing.expectEqual(program_id, owned.instructions[0].program_id);
    try std.testing.expectEqual(@as(usize, 2), owned.instructions[0].accounts.len);
    try std.testing.expectEqual(readonly_account, owned.instructions[0].accounts[0].pubkey);
    try std.testing.expect(!owned.instructions[0].accounts[0].is_signer);
    try std.testing.expect(!owned.instructions[0].accounts[0].is_writable);
    try std.testing.expectEqual(signer_account, owned.instructions[0].accounts[1].pubkey);
    try std.testing.expect(owned.instructions[0].accounts[1].is_signer);
    try std.testing.expect(owned.instructions[0].accounts[1].is_writable);
    try std.testing.expectEqualSlices(u8, "hi", owned.instructions[0].data);
    try std.testing.expectEqual(@as(usize, 0), owned.instructions[1].accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, owned.instructions[1].data);
}

test "instructions_invoke.buildOwnedInstructionsFromJson deduplicates duplicate account metas" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{28} ** 32);
    const account = sdk.Pubkey.fromBytes([_]u8{29} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const account_base58 = try account.toBase58(allocator);
    defer allocator.free(account_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[
        \\  {{
        \\    "programId": "{s}",
        \\    "accounts": [
        \\      "{s}",
        \\      {{"address":"{s}","signer":true,"writable":false}}
        \\    ],
        \\    "dataBytes":[1,2]
        \\  }}
        \\]
    ,
        .{ program_id_base58, account_base58, account_base58 },
    );
    defer allocator.free(instructions_json);

    var owned = try buildOwnedInstructionsFromJson(allocator, instructions_json);
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned.instructions.len);
    try std.testing.expectEqual(@as(usize, 1), owned.instructions[0].accounts.len);
    try std.testing.expectEqual(account, owned.instructions[0].accounts[0].pubkey);
    try std.testing.expect(owned.instructions[0].accounts[0].is_signer);
    try std.testing.expect(!owned.instructions[0].accounts[0].is_writable);
}

test "instructions_invoke.buildOwnedInstructionsFromJson encodes schema-driven instruction data" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{31} ** 32);
    const authority = sdk.Pubkey.fromBytes([_]u8{32} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[
        \\  {{
        \\    "programId":"{s}",
        \\    "dataSchema":{{"type":"struct","fields":[{{"name":"authority","type":"pubkey"}},{{"name":"payload","type":"bytes"}},{{"name":"memo","type":"string"}}]}},
        \\    "args":{{"authority":"{s}","payload":"base64:AQID","memo":"hi"}},
        \\    "schemaEncoding":"borsh"
        \\  }}
        \\]
    ,
        .{ program_id_base58, authority_base58 },
    );
    defer allocator.free(instructions_json);

    var owned = try buildOwnedInstructionsFromJson(allocator, instructions_json);
    defer owned.deinit(allocator);

    const expected = [_]u8{
        authority.bytes[0],  authority.bytes[1],  authority.bytes[2],  authority.bytes[3],  authority.bytes[4],  authority.bytes[5],  authority.bytes[6],  authority.bytes[7],
        authority.bytes[8],  authority.bytes[9],  authority.bytes[10], authority.bytes[11], authority.bytes[12], authority.bytes[13], authority.bytes[14], authority.bytes[15],
        authority.bytes[16], authority.bytes[17], authority.bytes[18], authority.bytes[19], authority.bytes[20], authority.bytes[21], authority.bytes[22], authority.bytes[23],
        authority.bytes[24], authority.bytes[25], authority.bytes[26], authority.bytes[27], authority.bytes[28], authority.bytes[29], authority.bytes[30], authority.bytes[31],
        3,                   0,                   0,                   0,                   1,                   2,                   3,                   2,
        0,                   0,                   0,                   'h',                 'i',
    };

    try std.testing.expectEqual(@as(usize, 1), owned.instructions.len);
    try std.testing.expectEqual(program_id, owned.instructions[0].program_id);
    try std.testing.expectEqual(@as(usize, 0), owned.instructions[0].accounts.len);
    try std.testing.expectEqualSlices(u8, &expected, owned.instructions[0].data);
}

test "instructions_invoke.buildLegacyTransactionBase64FromJson matches typed helper" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{26} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{27} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{28} ** 32);
    const signer_secret_key = [_]u8{29} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const payer_base58 = try payer.toBase58(allocator);
    defer allocator.free(payer_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "programId":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","signer":true,"writable":true}}],
        \\  "data":"hello",
        \\  "dataEncoding":"utf8"
        \\}}
    ,
        .{ program_id_base58, payer_base58 },
    );
    defer allocator.free(instructions_json);

    const encoded = try buildLegacyTransactionBase64FromJson(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions_json = instructions_json,
        .signers = &.{signer},
    });
    defer allocator.free(encoded);

    const expected_instruction = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = &.{sdk.AccountMeta.init(payer, true, true)},
            .data = "hello",
        },
    };
    const expected = try buildLegacyTransactionBase64(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = expected_instruction[0..],
        .signers = &.{signer},
    });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "instructions_invoke.buildVersionedMessageBytesFromJson matches typed helper" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{30} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{31} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{32} ** 32);
    const payer_base58 = try payer.toBase58(allocator);
    defer allocator.free(payer_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "program_id":"{s}",
        \\  "accounts":[{{"publicKey":"{s}","isSigner":true,"isWritable":false}}],
        \\  "data":"AQID",
        \\  "dataEncoding":"base64"
        \\}}]
    ,
        .{ program_id_base58, payer_base58 },
    );
    defer allocator.free(instructions_json);

    const encoded = try buildVersionedMessageBytesFromJson(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions_json = instructions_json,
    });
    defer allocator.free(encoded);

    const expected_instruction = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = &.{sdk.AccountMeta.init(payer, true, false)},
            .data = &.{ 1, 2, 3 },
        },
    };
    const expected = try buildVersionedMessageBytes(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = expected_instruction[0..],
    });
    defer allocator.free(expected);

    try std.testing.expectEqualSlices(u8, expected, encoded);
}

test "instructions_invoke.buildOwnedInvocationSpecFromJson parses signers and lookup tables" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{67} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{68} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{69} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{70} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{71} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes([_]u8{72} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{73} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{74} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_secret_key = extra_raw.secret_key.toBytes();
    const extra_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_secret_key);
    defer allocator.free(extra_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payerSecretKey":"{s}",
        \\  "additionalSignerSecretKeys":["{s}"],
        \\  "addressLookupTables":[{{"accountKey":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"programId":"{s}","data":"AQID","dataEncoding":"base64"}}],
        \\  "recentBlockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    var owned = try buildOwnedInvocationSpecFromJson(allocator, spec_json);
    defer owned.deinit(allocator);

    try std.testing.expectEqual(payer_raw.public_key, owned.payer);
    try std.testing.expectEqual(@as(usize, 2), owned.signers.len);
    try std.testing.expectEqual(extra_raw.public_key, owned.signers[1].public_key);
    try std.testing.expectEqual(@as(usize, 1), owned.owned_instructions.instructions.len);
    try std.testing.expectEqual(@as(usize, 1), owned.address_lookup_tables.len);
    try std.testing.expectEqual(lookup_table_key, owned.address_lookup_tables[0].account_key);
    try std.testing.expectEqual(lookup_table_address, owned.address_lookup_tables[0].addresses[0]);
    try std.testing.expectEqual(recent_blockhash.?, owned.recent_blockhash.?);
    try std.testing.expectEqual(@as(?sdk.Pubkey, null), owned.nonce_account);

    const nonce_account_base58_2 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58_2);
    const nonce_authority_secret_key_base58_2 = try nonce_authority_secret_key.toBase58(allocator);
    defer allocator.free(nonce_authority_secret_key_base58_2);

    const nonce_spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58_2,
            nonce_authority_secret_key_base58_2,
            program_id_base58,
        },
    );
    defer allocator.free(nonce_spec_json);

    var nonce_owned = try buildOwnedInvocationSpecFromJson(allocator, nonce_spec_json);
    defer nonce_owned.deinit(allocator);

    try std.testing.expectEqual(nonce_account, nonce_owned.nonce_account.?);
    try std.testing.expectEqual(nonce_authority_raw.public_key, nonce_owned.nonce_authority.?);
    try std.testing.expectEqual(@as(usize, 2), nonce_owned.signers.len);
}

test "instructions_invoke.buildOwnedInvocationSpecFromJson deduplicates signer keys by pubkey" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{76} ** 32);
    const duplicate_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{77} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{78} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{79} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const duplicate_secret_key = duplicate_raw.secret_key.toBytes();
    const duplicate_secret_key_base58 = try sdk.encodeBase58(allocator, &duplicate_secret_key);
    defer allocator.free(duplicate_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additionalSignerSecretKeys":["{s}","{s}","{s}","{s}"],
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            duplicate_secret_key_base58,
            payer_secret_key_base58,
            duplicate_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    var owned = try buildOwnedInvocationSpecFromJson(allocator, spec_json);
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.signers.len);
    try std.testing.expectEqual(payer_raw.public_key, owned.signers[0].public_key);
    try std.testing.expectEqual(duplicate_raw.public_key, owned.signers[1].public_key);
}

test "instructions_invoke.buildOwnedVersionedMessageFromJson uses address_lookup_tables_json" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{56} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{57} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{58} ** 32);
    const looked_up_account = sdk.Pubkey.fromBytes([_]u8{59} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{60} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const looked_up_account_base58 = try looked_up_account.toBase58(allocator);
    defer allocator.free(looked_up_account_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "programId":"{s}",
        \\  "accounts":["{s}"],
        \\  "dataBytes":[1]
        \\}}]
    ,
        .{ program_id_base58, looked_up_account_base58 },
    );
    defer allocator.free(instructions_json);

    const address_lookup_tables_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "accountKey":"{s}",
        \\  "addresses":["{s}"]
        \\}}]
    ,
        .{ lookup_table_key_base58, looked_up_account_base58 },
    );
    defer allocator.free(address_lookup_tables_json);

    var owned = try buildOwnedVersionedMessageFromJson(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions_json = instructions_json,
        .address_lookup_tables_json = address_lookup_tables_json,
    });
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned.message.address_table_lookups.len);
    try std.testing.expectEqual(lookup_table_key, owned.message.address_table_lookups[0].account_key);
    try std.testing.expectEqual(@as(usize, 0), owned.message.address_table_lookups[0].writable_indexes.len);
    try std.testing.expectEqual(@as(usize, 1), owned.message.address_table_lookups[0].readonly_indexes.len);
    try std.testing.expectEqual(@as(u8, 0), owned.message.address_table_lookups[0].readonly_indexes[0]);
}

test "instructions_invoke.buildMergedAddressLookupTables deduplicates duplicate lookup tables and addresses" {
    const allocator = std.testing.allocator;
    const table_key = sdk.Pubkey.fromBytes([_]u8{100} ** 32);
    const address_one = sdk.Pubkey.fromBytes([_]u8{101} ** 32);
    const address_two = sdk.Pubkey.fromBytes([_]u8{102} ** 32);
    const address_three = sdk.Pubkey.fromBytes([_]u8{103} ** 32);

    const table_key_base58 = try table_key.toBase58(allocator);
    defer allocator.free(table_key_base58);
    const address_one_base58 = try address_one.toBase58(allocator);
    defer allocator.free(address_one_base58);
    const address_two_base58 = try address_two.toBase58(allocator);
    defer allocator.free(address_two_base58);
    const address_three_base58 = try address_three.toBase58(allocator);
    defer allocator.free(address_three_base58);

    const base_addresses = try allocator.dupe(sdk.Pubkey, &.{ address_one, address_two });
    defer allocator.free(base_addresses);
    const base_tables = [_]sdk.AddressLookupTableAccount{
        .{
            .account_key = table_key,
            .addresses = base_addresses,
        },
    };

    const address_lookup_tables_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "accountKey":"{s}",
        \\  "addresses":["{s}","{s}","{s}"]
        \\}}]
    ,
        .{ table_key_base58, address_two_base58, address_three_base58, address_one_base58 },
    );
    defer allocator.free(address_lookup_tables_json);

    var merged = try buildMergedAddressLookupTables(allocator, base_tables[0..], address_lookup_tables_json);
    defer merged.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), merged.tables.len);
    try std.testing.expectEqual(@as(usize, 3), merged.tables[0].addresses.len);
    try std.testing.expect(merged.tables[0].account_key.eql(table_key));
    try std.testing.expect(merged.tables[0].addresses[0].eql(address_one));
    try std.testing.expect(merged.tables[0].addresses[1].eql(address_two));
    try std.testing.expect(merged.tables[0].addresses[2].eql(address_three));
}

test "instructions_invoke.buildLegacyMessageBase64WithOptionsFromJson forwards parsed instructions and build options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{33} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{34} ** 32);
    const account = sdk.Pubkey.fromBytes([_]u8{35} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const account_base58 = try account.toBase58(allocator);
    defer allocator.free(account_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "programId":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","isSigner":false,"isWritable":true}}],
        \\  "data":"6869",
        \\  "dataEncoding":"hex"
        \\}}]
    ,
        .{ program_id_base58, account_base58 },
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_program_id: ?sdk.Pubkey = null,
        captured_build_options: ?rpc_types.LegacyInstructionsBuildOptions = null,

        fn buildLegacyMessageBase64WithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            options_arg: ?rpc_types.LegacyInstructionsBuildOptions,
        ) ![]u8 {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_program_id = instructions_arg[0].program_id;
            self.captured_build_options = options_arg;
            return try self.allocator.dupe(u8, "legacy-json-base64");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const encoded = try buildLegacyMessageBase64WithOptionsFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .build = .{ .blockhash_commitment = .confirmed },
    });
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("legacy-json-base64", encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(program_id, rpc.captured_program_id.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_build_options.?.blockhash_commitment.?);
}

test "instructions_invoke.sendLegacyTransactionFromJson forwards parsed instructions and rpc options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{36} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{37} ** 32);
    const signer_secret_key = [_]u8{38} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","data":"hello","dataEncoding":"utf8"}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_options: ?rpc_types.SendLegacyInstructionsOptions = null,

        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_signer_count = signers_arg.len;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-json-legacy");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendLegacyTransactionFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .signers = &.{signer},
        .rpc = .{ .send_transaction_options = .{ .skip_preflight = true } },
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-json-legacy", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
    try std.testing.expect(rpc.captured_options.?.send_transaction_options.?.skip_preflight);
}

test "instructions_invoke.sendLegacyTransactionFromInvocationSpecJson forwards recent blockhash and signers" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{75} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{76} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{77} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{78} ** 32);

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
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","accounts":[{{"pubkey":"{s}","is_signer":true}}],"data":"hi","data_encoding":"utf8"}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            payer_secret_key_base58,
        },
    );
    defer allocator.free(spec_json);

    const payer_pubkey_base58 = try payer_raw.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);
    const fixed_spec_json = try std.mem.replaceOwned(u8, allocator, spec_json, payer_secret_key_base58, payer_pubkey_base58);
    defer allocator.free(fixed_spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_instruction_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_recent_blockhash: ?sdk.Hash = null,

        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            self.captured_payer = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_signer_count = signers_arg.len;
            self.captured_recent_blockhash = options_arg.?.recent_blockhash.?;
            return try self.allocator.dupe(u8, "sig-spec-legacy");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendLegacyTransactionFromInvocationSpecJson(&rpc, .{
        .instruction_spec_json = fixed_spec_json,
        .send_transaction_options = .{ .skip_preflight = true },
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spec-legacy", signature);
    try std.testing.expectEqual(payer_raw.public_key, rpc.captured_payer.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 2), rpc.captured_signer_count);
    try std.testing.expectEqual(recent_blockhash, rpc.captured_recent_blockhash.?);
}

test "instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson uses nonce query" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{79} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{80} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{81} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{82} ** 32);

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
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[9]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_signer_count: usize = 0,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_sig_verify: bool = false,

        fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            build_arg: ?rpc_types.LegacyInstructionsBuildOptions,
            options_arg: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_signer_count = signers_arg.len;
            self.captured_query = build_arg.?.blockhash_query.?;
            self.captured_nonce_authority = build_arg.?.nonce_authority.?;
            self.captured_sig_verify = options_arg.?.sig_verify;
            return .{ .context = .{ .slot = 1 }, .value = .{} };
        }
    };

    var rpc = MockRpc{};
    _ = try simulateLegacyTransactionFromInvocationSpecJson(&rpc, .{
        .instruction_spec_json = spec_json,
        .blockhash_commitment = .confirmed,
        .simulate_options = .{ .sig_verify = true },
    });

    try std.testing.expectEqual(@as(usize, 2), rpc.captured_signer_count);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .confirmed } },
        rpc.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, rpc.captured_nonce_authority.?);
    try std.testing.expect(rpc.captured_sig_verify);
}

test "instructions_invoke.sendVersionedTransactionFromInvocationSpecJson forwards latest blockhash and lookup tables" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{83} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{84} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{85} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes([_]u8{86} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","data":"AQ==","data_encoding":"base64"}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_blockhash_commitment: ?rpc_types.Commitment = null,

        fn sendVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendVersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_signer_count = signers_arg.len;
            self.captured_blockhash_commitment = options_arg.?.blockhash_commitment.?;
            return try self.allocator.dupe(u8, "sig-spec-versioned");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendVersionedTransactionFromInvocationSpecJson(&rpc, .{
        .instruction_spec_json = spec_json,
        .blockhash_commitment = .processed,
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spec-versioned", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
    try std.testing.expectEqual(.processed, rpc.captured_blockhash_commitment.?);
}

test "instructions_invoke.buildLegacyTransactionBase64FromInvocationSpecJson builds recent blockhash transaction" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{87} ** 32);
    const extra_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{88} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{89} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{90} ** 32);

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
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_data = [_]u8{ 1, 2, 3 };
    const instructions = [_]sdk.Instruction{.{
        .program_id = program_id,
        .accounts = &.{},
        .data = instruction_data[0..],
    }};
    const signers = [_]sdk.Keypair{ payer_raw, extra_raw };

    const expected = try buildLegacyTransactionBase64(allocator, .{
        .payer = payer_raw.public_key,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions[0..],
        .signers = signers[0..],
    });
    defer allocator.free(expected);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const actual = try buildLegacyTransactionBase64FromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson builds recent blockhash transaction" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{91} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{92} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{93} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{94} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes([_]u8{95} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[4,5,6]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const instruction_data = [_]u8{ 4, 5, 6 };
    const lookup_addresses = [_]sdk.Pubkey{lookup_table_address};
    const instructions = [_]sdk.Instruction{.{
        .program_id = program_id,
        .accounts = &.{},
        .data = instruction_data[0..],
    }};
    const lookup_tables = [_]sdk.AddressLookupTableAccount{.{
        .account_key = lookup_table_key,
        .addresses = lookup_addresses[0..],
    }};
    const signers = [_]sdk.Keypair{payer_raw};

    const expected = try buildVersionedTransactionBase64(allocator, .{
        .payer = payer_raw.public_key,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions[0..],
        .address_lookup_tables = lookup_tables[0..],
        .signers = signers[0..],
    });
    defer allocator.free(expected);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const actual = try buildVersionedTransactionBase64FromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "instructions_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson uses nonce query" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{96} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{97} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{98} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{99} ** 32);

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
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[7]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,
        captured_timeout_ms: u64 = 0,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_signer_count = signers_arg.len;
            self.captured_query = options_arg.?.blockhash_query.?;
            self.captured_nonce_authority = options_arg.?.nonce_authority.?;
            self.captured_commitment = options_arg.?.commitment.?;
            self.captured_timeout_ms = options_arg.?.timeout_ms;
            return try self.allocator.dupe(u8, "sig-spec-legacy-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(&rpc, .{
        .instruction_spec_json = spec_json,
        .blockhash_commitment = .confirmed,
        .commitment = .finalized,
        .timeout_ms = 777,
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spec-legacy-spinner", signature);
    try std.testing.expectEqual(@as(usize, 2), rpc.captured_signer_count);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .confirmed } },
        rpc.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, rpc.captured_nonce_authority.?);
    try std.testing.expectEqual(.finalized, rpc.captured_commitment.?);
    try std.testing.expectEqual(@as(u64, 777), rpc.captured_timeout_ms);
}

test "instructions_invoke.getFeeForVersionedMessageFromInvocationSpecJson forwards latest blockhash and lookup tables" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{100} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{101} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{102} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes([_]u8{103} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[8,9]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_lookup_count: usize = 0,
        captured_build_options: ?rpc_types.VersionedInstructionsBuildOptions = null,
        captured_commitment: ?rpc_types.Commitment = null,

        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            options_arg: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment_arg: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_build_options = options_arg;
            self.captured_commitment = commitment_arg;
            return .{ .value = 4321 };
        }
    };

    var rpc = MockRpc{};
    const fee = try getFeeForVersionedMessageFromInvocationSpecJson(&rpc, .{
        .instruction_spec_json = spec_json,
        .blockhash_commitment = .processed,
    }, .{
        .commitment = .finalized,
    });

    try std.testing.expectEqual(@as(u64, 4321), fee.value.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_lookup_count);
    try std.testing.expectEqual(.processed, rpc.captured_build_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.finalized, rpc.captured_commitment.?);
}

test "instructions_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromJson forwards parsed instructions and options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{39} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{40} ** 32);
    const signer_secret_key = [_]u8{41} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","data":"AQID","dataEncoding":"base64"}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_options: ?rpc_types.VersionedInstructionsOptions = null,

        fn sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.VersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_signer_count = signers_arg.len;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-json-versioned-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmVersionedTransactionWithSpinnerFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .signers = &.{signer},
        .rpc = .{
            .blockhash_commitment = .processed,
            .commitment = .finalized,
            .timeout_ms = 456,
        },
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-json-versioned-spinner", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
    try std.testing.expectEqual(.processed, rpc.captured_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.finalized, rpc.captured_options.?.commitment.?);
    try std.testing.expectEqual(@as(u64, 456), rpc.captured_options.?.timeout_ms);
}

test "instructions_invoke.getFeeForVersionedMessageWithOptionsFromJson forwards parsed instructions and fee options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{42} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{43} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","dataBytes":[9,8,7]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        captured_instruction_count: usize = 0,
        captured_lookup_count: usize = 0,
        captured_program_id: ?sdk.Pubkey = null,
        captured_build_options: ?rpc_types.VersionedInstructionsBuildOptions = null,
        captured_commitment: ?rpc_types.Commitment = null,

        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            options_arg: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment_arg: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_program_id = instructions_arg[0].program_id;
            self.captured_build_options = options_arg;
            self.captured_commitment = commitment_arg;
            return .{ .value = 999 };
        }
    };

    var rpc = MockRpc{};
    const fee = try getFeeForVersionedMessageWithOptionsFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .build = .{ .blockhash_commitment = .confirmed },
    }, .{
        .commitment = .finalized,
    });

    try std.testing.expectEqual(@as(u64, 999), fee.value.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_lookup_count);
    try std.testing.expectEqual(program_id, rpc.captured_program_id.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_build_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.finalized, rpc.captured_commitment.?);
}

test "instructions_invoke.buildLegacyMessageBytesWithBlockhashQueryFromJson forwards parsed instructions and query" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{44} ** 32);
    const authority = sdk.Pubkey.fromBytes([_]u8{45} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{46} ** 32);
    const blockhash_query = rpc_types.BlockhashQuery{
        .fixed = .{ .blockhash = "FixedBlockhash2222222222222222222222222222222222222" },
    };

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","data":"AQI=","dataEncoding":"base64"}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_build_options: ?rpc_types.LegacyInstructionsBuildOptions = null,

        fn buildLegacyMessageBytesWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            options_arg: ?rpc_types.LegacyInstructionsBuildOptions,
        ) ![]u8 {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_build_options = options_arg;
            return try self.allocator.dupe(u8, "legacy-query-bytes");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const encoded = try buildLegacyMessageBytesWithBlockhashQueryFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .blockhash_query = blockhash_query,
        .nonce_authority = authority,
    });
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("legacy-query-bytes", encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqualDeep(blockhash_query, rpc.captured_build_options.?.blockhash_query.?);
    try std.testing.expectEqual(authority, rpc.captured_build_options.?.nonce_authority.?);
}

test "instructions_invoke.sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson forwards parsed instructions and query options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{47} ** 32);
    const authority = sdk.Pubkey.fromBytes([_]u8{48} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{49} ** 32);
    const signer_secret_key = [_]u8{50} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);
    const blockhash_query = rpc_types.BlockhashQuery{
        .fixed = .{ .blockhash = "FixedBlockhash3333333333333333333333333333333333333" },
    };

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const json_lookup_key = sdk.Pubkey.fromBytes([_]u8{61} ** 32);
    const json_lookup_address = sdk.Pubkey.fromBytes([_]u8{62} ** 32);
    const typed_lookup_key = sdk.Pubkey.fromBytes([_]u8{63} ** 32);
    const typed_lookup_address = sdk.Pubkey.fromBytes([_]u8{64} ** 32);
    const json_lookup_key_base58 = try json_lookup_key.toBase58(allocator);
    defer allocator.free(json_lookup_key_base58);
    const json_lookup_address_base58 = try json_lookup_address.toBase58(allocator);
    defer allocator.free(json_lookup_address_base58);
    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","dataBytes":[7,6,5]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);
    const address_lookup_tables_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "accountKey":"{s}",
        \\  "addresses":["{s}"]
        \\}}]
    ,
        .{ json_lookup_key_base58, json_lookup_address_base58 },
    );
    defer allocator.free(address_lookup_tables_json);
    const typed_lookup_addresses = [_]sdk.Pubkey{typed_lookup_address};
    const typed_lookup_tables = [_]sdk.AddressLookupTableAccount{
        .{
            .account_key = typed_lookup_key,
            .addresses = typed_lookup_addresses[0..],
        },
    };

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_lookup_count: usize = 0,
        captured_options: ?rpc_types.VersionedInstructionsOptions = null,

        fn sendAndConfirmVersionedInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.VersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = signers_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-query-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .address_lookup_tables = typed_lookup_tables[0..],
        .address_lookup_tables_json = address_lookup_tables_json,
        .signers = &.{signer},
        .blockhash_query = blockhash_query,
        .nonce_authority = authority,
        .commitment = .confirmed,
        .timeout_ms = 321,
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-query-spinner", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 2), rpc.captured_lookup_count);
    try std.testing.expectEqualDeep(blockhash_query, rpc.captured_options.?.blockhash_query.?);
    try std.testing.expectEqual(authority, rpc.captured_options.?.nonce_authority.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_options.?.commitment.?);
    try std.testing.expectEqual(@as(u64, 321), rpc.captured_options.?.timeout_ms);
}

test "instructions_invoke.sendLegacyTransactionWithLatestBlockhashFromJson forwards parsed instructions and latest blockhash options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{51} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{52} ** 32);
    const signer_secret_key = [_]u8{53} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","data":"hello","dataEncoding":"utf8"}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_options: ?rpc_types.SendLegacyInstructionsOptions = null,

        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = signers_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-latest-legacy");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendLegacyTransactionWithLatestBlockhashFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .signers = &.{signer},
        .blockhash_commitment = .processed,
        .send_transaction_options = .{ .skip_preflight = true },
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-latest-legacy", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(.processed, rpc.captured_options.?.blockhash_commitment.?);
    try std.testing.expect(rpc.captured_options.?.send_transaction_options.?.skip_preflight);
}

test "instructions_invoke.getFeeForVersionedMessageWithLatestBlockhashFromJson forwards parsed instructions and fee options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{54} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{55} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes([_]u8{65} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes([_]u8{66} ** 32);

    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);
    const instructions_json = try std.fmt.allocPrint(
        allocator,
        \\{{"programId":"{s}","dataBytes":[1,4,9]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(instructions_json);
    const address_lookup_tables_json = try std.fmt.allocPrint(
        allocator,
        \\[{{
        \\  "accountKey":"{s}",
        \\  "addresses":["{s}"]
        \\}}]
    ,
        .{ lookup_table_key_base58, lookup_table_address_base58 },
    );
    defer allocator.free(address_lookup_tables_json);

    const MockRpc = struct {
        captured_instruction_count: usize = 0,
        captured_lookup_count: usize = 0,
        captured_build_options: ?rpc_types.VersionedInstructionsBuildOptions = null,
        captured_commitment: ?rpc_types.Commitment = null,

        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            options_arg: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment_arg: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_build_options = options_arg;
            self.captured_commitment = commitment_arg;
            return .{ .value = 4242 };
        }
    };

    var rpc = MockRpc{};
    const fee = try getFeeForVersionedMessageWithLatestBlockhashFromJson(&rpc, .{
        .payer = payer,
        .instructions_json = instructions_json,
        .address_lookup_tables_json = address_lookup_tables_json,
        .blockhash_commitment = .finalized,
    }, .{
        .commitment = .confirmed,
    });

    try std.testing.expectEqual(@as(u64, 4242), fee.value.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_lookup_count);
    try std.testing.expectEqual(.finalized, rpc.captured_build_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_commitment.?);
}

test "instructions_invoke.buildVersionedTransactionBase64 matches sdk helper" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{6} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes([_]u8{7} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{8} ** 32);
    const instruction_data = [_]u8{ 0x11, 0x22 };
    const instructions = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = &.{sdk.AccountMeta.init(payer, true, true)},
            .data = instruction_data[0..],
        },
    };
    const signer_secret_key = [_]u8{9} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const encoded = try buildVersionedTransactionBase64(allocator, .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions[0..],
        .signers = &.{signer},
    });
    defer allocator.free(encoded);

    const expected = try sdk.buildVersionedTransactionBase64(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
        &.{},
        &.{signer},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "instructions_invoke.sendLegacyTransaction delegates to rpc client" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{10} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{11} ** 32);
    const signer_secret_key = [_]u8{12} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);
    const instruction_data = [_]u8{0x33};
    const instructions = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = &.{sdk.AccountMeta.init(payer, true, true)},
            .data = instruction_data[0..],
        },
    };

    const MockRpc = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_instruction_count: usize = 0,
        captured_signer_count: usize = 0,

        fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = options_arg;
            self.captured_payer = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_signer_count = signers_arg.len;
            return try self.allocator.dupe(u8, "sig-legacy");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendLegacyTransaction(&rpc, .{
        .payer = payer,
        .instructions = instructions[0..],
        .signers = &.{signer},
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-legacy", signature);
    try std.testing.expectEqual(payer, rpc.captured_payer.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
}

test "instructions_invoke.sendAndConfirmVersionedTransaction delegates to rpc client" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{13} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{14} ** 32);
    const signer_secret_key = [_]u8{15} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);
    const instruction_data = [_]u8{0x44};
    const instructions = [_]sdk.Instruction{
        .{
            .program_id = program_id,
            .accounts = &.{sdk.AccountMeta.init(payer, true, true)},
            .data = instruction_data[0..],
        },
    };

    const MockRpc = struct {
        allocator: Allocator,
        captured_instruction_count: usize = 0,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,

        fn sendAndConfirmVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.VersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = options_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_signer_count = signers_arg.len;
            return try self.allocator.dupe(u8, "sig-versioned");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmVersionedTransaction(&rpc, .{
        .payer = payer,
        .instructions = instructions[0..],
        .signers = &.{signer},
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-versioned", signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_instruction_count);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
}

test "instructions_invoke.buildLegacyMessageBase64WithLatestBlockhash forwards build options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{16} ** 32);

    const MockRpc = struct {
        allocator: Allocator,
        captured_payer: ?sdk.Pubkey = null,
        captured_instruction_count: usize = 0,
        captured_build_options: ?rpc_types.LegacyInstructionsBuildOptions = null,

        fn buildLegacyMessageBase64WithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            options_arg: ?rpc_types.LegacyInstructionsBuildOptions,
        ) ![]u8 {
            self.captured_payer = payer_arg;
            self.captured_instruction_count = instructions_arg.len;
            self.captured_build_options = options_arg;
            return try self.allocator.dupe(u8, "legacy-message");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const encoded = try buildLegacyMessageBase64WithLatestBlockhash(&rpc, .{
        .payer = payer,
        .instructions = &.{},
        .blockhash_commitment = .confirmed,
    });
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("legacy-message", encoded);
    try std.testing.expectEqual(payer, rpc.captured_payer.?);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_instruction_count);
    try std.testing.expectEqual(.confirmed, rpc.captured_build_options.?.blockhash_commitment.?);
}

test "instructions_invoke.sendVersionedTransactionWithBlockhashQuery forwards query options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{17} ** 32);
    const authority = sdk.Pubkey.fromBytes([_]u8{18} ** 32);
    const signer_secret_key = [_]u8{19} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);
    const blockhash_query = rpc_types.BlockhashQuery{
        .fixed = .{ .blockhash = "FixedBlockhash1111111111111111111111111111111111111" },
    };

    const MockRpc = struct {
        allocator: Allocator,
        captured_lookup_count: usize = 0,
        captured_signer_count: usize = 0,
        captured_options: ?rpc_types.SendVersionedInstructionsOptions = null,

        fn sendVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.SendVersionedInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_signer_count = signers_arg.len;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-query");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendVersionedTransactionWithBlockhashQuery(&rpc, .{
        .payer = payer,
        .instructions = &.{},
        .signers = &.{signer},
        .blockhash_query = blockhash_query,
        .nonce_authority = authority,
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-query", signature);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_lookup_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.captured_signer_count);
    try std.testing.expect(rpc.captured_options != null);
    try std.testing.expectEqualDeep(blockhash_query, rpc.captured_options.?.blockhash_query.?);
    try std.testing.expectEqual(authority, rpc.captured_options.?.nonce_authority.?);
}

test "instructions_invoke.sendAndConfirmLegacyTransactionWithSpinner forwards options" {
    const allocator = std.testing.allocator;
    const payer = sdk.Pubkey.fromBytes([_]u8{20} ** 32);
    const signer_secret_key = [_]u8{21} ** 32;
    const signer = try sdk.Keypair.fromSecretKeySlice(signer_secret_key[0..]);

    const MockRpc = struct {
        allocator: Allocator,
        captured_options: ?rpc_types.LegacyInstructionsOptions = null,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            _ = signers_arg;
            self.captured_options = options_arg;
            return try self.allocator.dupe(u8, "sig-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmLegacyTransactionWithSpinner(&rpc, .{
        .payer = payer,
        .instructions = &.{},
        .signers = &.{signer},
        .rpc = .{
            .blockhash_commitment = .processed,
            .commitment = .confirmed,
            .timeout_ms = 123,
        },
    });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spinner", signature);
    try std.testing.expectEqual(.processed, rpc.captured_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_options.?.commitment.?);
    try std.testing.expectEqual(@as(u64, 123), rpc.captured_options.?.timeout_ms);
}

test "instructions_invoke.getFeeForVersionedMessageWithLatestBlockhash forwards fee query inputs" {
    const payer = sdk.Pubkey.fromBytes([_]u8{22} ** 32);

    const MockRpc = struct {
        captured_lookup_count: usize = 0,
        captured_build_options: ?rpc_types.VersionedInstructionsBuildOptions = null,
        captured_commitment: ?rpc_types.Commitment = null,

        fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            address_lookup_tables_arg: []const sdk.AddressLookupTableAccount,
            options_arg: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment_arg: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_lookup_count = address_lookup_tables_arg.len;
            self.captured_build_options = options_arg;
            self.captured_commitment = commitment_arg;
            return .{ .value = 777 };
        }
    };

    var rpc = MockRpc{};
    const fee = try getFeeForVersionedMessageWithLatestBlockhash(&rpc, .{
        .payer = payer,
        .instructions = &.{},
        .blockhash_commitment = .finalized,
    }, .{
        .commitment = .confirmed,
    });

    try std.testing.expectEqual(@as(u64, 777), fee.value.?);
    try std.testing.expectEqual(@as(usize, 0), rpc.captured_lookup_count);
    try std.testing.expectEqual(.finalized, rpc.captured_build_options.?.blockhash_commitment.?);
    try std.testing.expectEqual(.confirmed, rpc.captured_commitment.?);
}
