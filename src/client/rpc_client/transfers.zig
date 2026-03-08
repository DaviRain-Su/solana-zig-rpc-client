const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const BlockhashQuery = rpc_types.BlockhashQuery;
const Commitment = rpc_types.Commitment;
const FeeForMessage = rpc_types.FeeForMessage;
const FeeForMessageResponse = rpc_types.FeeForMessageResponse;
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
const OwnedVersionedMessageV0 = sdk.OwnedVersionedMessageV0;
const SignedVersionedTransaction = sdk.SignedVersionedTransaction;
const Pubkey = sdk.Pubkey;
const AddressLookupTableAccount = sdk.AddressLookupTableAccount;
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

fn buildVersionedTransferSignedTransactionWithResolvedBlockhash(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    nonce_account_pubkey: ?[]const u8,
) !SignedVersionedTransaction {
    const keypair = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);
    const transfer_instruction = SystemProgram.transfer(keypair.public_key, destination_pubkey, lamports);

    if (nonce_account_pubkey) |value| {
        const nonce_pubkey = try Pubkey.fromBase58(self.allocator, value);
        return try sdk.buildSignedVersionedNonceTransferTransaction(
            self.allocator,
            keypair.public_key,
            nonce_pubkey,
            keypair.public_key,
            destination_pubkey,
            blockhash,
            lamports,
            address_lookup_tables,
            &.{keypair},
        );
    }

    return try sdk.buildSignedVersionedTransactionV0(
        self.allocator,
        keypair.public_key,
        blockhash,
        &[_]Instruction{transfer_instruction.instruction()},
        address_lookup_tables,
        &.{keypair},
    );
}

fn buildVersionedTransferMessageBytesWithResolvedBlockhash(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    nonce_account_pubkey: ?[]const u8,
) ![]u8 {
    const keypair = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    if (nonce_account_pubkey) |value| {
        const nonce_pubkey = try Pubkey.fromBase58(self.allocator, value);
        return try sdk.buildVersionedTransferMessageBytesWithNonce(
            self.allocator,
            keypair.public_key,
            nonce_pubkey,
            keypair.public_key,
            destination_pubkey,
            blockhash,
            lamports,
            address_lookup_tables,
        );
    }

    return try sdk.buildVersionedTransferMessageBytes(
        self.allocator,
        keypair.public_key,
        destination_pubkey,
        blockhash,
        lamports,
        address_lookup_tables,
    );
}

fn buildVersionedTransferSignedTransactionWithSenderAndResolvedBlockhash(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    nonce_account_pubkey: ?[]const u8,
) !SignedVersionedTransaction {
    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const sender = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    if (nonce_account_pubkey) |value| {
        const nonce_pubkey = try Pubkey.fromBase58(self.allocator, value);
        return try sdk.buildSignedVersionedNonceTransferTransactionWithSender(
            self.allocator,
            fee_payer.public_key,
            sender.public_key,
            nonce_pubkey,
            sender.public_key,
            destination_pubkey,
            blockhash,
            lamports,
            address_lookup_tables,
            &.{ fee_payer, sender },
        );
    }

    return try sdk.buildSignedVersionedTransferTransactionWithSender(
        self.allocator,
        fee_payer.public_key,
        sender.public_key,
        destination_pubkey,
        blockhash,
        lamports,
        address_lookup_tables,
        &.{ fee_payer, sender },
    );
}

fn buildOwnedVersionedTransferMessageWithResolvedBlockhash(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    nonce_account_pubkey: ?[]const u8,
) !OwnedVersionedMessageV0 {
    const keypair = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(keypair.public_key, destination_pubkey, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};

    if (nonce_account_pubkey) |value| {
        const nonce_pubkey = try Pubkey.fromBase58(self.allocator, value);
        return try sdk.buildOwnedVersionedMessageV0WithNonceInstructions(
            self.allocator,
            keypair.public_key,
            nonce_pubkey,
            keypair.public_key,
            blockhash,
            instructions[0..],
            address_lookup_tables,
        );
    }

    return try sdk.compileVersionedMessageV0(
        self.allocator,
        keypair.public_key,
        blockhash,
        instructions[0..],
        address_lookup_tables,
    );
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

fn buildVersionedNonceTransferSignedTransactionWithResolvedBlockhash(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !SignedVersionedTransaction {
    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const sender = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const nonce_authority = try Keypair.fromBase58SecretKey(self.allocator, nonce_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(sender.public_key, destination_pubkey, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    return try sdk.buildSignedVersionedTransactionV0WithNonceInstructions(
        self.allocator,
        fee_payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        blockhash,
        instructions[0..],
        address_lookup_tables,
        &.{ fee_payer, sender, nonce_authority },
    );
}

fn buildVersionedNonceTransferMessageBytesWithResolvedBlockhash(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const sender = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const nonce_authority = try Keypair.fromBase58SecretKey(self.allocator, nonce_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(sender.public_key, destination_pubkey, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    return try sdk.buildVersionedMessageV0BytesWithNonceInstructions(
        self.allocator,
        fee_payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        blockhash,
        instructions[0..],
        address_lookup_tables,
    );
}

fn buildOwnedVersionedNonceTransferMessageWithResolvedBlockhash(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const sender = try Keypair.fromBase58SecretKey(self.allocator, sender_secret_key);
    const nonce_authority = try Keypair.fromBase58SecretKey(self.allocator, nonce_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const destination_pubkey = try Pubkey.fromBase58(self.allocator, destination);
    const blockhash = try Hash.fromBase58(self.allocator, recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(sender.public_key, destination_pubkey, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    return try sdk.buildOwnedVersionedMessageV0WithNonceInstructions(
        self.allocator,
        fee_payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        blockhash,
        instructions[0..],
        address_lookup_tables,
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

pub fn buildVersionedTransferSignedTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !SignedVersionedTransaction {
    return try buildVersionedTransferSignedTransactionWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        null,
    );
}

pub fn buildVersionedTransferSignedTransactionWithSender(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !SignedVersionedTransaction {
    return try buildVersionedTransferSignedTransactionWithSenderAndResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        null,
    );
}

pub fn buildVersionedTransferSignedTransactionWithSenderAndOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !SignedVersionedTransaction {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildVersionedTransferSignedTransactionWithSenderAndResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
        transferNonceAccountPubkey(blockhash_query),
    );
}

pub fn buildVersionedTransferSignedTransactionWithSenderAndConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !SignedVersionedTransaction {
    return try self.buildVersionedTransferSignedTransactionWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedTransferSignedTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !SignedVersionedTransaction {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildVersionedTransferSignedTransactionWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
        transferNonceAccountPubkey(blockhash_query),
    );
}

pub fn buildVersionedTransferSignedTransactionWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !SignedVersionedTransaction {
    return try self.buildVersionedTransferSignedTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildOwnedVersionedTransferMessage(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedTransferMessageWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        null,
    );
}

pub fn buildOwnedVersionedTransferMessageWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !OwnedVersionedMessageV0 {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildOwnedVersionedTransferMessageWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
        transferNonceAccountPubkey(blockhash_query),
    );
}

pub fn buildOwnedVersionedTransferMessageWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) !OwnedVersionedMessageV0 {
    return try self.buildOwnedVersionedTransferMessageWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedTransferMessageBytes(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedTransferMessageBytesWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        null,
    );
}

pub fn buildVersionedTransferMessageBytesWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]u8 {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildVersionedTransferMessageBytesWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
        transferNonceAccountPubkey(blockhash_query),
    );
}

pub fn buildVersionedTransferMessageBytesWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]u8 {
    return try self.buildVersionedTransferMessageBytesWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedTransferMessageBase64(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try self.buildVersionedTransferMessageBytes(
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
    defer self.allocator.free(message_bytes);
    return try sdk.encodeBase64(self.allocator, message_bytes);
}

pub fn buildVersionedTransferMessageBase64WithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]u8 {
    const message_bytes = try self.buildVersionedTransferMessageBytesWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
    defer self.allocator.free(message_bytes);
    return try sdk.encodeBase64(self.allocator, message_bytes);
}

pub fn buildVersionedTransferMessageBase64WithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]u8 {
    return try self.buildVersionedTransferMessageBase64WithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn getFeeForVersionedTransferMessageResponse(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForVersionedTransferMessageResponseWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        .{ .recent_blockhash = recent_blockhash },
        commitment,
    );
}

pub fn getFeeForVersionedTransferMessageResponseWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    const blockhash_query = resolveTransferBlockhashQuery(options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    var owned = try buildOwnedVersionedTransferMessageWithResolvedBlockhash(
        self,
        sender_secret_key,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
        transferNonceAccountPubkey(blockhash_query),
    );
    defer owned.deinit(self.allocator);

    return try self.getFeeForVersionedMessageResponseTyped(owned.message, commitment);
}

pub fn getFeeForVersionedTransferMessageResponseWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForVersionedTransferMessageResponseWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
    );
}

pub fn getFeeForVersionedTransferMessage(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
) !FeeForMessage {
    const response = try self.getFeeForVersionedTransferMessageResponse(
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        commitment,
    );
    return FeeForMessage{ .value = response.value };
}

pub fn getFeeForVersionedTransferMessageWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    const response = try self.getFeeForVersionedTransferMessageResponseWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
    );
    return FeeForMessage{ .value = response.value };
}

pub fn getFeeForVersionedTransferMessageWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    return try self.getFeeForVersionedTransferMessageWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
    );
}

pub fn buildOwnedVersionedNonceTransferMessage(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedNonceTransferMessageWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedNonceTransferMessageWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) !OwnedVersionedMessageV0 {
    const blockhash_query = resolveNonceTransferBlockhashQuery(nonce_account_pubkey, options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildOwnedVersionedNonceTransferMessageWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedNonceTransferMessageWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) !OwnedVersionedMessageV0 {
    return try self.buildOwnedVersionedNonceTransferMessageWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedNonceTransferMessageBytes(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedNonceTransferMessageBytesWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessageBytesWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]u8 {
    const blockhash_query = resolveNonceTransferBlockhashQuery(nonce_account_pubkey, options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildVersionedNonceTransferMessageBytesWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessageBytesWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]u8 {
    return try self.buildVersionedNonceTransferMessageBytesWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedNonceTransferMessageBase64(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try self.buildVersionedNonceTransferMessageBytes(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
    defer self.allocator.free(message_bytes);
    return try sdk.encodeBase64(self.allocator, message_bytes);
}

pub fn buildVersionedNonceTransferMessageBase64WithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]u8 {
    const message_bytes = try self.buildVersionedNonceTransferMessageBytesWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
    defer self.allocator.free(message_bytes);
    return try sdk.encodeBase64(self.allocator, message_bytes);
}

pub fn buildVersionedNonceTransferMessageBase64WithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]u8 {
    return try self.buildVersionedNonceTransferMessageBase64WithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn getFeeForVersionedNonceTransferMessageResponse(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForVersionedNonceTransferMessageResponseWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        .{ .recent_blockhash = recent_blockhash },
        commitment,
    );
}

pub fn getFeeForVersionedNonceTransferMessageResponseWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    const blockhash_query = resolveNonceTransferBlockhashQuery(nonce_account_pubkey, options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    var owned = try buildOwnedVersionedNonceTransferMessageWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
    );
    defer owned.deinit(self.allocator);

    return try self.getFeeForVersionedMessageResponseTyped(owned.message, commitment);
}

pub fn getFeeForVersionedNonceTransferMessageResponseWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForVersionedNonceTransferMessageResponseWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
    );
}

pub fn getFeeForVersionedNonceTransferMessage(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
) !FeeForMessage {
    const response = try self.getFeeForVersionedNonceTransferMessageResponse(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
        commitment,
    );
    return FeeForMessage{ .value = response.value };
}

pub fn getFeeForVersionedNonceTransferMessageWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    const response = try self.getFeeForVersionedNonceTransferMessageResponseWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
    );
    return FeeForMessage{ .value = response.value };
}

pub fn getFeeForVersionedNonceTransferMessageWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    return try self.getFeeForVersionedNonceTransferMessageWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
        commitment,
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

pub fn buildVersionedNonceTransferSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) !SignedVersionedTransaction {
    return try buildVersionedNonceTransferSignedTransactionWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) !SignedVersionedTransaction {
    const blockhash_query = resolveNonceTransferBlockhashQuery(nonce_account_pubkey, options);
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    return try buildVersionedNonceTransferSignedTransactionWithResolvedBlockhash(
        self,
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        resolved.blockhash,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) !SignedVersionedTransaction {
    return try self.buildVersionedNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn buildVersionedTransferTransaction(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]const u8 {
    var signed = try self.buildVersionedTransferSignedTransaction(
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransferTransactionWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]const u8 {
    var signed = try self.buildVersionedTransferSignedTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransferTransactionWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]const u8 {
    return try self.buildVersionedTransferTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn buildVersionedTransferTransactionWithSender(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]const u8 {
    var signed = try self.buildVersionedTransferSignedTransactionWithSender(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransferTransactionWithSenderAndOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]const u8 {
    var signed = try self.buildVersionedTransferSignedTransactionWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedTransferTransactionWithSenderAndConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferBuildOptions,
) ![]const u8 {
    return try self.buildVersionedTransferTransactionWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
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

pub fn buildVersionedNonceTransferTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]const u8 {
    var signed = try self.buildVersionedNonceTransferSignedTransaction(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        recent_blockhash,
        address_lookup_tables,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedNonceTransferTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]const u8 {
    var signed = try self.buildVersionedNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildVersionedNonceTransferTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferBuildOptions,
) ![]const u8 {
    return try self.buildVersionedNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn sendVersionedTransfer(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]const u8 {
    return try self.sendVersionedTransferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn sendVersionedTransferWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildVersionedTransferTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn sendVersionedTransferWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendTransferOptions,
) ![]const u8 {
    return try self.sendVersionedTransferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn sendVersionedTransferWithSender(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendVersionedTransferWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendVersionedTransferWithSenderAndOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendTransferOptions,
) ![]const u8 {
    const build_options: ?TransferBuildOptions = if (options) |value| .{
        .recent_blockhash = value.recent_blockhash,
        .blockhash_commitment = value.blockhash_commitment,
        .blockhash_query = value.blockhash_query,
    } else null;

    const signed_tx_base64 = try self.buildVersionedTransferTransactionWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        build_options,
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendEncodedTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendVersionedTransferWithSenderAndConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendTransferOptions,
) ![]const u8 {
    return try self.sendVersionedTransferWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
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

pub fn sendVersionedNonceTransfer(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]const u8 {
    return try self.sendVersionedNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn sendVersionedNonceTransferWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendNonceTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildVersionedNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn sendVersionedNonceTransferWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?SendNonceTransferOptions,
) ![]const u8 {
    return try self.sendVersionedNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn versionedTransfer(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.versionedTransferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn versionedTransferWithOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildVersionedTransferTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn versionedTransferWithConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    return try self.versionedTransferWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn versionedTransferWithSender(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.versionedTransferWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn versionedTransferWithSenderAndOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    const build_options: ?TransferBuildOptions = if (options) |value| .{
        .recent_blockhash = value.recent_blockhash,
        .blockhash_commitment = value.blockhash_commitment,
        .blockhash_query = value.blockhash_query,
    } else null;

    const signed_tx_base64 = try self.buildVersionedTransferTransactionWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        build_options,
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendAndConfirmEncodedTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn versionedTransferWithSenderAndConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    return try self.versionedTransferWithSenderAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
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

pub fn versionedNonceTransfer(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.versionedNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn versionedNonceTransferWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildVersionedNonceTransferTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
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

pub fn versionedNonceTransferWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferOptions,
) ![]const u8 {
    return try self.versionedNonceTransferWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn versionedTransferWithSpinner(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.versionedTransferWithSpinnerAndOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn versionedTransferWithSpinnerAndOptions(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    const build_options: ?TransferBuildOptions = if (options) |value| .{
        .recent_blockhash = value.recent_blockhash,
        .blockhash_commitment = value.blockhash_commitment,
        .blockhash_query = value.blockhash_query,
    } else null;

    var signed = try self.buildVersionedTransferSignedTransactionWithOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        build_options,
    );
    defer signed.deinit(self.allocator);

    return try self.sendAndConfirmVersionedTransactionTypedWithSpinner(
        signed,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn versionedTransferWithSpinnerAndConfig(
    self: anytype,
    sender_secret_key: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?TransferOptions,
) ![]const u8 {
    return try self.versionedTransferWithSpinnerAndOptions(
        sender_secret_key,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}

pub fn versionedNonceTransferWithSpinner(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    address_lookup_tables: []const AddressLookupTableAccount,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.versionedNonceTransferWithSpinnerAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn versionedNonceTransferWithSpinnerAndOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferOptions,
) ![]const u8 {
    const build_options: ?NonceTransferBuildOptions = if (options) |value| .{
        .recent_blockhash = value.recent_blockhash,
        .blockhash_commitment = value.blockhash_commitment,
        .blockhash_query = value.blockhash_query,
    } else null;

    var signed = try self.buildVersionedNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        build_options,
    );
    defer signed.deinit(self.allocator);

    return try self.sendAndConfirmVersionedTransactionTypedWithSpinner(
        signed,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn versionedNonceTransferWithSpinnerAndConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    sender_secret_key: []const u8,
    nonce_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    destination: []const u8,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    options: ?NonceTransferOptions,
) ![]const u8 {
    return try self.versionedNonceTransferWithSpinnerAndOptions(
        fee_payer_secret_key,
        sender_secret_key,
        nonce_authority_secret_key,
        nonce_account_pubkey,
        destination,
        lamports,
        address_lookup_tables,
        options,
    );
}
