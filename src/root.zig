const std = @import("std");
const json = std.json;

const Allocator = std.mem.Allocator;
const max_lockout_history: u64 = 31;
const poll_for_signature_timeout_ms: u64 = 15_000;
const poll_for_signature_confirmation_timeout_ms: u64 = 20_000;
const signature_poll_interval_ms: u64 = 250;
pub const default_balance_poll_timeout_ms: u64 = 1_000;
pub const default_balance_poll_interval_ms: u64 = 100;
const wait_for_balance_error_retries: usize = 30;

pub const RpcError = error{
    HttpError,
    RpcError,
    InvalidResponse,
    AccountDataUnavailable,
    AccountNotFound,
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

pub const TransactionEncoding = enum {
    json,
    jsonParsed,
    base58,
    base64,
};

pub const AccountEncoding = enum {
    base58,
    base64,
};

pub const TransactionDetails = enum {
    full,
    accounts,
    signatures,
    none,
};

pub const RpcErrorDetail = struct {
    code: i64 = 0,
    message: []const u8 = "",
};

pub const LatestBlockhash = struct {
    blockhash: []const u8,
    last_valid_block_height: u64,
};

pub const LatestBlockhashResponse = struct {
    context_slot: u64 = 0,
    value: LatestBlockhash,
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
    space: ?u64 = null,
    data: ?[]const u8 = null,
    data_encoding: ?[]const u8 = null,
};

pub const ProgramAccount = struct {
    pubkey: []const u8 = "",
    account: AccountInfo = .{},
};

pub const ProgramAccountsResponse = struct {
    context_slot: ?u64 = null,
    accounts: []ProgramAccount = &.{},
};

pub const AccountInfoResponse = struct {
    context_slot: u64 = 0,
    account: ?AccountInfo = null,
};

pub const BalanceResponse = struct {
    context_slot: u64 = 0,
    value: u64 = 0,
};

pub const MultipleAccountsResponse = struct {
    context_slot: u64 = 0,
    accounts: []?AccountInfo = &.{},
};

pub const TokenAmount = struct {
    amount: []const u8 = "",
    decimals: u8 = 0,
    ui_amount: ?f64 = null,
    ui_amount_string: []const u8 = "",
};

pub const TokenAmountResponse = struct {
    context_slot: u64 = 0,
    value: TokenAmount = .{},
};

pub const TokenLargestAccount = struct {
    address: []const u8 = "",
    amount: TokenAmount = .{},
};

pub const TokenLargestAccountsResponse = struct {
    context_slot: u64 = 0,
    value: []TokenLargestAccount = &.{},
};

pub const LargestAccount = struct {
    address: []const u8 = "",
    lamports: u64 = 0,
};

pub const LargestAccountsFilter = enum {
    circulating,
    non_circulating,
};

pub const ProgramAccountsQueryOptions = struct {
    commitment: ?Commitment = null,
    min_context_slot: ?u64 = null,
    with_context: bool = false,
    sort_results: bool = false,
    data_size: ?u64 = null,
    memcmp_offset: ?u64 = null,
    memcmp_bytes: ?[]const u8 = null,
    data_slice_offset: ?u64 = null,
    data_slice_length: ?u64 = null,
};

pub const AccountQueryOptions = struct {
    commitment: ?Commitment = null,
    min_context_slot: ?u64 = null,
    encoding: ?AccountEncoding = null,
    data_slice_offset: ?u64 = null,
    data_slice_length: ?u64 = null,
};

pub const UiAccountQueryOptions = struct {
    commitment: ?Commitment = null,
    min_context_slot: ?u64 = null,
};

pub const SimulationAccountsOptions = struct {
    addresses: []const []const u8 = &.{},
    encoding: ?AccountEncoding = null,
};

pub const LargestAccountsQueryOptions = struct {
    commitment: ?Commitment = null,
    filter: ?LargestAccountsFilter = null,
};

pub const BlockCommitment = struct {
    commitment: ?[]u64 = null,
    total_stake: u64 = 0,
};

pub const JsonParsedAccountInfo = struct {
    lamports: u64 = 0,
    owner: []const u8 = "",
    executable: bool = false,
    rent_epoch: ?u64 = null,
    space: ?u64 = null,
    data_json: []const u8 = "",
};

pub const UiAccountResponse = struct {
    context_slot: u64 = 0,
    account: ?JsonParsedAccountInfo = null,
};

pub const JsonParsedProgramAccount = struct {
    pubkey: []const u8 = "",
    account: JsonParsedAccountInfo = .{},
};

pub const JsonParsedProgramAccountsResponse = struct {
    context_slot: ?u64 = null,
    accounts: []JsonParsedProgramAccount = &.{},
};

pub const MultipleUiAccountsResponse = struct {
    context_slot: u64 = 0,
    accounts: []?JsonParsedAccountInfo = &.{},
};

pub const TokenAccountsFilter = union(enum) {
    mint: []const u8,
    program_id: []const u8,
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
    non_circulating_accounts: ?[][]const u8 = null,
};

pub const FeeForMessage = struct {
    value: ?u64 = null,
};

pub const FeeForMessageResponse = struct {
    context_slot: u64 = 0,
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

pub const InflationReward = struct {
    epoch: u64 = 0,
    effective_slot: u64 = 0,
    amount: u64 = 0,
    post_balance: u64 = 0,
    commission: ?u8 = null,
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

const RpcAccountInfoResult = struct {
    data: ?[]const []const u8 = null,
    executable: bool = false,
    lamports: u64 = 0,
    owner: []const u8 = "",
    rentEpoch: ?u64 = null,
    space: ?u64 = null,
};

const RpcTokenAmountResult = struct {
    amount: []const u8 = "",
    decimals: u8 = 0,
    uiAmount: ?f64 = null,
    uiAmountString: []const u8 = "",
};

const RpcProgramAccountResult = struct {
    pubkey: []const u8 = "",
    account: RpcAccountInfoResult = .{},
};

const RpcJsonParsedAccountInfoResult = struct {
    data: json.Value = .null,
    executable: bool = false,
    lamports: u64 = 0,
    owner: []const u8 = "",
    rentEpoch: ?u64 = null,
    space: ?u64 = null,
};

const RpcJsonParsedProgramAccountResult = struct {
    pubkey: []const u8 = "",
    account: RpcJsonParsedAccountInfoResult = .{},
};

const RpcSimulatedTransactionResult = struct {
    accounts: ?[]?RpcAccountInfoResult = null,
    err: ?json.Value = null,
    fee: ?u64 = null,
    innerInstructions: ?json.Value = null,
    logs: ?[]const []const u8 = null,
    loadedAccountsDataSize: ?u32 = null,
    replacementBlockhash: ?struct {
        blockhash: []const u8 = "",
        lastValidBlockHeight: u64 = 0,
    } = null,
    returnData: ?struct {
        programId: []const u8 = "",
        data: ?[]const []const u8 = null,
    } = null,
    unitsConsumed: ?u64 = null,
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

pub const VoteAccountsQueryOptions = struct {
    commitment: ?Commitment = null,
    vote_pubkey: ?[]const u8 = null,
    keep_unstaked_delinquents: ?bool = null,
    delinquent_slot_distance: ?u64 = null,
};

pub const BlockProductionQueryOptions = struct {
    commitment: ?Commitment = null,
    identity: ?[]const u8 = null,
    first_slot: ?u64 = null,
    last_slot: ?u64 = null,
};

pub const SupplyQueryOptions = struct {
    commitment: ?Commitment = null,
    exclude_non_circulating_accounts_list: ?bool = null,
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
    min_context_slot: ?u64 = null,
};

pub const SignaturesForAddressOptions = struct {
    before: ?[]const u8 = null,
    until: ?[]const u8 = null,
    limit: ?u64 = null,
    commitment: ?Commitment = null,
    min_context_slot: ?u64 = null,
};

pub const SignatureStatusesQueryOptions = struct {
    search_transaction_history: bool = false,
    commitment: ?Commitment = null,
};

pub const RequestAirdropOptions = struct {
    commitment: ?Commitment = null,
    recent_blockhash: ?[]const u8 = null,
};

pub const SimulateTransactionOptions = struct {
    sig_verify: bool = false,
    replace_recent_blockhash: bool = false,
    commitment: ?Commitment = null,
    min_context_slot: ?u64 = null,
    inner_instructions: bool = false,
    accounts: ?SimulationAccountsOptions = null,
};

pub const SimulationReturnData = struct {
    program_id: []const u8 = "",
    data: ?[]const u8 = null,
    data_encoding: ?[]const u8 = null,
};

pub const SimulatedTransaction = struct {
    context_slot: u64 = 0,
    accounts: ?[]?AccountInfo = null,
    err_json: ?[]const u8 = null,
    fee: ?u64 = null,
    inner_instructions_json: ?[]const u8 = null,
    logs: ?[][]const u8 = null,
    loaded_accounts_data_size: ?u32 = null,
    replacement_blockhash: ?LatestBlockhash = null,
    return_data: ?SimulationReturnData = null,
    units_consumed: ?u64 = null,
};

pub const BlockSummary = struct {
    blockhash: ?[]const u8 = null,
    previous_blockhash: ?[]const u8 = null,
    parent_slot: u64 = 0,
    block_height: ?u64 = null,
    block_time: ?i64 = null,
    transaction_count: ?usize = null,
    rewards_count: ?usize = null,
};

pub const TransactionSummary = struct {
    slot: u64 = 0,
    block_time: ?i64 = null,
    version: ?[]const u8 = null,
    signature_count: ?usize = null,
    fee: ?u64 = null,
    log_messages_count: ?usize = null,
    has_error: bool = false,
    error_json: ?[]const u8 = null,
};

pub const BlockQueryOptions = struct {
    commitment: ?Commitment = null,
    encoding: ?TransactionEncoding = null,
    transaction_details: ?TransactionDetails = null,
    rewards: ?bool = null,
    max_supported_transaction_version: ?u8 = null,
};

pub const TransactionQueryOptions = struct {
    commitment: ?Commitment = null,
    encoding: ?TransactionEncoding = null,
    max_supported_transaction_version: ?u8 = null,
};

const TokenAccountsFilterParams = struct {
    mint: ?[]const u8 = null,
    programId: ?[]const u8 = null,
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

fn commitmentRank(value: Commitment) u8 {
    return switch (value) {
        .processed => 0,
        .confirmed => 1,
        .finalized => 2,
    };
}

fn confirmationStatusRank(value: []const u8) ?u8 {
    if (std.mem.eql(u8, value, "processed")) return 0;
    if (std.mem.eql(u8, value, "confirmed")) return 1;
    if (std.mem.eql(u8, value, "finalized")) return 2;
    return null;
}

fn confirmationSatisfiesCommitment(status: ?[]const u8, commitment: ?Commitment) bool {
    const status_value = status orelse return false;
    const status_rank = confirmationStatusRank(status_value) orelse return false;
    const required_rank = if (commitment) |value| commitmentRank(value) else commitmentRank(.processed);
    return status_rank >= required_rank;
}

fn transactionEncodingToString(value: TransactionEncoding) []const u8 {
    return switch (value) {
        .json => "json",
        .jsonParsed => "jsonParsed",
        .base58 => "base58",
        .base64 => "base64",
    };
}

fn accountEncodingToString(value: AccountEncoding) []const u8 {
    return switch (value) {
        .base58 => "base58",
        .base64 => "base64",
    };
}

fn transactionDetailsToString(value: TransactionDetails) []const u8 {
    return switch (value) {
        .full => "full",
        .accounts => "accounts",
        .signatures => "signatures",
        .none => "none",
    };
}

fn largestAccountsFilterToString(value: LargestAccountsFilter) []const u8 {
    return switch (value) {
        .circulating => "circulating",
        .non_circulating => "nonCirculating",
    };
}

fn tokenAccountsFilterParams(filter: TokenAccountsFilter) TokenAccountsFilterParams {
    return switch (filter) {
        .mint => |value| .{ .mint = value },
        .program_id => |value| .{ .programId = value },
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

        const response = self.http_client.fetch(.{
            .location = .{ .url = self.endpoint },
            .method = .POST,
            .payload = request_body,
            .extra_headers = &headers,
            .response_writer = &response_writer.writer,
        }) catch |err| switch (err) {
            error.HttpConnectionClosing => retry: {
                response_writer.deinit();
                response_writer = std.io.Writer.Allocating.init(self.allocator);

                self.http_client.deinit();
                self.http_client = .{ .allocator = self.allocator };

                break :retry try self.http_client.fetch(.{
                    .location = .{ .url = self.endpoint },
                    .method = .POST,
                    .payload = request_body,
                    .extra_headers = &headers,
                    .response_writer = &response_writer.writer,
                });
            },
            else => return err,
        };

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

    fn cloneAccountInfo(self: *RpcClient, source: RpcAccountInfoResult) !AccountInfo {
        return AccountInfo{
            .lamports = source.lamports,
            .owner = try self.allocator.dupe(u8, source.owner),
            .executable = source.executable,
            .rent_epoch = source.rentEpoch,
            .space = source.space,
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

    fn freeOwnedAccountInfo(self: *RpcClient, info: AccountInfo) void {
        self.allocator.free(info.owner);
        if (info.data) |value| self.allocator.free(value);
        if (info.data_encoding) |value| self.allocator.free(value);
    }

    fn cloneOptionalAccountInfos(self: *RpcClient, source: []const ?RpcAccountInfoResult) ![]?AccountInfo {
        const copied = try self.allocator.alloc(?AccountInfo, source.len);
        var copied_len: usize = 0;
        errdefer {
            for (copied[0..copied_len]) |maybe_info| {
                if (maybe_info) |info| {
                    self.allocator.free(info.owner);
                    if (info.data) |value| self.allocator.free(value);
                    if (info.data_encoding) |value| self.allocator.free(value);
                }
            }
            self.allocator.free(copied);
        }

        for (source, 0..) |maybe_info, index| {
            copied[index] = if (maybe_info) |info| try self.cloneAccountInfo(info) else null;
            copied_len += 1;
        }

        return copied;
    }

    fn cloneOptionalJsonParsedAccountInfos(
        self: *RpcClient,
        source: []const ?RpcJsonParsedAccountInfoResult,
    ) ![]?JsonParsedAccountInfo {
        const copied = try self.allocator.alloc(?JsonParsedAccountInfo, source.len);
        var copied_len: usize = 0;
        errdefer {
            for (copied[0..copied_len]) |maybe_info| {
                if (maybe_info) |info| {
                    self.allocator.free(info.owner);
                    self.allocator.free(info.data_json);
                }
            }
            self.allocator.free(copied);
        }

        for (source, 0..) |maybe_info, index| {
            copied[index] = if (maybe_info) |info| try self.cloneJsonParsedAccountInfo(info) else null;
            copied_len += 1;
        }

        return copied;
    }

    fn cloneTokenAmount(self: *RpcClient, source: RpcTokenAmountResult) !TokenAmount {
        return TokenAmount{
            .amount = try self.allocator.dupe(u8, source.amount),
            .decimals = source.decimals,
            .ui_amount = source.uiAmount,
            .ui_amount_string = try self.allocator.dupe(u8, source.uiAmountString),
        };
    }

    fn cloneStringList(self: *RpcClient, source: []const []const u8) ![][]const u8 {
        const copied = try self.allocator.alloc([]const u8, source.len);
        var copied_len: usize = 0;
        errdefer {
            for (copied[0..copied_len]) |entry| {
                self.allocator.free(entry);
            }
            self.allocator.free(copied);
        }

        for (source, 0..) |entry, index| {
            copied[index] = try self.allocator.dupe(u8, entry);
            copied_len += 1;
        }

        return copied;
    }

    fn cloneU64List(self: *RpcClient, source: []const u64) ![]u64 {
        const copied = try self.allocator.alloc(u64, source.len);
        @memcpy(copied, source);
        return copied;
    }

    fn cloneJsonParsedAccountInfo(self: *RpcClient, source: RpcJsonParsedAccountInfoResult) !JsonParsedAccountInfo {
        return JsonParsedAccountInfo{
            .lamports = source.lamports,
            .owner = try self.allocator.dupe(u8, source.owner),
            .executable = source.executable,
            .rent_epoch = source.rentEpoch,
            .space = source.space,
            .data_json = try json.Stringify.valueAlloc(self.allocator, source.data, .{}),
        };
    }

    fn cloneProgramAccounts(self: *RpcClient, source: []const RpcProgramAccountResult) ![]ProgramAccount {
        const copied = try self.allocator.alloc(ProgramAccount, source.len);
        var copied_len: usize = 0;
        errdefer {
            for (copied[0..copied_len]) |entry| {
                self.allocator.free(entry.pubkey);
                self.allocator.free(entry.account.owner);
                if (entry.account.data) |value| self.allocator.free(value);
                if (entry.account.data_encoding) |value| self.allocator.free(value);
            }
            self.allocator.free(copied);
        }

        for (source, 0..) |entry, index| {
            copied[index] = ProgramAccount{
                .pubkey = try self.allocator.dupe(u8, entry.pubkey),
                .account = try self.cloneAccountInfo(entry.account),
            };
            copied_len += 1;
        }

        return copied;
    }

    fn cloneJsonParsedProgramAccounts(
        self: *RpcClient,
        source: []const RpcJsonParsedProgramAccountResult,
    ) ![]JsonParsedProgramAccount {
        const copied = try self.allocator.alloc(JsonParsedProgramAccount, source.len);
        var copied_len: usize = 0;
        errdefer {
            for (copied[0..copied_len]) |entry| {
                self.allocator.free(entry.pubkey);
                self.allocator.free(entry.account.owner);
                self.allocator.free(entry.account.data_json);
            }
            self.allocator.free(copied);
        }

        for (source, 0..) |entry, index| {
            copied[index] = JsonParsedProgramAccount{
                .pubkey = try self.allocator.dupe(u8, entry.pubkey),
                .account = try self.cloneJsonParsedAccountInfo(entry.account),
            };
            copied_len += 1;
        }

        return copied;
    }

    fn lessThanProgramAccount(_: void, lhs: ProgramAccount, rhs: ProgramAccount) bool {
        return std.mem.order(u8, lhs.pubkey, rhs.pubkey) == .lt;
    }

    fn lessThanJsonParsedProgramAccount(_: void, lhs: JsonParsedProgramAccount, rhs: JsonParsedProgramAccount) bool {
        return std.mem.order(u8, lhs.pubkey, rhs.pubkey) == .lt;
    }

    fn maybeSortProgramAccounts(accounts: []ProgramAccount, sort_results: bool) void {
        if (!sort_results) return;
        std.mem.sort(ProgramAccount, accounts, {}, lessThanProgramAccount);
    }

    fn maybeSortJsonParsedProgramAccounts(accounts: []JsonParsedProgramAccount, sort_results: bool) void {
        if (!sort_results) return;
        std.mem.sort(JsonParsedProgramAccount, accounts, {}, lessThanJsonParsedProgramAccount);
    }

    pub fn getLatestBlockhashResponse(self: *RpcClient, commitment: ?Commitment) !LatestBlockhashResponse {
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

        return LatestBlockhashResponse{
            .context_slot = result.context.slot,
            .value = LatestBlockhash{
                .blockhash = try self.allocator.dupe(u8, result.value.blockhash),
                .last_valid_block_height = result.value.lastValidBlockHeight,
            },
        };
    }

    pub fn getLatestBlockhash(self: *RpcClient, commitment: ?Commitment) !LatestBlockhash {
        const response = try self.getLatestBlockhashResponse(commitment);
        return response.value;
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

    pub fn getBalanceResponse(self: *RpcClient, account: []const u8, commitment: ?Commitment) !BalanceResponse {
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
        return BalanceResponse{
            .context_slot = result.context.slot,
            .value = result.value,
        };
    }

    pub fn getBalance(self: *RpcClient, account: []const u8, commitment: ?Commitment) !u64 {
        const result = try self.getBalanceResponse(account, commitment);
        return result.value;
    }

    fn serializeAccountParams(self: *RpcClient, account: []const u8, options: ?AccountQueryOptions) ![]u8 {
        const DataSlice = struct {
            offset: u64,
            length: u64,
        };

        if (options) |value| {
            const has_data_slice = value.data_slice_offset != null and value.data_slice_length != null;
            const params = .{
                account,
                .{
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .minContextSlot = value.min_context_slot,
                    .encoding = if (value.encoding) |entry| accountEncodingToString(entry) else null,
                    .dataSlice = if (has_data_slice)
                        DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        }
                    else
                        null,
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{account});
    }

    fn serializeMultipleAccountsParams(self: *RpcClient, accounts: []const []const u8, options: ?AccountQueryOptions) ![]u8 {
        const DataSlice = struct {
            offset: u64,
            length: u64,
        };

        if (options) |value| {
            const has_data_slice = value.data_slice_offset != null and value.data_slice_length != null;
            const params = .{
                accounts,
                .{
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .minContextSlot = value.min_context_slot,
                    .encoding = if (value.encoding) |entry| accountEncodingToString(entry) else null,
                    .dataSlice = if (has_data_slice)
                        DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        }
                    else
                        null,
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{accounts});
    }

    fn serializeUiAccountParams(self: *RpcClient, account: []const u8, options: ?UiAccountQueryOptions) ![]u8 {
        const params = .{
            account,
            .{
                .commitment = if (options) |value|
                    if (value.commitment) |entry| commitmentToString(entry) else null
                else
                    null,
                .minContextSlot = if (options) |value| value.min_context_slot else null,
                .encoding = "jsonParsed",
            },
        };
        return try self.serializeParams(params);
    }

    fn serializeMultipleUiAccountsParams(self: *RpcClient, accounts: []const []const u8, options: ?UiAccountQueryOptions) ![]u8 {
        const params = .{
            accounts,
            .{
                .commitment = if (options) |value|
                    if (value.commitment) |entry| commitmentToString(entry) else null
                else
                    null,
                .minContextSlot = if (options) |value| value.min_context_slot else null,
                .encoding = "jsonParsed",
            },
        };
        return try self.serializeParams(params);
    }

    fn serializeSimulateTransactionParams(
        self: *RpcClient,
        signed_tx_base64: []const u8,
        options: ?SimulateTransactionOptions,
    ) ![]u8 {
        const SimulationAccountsConfig = struct {
            addresses: []const []const u8 = &.{},
            encoding: ?[]const u8 = null,
        };

        const SimulateOptions = struct {
            commitment: ?[]const u8 = null,
            encoding: []const u8 = "base64",
            replaceRecentBlockhash: bool = false,
            sigVerify: bool = false,
            minContextSlot: ?u64 = null,
            innerInstructions: bool = false,
            accounts: ?SimulationAccountsConfig = null,
        };

        const params = .{
            signed_tx_base64,
            SimulateOptions{
                .commitment = if (options) |opts| if (opts.commitment) |value| commitmentToString(value) else null else null,
                .replaceRecentBlockhash = if (options) |opts| opts.replace_recent_blockhash else false,
                .sigVerify = if (options) |opts| opts.sig_verify else false,
                .minContextSlot = if (options) |opts| opts.min_context_slot else null,
                .innerInstructions = if (options) |opts| opts.inner_instructions else false,
                .accounts = if (options) |opts|
                    if (opts.accounts) |accounts|
                        SimulationAccountsConfig{
                            .addresses = accounts.addresses,
                            .encoding = if (accounts.encoding) |value| accountEncodingToString(value) else null,
                        }
                    else
                        null
                else
                    null,
            },
        };

        return try self.serializeParams(params);
    }

    fn serializeSendTransactionParams(
        self: *RpcClient,
        signed_tx_base64: []const u8,
        options: ?SendTransactionOptions,
    ) ![]u8 {
        const SendOptions = struct {
            encoding: []const u8 = "base64",
            skipPreflight: bool,
            maxRetries: ?u32 = null,
            preflightCommitment: ?[]const u8 = null,
            minContextSlot: ?u64 = null,
        };

        const params = .{
            signed_tx_base64,
            SendOptions{
                .skipPreflight = if (options) |opts| opts.skip_preflight else false,
                .maxRetries = if (options) |opts| opts.max_retries else null,
                .preflightCommitment = if (options) |opts|
                    if (opts.preflight_commitment) |value| commitmentToString(value) else null
                else
                    null,
                .minContextSlot = if (options) |opts| opts.min_context_slot else null,
            },
        };

        return try self.serializeParams(params);
    }

    fn serializeSignaturesForAddressParams(
        self: *RpcClient,
        address: []const u8,
        options: ?SignaturesForAddressOptions,
    ) ![]u8 {
        if (options) |value| {
            if (value.before == null and value.until == null and value.limit == null and value.commitment == null and value.min_context_slot == null) {
                return try self.serializeParams(.{address});
            }

            const params = .{
                address,
                .{
                    .before = value.before,
                    .until = value.until,
                    .limit = value.limit,
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .minContextSlot = value.min_context_slot,
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{address});
    }

    fn serializeSignatureStatusesParams(
        self: *RpcClient,
        signatures: []const []const u8,
        options: ?SignatureStatusesQueryOptions,
    ) ![]u8 {
        if (options) |value| {
            const commitment = if (value.commitment) |entry| commitmentToString(entry) else null;

            if (!value.search_transaction_history and commitment == null) {
                return try self.serializeParams(.{signatures});
            }

            if (value.search_transaction_history and commitment != null) {
                return try self.serializeParams(.{
                    signatures,
                    .{
                        .searchTransactionHistory = true,
                        .commitment = commitment,
                    },
                });
            }

            if (value.search_transaction_history) {
                return try self.serializeParams(.{
                    signatures,
                    .{ .searchTransactionHistory = true },
                });
            }

            return try self.serializeParams(.{
                signatures,
                .{ .commitment = commitment },
            });
        }

        return try self.serializeParams(.{signatures});
    }

    fn serializeRequestAirdropParams(
        self: *RpcClient,
        account: []const u8,
        lamports: u64,
        options: ?RequestAirdropOptions,
    ) ![]u8 {
        if (options) |value| {
            const params = .{
                account,
                lamports,
                .{
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .recentBlockhash = value.recent_blockhash,
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{ account, lamports });
    }

    pub fn getAccountInfoResponseWithOptions(self: *RpcClient, account: []const u8, options: ?AccountQueryOptions) !AccountInfoResponse {
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

    pub fn getAccountInfoMaybeWithOptions(self: *RpcClient, account: []const u8, options: ?AccountQueryOptions) !?AccountInfo {
        const response = try self.getAccountInfoResponseWithOptions(account, options);
        return response.account;
    }

    pub fn getAccountInfoWithOptions(self: *RpcClient, account: []const u8, options: ?AccountQueryOptions) !AccountInfo {
        return (try self.getAccountInfoMaybeWithOptions(account, options)) orelse error.AccountNotFound;
    }

    pub fn getAccountInfoResponse(self: *RpcClient, account: []const u8, commitment: ?Commitment) !AccountInfoResponse {
        return try self.getAccountInfoResponseWithOptions(
            account,
            if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getAccountInfoMaybe(self: *RpcClient, account: []const u8, commitment: ?Commitment) !?AccountInfo {
        return try self.getAccountInfoMaybeWithOptions(
            account,
            if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getAccountInfo(self: *RpcClient, account: []const u8, commitment: ?Commitment) !AccountInfo {
        return (try self.getAccountInfoMaybe(account, commitment)) orelse error.AccountNotFound;
    }

    pub fn getAccountDataWithOptions(self: *RpcClient, account: []const u8, options: ?AccountQueryOptions) ![]const u8 {
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

    pub fn getAccountData(self: *RpcClient, account: []const u8, commitment: ?Commitment) ![]const u8 {
        return try self.getAccountDataWithOptions(
            account,
            if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getUiAccountResponseWithOptions(self: *RpcClient, account: []const u8, options: ?UiAccountQueryOptions) !UiAccountResponse {
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

    pub fn getUiAccountMaybeWithOptions(self: *RpcClient, account: []const u8, options: ?UiAccountQueryOptions) !?JsonParsedAccountInfo {
        const response = try self.getUiAccountResponseWithOptions(account, options);
        return response.account;
    }

    pub fn getUiAccountWithOptions(self: *RpcClient, account: []const u8, options: ?UiAccountQueryOptions) !JsonParsedAccountInfo {
        return (try self.getUiAccountMaybeWithOptions(account, options)) orelse error.AccountNotFound;
    }

    pub fn getUiAccountResponse(self: *RpcClient, account: []const u8, commitment: ?Commitment) !UiAccountResponse {
        return try self.getUiAccountResponseWithOptions(
            account,
            if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getUiAccountMaybe(self: *RpcClient, account: []const u8, commitment: ?Commitment) !?JsonParsedAccountInfo {
        return try self.getUiAccountMaybeWithOptions(
            account,
            if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getUiAccount(self: *RpcClient, account: []const u8, commitment: ?Commitment) !JsonParsedAccountInfo {
        return (try self.getUiAccountMaybe(account, commitment)) orelse error.AccountNotFound;
    }

    pub fn getMultipleAccountsResponseWithOptions(self: *RpcClient, accounts: []const []const u8, options: ?AccountQueryOptions) !MultipleAccountsResponse {
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

    pub fn getMultipleAccountsWithOptions(self: *RpcClient, accounts: []const []const u8, options: ?AccountQueryOptions) ![]?AccountInfo {
        const response = try self.getMultipleAccountsResponseWithOptions(accounts, options);
        return response.accounts;
    }

    pub fn getMultipleAccounts(self: *RpcClient, accounts: []const []const u8, commitment: ?Commitment) ![]?AccountInfo {
        return try self.getMultipleAccountsWithOptions(
            accounts,
            if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getMultipleAccountsResponse(self: *RpcClient, accounts: []const []const u8, commitment: ?Commitment) !MultipleAccountsResponse {
        return try self.getMultipleAccountsResponseWithOptions(
            accounts,
            if (commitment) |value| AccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getMultipleUiAccountsResponseWithOptions(self: *RpcClient, accounts: []const []const u8, options: ?UiAccountQueryOptions) !MultipleUiAccountsResponse {
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

    pub fn getMultipleUiAccountsWithOptions(self: *RpcClient, accounts: []const []const u8, options: ?UiAccountQueryOptions) ![]?JsonParsedAccountInfo {
        const response = try self.getMultipleUiAccountsResponseWithOptions(accounts, options);
        return response.accounts;
    }

    pub fn getMultipleUiAccounts(self: *RpcClient, accounts: []const []const u8, commitment: ?Commitment) ![]?JsonParsedAccountInfo {
        return try self.getMultipleUiAccountsWithOptions(
            accounts,
            if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
        );
    }

    pub fn getMultipleUiAccountsResponse(self: *RpcClient, accounts: []const []const u8, commitment: ?Commitment) !MultipleUiAccountsResponse {
        return try self.getMultipleUiAccountsResponseWithOptions(
            accounts,
            if (commitment) |value| UiAccountQueryOptions{ .commitment = value } else null,
        );
    }

    fn serializeProgramAccountsParams(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]u8 {
        const DataSlice = struct {
            offset: u64,
            length: u64,
        };
        const DataSizeFilter = struct {
            dataSize: u64,
        };
        const MemcmpFilter = struct {
            memcmp: struct {
                offset: u64,
                bytes: []const u8,
            },
        };

        if (options) |value| {
            const commitment = if (value.commitment) |entry| commitmentToString(entry) else null;
            const min_context_slot = value.min_context_slot;
            const with_context = value.with_context;
            const has_data_size = value.data_size != null;
            const has_memcmp = value.memcmp_offset != null and value.memcmp_bytes != null;
            const has_data_slice = value.data_slice_offset != null and value.data_slice_length != null;

            if (!has_data_size and !has_memcmp and !has_data_slice and commitment == null and min_context_slot == null and !with_context) {
                return try self.serializeParams(.{program_id});
            }

            if (has_data_size and has_memcmp and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{
                            DataSizeFilter{ .dataSize = value.data_size.? },
                            MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } },
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size and has_memcmp) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .filters = .{
                            DataSizeFilter{ .dataSize = value.data_size.? },
                            MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } },
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{DataSizeFilter{ .dataSize = value.data_size.? }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_memcmp and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .filters = .{DataSizeFilter{ .dataSize = value.data_size.? }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_memcmp) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .filters = .{MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            const params = .{
                program_id,
                .{
                    .commitment = commitment,
                    .minContextSlot = min_context_slot,
                    .withContext = with_context,
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{program_id});
    }

    fn serializeProgramUiAccountsParams(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]u8 {
        const DataSlice = struct {
            offset: u64,
            length: u64,
        };
        const DataSizeFilter = struct {
            dataSize: u64,
        };
        const MemcmpFilter = struct {
            memcmp: struct {
                offset: u64,
                bytes: []const u8,
            },
        };

        if (options) |value| {
            const commitment = if (value.commitment) |entry| commitmentToString(entry) else null;
            const min_context_slot = value.min_context_slot;
            const with_context = value.with_context;
            const has_data_size = value.data_size != null;
            const has_memcmp = value.memcmp_offset != null and value.memcmp_bytes != null;
            const has_data_slice = value.data_slice_offset != null and value.data_slice_length != null;

            if (!has_data_size and !has_memcmp and !has_data_slice and commitment == null and min_context_slot == null and !with_context) {
                return try self.serializeParams(.{
                    program_id,
                    .{ .encoding = "jsonParsed" },
                });
            }

            if (has_data_size and has_memcmp and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{
                            DataSizeFilter{ .dataSize = value.data_size.? },
                            MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } },
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size and has_memcmp) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .filters = .{
                            DataSizeFilter{ .dataSize = value.data_size.? },
                            MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } },
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{DataSizeFilter{ .dataSize = value.data_size.? }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_memcmp and has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                        .filters = .{MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_size) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .filters = .{DataSizeFilter{ .dataSize = value.data_size.? }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_memcmp) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .filters = .{MemcmpFilter{ .memcmp = .{ .offset = value.memcmp_offset.?, .bytes = value.memcmp_bytes.? } }},
                    },
                };
                return try self.serializeParams(params);
            }

            if (has_data_slice) {
                const params = .{
                    program_id,
                    .{
                        .commitment = commitment,
                        .minContextSlot = min_context_slot,
                        .withContext = with_context,
                        .encoding = "jsonParsed",
                        .dataSlice = DataSlice{
                            .offset = value.data_slice_offset.?,
                            .length = value.data_slice_length.?,
                        },
                    },
                };
                return try self.serializeParams(params);
            }

            const params = .{
                program_id,
                .{
                    .commitment = commitment,
                    .minContextSlot = min_context_slot,
                    .withContext = with_context,
                    .encoding = "jsonParsed",
                },
            };
            return try self.serializeParams(params);
        }

        return try self.serializeParams(.{
            program_id,
            .{ .encoding = "jsonParsed" },
        });
    }

    pub fn getProgramAccountsResponseWithOptions(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) !ProgramAccountsResponse {
        const params_json = try self.serializeProgramAccountsParams(program_id, options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getProgramAccounts", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        if (options != null and options.?.with_context) {
            const ParsedEnvelope = struct {
                jsonrpc: []const u8 = "",
                id: u64 = 0,
                result: ?struct {
                    context: struct {
                        slot: u64 = 0,
                    } = .{ .slot = 0 },
                    value: []RpcProgramAccountResult = &.{},
                } = null,
            };

            const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();

            const result = parsed.value.result orelse return error.InvalidResponse;
            const copied = try self.cloneProgramAccounts(result.value);
            maybeSortProgramAccounts(copied, if (options) |value| value.sort_results else false);
            return ProgramAccountsResponse{
                .context_slot = result.context.slot,
                .accounts = copied,
            };
        }

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]RpcProgramAccountResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.cloneProgramAccounts(source);
        maybeSortProgramAccounts(copied, if (options) |value| value.sort_results else false);
        return ProgramAccountsResponse{
            .context_slot = null,
            .accounts = copied,
        };
    }

    pub fn getProgramAccountsWithOptions(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]ProgramAccount {
        const response = try self.getProgramAccountsResponseWithOptions(program_id, options);
        return response.accounts;
    }

    pub fn getProgramAccounts(self: *RpcClient, program_id: []const u8, commitment: ?Commitment) ![]ProgramAccount {
        const options = if (commitment) |value|
            ProgramAccountsQueryOptions{ .commitment = value }
        else
            null;
        return try self.getProgramAccountsWithOptions(program_id, options);
    }

    pub fn getProgramUiAccountsResponseWithOptions(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) !JsonParsedProgramAccountsResponse {
        const params_json = try self.serializeProgramUiAccountsParams(program_id, options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getProgramAccounts", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        if (options != null and options.?.with_context) {
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
            const copied = try self.cloneJsonParsedProgramAccounts(result.value);
            maybeSortJsonParsedProgramAccounts(copied, if (options) |value| value.sort_results else false);
            return JsonParsedProgramAccountsResponse{
                .context_slot = result.context.slot,
                .accounts = copied,
            };
        }

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?[]RpcJsonParsedProgramAccountResult = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const source = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.cloneJsonParsedProgramAccounts(source);
        maybeSortJsonParsedProgramAccounts(copied, if (options) |value| value.sort_results else false);
        return JsonParsedProgramAccountsResponse{
            .context_slot = null,
            .accounts = copied,
        };
    }

    pub fn getProgramUiAccountsWithOptions(self: *RpcClient, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]JsonParsedProgramAccount {
        const response = try self.getProgramUiAccountsResponseWithOptions(program_id, options);
        return response.accounts;
    }

    pub fn getProgramUiAccounts(self: *RpcClient, program_id: []const u8, commitment: ?Commitment) ![]JsonParsedProgramAccount {
        const options = if (commitment) |value|
            ProgramAccountsQueryOptions{ .commitment = value }
        else
            null;
        return try self.getProgramUiAccountsWithOptions(program_id, options);
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

    pub fn requestAirdropWithOptions(
        self: *RpcClient,
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
        self: *RpcClient,
        account: []const u8,
        lamports: u64,
        options: ?RequestAirdropOptions,
    ) ![]const u8 {
        return try self.requestAirdropWithOptions(account, lamports, options);
    }

    pub fn requestAirdrop(self: *RpcClient, account: []const u8, lamports: u64, commitment: ?Commitment) ![]const u8 {
        return try self.requestAirdropWithOptions(
            account,
            lamports,
            if (commitment) |value| RequestAirdropOptions{ .commitment = value } else null,
        );
    }

    pub fn requestAirdropWithBlockhash(
        self: *RpcClient,
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

    pub fn getSupply(self: *RpcClient, commitment: ?Commitment) !Supply {
        return try self.getSupplyWithOptions(if (commitment) |value|
            SupplyQueryOptions{ .commitment = value }
        else
            null);
    }

    pub fn getSupplyWithOptions(self: *RpcClient, options: ?SupplyQueryOptions) !Supply {
        const SupplyConfig = struct {
            commitment: ?[]const u8 = null,
            excludeNonCirculatingAccountsList: ?bool = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{SupplyConfig{
                .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                .excludeNonCirculatingAccountsList = value.exclude_non_circulating_accounts_list,
            }};
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{};
            break :blk try self.serializeParams(params);
        };
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
                nonCirculatingAccounts: ?[][]const u8 = null,
            } = .{
                .total = 0,
                .circulating = 0,
                .nonCirculating = 0,
                .nonCirculatingAccounts = null,
            },
        };

        const result = try self.parseResponse(response, SupplyResult);
        return Supply{
            .total = result.value.total,
            .circulating = result.value.circulating,
            .non_circulating = result.value.nonCirculating,
            .non_circulating_accounts = if (result.value.nonCirculatingAccounts) |value| try self.cloneStringList(value) else null,
        };
    }

    pub fn getLargestAccountsWithOptions(self: *RpcClient, options: ?LargestAccountsQueryOptions) ![]LargestAccount {
        const LargestAccountsConfig = struct {
            commitment: ?[]const u8 = null,
            filter: ?[]const u8 = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{LargestAccountsConfig{
                .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                .filter = if (value.filter) |entry| largestAccountsFilterToString(entry) else null,
            }};
            break :blk try self.serializeParams(params);
        } else null;
        defer if (params_json) |value| self.allocator.free(value);

        const response = if (params_json) |value| try self.sendRequest("getLargestAccounts", value) else try self.sendNoParamsRequest("getLargestAccounts");
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

    pub fn getLargestAccounts(self: *RpcClient, commitment: ?Commitment) ![]LargestAccount {
        return try self.getLargestAccountsWithOptions(if (commitment) |value|
            LargestAccountsQueryOptions{ .commitment = value }
        else
            null);
    }

    pub fn getTokenAccountBalance(self: *RpcClient, token_account: []const u8, commitment: ?Commitment) !TokenAmount {
        const response = try self.getTokenAccountBalanceResponse(token_account, commitment);
        return response.value;
    }

    pub fn getTokenAccountBalanceResponse(self: *RpcClient, token_account: []const u8, commitment: ?Commitment) !TokenAmountResponse {
        const params_json = if (commitment) |value| blk: {
            const params = .{ token_account, .{ .commitment = commitmentToString(value) } };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{token_account};
            break :blk try self.serializeParams(params);
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
            .value = try self.cloneTokenAmount(result.value),
        };
    }

    pub fn getTokenAccountMaybe(self: *RpcClient, token_account: []const u8, commitment: ?Commitment) !?JsonParsedAccountInfo {
        return try self.getUiAccountMaybe(token_account, commitment);
    }

    pub fn getTokenAccountMaybeWithOptions(self: *RpcClient, token_account: []const u8, options: ?UiAccountQueryOptions) !?JsonParsedAccountInfo {
        return try self.getUiAccountMaybeWithOptions(token_account, options);
    }

    pub fn getTokenAccountWithOptions(self: *RpcClient, token_account: []const u8, options: ?UiAccountQueryOptions) !JsonParsedAccountInfo {
        return (try self.getTokenAccountMaybeWithOptions(token_account, options)) orelse error.AccountNotFound;
    }

    pub fn getTokenAccount(self: *RpcClient, token_account: []const u8, commitment: ?Commitment) !JsonParsedAccountInfo {
        return (try self.getTokenAccountMaybe(token_account, commitment)) orelse error.AccountNotFound;
    }

    pub fn getTokenSupply(self: *RpcClient, mint: []const u8, commitment: ?Commitment) !TokenAmount {
        const response = try self.getTokenSupplyResponse(mint, commitment);
        return response.value;
    }

    pub fn getTokenSupplyResponse(self: *RpcClient, mint: []const u8, commitment: ?Commitment) !TokenAmountResponse {
        const params_json = if (commitment) |value| blk: {
            const params = .{ mint, .{ .commitment = commitmentToString(value) } };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{mint};
            break :blk try self.serializeParams(params);
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
            .value = try self.cloneTokenAmount(result.value),
        };
    }

    pub fn getTokenLargestAccounts(self: *RpcClient, mint: []const u8, commitment: ?Commitment) ![]TokenLargestAccount {
        const response = try self.getTokenLargestAccountsResponse(mint, commitment);
        return response.value;
    }

    pub fn getTokenLargestAccountsResponse(self: *RpcClient, mint: []const u8, commitment: ?Commitment) !TokenLargestAccountsResponse {
        const params_json = if (commitment) |value| blk: {
            const params = .{ mint, .{ .commitment = commitmentToString(value) } };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{mint};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getTokenLargestAccounts", params_json);
        defer self.allocator.free(response);

        const TokenLargestAccountResult = struct {
            address: []const u8 = "",
            amount: []const u8 = "",
            decimals: u8 = 0,
            uiAmount: ?f64 = null,
            uiAmountString: []const u8 = "",
        };

        const ParsedResponse = struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: []TokenLargestAccountResult = &.{},
        };

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?ParsedResponse = null,
            @"error": ?RpcErrorDetail = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error" != null) {
            const err = parsed.value.@"error".?;
            self.last_error = RpcErrorDetail{
                .code = err.code,
                .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
            };
            return error.RpcError;
        }

        const result = parsed.value.result orelse return error.InvalidResponse;

        const copied = try self.allocator.alloc(TokenLargestAccount, result.value.len);

        for (result.value, 0..) |entry, index| {
            copied[index] = TokenLargestAccount{
                .address = try self.allocator.dupe(u8, entry.address),
                .amount = try self.cloneTokenAmount(.{
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
        self: *RpcClient,
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
                .commitment = if (commitment) |value| commitmentToString(value) else null,
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
        self: *RpcClient,
        owner: []const u8,
        filter: TokenAccountsFilter,
        commitment: ?Commitment,
    ) ![]JsonParsedProgramAccount {
        return try self.getTokenAccounts("getTokenAccountsByOwner", owner, filter, commitment);
    }

    pub fn getTokenAccountsByDelegate(
        self: *RpcClient,
        delegate: []const u8,
        filter: TokenAccountsFilter,
        commitment: ?Commitment,
    ) ![]JsonParsedProgramAccount {
        return try self.getTokenAccounts("getTokenAccountsByDelegate", delegate, filter, commitment);
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

    pub fn getBlockCommitment(self: *RpcClient, slot: u64) !BlockCommitment {
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
            .commitment = if (result.commitment) |value| try self.cloneU64List(value) else null,
            .total_stake = result.totalStake,
        };
    }

    pub fn getBlockWithOptions(self: *RpcClient, slot: u64, options: ?BlockQueryOptions) !?[]const u8 {
        const BlockConfig = struct {
            commitment: ?[]const u8 = null,
            encoding: ?[]const u8 = null,
            transactionDetails: ?[]const u8 = null,
            rewards: ?bool = null,
            maxSupportedTransactionVersion: ?u8 = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{
                slot,
                BlockConfig{
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .encoding = if (value.encoding) |entry| transactionEncodingToString(entry) else null,
                    .transactionDetails = if (value.transaction_details) |entry| transactionDetailsToString(entry) else null,
                    .rewards = value.rewards,
                    .maxSupportedTransactionVersion = value.max_supported_transaction_version,
                },
            };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{slot};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getBlock", params_json);
        defer self.allocator.free(response);

        return try self.parseGetBlockResponse(response);
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
        return try self.parseJsonValueResponse(response);
    }

    pub fn summarizeBlockJson(self: *RpcClient, block_json: []const u8) !BlockSummary {
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

    pub fn freeOwnedBlockSummary(self: *RpcClient, summary: BlockSummary) void {
        if (summary.blockhash) |value| self.allocator.free(value);
        if (summary.previous_blockhash) |value| self.allocator.free(value);
    }

    pub fn getBlockSummaryWithOptions(self: *RpcClient, slot: u64, options: ?BlockQueryOptions) !?BlockSummary {
        const block_json = try self.getBlockWithOptions(slot, options);
        defer if (block_json) |value| self.allocator.free(value);

        if (block_json) |value| {
            return try self.summarizeBlockJson(value);
        }

        return null;
    }

    pub fn getBlockSummary(self: *RpcClient, slot: u64, commitment: ?Commitment) !?BlockSummary {
        return try self.getBlockSummaryWithOptions(
            slot,
            if (commitment) |value|
                BlockQueryOptions{ .commitment = value }
            else
                null,
        );
    }

    pub fn getTransaction(self: *RpcClient, signature: []const u8, options: ?TransactionQueryOptions) !?[]const u8 {
        const TransactionConfig = struct {
            commitment: ?[]const u8 = null,
            encoding: ?[]const u8 = null,
            maxSupportedTransactionVersion: ?u8 = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{
                signature,
                TransactionConfig{
                    .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                    .encoding = if (value.encoding) |entry| transactionEncodingToString(entry) else null,
                    .maxSupportedTransactionVersion = value.max_supported_transaction_version,
                },
            };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{signature};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getTransaction", params_json);
        defer self.allocator.free(response);

        return try self.parseGetTransactionResponse(response);
    }

    fn parseGetTransactionResponse(self: *RpcClient, response: []const u8) !?[]const u8 {
        return try self.parseJsonValueResponse(response);
    }

    pub fn summarizeTransactionJson(self: *RpcClient, transaction_json: []const u8) !TransactionSummary {
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
                    error_json = try self.cloneJsonValueText(err_value);
                }
            }
        }

        return TransactionSummary{
            .slot = parsed.value.slot,
            .block_time = parsed.value.blockTime,
            .version = if (parsed.value.version) |value| try self.cloneJsonValueText(value) else null,
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

    pub fn freeOwnedTransactionSummary(self: *RpcClient, summary: TransactionSummary) void {
        if (summary.version) |value| self.allocator.free(value);
        if (summary.error_json) |value| self.allocator.free(value);
    }

    pub fn getTransactionSummaryWithOptions(self: *RpcClient, signature: []const u8, options: ?TransactionQueryOptions) !?TransactionSummary {
        const transaction_json = try self.getTransaction(signature, options);
        defer if (transaction_json) |value| self.allocator.free(value);

        if (transaction_json) |value| {
            return try self.summarizeTransactionJson(value);
        }

        return null;
    }

    pub fn getTransactionSummary(self: *RpcClient, signature: []const u8, commitment: ?Commitment) !?TransactionSummary {
        return try self.getTransactionSummaryWithOptions(
            signature,
            if (commitment) |value|
                TransactionQueryOptions{ .commitment = value }
            else
                null,
        );
    }

    fn parseJsonValueResponse(self: *RpcClient, response: []const u8) !?[]const u8 {
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

    pub fn getFeeForMessageResponse(self: *RpcClient, encoded_message: []const u8, commitment: ?Commitment) !FeeForMessageResponse {
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
        return FeeForMessageResponse{
            .context_slot = result.context.slot,
            .value = result.value,
        };
    }

    pub fn getFeeForMessage(self: *RpcClient, encoded_message: []const u8, commitment: ?Commitment) !FeeForMessage {
        const response = try self.getFeeForMessageResponse(encoded_message, commitment);
        return FeeForMessage{ .value = response.value };
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

    pub fn getInflationReward(
        self: *RpcClient,
        addresses: []const []const u8,
        epoch: ?u64,
        commitment: ?Commitment,
    ) ![]?InflationReward {
        const InflationRewardConfig = struct {
            commitment: ?[]const u8 = null,
            epoch: ?u64 = null,
        };

        const params_json = if (epoch != null or commitment != null) blk: {
            const params = .{
                addresses,
                InflationRewardConfig{
                    .commitment = if (commitment) |value| commitmentToString(value) else null,
                    .epoch = epoch,
                },
            };
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{addresses};
            break :blk try self.serializeParams(params);
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
            if (entry) |value| {
                copied[idx] = InflationReward{
                    .epoch = value.epoch,
                    .effective_slot = value.effectiveSlot,
                    .amount = value.amount,
                    .post_balance = value.postBalance,
                    .commission = value.commission,
                };
            } else {
                copied[idx] = null;
            }
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

    pub fn getSlotLeader(self: *RpcClient, commitment: ?Commitment) ![]const u8 {
        const params_json = if (commitment) |value| blk: {
            const params = .{.{ .commitment = commitmentToString(value) }};
            break :blk try self.serializeParams(params);
        } else blk: {
            const params = .{};
            break :blk try self.serializeParams(params);
        };
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSlotLeader", params_json);
        defer self.allocator.free(response);

        const leader = try self.parseResponse(response, []const u8);
        return try self.allocator.dupe(u8, leader);
    }

    pub fn getRecentPrioritizationFees(self: *RpcClient, addresses: ?[]const []const u8) ![]RecentPrioritizationFee {
        const response = if (addresses) |value| blk: {
            const params = .{value};
            const params_json = try self.serializeParams(params);
            defer self.allocator.free(params_json);
            break :blk try self.sendRequest("getRecentPrioritizationFees", params_json);
        } else try self.sendNoParamsRequest("getRecentPrioritizationFees");
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

    fn cloneJsonValueText(self: *RpcClient, value: json.Value) ![]const u8 {
        return switch (value) {
            .string => |text| try self.allocator.dupe(u8, text),
            else => try json.Stringify.valueAlloc(self.allocator, value, .{}),
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

    pub fn getVoteAccountsWithOptions(self: *RpcClient, options: ?VoteAccountsQueryOptions) !VoteAccounts {
        const VoteAccountsConfig = struct {
            commitment: ?[]const u8 = null,
            votePubkey: ?[]const u8 = null,
            keepUnstakedDelinquents: ?bool = null,
            delinquentSlotDistance: ?u64 = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{VoteAccountsConfig{
                .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                .votePubkey = value.vote_pubkey,
                .keepUnstakedDelinquents = value.keep_unstaked_delinquents,
                .delinquentSlotDistance = value.delinquent_slot_distance,
            }};
            break :blk try self.serializeParams(params);
        } else null;
        defer if (params_json) |value| self.allocator.free(value);

        const response = if (params_json) |value| try self.sendRequest("getVoteAccounts", value) else try self.sendNoParamsRequest("getVoteAccounts");
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

    pub fn getVoteAccounts(self: *RpcClient) !VoteAccounts {
        return try self.getVoteAccountsWithOptions(null);
    }

    pub fn getBlockProductionWithOptions(self: *RpcClient, options: ?BlockProductionQueryOptions) !BlockProduction {
        const BlockProductionConfig = struct {
            commitment: ?[]const u8 = null,
            identity: ?[]const u8 = null,
            range: ?struct {
                firstSlot: u64,
                lastSlot: ?u64 = null,
            } = null,
        };

        const params_json = if (options) |value| blk: {
            const params = .{BlockProductionConfig{
                .commitment = if (value.commitment) |entry| commitmentToString(entry) else null,
                .identity = value.identity,
                .range = if (value.first_slot) |first_slot|
                    .{
                        .firstSlot = first_slot,
                        .lastSlot = value.last_slot,
                    }
                else
                    null,
            }};
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

    pub fn getBlockProduction(self: *RpcClient, commitment: ?Commitment) !BlockProduction {
        return try self.getBlockProductionWithOptions(if (commitment) |value|
            BlockProductionQueryOptions{ .commitment = value }
        else
            null);
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
        const params_json = try self.serializeSendTransactionParams(signed_tx_base64, options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("sendTransaction", params_json);
        defer self.allocator.free(response);

        const signature = try self.parseResponse(response, []const u8);

        return try self.allocator.dupe(u8, signature);
    }

    pub fn simulateTransaction(
        self: *RpcClient,
        signed_tx_base64: []const u8,
        options: ?SimulateTransactionOptions,
    ) !SimulatedTransaction {
        const params_json = try self.serializeSimulateTransactionParams(signed_tx_base64, options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("simulateTransaction", params_json);
        defer self.allocator.free(response);

        try self.captureRpcError(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?struct {
                context: struct {
                    slot: u64 = 0,
                } = .{ .slot = 0 },
                value: RpcSimulatedTransactionResult = .{},
            } = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.result orelse return error.InvalidResponse;
        var simulation = SimulatedTransaction{};
        errdefer {
            if (simulation.accounts) |accounts| {
                for (accounts) |maybe_info| {
                    if (maybe_info) |info| {
                        self.allocator.free(info.owner);
                        if (info.data) |value| self.allocator.free(value);
                        if (info.data_encoding) |value| self.allocator.free(value);
                    }
                }
                self.allocator.free(accounts);
            }
            if (simulation.err_json) |value| self.allocator.free(value);
            if (simulation.inner_instructions_json) |value| self.allocator.free(value);
            if (simulation.logs) |logs| {
                for (logs) |entry| self.allocator.free(entry);
                self.allocator.free(logs);
            }
            if (simulation.replacement_blockhash) |value| self.allocator.free(value.blockhash);
            if (simulation.return_data) |value| {
                self.allocator.free(value.program_id);
                if (value.data) |entry| self.allocator.free(entry);
                if (value.data_encoding) |entry| self.allocator.free(entry);
            }
        }

        simulation.context_slot = result.context.slot;

        if (result.value.accounts) |accounts| {
            simulation.accounts = try self.cloneOptionalAccountInfos(accounts);
        }

        if (result.value.err) |value| {
            simulation.err_json = switch (value) {
                .null => null,
                .string => |text| try self.allocator.dupe(u8, text),
                else => try json.Stringify.valueAlloc(self.allocator, value, .{}),
            };
        }

        simulation.fee = result.value.fee;

        if (result.value.innerInstructions) |value| {
            simulation.inner_instructions_json = try json.Stringify.valueAlloc(self.allocator, value, .{});
        }

        if (result.value.logs) |logs| {
            simulation.logs = try self.cloneStringList(logs);
        }

        simulation.loaded_accounts_data_size = result.value.loadedAccountsDataSize;
        simulation.units_consumed = result.value.unitsConsumed;
        simulation.replacement_blockhash = if (result.value.replacementBlockhash) |value|
            LatestBlockhash{
                .blockhash = try self.allocator.dupe(u8, value.blockhash),
                .last_valid_block_height = value.lastValidBlockHeight,
            }
        else
            null;

        simulation.return_data = if (result.value.returnData) |value|
            SimulationReturnData{
                .program_id = try self.allocator.dupe(u8, value.programId),
                .data = if (value.data) |entry|
                    if (entry.len >= 1) try self.allocator.dupe(u8, entry[0]) else null
                else
                    null,
                .data_encoding = if (value.data) |entry|
                    if (entry.len >= 2) try self.allocator.dupe(u8, entry[1]) else null
                else
                    null,
            }
        else
            null;

        return simulation;
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

    pub fn getSignatureStatusWithOptions(
        self: *RpcClient,
        signature: []const u8,
        options: ?SignatureStatusesQueryOptions,
    ) !SignatureStatus {
        const signatures = [_][]const u8{signature};
        const params_json = try self.serializeSignatureStatusesParams(signatures[0..], options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSignatureStatuses", params_json);
        defer self.allocator.free(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?SignatureStatusesResult = null,
            @"error": ?RpcErrorDetail = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error" != null) {
            const err = parsed.value.@"error".?;
            self.last_error = RpcErrorDetail{
                .code = err.code,
                .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
            };
            return error.RpcError;
        }

        const result = parsed.value.result orelse return error.InvalidResponse;
        if (result.value.len == 0) return error.TransactionNotFound;

        const first = result.value[0] orelse return error.TransactionNotFound;

        return SignatureStatus{
            .confirmation_status = if (first.confirmationStatus) |value| try self.allocator.dupe(u8, value) else null,
            .has_error = first.err != null,
            .slot = first.slot,
            .confirmations = first.confirmations,
        };
    }

    pub fn getSignatureStatus(self: *RpcClient, signature: []const u8, commitment: ?Commitment) !SignatureStatus {
        return try self.getSignatureStatusWithOptions(
            signature,
            if (commitment) |value| .{ .commitment = value } else null,
        );
    }

    pub fn getSignatureStatusWithHistory(self: *RpcClient, signature: []const u8) !SignatureStatus {
        return try self.getSignatureStatusWithOptions(signature, .{ .search_transaction_history = true });
    }

    pub fn getSignatureStatusWithCommitmentAndHistory(
        self: *RpcClient,
        signature: []const u8,
        commitment: ?Commitment,
    ) !SignatureStatus {
        return try self.getSignatureStatusWithOptions(
            signature,
            .{
                .search_transaction_history = true,
                .commitment = commitment,
            },
        );
    }

    pub fn getSignatureStatusesWithOptions(
        self: *RpcClient,
        signatures: []const []const u8,
        options: ?SignatureStatusesQueryOptions,
    ) ![]?SignatureStatus {
        const params_json = try self.serializeSignatureStatusesParams(signatures, options);
        defer self.allocator.free(params_json);

        const response = try self.sendRequest("getSignatureStatuses", params_json);
        defer self.allocator.free(response);

        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?SignatureStatusesResult = null,
            @"error": ?RpcErrorDetail = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error" != null) {
            const err = parsed.value.@"error".?;
            self.last_error = RpcErrorDetail{
                .code = err.code,
                .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
            };
            return error.RpcError;
        }

        const result = parsed.value.result orelse return error.InvalidResponse;
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

    pub fn getSignatureStatuses(self: *RpcClient, signatures: []const []const u8, commitment: ?Commitment) ![]?SignatureStatus {
        return try self.getSignatureStatusesWithOptions(
            signatures,
            if (commitment) |value| .{ .commitment = value } else null,
        );
    }

    pub fn getSignatureStatusesWithHistory(self: *RpcClient, signatures: []const []const u8) ![]?SignatureStatus {
        return try self.getSignatureStatusesWithOptions(signatures, .{ .search_transaction_history = true });
    }

    pub fn getSignatureStatusesWithCommitmentAndHistory(
        self: *RpcClient,
        signatures: []const []const u8,
        commitment: ?Commitment,
    ) ![]?SignatureStatus {
        return try self.getSignatureStatusesWithOptions(
            signatures,
            .{
                .search_transaction_history = true,
                .commitment = commitment,
            },
        );
    }

    pub fn confirmTransaction(
        self: *RpcClient,
        signature: []const u8,
        commitment: ?Commitment,
        search_transaction_history: bool,
    ) !bool {
        const signature_status_options = if (search_transaction_history or commitment != null)
            SignatureStatusesQueryOptions{
                .search_transaction_history = search_transaction_history,
                .commitment = commitment,
            }
        else
            null;

        const status = self.getSignatureStatusWithOptions(
            signature,
            signature_status_options,
        ) catch |err| switch (err) {
            error.TransactionNotFound => return false,
            else => return err,
        };
        defer if (status.confirmation_status) |value| self.allocator.free(value);

        if (status.has_error) return false;
        return confirmationSatisfiesCommitment(status.confirmation_status, commitment);
    }

    pub fn getNumBlocksSinceSignatureConfirmation(
        self: *RpcClient,
        signature: []const u8,
        search_transaction_history: bool,
    ) !u64 {
        const status = try self.getSignatureStatusWithOptions(
            signature,
            if (search_transaction_history)
                SignatureStatusesQueryOptions{ .search_transaction_history = true }
            else
                null,
        );
        defer if (status.confirmation_status) |value| self.allocator.free(value);

        return status.confirmations orelse max_lockout_history + 1;
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
        return try self.getSignaturesForAddressWithOptions(
            address,
            .{
                .before = before,
                .until = until,
                .limit = limit,
                .commitment = commitment,
            },
        );
    }

    pub fn getSignaturesForAddressWithOptions(
        self: *RpcClient,
        address: []const u8,
        options: ?SignaturesForAddressOptions,
    ) ![]SignatureForAddress {
        const params = try self.serializeSignaturesForAddressParams(address, options);
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

    pub fn pollGetBalanceWithCommitmentAndTimeouts(
        self: *RpcClient,
        account: []const u8,
        commitment: ?Commitment,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !u64 {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
        var last_error: ?anyerror = null;

        while (std.time.milliTimestamp() < deadline) {
            const balance_result = self.getBalance(account, commitment);
            if (balance_result) |balance| {
                return balance;
            } else |err| {
                last_error = err;
            }

            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }

        if (last_error) |err| return err;
        return error.Timeout;
    }

    pub fn pollGetBalanceWithCommitment(self: *RpcClient, account: []const u8, commitment: ?Commitment) !u64 {
        return try self.pollGetBalanceWithCommitmentAndTimeouts(
            account,
            commitment,
            default_balance_poll_timeout_ms,
            default_balance_poll_interval_ms,
        );
    }

    pub fn waitForBalanceWithCommitmentAndTimeouts(
        self: *RpcClient,
        account: []const u8,
        expected_balance: ?u64,
        commitment: ?Commitment,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !u64 {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
        var last_error: ?anyerror = null;

        while (std.time.milliTimestamp() < deadline) {
            const balance_result = self.getBalance(account, commitment);
            if (balance_result) |balance| {
                last_error = null;
                if (expected_balance == null or balance == expected_balance.?) {
                    return balance;
                }
            } else |err| {
                last_error = err;
            }

            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }

        if (last_error) |err| return err;
        return error.Timeout;
    }

    pub fn waitForBalanceWithCommitment(
        self: *RpcClient,
        account: []const u8,
        expected_balance: ?u64,
        commitment: ?Commitment,
    ) !u64 {
        var run: usize = 0;

        while (true) {
            const balance_result = self.pollGetBalanceWithCommitment(account, commitment);
            if (expected_balance == null) return balance_result;

            if (balance_result) |balance| {
                if (balance == expected_balance.?) return balance;
            } else |err| {
                if (run == wait_for_balance_error_retries) return err;
            }

            run += 1;
        }
    }

    pub fn waitForSignatureStatus(
        self: *RpcClient,
        signature: []const u8,
        commitment: ?Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !void {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            const status_options = if (search_transaction_history or commitment != null)
                SignatureStatusesQueryOptions{
                    .search_transaction_history = search_transaction_history,
                    .commitment = commitment,
                }
            else
                null;

            const status = self.getSignatureStatusWithOptions(signature, status_options) catch |err| {
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
            if (confirmationSatisfiesCommitment(status.confirmation_status, commitment)) {
                return;
            }

            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }

        return error.TransactionNotConfirmed;
    }

    pub fn pollForSignature(self: *RpcClient, signature: []const u8, commitment: ?Commitment, search_transaction_history: bool) !void {
        try self.waitForSignatureStatus(
            signature,
            commitment,
            search_transaction_history,
            poll_for_signature_timeout_ms,
            signature_poll_interval_ms,
        );
    }

    pub fn pollForSignatureConfirmationWithTimeouts(
        self: *RpcClient,
        signature: []const u8,
        min_confirmed_blocks: u64,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !u64 {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            const status = self.getSignatureStatusWithOptions(
                signature,
                if (search_transaction_history)
                    SignatureStatusesQueryOptions{ .search_transaction_history = true }
                else
                    null,
            ) catch |err| switch (err) {
                error.TransactionNotFound => {
                    std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
                    continue;
                },
                else => return err,
            };
            defer if (status.confirmation_status) |value| self.allocator.free(value);

            if (status.has_error) return error.TransactionFailed;

            const confirmed_blocks = status.confirmations orelse max_lockout_history + 1;
            if (confirmed_blocks >= min_confirmed_blocks) return confirmed_blocks;

            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }

        return error.TransactionNotConfirmed;
    }

    pub fn pollForSignatureConfirmation(
        self: *RpcClient,
        signature: []const u8,
        min_confirmed_blocks: u64,
        search_transaction_history: bool,
    ) !u64 {
        return try self.pollForSignatureConfirmationWithTimeouts(
            signature,
            min_confirmed_blocks,
            search_transaction_history,
            poll_for_signature_confirmation_timeout_ms,
            signature_poll_interval_ms,
        );
    }

    pub fn sendTransactionAndConfirm(
        self: *RpcClient,
        signed_tx_base64: []const u8,
        options: ?SendTransactionOptions,
        commitment: ?Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        const signature = try self.sendTransaction(signed_tx_base64, options);
        errdefer self.allocator.free(signature);

        try self.waitForSignatureStatus(signature, commitment, search_transaction_history, timeout_ms, poll_interval_ms);

        return signature;
    }
};

fn acceptMockRootConnection(listener: *std.net.Server) ?std.net.Server.Connection {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = listener.stream.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    const ready = std.posix.poll(&poll_fds, 500) catch return null;
    if (ready == 0) return null;
    if (poll_fds[0].revents & std.posix.POLL.IN != std.posix.POLL.IN) return null;

    return listener.accept() catch return null;
}

fn runMockRootServer(listener: *std.net.Server, allocator: Allocator, response_body: []const u8) void {
    var connection = acceptMockRootConnection(listener) orelse return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var request_body_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&request_body_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request.respond(response_body, .{}) catch return;
}

fn runMockRootServerSequence(listener: *std.net.Server, allocator: Allocator, response_bodies: []const []const u8) void {
    for (response_bodies) |response_body| {
        var connection = acceptMockRootConnection(listener) orelse return;
        defer connection.stream.close();

        var receive_buffer: [4096]u8 = undefined;
        var request_body_buffer: [4096]u8 = undefined;
        var send_buffer: [4096]u8 = undefined;
        var connection_reader = connection.stream.reader(&receive_buffer);
        var connection_writer = connection.stream.writer(&send_buffer);
        var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

        var request = http_server.receiveHead() catch return;
        const body_length = request.head.content_length orelse 0;
        const request_body_reader = request.readerExpectNone(&request_body_buffer);
        const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
        defer allocator.free(request_body);

        request.respond(response_body, .{}) catch return;
    }
}

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

test "root.getLatestBlockhashResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":9},"value":{"blockhash":"Blockhash111111111111111111111111111111111111","lastValidBlockHeight":55}},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const blockhash_response = try client.getLatestBlockhashResponse(.confirmed);
    defer allocator.free(blockhash_response.value.blockhash);

    try std.testing.expectEqual(@as(u64, 9), blockhash_response.context_slot);
    try std.testing.expectEqualStrings("Blockhash111111111111111111111111111111111111", blockhash_response.value.blockhash);
    try std.testing.expectEqual(@as(u64, 55), blockhash_response.value.last_valid_block_height);
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

test "root.getBalanceResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":42},"value":9001},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const balance_response = try client.getBalanceResponse("Address11111111111111111111111111111111", .confirmed);
    try std.testing.expectEqual(@as(u64, 42), balance_response.context_slot);
    try std.testing.expectEqual(@as(u64, 9001), balance_response.value);
}

test "root.pollGetBalanceWithCommitmentAndTimeouts retries until success" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"node behind"}}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":44},"value":77},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const balance = try client.pollGetBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        .confirmed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 77), balance);
}

test "root.waitForBalanceWithCommitmentAndTimeouts waits for expected value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":45},"value":1},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":46},"value":5},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const balance = try client.waitForBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        5,
        .processed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 5), balance);
}

test "root.confirmTransaction checks transaction confirmed status" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[{"slot":10,"confirmations":1,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":[{"slot":11,"confirmations":2,"confirmationStatus":"finalized","err":null}]},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const confirmed = try client.confirmTransaction("Sig111111111111111111111111111111111111", .confirmed, false);
    try std.testing.expect(confirmed);
}

test "root.confirmTransaction returns false for missing signature" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":1},"value":[null]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const confirmed = try client.confirmTransaction("Sig111111111111111111111111111111111111", .processed, false);
    try std.testing.expect(!confirmed);
}

test "root.pollForSignatureConfirmationWithTimeouts waits for configured lockout" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":21},"value":[{"slot":21,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":22},"value":[{"slot":22,"confirmations":3,"confirmationStatus":"confirmed","err":null}]},"id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":23},"value":[{"slot":23,"confirmations":10,"confirmationStatus":"confirmed","err":null}]},"id":3}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const confirmed_blocks = try client.pollForSignatureConfirmationWithTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        false,
        500,
        10,
    );
    try std.testing.expectEqual(@as(u64, 10), confirmed_blocks);
}

test "root.getNumBlocksSinceSignatureConfirmation returns lockout fallback when confirmations missing" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":31},"value":[{"slot":31,"confirmationStatus":"confirmed","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const confirmed_blocks = try client.getNumBlocksSinceSignatureConfirmation("Sig111111111111111111111111111111111111", false);
    try std.testing.expectEqual(@as(u64, max_lockout_history + 1), confirmed_blocks);
}

test "root.getAccountInfo params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment_json = try client.serializeAccountParams(
        "Address11111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment_json = try client.serializeAccountParams(
        "Address11111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_options_json = try client.serializeAccountParams(
        "Address11111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 42,
            .encoding = .base64,
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(with_options_json);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"minContextSlot\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"length\":32") != null);
}

test "root.getUiAccount params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params_json = try client.serializeUiAccountParams(
        "Address11111111111111111111111111111111",
        .{
            .commitment = .confirmed,
            .min_context_slot = 55,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":55") != null);
}

test "root.getAccountInfoMaybeWithOptions returns null when account missing" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":1},"value":null},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const maybe_info = try client.getAccountInfoMaybeWithOptions("Address11111111111111111111111111111111", null);
    try std.testing.expect(maybe_info == null);
}

test "root.getAccountInfoResponseWithOptions preserves context slot" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":42},"value":{"data":["","base64"],"executable":false,"lamports":99,"owner":"Owner1111111111111111111111111111111111","rentEpoch":7,"space":0}},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const info_response = try client.getAccountInfoResponseWithOptions("Address11111111111111111111111111111111", null);
    try std.testing.expectEqual(@as(u64, 42), info_response.context_slot);
    try std.testing.expect(info_response.account != null);

    const info = info_response.account.?;
    defer client.freeOwnedAccountInfo(info);

    try std.testing.expectEqual(@as(u64, 99), info.lamports);
    try std.testing.expectEqualStrings("Owner1111111111111111111111111111111111", info.owner);
}

test "root.getUiAccountWithOptions returns account not found when account missing" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":1},"value":null},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    try std.testing.expectError(
        error.AccountNotFound,
        client.getUiAccountWithOptions("Address11111111111111111111111111111111", null),
    );
}

test "root.getMultipleUiAccountsResponseWithOptions preserves context slot" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":[{"data":{"program":"spl-token","parsed":{"type":"account"}},"executable":false,"lamports":1,"owner":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","rentEpoch":2,"space":165},null]},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const infos_response = try client.getMultipleUiAccountsResponseWithOptions(&.{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    }, null);
    defer {
        for (infos_response.accounts) |maybe_info| {
            if (maybe_info) |info| {
                client.allocator.free(info.owner);
                client.allocator.free(info.data_json);
            }
        }
        client.allocator.free(infos_response.accounts);
    }

    try std.testing.expectEqual(@as(u64, 77), infos_response.context_slot);
    try std.testing.expectEqual(@as(usize, 2), infos_response.accounts.len);
    try std.testing.expect(infos_response.accounts[0] != null);
    try std.testing.expect(infos_response.accounts[1] == null);
}

test "root.getMultipleUiAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const params_json = try client.serializeMultipleUiAccountsParams(addresses[0..], .{
        .commitment = .finalized,
        .min_context_slot = 77,
    });
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Address22222222222222222222222222222222\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":77") != null);
}

test "root.getMultipleAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const without_commitment_json = try client.serializeMultipleAccountsParams(addresses[0..], null);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address22222222222222222222222222222222\"") != null);

    const with_commitment_json = try client.serializeMultipleAccountsParams(
        addresses[0..],
        .{
            .commitment = .finalized,
            .min_context_slot = 88,
            .encoding = .base58,
            .data_slice_offset = 4,
            .data_slice_length = 16,
        },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"minContextSlot\":88") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"encoding\":\"base58\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"offset\":4") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"length\":16") != null);
}

test "root.getProgramAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment_json = try client.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Program1111111111111111111111111111111111\"") != null);

    const with_commitment_json = try client.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_filters_json = try client.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 99,
            .with_context = true,
            .sort_results = true,
            .data_size = 165,
            .memcmp_offset = 32,
            .memcmp_bytes = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(with_filters_json);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"minContextSlot\":99") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"withContext\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "sortResults") == null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"dataSize\":165") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"offset\":32") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"bytes\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"length\":32") != null);
}

test "root.getProgramUiAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "Program1111111111111111111111111111111111",
        .{
            .commitment = commitmentToString(.processed),
            .encoding = "jsonParsed",
        },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getProgramUiAccountsWithOptions params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params_json = try client.serializeProgramUiAccountsParams(
        "Program1111111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 111,
            .with_context = true,
            .sort_results = true,
            .data_size = 165,
            .memcmp_offset = 32,
            .memcmp_bytes = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":111") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"withContext\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "sortResults") == null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"dataSize\":165") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"offset\":32") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"bytes\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"length\":32") != null);
}

test "root.requestAirdrop params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const default_json = try client.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        null,
    );
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "12345") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"commitment\"") == null);

    const with_commitment_json = try client.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        .{ .commitment = .processed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);

    const with_blockhash_json = try client.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        .{ .recent_blockhash = "RecentBlockhash1111111111111111111111111111" },
    );
    defer allocator.free(with_blockhash_json);
    try std.testing.expect(std.mem.indexOf(u8, with_blockhash_json, "\"recentBlockhash\":\"RecentBlockhash1111111111111111111111111111\"") != null);
}

test "root.requestAirdropWithConfig returns signature copy" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":"Sig111111111111111111111111111111111111111111111111111111111111111111","id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const signature = try client.requestAirdropWithConfig(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        9001,
        .{
            .commitment = .processed,
            .recent_blockhash = "RecentBlockhash1111111111111111111111111111",
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
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

    const with_option = .{.{
        .commitment = commitmentToString(.confirmed),
        .excludeNonCirculatingAccountsList = true,
    }};
    const with_option_json = try client.serializeParams(with_option);
    defer allocator.free(with_option_json);

    try std.testing.expect(std.mem.indexOf(u8, with_option_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_option_json, "\"excludeNonCirculatingAccountsList\":true") != null);
}

test "root.getLargestAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const no_commitment = .{};
    const no_commitment_json = try client.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.eql(u8, no_commitment_json, "[]"));

    const with_commitment = .{.{ .commitment = commitmentToString(.confirmed) }};
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_filter = .{.{
        .commitment = commitmentToString(.finalized),
        .filter = largestAccountsFilterToString(.non_circulating),
    }};
    const with_filter_json = try client.serializeParams(with_filter);
    defer allocator.free(with_filter_json);
    try std.testing.expect(std.mem.indexOf(u8, with_filter_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filter_json, "\"filter\":\"nonCirculating\"") != null);
}

test "root.getTokenAccountBalance params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment = .{"TokenAcct1111111111111111111111111111111"};
    const without_commitment_json = try client.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"TokenAcct1111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "TokenAcct1111111111111111111111111111111",
        .{ .commitment = commitmentToString(.processed) },
    };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);
}

test "root.getTokenSupply params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment = .{"Mint111111111111111111111111111111111111"};
    const without_commitment_json = try client.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Mint111111111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "Mint111111111111111111111111111111111111",
        .{ .commitment = commitmentToString(.finalized) },
    };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getTokenLargestAccounts params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment = .{"Mint111111111111111111111111111111111111"};
    const without_commitment_json = try client.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Mint111111111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "Mint111111111111111111111111111111111111",
        .{ .commitment = commitmentToString(.confirmed) },
    };
    const with_commitment_json = try client.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getTokenAccountsByOwner params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const mint_filter = tokenAccountsFilterParams(.{ .mint = "Mint111111111111111111111111111111111111" });
    const mint_params = .{
        "Owner1111111111111111111111111111111111111",
        mint_filter,
        .{
            .commitment = commitmentToString(.confirmed),
            .encoding = "jsonParsed",
        },
    };
    const mint_params_json = try client.serializeParams(mint_params);
    defer allocator.free(mint_params_json);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"Owner1111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"mint\":\"Mint111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"commitment\":\"confirmed\"") != null);

    const program_filter = tokenAccountsFilterParams(.{ .program_id = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" });
    const program_params = .{
        "Owner1111111111111111111111111111111111111",
        program_filter,
        .{ .commitment = null, .encoding = "jsonParsed" },
    };
    const program_params_json = try client.serializeParams(program_params);
    defer allocator.free(program_params_json);
    try std.testing.expect(std.mem.indexOf(u8, program_params_json, "\"programId\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
}

test "root.getTokenAccountsByDelegate params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "Delegate11111111111111111111111111111111111",
        tokenAccountsFilterParams(.{ .mint = "Mint111111111111111111111111111111111111" }),
        .{
            .commitment = commitmentToString(.processed),
            .encoding = "jsonParsed",
        },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Delegate11111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"mint\":\"Mint111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.sendTransaction params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params_json = try client.serializeSendTransactionParams(
        "signed-transaction-base64",
        .{
            .skip_preflight = true,
            .preflight_commitment = .confirmed,
            .max_retries = 3,
            .min_context_slot = 456,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"signed-transaction-base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"preflightCommitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxRetries\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":456") != null);
}

test "root.simulateTransaction params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params_json = try client.serializeSimulateTransactionParams(
        "signed-transaction-base64",
        .{
            .sig_verify = true,
            .replace_recent_blockhash = true,
            .commitment = .finalized,
            .min_context_slot = 123,
            .inner_instructions = true,
            .accounts = .{
                .addresses = &.{
                    "Account11111111111111111111111111111111",
                    "Account22222222222222222222222222222222",
                },
                .encoding = .base64,
            },
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"signed-transaction-base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"replaceRecentBlockhash\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"innerInstructions\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"addresses\":[\"Account11111111111111111111111111111111\",\"Account22222222222222222222222222222222\"]") != null);
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

test "root.getBlockCommitment params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{321};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "321") != null);
}

test "root.getBlockWithOptions params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        456,
        .{
            .commitment = commitmentToString(.confirmed),
            .encoding = transactionEncodingToString(.jsonParsed),
            .transactionDetails = transactionDetailsToString(.signatures),
            .rewards = false,
            .maxSupportedTransactionVersion = @as(u8, 0),
        },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "456") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"transactionDetails\":\"signatures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"rewards\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxSupportedTransactionVersion\":0") != null);
}

test "root.getTransaction params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{
        "5h6xSignature111111111111111111111111111111111111",
        .{
            .commitment = commitmentToString(.finalized),
            .encoding = transactionEncodingToString(.json),
            .maxSupportedTransactionVersion = @as(u8, 0),
        },
    };
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"5h6xSignature111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxSupportedTransactionVersion\":0") != null);
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

test "root.parseGetTransactionResponse parses transaction object" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":123,\"version\":0},\"id\":1}";
    const transaction = try client.parseGetTransactionResponse(body);
    defer allocator.free(transaction.?);

    try std.testing.expect(transaction != null);
    try std.testing.expect(std.mem.indexOf(u8, transaction.?, "\"slot\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, transaction.?, "\"version\":0") != null);
}

test "root.parseGetTransactionResponse handles null transaction" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const transaction = try client.parseGetTransactionResponse(body);

    try std.testing.expect(transaction == null);
}

test "root.summarizeBlockJson extracts block summary" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const block_json =
        \\{"blockhash":"Blockhash111111111111111111111111111111111111","previousBlockhash":"Prev111111111111111111111111111111111111111","parentSlot":456,"blockHeight":123,"blockTime":1700000000,"transactions":[{"transaction":{}},{"transaction":{}}],"rewards":[{},{}]}
    ;

    const summary = try client.summarizeBlockJson(block_json);
    defer client.freeOwnedBlockSummary(summary);

    try std.testing.expectEqualStrings("Blockhash111111111111111111111111111111111111", summary.blockhash orelse "");
    try std.testing.expectEqualStrings("Prev111111111111111111111111111111111111111", summary.previous_blockhash orelse "");
    try std.testing.expectEqual(@as(u64, 456), summary.parent_slot);
    try std.testing.expectEqual(@as(?u64, 123), summary.block_height);
    try std.testing.expectEqual(@as(?i64, 1700000000), summary.block_time);
    try std.testing.expectEqual(@as(?usize, 2), summary.transaction_count);
    try std.testing.expectEqual(@as(?usize, 2), summary.rewards_count);
}

test "root.getBlockSummaryWithOptions fetches and summarizes block" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"blockhash":"Blockhash111111111111111111111111111111111111","previousBlockhash":"Prev111111111111111111111111111111111111111","parentSlot":88,"blockHeight":77,"blockTime":1700000200,"transactions":[{}],"rewards":[]},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const summary = try client.getBlockSummaryWithOptions(88, null);
    try std.testing.expect(summary != null);
    defer client.freeOwnedBlockSummary(summary.?);

    try std.testing.expectEqual(@as(u64, 88), summary.?.parent_slot);
    try std.testing.expectEqual(@as(?u64, 77), summary.?.block_height);
    try std.testing.expectEqual(@as(?usize, 1), summary.?.transaction_count);
    try std.testing.expectEqual(@as(?usize, 0), summary.?.rewards_count);
}

test "root.summarizeTransactionJson extracts transaction summary" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const transaction_json =
        \\{"slot":123,"blockTime":1700000100,"version":"legacy","meta":{"err":{"InstructionError":[0,{"Custom":1}]},"fee":5000,"logMessages":["a","b","c"]},"transaction":{"signatures":["sig1","sig2"]}}
    ;

    const summary = try client.summarizeTransactionJson(transaction_json);
    defer client.freeOwnedTransactionSummary(summary);

    try std.testing.expectEqual(@as(u64, 123), summary.slot);
    try std.testing.expectEqual(@as(?i64, 1700000100), summary.block_time);
    try std.testing.expectEqualStrings("legacy", summary.version orelse "");
    try std.testing.expectEqual(@as(?usize, 2), summary.signature_count);
    try std.testing.expectEqual(@as(?u64, 5000), summary.fee);
    try std.testing.expectEqual(@as(?usize, 3), summary.log_messages_count);
    try std.testing.expect(summary.has_error);
    try std.testing.expect(summary.error_json != null);
}

test "root.getTransactionSummaryWithOptions fetches and summarizes transaction" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"slot":55,"blockTime":1700000300,"version":0,"meta":{"err":null,"fee":7000,"logMessages":["a","b"]},"transaction":{"signatures":["sig-1"]}},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const summary = try client.getTransactionSummaryWithOptions("Signature111111111111111111111111111111111111", null);
    try std.testing.expect(summary != null);
    defer client.freeOwnedTransactionSummary(summary.?);

    try std.testing.expectEqual(@as(u64, 55), summary.?.slot);
    try std.testing.expectEqual(@as(?u64, 7000), summary.?.fee);
    try std.testing.expectEqual(@as(?usize, 2), summary.?.log_messages_count);
    try std.testing.expectEqual(@as(?usize, 1), summary.?.signature_count);
    try std.testing.expect(!summary.?.has_error);
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

test "root.getFeeForMessageResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":123},"value":5000},"id":1}
    ;

    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var client = try RpcClient.init(allocator, rpc_url);
    defer client.deinit();

    const fee_response = try client.getFeeForMessageResponse("AQAB", .processed);
    try std.testing.expectEqual(@as(u64, 123), fee_response.context_slot);
    try std.testing.expectEqual(@as(?u64, 5000), fee_response.value);
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

test "root.getInflationReward params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const no_config = .{addresses};
    const no_config_json = try client.serializeParams(no_config);
    defer allocator.free(no_config_json);
    try std.testing.expect(std.mem.indexOf(u8, no_config_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, no_config_json, "\"Address22222222222222222222222222222222\"") != null);

    const with_config = .{
        addresses,
        .{
            .commitment = commitmentToString(.confirmed),
            .epoch = @as(u64, 42),
        },
    };
    const with_config_json = try client.serializeParams(with_config);
    defer allocator.free(with_config_json);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"epoch\":42") != null);
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

test "root.getSlotLeader params serialization" {
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

test "root.getRecentPrioritizationFees params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const params = .{};
    const params_json = try client.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));

    const accounts = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };
    const filtered_params = .{accounts};
    const filtered_params_json = try client.serializeParams(filtered_params);
    defer allocator.free(filtered_params_json);

    try std.testing.expect(std.mem.indexOf(u8, filtered_params_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, filtered_params_json, "\"Address22222222222222222222222222222222\"") != null);
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

    const signatures = [_][]const u8{"signature"};

    const default_json = try client.serializeSignatureStatusesParams(signatures[0..], null);
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "searchTransactionHistory") == null);

    const with_history_json = try client.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true },
    );
    defer allocator.free(with_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "searchTransactionHistory") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "true") != null);

    const with_commitment_json = try client.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "commitment") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"confirmed\"") != null);

    const with_commitment_history_json = try client.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true, .commitment = .finalized },
    );
    defer allocator.free(with_commitment_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "searchTransactionHistory") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "\"finalized\"") != null);
}

test "root.getSignatureStatuses params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const signatures = [_][]const u8{ "sig-1", "sig-2" };

    const default_json = try client.serializeSignatureStatusesParams(signatures[0..], null);
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"sig-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"sig-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "searchTransactionHistory") == null);

    const with_history_json = try client.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true },
    );
    defer allocator.free(with_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"sig-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"sig-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "searchTransactionHistory") != null);
}

test "root.confirmationSatisfiesCommitment" {
    try std.testing.expect(confirmationSatisfiesCommitment("processed", null));
    try std.testing.expect(confirmationSatisfiesCommitment("confirmed", .processed));
    try std.testing.expect(confirmationSatisfiesCommitment("finalized", .confirmed));
    try std.testing.expect(!confirmationSatisfiesCommitment("processed", .confirmed));
    try std.testing.expect(!confirmationSatisfiesCommitment(null, .processed));
}

test "root.getSignaturesForAddress params serialization" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const without_commitment_json = try client.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment_json = try client.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getSignaturesForAddress params serialization with filters" {
    const allocator = std.testing.allocator;
    var client = try RpcClient.init(allocator, "https://example.com");
    defer client.deinit();

    const with_filters_json = try client.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        .{
            .before = "BeforeSig",
            .until = "UntilSig",
            .limit = @as(u64, 50),
            .commitment = .finalized,
            .min_context_slot = 789,
        },
    );
    defer allocator.free(with_filters_json);

    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"before\":\"BeforeSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"until\":\"UntilSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"limit\":50") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"minContextSlot\":789") != null);
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

    const with_config = .{.{
        .commitment = commitmentToString(.confirmed),
        .votePubkey = "Vote111111111111111111111111111111111111111",
        .keepUnstakedDelinquents = true,
        .delinquentSlotDistance = @as(u64, 128),
    }};
    const with_config_json = try client.serializeParams(with_config);
    defer allocator.free(with_config_json);

    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"votePubkey\":\"Vote111111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"keepUnstakedDelinquents\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"delinquentSlotDistance\":128") != null);
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

    const with_config = .{.{
        .commitment = commitmentToString(.confirmed),
        .identity = "Identity1111111111111111111111111111111111",
        .range = .{
            .firstSlot = @as(u64, 100),
            .lastSlot = @as(u64, 200),
        },
    }};
    const with_config_json = try client.serializeParams(with_config);
    defer allocator.free(with_config_json);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"identity\":\"Identity1111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"firstSlot\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"lastSlot\":200") != null);
}
