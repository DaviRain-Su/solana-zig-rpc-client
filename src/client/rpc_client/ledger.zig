const std = @import("std");
const json = std.json;
const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const BlockQueryOptions = rpc_types.BlockQueryOptions;
const BlockSummary = rpc_types.BlockSummary;
const Commitment = rpc_types.Commitment;
const FeeForMessage = rpc_types.FeeForMessage;
const FeeForMessageResponse = rpc_types.FeeForMessageResponse;
const TransactionQueryOptions = rpc_types.TransactionQueryOptions;
const TransactionSummary = rpc_types.TransactionSummary;
const VersionedMessageV0 = sdk.VersionedMessageV0;
const LegacyMessage = sdk.LegacyMessage;
const commitmentParams = rpc_types.commitmentParams;
const commitmentToString = rpc_types.commitmentToString;
const transactionDetailsToString = rpc_types.transactionDetailsToString;
const transactionEncodingToString = rpc_types.transactionEncodingToString;

fn parseJsonValueResponse(self: anytype, response: []const u8) !?[]const u8 {
    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?json.Value = null,
    };

    try self.captureRpcError(response);

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const source = parsed.value.result orelse return null;
    return try json.Stringify.valueAlloc(self.allocator, source, .{});
}

fn cloneJsonValueText(self: anytype, value: json.Value) ![]const u8 {
    return switch (value) {
        .string => |text| try self.allocator.dupe(u8, text),
        else => try json.Stringify.valueAlloc(self.allocator, value, .{}),
    };
}

pub fn parseGetBlockResponse(self: anytype, response: []const u8) !?[]const u8 {
    return try parseJsonValueResponse(self, response);
}

pub fn parseGetTransactionResponse(self: anytype, response: []const u8) !?[]const u8 {
    return try parseJsonValueResponse(self, response);
}

pub fn getBlockWithOptions(self: anytype, slot: u64, options: ?BlockQueryOptions) !?[]const u8 {
    const BlockConfig = struct {
        commitment: ?[]const u8 = null,
        encoding: ?[]const u8 = null,
        transactionDetails: ?[]const u8 = null,
        rewards: ?bool = null,
        maxSupportedTransactionVersion: ?u8 = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const encoding = if (options) |value|
        if (value.encoding) |entry| transactionEncodingToString(entry) else null
    else
        null;
    const transaction_details = if (options) |value|
        if (value.transaction_details) |entry| transactionDetailsToString(entry) else null
    else
        null;
    const rewards = if (options) |value| value.rewards else null;
    const max_supported_transaction_version = if (options) |value| value.max_supported_transaction_version else null;

    const params_json = if (resolved_commitment != null or encoding != null or transaction_details != null or rewards != null or max_supported_transaction_version != null) blk: {
        const params = .{
            slot,
            BlockConfig{
                .commitment = resolved_commitment,
                .encoding = encoding,
                .transactionDetails = transaction_details,
                .rewards = rewards,
                .maxSupportedTransactionVersion = max_supported_transaction_version,
            },
        };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{slot});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBlock", params_json);
    defer self.allocator.free(response);

    return try parseGetBlockResponse(self, response);
}

pub fn getBlockWithConfig(self: anytype, slot: u64, options: ?BlockQueryOptions) !?[]const u8 {
    return try self.getBlockWithOptions(slot, options);
}

pub fn getBlockWithEncoding(
    self: anytype,
    slot: u64,
    encoding: rpc_types.TransactionEncoding,
) !?[]const u8 {
    return try self.getBlockWithOptions(
        slot,
        BlockQueryOptions{
            .encoding = encoding,
        },
    );
}

pub fn getBlock(self: anytype, slot: u64, commitment: ?Commitment) !?[]const u8 {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        break :blk try self.serializeParams(.{ slot, .{ .commitment = commitmentToString(value) } });
    } else blk: {
        break :blk try self.serializeParams(.{slot});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBlock", params_json);
    defer self.allocator.free(response);

    return try parseGetBlockResponse(self, response);
}

pub fn summarizeBlockJson(self: anytype, block_json: []const u8) !BlockSummary {
    const ParsedBlock = struct {
        blockhash: ?[]const u8 = null,
        previousBlockhash: ?[]const u8 = null,
        parentSlot: u64 = 0,
        blockHeight: ?u64 = null,
        blockTime: ?i64 = null,
        transactions: ?[]json.Value = null,
        rewards: ?[]json.Value = null,
    };

    const parsed = try json.parseFromSlice(ParsedBlock, self.allocator, block_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    return BlockSummary{
        .blockhash = if (parsed.value.blockhash) |value| try self.allocator.dupe(u8, value) else null,
        .previous_blockhash = if (parsed.value.previousBlockhash) |value| try self.allocator.dupe(u8, value) else null,
        .parent_slot = parsed.value.parentSlot,
        .block_height = parsed.value.blockHeight,
        .block_time = parsed.value.blockTime,
        .transaction_count = if (parsed.value.transactions) |value| value.len else null,
        .rewards_count = if (parsed.value.rewards) |value| value.len else null,
    };
}

pub fn freeOwnedBlockSummary(self: anytype, summary: BlockSummary) void {
    if (summary.blockhash) |value| self.allocator.free(value);
    if (summary.previous_blockhash) |value| self.allocator.free(value);
}

pub fn getBlockSummaryWithOptions(self: anytype, slot: u64, options: ?BlockQueryOptions) !?BlockSummary {
    const block_json = try self.getBlockWithOptions(slot, options);
    defer if (block_json) |value| self.allocator.free(value);

    if (block_json) |value| {
        return try self.summarizeBlockJson(value);
    }

    return null;
}

pub fn getBlockSummaryWithConfig(self: anytype, slot: u64, options: ?BlockQueryOptions) !?BlockSummary {
    return try self.getBlockSummaryWithOptions(slot, options);
}

pub fn getBlockSummary(self: anytype, slot: u64, commitment: ?Commitment) !?BlockSummary {
    return try self.getBlockSummaryWithOptions(
        slot,
        if (commitment) |value|
            BlockQueryOptions{ .commitment = value }
        else
            null,
    );
}

pub fn getTransaction(self: anytype, signature: []const u8, options: ?TransactionQueryOptions) !?[]const u8 {
    const TransactionConfig = struct {
        commitment: ?[]const u8 = null,
        encoding: ?[]const u8 = null,
        maxSupportedTransactionVersion: ?u8 = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const encoding = if (options) |value|
        if (value.encoding) |entry| transactionEncodingToString(entry) else null
    else
        null;
    const max_supported_transaction_version = if (options) |value| value.max_supported_transaction_version else null;

    const params_json = if (resolved_commitment != null or encoding != null or max_supported_transaction_version != null) blk: {
        const params = .{
            signature,
            TransactionConfig{
                .commitment = resolved_commitment,
                .encoding = encoding,
                .maxSupportedTransactionVersion = max_supported_transaction_version,
            },
        };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{signature});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getTransaction", params_json);
    defer self.allocator.free(response);

    return try parseGetTransactionResponse(self, response);
}

pub fn getTransactionWithConfig(self: anytype, signature: []const u8, options: ?TransactionQueryOptions) !?[]const u8 {
    return try self.getTransaction(signature, options);
}

pub fn summarizeTransactionJson(self: anytype, transaction_json: []const u8) !TransactionSummary {
    const ParsedTransaction = struct {
        slot: u64 = 0,
        blockTime: ?i64 = null,
        version: ?json.Value = null,
        meta: ?struct {
            err: ?json.Value = null,
            fee: ?u64 = null,
            logMessages: ?[]json.Value = null,
        } = null,
        transaction: ?json.Value = null,
    };

    const parsed = try json.parseFromSlice(ParsedTransaction, self.allocator, transaction_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var signature_count: ?usize = null;
    if (parsed.value.transaction) |transaction_value| {
        if (transaction_value == .object) {
            if (transaction_value.object.get("signatures")) |signatures_value| {
                if (signatures_value == .array) {
                    signature_count = signatures_value.array.items.len;
                }
            }
        }
    }

    var error_json: ?[]const u8 = null;
    var has_error = false;
    if (parsed.value.meta) |meta| {
        if (meta.err) |err_value| {
            if (err_value != .null) {
                has_error = true;
                error_json = try cloneJsonValueText(self, err_value);
            }
        }
    }

    return TransactionSummary{
        .slot = parsed.value.slot,
        .block_time = parsed.value.blockTime,
        .version = if (parsed.value.version) |value| try cloneJsonValueText(self, value) else null,
        .signature_count = signature_count,
        .fee = if (parsed.value.meta) |meta| meta.fee else null,
        .log_messages_count = if (parsed.value.meta) |meta|
            if (meta.logMessages) |logs| logs.len else null
        else
            null,
        .has_error = has_error,
        .error_json = error_json,
    };
}

pub fn freeOwnedTransactionSummary(self: anytype, summary: TransactionSummary) void {
    if (summary.version) |value| self.allocator.free(value);
    if (summary.error_json) |value| self.allocator.free(value);
}

pub fn getTransactionSummaryWithOptions(self: anytype, signature: []const u8, options: ?TransactionQueryOptions) !?TransactionSummary {
    const transaction_json = try self.getTransaction(signature, options);
    defer if (transaction_json) |value| self.allocator.free(value);

    if (transaction_json) |value| {
        return try self.summarizeTransactionJson(value);
    }

    return null;
}

pub fn getTransactionSummaryWithConfig(
    self: anytype,
    signature: []const u8,
    options: ?TransactionQueryOptions,
) !?TransactionSummary {
    return try self.getTransactionSummaryWithOptions(signature, options);
}

pub fn getTransactionSummary(self: anytype, signature: []const u8, commitment: ?Commitment) !?TransactionSummary {
    return try self.getTransactionSummaryWithOptions(
        signature,
        if (commitment) |value|
            TransactionQueryOptions{ .commitment = value }
        else
            null,
    );
}

pub fn getFeeForMessageResponse(self: anytype, encoded_message: []const u8, commitment: ?Commitment) !FeeForMessageResponse {
    const params = .{
        encoded_message,
        commitmentParams(self.resolveCommitment(commitment)),
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getFeeForMessage", params_json);
    defer self.allocator.free(response);

    const FeeResult = struct {
        context: struct {
            slot: u64 = 0,
        } = .{ .slot = 0 },
        value: ?u64 = null,
    };

    const result = try self.parseResponse(response, FeeResult);
    return FeeForMessageResponse{
        .context_slot = result.context.slot,
        .value = result.value,
    };
}

pub fn getFeeForMessage(self: anytype, encoded_message: []const u8, commitment: ?Commitment) !FeeForMessage {
    const response = try self.getFeeForMessageResponse(encoded_message, commitment);
    return FeeForMessage{ .value = response.value };
}

pub fn getFeeForMessageTyped(self: anytype, message: LegacyMessage, commitment: ?Commitment) !FeeForMessage {
    const encoded_message = try message.toBase64(self.allocator);
    defer self.allocator.free(encoded_message);
    return try self.getFeeForMessage(encoded_message, commitment);
}

pub fn getFeeForVersionedMessageTyped(self: anytype, message: VersionedMessageV0, commitment: ?Commitment) !FeeForMessage {
    const encoded_message = try message.toBase64(self.allocator);
    defer self.allocator.free(encoded_message);
    return try self.getFeeForMessage(encoded_message, commitment);
}

pub fn getFeeForVersionedMessageResponseTyped(self: anytype, message: VersionedMessageV0, commitment: ?Commitment) !FeeForMessageResponse {
    const encoded_message = try message.toBase64(self.allocator);
    defer self.allocator.free(encoded_message);
    return try self.getFeeForMessageResponse(encoded_message, commitment);
}

pub fn getFeeForMessageResponseTyped(self: anytype, message: LegacyMessage, commitment: ?Commitment) !FeeForMessageResponse {
    const encoded_message = try message.toBase64(self.allocator);
    defer self.allocator.free(encoded_message);
    return try self.getFeeForMessageResponse(encoded_message, commitment);
}
