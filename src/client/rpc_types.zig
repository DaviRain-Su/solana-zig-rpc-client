const std = @import("std");
const json = std.json;
const sdk = @import("./sdk.zig");

pub const TransportStats = struct {
    request_count: usize = 0,
    elapsed_time_ms: u64 = 0,
    rate_limited_time_ms: u64 = 0,
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

pub fn OwnedRpcResult(comptime ResultType: type) type {
    return struct {
        allocator: std.mem.Allocator,
        arena: std.heap.ArenaAllocator,
        response_body: []u8,
        value: ResultType,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.allocator.free(self.response_body);
            self.* = undefined;
        }
    };
}

pub const RpcRequest = struct {
    method: []const u8,

    pub fn custom(method: []const u8) RpcRequest {
        return .{ .method = method };
    }

    pub const getAccountInfo: RpcRequest = .{ .method = "getAccountInfo" };
    pub const getBalance: RpcRequest = .{ .method = "getBalance" };
    pub const getBlock: RpcRequest = .{ .method = "getBlock" };
    pub const getBlockCommitment: RpcRequest = .{ .method = "getBlockCommitment" };
    pub const getBlockHeight: RpcRequest = .{ .method = "getBlockHeight" };
    pub const getBlockProduction: RpcRequest = .{ .method = "getBlockProduction" };
    pub const getBlockTime: RpcRequest = .{ .method = "getBlockTime" };
    pub const getBlocks: RpcRequest = .{ .method = "getBlocks" };
    pub const getBlocksWithLimit: RpcRequest = .{ .method = "getBlocksWithLimit" };
    pub const getClusterNodes: RpcRequest = .{ .method = "getClusterNodes" };
    pub const getEpochInfo: RpcRequest = .{ .method = "getEpochInfo" };
    pub const getEpochSchedule: RpcRequest = .{ .method = "getEpochSchedule" };
    pub const getFeatureActivationSlot: RpcRequest = .{ .method = "getFeatureActivationSlot" };
    pub const getFeeForMessage: RpcRequest = .{ .method = "getFeeForMessage" };
    pub const getFirstAvailableBlock: RpcRequest = .{ .method = "getFirstAvailableBlock" };
    pub const getGenesisHash: RpcRequest = .{ .method = "getGenesisHash" };
    pub const getHealth: RpcRequest = .{ .method = "getHealth" };
    pub const getHighestSnapshotSlot: RpcRequest = .{ .method = "getHighestSnapshotSlot" };
    pub const getIdentity: RpcRequest = .{ .method = "getIdentity" };
    pub const getInflationGovernor: RpcRequest = .{ .method = "getInflationGovernor" };
    pub const getInflationRate: RpcRequest = .{ .method = "getInflationRate" };
    pub const getInflationReward: RpcRequest = .{ .method = "getInflationReward" };
    pub const getLargestAccounts: RpcRequest = .{ .method = "getLargestAccounts" };
    pub const getLatestBlockhash: RpcRequest = .{ .method = "getLatestBlockhash" };
    pub const getLeaderSchedule: RpcRequest = .{ .method = "getLeaderSchedule" };
    pub const getMaxRetransmitSlot: RpcRequest = .{ .method = "getMaxRetransmitSlot" };
    pub const getMaxShredInsertSlot: RpcRequest = .{ .method = "getMaxShredInsertSlot" };
    pub const minimumLedgerSlot: RpcRequest = .{ .method = "minimumLedgerSlot" };
    pub const getMinimumBalanceForRentExemption: RpcRequest = .{ .method = "getMinimumBalanceForRentExemption" };
    pub const getMultipleAccounts: RpcRequest = .{ .method = "getMultipleAccounts" };
    pub const getProgramAccounts: RpcRequest = .{ .method = "getProgramAccounts" };
    pub const getRecentPerformanceSamples: RpcRequest = .{ .method = "getRecentPerformanceSamples" };
    pub const getRecentPrioritizationFees: RpcRequest = .{ .method = "getRecentPrioritizationFees" };
    pub const getSignatureStatuses: RpcRequest = .{ .method = "getSignatureStatuses" };
    pub const getSignaturesForAddress: RpcRequest = .{ .method = "getSignaturesForAddress" };
    pub const getSlot: RpcRequest = .{ .method = "getSlot" };
    pub const getSlotLeader: RpcRequest = .{ .method = "getSlotLeader" };
    pub const getSlotLeaders: RpcRequest = .{ .method = "getSlotLeaders" };
    pub const getStakeMinimumDelegation: RpcRequest = .{ .method = "getStakeMinimumDelegation" };
    pub const getSupply: RpcRequest = .{ .method = "getSupply" };
    pub const getTokenAccountBalance: RpcRequest = .{ .method = "getTokenAccountBalance" };
    pub const getTokenAccountsByDelegate: RpcRequest = .{ .method = "getTokenAccountsByDelegate" };
    pub const getTokenAccountsByOwner: RpcRequest = .{ .method = "getTokenAccountsByOwner" };
    pub const getTokenLargestAccounts: RpcRequest = .{ .method = "getTokenLargestAccounts" };
    pub const getTokenSupply: RpcRequest = .{ .method = "getTokenSupply" };
    pub const getTransaction: RpcRequest = .{ .method = "getTransaction" };
    pub const getTransactionCount: RpcRequest = .{ .method = "getTransactionCount" };
    pub const getVersion: RpcRequest = .{ .method = "getVersion" };
    pub const getVoteAccounts: RpcRequest = .{ .method = "getVoteAccounts" };
    pub const isBlockhashValid: RpcRequest = .{ .method = "isBlockhashValid" };
    pub const requestAirdrop: RpcRequest = .{ .method = "requestAirdrop" };
    pub const sendTransaction: RpcRequest = .{ .method = "sendTransaction" };
    pub const simulateTransaction: RpcRequest = .{ .method = "simulateTransaction" };
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

pub const NonceAccount = struct {
    authority: []const u8 = "",
    blockhash: []const u8 = "",
    lamports_per_signature: ?u64 = null,
};

pub const NonceAccountResponse = struct {
    context_slot: u64 = 0,
    account: ?NonceAccount = null,
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

pub const BlockhashQuerySource = enum {
    cluster,
    fixed,
    nonce_account,
};

pub const ResolvedBlockhash = struct {
    blockhash: []const u8 = "",
    source: BlockhashQuerySource = .cluster,
    context_slot: ?u64 = null,
    last_valid_block_height: ?u64 = null,
};

pub const BlockhashQuery = union(enum) {
    cluster: struct {
        commitment: ?Commitment = null,
    },
    fixed: []const u8,
    nonce_account: struct {
        pubkey: []const u8,
        commitment: ?Commitment = null,
    },
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

pub const VoteAccountResult = struct {
    votePubkey: []const u8 = "",
    nodePubkey: []const u8 = "",
    activatedStake: u64 = 0,
    commission: u64 = 0,
    epochCredits: ?[][]i64 = null,
    lastVote: ?u64 = null,
    epochVoteAccount: bool = false,
    rootSlot: ?u64 = null,
};

pub const RpcAccountInfoResult = struct {
    data: ?[]const []const u8 = null,
    executable: bool = false,
    lamports: u64 = 0,
    owner: []const u8 = "",
    rentEpoch: ?u64 = null,
    space: ?u64 = null,
};

pub const RpcTokenAmountResult = struct {
    amount: []const u8 = "",
    decimals: u8 = 0,
    uiAmount: ?f64 = null,
    uiAmountString: []const u8 = "",
};

pub const RpcProgramAccountResult = struct {
    pubkey: []const u8 = "",
    account: RpcAccountInfoResult = .{},
};

pub const RpcJsonParsedAccountInfoResult = struct {
    data: json.Value = .null,
    executable: bool = false,
    lamports: u64 = 0,
    owner: []const u8 = "",
    rentEpoch: ?u64 = null,
    space: ?u64 = null,
};

pub const RpcJsonParsedProgramAccountResult = struct {
    pubkey: []const u8 = "",
    account: RpcJsonParsedAccountInfoResult = .{},
};

pub const RpcSimulatedTransactionResult = struct {
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

pub const TransferBuildOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
};

pub const NonceTransferBuildOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
};

pub const SendTransferOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
    send_transaction_options: ?SendTransactionOptions = null,
};

pub const SendNonceTransferOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
    send_transaction_options: ?SendTransactionOptions = null,
};

pub const TransferOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
    send_transaction_options: ?SendTransactionOptions = null,
    commitment: ?Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const NonceTransferOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    blockhash_query: ?BlockhashQuery = null,
    send_transaction_options: ?SendTransactionOptions = null,
    commitment: ?Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
};

pub const NonceAccountBuildOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
};

pub const SendNonceAccountOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    send_transaction_options: ?SendTransactionOptions = null,
};

pub const NonceAccountOptions = struct {
    recent_blockhash: ?[]const u8 = null,
    blockhash_commitment: ?Commitment = null,
    send_transaction_options: ?SendTransactionOptions = null,
    commitment: ?Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = sdk.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = sdk.signature_poll_interval_ms,
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

pub const TokenAccountsFilterParams = struct {
    mint: ?[]const u8 = null,
    programId: ?[]const u8 = null,
};

pub fn commitmentParams(commitment: ?Commitment) struct { commitment: ?[]const u8 = null } {
    return .{ .commitment = if (commitment) |value| commitmentToString(value) else null };
}

pub fn commitmentToString(c: Commitment) []const u8 {
    return switch (c) {
        .processed => "processed",
        .confirmed => "confirmed",
        .finalized => "finalized",
    };
}

pub fn commitmentRank(value: Commitment) u8 {
    return switch (value) {
        .processed => 0,
        .confirmed => 1,
        .finalized => 2,
    };
}

pub fn confirmationStatusRank(value: []const u8) ?u8 {
    if (std.mem.eql(u8, value, "processed")) return 0;
    if (std.mem.eql(u8, value, "confirmed")) return 1;
    if (std.mem.eql(u8, value, "finalized")) return 2;
    return null;
}

pub fn confirmationSatisfiesCommitment(status: ?[]const u8, commitment: ?Commitment) bool {
    const status_value = status orelse return false;
    const status_rank = confirmationStatusRank(status_value) orelse return false;
    const required_rank = if (commitment) |value| commitmentRank(value) else commitmentRank(.processed);
    return status_rank >= required_rank;
}

pub fn transactionEncodingToString(value: TransactionEncoding) []const u8 {
    return switch (value) {
        .json => "json",
        .jsonParsed => "jsonParsed",
        .base58 => "base58",
        .base64 => "base64",
    };
}

pub fn accountEncodingToString(value: AccountEncoding) []const u8 {
    return switch (value) {
        .base58 => "base58",
        .base64 => "base64",
    };
}

pub fn transactionDetailsToString(value: TransactionDetails) []const u8 {
    return switch (value) {
        .full => "full",
        .accounts => "accounts",
        .signatures => "signatures",
        .none => "none",
    };
}

pub fn largestAccountsFilterToString(value: LargestAccountsFilter) []const u8 {
    return switch (value) {
        .circulating => "circulating",
        .non_circulating => "nonCirculating",
    };
}

pub fn tokenAccountsFilterParams(filter: TokenAccountsFilter) TokenAccountsFilterParams {
    return switch (filter) {
        .mint => |value| .{ .mint = value },
        .program_id => |value| .{ .programId = value },
    };
}
