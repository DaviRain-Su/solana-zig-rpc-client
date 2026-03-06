const std = @import("std");
const json = std.json;
const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const BlockCommitment = rpc_types.BlockCommitment;
const BlockProduction = rpc_types.BlockProduction;
const BlockProductionIdentity = rpc_types.BlockProductionIdentity;
const BlockProductionQueryOptions = rpc_types.BlockProductionQueryOptions;
const ClusterNode = rpc_types.ClusterNode;
const Commitment = rpc_types.Commitment;
const EpochCredit = rpc_types.EpochCredit;
const EpochInfo = rpc_types.EpochInfo;
const EpochSchedule = rpc_types.EpochSchedule;
const InflationGovernor = rpc_types.InflationGovernor;
const InflationRate = rpc_types.InflationRate;
const InflationReward = rpc_types.InflationReward;
const LatestBlockhash = rpc_types.LatestBlockhash;
const LatestBlockhashResponse = rpc_types.LatestBlockhashResponse;
const LeaderSchedule = rpc_types.LeaderSchedule;
const PerformanceSample = rpc_types.PerformanceSample;
const RecentPrioritizationFee = rpc_types.RecentPrioritizationFee;
const SnapshotSlots = rpc_types.SnapshotSlots;
const VoteAccount = rpc_types.VoteAccount;
const VoteAccountResult = rpc_types.VoteAccountResult;
const VoteAccounts = rpc_types.VoteAccounts;
const VoteAccountsQueryOptions = rpc_types.VoteAccountsQueryOptions;
const commitmentParams = rpc_types.commitmentParams;
const commitmentToString = rpc_types.commitmentToString;

fn sendNoParamsRequest(self: anytype, method: []const u8) ![]u8 {
    return try self.sendRequest(method, "[]");
}

fn cloneU64List(allocator: std.mem.Allocator, source: []const u64) ![]u64 {
    const copied = try allocator.alloc(u64, source.len);
    @memcpy(copied, source);
    return copied;
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

fn cloneEpochCredits(self: anytype, source: ?[][]i64) !?[]EpochCredit {
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

fn parseVoteAccounts(self: anytype, source: []VoteAccountResult) ![]VoteAccount {
    const copied = try self.allocator.alloc(VoteAccount, source.len);

    for (source, 0..) |account, idx| {
        copied[idx] = VoteAccount{
            .vote_pubkey = try self.allocator.dupe(u8, account.votePubkey),
            .node_pubkey = try self.allocator.dupe(u8, account.nodePubkey),
            .activated_stake = account.activatedStake,
            .commission = account.commission,
            .epoch_credits = try cloneEpochCredits(self, account.epochCredits),
            .last_vote = account.lastVote,
            .root_slot = account.rootSlot,
            .epoch_vote_account = account.epochVoteAccount,
        };
    }

    return copied;
}

pub fn getLatestBlockhashResponse(self: anytype, commitment: ?Commitment) !LatestBlockhashResponse {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
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
    if (result.value.blockhash.len == 0) return error.InvalidResponse;

    return LatestBlockhashResponse{
        .context_slot = result.context.slot,
        .value = LatestBlockhash{
            .blockhash = try self.allocator.dupe(u8, result.value.blockhash),
            .last_valid_block_height = result.value.lastValidBlockHeight,
        },
    };
}

pub fn getLatestBlockhash(self: anytype, commitment: ?Commitment) !LatestBlockhash {
    const response = try self.getLatestBlockhashResponse(commitment);
    return response.value;
}

pub fn getNewLatestBlockhash(self: anytype, blockhash: []const u8) ![]const u8 {
    const deadline = std.time.milliTimestamp() + @as(i64, @intCast(sdk.get_new_latest_blockhash_timeout_ms));

    while (std.time.milliTimestamp() < deadline) {
        const latest = try self.getLatestBlockhash(null);
        if (!std.mem.eql(u8, latest.blockhash, blockhash)) {
            return latest.blockhash;
        }

        self.allocator.free(latest.blockhash);
        std.Thread.sleep(sdk.get_new_latest_blockhash_interval_ms * std.time.ns_per_ms);
    }

    return error.Timeout;
}

pub fn getFeatureActivationSlot(self: anytype, feature_pubkey: []const u8, commitment: ?Commitment) !?u64 {
    const params = .{
        feature_pubkey,
        .{ .commitment = self.resolveCommitmentString(commitment) },
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getFeatureActivationSlot", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, ?u64);
}

pub fn getSlot(self: anytype, commitment: ?Commitment) !u64 {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getSlot", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getBlockHeight(self: anytype, commitment: ?Commitment) !u64 {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBlockHeight", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getTransactionCount(self: anytype, commitment: ?Commitment) !u64 {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getTransactionCount", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getGenesisHash(self: anytype) ![]const u8 {
    const response = try sendNoParamsRequest(self, "getGenesisHash");
    defer self.allocator.free(response);

    const hash = try self.parseResponse(response, []const u8);
    return try self.allocator.dupe(u8, hash);
}

pub fn getHealth(self: anytype) ![]const u8 {
    const response = try sendNoParamsRequest(self, "getHealth");
    defer self.allocator.free(response);

    const health = try self.parseResponse(response, []const u8);
    return try self.allocator.dupe(u8, health);
}

pub fn getFirstAvailableBlock(self: anytype, commitment: ?Commitment) !u64 {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getFirstAvailableBlock", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getStakeMinimumDelegation(self: anytype, commitment: ?Commitment) !u64 {
    const params = .{.{ .commitment = self.resolveCommitmentString(commitment) }};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getStakeMinimumDelegation", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getEpochInfo(self: anytype, commitment: ?Commitment) !EpochInfo {
    const params = .{commitmentParams(self.resolveCommitment(commitment))};
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

pub fn getVersion(self: anytype) ![]const u8 {
    const response = try sendNoParamsRequest(self, "getVersion");
    defer self.allocator.free(response);

    const VersionResult = struct {
        @"solana-core": []const u8 = "",
    };

    const result = try self.parseResponse(response, VersionResult);
    return try self.allocator.dupe(u8, result.@"solana-core");
}

pub fn getEpochSchedule(self: anytype) !EpochSchedule {
    const response = try sendNoParamsRequest(self, "getEpochSchedule");
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

pub fn getHighestSnapshotSlot(self: anytype) !SnapshotSlots {
    const response = try sendNoParamsRequest(self, "getHighestSnapshotSlot");
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

pub fn getInflationRate(self: anytype) !InflationRate {
    const response = try sendNoParamsRequest(self, "getInflationRate");
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

pub fn getBlockTime(self: anytype, slot: u64) !?i64 {
    const params = .{slot};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBlockTime", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, ?i64);
}

pub fn getBlockCommitment(self: anytype, slot: u64) !BlockCommitment {
    const params = .{slot};
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getBlockCommitment", params_json);
    defer self.allocator.free(response);

    const BlockCommitmentResult = struct {
        commitment: ?[]u64 = null,
        totalStake: u64 = 0,
    };

    const result = try self.parseResponse(response, BlockCommitmentResult);
    return BlockCommitment{
        .commitment = if (result.commitment) |value| try cloneU64List(self.allocator, value) else null,
        .total_stake = result.totalStake,
    };
}

pub fn getRecentPerformanceSamples(self: anytype, limit: ?u64) ![]PerformanceSample {
    const response = if (limit) |value| blk: {
        const params_json = try self.serializeParams(.{value});
        defer self.allocator.free(params_json);
        break :blk try self.sendRequest("getRecentPerformanceSamples", params_json);
    } else try sendNoParamsRequest(self, "getRecentPerformanceSamples");
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

pub fn getInflationReward(
    self: anytype,
    addresses: []const []const u8,
    epoch: ?u64,
    commitment: ?Commitment,
) ![]?InflationReward {
    const InflationRewardConfig = struct {
        commitment: ?[]const u8 = null,
        epoch: ?u64 = null,
    };

    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (epoch != null or resolved_commitment != null) blk: {
        const params = .{
            addresses,
            InflationRewardConfig{
                .commitment = if (resolved_commitment) |value| commitmentToString(value) else null,
                .epoch = epoch,
            },
        };
        break :blk try self.serializeParams(params);
    } else blk: {
        break :blk try self.serializeParams(.{addresses});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getInflationReward", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const InflationRewardResult = struct {
        epoch: u64 = 0,
        effectiveSlot: u64 = 0,
        amount: u64 = 0,
        postBalance: u64 = 0,
        commission: ?u8 = null,
    };
    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?[]?InflationRewardResult = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const source = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.allocator.alloc(?InflationReward, source.len);

    for (source, 0..) |entry, idx| {
        copied[idx] = if (entry) |value| InflationReward{
            .epoch = value.epoch,
            .effective_slot = value.effectiveSlot,
            .amount = value.amount,
            .post_balance = value.postBalance,
            .commission = value.commission,
        } else null;
    }

    return copied;
}

pub fn getBlocks(self: anytype, start_slot: u64, end_slot: ?u64, commitment: ?Commitment) ![]u64 {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (end_slot) |value| blk: {
        if (resolved_commitment) |value_commitment| {
            break :blk try self.serializeParams(.{ start_slot, value, .{ .commitment = commitmentToString(value_commitment) } });
        }
        break :blk try self.serializeParams(.{ start_slot, value });
    } else blk: {
        if (resolved_commitment) |value_commitment| {
            break :blk try self.serializeParams(.{ start_slot, .{ .commitment = commitmentToString(value_commitment) } });
        }
        break :blk try self.serializeParams(.{start_slot});
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

    return try cloneU64List(self.allocator, parsed.value.result orelse return error.InvalidResponse);
}

pub fn getBlocksWithLimit(self: anytype, start_slot: u64, limit: u64, commitment: ?Commitment) ![]u64 {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        break :blk try self.serializeParams(.{ start_slot, limit, .{ .commitment = commitmentToString(value) } });
    } else blk: {
        break :blk try self.serializeParams(.{ start_slot, limit });
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

    return try cloneU64List(self.allocator, parsed.value.result orelse return error.InvalidResponse);
}

pub fn getSlotLeaders(self: anytype, start_slot: u64, limit: u64) ![][]const u8 {
    const params_json = try self.serializeParams(.{ start_slot, limit });
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

pub fn getSlotLeader(self: anytype, commitment: ?Commitment) ![]const u8 {
    const resolved_commitment = self.resolveCommitment(commitment);
    const params_json = if (resolved_commitment) |value| blk: {
        break :blk try self.serializeParams(.{.{ .commitment = commitmentToString(value) }});
    } else blk: {
        break :blk try self.serializeParams(.{});
    };
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getSlotLeader", params_json);
    defer self.allocator.free(response);

    const leader = try self.parseResponse(response, []const u8);
    return try self.allocator.dupe(u8, leader);
}

pub fn getRecentPrioritizationFees(self: anytype, addresses: ?[]const []const u8) ![]RecentPrioritizationFee {
    const response = if (addresses) |value| blk: {
        const params_json = try self.serializeParams(.{value});
        defer self.allocator.free(params_json);
        break :blk try self.sendRequest("getRecentPrioritizationFees", params_json);
    } else try sendNoParamsRequest(self, "getRecentPrioritizationFees");
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

pub fn getIdentity(self: anytype) ![]const u8 {
    const response = try sendNoParamsRequest(self, "getIdentity");
    defer self.allocator.free(response);

    const IdentityResult = struct {
        identity: []const u8 = "",
    };

    const result = try self.parseResponse(response, IdentityResult);
    return try self.allocator.dupe(u8, result.identity);
}

pub fn getInflationGovernor(self: anytype) !InflationGovernor {
    const response = try sendNoParamsRequest(self, "getInflationGovernor");
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

pub fn getMinimumLedgerSlot(self: anytype) !u64 {
    const response = try sendNoParamsRequest(self, "minimumLedgerSlot");
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getMaxRetransmitSlot(self: anytype) !u64 {
    const response = try sendNoParamsRequest(self, "getMaxRetransmitSlot");
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getMaxShredInsertSlot(self: anytype) !u64 {
    const response = try sendNoParamsRequest(self, "getMaxShredInsertSlot");
    defer self.allocator.free(response);

    return try self.parseResponse(response, u64);
}

pub fn getClusterNodes(self: anytype) ![]ClusterNode {
    const response = try sendNoParamsRequest(self, "getClusterNodes");
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

pub fn getLeaderSchedule(self: anytype, slot: ?u64, identity: ?[]const u8, commitment: ?Commitment) !?[]LeaderSchedule {
    const resolved_commitment = self.resolveCommitment(commitment);
    const schedule = if (slot) |value| blk: {
        if (identity) |identity_value| {
            break :blk try self.serializeParams(.{ value, .{ .identity = identity_value, .commitment = if (resolved_commitment) |commitment_value| commitmentToString(commitment_value) else null } });
        } else if (resolved_commitment) |commitment_value| {
            break :blk try self.serializeParams(.{ value, .{ .commitment = commitmentToString(commitment_value) } });
        } else {
            break :blk try self.serializeParams(.{value});
        }
    } else blk: {
        if (identity) |identity_value| {
            break :blk try self.serializeParams(.{.{ .identity = identity_value, .commitment = if (resolved_commitment) |commitment_value| commitmentToString(commitment_value) else null }});
        } else if (resolved_commitment) |commitment_value| {
            break :blk try self.serializeParams(.{.{ .commitment = commitmentToString(commitment_value) }});
        } else {
            break :blk null;
        }
    };
    defer if (schedule) |value| self.allocator.free(value);

    const response = if (schedule) |schedule_json|
        try self.sendRequest("getLeaderSchedule", schedule_json)
    else
        try sendNoParamsRequest(self, "getLeaderSchedule");
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

pub fn getVoteAccountsWithOptions(self: anytype, options: ?VoteAccountsQueryOptions) !VoteAccounts {
    const VoteAccountsConfig = struct {
        commitment: ?[]const u8 = null,
        votePubkey: ?[]const u8 = null,
        keepUnstakedDelinquents: ?bool = null,
        delinquentSlotDistance: ?u64 = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const vote_pubkey = if (options) |value| value.vote_pubkey else null;
    const keep_unstaked_delinquents = if (options) |value| value.keep_unstaked_delinquents else null;
    const delinquent_slot_distance = if (options) |value| value.delinquent_slot_distance else null;

    const params_json = if (resolved_commitment != null or vote_pubkey != null or keep_unstaked_delinquents != null or delinquent_slot_distance != null) blk: {
        break :blk try self.serializeParams(.{VoteAccountsConfig{
            .commitment = resolved_commitment,
            .votePubkey = vote_pubkey,
            .keepUnstakedDelinquents = keep_unstaked_delinquents,
            .delinquentSlotDistance = delinquent_slot_distance,
        }});
    } else null;
    defer if (params_json) |value| self.allocator.free(value);

    const response = if (params_json) |value|
        try self.sendRequest("getVoteAccounts", value)
    else
        try sendNoParamsRequest(self, "getVoteAccounts");
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
    return VoteAccounts{
        .current = try parseVoteAccounts(self, source.current),
        .delinquent = try parseVoteAccounts(self, source.delinquent),
    };
}

pub fn getVoteAccountsWithConfig(self: anytype, options: ?VoteAccountsQueryOptions) !VoteAccounts {
    return try self.getVoteAccountsWithOptions(options);
}

pub fn getVoteAccounts(self: anytype) !VoteAccounts {
    return try self.getVoteAccountsWithOptions(null);
}

pub fn getBlockProductionWithOptions(self: anytype, options: ?BlockProductionQueryOptions) !BlockProduction {
    const BlockProductionConfig = struct {
        commitment: ?[]const u8 = null,
        identity: ?[]const u8 = null,
        range: ?struct {
            firstSlot: u64,
            lastSlot: ?u64 = null,
        } = null,
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const identity = if (options) |value| value.identity else null;
    const first_slot = if (options) |value| value.first_slot else null;
    const last_slot = if (options) |value| value.last_slot else null;

    const params_json = if (resolved_commitment != null or identity != null or first_slot != null) blk: {
        break :blk try self.serializeParams(.{BlockProductionConfig{
            .commitment = resolved_commitment,
            .identity = identity,
            .range = if (first_slot) |start_slot|
                .{
                    .firstSlot = start_slot,
                    .lastSlot = last_slot,
                }
            else
                null,
        }});
    } else null;
    defer if (params_json) |params| self.allocator.free(params);

    const response = if (params_json) |value|
        try self.sendRequest("getBlockProduction", value)
    else
        try sendNoParamsRequest(self, "getBlockProduction");
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

pub fn getBlockProductionWithConfig(self: anytype, options: ?BlockProductionQueryOptions) !BlockProduction {
    return try self.getBlockProductionWithOptions(options);
}

pub fn getBlockProduction(self: anytype, commitment: ?Commitment) !BlockProduction {
    return try self.getBlockProductionWithOptions(if (commitment) |value|
        BlockProductionQueryOptions{ .commitment = value }
    else
        null);
}

pub fn isBlockhashValid(self: anytype, blockhash: []const u8, commitment: ?Commitment) !bool {
    const params = .{
        blockhash,
        commitmentParams(self.resolveCommitment(commitment)),
    };
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("isBlockhashValid", params_json);
    defer self.allocator.free(response);

    return try self.parseResponse(response, bool);
}
