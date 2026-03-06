const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const AccountInfo = rpc_types.AccountInfo;
const AccountInfoResponse = rpc_types.AccountInfoResponse;
const AccountQueryOptions = rpc_types.AccountQueryOptions;
const Commitment = rpc_types.Commitment;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const MultipleAccountsResponse = rpc_types.MultipleAccountsResponse;
const MultipleUiAccountsResponse = rpc_types.MultipleUiAccountsResponse;
const RpcAccountInfoResult = rpc_types.RpcAccountInfoResult;
const RpcJsonParsedAccountInfoResult = rpc_types.RpcJsonParsedAccountInfoResult;
const UiAccountQueryOptions = rpc_types.UiAccountQueryOptions;
const UiAccountResponse = rpc_types.UiAccountResponse;
const accountEncodingToString = rpc_types.accountEncodingToString;
const commitmentToString = rpc_types.commitmentToString;

pub fn serializeAccountParams(self: anytype, account: []const u8, options: ?AccountQueryOptions) ![]u8 {
    const DataSlice = struct {
        offset: u64,
        length: u64,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const min_context_slot = if (options) |value| value.min_context_slot else null;
    const encoding = if (options) |value|
        if (value.encoding) |entry| accountEncodingToString(entry) else null
    else
        null;
    const has_data_slice = if (options) |value|
        value.data_slice_offset != null and value.data_slice_length != null
    else
        false;

    if (resolved_commitment == null and min_context_slot == null and encoding == null and !has_data_slice) {
        return try self.serializeParams(.{account});
    }

    const params = .{
        account,
        .{
            .commitment = resolved_commitment,
            .minContextSlot = min_context_slot,
            .encoding = encoding,
            .dataSlice = if (has_data_slice)
                DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                }
            else
                null,
        },
    };
    return try self.serializeParams(params);
}

pub fn serializeMultipleAccountsParams(self: anytype, accounts: []const []const u8, options: ?AccountQueryOptions) ![]u8 {
    const DataSlice = struct {
        offset: u64,
        length: u64,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const min_context_slot = if (options) |value| value.min_context_slot else null;
    const encoding = if (options) |value|
        if (value.encoding) |entry| accountEncodingToString(entry) else null
    else
        null;
    const has_data_slice = if (options) |value|
        value.data_slice_offset != null and value.data_slice_length != null
    else
        false;

    if (resolved_commitment == null and min_context_slot == null and encoding == null and !has_data_slice) {
        return try self.serializeParams(.{accounts});
    }

    const params = .{
        accounts,
        .{
            .commitment = resolved_commitment,
            .minContextSlot = min_context_slot,
            .encoding = encoding,
            .dataSlice = if (has_data_slice)
                DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                }
            else
                null,
        },
    };
    return try self.serializeParams(params);
}

pub fn serializeUiAccountParams(self: anytype, account: []const u8, options: ?UiAccountQueryOptions) ![]u8 {
    const params = .{
        account,
        .{
            .commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null),
            .minContextSlot = if (options) |value| value.min_context_slot else null,
            .encoding = "jsonParsed",
        },
    };
    return try self.serializeParams(params);
}

pub fn serializeMultipleUiAccountsParams(self: anytype, accounts: []const []const u8, options: ?UiAccountQueryOptions) ![]u8 {
    const params = .{
        accounts,
        .{
            .commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null),
            .minContextSlot = if (options) |value| value.min_context_slot else null,
            .encoding = "jsonParsed",
        },
    };
    return try self.serializeParams(params);
}

pub fn getAccountInfoResponseWithOptions(self: anytype, account: []const u8, options: ?AccountQueryOptions) !AccountInfoResponse {
    const params_json = try self.serializeAccountParams(account, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getAccountInfo", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: ?RpcAccountInfoResult = null,
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return AccountInfoResponse{
        .context_slot = result.context.slot,
        .account = if (result.value) |source| try self.cloneAccountInfo(source) else null,
    };
}

pub fn getAccountInfoResponseWithConfig(
    self: anytype,
    account: []const u8,
    options: ?AccountQueryOptions,
) !AccountInfoResponse {
    return try self.getAccountInfoResponseWithOptions(account, options);
}

pub fn getAccountInfoMaybeWithOptions(self: anytype, account: []const u8, options: ?AccountQueryOptions) !?AccountInfo {
    const response = try self.getAccountInfoResponseWithOptions(account, options);
    return response.account;
}

pub fn getAccountInfoMaybeWithConfig(
    self: anytype,
    account: []const u8,
    options: ?AccountQueryOptions,
) !?AccountInfo {
    return try self.getAccountInfoMaybeWithOptions(account, options);
}

pub fn getAccountInfoWithOptions(self: anytype, account: []const u8, options: ?AccountQueryOptions) !AccountInfo {
    return (try self.getAccountInfoMaybeWithOptions(account, options)) orelse error.AccountNotFound;
}

pub fn getAccountInfoWithConfig(
    self: anytype,
    account: []const u8,
    options: ?AccountQueryOptions,
) !AccountInfo {
    return try self.getAccountInfoWithOptions(account, options);
}

pub fn getAccountInfoResponse(self: anytype, account: []const u8, commitment: ?Commitment) !AccountInfoResponse {
    return try self.getAccountInfoResponseWithOptions(
        account,
        if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getAccountInfoMaybe(self: anytype, account: []const u8, commitment: ?Commitment) !?AccountInfo {
    return try self.getAccountInfoMaybeWithOptions(
        account,
        if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getAccount(self: anytype, account: []const u8) !?AccountInfo {
    return try self.getAccountInfoMaybe(account, null);
}

pub fn getAccountWithCommitment(
    self: anytype,
    account: []const u8,
    commitment: Commitment,
) !?AccountInfo {
    return try self.getAccountInfoMaybe(account, commitment);
}

pub fn getAccountWithConfig(
    self: anytype,
    account: []const u8,
    options: ?AccountQueryOptions,
) !?AccountInfo {
    return try self.getAccountInfoMaybeWithOptions(account, options);
}

pub fn getAccountInfo(self: anytype, account: []const u8, commitment: ?Commitment) !AccountInfo {
    return (try self.getAccountInfoMaybe(account, commitment)) orelse error.AccountNotFound;
}

pub fn getAccountDataWithOptions(self: anytype, account: []const u8, options: ?AccountQueryOptions) ![]const u8 {
    const info = try self.getAccountInfoWithOptions(account, .{
        .commitment = if (options) |value| value.commitment else null,
        .min_context_slot = if (options) |value| value.min_context_slot else null,
        .encoding = .base64,
        .data_slice_offset = if (options) |value| value.data_slice_offset else null,
        .data_slice_length = if (options) |value| value.data_slice_length else null,
    });
    errdefer self.freeOwnedAccountInfo(info);

    const encoded_data = info.data orelse return error.AccountDataUnavailable;
    const data_encoding = info.data_encoding orelse return error.AccountDataUnavailable;
    if (!std.mem.eql(u8, data_encoding, "base64")) return error.AccountDataUnavailable;

    const decoded_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded_data);
    const decoded = try self.allocator.alloc(u8, decoded_len);
    errdefer self.allocator.free(decoded);
    try std.base64.standard.Decoder.decode(decoded, encoded_data);

    self.freeOwnedAccountInfo(info);
    return decoded;
}

pub fn getAccountDataWithConfig(
    self: anytype,
    account: []const u8,
    options: ?AccountQueryOptions,
) ![]const u8 {
    return try self.getAccountDataWithOptions(account, options);
}

pub fn getAccountData(self: anytype, account: []const u8, commitment: ?Commitment) ![]const u8 {
    return try self.getAccountDataWithOptions(
        account,
        if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getUiAccountResponseWithOptions(self: anytype, account: []const u8, options: ?UiAccountQueryOptions) !UiAccountResponse {
    const params_json = try self.serializeUiAccountParams(account, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getAccountInfo", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: ?RpcJsonParsedAccountInfoResult = null,
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return UiAccountResponse{
        .context_slot = result.context.slot,
        .account = if (result.value) |source| try self.cloneJsonParsedAccountInfo(source) else null,
    };
}

pub fn getUiAccountResponseWithConfig(
    self: anytype,
    account: []const u8,
    options: ?UiAccountQueryOptions,
) !UiAccountResponse {
    return try self.getUiAccountResponseWithOptions(account, options);
}

pub fn getUiAccountMaybeWithOptions(self: anytype, account: []const u8, options: ?UiAccountQueryOptions) !?JsonParsedAccountInfo {
    const response = try self.getUiAccountResponseWithOptions(account, options);
    return response.account;
}

pub fn getUiAccountMaybeWithConfig(
    self: anytype,
    account: []const u8,
    options: ?UiAccountQueryOptions,
) !?JsonParsedAccountInfo {
    return try self.getUiAccountMaybeWithOptions(account, options);
}

pub fn getUiAccountWithOptions(self: anytype, account: []const u8, options: ?UiAccountQueryOptions) !JsonParsedAccountInfo {
    return (try self.getUiAccountMaybeWithOptions(account, options)) orelse error.AccountNotFound;
}

pub fn getUiAccountWithConfig(self: anytype, account: []const u8, options: ?UiAccountQueryOptions) !JsonParsedAccountInfo {
    return try self.getUiAccountWithOptions(account, options);
}

pub fn getUiAccountResponse(self: anytype, account: []const u8, commitment: ?Commitment) !UiAccountResponse {
    return try self.getUiAccountResponseWithOptions(
        account,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getUiAccountMaybe(self: anytype, account: []const u8, commitment: ?Commitment) !?JsonParsedAccountInfo {
    return try self.getUiAccountMaybeWithOptions(
        account,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getUiAccount(self: anytype, account: []const u8, commitment: ?Commitment) !JsonParsedAccountInfo {
    return (try self.getUiAccountMaybe(account, commitment)) orelse error.AccountNotFound;
}

pub fn getMultipleAccountsResponseWithOptions(self: anytype, accounts: []const []const u8, options: ?AccountQueryOptions) !MultipleAccountsResponse {
    const params_json = try self.serializeMultipleAccountsParams(accounts, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getMultipleAccounts", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []?RpcAccountInfoResult = &.{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return MultipleAccountsResponse{
        .context_slot = result.context.slot,
        .accounts = try self.cloneOptionalAccountInfos(result.value),
    };
}

pub fn getMultipleAccountsResponseWithConfig(
    self: anytype,
    accounts: []const []const u8,
    options: ?AccountQueryOptions,
) !MultipleAccountsResponse {
    return try self.getMultipleAccountsResponseWithOptions(accounts, options);
}

pub fn getMultipleAccountsWithOptions(self: anytype, accounts: []const []const u8, options: ?AccountQueryOptions) ![]?AccountInfo {
    const response = try self.getMultipleAccountsResponseWithOptions(accounts, options);
    return response.accounts;
}

pub fn getMultipleAccountsWithConfig(
    self: anytype,
    accounts: []const []const u8,
    options: ?AccountQueryOptions,
) ![]?AccountInfo {
    return try self.getMultipleAccountsWithOptions(accounts, options);
}

pub fn getMultipleAccounts(self: anytype, accounts: []const []const u8, commitment: ?Commitment) ![]?AccountInfo {
    return try self.getMultipleAccountsWithOptions(
        accounts,
        if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getMultipleAccountsResponse(self: anytype, accounts: []const []const u8, commitment: ?Commitment) !MultipleAccountsResponse {
    return try self.getMultipleAccountsResponseWithOptions(
        accounts,
        if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getMultipleUiAccountsResponseWithOptions(self: anytype, accounts: []const []const u8, options: ?UiAccountQueryOptions) !MultipleUiAccountsResponse {
    const params_json = try self.serializeMultipleUiAccountsParams(accounts, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getMultipleAccounts", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []?RpcJsonParsedAccountInfoResult = &.{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    return MultipleUiAccountsResponse{
        .context_slot = result.context.slot,
        .accounts = try self.cloneOptionalJsonParsedAccountInfos(result.value),
    };
}

pub fn getMultipleUiAccountsResponseWithConfig(
    self: anytype,
    accounts: []const []const u8,
    options: ?UiAccountQueryOptions,
) !MultipleUiAccountsResponse {
    return try self.getMultipleUiAccountsResponseWithOptions(accounts, options);
}

pub fn getMultipleUiAccountsWithOptions(self: anytype, accounts: []const []const u8, options: ?UiAccountQueryOptions) ![]?JsonParsedAccountInfo {
    const response = try self.getMultipleUiAccountsResponseWithOptions(accounts, options);
    return response.accounts;
}

pub fn getMultipleUiAccountsWithConfig(
    self: anytype,
    accounts: []const []const u8,
    options: ?UiAccountQueryOptions,
) ![]?JsonParsedAccountInfo {
    return try self.getMultipleUiAccountsWithOptions(accounts, options);
}

pub fn getMultipleUiAccounts(self: anytype, accounts: []const []const u8, commitment: ?Commitment) ![]?JsonParsedAccountInfo {
    return try self.getMultipleUiAccountsWithOptions(
        accounts,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}

pub fn getMultipleUiAccountsResponse(self: anytype, accounts: []const []const u8, commitment: ?Commitment) !MultipleUiAccountsResponse {
    return try self.getMultipleUiAccountsResponseWithOptions(
        accounts,
        if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
    );
}
