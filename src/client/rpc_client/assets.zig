const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const BalanceResponse = rpc_types.BalanceResponse;
const Commitment = rpc_types.Commitment;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const LargestAccount = rpc_types.LargestAccount;
const LargestAccountsQueryOptions = rpc_types.LargestAccountsQueryOptions;
const RequestAirdropOptions = rpc_types.RequestAirdropOptions;
const RpcJsonParsedProgramAccountResult = rpc_types.RpcJsonParsedProgramAccountResult;
const RpcTokenAmountResult = rpc_types.RpcTokenAmountResult;
const Supply = rpc_types.Supply;
const SupplyQueryOptions = rpc_types.SupplyQueryOptions;
const TokenAccountsFilter = rpc_types.TokenAccountsFilter;
const TokenAmount = rpc_types.TokenAmount;
const TokenAmountResponse = rpc_types.TokenAmountResponse;
const TokenLargestAccount = rpc_types.TokenLargestAccount;
const TokenLargestAccountsResponse = rpc_types.TokenLargestAccountsResponse;
const UiAccountQueryOptions = rpc_types.UiAccountQueryOptions;
const commitmentParams = rpc_types.commitmentParams;
const commitmentToString = rpc_types.commitmentToString;
const largestAccountsFilterToString = rpc_types.largestAccountsFilterToString;
const tokenAccountsFilterParams = rpc_types.tokenAccountsFilterParams;

fn cloneTokenAmount(self: anytype, source: RpcTokenAmountResult) !TokenAmount {
    return TokenAmount{
        .amount = try self.allocator.dupe(u8, source.amount),
        .decimals = source.decimals,
        .ui_amount = source.uiAmount,
        .ui_amount_string = try self.allocator.dupe(u8, source.uiAmountString),
    };
}

pub fn getBalanceResponse(self: anytype, account: []const u8, commitment: ?Commitment) !BalanceResponse {
    const BalanceResult = struct {
        context: struct {
            slot: u64 = 0,
        } = .{ .slot = 0 },
        value: u64 = 0,
    };

    const params = .{
        account,
        commitmentParams(self.resolveCommitment(commitment)),
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBalance", params_json);
    defer self.allocator.free(response);

    const result = try self.parseResponse(response, BalanceResult);
    return BalanceResponse{
        .context_slot = result.context.slot,
        .value = result.value,
    };
}

pub fn getBalance(self: anytype, account: []const u8, commitment: ?Commitment) !u64 {
    const result = try self.getBalanceResponse(account, commitment);
    return result.value;
}

pub fn serializeRequestAirdropParams(
    self: anytype,
    account: []const u8,
    lamports: u64,
    options: ?RequestAirdropOptions,
) ![]u8 {
    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const recent_blockhash = if (options) |value| value.recent_blockhash else null;

    if (resolved_commitment != null or recent_blockhash != null) {
        const params = .{
            account,
            lamports,
            .{
                .commitment = resolved_commitment,
                .recentBlockhash = recent_blockhash,
            },
        };
        return try self.serializeParams(params);
    }

    return try self.serializeParams(.{ account, lamports });
}

pub fn minimumBalanceForRentExemption(
    self: anytype,
    data_length: u64,
    commitment: ?Commitment,
) !u64 {
    const params = .{
        data_length,
        commitmentParams(self.resolveCommitment(commitment)),
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getMinimumBalanceForRentExemption", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn requestAirdropWithOptions(
    self: anytype,
    account: []const u8,
    lamports: u64,
    options: ?RequestAirdropOptions,
) ![]const u8 {
    const params_json = try self.serializeRequestAirdropParams(account, lamports, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("requestAirdrop", params_json);
    defer self.allocator.free(response);

    const signature = try self.parseResponse(response, []const u8);
    return try self.allocator.dupe(u8, signature);
}

pub fn requestAirdropWithConfig(
    self: anytype,
    account: []const u8,
    lamports: u64,
    options: ?RequestAirdropOptions,
) ![]const u8 {
    return try self.requestAirdropWithOptions(account, lamports, options);
}

pub fn requestAirdrop(self: anytype, account: []const u8, lamports: u64, commitment: ?Commitment) ![]const u8 {
    return try self.requestAirdropWithOptions(
        account,
        lamports,
        if (commitment) |value| RequestAirdropOptions{ .commitment = value } else null,
    );
}

pub fn requestAirdropWithBlockhash(
    self: anytype,
    account: []const u8,
    lamports: u64,
    recent_blockhash: []const u8,
) ![]const u8 {
    return try self.requestAirdropWithOptions(
        account,
        lamports,
        .{ .recent_blockhash = recent_blockhash },
    );
}

pub fn getSupply(self: anytype, commitment: ?Commitment) !Supply {
    return try self.getSupplyWithOptions(if (commitment) |value|
        SupplyQueryOptions{ .commitment = value }
    else
        null);
}

pub fn getSupplyWithOptions(self: anytype, options: ?SupplyQueryOptions) !Supply {
    const SupplyConfig = struct {
        commitment: ?[]const u8 = null,
        excludeNonCirculatingAccountsList: ?bool = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const exclude_non_circulating_accounts_list = if (options) |value| value.exclude_non_circulating_accounts_list else null;

    const params_json = if (resolved_commitment != null or exclude_non_circulating_accounts_list != null) blk: {
        const params = .{SupplyConfig{
            .commitment = resolved_commitment,
            .excludeNonCirculatingAccountsList = exclude_non_circulating_accounts_list,
        }};
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getSupply", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: struct {
                total: u64 = 0,
                circulating: u64 = 0,
                nonCirculating: u64 = 0,
                nonCirculatingAccounts: ?[][]const u8 = null,
            } = .{
                .total = 0,
                .circulating = 0,
                .nonCirculating = 0,
                .nonCirculatingAccounts = null,
            },
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return Supply{
        .total = result.value.total,
        .circulating = result.value.circulating,
        .non_circulating = result.value.nonCirculating,
        .non_circulating_accounts = if (result.value.nonCirculatingAccounts) |value| try self.cloneStringList(value) else null,
    };
}

pub fn getSupplyWithConfig(self: anytype, options: ?SupplyQueryOptions) !Supply {
    return try self.getSupplyWithOptions(options);
}

pub fn getLargestAccountsWithOptions(self: anytype, options: ?LargestAccountsQueryOptions) ![]LargestAccount {
    const LargestAccountsConfig = struct {
        commitment: ?[]const u8 = null,
        filter: ?[]const u8 = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const filter = if (options) |value|
        if (value.filter) |entry| largestAccountsFilterToString(entry) else null
    else
        null;

    const params_json = if (resolved_commitment != null or filter != null) blk: {
        const params = .{LargestAccountsConfig{
            .commitment = resolved_commitment,
            .filter = filter,
        }};
        break :blk try self.serializeParams(params);
    } else null;
    defer if (params_json) |value| self.allocator.free(value);

    const response = if (params_json) |value|
        try self.sendRequest("getLargestAccounts", value)
    else
        try self.sendRequest("getLargestAccounts", "[]");
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const LargestAccountResult = struct {
        address: []const u8 = "",
        lamports: u64 = 0,
    };

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []LargestAccountResult = &.{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.allocator.alloc(LargestAccount, result.value.len);

    for (result.value, 0..) |entry, index| {
        copied[index] = LargestAccount{
            .address = try self.allocator.dupe(u8, entry.address),
            .lamports = entry.lamports,
        };
    }

    return copied;
}

pub fn getLargestAccountsWithConfig(self: anytype, options: ?LargestAccountsQueryOptions) ![]LargestAccount {
    return try self.getLargestAccountsWithOptions(options);
}

pub fn getLargestAccounts(self: anytype, commitment: ?Commitment) ![]LargestAccount {
    return try self.getLargestAccountsWithOptions(if (commitment) |value|
        LargestAccountsQueryOptions{ .commitment = value }
    else
        null);
}

pub fn getTokenAccountBalance(self: anytype, token_account: []const u8, commitment: ?Commitment) !TokenAmount {
    const response = try self.getTokenAccountBalanceResponse(token_account, commitment);
    return response.value;
}

pub fn getTokenAccountBalanceResponse(self: anytype, token_account: []const u8, commitment: ?Commitment) !TokenAmountResponse {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        const params = .{ token_account, .{ .commitment = commitmentToString(value) } };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{token_account});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getTokenAccountBalance", params_json);
    defer self.allocator.free(response);

    const RpcResult = struct {
        context: struct {
            slot: u64 = 0,
        } = .{ .slot = 0 },
        value: RpcTokenAmountResult = .{},
    };

    const result = try self.parseResponse(response, RpcResult);
    return TokenAmountResponse{
        .context_slot = result.context.slot,
        .value = try cloneTokenAmount(self, result.value),
    };
}

pub fn getTokenAccountMaybe(self: anytype, token_account: []const u8, commitment: ?Commitment) !?JsonParsedAccountInfo {
    return try self.getUiAccountMaybe(token_account, commitment);
}

pub fn getTokenAccountMaybeWithOptions(
    self: anytype,
    token_account: []const u8,
    options: ?UiAccountQueryOptions,
) !?JsonParsedAccountInfo {
    return try self.getUiAccountMaybeWithOptions(token_account, options);
}

pub fn getTokenAccountWithOptions(
    self: anytype,
    token_account: []const u8,
    options: ?UiAccountQueryOptions,
) !JsonParsedAccountInfo {
    return (try self.getTokenAccountMaybeWithOptions(token_account, options)) orelse error.AccountNotFound;
}

pub fn getTokenAccountWithConfig(
    self: anytype,
    token_account: []const u8,
    options: ?UiAccountQueryOptions,
) !JsonParsedAccountInfo {
    return try self.getTokenAccountWithOptions(token_account, options);
}

pub fn getTokenAccountMaybeWithConfig(
    self: anytype,
    token_account: []const u8,
    options: ?UiAccountQueryOptions,
) !?JsonParsedAccountInfo {
    return try self.getTokenAccountMaybeWithOptions(token_account, options);
}

pub fn getTokenAccount(self: anytype, token_account: []const u8, commitment: ?Commitment) !JsonParsedAccountInfo {
    return (try self.getTokenAccountMaybe(token_account, commitment)) orelse error.AccountNotFound;
}

pub fn getTokenSupply(self: anytype, mint: []const u8, commitment: ?Commitment) !TokenAmount {
    const response = try self.getTokenSupplyResponse(mint, commitment);
    return response.value;
}

pub fn getTokenSupplyResponse(self: anytype, mint: []const u8, commitment: ?Commitment) !TokenAmountResponse {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        const params = .{ mint, .{ .commitment = commitmentToString(value) } };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{mint});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getTokenSupply", params_json);
    defer self.allocator.free(response);

    const RpcResult = struct {
        context: struct {
            slot: u64 = 0,
        } = .{ .slot = 0 },
        value: RpcTokenAmountResult = .{},
    };

    const result = try self.parseResponse(response, RpcResult);
    return TokenAmountResponse{
        .context_slot = result.context.slot,
        .value = try cloneTokenAmount(self, result.value),
    };
}

pub fn getTokenLargestAccounts(self: anytype, mint: []const u8, commitment: ?Commitment) ![]TokenLargestAccount {
    const response = try self.getTokenLargestAccountsResponse(mint, commitment);
    return response.value;
}

pub fn getTokenLargestAccountsResponse(
    self: anytype,
    mint: []const u8,
    commitment: ?Commitment,
) !TokenLargestAccountsResponse {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        const params = .{ mint, .{ .commitment = commitmentToString(value) } };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{mint});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getTokenLargestAccounts", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const TokenLargestAccountResult = struct {
        address: []const u8 = "",
        amount: []const u8 = "",
        decimals: u8 = 0,
        uiAmount: ?f64 = null,
        uiAmountString: []const u8 = "",
    };

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []TokenLargestAccountResult = &.{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.allocator.alloc(TokenLargestAccount, result.value.len);

    for (result.value, 0..) |entry, index| {
        copied[index] = TokenLargestAccount{
            .address = try self.allocator.dupe(u8, entry.address),
            .amount = try cloneTokenAmount(self, .{
                .amount = entry.amount,
                .decimals = entry.decimals,
                .uiAmount = entry.uiAmount,
                .uiAmountString = entry.uiAmountString,
            }),
        };
    }

    return TokenLargestAccountsResponse{
        .context_slot = result.context.slot,
        .value = copied,
    };
}

fn getTokenAccounts(
    self: anytype,
    method: []const u8,
    authority: []const u8,
    filter: TokenAccountsFilter,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    const TokenAccountsConfig = struct {
        commitment: ?[]const u8 = null,
        encoding: []const u8 = "jsonParsed",
    };

    const params = .{
        authority,
        tokenAccountsFilterParams(filter),
        TokenAccountsConfig{
            .commitment = self.resolveCommitmentString(commitment),
        },
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest(method, params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []RpcJsonParsedProgramAccountResult = &.{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return try self.cloneJsonParsedProgramAccounts(result.value);
}

pub fn getTokenAccountsByOwner(
    self: anytype,
    owner: []const u8,
    filter: TokenAccountsFilter,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    return try getTokenAccounts(self, "getTokenAccountsByOwner", owner, filter, commitment);
}

pub fn getTokenAccountsByDelegate(
    self: anytype,
    delegate: []const u8,
    filter: TokenAccountsFilter,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    return try getTokenAccounts(self, "getTokenAccountsByDelegate", delegate, filter, commitment);
}
