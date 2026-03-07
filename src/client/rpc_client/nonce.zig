const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const BlockhashQuery = rpc_types.BlockhashQuery;
const Commitment = rpc_types.Commitment;
const NonceAccountBuildOptions = rpc_types.NonceAccountBuildOptions;
const NonceAccountOptions = rpc_types.NonceAccountOptions;
const NonceAccount = rpc_types.NonceAccount;
const NonceAccountResponse = rpc_types.NonceAccountResponse;
const ResolvedBlockhash = rpc_types.ResolvedBlockhash;
const SendNonceAccountOptions = rpc_types.SendNonceAccountOptions;
const SendTransactionOptions = rpc_types.SendTransactionOptions;
const UiAccountQueryOptions = rpc_types.UiAccountQueryOptions;
const Hash = @import("../sdk.zig").Hash;
const Keypair = @import("../sdk.zig").Keypair;
const LegacyTransaction = @import("../sdk.zig").LegacyTransaction;
const Pubkey = @import("../sdk.zig").Pubkey;
const SignedLegacyTransaction = @import("../sdk.zig").SignedLegacyTransaction;
const SystemProgram = @import("../sdk.zig").SystemProgram;
const poll_for_signature_confirmation_timeout_ms = @import("../sdk.zig").poll_for_signature_confirmation_timeout_ms;
const signature_poll_interval_ms = @import("../sdk.zig").signature_poll_interval_ms;

fn resolveNonceAccountBuildQuery(options: ?NonceAccountBuildOptions) BlockhashQuery {
    if (options) |value| {
        if (value.recent_blockhash) |blockhash| return .{ .fixed = blockhash };
        return .{ .cluster = .{ .commitment = value.blockhash_commitment } };
    }

    return .{ .cluster = .{} };
}

fn resolveNonceAccountBuildBlockhash(self: anytype, options: ?NonceAccountBuildOptions) !ResolvedBlockhash {
    return try self.resolveBlockhashQuery(resolveNonceAccountBuildQuery(options));
}

fn nonceAccountBuildOptionsFromSendOptions(options: ?SendNonceAccountOptions) ?NonceAccountBuildOptions {
    if (options) |value| {
        return NonceAccountBuildOptions{
            .recent_blockhash = value.recent_blockhash,
            .blockhash_commitment = value.blockhash_commitment,
        };
    }

    return null;
}

fn nonceAccountBuildOptionsFromOptions(options: ?NonceAccountOptions) ?NonceAccountBuildOptions {
    if (options) |value| {
        return NonceAccountBuildOptions{
            .recent_blockhash = value.recent_blockhash,
            .blockhash_commitment = value.blockhash_commitment,
        };
    }

    return null;
}

fn confirmNonceAccountTransaction(
    self: anytype,
    signed: SignedLegacyTransaction,
    options: ?NonceAccountOptions,
) ![]const u8 {
    return try self.sendTransactionAndConfirmTyped(
        signed,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

fn freeOwnedJsonParsedAccount(self: anytype, account: rpc_types.JsonParsedAccountInfo) void {
    self.allocator.free(account.owner);
    self.allocator.free(account.data_json);
}

fn parseNonceAccount(self: anytype, account: rpc_types.JsonParsedAccountInfo) !NonceAccount {
    const ParsedNonceData = struct {
        parsed: ?struct {
            info: ?struct {
                authority: ?[]const u8 = null,
                blockhash: ?[]const u8 = null,
                feeCalculator: ?struct {
                    lamportsPerSignature: ?u64 = null,
                } = null,
            } = null,
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedNonceData, self.allocator, account.data_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const parsed_data = parsed.value.parsed orelse return error.InvalidResponse;
    const parsed_info = parsed_data.info orelse return error.InvalidResponse;
    const authority = parsed_info.authority orelse return error.InvalidResponse;
    const blockhash = parsed_info.blockhash orelse return error.InvalidResponse;

    return NonceAccount{
        .authority = try self.allocator.dupe(u8, authority),
        .blockhash = try self.allocator.dupe(u8, blockhash),
        .lamports_per_signature = if (parsed_info.feeCalculator) |value| value.lamportsPerSignature else null,
    };
}

pub fn freeOwnedNonceAccount(self: anytype, account: NonceAccount) void {
    self.allocator.free(account.authority);
    self.allocator.free(account.blockhash);
}

pub fn freeOwnedResolvedBlockhash(self: anytype, resolved: ResolvedBlockhash) void {
    self.allocator.free(resolved.blockhash);
}

pub fn getNonceAccountResponseWithOptions(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !NonceAccountResponse {
    const response = try self.getUiAccountResponseWithOptions(nonce_account_pubkey, options);
    errdefer if (response.account) |account| freeOwnedJsonParsedAccount(self, account);

    return NonceAccountResponse{
        .context_slot = response.context_slot,
        .account = if (response.account) |account| blk: {
            defer freeOwnedJsonParsedAccount(self, account);
            break :blk try parseNonceAccount(self, account);
        } else null,
    };
}

pub fn getNonceAccountResponseWithConfig(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !NonceAccountResponse {
    return try self.getNonceAccountResponseWithOptions(nonce_account_pubkey, options);
}

pub fn getNonceAccountMaybeWithOptions(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !?NonceAccount {
    const response = try self.getNonceAccountResponseWithOptions(nonce_account_pubkey, options);
    return response.account;
}

pub fn getNonceAccountMaybeWithConfig(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !?NonceAccount {
    return try self.getNonceAccountMaybeWithOptions(nonce_account_pubkey, options);
}

pub fn getNonceAccountWithOptions(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !NonceAccount {
    return (try self.getNonceAccountMaybeWithOptions(nonce_account_pubkey, options)) orelse error.AccountNotFound;
}

pub fn getNonceAccountWithConfig(
    self: anytype,
    nonce_account_pubkey: []const u8,
    options: ?UiAccountQueryOptions,
) !NonceAccount {
    return try self.getNonceAccountWithOptions(nonce_account_pubkey, options);
}

pub fn getNonceAccountResponse(
    self: anytype,
    nonce_account_pubkey: []const u8,
    commitment: ?Commitment,
) !NonceAccountResponse {
    return try self.getNonceAccountResponseWithOptions(
        nonce_account_pubkey,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getNonceAccountMaybe(
    self: anytype,
    nonce_account_pubkey: []const u8,
    commitment: ?Commitment,
) !?NonceAccount {
    return try self.getNonceAccountMaybeWithOptions(
        nonce_account_pubkey,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getNonceAccount(
    self: anytype,
    nonce_account_pubkey: []const u8,
    commitment: ?Commitment,
) !NonceAccount {
    return (try self.getNonceAccountMaybe(nonce_account_pubkey, commitment)) orelse error.AccountNotFound;
}

pub fn getNonceBlockhash(
    self: anytype,
    nonce_account_pubkey: []const u8,
    commitment: ?Commitment,
) ![]const u8 {
    const nonce_account = try self.getNonceAccount(nonce_account_pubkey, commitment);
    defer self.freeOwnedNonceAccount(nonce_account);

    return try self.allocator.dupe(u8, nonce_account.blockhash);
}

pub fn resolveBlockhashQuery(self: anytype, query: BlockhashQuery) !ResolvedBlockhash {
    return switch (query) {
        .cluster => |cluster_query| blk: {
            const latest = try self.getLatestBlockhashResponse(cluster_query.commitment);
            break :blk ResolvedBlockhash{
                .blockhash = latest.value.blockhash,
                .source = .cluster,
                .context_slot = latest.context_slot,
                .last_valid_block_height = latest.value.last_valid_block_height,
            };
        },
        .fixed => |blockhash| ResolvedBlockhash{
            .blockhash = try self.allocator.dupe(u8, blockhash),
            .source = .fixed,
            .context_slot = null,
            .last_valid_block_height = null,
        },
        .nonce_account => |nonce_query| blk: {
            const nonce_account = try self.getNonceAccountResponse(nonce_query.pubkey, nonce_query.commitment);
            const account = nonce_account.account orelse return error.AccountNotFound;
            self.allocator.free(account.authority);
            break :blk ResolvedBlockhash{
                .blockhash = account.blockhash,
                .source = .nonce_account,
                .context_slot = nonce_account.context_slot,
                .last_valid_block_height = null,
            };
        },
    };
}

pub fn buildInitializeNonceAccountSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    const resolved = try resolveNonceAccountBuildBlockhash(self, options);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const nonce_authority = try Pubkey.fromBase58(self.allocator, nonce_authority_pubkey);
    const initialize = try SystemProgram.initializeNonceAccount(self.allocator, nonce_account, nonce_authority);
    const instructions = [_]@import("../sdk.zig").Instruction{initialize.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash),
            .instructions = instructions[0..],
        },
    };

    return try transaction.sign(self.allocator, &.{fee_payer});
}

pub fn buildInitializeNonceAccountSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try self.buildInitializeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildInitializeNonceAccountSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildInitializeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        options,
    );
}

pub fn buildInitializeNonceAccountTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildInitializeNonceAccountSignedTransaction(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildInitializeNonceAccountTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    var signed = try self.buildInitializeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildInitializeNonceAccountTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    return try self.buildInitializeNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        options,
    );
}

pub fn sendInitializeNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendInitializeNonceAccountWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendInitializeNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildInitializeNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        nonceAccountBuildOptionsFromSendOptions(options),
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendInitializeNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    return try self.sendInitializeNonceAccountWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        options,
    );
}

pub fn initializeNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.initializeNonceAccountWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn initializeNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    var signed = try self.buildInitializeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        nonceAccountBuildOptionsFromOptions(options),
    );
    defer signed.deinit(self.allocator);

    return try confirmNonceAccountTransaction(
        self,
        signed,
        options,
    );
}

pub fn initializeNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    nonce_authority_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    return try self.initializeNonceAccountWithOptions(
        fee_payer_secret_key,
        nonce_account_pubkey,
        nonce_authority_pubkey,
        options,
    );
}

pub fn buildAdvanceNonceAccountSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    const resolved = try resolveNonceAccountBuildBlockhash(self, options);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const current_authority = try Keypair.fromBase58SecretKey(self.allocator, current_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const advance = try SystemProgram.advanceNonceAccount(
        self.allocator,
        nonce_account,
        current_authority.public_key,
    );
    const instructions = [_]@import("../sdk.zig").Instruction{advance.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash),
            .instructions = instructions[0..],
        },
    };

    return try transaction.sign(self.allocator, &.{ fee_payer, current_authority });
}

pub fn buildAdvanceNonceAccountSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try self.buildAdvanceNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildAdvanceNonceAccountSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildAdvanceNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        options,
    );
}

pub fn buildAdvanceNonceAccountTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildAdvanceNonceAccountSignedTransaction(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildAdvanceNonceAccountTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    var signed = try self.buildAdvanceNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildAdvanceNonceAccountTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    return try self.buildAdvanceNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        options,
    );
}

pub fn sendAdvanceNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recent_blockhash: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendAdvanceNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendAdvanceNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildAdvanceNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        nonceAccountBuildOptionsFromSendOptions(options),
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendAdvanceNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    return try self.sendAdvanceNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        options,
    );
}

pub fn advanceNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.advanceNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn advanceNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    var signed = try self.buildAdvanceNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        nonceAccountBuildOptionsFromOptions(options),
    );
    defer signed.deinit(self.allocator);

    return try confirmNonceAccountTransaction(
        self,
        signed,
        options,
    );
}

pub fn advanceNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    return try self.advanceNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        options,
    );
}

pub fn buildAuthorizeNonceAccountSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    const resolved = try resolveNonceAccountBuildBlockhash(self, options);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const current_authority = try Keypair.fromBase58SecretKey(self.allocator, current_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const new_authority = try Pubkey.fromBase58(self.allocator, new_authority_pubkey);
    const authorize = SystemProgram.authorizeNonceAccount(nonce_account, current_authority.public_key, new_authority);
    const instructions = [_]@import("../sdk.zig").Instruction{authorize.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash),
            .instructions = instructions[0..],
        },
    };

    return try transaction.sign(self.allocator, &.{ fee_payer, current_authority });
}

pub fn buildAuthorizeNonceAccountSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try self.buildAuthorizeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildAuthorizeNonceAccountSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildAuthorizeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        options,
    );
}

pub fn buildAuthorizeNonceAccountTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildAuthorizeNonceAccountSignedTransaction(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildAuthorizeNonceAccountTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    var signed = try self.buildAuthorizeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildAuthorizeNonceAccountTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    return try self.buildAuthorizeNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        options,
    );
}

pub fn sendAuthorizeNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendAuthorizeNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendAuthorizeNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildAuthorizeNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        nonceAccountBuildOptionsFromSendOptions(options),
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendAuthorizeNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    return try self.sendAuthorizeNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        options,
    );
}

pub fn authorizeNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.authorizeNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn authorizeNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    var signed = try self.buildAuthorizeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        nonceAccountBuildOptionsFromOptions(options),
    );
    defer signed.deinit(self.allocator);

    return try confirmNonceAccountTransaction(
        self,
        signed,
        options,
    );
}

pub fn authorizeNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    new_authority_pubkey: []const u8,
    options: ?NonceAccountOptions,
) ![]const u8 {
    return try self.authorizeNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        new_authority_pubkey,
        options,
    );
}

pub fn buildWithdrawNonceAccountSignedTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    const resolved = try resolveNonceAccountBuildBlockhash(self, options);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const fee_payer = try Keypair.fromBase58SecretKey(self.allocator, fee_payer_secret_key);
    const current_authority = try Keypair.fromBase58SecretKey(self.allocator, current_authority_secret_key);
    const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_account_pubkey);
    const recipient = try Pubkey.fromBase58(self.allocator, recipient_pubkey);
    const withdraw = try SystemProgram.withdrawNonceAccount(
        self.allocator,
        nonce_account,
        recipient,
        current_authority.public_key,
        lamports,
    );
    const instructions = [_]@import("../sdk.zig").Instruction{withdraw.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash),
            .instructions = instructions[0..],
        },
    };

    return try transaction.sign(self.allocator, &.{ fee_payer, current_authority });
}

pub fn buildWithdrawNonceAccountSignedTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try self.buildWithdrawNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildWithdrawNonceAccountSignedTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildWithdrawNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        options,
    );
}

pub fn buildWithdrawNonceAccountTransaction(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    var signed = try self.buildWithdrawNonceAccountSignedTransaction(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        recent_blockhash,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildWithdrawNonceAccountTransactionWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    var signed = try self.buildWithdrawNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildWithdrawNonceAccountTransactionWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountBuildOptions,
) ![]const u8 {
    return try self.buildWithdrawNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        options,
    );
}

pub fn sendWithdrawNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendWithdrawNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendWithdrawNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    const signed_tx_base64 = try self.buildWithdrawNonceAccountTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        nonceAccountBuildOptionsFromSendOptions(options),
    );
    defer self.allocator.free(signed_tx_base64);

    return try self.sendTransaction(
        signed_tx_base64,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendWithdrawNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?SendNonceAccountOptions,
) ![]const u8 {
    return try self.sendWithdrawNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        options,
    );
}

pub fn withdrawNonceAccount(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.withdrawNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn withdrawNonceAccountWithOptions(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountOptions,
) ![]const u8 {
    var signed = try self.buildWithdrawNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        nonceAccountBuildOptionsFromOptions(options),
    );
    defer signed.deinit(self.allocator);

    return try confirmNonceAccountTransaction(
        self,
        signed,
        options,
    );
}

pub fn withdrawNonceAccountWithConfig(
    self: anytype,
    fee_payer_secret_key: []const u8,
    current_authority_secret_key: []const u8,
    nonce_account_pubkey: []const u8,
    recipient_pubkey: []const u8,
    lamports: u64,
    options: ?NonceAccountOptions,
) ![]const u8 {
    return try self.withdrawNonceAccountWithOptions(
        fee_payer_secret_key,
        current_authority_secret_key,
        nonce_account_pubkey,
        recipient_pubkey,
        lamports,
        options,
    );
}
