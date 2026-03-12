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
