const std = @import("std");
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

pub const OwnedInstruction = struct {
    instruction: sdk.Instruction,

    pub fn deinit(self: *OwnedInstruction, allocator: Allocator) void {
        allocator.free(self.instruction.accounts);
        allocator.free(self.instruction.data);
        self.* = undefined;
    }
};

const JsonAccountMeta = struct {
    pubkey: []const u8,
    is_signer: bool = false,
    is_writable: bool = false,
};

const OwnedAccounts = struct {
    metas: []sdk.AccountMeta,

    fn deinit(self: *OwnedAccounts, allocator: Allocator) void {
        allocator.free(self.metas);
        self.* = undefined;
    }
};

fn parseAccountsJson(allocator: Allocator, json_source: []const u8) BuildError!OwnedAccounts {
    const parsed = std.json.parseFromSlice([]JsonAccountMeta, allocator, json_source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidProgramInvokeSpec;
    defer parsed.deinit();

    const metas = try allocator.alloc(sdk.AccountMeta, parsed.value.len);
    errdefer allocator.free(metas);

    for (parsed.value, 0..) |account, index| {
        metas[index] = sdk.AccountMeta.init(
            sdk.Pubkey.fromBase58(allocator, account.pubkey) catch return error.InvalidProgramInvokeSpec,
            account.is_signer,
            account.is_writable,
        );
    }

    return .{ .metas = metas };
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
    const program_pubkey = sdk.Pubkey.fromBase58(allocator, program_id) catch return error.InvalidProgramInvokeSpec;
    return try buildOwnedInstruction(allocator, program_pubkey, options);
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
