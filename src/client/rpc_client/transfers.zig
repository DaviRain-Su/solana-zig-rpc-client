const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const BlockhashQuery = rpc_types.BlockhashQuery;
const Commitment = rpc_types.Commitment;
const NonceTransferBuildOptions = rpc_types.NonceTransferBuildOptions;
const NonceTransferOptions = rpc_types.NonceTransferOptions;
const SendTransactionOptions = rpc_types.SendTransactionOptions;
const SendNonceTransferOptions = rpc_types.SendNonceTransferOptions;
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
const poll_for_signature_confirmation_timeout_ms = sdk.poll_for_signature_confirmation_timeout_ms;
const signature_poll_interval_ms = sdk.signature_poll_interval_ms;

fn resolveTransferBlockhashQuery(options: ?TransferBuildOptions) BlockhashQuery {
    if (options) |value| {
        if (value.blockhash_query) |query| return query;
        if (value.recent_blockhash) |blockhash| return .{ .fixed = blockhash };
        return .{ .cluster = .{ .commitment = value.blockhash_commitment } };
    }

    return .{ .cluster = .{} };
}

fn resolveNonceTransferBlockhashQuery(nonce_account_pubkey: []const u8, options: ?NonceTransferBuildOptions) BlockhashQuery {
    if (options) |value| {
        if (value.blockhash_query) |query| return query;
        if (value.recent_blockhash) |blockhash| return .{ .fixed = blockhash };
        return .{ .nonce_account = .{
            .pubkey = nonce_account_pubkey,
            .commitment = value.blockhash_commitment,
        } };
    }

    return .{ .nonce_account = .{
        .pubkey = nonce_account_pubkey,
        .commitment = null,
    } };
}

fn transferNonceAccountPubkey(query: BlockhashQuery) ?[]const u8 {
    return switch (query) {
        .nonce_account => |value| value.pubkey,
        else => null,
    };
}

fn buildTransferSignedTransactionWithResolvedBlockhash(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    nonce_account_pubkey: ?[]const u8,
) !SignedLegacyTransaction {
    const keypair = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(keypair.public_key, destination_pubkey, lamports);

    if (nonce_account_pubkey) |value| {
        const nonce_pubkey = try Pubkey.fromBase58(self.allocator, value);
        const nonce_instruction = try SystemProgram.advanceNonceAccount(
            self.allocator,
            nonce_pubkey,
            keypair.public_key,
        );
        const instructions = [_]Instruction{
            nonce_instruction.instruction(),
            transfer_instruction.instruction(),
        };
        const transaction = LegacyTransaction{
            .message = .{
                .payer = keypair.public_key,
                .recent_blockhash = blockhash,
                .instructions = instructions[0..],
            },
        };

        return try transaction.sign(self.allocator, &.{keypair});
    }

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

fn buildNonceTransferSignedTransactionWithResolvedBlockhash(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const sender = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const nonce_authority = try Keypair.fromBase58SecretKey(self.allocator, nonce_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    return try sdk.buildSignedLegacyNonceTransferTransaction(
        self.allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination_pubkey,
        blockhash,
        lamports,
        &.{ fee_payer, sender, nonce_authority },
    );
}

pub fn buildTransferSignedTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try buildTransferSignedTransactionWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        null,
    );
}

pub fn buildNonceTransferSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try buildNonceTransferSignedTransactionWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
    );
}

pub fn buildTransferSignedTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) !SignedLegacyTransaction {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildTransferSignedTransactionWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        transferNonceAccountPubkey(blockhash_query),
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

pub fn buildNonceTransferSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferBuildOptions,
) !SignedLegacyTransaction {
    const blockhash_query = resolveNonceTransferBlockhashQuery(nonce_account_pubkey, options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildNonceTransferSignedTransactionWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        resolved.blockhash,
    );
}

pub fn buildNonceTransferSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        options,
    );
}

pub fn buildTransferTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildTransferSignedTransaction(
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildNonceTransferTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildNonceTransferSignedTransaction(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildTransferTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?TransferBuildOptions,
) ![]const u8 {
    var signed = try self.buildTransferSignedTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
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

pub fn buildNonceTransferTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferBuildOptions,
) ![]const u8 {
    var signed = try self.buildNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildNonceTransferTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferBuildOptions,
) ![]const u8 {
    return try self.buildNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        options,
    );
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
                .blockhash_query = value.blockhash_query,
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

pub fn sendNonceTransfer(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    return try self.sendNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn sendNonceTransferWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?SendNonceTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        if (options) |value|
            NonceTransferBuildOptions{
                .recent_blockhash = value.recent_blockhash,
                .blockhash_commitment = value.blockhash_commitment,
                .blockhash_query = value.blockhash_query,
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

pub fn sendNonceTransferWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?SendNonceTransferOptions,
) ![]const u8 {
    return try self.sendNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        options,
    );
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
                .blockhash_query = value.blockhash_query,
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

pub fn nonceTransfer(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.nonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn nonceTransferWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        if (options) |value|
            NonceTransferBuildOptions{
                .recent_blockhash = value.recent_blockhash,
                .blockhash_commitment = value.blockhash_commitment,
                .blockhash_query = value.blockhash_query,
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

pub fn nonceTransferWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    options: ?NonceTransferOptions,
) ![]const u8 {
    return try self.nonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        options,
    );
}
