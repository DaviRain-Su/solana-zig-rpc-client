const std = @import("std");
const json = std.json;

const Allocator = std.mem.Allocator;

pub const RpcError = error{
    HttpError,
    RpcError,
    InvalidResponse,
    Timeout,
    TransactionFailed,
    TransactionNotConfirmed,
    TransactionNotFound,
};

pub const Commitment = enum {
    processed,
    confirmed,
    finalized,
};

pub const RpcErrorDetail = struct {
    code: i64 = 0,
    message: []const u8 = "",
};

pub const LatestBlockhash = struct {
    blockhash: []const u8,
    last_valid_block_height: u64,
};

pub const SignatureStatus = struct {
    confirmation_status: ?[]const u8 = null,
    has_error: bool = false,
    slot: ?u64 = null,
    confirmations: ?u64 = null,
};

pub const AccountInfo = struct {
    lamports: u64 = 0,
    owner: []const u8 = "",
    executable: bool = false,
    rent_epoch: ?u64 = null,
    data: ?[]const u8 = null,
    data_encoding: ?[]const u8 = null,
};

pub const SignatureForAddress = struct {
    signature: []const u8 = "",
    slot: u64 = 0,
    block_time: ?i64 = null,
    confirmation_status: ?[]const u8 = null,
    memo: ?[]const u8 = null,
    has_error: bool = false,
};

pub const EpochInfo = struct {
    absolute_slot: ?u64 = null,
    block_height: ?u64 = null,
    epoch: ?u64 = null,
    slot_index: ?u64 = null,
    slots_in_epoch: ?u64 = null,
};

pub const Supply = struct {
    total: u64 = 0,
    circulating: u64 = 0,
    non_circulating: u64 = 0,
};

pub const FeeForMessage = struct {
    value: ?u64 = null,
};

pub const EpochSchedule = struct {
    first_normal_slot: u64 = 0,
    first_normal_epoch: u64 = 0,
    leader_schedule_slot_offset: u64 = 0,
    slots_per_epoch: u64 = 0,
    warmup: bool = false,
};

pub const InflationRate = struct {
    total: f64 = 0,
    validator: f64 = 0,
    foundation: f64 = 0,
    epoch: u64 = 0,
};

pub const PerformanceSample = struct {
    slot: u64 = 0,
    num_slots: u64 = 0,
    num_transactions: u64 = 0,
    sample_period_secs: u64 = 0,
    num_non_vote_slots: u64 = 0,
};

pub const SnapshotSlots = struct {
    full: ?u64 = null,
    incremental: ?u64 = null,
};

pub const RecentPrioritizationFee = struct {
    slot: u64 = 0,
    prioritization_fee: u64 = 0,
};

pub const InflationGovernor = struct {
    foundation: f64 = 0,
    foundation_term: f64 = 0,
    initial: f64 = 0,
    taper: f64 = 0,
    terminal: f64 = 0,
};

const VoteAccountResult = struct {
    votePubkey: []const u8 = "",
    nodePubkey: []const u8 = "",
    activatedStake: u64 = 0,
    commission: u64 = 0,
    epochCredits: ?[][]i64 = null,
    lastVote: ?u64 = null,
    epochVoteAccount: bool = false,
    rootSlot: ?u64 = null,
};

pub const ClusterNode = struct {
    feature_set: u64 = 0,
    gossip: ?[]const u8 = null,
    pubkey: []const u8 = "",
    rpc: ?[]const u8 = null,
    shred_version: u64 = 0,
    tpu: ?[]const u8 = null,
    version: ?[]const u8 = null,
};

pub const LeaderSchedule = struct {
    identity: []const u8 = "",
    slots: []u64 = &.{},
};

pub const EpochCredit = struct {
    epoch: u64 = 0,
    prev_credits: u64 = 0,
    curr_credits: u64 = 0,
};

pub const VoteAccount = struct {
    vote_pubkey: []const u8 = "",
    node_pubkey: []const u8 = "",
    activated_stake: u64 = 0,
    commission: u64 = 0,
    epoch_credits: ?[]EpochCredit = null,
    last_vote: ?u64 = null,
    root_slot: ?u64 = null,
    epoch_vote_account: bool = false,
};

pub const VoteAccounts = struct {
    current: []VoteAccount = &.{},
    delinquent: []VoteAccount = &.{},
};

pub const BlockProduction = struct {
    first_slot: u64 = 0,
    last_slot: u64 = 0,
    by_identity: []BlockProductionIdentity = &.{},
};

pub const BlockProductionIdentity = struct {
    identity: []const u8 = "",
    leader_slots: u64 = 0,
    blocks: u64 = 0,
};

pub const SendTransactionOptions = struct {
    skip_preflight: bool = false,
    preflight_commitment: ?Commitment = null,
    max_retries: ?u32 = null,
};

fn commitmentParams(commitment: ?Commitment) struct { commitment: ?[]const u8 = null } {
    return .{ .commitment = if (commitment) |value| commitmentToString(value) else null };
}

fn commitmentToString(c: Commitment) []const u8 {
    return switch (c) {
        .processed => "processed",
        .confirmed => "confirmed",
        .finalized => "finalized",
    };
}

pub const RpcClient = struct {
    allocator: Allocator,
    endpoint: []const u8,
    http_client: std.http.Client,
    request_id: u64,
    last_error: ?RpcErrorDetail,

    pub fn init(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return RpcClient{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .http_client = .{ .allocator = allocator },
            .request_id = 1,
            .last_error = null,
        };
    }

    pub fn deinit(self: *RpcClient) void {
        self.clearLastError();
        self.http_client.deinit();
        self.allocator.free(self.endpoint);
    }

    pub fn getLastError(self: *RpcClient) ?RpcErrorDetail {
        return self.last_error;
    }

    fn clearLastError(self: *RpcClient) void {
        if (self.last_error) |last| {
            self.allocator.free(last.message);
            self.last_error = null;
        }
    }

    fn serializeParams(self: *RpcClient, value: anytype) ![]u8 {
        return try json.Stringify.valueAlloc(self.allocator, value, .{});
    }

    fn sendRequest(self: *RpcClient, method: []const u8, params_json: []const u8) ![]u8 {
        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"jsonrpc\":\"2.0\",\"id\":{},\"method\":\"{s}\",\"params\":{s}}}",
            .{ self.request_id, method, params_json },
        );
        errdefer self.allocator.free(request_body);
        self.request_id +%= 1;

        var response_writer = std.io.Writer.Allocating.init(self.allocator);
        errdefer response_writer.deinit();

        const headers = [_]std.http.Header{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "accept", .value = "application/json" },
        };

        const response = try self.http_client.fetch(.{
            .location = .{ .url = self.endpoint },
            .method = .POST,
            .payload = request_body,
            .extra_headers = &headers,
            .response_writer = &response_writer.writer,
        });

        self.allocator.free(request_body);

        if (response.status != .ok) {
            return switch (response.status) {
                .request_timeout => error.Timeout,
                else => error.HttpError,
            };
        }

        return try response_writer.toOwnedSlice();
    }

    fn sendNoParamsRequest(self: *RpcClient, method: []const u8) ![]u8 {
        return try self.sendRequest(method, "[]");
    }

    fn parseResponse(self: *RpcClient, body: []const u8, comptime ResultType: type) !ResultType {
        self.clearLastError();
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?ResultType = null,
            @"error": ?RpcErrorDetail = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error" != null) {
            const err = parsed.value.@"error".?;
            self.last_error = RpcErrorDetail{
                .code = err.code,
                .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
            };
            return error.RpcError;
        }

        return parsed.value.result orelse error.InvalidResponse;
    }

    fn captureRpcError(self: *RpcClient, body: []const u8) !void {
        self.clearLastError();

        const ParsedEnvelope = struct {
            @"error": ?RpcErrorDetail = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error") |err| {
            self.last_error = RpcErrorDetail{
                .code = err.code,
                .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
            };
            return error.RpcError;
        }
    }

    pub fn getLatestBlockhash(self: *RpcClient, commitment: ?Commitment) !LatestBlockhash {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getLatestBlockhash", params_json);
        defer self.allocator.free(response);

        const RpcResult = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: struct {
                blockhash: []const u8 = "",
                minContextSlot: ?u64 = null,
                lastValidBlockHeight: u64 = 0,
            } = .{
                .blockhash = "",
                .minContextSlot = null,
                .lastValidBlockHeight = 0,
            },
        };

        const result = try self.parseResponse(response, RpcResult);

        if (result.value.blockhash.len == 0) {
            return error.InvalidResponse;
        }

        return LatestBlockhash{
            .blockhash = try self.allocator.dupe(u8, result.value.blockhash),
            .last_valid_block_height = result.value.lastValidBlockHeight,
        };
    }

    pub fn getFeatureActivationSlot(self: *RpcClient, feature_pubkey: []const u8, commitment: ?Commitment) !?u64 {
        const params = .{
            feature_pubkey,
            .{ .commitment = if (commitment) |value| commitmentToString(value) else null },
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getFeatureActivationSlot", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, ?u64);
    }

    pub fn getSlot(self: *RpcClient, commitment: ?Commitment) !u64 {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSlot", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getBlockHeight(self: *RpcClient, commitment: ?Commitment) !u64 {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBlockHeight", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getTransactionCount(self: *RpcClient, commitment: ?Commitment) !u64 {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getTransactionCount", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getBalance(self: *RpcClient, account: []const u8, commitment: ?Commitment) !u64 {
        const BalanceResult = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: u64 = 0,
        };

        const params = .{
            account,
            commitmentParams(commitment),
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBalance", params_json);
        defer self.allocator.free(response);

        const result = try self.parseResponse(response, BalanceResult);
        return result.value;
    }

    pub fn getAccountInfo(self: *RpcClient, account: []const u8, commitment: ?Commitment) !AccountInfo {
        const params = .{
            account,
            commitmentParams(commitment),
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getAccountInfo", params_json);
        defer self.allocator.free(response);

        const RpcResult = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: ?struct {
                data: ?[]const []const u8 = null,
                executable: bool = false,
                lamports: u64 = 0,
                owner: []const u8 = "",
                rentEpoch: ?u64 = null,
            } = null,
        };

        const result = try self.parseResponse(response, RpcResult);
        const source = result.value orelse return error.InvalidResponse;

        return AccountInfo{
            .lamports = source.lamports,
            .owner = try self.allocator.dupe(u8, source.owner),
            .executable = source.executable,
            .rent_epoch = source.rentEpoch,
            .data = if (source.data) |entry|
                if (entry.len >= 1) try self.allocator.dupe(u8, entry[0]) else null
            else
                null,
            .data_encoding = if (source.data) |entry|
                if (entry.len >= 2) try self.allocator.dupe(u8, entry[1]) else null
            else
                null,
        };
    }

    pub fn getGenesisHash(self: *RpcClient) ![]const u8 {
        const response = try self.sendNoParamsRequest("getGenesisHash");
        defer self.allocator.free(response);

        const hash = try self.parseResponse(response, []const u8);
        return try self.allocator.dupe(u8, hash);
    }

    pub fn getHealth(self: *RpcClient) ![]const u8 {
        const response = try self.sendNoParamsRequest("getHealth");
        defer self.allocator.free(response);

        const health = try self.parseResponse(response, []const u8);
        return try self.allocator.dupe(u8, health);
    }

    pub fn getFirstAvailableBlock(self: *RpcClient, commitment: ?Commitment) !u64 {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getFirstAvailableBlock", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getStakeMinimumDelegation(self: *RpcClient, commitment: ?Commitment) !u64 {
        const params = .{.{ .commitment = if (commitment) |value| commitmentToString(value) else null }};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getStakeMinimumDelegation", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getEpochInfo(self: *RpcClient, commitment: ?Commitment) !EpochInfo {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getEpochInfo", params_json);
        defer self.allocator.free(response);

        const EpochResponse = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: struct {
                absoluteSlot: ?u64 = null,
                blockHeight: ?u64 = null,
                epoch: ?u64 = null,
                slotIndex: ?u64 = null,
                slotsInEpoch: ?u64 = null,
            } = .{
                .absoluteSlot = null,
                .blockHeight = null,
                .epoch = null,
                .slotIndex = null,
                .slotsInEpoch = null,
            },
        };

        const result = try self.parseResponse(response, EpochResponse);

        return EpochInfo{
            .absolute_slot = result.value.absoluteSlot,
            .block_height = result.value.blockHeight,
            .epoch = result.value.epoch,
            .slot_index = result.value.slotIndex,
            .slots_in_epoch = result.value.slotsInEpoch,
        };
    }

    pub fn getVersion(self: *RpcClient) ![]const u8 {
        const response = try self.sendNoParamsRequest("getVersion");
        defer self.allocator.free(response);

        const VersionResult = struct {
            @"solana-core": []const u8 = "",
        };

        const result = try self.parseResponse(response, VersionResult);
        return try self.allocator.dupe(u8, result.@"solana-core");
    }

    pub fn minimumBalanceForRentExemption(
        self: *RpcClient,
        data_length: u64,
        commitment: ?Commitment,
    ) !u64 {
        const params = .{
            data_length,
            commitmentParams(commitment),
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getMinimumBalanceForRentExemption", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn requestAirdrop(self: *RpcClient, account: []const u8, lamports: u64, commitment: ?Commitment) ![]const u8 {
        const params = .{
            account,
            lamports,
            commitmentParams(commitment),
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("requestAirdrop", params_json);
        defer self.allocator.free(response);

        const signature = try self.parseResponse(response, []const u8);
        return try self.allocator.dupe(u8, signature);
    }

    pub fn getSupply(self: *RpcClient, commitment: ?Commitment) !Supply {
        const params = .{commitmentParams(commitment)};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSupply", params_json);
        defer self.allocator.free(response);

        const SupplyResult = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: struct {
                total: u64 = 0,
                circulating: u64 = 0,
                nonCirculating: u64 = 0,
            } = .{
                .total = 0,
                .circulating = 0,
                .nonCirculating = 0,
            },
        };

        const result = try self.parseResponse(response, SupplyResult);
        return Supply{
            .total = result.value.total,
            .circulating = result.value.circulating,
            .non_circulating = result.value.nonCirculating,
        };
    }

    pub fn getEpochSchedule(self: *RpcClient) !EpochSchedule {
        const response = try self.sendNoParamsRequest("getEpochSchedule");
        defer self.allocator.free(response);

        const EpochScheduleResult = struct {
            firstNormalSlot: u64 = 0,
            firstNormalEpoch: u64 = 0,
            leaderScheduleSlotOffset: u64 = 0,
            slotsPerEpoch: u64 = 0,
            warmup: bool = false,
        };

        const result = try self.parseResponse(response, EpochScheduleResult);
        return EpochSchedule{
            .first_normal_slot = result.firstNormalSlot,
            .first_normal_epoch = result.firstNormalEpoch,
            .leader_schedule_slot_offset = result.leaderScheduleSlotOffset,
            .slots_per_epoch = result.slotsPerEpoch,
            .warmup = result.warmup,
        };
    }

    pub fn getHighestSnapshotSlot(self: *RpcClient) !SnapshotSlots {
        const response = try self.sendNoParamsRequest("getHighestSnapshotSlot");
        defer self.allocator.free(response);

        const HighestSnapshotSlotResult = struct {
            full: ?u64 = null,
            incremental: ?u64 = null,
        };

        const result = try self.parseResponse(response, HighestSnapshotSlotResult);
        return SnapshotSlots{
            .full = result.full,
            .incremental = result.incremental,
        };
    }

    pub fn getInflationRate(self: *RpcClient) !InflationRate {
        const response = try self.sendNoParamsRequest("getInflationRate");
        defer self.allocator.free(response);

        const InflationRateResult = struct {
            total: f64 = 0,
            validator: f64 = 0,
            foundation: f64 = 0,
            epoch: u64 = 0,
        };

        const result = try self.parseResponse(response, InflationRateResult);
        return InflationRate{
            .total = result.total,
            .validator = result.validator,
            .foundation = result.foundation,
            .epoch = result.epoch,
        };
    }

    pub fn getBlockTime(self: *RpcClient, slot: u64) !?i64 {
        const params = .{slot};
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBlockTime", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, ?i64);
    }

    pub fn getBlock(self: *RpcClient, slot: u64, commitment: ?Commitment) !?[]const u8 {
        const params = if (commitment) |value| blk: {
            const params = .{ slot, .{ .commitment = commitmentToString(value) } };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{slot};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params);

        const response = try self.sendRequest("getBlock", params);
        defer self.allocator.free(response);

        return try self.parseGetBlockResponse(response);
    }

    fn parseGetBlockResponse(self: *RpcClient, response: []const u8) !?[]const u8 {
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

    pub fn getFeeForMessage(self: *RpcClient, encoded_message: []const u8, commitment: ?Commitment) !FeeForMessage {
        const params = .{
            encoded_message,
            commitmentParams(commitment),
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
        return FeeForMessage{ .value = result.value };
    }

    pub fn getRecentPerformanceSamples(self: *RpcClient, limit: ?u64) ![]PerformanceSample {
        var response: []u8 = undefined;
        if (limit) |value| {
            const params = .{value};
            const params_json = try self.serializeParams(params);
            defer self.allocator.free(params_json);
            response = try self.sendRequest("getRecentPerformanceSamples", params_json);
        } else {
            response = try self.sendNoParamsRequest("getRecentPerformanceSamples");
        }
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const PerformanceSampleResult = struct {
            slot: u64 = 0,
            numSlots: u64 = 0,
            numTransactions: u64 = 0,
            samplePeriodSecs: u64 = 0,
            numNonVoteSlots: u64 = 0,
        };
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]PerformanceSampleResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(PerformanceSample, source.len);

        for (source, 0..) |sample, idx| {
            copied[idx] = PerformanceSample{
                .slot = sample.slot,
                .num_slots = sample.numSlots,
                .num_transactions = sample.numTransactions,
                .sample_period_secs = sample.samplePeriodSecs,
                .num_non_vote_slots = sample.numNonVoteSlots,
            };
        }

        return copied;
    }

    pub fn getBlocks(self: *RpcClient, start_slot: u64, end_slot: ?u64, commitment: ?Commitment) ![]u64 {
        const params_json = if (end_slot) |value| blk: {
            if (commitment) |value_commitment| {
                const params = .{ start_slot, value, .{ .commitment = commitmentToString(value_commitment) } };
                break :blk try self.serializeParams(params);
            }
            const params = .{ start_slot, value };
            break :blk try self.serializeParams(params);
        } else blk: {
            if (commitment) |value_commitment| {
                const params = .{ start_slot, .{ .commitment = commitmentToString(value_commitment) } };
                break :blk try self.serializeParams(params);
            }
            const params = .{start_slot};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBlocks", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]u64 = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(u64, source.len);
        @memcpy(copied, source);
        return copied;
    }

    pub fn getBlocksWithLimit(self: *RpcClient, start_slot: u64, limit: u64, commitment: ?Commitment) ![]u64 {
        const params_json = if (commitment) |value| blk: {
            const params = .{ start_slot, limit, .{ .commitment = commitmentToString(value) } };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{ start_slot, limit };
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBlocksWithLimit", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]u64 = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(u64, source.len);
        @memcpy(copied, source);
        return copied;
    }

    pub fn getSlotLeaders(self: *RpcClient, start_slot: u64, limit: u64) ![][]const u8 {
        const params = .{ start_slot, limit };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSlotLeaders", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[][]const u8 = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc([]const u8, source.len);

        for (source, 0..) |leader, idx| {
            copied[idx] = try self.allocator.dupe(u8, leader);
        }

        return copied;
    }

    pub fn getRecentPrioritizationFees(self: *RpcClient) ![]RecentPrioritizationFee {
        const response = try self.sendNoParamsRequest("getRecentPrioritizationFees");
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const PrioritizationFeeResult = struct {
            slot: u64 = 0,
            prioritizationFee: u64 = 0,
        };
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]PrioritizationFeeResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(RecentPrioritizationFee, source.len);

        for (source, 0..) |fee, idx| {
            copied[idx] = RecentPrioritizationFee{
                .slot = fee.slot,
                .prioritization_fee = fee.prioritizationFee,
            };
        }

        return copied;
    }

    pub fn getIdentity(self: *RpcClient) ![]const u8 {
        const response = try self.sendNoParamsRequest("getIdentity");
        defer self.allocator.free(response);

        const IdentityResult = struct {
            identity: []const u8 = "",
        };

        const result = try self.parseResponse(response, IdentityResult);
        return try self.allocator.dupe(u8, result.identity);
    }

    pub fn getInflationGovernor(self: *RpcClient) !InflationGovernor {
        const response = try self.sendNoParamsRequest("getInflationGovernor");
        defer self.allocator.free(response);

        const InflationGovernorResult = struct {
            foundation: f64 = 0,
            foundationTerm: f64 = 0,
            initial: f64 = 0,
            taper: f64 = 0,
            terminal: f64 = 0,
        };

        const result = try self.parseResponse(response, InflationGovernorResult);
        return InflationGovernor{
            .foundation = result.foundation,
            .foundation_term = result.foundationTerm,
            .initial = result.initial,
            .taper = result.taper,
            .terminal = result.terminal,
        };
    }

    pub fn getMinimumLedgerSlot(self: *RpcClient) !u64 {
        const response = try self.sendNoParamsRequest("minimumLedgerSlot");
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getMaxRetransmitSlot(self: *RpcClient) !u64 {
        const response = try self.sendNoParamsRequest("getMaxRetransmitSlot");
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    pub fn getMaxShredInsertSlot(self: *RpcClient) !u64 {
        const response = try self.sendNoParamsRequest("getMaxShredInsertSlot");
        defer self.allocator.free(response);

        return try self.parseResponse(response, u64);
    }

    fn parseNumberAsU64(value: json.Value) !u64 {
        return switch (value) {
            .integer => |int_value| if (int_value < 0) return error.InvalidResponse else @intCast(int_value),
            .number_string => |number| std.fmt.parseInt(u64, number, 10) catch return error.InvalidResponse,
            .float => |float_value| {
                if (float_value < 0.0) return error.InvalidResponse;
                if (float_value != std.math.floor(float_value)) return error.InvalidResponse;
                return @intFromFloat(float_value);
            },
            else => return error.InvalidResponse,
        };
    }

    pub fn getClusterNodes(self: *RpcClient) ![]ClusterNode {
        const response = try self.sendNoParamsRequest("getClusterNodes");
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ClusterNodeResult = struct {
            featureSet: u64 = 0,
            gossip: ?[]const u8 = null,
            pubkey: []const u8 = "",
            rpc: ?[]const u8 = null,
            shredVersion: u64 = 0,
            tpu: ?[]const u8 = null,
            version: ?[]const u8 = null,
        };
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]ClusterNodeResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(ClusterNode, source.len);

        for (source, 0..) |node, idx| {
            copied[idx] = ClusterNode{
                .feature_set = node.featureSet,
                .gossip = if (node.gossip) |value| try self.allocator.dupe(u8, value) else null,
                .pubkey = try self.allocator.dupe(u8, node.pubkey),
                .rpc = if (node.rpc) |value| try self.allocator.dupe(u8, value) else null,
                .shred_version = node.shredVersion,
                .tpu = if (node.tpu) |value| try self.allocator.dupe(u8, value) else null,
                .version = if (node.version) |value| try self.allocator.dupe(u8, value) else null,
            };
        }

        return copied;
    }

    pub fn getLeaderSchedule(self: *RpcClient, slot: ?u64, identity: ?[]const u8, commitment: ?Commitment) !?[]LeaderSchedule {
        const schedule = if (slot) |value| blk: {
            if (identity) |identity_value| {
                const params = .{ value, .{ .identity = identity_value, .commitment = if (commitment) |commitment_value| commitmentToString(commitment_value) else null } };
                break :blk try self.serializeParams(params);
            } else if (commitment) |commitment_value| {
                const params = .{ value, .{ .commitment = commitmentToString(commitment_value) } };
                break :blk try self.serializeParams(params);
            } else {
                break :blk try self.serializeParams(.{value});
            }
        } else blk: {
            if (identity) |identity_value| {
                const params = .{.{ .identity = identity_value, .commitment = if (commitment) |commitment_value| commitmentToString(commitment_value) else null }};
                break :blk try self.serializeParams(params);
            } else if (commitment) |commitment_value| {
                const params = .{.{ .commitment = commitmentToString(commitment_value) }};
                break :blk try self.serializeParams(params);
            } else {
                break :blk null;
            }
        };
        defer if (schedule) |value| self.allocator.free(value);

        const response = if (schedule) |schedule_json| try self.sendRequest("getLeaderSchedule", schedule_json) else try self.sendNoParamsRequest("getLeaderSchedule");
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?json.Value = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        if (source == .null) return null;
        if (source != .object) return error.InvalidResponse;

        const object = source.object;
        const copied = try self.allocator.alloc(LeaderSchedule, object.count());

        var iterator = object.iterator();
        var index: usize = 0;
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* != .array) return error.InvalidResponse;

            const slots = entry.value_ptr.*.array;
            const copied_slots = try self.allocator.alloc(u64, slots.items.len);
            for (slots.items, 0..) |slot_value, slot_index| {
                copied_slots[slot_index] = try parseNumberAsU64(slot_value);
            }

            copied[index] = LeaderSchedule{
                .identity = try self.allocator.dupe(u8, entry.key_ptr.*),
                .slots = copied_slots,
            };
            index += 1;
        }

        return copied;
    }

    fn cloneEpochCredits(self: *RpcClient, source: ?[][]i64) !?[]EpochCredit {
        const raw_credits = source orelse return null;
        const copied = try self.allocator.alloc(EpochCredit, raw_credits.len);

        for (raw_credits, 0..) |row, row_idx| {
            if (row.len < 3) return error.InvalidResponse;
            copied[row_idx] = EpochCredit{
                .epoch = if (row[0] < 0) return error.InvalidResponse else @intCast(row[0]),
                .prev_credits = if (row[1] < 0) return error.InvalidResponse else @intCast(row[1]),
                .curr_credits = if (row[2] < 0) return error.InvalidResponse else @intCast(row[2]),
            };
        }

        return copied;
    }

    fn parseVoteAccounts(self: *RpcClient, source: []VoteAccountResult) ![]VoteAccount {
        const copied = try self.allocator.alloc(VoteAccount, source.len);

        for (source, 0..) |account, idx| {
            copied[idx] = VoteAccount{
                .vote_pubkey = try self.allocator.dupe(u8, account.votePubkey),
                .node_pubkey = try self.allocator.dupe(u8, account.nodePubkey),
                .activated_stake = account.activatedStake,
                .commission = account.commission,
                .epoch_credits = try self.cloneEpochCredits(account.epochCredits),
                .last_vote = account.lastVote,
                .root_slot = account.rootSlot,
                .epoch_vote_account = account.epochVoteAccount,
            };
        }

        return copied;
    }

    pub fn getVoteAccounts(self: *RpcClient) !VoteAccounts {
        const response = try self.sendNoParamsRequest("getVoteAccounts");
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const VoteAccountsResult = struct {
            current: []VoteAccountResult = &.{},
            delinquent: []VoteAccountResult = &.{},
        };

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?VoteAccountsResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const current = try self.parseVoteAccounts(source.current);
        const delinquent = try self.parseVoteAccounts(source.delinquent);

        return VoteAccounts{ .current = current, .delinquent = delinquent };
    }

    pub fn getBlockProduction(self: *RpcClient, commitment: ?Commitment) !BlockProduction {
        const params_json = if (commitment) |value| blk: {
            const params = .{.{ .commitment = commitmentToString(value) }};
            break :blk try self.serializeParams(params);
        } else null;
        defer if (params_json) |params| self.allocator.free(params);

        const response = if (params_json) |value| try self.sendRequest("getBlockProduction", value) else try self.sendNoParamsRequest("getBlockProduction");
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const BlockProductionRange = struct {
            firstSlot: u64 = 0,
            lastSlot: u64 = 0,
        };

        const BlockProductionValue = struct {
            byIdentity: ?json.Value = null,
            range: ?BlockProductionRange = null,
        };

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?BlockProductionValue = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const value = parsed.value.result orelse return error.InvalidResponse;
        const range = value.range orelse return error.InvalidResponse;

        var by_identity = try self.allocator.alloc(BlockProductionIdentity, 0);
        if (value.byIdentity) |by_identity_value| {
            if (by_identity_value != .object) return error.InvalidResponse;

            const map = by_identity_value.object;
            by_identity = try self.allocator.alloc(BlockProductionIdentity, map.count());

            var it = map.iterator();
            var index: usize = 0;
            while (it.next()) |entry| {
                if (entry.value_ptr.* != .array) return error.InvalidResponse;
                const pair = entry.value_ptr.*.array;
                if (pair.items.len < 2) return error.InvalidResponse;

                by_identity[index] = BlockProductionIdentity{
                    .identity = try self.allocator.dupe(u8, entry.key_ptr.*),
                    .leader_slots = try parseNumberAsU64(pair.items[0]),
                    .blocks = try parseNumberAsU64(pair.items[1]),
                };
                index += 1;
            }
        }

        return BlockProduction{
            .first_slot = range.firstSlot,
            .last_slot = range.lastSlot,
            .by_identity = by_identity,
        };
    }

    pub fn isBlockhashValid(self: *RpcClient, blockhash: []const u8, commitment: ?Commitment) !bool {
        const params = .{
            blockhash,
            commitmentParams(commitment),
        };
        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("isBlockhashValid", params_json);
        defer self.allocator.free(response);

        return try self.parseResponse(response, bool);
    }

    pub fn sendTransaction(self: *RpcClient, signed_tx_base64: []const u8, options: ?SendTransactionOptions) ![]const u8 {
        const encoded_commitment = if (options) |opts| if (opts.preflight_commitment) |value|
            commitmentToString(value)
        else
            null else null;

        const SendOptions = struct {
            encoding: []const u8 = "base64",
            skipPreflight: bool,
            maxRetries: ?u32 = null,
            preflightCommitment: ?[]const u8 = null,
        };

        const params = .{
            signed_tx_base64,
            SendOptions{
                .skipPreflight = if (options) |opts| opts.skip_preflight else false,
                .maxRetries = if (options) |opts| opts.max_retries else null,
                .preflightCommitment = encoded_commitment,
            },
        };

        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("sendTransaction", params_json);
        defer self.allocator.free(response);

        const signature = try self.parseResponse(response, []const u8);

        return try self.allocator.dupe(u8, signature);
    }

    const SignatureStatusEntry = struct {
        confirmationStatus: ?[]const u8 = null,
        err: ?json.Value = null,
        slot: ?u64 = null,
        confirmations: ?u64 = null,
    };

    const SignatureStatusesResult = struct {
        context: struct {
            slot: u64 = 0,
        } = .{ .slot = 0 },
        value: []?SignatureStatusEntry = &.{},
    };

    pub fn getSignatureStatus(self: *RpcClient, signature: []const u8, commitment: ?Commitment) !SignatureStatus {
        const SignatureStatusConfig = struct {
            searchTransactionHistory: bool = true,
            commitment: ?[]const u8 = null,
        };

        const params = .{
            [_][]const u8{signature},
            SignatureStatusConfig{
                .commitment = if (commitment) |value| commitmentToString(value) else null,
            },
        };

        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSignatureStatuses", params_json);
        defer self.allocator.free(response);

        const result = try self.parseResponse(response, SignatureStatusesResult);
        if (result.value.len == 0) return error.TransactionNotFound;

        const first = result.value[0] orelse return error.TransactionNotFound;

        return SignatureStatus{
            .confirmation_status = if (first.confirmationStatus) |value| try self.allocator.dupe(u8, value) else null,
            .has_error = first.err != null,
            .slot = first.slot,
            .confirmations = first.confirmations,
        };
    }

    pub fn getSignatureStatuses(self: *RpcClient, signatures: []const []const u8, commitment: ?Commitment) ![]?SignatureStatus {
        const SignatureStatusConfig = struct {
            searchTransactionHistory: bool = true,
            commitment: ?[]const u8 = null,
        };

        const params = .{
            signatures,
            SignatureStatusConfig{
                .commitment = if (commitment) |value| commitmentToString(value) else null,
            },
        };

        const params_json = try self.serializeParams(params);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSignatureStatuses", params_json);
        defer self.allocator.free(response);

        const result = try self.parseResponse(response, SignatureStatusesResult);
        if (result.value.len == 0) return self.allocator.alloc(?SignatureStatus, 0);

        const copied = try self.allocator.alloc(?SignatureStatus, result.value.len);

        for (result.value, 0..) |entry, index| {
            if (entry) |status| {
                copied[index] = SignatureStatus{
                    .confirmation_status = if (status.confirmationStatus) |value| try self.allocator.dupe(u8, value) else null,
                    .has_error = status.err != null,
                    .slot = status.slot,
                    .confirmations = status.confirmations,
                };
            } else {
                copied[index] = null;
            }
        }

        return copied;
    }

    const SignatureForAddressResult = struct {
        signature: []const u8 = "",
        slot: u64 = 0,
        err: ?json.Value = null,
        memo: ?[]const u8 = null,
        confirmationStatus: ?[]const u8 = null,
        blockTime: ?i64 = null,
    };

    pub fn getSignaturesForAddress(
        self: *RpcClient,
        address: []const u8,
        before: ?[]const u8,
        until: ?[]const u8,
        limit: ?u64,
        commitment: ?Commitment,
    ) ![]SignatureForAddress {
        const params = if (before == null and until == null and limit == null and commitment == null) blk: {
            const params = .{address};
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{
                address,
                .{
                    .before = before,
                    .until = until,
                    .limit = limit,
                    .commitment = if (commitment) |value| commitmentToString(value) else null,
                },
            };
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params);

        const response = try self.sendRequest("getSignaturesForAddress", params);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]SignatureForAddressResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.allocator.alloc(SignatureForAddress, source.len);

        for (source, 0..) |entry, idx| {
            copied[idx] = SignatureForAddress{
                .signature = try self.allocator.dupe(u8, entry.signature),
                .slot = entry.slot,
                .block_time = entry.blockTime,
                .confirmation_status = if (entry.confirmationStatus) |status| try self.allocator.dupe(u8, status) else null,
                .memo = if (entry.memo) |memo| try self.allocator.dupe(u8, memo) else null,
                .has_error = entry.err != null,
            };
        }

        return copied;
    }

    pub fn waitForSignatureStatus(self: *RpcClient, signature: []const u8, commitment: ?Commitment, timeout_ms: u64, poll_interval_ms: u64) !void {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            const status = self.getSignatureStatus(signature, commitment) catch |err| {
                switch (err) {
                    error.TransactionNotFound => {
                        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
                        continue;
                    },
                    else => return err,
                }
            };

            defer {
                if (status.confirmation_status) |value| {
                    self.allocator.free(value);
                }
            }

            if (status.has_error) return error.TransactionFailed;
            if (status.confirmation_status) |value| {
                if (value.len > 0) return;
            }

            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }

        return error.TransactionNotConfirmed;
    }

    pub fn sendTransactionAndConfirm(
        self: *RpcClient,
        signed_tx_base64: []const u8,
        options: ?SendTransactionOptions,
        commitment: ?Commitment,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        const signature = try self.sendTransaction(signed_tx_base64, options);
        errdefer self.allocator.free(signature);

        try self.waitForSignatureStatus(signature, commitment, timeout_ms, poll_interval_ms);

        return signature;
    }
};

test "root.getLatestBlockhash params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params_json = try client.serializeParams(.{struct {
        commitment: ?[]const u8 = "finalized",
    }{ .commitment = "finalized" }});
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.balance params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        .{ .commitment = commitmentToString(.finalized) },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getAccountInfo params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment = .{"Address11111111111111111111111111111111"};
    const without_commitment_json = try client.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "Address11111111111111111111111111111111",
        .{ .commitment = commitmentToString(.confirmed) },
    };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.requestAirdrop params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        .{ .commitment = commitmentToString(.processed) },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "12345") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.minimumBalanceForRentExemption params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        128,
        .{ .commitment = commitmentToString(.confirmed) },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "128") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.featureActivationSlot params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "Feature11111111111111111111111111111111111111111",
        .{ .commitment = commitmentToString(.processed) },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Feature11111111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.firstAvailableBlock params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{.{ .commitment = commitmentToString(.processed) }};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getStakeMinimumDelegation params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{.{ .commitment = commitmentToString(.confirmed) }};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.epochInfo params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{.{ .commitment = commitmentToString(.finalized) }};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getSupply params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{.{ .commitment = commitmentToString(.processed) }};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.blockTime params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{123456};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123456") != null);
}

test "root.getBlock params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{123};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);

    const with_commitment = .{ 123, .{ .commitment = commitmentToString(.finalized) } };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.parseGetBlockResponse parses block object" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"blockHeight\":123,\"parentSlot\":456},\"id\":1}";
    const block = try client.parseGetBlockResponse(body);
    defer allocator.free(block.?);

    try std.testing.expect(block != null);
    try std.testing.expect(std.mem.indexOf(u8, block.?, "\"blockHeight\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, block.?, "\"parentSlot\":456") != null);
}

test "root.parseGetBlockResponse handles null block" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const block = try client.parseGetBlockResponse(body);

    try std.testing.expect(block == null);
}

test "root.parseGetBlockResponse propagates rpc error" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32600,\"message\":\"invalid request\"}}";

    try std.testing.expectError(error.RpcError, client.parseGetBlockResponse(body));

    const last_error = client.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32600), last_error.code);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "invalid request"));
}

test "root.parseGetBlockResponse clears last error on successful parse" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const rpc_error_body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32000,\"message\":\"not found\"}}";

    _ = client.parseGetBlockResponse(rpc_error_body) catch {};
    try std.testing.expect(client.getLastError() != null);

    const success_body = "{\"jsonrpc\":\"2.0\",\"result\":{\"blockHeight\":789},\"id\":1}";
    const block = try client.parseGetBlockResponse(success_body);
    defer allocator.free(block.?);

    try std.testing.expect(client.getLastError() == null);
    try std.testing.expect(block != null);
}

test "root.captureRpcError stores rpc error detail" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32005,\"message\":\"custom rpc error\"}}";

    try std.testing.expectError(error.RpcError, client.captureRpcError(body));

    const last_error = client.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32005), last_error.code);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "custom rpc error"));
}

test "root.captureRpcError clears stale error on success" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const error_body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32001,\"message\":\"stale error\"}}";
    try std.testing.expectError(error.RpcError, client.captureRpcError(error_body));
    try std.testing.expect(client.getLastError() != null);

    const ok_body = "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":[]}";
    try client.captureRpcError(ok_body);
    try std.testing.expect(client.getLastError() == null);
}

test "root.getFeeForMessage params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{ "base64-message", .{ .commitment = commitmentToString(.finalized) } };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"base64-message\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.recentPerformanceSamples params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{999};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "999") != null);
}

test "root.getBlocks params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{ 123, 456 };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "456") != null);

    const with_end_only_commitment = .{ 123, 456, .{ .commitment = commitmentToString(.confirmed) } };
    const with_end_only_commitment_json = try client.serializeParams(with_end_only_commitment);
    defer allocator.free(with_end_only_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_end_only_commitment_json, "confirmed") != null);

    const with_commitment = .{ 123, .{ .commitment = commitmentToString(.finalized) } };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "finalized") != null);
}

test "root.getBlocksWithLimit params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{ 123, 25 };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "25") != null);

    const with_commitment = .{ 123, 25, .{ .commitment = commitmentToString(.finalized) } };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getSlotLeaders params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{ 789, 5 };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "789") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "5") != null);
}

test "root.getRecentPrioritizationFees params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getIdentity params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getInflationGovernor params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getSignatureStatus params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const required = .{
        [_][]const u8{"signature"},
        .{ .searchTransactionHistory = true },
    };
    const required_json = try client.serializeParams(required);
    defer allocator.free(required_json);
    try std.testing.expect(std.mem.indexOf(u8, required_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, required_json, "searchTransactionHistory") != null);
    try std.testing.expect(std.mem.indexOf(u8, required_json, "true") != null);

    const committed = .{
        [_][]const u8{"signature"},
        .{ .searchTransactionHistory = true, .commitment = commitmentToString(.confirmed) },
    };
    const committed_json = try client.serializeParams(committed);
    defer allocator.free(committed_json);
    try std.testing.expect(std.mem.indexOf(u8, committed_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, committed_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getSignatureStatuses params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const signatures = [_][]const u8{ "sig-1", "sig-2" };

    const no_commitment = .{
        signatures,
        .{ .searchTransactionHistory = true },
    };
    const no_commitment_json = try client.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, no_commitment_json, "\"sig-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, no_commitment_json, "\"sig-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, no_commitment_json, "searchTransactionHistory") != null);

    const with_commitment = .{
        signatures,
        .{ .searchTransactionHistory = true, .commitment = commitmentToString(.finalized) },
    };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getSignaturesForAddress params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment = .{"Address11111111111111111111111111111111"};
    const without_commitment_json = try client.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment = .{ "Address11111111111111111111111111111111", .{ .commitment = commitmentToString(.confirmed) } };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getSignaturesForAddress params serialization with filters" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const with_filters = .{
        "Address11111111111111111111111111111111",
        .{
            .before = "BeforeSig",
            .until = "UntilSig",
            .limit = @as(u64, 50),
            .commitment = commitmentToString(.finalized),
        },
    };
    const with_filters_json = try client.serializeParams(with_filters);
    defer allocator.free(with_filters_json);

    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"before\":\"BeforeSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"until\":\"UntilSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"limit\":50") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"commitment\":\"finalized\"") != null);
}

test "root.rpc error detail is captured" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32600,\"message\":\"invalid request\"}}";

    const response = client.parseResponse(body, u64);
    try std.testing.expectError(error.RpcError, response);

    const last_error = client.getLastError() orelse return error.TestExpectedError;
    try std.testing.expect(last_error.code == -32600);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "invalid request"));
}

test "root.getClusterNodes params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getLeaderSchedule params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const no_args = .{};
    const no_args_json = try client.serializeParams(no_args);
    defer allocator.free(no_args_json);
    try std.testing.expect(std.mem.eql(u8, no_args_json, "[]"));

    const slot_only = .{123};
    const slot_only_json = try client.serializeParams(slot_only);
    defer allocator.free(slot_only_json);
    try std.testing.expect(std.mem.indexOf(u8, slot_only_json, "123") != null);

    const slot_identity = .{ 123, .{ .identity = "ABC", .commitment = commitmentToString(.finalized) } };
    const slot_identity_json = try client.serializeParams(slot_identity);
    defer allocator.free(slot_identity_json);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "\"identity\":\"ABC\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "\"commitment\":\"finalized\"") != null);

    const identity_only = .{.{ .identity = "DEF", .commitment = commitmentToString(.confirmed) }};
    const identity_only_json = try client.serializeParams(identity_only);
    defer allocator.free(identity_only_json);
    try std.testing.expect(std.mem.indexOf(u8, identity_only_json, "\"identity\":\"DEF\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, identity_only_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getVoteAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getBlockProduction params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const no_commitment = .{};
    const no_commitment_json = try client.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.eql(u8, no_commitment_json, "[]"));

    const with_commitment = .{.{ .commitment = commitmentToString(.processed) }};
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);
}
