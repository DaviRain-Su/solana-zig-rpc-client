const std = @import("std");
const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const Ed25519 = std.crypto.sign.Ed25519;

const Commitment = rpc_types.Commitment;
const SendTransactionOptions = rpc_types.SendTransactionOptions;
const SendTransferOptions = rpc_types.SendTransferOptions;
const TransferBuildOptions = rpc_types.TransferBuildOptions;
const TransferOptions = rpc_types.TransferOptions;

const Hash = sdk.Hash;
const Instruction = sdk.Instruction;
const Keypair = sdk.Keypair;
const LegacyTransaction = sdk.LegacyTransaction;
const Pubkey = sdk.Pubkey;
const SignedLegacyTransaction = sdk.SignedLegacyTransaction;
const SystemProgram = sdk.SystemProgram;
const buildLegacyTransferTransaction = sdk.buildLegacyTransferTransaction;
const decodeBase58WithLength = sdk.decodeBase58WithLength;
const poll_for_signature_confirmation_timeout_ms = sdk.poll_for_signature_confirmation_timeout_ms;
const signature_poll_interval_ms = sdk.signature_poll_interval_ms;

fn resolveTransferRecentBlockhash(
    self: anytype,
    recent_blockhash: ?[]const u8,
    blockhash_commitment: ?Commitment,
) ![]const u8 {
    if (recent_blockhash) |value| {
        return try self.allocator.dupe(u8, value);
    }

    const latest_blockhash = try self.getLatestBlockhash(blockhash_commitment);
    return latest_blockhash.blockhash;
}

pub fn buildTransferSignedTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    const keypair = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(keypair.public_key, destination_pubkey, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = blockhash,
            .instructions = instructions[0..],
        },
    };

    return try transaction.sign(self.allocator, &.{keypair});
}

pub fn buildTransferSignedTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) !SignedLegacyTransaction {
    const recent_blockhash = try resolveTransferRecentBlockhash(
        self,
        if (options) |value| value.recent_blockhash else null,
        if (options) |value| value.blockhash_commitment else null,
    );
    defer self.allocator.free(recent_blockhash);

    return try self.buildTransferSignedTransaction(
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
    );
}

pub fn buildTransferSignedTransactionWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildTransferSignedTransactionWithOptions(sender_secret_key, destination, lamports, options);
}

pub fn buildTransferTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    const sender_secret_key_bytes = try decodeBase58WithLength(
        self.allocator,
        sender_secret_key,
        Ed25519.SecretKey.encoded_length,
    );
    defer self.allocator.free(sender_secret_key_bytes);

    const destination_public_key = try decodeBase58WithLength(
        self.allocator,
        destination,
        Ed25519.PublicKey.encoded_length,
    );
    defer self.allocator.free(destination_public_key);

    const recent_blockhash_bytes = try decodeBase58WithLength(self.allocator, recent_blockhash, 32);
    defer self.allocator.free(recent_blockhash_bytes);

    return try buildLegacyTransferTransaction(
        self.allocator,
        sender_secret_key_bytes,
        destination_public_key,
        recent_blockhash_bytes,
        lamports,
    );
}

pub fn buildTransferTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) ![]const u8 {
    const recent_blockhash = try resolveTransferRecentBlockhash(
        self,
        if (options) |value| value.recent_blockhash else null,
        if (options) |value| value.blockhash_commitment else null,
    );
    defer self.allocator.free(recent_blockhash);

    return try self.buildTransferTransaction(sender_secret_key, destination, lamports, recent_blockhash);
}

pub fn buildTransferTransactionWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) ![]const u8 {
    return try self.buildTransferTransactionWithOptions(sender_secret_key, destination, lamports, options);
}

pub fn sendTransfer(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    return try self.sendTransferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn sendTransferWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?SendTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildTransferTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        if (options) |value|
            TransferBuildOptions{
                .recent_blockhash = value.recent_blockhash,
                .blockhash_commitment = value.blockhash_commitment,
            }
        else
            null,
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendTransferWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?SendTransferOptions,
) ![]const u8 {
    return try self.sendTransferWithOptions(sender_secret_key, destination, lamports, options);
}

pub fn transfer(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.transferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn transferWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildTransferTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        if (options) |value|
            TransferBuildOptions{
                .recent_blockhash = value.recent_blockhash,
                .blockhash_commitment = value.blockhash_commitment,
            }
        else
            null,
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransactionAndConfirm(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn transferWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferOptions,
) ![]const u8 {
    return try self.transferWithOptions(sender_secret_key, destination, lamports, options);
}
