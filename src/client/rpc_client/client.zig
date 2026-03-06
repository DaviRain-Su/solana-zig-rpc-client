const std = @import("std");
const rpc_types = @import("../rpc_types.zig");

const lifecycle_methods = @import("./lifecycle.zig");
const owned_methods = @import("./owned.zig");
const response_methods = @import("./response.zig");
const transport_methods = @import("./transport.zig");
const account_methods = @import("./accounts.zig");
const asset_methods = @import("./assets.zig");
const ledger_methods = @import("./ledger.zig");
const network_methods = @import("./network.zig");
const program_methods = @import("./programs.zig");
const transfer_methods = @import("./transfers.zig");
const transaction_methods = @import("./transactions.zig");

const Allocator = std.mem.Allocator;
const Commitment = rpc_types.Commitment;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const TransportStats = rpc_types.TransportStats;

pub const RpcClient = struct {
    allocator: Allocator,
    endpoint: []const u8,
    http_client: std.http.Client,
    request_id: u64,
    default_commitment: ?Commitment,
    last_error: ?RpcErrorDetail,
    transport_stats: TransportStats,

    pub const serializeParams = response_methods.serializeParams;
    pub const parseResponse = response_methods.parseResponse;
    pub const captureRpcError = response_methods.captureRpcError;
    pub const cloneAccountInfo = owned_methods.cloneAccountInfo;
    pub const freeOwnedAccountInfo = owned_methods.freeOwnedAccountInfo;
    pub const cloneOptionalAccountInfos = owned_methods.cloneOptionalAccountInfos;
    pub const cloneOptionalJsonParsedAccountInfos = owned_methods.cloneOptionalJsonParsedAccountInfos;
    pub const cloneStringList = owned_methods.cloneStringList;
    pub const cloneJsonParsedAccountInfo = owned_methods.cloneJsonParsedAccountInfo;
    pub const cloneProgramAccounts = owned_methods.cloneProgramAccounts;
    pub const cloneJsonParsedProgramAccounts = owned_methods.cloneJsonParsedProgramAccounts;

    pub const serializeAccountParams = account_methods.serializeAccountParams;
    pub const serializeMultipleAccountsParams = account_methods.serializeMultipleAccountsParams;
    pub const serializeUiAccountParams = account_methods.serializeUiAccountParams;
    pub const serializeMultipleUiAccountsParams = account_methods.serializeMultipleUiAccountsParams;
    pub const getAccountInfoResponseWithOptions = account_methods.getAccountInfoResponseWithOptions;
    pub const getAccountInfoResponseWithConfig = account_methods.getAccountInfoResponseWithConfig;
    pub const getAccountInfoMaybeWithOptions = account_methods.getAccountInfoMaybeWithOptions;
    pub const getAccountInfoMaybeWithConfig = account_methods.getAccountInfoMaybeWithConfig;
    pub const getAccountInfoWithOptions = account_methods.getAccountInfoWithOptions;
    pub const getAccountInfoWithConfig = account_methods.getAccountInfoWithConfig;
    pub const getAccountInfoResponse = account_methods.getAccountInfoResponse;
    pub const getAccountInfoMaybe = account_methods.getAccountInfoMaybe;
    pub const getAccount = account_methods.getAccount;
    pub const getAccountWithCommitment = account_methods.getAccountWithCommitment;
    pub const getAccountWithConfig = account_methods.getAccountWithConfig;
    pub const getAccountInfo = account_methods.getAccountInfo;
    pub const getAccountDataWithOptions = account_methods.getAccountDataWithOptions;
    pub const getAccountDataWithConfig = account_methods.getAccountDataWithConfig;
    pub const getAccountData = account_methods.getAccountData;
    pub const getUiAccountResponseWithOptions = account_methods.getUiAccountResponseWithOptions;
    pub const getUiAccountResponseWithConfig = account_methods.getUiAccountResponseWithConfig;
    pub const getUiAccountMaybeWithOptions = account_methods.getUiAccountMaybeWithOptions;
    pub const getUiAccountMaybeWithConfig = account_methods.getUiAccountMaybeWithConfig;
    pub const getUiAccountWithOptions = account_methods.getUiAccountWithOptions;
    pub const getUiAccountWithConfig = account_methods.getUiAccountWithConfig;
    pub const getUiAccountResponse = account_methods.getUiAccountResponse;
    pub const getUiAccountMaybe = account_methods.getUiAccountMaybe;
    pub const getUiAccount = account_methods.getUiAccount;
    pub const getMultipleAccountsResponseWithOptions = account_methods.getMultipleAccountsResponseWithOptions;
    pub const getMultipleAccountsResponseWithConfig = account_methods.getMultipleAccountsResponseWithConfig;
    pub const getMultipleAccountsWithOptions = account_methods.getMultipleAccountsWithOptions;
    pub const getMultipleAccountsWithConfig = account_methods.getMultipleAccountsWithConfig;
    pub const getMultipleAccounts = account_methods.getMultipleAccounts;
    pub const getMultipleAccountsResponse = account_methods.getMultipleAccountsResponse;
    pub const getMultipleUiAccountsResponseWithOptions = account_methods.getMultipleUiAccountsResponseWithOptions;
    pub const getMultipleUiAccountsResponseWithConfig = account_methods.getMultipleUiAccountsResponseWithConfig;
    pub const getMultipleUiAccountsWithOptions = account_methods.getMultipleUiAccountsWithOptions;
    pub const getMultipleUiAccountsWithConfig = account_methods.getMultipleUiAccountsWithConfig;
    pub const getMultipleUiAccounts = account_methods.getMultipleUiAccounts;
    pub const getMultipleUiAccountsResponse = account_methods.getMultipleUiAccountsResponse;
    pub const getBalanceResponse = asset_methods.getBalanceResponse;
    pub const getBalance = asset_methods.getBalance;
    pub const serializeRequestAirdropParams = asset_methods.serializeRequestAirdropParams;
    pub const minimumBalanceForRentExemption = asset_methods.minimumBalanceForRentExemption;
    pub const requestAirdropWithOptions = asset_methods.requestAirdropWithOptions;
    pub const requestAirdropWithConfig = asset_methods.requestAirdropWithConfig;
    pub const requestAirdrop = asset_methods.requestAirdrop;
    pub const requestAirdropWithBlockhash = asset_methods.requestAirdropWithBlockhash;
    pub const getSupply = asset_methods.getSupply;
    pub const getSupplyWithOptions = asset_methods.getSupplyWithOptions;
    pub const getSupplyWithConfig = asset_methods.getSupplyWithConfig;
    pub const getLargestAccountsWithOptions = asset_methods.getLargestAccountsWithOptions;
    pub const getLargestAccountsWithConfig = asset_methods.getLargestAccountsWithConfig;
    pub const getLargestAccounts = asset_methods.getLargestAccounts;
    pub const getTokenAccountBalance = asset_methods.getTokenAccountBalance;
    pub const getTokenAccountBalanceResponse = asset_methods.getTokenAccountBalanceResponse;
    pub const getTokenAccountMaybe = asset_methods.getTokenAccountMaybe;
    pub const getTokenAccountMaybeWithOptions = asset_methods.getTokenAccountMaybeWithOptions;
    pub const getTokenAccountWithOptions = asset_methods.getTokenAccountWithOptions;
    pub const getTokenAccountWithConfig = asset_methods.getTokenAccountWithConfig;
    pub const getTokenAccountMaybeWithConfig = asset_methods.getTokenAccountMaybeWithConfig;
    pub const getTokenAccount = asset_methods.getTokenAccount;
    pub const getTokenSupply = asset_methods.getTokenSupply;
    pub const getTokenSupplyResponse = asset_methods.getTokenSupplyResponse;
    pub const getTokenLargestAccounts = asset_methods.getTokenLargestAccounts;
    pub const getTokenLargestAccountsResponse = asset_methods.getTokenLargestAccountsResponse;
    pub const getTokenAccountsByOwner = asset_methods.getTokenAccountsByOwner;
    pub const getTokenAccountsByDelegate = asset_methods.getTokenAccountsByDelegate;
    pub const getBlockWithOptions = ledger_methods.getBlockWithOptions;
    pub const getBlockWithConfig = ledger_methods.getBlockWithConfig;
    pub const getBlockWithEncoding = ledger_methods.getBlockWithEncoding;
    pub const getBlock = ledger_methods.getBlock;
    pub const parseGetBlockResponse = ledger_methods.parseGetBlockResponse;
    pub const summarizeBlockJson = ledger_methods.summarizeBlockJson;
    pub const freeOwnedBlockSummary = ledger_methods.freeOwnedBlockSummary;
    pub const getBlockSummaryWithOptions = ledger_methods.getBlockSummaryWithOptions;
    pub const getBlockSummaryWithConfig = ledger_methods.getBlockSummaryWithConfig;
    pub const getBlockSummary = ledger_methods.getBlockSummary;
    pub const getTransaction = ledger_methods.getTransaction;
    pub const getTransactionWithConfig = ledger_methods.getTransactionWithConfig;
    pub const parseGetTransactionResponse = ledger_methods.parseGetTransactionResponse;
    pub const summarizeTransactionJson = ledger_methods.summarizeTransactionJson;
    pub const freeOwnedTransactionSummary = ledger_methods.freeOwnedTransactionSummary;
    pub const getTransactionSummaryWithOptions = ledger_methods.getTransactionSummaryWithOptions;
    pub const getTransactionSummaryWithConfig = ledger_methods.getTransactionSummaryWithConfig;
    pub const getTransactionSummary = ledger_methods.getTransactionSummary;
    pub const getFeeForMessageResponse = ledger_methods.getFeeForMessageResponse;
    pub const getFeeForMessage = ledger_methods.getFeeForMessage;
    pub const getFeeForMessageTyped = ledger_methods.getFeeForMessageTyped;
    pub const getFeeForVersionedMessageTyped = ledger_methods.getFeeForVersionedMessageTyped;
    pub const getFeeForMessageResponseTyped = ledger_methods.getFeeForMessageResponseTyped;
    pub const getLatestBlockhashResponse = network_methods.getLatestBlockhashResponse;
    pub const getLatestBlockhash = network_methods.getLatestBlockhash;
    pub const getNewLatestBlockhash = network_methods.getNewLatestBlockhash;
    pub const getFeatureActivationSlot = network_methods.getFeatureActivationSlot;
    pub const getSlot = network_methods.getSlot;
    pub const getBlockHeight = network_methods.getBlockHeight;
    pub const getTransactionCount = network_methods.getTransactionCount;
    pub const getGenesisHash = network_methods.getGenesisHash;
    pub const getHealth = network_methods.getHealth;
    pub const getFirstAvailableBlock = network_methods.getFirstAvailableBlock;
    pub const getStakeMinimumDelegation = network_methods.getStakeMinimumDelegation;
    pub const getEpochInfo = network_methods.getEpochInfo;
    pub const getVersion = network_methods.getVersion;
    pub const getEpochSchedule = network_methods.getEpochSchedule;
    pub const getHighestSnapshotSlot = network_methods.getHighestSnapshotSlot;
    pub const getInflationRate = network_methods.getInflationRate;
    pub const getBlockTime = network_methods.getBlockTime;
    pub const getBlockCommitment = network_methods.getBlockCommitment;
    pub const getRecentPerformanceSamples = network_methods.getRecentPerformanceSamples;
    pub const getInflationReward = network_methods.getInflationReward;
    pub const getBlocks = network_methods.getBlocks;
    pub const getBlocksWithLimit = network_methods.getBlocksWithLimit;
    pub const getSlotLeaders = network_methods.getSlotLeaders;
    pub const getSlotLeader = network_methods.getSlotLeader;
    pub const getRecentPrioritizationFees = network_methods.getRecentPrioritizationFees;
    pub const getIdentity = network_methods.getIdentity;
    pub const getInflationGovernor = network_methods.getInflationGovernor;
    pub const getMinimumLedgerSlot = network_methods.getMinimumLedgerSlot;
    pub const getMaxRetransmitSlot = network_methods.getMaxRetransmitSlot;
    pub const getMaxShredInsertSlot = network_methods.getMaxShredInsertSlot;
    pub const getClusterNodes = network_methods.getClusterNodes;
    pub const getLeaderSchedule = network_methods.getLeaderSchedule;
    pub const getVoteAccountsWithOptions = network_methods.getVoteAccountsWithOptions;
    pub const getVoteAccountsWithConfig = network_methods.getVoteAccountsWithConfig;
    pub const getVoteAccounts = network_methods.getVoteAccounts;
    pub const getBlockProductionWithOptions = network_methods.getBlockProductionWithOptions;
    pub const getBlockProductionWithConfig = network_methods.getBlockProductionWithConfig;
    pub const getBlockProduction = network_methods.getBlockProduction;
    pub const isBlockhashValid = network_methods.isBlockhashValid;
    pub const serializeProgramAccountsParams = program_methods.serializeProgramAccountsParams;
    pub const serializeProgramUiAccountsParams = program_methods.serializeProgramUiAccountsParams;
    pub const getProgramAccountsResponseWithOptions = program_methods.getProgramAccountsResponseWithOptions;
    pub const getProgramAccountsResponseWithConfig = program_methods.getProgramAccountsResponseWithConfig;
    pub const getProgramAccountsWithOptions = program_methods.getProgramAccountsWithOptions;
    pub const getProgramAccountsWithConfig = program_methods.getProgramAccountsWithConfig;
    pub const getProgramAccounts = program_methods.getProgramAccounts;
    pub const getProgramUiAccountsResponseWithOptions = program_methods.getProgramUiAccountsResponseWithOptions;
    pub const getProgramUiAccountsResponseWithConfig = program_methods.getProgramUiAccountsResponseWithConfig;
    pub const getProgramUiAccountsWithOptions = program_methods.getProgramUiAccountsWithOptions;
    pub const getProgramUiAccountsWithConfig = program_methods.getProgramUiAccountsWithConfig;
    pub const getProgramUiAccounts = program_methods.getProgramUiAccounts;
    pub const buildTransferSignedTransaction = transfer_methods.buildTransferSignedTransaction;
    pub const buildTransferSignedTransactionWithOptions = transfer_methods.buildTransferSignedTransactionWithOptions;
    pub const buildTransferSignedTransactionWithConfig = transfer_methods.buildTransferSignedTransactionWithConfig;
    pub const buildTransferTransaction = transfer_methods.buildTransferTransaction;
    pub const buildTransferTransactionWithOptions = transfer_methods.buildTransferTransactionWithOptions;
    pub const buildTransferTransactionWithConfig = transfer_methods.buildTransferTransactionWithConfig;
    pub const sendTransfer = transfer_methods.sendTransfer;
    pub const sendTransferWithOptions = transfer_methods.sendTransferWithOptions;
    pub const sendTransferWithConfig = transfer_methods.sendTransferWithConfig;
    pub const transfer = transfer_methods.transfer;
    pub const transferWithOptions = transfer_methods.transferWithOptions;
    pub const transferWithConfig = transfer_methods.transferWithConfig;

    pub const serializeSimulateTransactionParams = transaction_methods.serializeSimulateTransactionParams;
    pub const serializeSendTransactionParams = transaction_methods.serializeSendTransactionParams;
    pub const serializeSignaturesForAddressParams = transaction_methods.serializeSignaturesForAddressParams;
    pub const serializeSignatureStatusesParams = transaction_methods.serializeSignatureStatusesParams;
    pub const send = transaction_methods.send;
    pub const sendTransactionWithConfig = transaction_methods.sendTransactionWithConfig;
    pub const sendAndConfirmTransaction = transaction_methods.sendAndConfirmTransaction;
    pub const sendAndConfirmTransactionWithCommitment = transaction_methods.sendAndConfirmTransactionWithCommitment;
    pub const sendAndConfirmTransactionWithConfig = transaction_methods.sendAndConfirmTransactionWithConfig;
    pub const sendAndConfirmTransactionWithCommitmentAndConfig = transaction_methods.sendAndConfirmTransactionWithCommitmentAndConfig;
    pub const sendTransaction = transaction_methods.sendTransaction;
    pub const sendTransactionTyped = transaction_methods.sendTransactionTyped;
    pub const sendVersionedTransactionTyped = transaction_methods.sendVersionedTransactionTyped;
    pub const sendLegacyTransaction = transaction_methods.sendLegacyTransaction;
    pub const sendVersionedTransaction = transaction_methods.sendVersionedTransaction;
    pub const simulateTransaction = transaction_methods.simulateTransaction;
    pub const simulateTransactionWithConfig = transaction_methods.simulateTransactionWithConfig;
    pub const simulateTransactionTyped = transaction_methods.simulateTransactionTyped;
    pub const simulateVersionedTransactionTyped = transaction_methods.simulateVersionedTransactionTyped;
    pub const simulateLegacyTransaction = transaction_methods.simulateLegacyTransaction;
    pub const simulateVersionedTransaction = transaction_methods.simulateVersionedTransaction;
    pub const getSignatureStatusWithOptions = transaction_methods.getSignatureStatusWithOptions;
    pub const getSignatureStatusWithConfig = transaction_methods.getSignatureStatusWithConfig;
    pub const getSignatureStatus = transaction_methods.getSignatureStatus;
    pub const getSignatureStatusWithHistory = transaction_methods.getSignatureStatusWithHistory;
    pub const getSignatureStatusWithCommitmentAndHistory = transaction_methods.getSignatureStatusWithCommitmentAndHistory;
    pub const getSignatureStatusesWithOptions = transaction_methods.getSignatureStatusesWithOptions;
    pub const getSignatureStatusesWithConfig = transaction_methods.getSignatureStatusesWithConfig;
    pub const getSignatureStatuses = transaction_methods.getSignatureStatuses;
    pub const getSignatureStatusesWithHistory = transaction_methods.getSignatureStatusesWithHistory;
    pub const getSignatureStatusesWithCommitmentAndHistory = transaction_methods.getSignatureStatusesWithCommitmentAndHistory;
    pub const confirmTransaction = transaction_methods.confirmTransaction;
    pub const getNumBlocksSinceSignatureConfirmation = transaction_methods.getNumBlocksSinceSignatureConfirmation;
    pub const getNumBlocksSinceSignatureConfirmationWithCommitment = transaction_methods.getNumBlocksSinceSignatureConfirmationWithCommitment;
    pub const getSignaturesForAddress = transaction_methods.getSignaturesForAddress;
    pub const getSignaturesForAddressWithConfig = transaction_methods.getSignaturesForAddressWithConfig;
    pub const getSignaturesForAddressWithOptions = transaction_methods.getSignaturesForAddressWithOptions;
    pub const pollGetBalanceWithCommitmentAndTimeouts = transaction_methods.pollGetBalanceWithCommitmentAndTimeouts;
    pub const pollGetBalanceWithCommitment = transaction_methods.pollGetBalanceWithCommitment;
    pub const waitForBalanceWithCommitmentAndTimeouts = transaction_methods.waitForBalanceWithCommitmentAndTimeouts;
    pub const waitForBalanceWithCommitment = transaction_methods.waitForBalanceWithCommitment;
    pub const waitForSignatureStatus = transaction_methods.waitForSignatureStatus;
    pub const pollForSignature = transaction_methods.pollForSignature;
    pub const pollForSignatureConfirmationWithTimeouts = transaction_methods.pollForSignatureConfirmationWithTimeouts;
    pub const pollForSignatureConfirmationWithCommitmentAndTimeouts = transaction_methods.pollForSignatureConfirmationWithCommitmentAndTimeouts;
    pub const pollForSignatureConfirmation = transaction_methods.pollForSignatureConfirmation;
    pub const sendTransactionAndConfirm = transaction_methods.sendTransactionAndConfirm;
    pub const sendTransactionAndConfirmTyped = transaction_methods.sendTransactionAndConfirmTyped;
    pub const sendAndConfirmVersionedTransactionTyped = transaction_methods.sendAndConfirmVersionedTransactionTyped;
    pub const sendAndConfirmLegacyTransaction = transaction_methods.sendAndConfirmLegacyTransaction;
    pub const sendAndConfirmVersionedTransaction = transaction_methods.sendAndConfirmVersionedTransaction;

    pub fn init(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, null);
    }

    pub fn new(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return RpcClient.init(allocator, endpoint);
    }

    pub fn newWithCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment);
    }

    pub fn newWithTimeout(allocator: Allocator, endpoint: []const u8, timeout_ms: u64) !RpcClient {
        _ = timeout_ms;
        return RpcClient.init(allocator, endpoint);
    }

    pub fn newWithTimeoutAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        _ = timeout_ms;
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment);
    }

    pub fn newWithTimeoutsAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        send_timeout_ms: u64,
        request_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        _ = send_timeout_ms;
        _ = request_timeout_ms;
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment);
    }

    pub fn newSender(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return RpcClient.init(allocator, endpoint);
    }

    pub fn newSocket(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return RpcClient.init(allocator, endpoint);
    }

    pub fn newSocketWithCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment);
    }

    pub fn newSocketWithTimeout(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
    ) !RpcClient {
        _ = timeout_ms;
        return RpcClient.init(allocator, endpoint);
    }

    pub fn deinit(self: *RpcClient) void {
        lifecycle_methods.deinit(self);
    }

    pub fn url(self: *const RpcClient) []const u8 {
        return lifecycle_methods.url(self);
    }

    pub fn getLastError(self: *RpcClient) ?RpcErrorDetail {
        return lifecycle_methods.getLastError(self);
    }

    pub fn getTransportStats(self: *const RpcClient) TransportStats {
        return lifecycle_methods.getTransportStats(self);
    }

    pub fn getDefaultCommitment(self: *const RpcClient) ?Commitment {
        return self.default_commitment;
    }

    pub fn resolveCommitment(self: *const RpcClient, commitment_override: ?Commitment) ?Commitment {
        return commitment_override orelse self.default_commitment;
    }

    pub fn resolveCommitmentString(self: *const RpcClient, commitment_override: ?Commitment) ?[]const u8 {
        return if (self.resolveCommitment(commitment_override)) |value| rpc_types.commitmentToString(value) else null;
    }

    fn clearLastError(self: *RpcClient) void {
        lifecycle_methods.clearLastError(self);
    }

    pub fn sendRequest(self: *RpcClient, method: []const u8, params_json: []const u8) ![]u8 {
        return transport_methods.sendRequest(self, method, params_json);
    }
};
