const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const BlockhashQuery = rpc_types.BlockhashQuery;
const Commitment = rpc_types.Commitment;
const NonceAccount = rpc_types.NonceAccount;
const NonceAccountResponse = rpc_types.NonceAccountResponse;
const ResolvedBlockhash = rpc_types.ResolvedBlockhash;
const UiAccountQueryOptions = rpc_types.UiAccountQueryOptions;

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
