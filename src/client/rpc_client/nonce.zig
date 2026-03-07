const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const BlockhashQuery = rpc_types.BlockhashQuery;
const Commitment = rpc_types.Commitment;
const FeeForMessage = rpc_types.FeeForMessage;
const FeeForMessageResponse = rpc_types.FeeForMessageResponse;
const LegacyInstructionsBuildOptions = rpc_types.LegacyInstructionsBuildOptions;
const LegacyInstructionsOptions = rpc_types.LegacyInstructionsOptions;
const NonceAccountBuildOptions = rpc_types.NonceAccountBuildOptions;
const NonceAccountOptions = rpc_types.NonceAccountOptions;
const NonceAccount = rpc_types.NonceAccount;
const NonceAccountResponse = rpc_types.NonceAccountResponse;
const ResolvedBlockhash = rpc_types.ResolvedBlockhash;
const SendLegacyInstructionsOptions = rpc_types.SendLegacyInstructionsOptions;
const SendNonceAccountOptions = rpc_types.SendNonceAccountOptions;
const SendTransactionOptions = rpc_types.SendTransactionOptions;
const SimulateTransactionOptions = rpc_types.SimulateTransactionOptions;
const SimulatedTransaction = rpc_types.SimulatedTransaction;
const UiAccountQueryOptions = rpc_types.UiAccountQueryOptions;
const Hash = @import("../sdk.zig").Hash;
const Instruction = @import("../sdk.zig").Instruction;
const Keypair = @import("../sdk.zig").Keypair;
const LegacyTransaction = @import("../sdk.zig").LegacyTransaction;
const OwnedLegacyMessage = @import("../sdk.zig").OwnedLegacyMessage;
const Pubkey = @import("../sdk.zig").Pubkey;
const SignedLegacyTransaction = @import("../sdk.zig").SignedLegacyTransaction;
const SystemProgram = @import("../sdk.zig").SystemProgram;
const buildLegacyTransactionBase64 = @import("../sdk.zig").buildLegacyTransactionBase64;
const sdkBuildOwnedLegacyMessage = @import("../sdk.zig").buildOwnedLegacyMessage;
const buildOwnedLegacyMessageWithNonceInstructions = @import("../sdk.zig").buildOwnedLegacyMessageWithNonceInstructions;
const buildSignedLegacyTransaction = @import("../sdk.zig").buildSignedLegacyTransaction;
const buildSignedLegacyTransactionWithNonceInstructions = @import("../sdk.zig").buildSignedLegacyTransactionWithNonceInstructions;
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

fn resolveLegacyInstructionsBuildQuery(options: ?LegacyInstructionsBuildOptions) BlockhashQuery {
    if (options) |value| {
        if (value.blockhash_query) |query| return query;
        if (value.recent_blockhash) |blockhash| return .{ .fixed = blockhash };
        return .{ .cluster = .{ .commitment = value.blockhash_commitment } };
    }

    return .{ .cluster = .{} };
}

fn legacyInstructionsBuildOptionsFromSendOptions(options: ?SendLegacyInstructionsOptions) ?LegacyInstructionsBuildOptions {
    if (options) |value| {
        return LegacyInstructionsBuildOptions{
            .recent_blockhash = value.recent_blockhash,
            .blockhash_commitment = value.blockhash_commitment,
            .blockhash_query = value.blockhash_query,
            .nonce_authority = value.nonce_authority,
        };
    }

    return null;
}

fn legacyInstructionsBuildOptionsFromOptions(options: ?LegacyInstructionsOptions) ?LegacyInstructionsBuildOptions {
    if (options) |value| {
        return LegacyInstructionsBuildOptions{
            .recent_blockhash = value.recent_blockhash,
            .blockhash_commitment = value.blockhash_commitment,
            .blockhash_query = value.blockhash_query,
            .nonce_authority = value.nonce_authority,
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

pub fn buildOwnedLegacyMessageWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
) !OwnedLegacyMessage {
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash);
    return switch (blockhash_query) {
        .nonce_account => |nonce_query| {
            const authority = nonce_authority orelse return error.MissingNonceAuthority;
            const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_query.pubkey);
            return try buildOwnedLegacyMessageWithNonceInstructions(
                self.allocator,
                payer,
                nonce_account,
                authority,
                recent_blockhash,
                instructions,
            );
        },
        else => try sdkBuildOwnedLegacyMessage(
            self.allocator,
            payer,
            recent_blockhash,
            instructions,
        ),
    };
}

pub fn buildOwnedLegacyMessageWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) !OwnedLegacyMessage {
    return try self.buildOwnedLegacyMessageWithBlockhashQuery(
        payer,
        instructions,
        resolveLegacyInstructionsBuildQuery(options),
        if (options) |value| value.nonce_authority else null,
    );
}

pub fn buildOwnedLegacyMessageWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) !OwnedLegacyMessage {
    return try self.buildOwnedLegacyMessageWithOptions(payer, instructions, options);
}

pub fn buildOwnedLegacyMessage(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    recent_blockhash: []const u8,
) !OwnedLegacyMessage {
    return try self.buildOwnedLegacyMessageWithOptions(
        payer,
        instructions,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildSignedLegacyTransactionWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
) !SignedLegacyTransaction {
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash);
    return switch (blockhash_query) {
        .nonce_account => |nonce_query| {
            const authority = nonce_authority orelse return error.MissingNonceAuthority;
            const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_query.pubkey);
            return try buildSignedLegacyTransactionWithNonceInstructions(
                self.allocator,
                payer,
                nonce_account,
                authority,
                recent_blockhash,
                instructions,
                signers,
            );
        },
        else => try buildSignedLegacyTransaction(
            self.allocator,
            payer,
            recent_blockhash,
            instructions,
            signers,
        ),
    };
}

pub fn buildSignedLegacyTransactionWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildSignedLegacyTransactionWithBlockhashQuery(
        payer,
        instructions,
        signers,
        resolveLegacyInstructionsBuildQuery(options),
        if (options) |value| value.nonce_authority else null,
    );
}

pub fn buildSignedLegacyTransactionWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildSignedLegacyTransactionWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn buildLegacyInstructionsSignedTransactionWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildSignedLegacyTransactionWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn buildLegacyInstructionsSignedTransactionWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) !SignedLegacyTransaction {
    return try self.buildLegacyInstructionsSignedTransactionWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn buildLegacyInstructionsSignedTransaction(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
) !SignedLegacyTransaction {
    return try self.buildSignedLegacyTransactionWithOptions(
        payer,
        instructions,
        signers,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildLegacyMessageBytesWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
) ![]u8 {
    var owned = try self.buildOwnedLegacyMessageWithBlockhashQuery(
        payer,
        instructions,
        blockhash_query,
        nonce_authority,
    );
    defer owned.deinit(self.allocator);

    return try owned.serialize(self.allocator);
}

pub fn buildLegacyMessageBytesWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    var owned = try self.buildOwnedLegacyMessageWithOptions(
        payer,
        instructions,
        options,
    );
    defer owned.deinit(self.allocator);

    return try owned.serialize(self.allocator);
}

pub fn buildLegacyMessageBytesWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    return try self.buildLegacyMessageBytesWithOptions(payer, instructions, options);
}

pub fn buildLegacyMessageBytes(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    recent_blockhash: []const u8,
) ![]u8 {
    return try self.buildLegacyMessageBytesWithOptions(
        payer,
        instructions,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildLegacyMessageBase64WithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
) ![]u8 {
    var owned = try self.buildOwnedLegacyMessageWithBlockhashQuery(
        payer,
        instructions,
        blockhash_query,
        nonce_authority,
    );
    defer owned.deinit(self.allocator);

    return try owned.toBase64(self.allocator);
}

pub fn buildLegacyMessageBase64WithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    var owned = try self.buildOwnedLegacyMessageWithOptions(
        payer,
        instructions,
        options,
    );
    defer owned.deinit(self.allocator);

    return try owned.toBase64(self.allocator);
}

pub fn buildLegacyMessageBase64WithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    return try self.buildLegacyMessageBase64WithOptions(payer, instructions, options);
}

pub fn buildLegacyMessageBase64(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    recent_blockhash: []const u8,
) ![]u8 {
    return try self.buildLegacyMessageBase64WithOptions(
        payer,
        instructions,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildLegacyTransactionBase64WithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
) ![]u8 {
    const resolved = try self.resolveBlockhashQuery(blockhash_query);
    defer self.freeOwnedResolvedBlockhash(resolved);

    const recent_blockhash = try Hash.fromBase58(self.allocator, resolved.blockhash);
    return switch (blockhash_query) {
        .nonce_account => |nonce_query| {
            const authority = nonce_authority orelse return error.MissingNonceAuthority;
            const nonce_account = try Pubkey.fromBase58(self.allocator, nonce_query.pubkey);
            var signed = try buildSignedLegacyTransactionWithNonceInstructions(
                self.allocator,
                payer,
                nonce_account,
                authority,
                recent_blockhash,
                instructions,
                signers,
            );
            defer signed.deinit(self.allocator);
            return try signed.toBase64(self.allocator);
        },
        else => try buildLegacyTransactionBase64(
            self.allocator,
            payer,
            recent_blockhash,
            instructions,
            signers,
        ),
    };
}

pub fn buildLegacyTransactionBase64WithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    var signed = try self.buildSignedLegacyTransactionWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
    defer signed.deinit(self.allocator);
    return try signed.toBase64(self.allocator);
}

pub fn buildLegacyTransactionBase64WithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    return try self.buildLegacyTransactionBase64WithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn buildLegacyInstructionsTransaction(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
) ![]u8 {
    return try self.buildLegacyTransactionBase64WithOptions(
        payer,
        instructions,
        signers,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn buildLegacyInstructionsTransactionWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    return try self.buildLegacyTransactionBase64WithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn buildLegacyInstructionsTransactionWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsBuildOptions,
) ![]u8 {
    return try self.buildLegacyInstructionsTransactionWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn getFeeForLegacyInstructionsResponseWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    var owned = try self.buildOwnedLegacyMessageWithBlockhashQuery(
        payer,
        instructions,
        blockhash_query,
        nonce_authority,
    );
    defer owned.deinit(self.allocator);

    return try self.getFeeForMessageResponseTyped(owned.message, commitment);
}

pub fn getFeeForLegacyInstructionsResponseWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForLegacyInstructionsResponseWithBlockhashQuery(
        payer,
        instructions,
        resolveLegacyInstructionsBuildQuery(options),
        if (options) |value| value.nonce_authority else null,
        commitment,
    );
}

pub fn getFeeForLegacyInstructionsResponseWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForLegacyInstructionsResponseWithOptions(
        payer,
        instructions,
        options,
        commitment,
    );
}

pub fn getFeeForLegacyInstructionsResponse(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
) !FeeForMessageResponse {
    return try self.getFeeForLegacyInstructionsResponseWithOptions(
        payer,
        instructions,
        .{ .recent_blockhash = recent_blockhash },
        commitment,
    );
}

pub fn getFeeForLegacyInstructionsWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    commitment: ?Commitment,
) !FeeForMessage {
    var owned = try self.buildOwnedLegacyMessageWithBlockhashQuery(
        payer,
        instructions,
        blockhash_query,
        nonce_authority,
    );
    defer owned.deinit(self.allocator);

    return try self.getFeeForMessageTyped(owned.message, commitment);
}

pub fn getFeeForLegacyInstructionsWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    return try self.getFeeForLegacyInstructionsWithBlockhashQuery(
        payer,
        instructions,
        resolveLegacyInstructionsBuildQuery(options),
        if (options) |value| value.nonce_authority else null,
        commitment,
    );
}

pub fn getFeeForLegacyInstructionsWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    options: ?LegacyInstructionsBuildOptions,
    commitment: ?Commitment,
) !FeeForMessage {
    return try self.getFeeForLegacyInstructionsWithOptions(
        payer,
        instructions,
        options,
        commitment,
    );
}

pub fn getFeeForLegacyInstructions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
) !FeeForMessage {
    return try self.getFeeForLegacyInstructionsWithOptions(
        payer,
        instructions,
        .{ .recent_blockhash = recent_blockhash },
        commitment,
    );
}

pub fn simulateLegacyInstructionsWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    var signed = try self.buildSignedLegacyTransactionWithBlockhashQuery(
        payer,
        instructions,
        signers,
        blockhash_query,
        nonce_authority,
    );
    defer signed.deinit(self.allocator);

    return try self.simulateTransactionTyped(
        signed,
        options,
    );
}

pub fn simulateLegacyInstructionsWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    build_options: ?LegacyInstructionsBuildOptions,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    return try self.simulateLegacyInstructionsWithBlockhashQuery(
        payer,
        instructions,
        signers,
        resolveLegacyInstructionsBuildQuery(build_options),
        if (build_options) |value| value.nonce_authority else null,
        options,
    );
}

pub fn simulateLegacyInstructionsWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    build_options: ?LegacyInstructionsBuildOptions,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    return try self.simulateLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        build_options,
        options,
    );
}

pub fn simulateLegacyInstructions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    return try self.simulateLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        .{ .recent_blockhash = recent_blockhash },
        options,
    );
}

pub fn sendLegacyInstructionsWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    options: ?SendTransactionOptions,
) ![]const u8 {
    var signed = try self.buildSignedLegacyTransactionWithBlockhashQuery(
        payer,
        instructions,
        signers,
        blockhash_query,
        nonce_authority,
    );
    defer signed.deinit(self.allocator);

    return try self.sendTransactionTyped(
        signed,
        options,
    );
}

pub fn sendLegacyInstructionsWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?SendLegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendLegacyInstructionsWithBlockhashQuery(
        payer,
        instructions,
        signers,
        resolveLegacyInstructionsBuildQuery(legacyInstructionsBuildOptionsFromSendOptions(options)),
        if (options) |value| value.nonce_authority else null,
        if (options) |value| value.send_transaction_options else null,
    );
}

pub fn sendLegacyInstructionsWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?SendLegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn sendLegacyInstructions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
        },
    );
}

pub fn sendAndConfirmLegacyInstructionsWithBlockhashQuery(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try self.buildSignedLegacyTransactionWithBlockhashQuery(
        payer,
        instructions,
        signers,
        blockhash_query,
        nonce_authority,
    );
    defer signed.deinit(self.allocator);

    return try self.sendTransactionAndConfirmTyped(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyInstructionsWithOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQuery(
        payer,
        instructions,
        signers,
        resolveLegacyInstructionsBuildQuery(legacyInstructionsBuildOptionsFromOptions(options)),
        if (options) |value| value.nonce_authority else null,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyInstructionsWithConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn sendAndConfirmLegacyInstructions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithOptions(
        payer,
        instructions,
        signers,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
}

pub fn sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    blockhash_query: BlockhashQuery,
    nonce_authority: ?Pubkey,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try self.buildSignedLegacyTransactionWithBlockhashQuery(
        payer,
        instructions,
        signers,
        blockhash_query,
        nonce_authority,
    );
    defer signed.deinit(self.allocator);

    return try self.sendTransactionAndConfirmTypedWithSpinner(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner(
        payer,
        instructions,
        signers,
        resolveLegacyInstructionsBuildQuery(legacyInstructionsBuildOptionsFromOptions(options)),
        if (options) |value| value.nonce_authority else null,
        if (options) |value| value.send_transaction_options else null,
        if (options) |value| value.commitment else null,
        if (options) |value| value.search_transaction_history else false,
        if (options) |value| value.timeout_ms else poll_for_signature_confirmation_timeout_ms,
        if (options) |value| value.poll_interval_ms else signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyInstructionsWithSpinnerAndConfig(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    options: ?LegacyInstructionsOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        payer,
        instructions,
        signers,
        options,
    );
}

pub fn sendAndConfirmLegacyInstructionsWithSpinner(
    self: anytype,
    payer: Pubkey,
    instructions: []const Instruction,
    signers: []const Keypair,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
        payer,
        instructions,
        signers,
        .{
            .recent_blockhash = recent_blockhash,
            .send_transaction_options = options,
            .commitment = commitment,
        },
    );
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
