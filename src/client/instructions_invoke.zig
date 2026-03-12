const std = @import("std");
const rpc_types = @import("./rpc_types.zig");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

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
