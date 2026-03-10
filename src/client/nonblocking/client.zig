const std = @import("std");
const rpc_client = @import("../rpc_client/client.zig");
const lifecycle_methods = @import("../rpc_client/lifecycle.zig");
const rpc_types = @import("../rpc_types.zig");

const Allocator = std.mem.Allocator;
const AccountInfo = rpc_types.AccountInfo;
const AccountInfoResponse = rpc_types.AccountInfoResponse;
const BalanceResponse = rpc_types.BalanceResponse;
const BlockProduction = rpc_types.BlockProduction;
const ClusterNode = rpc_types.ClusterNode;
const Commitment = rpc_types.Commitment;
const EpochSchedule = rpc_types.EpochSchedule;
const EpochInfo = rpc_types.EpochInfo;
const InflationGovernor = rpc_types.InflationGovernor;
const InflationRate = rpc_types.InflationRate;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const JsonParsedProgramAccountsResponse = rpc_types.JsonParsedProgramAccountsResponse;
const LargestAccount = rpc_types.LargestAccount;
const LatestBlockhash = rpc_types.LatestBlockhash;
const LatestBlockhashResponse = rpc_types.LatestBlockhashResponse;
const LeaderSchedule = rpc_types.LeaderSchedule;
const MultipleAccountsResponse = rpc_types.MultipleAccountsResponse;
const MultipleUiAccountsResponse = rpc_types.MultipleUiAccountsResponse;
const ProgramAccount = rpc_types.ProgramAccount;
const ProgramAccountsResponse = rpc_types.ProgramAccountsResponse;
const ProgramAccountsQueryOptions = rpc_types.ProgramAccountsQueryOptions;
const SnapshotSlots = rpc_types.SnapshotSlots;
const Supply = rpc_types.Supply;
const TokenAmount = rpc_types.TokenAmount;
const TokenAccountsFilter = rpc_types.TokenAccountsFilter;
const TokenLargestAccount = rpc_types.TokenLargestAccount;
const UiAccountResponse = rpc_types.UiAccountResponse;
const VoteAccounts = rpc_types.VoteAccounts;

fn runGetSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getSlot(commitment);
}

fn runGetBlockHeight(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBlockHeight(commitment);
}

fn runGetTransactionCount(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTransactionCount(commitment);
}

fn runGetFirstAvailableBlock(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getFirstAvailableBlock(commitment);
}

fn runGetStakeMinimumDelegation(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getStakeMinimumDelegation(commitment);
}

fn runGetMinimumLedgerSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMinimumLedgerSlot();
}

fn runGetMaxRetransmitSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMaxRetransmitSlot();
}

fn runGetMaxShredInsertSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !u64 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMaxShredInsertSlot();
}

fn runGetBalance(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !BalanceResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBalanceResponse("Balance111111111111111111111111111111111111", commitment);
}

fn runGetBalanceForAddress(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    address: []const u8,
    commitment: ?Commitment,
) !BalanceResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBalanceResponse(address, commitment);
}

fn runGetAccountInfoResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !AccountInfoResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getAccountInfoResponse(account, commitment);
}

fn runGetAccountInfo(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !AccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getAccountInfo(account, commitment);
}

fn runGetAccountData(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) ![]const u8 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getAccountData(account, commitment);
}

fn runGetAccountInfoMaybe(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !?AccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getAccountInfoMaybe(account, commitment);
}

fn runGetMultipleAccountsResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    accounts: []const []const u8,
    commitment: ?Commitment,
) !MultipleAccountsResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMultipleAccountsResponse(accounts, commitment);
}

fn runGetMultipleAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    accounts: []const []const u8,
    commitment: ?Commitment,
) ![]?AccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMultipleAccounts(accounts, commitment);
}

fn runGetUiAccountResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !UiAccountResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getUiAccountResponse(account, commitment);
}

fn runGetUiAccount(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !JsonParsedAccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getUiAccount(account, commitment);
}

fn runGetUiAccountMaybe(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    account: []const u8,
    commitment: ?Commitment,
) !?JsonParsedAccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getUiAccountMaybe(account, commitment);
}

fn runGetMultipleUiAccountsResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    accounts: []const []const u8,
    commitment: ?Commitment,
) !MultipleUiAccountsResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMultipleUiAccountsResponse(accounts, commitment);
}

fn runGetMultipleUiAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    accounts: []const []const u8,
    commitment: ?Commitment,
) ![]?JsonParsedAccountInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getMultipleUiAccounts(accounts, commitment);
}

fn runGetProgramAccountsResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    program_id: []const u8,
    commitment: ?Commitment,
) !ProgramAccountsResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getProgramAccountsResponseWithOptions(
        program_id,
        if (commitment) |value| ProgramAccountsQueryOptions{ .commitment = value } else null,
    );
}

fn runGetProgramAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    program_id: []const u8,
    commitment: ?Commitment,
) ![]ProgramAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getProgramAccounts(program_id, commitment);
}

fn runGetProgramUiAccountsResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    program_id: []const u8,
    commitment: ?Commitment,
) !JsonParsedProgramAccountsResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getProgramUiAccountsResponseWithOptions(
        program_id,
        if (commitment) |value| ProgramAccountsQueryOptions{ .commitment = value } else null,
    );
}

fn runGetProgramUiAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    program_id: []const u8,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getProgramUiAccounts(program_id, commitment);
}

fn runGetTokenAccountsByOwner(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    owner: []const u8,
    filter: TokenAccountsFilter,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTokenAccountsByOwner(owner, filter, commitment);
}

fn runGetTokenAccountsByDelegate(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    delegate: []const u8,
    filter: TokenAccountsFilter,
    commitment: ?Commitment,
) ![]JsonParsedProgramAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTokenAccountsByDelegate(delegate, filter, commitment);
}

fn runGetTokenAccountBalance(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    token_account: []const u8,
    commitment: ?Commitment,
) !TokenAmount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTokenAccountBalance(token_account, commitment);
}

fn runGetTokenSupply(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    mint: []const u8,
    commitment: ?Commitment,
) !TokenAmount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTokenSupply(mint, commitment);
}

fn runGetTokenLargestAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    mint: []const u8,
    commitment: ?Commitment,
) ![]TokenLargestAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getTokenLargestAccounts(mint, commitment);
}

fn runGetSupply(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !Supply {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getSupply(commitment);
}

fn runGetLargestAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]LargestAccount {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLargestAccounts(commitment);
}

fn runGetEpochInfo(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !EpochInfo {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getEpochInfo(commitment);
}

fn runGetEpochSchedule(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !EpochSchedule {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getEpochSchedule();
}

fn runGetFeatureActivationSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !?u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getFeatureActivationSlot(
        "Feature111111111111111111111111111111111111",
        commitment,
    );
}

fn runGetFeatureActivationSlotForFeature(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    feature_id: []const u8,
    commitment: ?Commitment,
) !?u64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getFeatureActivationSlot(feature_id, commitment);
}

fn runGetBlockTime(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !?i64 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBlockTime(123);
}

fn runGetBlockTimeForSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    slot: u64,
) !?i64 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBlockTime(slot);
}

fn runGetHighestSnapshotSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !SnapshotSlots {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getHighestSnapshotSlot();
}

fn runGetInflationRate(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !InflationRate {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getInflationRate();
}

fn runGetInflationGovernor(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !InflationGovernor {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getInflationGovernor();
}

fn runGetLatestBlockhash(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !LatestBlockhash {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLatestBlockhash(commitment);
}

fn runGetNewLatestBlockhash(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getNewLatestBlockhash("old-blockhash");
}

fn runGetLatestBlockhashResponse(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !LatestBlockhashResponse {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLatestBlockhashResponse(commitment);
}

fn runGetSlotLeader(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getSlotLeader(commitment);
}

fn runGetHealth(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getHealth();
}

fn runGetIdentity(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getIdentity();
}

fn runGetClusterNodes(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]ClusterNode {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getClusterNodes();
}

fn runGetVoteAccounts(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !VoteAccounts {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getVoteAccounts();
}

fn runGetLeaderSchedule(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !?[]LeaderSchedule {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLeaderSchedule(null, null, commitment);
}

fn runGetLeaderScheduleForSlot(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    slot: u64,
) !?[]LeaderSchedule {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLeaderSchedule(slot, null, null);
}

fn runGetLeaderScheduleForIdentity(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    identity: []const u8,
    commitment: ?Commitment,
) !?[]LeaderSchedule {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getLeaderSchedule(null, identity, commitment);
}

fn runGetBlockProduction(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) !BlockProduction {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getBlockProduction(commitment);
}

fn runIsBlockhashValid(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    blockhash: []const u8,
    commitment: ?Commitment,
) !bool {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.isBlockhashValid(blockhash, commitment);
}

fn runGetSlotLeaders(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    start_slot: u64,
    limit: u64,
) ![][]const u8 {
    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getSlotLeaders(start_slot, limit);
}

fn runGetVersion(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getVersion();
}

fn runGetGenesisHash(
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    commitment: ?Commitment,
) ![]const u8 {
    _ = commitment;

    var client = try lifecycle_methods.initClient(
        rpc_client.RpcClient,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    defer client.deinit();
    return try client.getGenesisHash();
}

fn AsyncTask(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        ?Commitment,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        commitment: ?Commitment,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            commitment: ?Commitment,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .commitment = commitment,
            };
            errdefer allocator.free(self.endpoint);

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.commitment,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

fn AsyncTaskWithU64(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        u64,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        value: u64,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            value: u64,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .value = value,
            };
            errdefer allocator.free(self.endpoint);

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.value,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

fn AsyncTaskWithU64Pair(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        u64,
        u64,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        first: u64,
        second: u64,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            first: u64,
            second: u64,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .first = first,
                .second = second,
            };
            errdefer allocator.free(self.endpoint);

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.first,
                self.second,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

fn AsyncTaskWithStringAndCommitment(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        []const u8,
        ?Commitment,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        value: []const u8,
        commitment: ?Commitment,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            value: []const u8,
            commitment: ?Commitment,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .value = try allocator.dupe(u8, value),
                .commitment = commitment,
            };
            errdefer {
                allocator.free(self.endpoint);
                allocator.free(self.value);
            }

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.value,
                self.commitment,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                self.allocator.free(self.value);
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

fn AsyncTaskWithStringAndTokenAccountsFilterAndCommitment(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        []const u8,
        TokenAccountsFilter,
        ?Commitment,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        value: []const u8,
        filter: TokenAccountsFilter,
        commitment: ?Commitment,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            value: []const u8,
            filter: TokenAccountsFilter,
            commitment: ?Commitment,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .value = try allocator.dupe(u8, value),
                .filter = switch (filter) {
                    .mint => |entry| .{ .mint = try allocator.dupe(u8, entry) },
                    .program_id => |entry| .{ .program_id = try allocator.dupe(u8, entry) },
                },
                .commitment = commitment,
            };
            errdefer {
                allocator.free(self.endpoint);
                allocator.free(self.value);
                switch (self.filter) {
                    .mint => |entry| allocator.free(entry),
                    .program_id => |entry| allocator.free(entry),
                }
            }

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.value,
                self.filter,
                self.commitment,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                self.allocator.free(self.value);
                switch (self.filter) {
                    .mint => |entry| self.allocator.free(entry),
                    .program_id => |entry| self.allocator.free(entry),
                }
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

fn AsyncTaskWithStringListAndCommitment(
    comptime ResultType: type,
    comptime work_fn: *const fn (
        Allocator,
        []const u8,
        ?Commitment,
        ?u64,
        ?u64,
        []const []const u8,
        ?Commitment,
    ) anyerror!ResultType,
) type {
    return struct {
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: ?Commitment,
        request_timeout_ms: ?u64,
        confirm_transaction_initial_timeout_ms: ?u64,
        values: []const []const u8,
        commitment: ?Commitment,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        done: bool = false,
        result: ?Result = null,
        thread: ?std.Thread = null,

        const Self = @This();
        const Result = union(enum) {
            success: ResultType,
            failure: anyerror,
        };

        pub fn start(
            allocator: Allocator,
            endpoint: []const u8,
            default_commitment: ?Commitment,
            request_timeout_ms: ?u64,
            confirm_transaction_initial_timeout_ms: ?u64,
            values: []const []const u8,
            commitment: ?Commitment,
        ) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            const copied_values = try allocator.alloc([]const u8, values.len);
            errdefer allocator.free(copied_values);

            var copied_count: usize = 0;
            errdefer {
                for (copied_values[0..copied_count]) |value| allocator.free(value);
            }

            for (values, 0..) |value, index| {
                copied_values[index] = try allocator.dupe(u8, value);
                copied_count += 1;
            }

            self.* = .{
                .allocator = allocator,
                .endpoint = try allocator.dupe(u8, endpoint),
                .default_commitment = default_commitment,
                .request_timeout_ms = request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
                .values = copied_values,
                .commitment = commitment,
            };
            errdefer {
                allocator.free(self.endpoint);
                for (self.values) |value| allocator.free(value);
                allocator.free(self.values);
            }

            self.thread = try std.Thread.spawn(.{}, Self.run, .{self});
            return self;
        }

        fn run(self: *Self) void {
            const value = work_fn(
                self.allocator,
                self.endpoint,
                self.default_commitment,
                self.request_timeout_ms,
                self.confirm_transaction_initial_timeout_ms,
                self.values,
                self.commitment,
            ) catch |err| {
                self.complete(.{ .failure = err });
                return;
            };
            self.complete(.{ .success = value });
        }

        fn complete(self: *Self, result: Result) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.result = result;
            self.done = true;
            self.cond.broadcast();
        }

        pub fn isDone(self: *const Self) bool {
            const mutable_self: *Self = @constCast(self);
            mutable_self.mutex.lock();
            defer mutable_self.mutex.unlock();
            return mutable_self.done;
        }

        pub fn wait(self: *Self) anyerror!ResultType {
            self.mutex.lock();
            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
            const result = self.result.?;
            self.mutex.unlock();

            if (self.thread) |thread| {
                thread.join();
                self.thread = null;
            }

            defer {
                self.allocator.free(self.endpoint);
                for (self.values) |value| self.allocator.free(value);
                self.allocator.free(self.values);
                self.allocator.destroy(self);
            }

            return switch (result) {
                .success => |value| value,
                .failure => |err| err,
            };
        }
    };
}

pub const NonblockingRpcClient = struct {
    allocator: Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,

    pub const Options = struct {
        endpoint: []const u8,
        commitment: ?Commitment = null,
        request_timeout_ms: ?u64 = null,
        confirm_transaction_initial_timeout_ms: ?u64 = null,
    };

    pub const SlotTask = AsyncTask(u64, runGetSlot);
    pub const BlockHeightTask = AsyncTask(u64, runGetBlockHeight);
    pub const TransactionCountTask = AsyncTask(u64, runGetTransactionCount);
    pub const FirstAvailableBlockTask = AsyncTask(u64, runGetFirstAvailableBlock);
    pub const StakeMinimumDelegationTask = AsyncTask(u64, runGetStakeMinimumDelegation);
    pub const MinimumLedgerSlotTask = AsyncTask(u64, runGetMinimumLedgerSlot);
    pub const MaxRetransmitSlotTask = AsyncTask(u64, runGetMaxRetransmitSlot);
    pub const MaxShredInsertSlotTask = AsyncTask(u64, runGetMaxShredInsertSlot);
    pub const BalanceTask = AsyncTask(BalanceResponse, runGetBalance);
    pub const BalanceForAddressTask = AsyncTaskWithStringAndCommitment(BalanceResponse, runGetBalanceForAddress);
    pub const AccountInfoResponseTask = AsyncTaskWithStringAndCommitment(AccountInfoResponse, runGetAccountInfoResponse);
    pub const AccountInfoTask = AsyncTaskWithStringAndCommitment(AccountInfo, runGetAccountInfo);
    pub const AccountDataTask = AsyncTaskWithStringAndCommitment([]const u8, runGetAccountData);
    pub const MaybeAccountInfoTask = AsyncTaskWithStringAndCommitment(?AccountInfo, runGetAccountInfoMaybe);
    pub const MultipleAccountsResponseTask = AsyncTaskWithStringListAndCommitment(MultipleAccountsResponse, runGetMultipleAccountsResponse);
    pub const MultipleAccountsTask = AsyncTaskWithStringListAndCommitment([]?AccountInfo, runGetMultipleAccounts);
    pub const UiAccountResponseTask = AsyncTaskWithStringAndCommitment(UiAccountResponse, runGetUiAccountResponse);
    pub const UiAccountTask = AsyncTaskWithStringAndCommitment(JsonParsedAccountInfo, runGetUiAccount);
    pub const MaybeUiAccountTask = AsyncTaskWithStringAndCommitment(?JsonParsedAccountInfo, runGetUiAccountMaybe);
    pub const MultipleUiAccountsResponseTask = AsyncTaskWithStringListAndCommitment(MultipleUiAccountsResponse, runGetMultipleUiAccountsResponse);
    pub const MultipleUiAccountsTask = AsyncTaskWithStringListAndCommitment([]?JsonParsedAccountInfo, runGetMultipleUiAccounts);
    pub const ProgramAccountsResponseTask = AsyncTaskWithStringAndCommitment(ProgramAccountsResponse, runGetProgramAccountsResponse);
    pub const ProgramAccountsTask = AsyncTaskWithStringAndCommitment([]ProgramAccount, runGetProgramAccounts);
    pub const ProgramUiAccountsResponseTask = AsyncTaskWithStringAndCommitment(JsonParsedProgramAccountsResponse, runGetProgramUiAccountsResponse);
    pub const ProgramUiAccountsTask = AsyncTaskWithStringAndCommitment([]JsonParsedProgramAccount, runGetProgramUiAccounts);
    pub const TokenAccountsByOwnerTask = AsyncTaskWithStringAndTokenAccountsFilterAndCommitment([]JsonParsedProgramAccount, runGetTokenAccountsByOwner);
    pub const TokenAccountsByDelegateTask = AsyncTaskWithStringAndTokenAccountsFilterAndCommitment([]JsonParsedProgramAccount, runGetTokenAccountsByDelegate);
    pub const TokenAccountBalanceTask = AsyncTaskWithStringAndCommitment(TokenAmount, runGetTokenAccountBalance);
    pub const TokenSupplyTask = AsyncTaskWithStringAndCommitment(TokenAmount, runGetTokenSupply);
    pub const TokenLargestAccountsTask = AsyncTaskWithStringAndCommitment([]TokenLargestAccount, runGetTokenLargestAccounts);
    pub const SupplyTask = AsyncTask(Supply, runGetSupply);
    pub const LargestAccountsTask = AsyncTask([]LargestAccount, runGetLargestAccounts);
    pub const EpochInfoTask = AsyncTask(EpochInfo, runGetEpochInfo);
    pub const EpochScheduleTask = AsyncTask(EpochSchedule, runGetEpochSchedule);
    pub const FeatureActivationSlotTask = AsyncTask(?u64, runGetFeatureActivationSlot);
    pub const FeatureActivationSlotForFeatureTask = AsyncTaskWithStringAndCommitment(?u64, runGetFeatureActivationSlotForFeature);
    pub const BlockTimeTask = AsyncTask(?i64, runGetBlockTime);
    pub const BlockTimeForSlotTask = AsyncTaskWithU64(?i64, runGetBlockTimeForSlot);
    pub const HighestSnapshotSlotTask = AsyncTask(SnapshotSlots, runGetHighestSnapshotSlot);
    pub const InflationRateTask = AsyncTask(InflationRate, runGetInflationRate);
    pub const InflationGovernorTask = AsyncTask(InflationGovernor, runGetInflationGovernor);
    pub const LatestBlockhashTask = AsyncTask(LatestBlockhash, runGetLatestBlockhash);
    pub const LatestBlockhashResponseTask = AsyncTask(LatestBlockhashResponse, runGetLatestBlockhashResponse);
    pub const NewLatestBlockhashTask = AsyncTask([]const u8, runGetNewLatestBlockhash);
    pub const SlotLeaderTask = AsyncTask([]const u8, runGetSlotLeader);
    pub const HealthTask = AsyncTask([]const u8, runGetHealth);
    pub const IdentityTask = AsyncTask([]const u8, runGetIdentity);
    pub const ClusterNodesTask = AsyncTask([]ClusterNode, runGetClusterNodes);
    pub const VoteAccountsTask = AsyncTask(VoteAccounts, runGetVoteAccounts);
    pub const LeaderScheduleTask = AsyncTask(?[]LeaderSchedule, runGetLeaderSchedule);
    pub const LeaderScheduleForSlotTask = AsyncTaskWithU64(?[]LeaderSchedule, runGetLeaderScheduleForSlot);
    pub const LeaderScheduleForIdentityTask = AsyncTaskWithStringAndCommitment(?[]LeaderSchedule, runGetLeaderScheduleForIdentity);
    pub const BlockProductionTask = AsyncTask(BlockProduction, runGetBlockProduction);
    pub const BlockhashValidityTask = AsyncTaskWithStringAndCommitment(bool, runIsBlockhashValid);
    pub const SlotLeadersTask = AsyncTaskWithU64Pair([][]const u8, runGetSlotLeaders);
    pub const VersionTask = AsyncTask([]const u8, runGetVersion);
    pub const GenesisHashTask = AsyncTask([]const u8, runGetGenesisHash);

    pub fn init(allocator: Allocator, endpoint: []const u8) !NonblockingRpcClient {
        return initWithOptions(allocator, .{ .endpoint = endpoint });
    }

    pub fn initWithOptions(allocator: Allocator, options: Options) !NonblockingRpcClient {
        return .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, options.endpoint),
            .default_commitment = options.commitment,
            .request_timeout_ms = options.request_timeout_ms,
            .confirm_transaction_initial_timeout_ms = options.confirm_transaction_initial_timeout_ms,
        };
    }

    pub fn new(allocator: Allocator, endpoint: []const u8) !NonblockingRpcClient {
        return init(allocator, endpoint);
    }

    pub fn newWithOptions(allocator: Allocator, options: Options) !NonblockingRpcClient {
        return initWithOptions(allocator, options);
    }

    pub fn newWithCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        default_commitment: Commitment,
    ) !NonblockingRpcClient {
        return initWithOptions(allocator, .{
            .endpoint = endpoint,
            .commitment = default_commitment,
        });
    }

    pub fn newWithTimeout(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
    ) !NonblockingRpcClient {
        return initWithOptions(allocator, .{
            .endpoint = endpoint,
            .request_timeout_ms = timeout_ms,
        });
    }

    pub fn newWithTimeoutAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
        default_commitment: Commitment,
    ) !NonblockingRpcClient {
        return initWithOptions(allocator, .{
            .endpoint = endpoint,
            .commitment = default_commitment,
            .request_timeout_ms = timeout_ms,
        });
    }

    pub fn newWithTimeoutsAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        request_timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        default_commitment: Commitment,
    ) !NonblockingRpcClient {
        return initWithOptions(allocator, .{
            .endpoint = endpoint,
            .commitment = default_commitment,
            .request_timeout_ms = request_timeout_ms,
            .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
        });
    }

    pub fn deinit(self: *NonblockingRpcClient) void {
        self.allocator.free(self.endpoint);
        self.* = undefined;
    }

    pub fn url(self: *const NonblockingRpcClient) []const u8 {
        return self.endpoint;
    }

    pub fn getDefaultCommitment(self: *const NonblockingRpcClient) ?Commitment {
        return self.default_commitment;
    }

    pub fn getRequestTimeoutMs(self: *const NonblockingRpcClient) ?u64 {
        return self.request_timeout_ms;
    }

    pub fn getConfirmTransactionInitialTimeoutMs(self: *const NonblockingRpcClient) ?u64 {
        return self.confirm_transaction_initial_timeout_ms;
    }

    pub fn getSlotAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*SlotTask {
        return SlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getLatestBlockhashAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*LatestBlockhashTask {
        return LatestBlockhashTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getBlockHeightAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*BlockHeightTask {
        return BlockHeightTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getTransactionCountAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*TransactionCountTask {
        return TransactionCountTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getFirstAvailableBlockAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*FirstAvailableBlockTask {
        return FirstAvailableBlockTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getStakeMinimumDelegationAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*StakeMinimumDelegationTask {
        return StakeMinimumDelegationTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getMinimumLedgerSlotAsync(self: *const NonblockingRpcClient) !*MinimumLedgerSlotTask {
        return MinimumLedgerSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getMaxRetransmitSlotAsync(self: *const NonblockingRpcClient) !*MaxRetransmitSlotTask {
        return MaxRetransmitSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getMaxShredInsertSlotAsync(self: *const NonblockingRpcClient) !*MaxShredInsertSlotTask {
        return MaxShredInsertSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getBalanceAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*BalanceTask {
        return BalanceTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getBalanceForAddressAsync(
        self: *const NonblockingRpcClient,
        address: []const u8,
        commitment: ?Commitment,
    ) !*BalanceForAddressTask {
        return BalanceForAddressTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            address,
            commitment,
        );
    }

    pub fn getAccountInfoResponseAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*AccountInfoResponseTask {
        return AccountInfoResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getAccountInfoAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*AccountInfoTask {
        return AccountInfoTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getAccountDataAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*AccountDataTask {
        return AccountDataTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getAccountInfoMaybeAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*MaybeAccountInfoTask {
        return MaybeAccountInfoTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getMultipleAccountsResponseAsync(
        self: *const NonblockingRpcClient,
        accounts: []const []const u8,
        commitment: ?Commitment,
    ) !*MultipleAccountsResponseTask {
        return MultipleAccountsResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            accounts,
            commitment,
        );
    }

    pub fn getMultipleAccountsAsync(
        self: *const NonblockingRpcClient,
        accounts: []const []const u8,
        commitment: ?Commitment,
    ) !*MultipleAccountsTask {
        return MultipleAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            accounts,
            commitment,
        );
    }

    pub fn getUiAccountResponseAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*UiAccountResponseTask {
        return UiAccountResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getUiAccountAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*UiAccountTask {
        return UiAccountTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getUiAccountMaybeAsync(
        self: *const NonblockingRpcClient,
        account: []const u8,
        commitment: ?Commitment,
    ) !*MaybeUiAccountTask {
        return MaybeUiAccountTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            account,
            commitment,
        );
    }

    pub fn getMultipleUiAccountsResponseAsync(
        self: *const NonblockingRpcClient,
        accounts: []const []const u8,
        commitment: ?Commitment,
    ) !*MultipleUiAccountsResponseTask {
        return MultipleUiAccountsResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            accounts,
            commitment,
        );
    }

    pub fn getMultipleUiAccountsAsync(
        self: *const NonblockingRpcClient,
        accounts: []const []const u8,
        commitment: ?Commitment,
    ) !*MultipleUiAccountsTask {
        return MultipleUiAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            accounts,
            commitment,
        );
    }

    pub fn getProgramAccountsResponseAsync(
        self: *const NonblockingRpcClient,
        program_id: []const u8,
        commitment: ?Commitment,
    ) !*ProgramAccountsResponseTask {
        return ProgramAccountsResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            program_id,
            commitment,
        );
    }

    pub fn getProgramAccountsAsync(
        self: *const NonblockingRpcClient,
        program_id: []const u8,
        commitment: ?Commitment,
    ) !*ProgramAccountsTask {
        return ProgramAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            program_id,
            commitment,
        );
    }

    pub fn getProgramUiAccountsResponseAsync(
        self: *const NonblockingRpcClient,
        program_id: []const u8,
        commitment: ?Commitment,
    ) !*ProgramUiAccountsResponseTask {
        return ProgramUiAccountsResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            program_id,
            commitment,
        );
    }

    pub fn getProgramUiAccountsAsync(
        self: *const NonblockingRpcClient,
        program_id: []const u8,
        commitment: ?Commitment,
    ) !*ProgramUiAccountsTask {
        return ProgramUiAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            program_id,
            commitment,
        );
    }

    pub fn getTokenAccountsByOwnerAsync(
        self: *const NonblockingRpcClient,
        owner: []const u8,
        filter: TokenAccountsFilter,
        commitment: ?Commitment,
    ) !*TokenAccountsByOwnerTask {
        return TokenAccountsByOwnerTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            owner,
            filter,
            commitment,
        );
    }

    pub fn getTokenAccountsByDelegateAsync(
        self: *const NonblockingRpcClient,
        delegate: []const u8,
        filter: TokenAccountsFilter,
        commitment: ?Commitment,
    ) !*TokenAccountsByDelegateTask {
        return TokenAccountsByDelegateTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            delegate,
            filter,
            commitment,
        );
    }

    pub fn getTokenAccountBalanceAsync(
        self: *const NonblockingRpcClient,
        token_account: []const u8,
        commitment: ?Commitment,
    ) !*TokenAccountBalanceTask {
        return TokenAccountBalanceTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            token_account,
            commitment,
        );
    }

    pub fn getTokenSupplyAsync(
        self: *const NonblockingRpcClient,
        mint: []const u8,
        commitment: ?Commitment,
    ) !*TokenSupplyTask {
        return TokenSupplyTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            mint,
            commitment,
        );
    }

    pub fn getTokenLargestAccountsAsync(
        self: *const NonblockingRpcClient,
        mint: []const u8,
        commitment: ?Commitment,
    ) !*TokenLargestAccountsTask {
        return TokenLargestAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            mint,
            commitment,
        );
    }

    pub fn getSupplyAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*SupplyTask {
        return SupplyTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getLargestAccountsAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*LargestAccountsTask {
        return LargestAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getEpochInfoAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*EpochInfoTask {
        return EpochInfoTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getEpochScheduleAsync(self: *const NonblockingRpcClient) !*EpochScheduleTask {
        return EpochScheduleTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getFeatureActivationSlotAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*FeatureActivationSlotTask {
        return FeatureActivationSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getFeatureActivationSlotForFeatureAsync(
        self: *const NonblockingRpcClient,
        feature_id: []const u8,
        commitment: ?Commitment,
    ) !*FeatureActivationSlotForFeatureTask {
        return FeatureActivationSlotForFeatureTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            feature_id,
            commitment,
        );
    }

    pub fn getBlockTimeAsync(self: *const NonblockingRpcClient) !*BlockTimeTask {
        return BlockTimeTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getBlockTimeForSlotAsync(
        self: *const NonblockingRpcClient,
        slot: u64,
    ) !*BlockTimeForSlotTask {
        return BlockTimeForSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            slot,
        );
    }

    pub fn getHighestSnapshotSlotAsync(self: *const NonblockingRpcClient) !*HighestSnapshotSlotTask {
        return HighestSnapshotSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getInflationRateAsync(self: *const NonblockingRpcClient) !*InflationRateTask {
        return InflationRateTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getInflationGovernorAsync(self: *const NonblockingRpcClient) !*InflationGovernorTask {
        return InflationGovernorTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getLatestBlockhashResponseAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*LatestBlockhashResponseTask {
        return LatestBlockhashResponseTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getNewLatestBlockhashAsync(self: *const NonblockingRpcClient) !*NewLatestBlockhashTask {
        return NewLatestBlockhashTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getGenesisHashAsync(self: *const NonblockingRpcClient) !*GenesisHashTask {
        return GenesisHashTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getSlotLeaderAsync(self: *const NonblockingRpcClient, commitment: ?Commitment) !*SlotLeaderTask {
        return SlotLeaderTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getHealthAsync(self: *const NonblockingRpcClient) !*HealthTask {
        return HealthTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getIdentityAsync(self: *const NonblockingRpcClient) !*IdentityTask {
        return IdentityTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getClusterNodesAsync(self: *const NonblockingRpcClient) !*ClusterNodesTask {
        return ClusterNodesTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getVoteAccountsAsync(self: *const NonblockingRpcClient) !*VoteAccountsTask {
        return VoteAccountsTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }

    pub fn getLeaderScheduleAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*LeaderScheduleTask {
        return LeaderScheduleTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn getLeaderScheduleForSlotAsync(
        self: *const NonblockingRpcClient,
        slot: u64,
    ) !*LeaderScheduleForSlotTask {
        return LeaderScheduleForSlotTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            slot,
        );
    }

    pub fn getLeaderScheduleForIdentityAsync(
        self: *const NonblockingRpcClient,
        identity: []const u8,
        commitment: ?Commitment,
    ) !*LeaderScheduleForIdentityTask {
        return LeaderScheduleForIdentityTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            identity,
            commitment,
        );
    }

    pub fn getBlockProductionAsync(
        self: *const NonblockingRpcClient,
        commitment: ?Commitment,
    ) !*BlockProductionTask {
        return BlockProductionTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn isBlockhashValidAsync(
        self: *const NonblockingRpcClient,
        blockhash: []const u8,
        commitment: ?Commitment,
    ) !*BlockhashValidityTask {
        return BlockhashValidityTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            blockhash,
            commitment,
        );
    }

    pub fn getSlotLeadersAsync(
        self: *const NonblockingRpcClient,
        start_slot: u64,
        limit: u64,
    ) !*SlotLeadersTask {
        return SlotLeadersTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            start_slot,
            limit,
        );
    }

    pub fn getVersionAsync(self: *const NonblockingRpcClient) !*VersionTask {
        return VersionTask.start(
            self.allocator,
            self.endpoint,
            self.default_commitment,
            self.request_timeout_ms,
            self.confirm_transaction_initial_timeout_ms,
            null,
        );
    }
};
