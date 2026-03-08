const std = @import("std");
const rpc_types = @import("../rpc_types.zig");

const lifecycle_methods = @import("./lifecycle.zig");
const mock_methods = @import("./mock.zig");
const owned_methods = @import("./owned.zig");
const raw_methods = @import("./raw.zig");
const response_methods = @import("./response.zig");
const sender_methods = @import("./sender.zig");
const transport_methods = @import("./transport.zig");
const account_methods = @import("./accounts.zig");
const asset_methods = @import("./assets.zig");
const ledger_methods = @import("./ledger.zig");
const network_methods = @import("./network.zig");
const nonce_methods = @import("./nonce.zig");
const program_methods = @import("./programs.zig");
const transfer_methods = @import("./transfers.zig");
const transaction_methods = @import("./transactions.zig");

const Allocator = std.mem.Allocator;
const Commitment = rpc_types.Commitment;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const TransportStats = rpc_types.TransportStats;
const RequestSenderRequestType = sender_methods.RequestSenderRequest;
const RequestSenderType = sender_methods.RequestSender;
const MockRequestType = mock_methods.MockRequest;
const AccountInfoType = rpc_types.AccountInfo;
const JsonParsedAccountInfoType = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccountType = rpc_types.JsonParsedProgramAccount;
const MockRequestMatcherType = mock_methods.MockRequestMatcher;
const MockRequestHandlerType = mock_methods.MockRequestHandler;
const MockRequestViewType = mock_methods.MockRequestView;
const MockRouteType = mock_methods.MockRoute;
const MockResponseType = mock_methods.MockResponse;
const MockHandlerResponseType = mock_methods.MockHandlerResponse;
const MockSenderType = mock_methods.MockSender;
const MockRpcErrorType = mock_methods.MockRpcError;
const MockTransportErrorType = mock_methods.MockTransportError;
const TokenAmountType = rpc_types.TokenAmount;
const TokenLargestAccountType = rpc_types.TokenLargestAccount;

pub const RpcClient = struct {
    allocator: Allocator,
    endpoint: []const u8,
    http_client: std.http.Client,
    request_sender: ?RequestSenderType,
    mock_sender: ?*MockSenderType,
    request_id: u64,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
    last_error: ?RpcErrorDetail,
    transport_stats: TransportStats,

    pub const RequestSenderRequest = sender_methods.RequestSenderRequest;
    pub const RequestSender = sender_methods.RequestSender;
    pub const MockRequest = mock_methods.MockRequest;
    pub const MockRequestMatcher = mock_methods.MockRequestMatcher;
    pub const MockRequestView = mock_methods.MockRequestView;
    pub const MockSignatureStatus = mock_methods.MockSignatureStatus;
    pub const MockSignatureStatusPollStep = mock_methods.MockSignatureStatusPollStep;
    pub const MockSignatureObservationPollStep = mock_methods.MockSignatureObservationPollStep;
    pub const MockBalancePollStep = mock_methods.MockBalancePollStep;
    pub const MockRequestHandler = mock_methods.MockRequestHandler;
    pub const MockRoute = mock_methods.MockRoute;
    pub const MockRouteBuilder = mock_methods.MockRouteBuilder;
    pub const MockResponse = mock_methods.MockResponse;
    pub const MockHandlerResponse = mock_methods.MockHandlerResponse;
    pub const MockSender = mock_methods.MockSender;
    pub const MockRpcError = mock_methods.MockRpcError;
    pub const MockTransportError = mock_methods.MockTransportError;
    pub const MockClientOptions = struct {
        commitment: ?Commitment = null,
        request_timeout_ms: ?u64 = null,
        confirm_transaction_initial_timeout_ms: ?u64 = null,
    };
    pub const RequestSenderOptions = struct {
        endpoint: []const u8 = "custom://local",
        commitment: ?Commitment = null,
        request_timeout_ms: ?u64 = null,
        confirm_transaction_initial_timeout_ms: ?u64 = null,
    };

    pub const serializeParams = response_methods.serializeParams;
    pub const parseResponse = response_methods.parseResponse;
    pub const parseOwnedResponse = response_methods.parseOwnedResponse;
    pub const captureRpcError = response_methods.captureRpcError;
    pub const encodeJsonRpcResultEnvelope = sender_methods.encodeJsonRpcResultEnvelope;
    pub const encodeJsonRpcErrorEnvelope = sender_methods.encodeJsonRpcErrorEnvelope;
    pub const sendRaw = raw_methods.sendRaw;
    pub const sendJsonRpc = raw_methods.sendJsonRpc;
    pub const sendTyped = raw_methods.sendTyped;
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
    pub const getFeeForVersionedMessageResponseTyped = ledger_methods.getFeeForVersionedMessageResponseTyped;
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
    pub const freeOwnedNonceAccount = nonce_methods.freeOwnedNonceAccount;
    pub const freeOwnedResolvedBlockhash = nonce_methods.freeOwnedResolvedBlockhash;
    pub const getNonceAccountResponseWithOptions = nonce_methods.getNonceAccountResponseWithOptions;
    pub const getNonceAccountResponseWithConfig = nonce_methods.getNonceAccountResponseWithConfig;
    pub const getNonceAccountMaybeWithOptions = nonce_methods.getNonceAccountMaybeWithOptions;
    pub const getNonceAccountMaybeWithConfig = nonce_methods.getNonceAccountMaybeWithConfig;
    pub const getNonceAccountWithOptions = nonce_methods.getNonceAccountWithOptions;
    pub const getNonceAccountWithConfig = nonce_methods.getNonceAccountWithConfig;
    pub const getNonceAccountResponse = nonce_methods.getNonceAccountResponse;
    pub const getNonceAccountMaybe = nonce_methods.getNonceAccountMaybe;
    pub const getNonceAccount = nonce_methods.getNonceAccount;
    pub const getNonceBlockhash = nonce_methods.getNonceBlockhash;
    pub const resolveBlockhashQuery = nonce_methods.resolveBlockhashQuery;
    pub const buildOwnedLegacyMessage = nonce_methods.buildOwnedLegacyMessage;
    pub const buildOwnedLegacyMessageWithOptions = nonce_methods.buildOwnedLegacyMessageWithOptions;
    pub const buildOwnedLegacyMessageWithConfig = nonce_methods.buildOwnedLegacyMessageWithConfig;
    pub const buildOwnedLegacyMessageWithBlockhashQuery = nonce_methods.buildOwnedLegacyMessageWithBlockhashQuery;
    pub const buildLegacyMessageBytes = nonce_methods.buildLegacyMessageBytes;
    pub const buildLegacyMessageBytesWithOptions = nonce_methods.buildLegacyMessageBytesWithOptions;
    pub const buildLegacyMessageBytesWithConfig = nonce_methods.buildLegacyMessageBytesWithConfig;
    pub const buildLegacyMessageBytesWithBlockhashQuery = nonce_methods.buildLegacyMessageBytesWithBlockhashQuery;
    pub const buildLegacyMessageBase64 = nonce_methods.buildLegacyMessageBase64;
    pub const buildLegacyMessageBase64WithOptions = nonce_methods.buildLegacyMessageBase64WithOptions;
    pub const buildLegacyMessageBase64WithConfig = nonce_methods.buildLegacyMessageBase64WithConfig;
    pub const buildLegacyMessageBase64WithBlockhashQuery = nonce_methods.buildLegacyMessageBase64WithBlockhashQuery;
    pub const buildLegacyInstructionsSignedTransaction = nonce_methods.buildLegacyInstructionsSignedTransaction;
    pub const buildLegacyInstructionsSignedTransactionWithOptions = nonce_methods.buildLegacyInstructionsSignedTransactionWithOptions;
    pub const buildLegacyInstructionsSignedTransactionWithConfig = nonce_methods.buildLegacyInstructionsSignedTransactionWithConfig;
    pub const buildSignedLegacyTransactionWithOptions = nonce_methods.buildSignedLegacyTransactionWithOptions;
    pub const buildSignedLegacyTransactionWithConfig = nonce_methods.buildSignedLegacyTransactionWithConfig;
    pub const buildSignedLegacyTransactionWithBlockhashQuery = nonce_methods.buildSignedLegacyTransactionWithBlockhashQuery;
    pub const buildLegacyInstructionsTransaction = nonce_methods.buildLegacyInstructionsTransaction;
    pub const buildLegacyInstructionsTransactionWithOptions = nonce_methods.buildLegacyInstructionsTransactionWithOptions;
    pub const buildLegacyInstructionsTransactionWithConfig = nonce_methods.buildLegacyInstructionsTransactionWithConfig;
    pub const buildLegacyTransactionBase64WithOptions = nonce_methods.buildLegacyTransactionBase64WithOptions;
    pub const buildLegacyTransactionBase64WithConfig = nonce_methods.buildLegacyTransactionBase64WithConfig;
    pub const buildLegacyTransactionBase64WithBlockhashQuery = nonce_methods.buildLegacyTransactionBase64WithBlockhashQuery;
    pub const buildOwnedVersionedMessage = nonce_methods.buildOwnedVersionedMessage;
    pub const buildOwnedVersionedMessageWithOptions = nonce_methods.buildOwnedVersionedMessageWithOptions;
    pub const buildOwnedVersionedMessageWithConfig = nonce_methods.buildOwnedVersionedMessageWithConfig;
    pub const buildOwnedVersionedMessageWithBlockhashQuery = nonce_methods.buildOwnedVersionedMessageWithBlockhashQuery;
    pub const buildVersionedMessageBytes = nonce_methods.buildVersionedMessageBytes;
    pub const buildVersionedMessageBytesWithOptions = nonce_methods.buildVersionedMessageBytesWithOptions;
    pub const buildVersionedMessageBytesWithConfig = nonce_methods.buildVersionedMessageBytesWithConfig;
    pub const buildVersionedMessageBytesWithBlockhashQuery = nonce_methods.buildVersionedMessageBytesWithBlockhashQuery;
    pub const buildVersionedMessageBase64 = nonce_methods.buildVersionedMessageBase64;
    pub const buildVersionedMessageBase64WithOptions = nonce_methods.buildVersionedMessageBase64WithOptions;
    pub const buildVersionedMessageBase64WithConfig = nonce_methods.buildVersionedMessageBase64WithConfig;
    pub const buildVersionedMessageBase64WithBlockhashQuery = nonce_methods.buildVersionedMessageBase64WithBlockhashQuery;
    pub const buildVersionedInstructionsSignedTransaction = nonce_methods.buildVersionedInstructionsSignedTransaction;
    pub const buildVersionedInstructionsSignedTransactionWithOptions = nonce_methods.buildVersionedInstructionsSignedTransactionWithOptions;
    pub const buildVersionedInstructionsSignedTransactionWithConfig = nonce_methods.buildVersionedInstructionsSignedTransactionWithConfig;
    pub const buildSignedVersionedTransactionWithOptions = nonce_methods.buildSignedVersionedTransactionWithOptions;
    pub const buildSignedVersionedTransactionWithConfig = nonce_methods.buildSignedVersionedTransactionWithConfig;
    pub const buildSignedVersionedTransactionWithBlockhashQuery = nonce_methods.buildSignedVersionedTransactionWithBlockhashQuery;
    pub const buildVersionedInstructionsTransaction = nonce_methods.buildVersionedInstructionsTransaction;
    pub const buildVersionedInstructionsTransactionWithOptions = nonce_methods.buildVersionedInstructionsTransactionWithOptions;
    pub const buildVersionedInstructionsTransactionWithConfig = nonce_methods.buildVersionedInstructionsTransactionWithConfig;
    pub const buildVersionedTransactionBase64WithOptions = nonce_methods.buildVersionedTransactionBase64WithOptions;
    pub const buildVersionedTransactionBase64WithConfig = nonce_methods.buildVersionedTransactionBase64WithConfig;
    pub const buildVersionedTransactionBase64WithBlockhashQuery = nonce_methods.buildVersionedTransactionBase64WithBlockhashQuery;
    pub const getFeeForLegacyInstructionsResponse = nonce_methods.getFeeForLegacyInstructionsResponse;
    pub const getFeeForLegacyInstructionsResponseWithOptions = nonce_methods.getFeeForLegacyInstructionsResponseWithOptions;
    pub const getFeeForLegacyInstructionsResponseWithConfig = nonce_methods.getFeeForLegacyInstructionsResponseWithConfig;
    pub const getFeeForLegacyInstructionsResponseWithBlockhashQuery = nonce_methods.getFeeForLegacyInstructionsResponseWithBlockhashQuery;
    pub const getFeeForVersionedInstructionsResponse = nonce_methods.getFeeForVersionedInstructionsResponse;
    pub const getFeeForVersionedInstructionsResponseWithOptions = nonce_methods.getFeeForVersionedInstructionsResponseWithOptions;
    pub const getFeeForVersionedInstructionsResponseWithConfig = nonce_methods.getFeeForVersionedInstructionsResponseWithConfig;
    pub const getFeeForVersionedInstructionsResponseWithBlockhashQuery = nonce_methods.getFeeForVersionedInstructionsResponseWithBlockhashQuery;
    pub const getFeeForLegacyInstructions = nonce_methods.getFeeForLegacyInstructions;
    pub const getFeeForLegacyInstructionsWithOptions = nonce_methods.getFeeForLegacyInstructionsWithOptions;
    pub const getFeeForLegacyInstructionsWithConfig = nonce_methods.getFeeForLegacyInstructionsWithConfig;
    pub const getFeeForLegacyInstructionsWithBlockhashQuery = nonce_methods.getFeeForLegacyInstructionsWithBlockhashQuery;
    pub const getFeeForVersionedInstructions = nonce_methods.getFeeForVersionedInstructions;
    pub const getFeeForVersionedInstructionsWithOptions = nonce_methods.getFeeForVersionedInstructionsWithOptions;
    pub const getFeeForVersionedInstructionsWithConfig = nonce_methods.getFeeForVersionedInstructionsWithConfig;
    pub const getFeeForVersionedInstructionsWithBlockhashQuery = nonce_methods.getFeeForVersionedInstructionsWithBlockhashQuery;
    pub const simulateLegacyInstructions = nonce_methods.simulateLegacyInstructions;
    pub const simulateLegacyInstructionsWithOptions = nonce_methods.simulateLegacyInstructionsWithOptions;
    pub const simulateLegacyInstructionsWithConfig = nonce_methods.simulateLegacyInstructionsWithConfig;
    pub const simulateLegacyInstructionsWithBlockhashQuery = nonce_methods.simulateLegacyInstructionsWithBlockhashQuery;
    pub const simulateVersionedInstructions = nonce_methods.simulateVersionedInstructions;
    pub const simulateVersionedInstructionsWithOptions = nonce_methods.simulateVersionedInstructionsWithOptions;
    pub const simulateVersionedInstructionsWithConfig = nonce_methods.simulateVersionedInstructionsWithConfig;
    pub const simulateVersionedInstructionsWithBlockhashQuery = nonce_methods.simulateVersionedInstructionsWithBlockhashQuery;
    pub const sendLegacyInstructions = nonce_methods.sendLegacyInstructions;
    pub const sendLegacyInstructionsWithOptions = nonce_methods.sendLegacyInstructionsWithOptions;
    pub const sendLegacyInstructionsWithConfig = nonce_methods.sendLegacyInstructionsWithConfig;
    pub const sendLegacyInstructionsWithBlockhashQuery = nonce_methods.sendLegacyInstructionsWithBlockhashQuery;
    pub const sendVersionedInstructions = nonce_methods.sendVersionedInstructions;
    pub const sendVersionedInstructionsWithOptions = nonce_methods.sendVersionedInstructionsWithOptions;
    pub const sendVersionedInstructionsWithConfig = nonce_methods.sendVersionedInstructionsWithConfig;
    pub const sendVersionedInstructionsWithBlockhashQuery = nonce_methods.sendVersionedInstructionsWithBlockhashQuery;
    pub const sendAndConfirmLegacyInstructions = nonce_methods.sendAndConfirmLegacyInstructions;
    pub const sendAndConfirmLegacyInstructionsWithOptions = nonce_methods.sendAndConfirmLegacyInstructionsWithOptions;
    pub const sendAndConfirmLegacyInstructionsWithConfig = nonce_methods.sendAndConfirmLegacyInstructionsWithConfig;
    pub const sendAndConfirmLegacyInstructionsWithBlockhashQuery = nonce_methods.sendAndConfirmLegacyInstructionsWithBlockhashQuery;
    pub const sendAndConfirmVersionedInstructions = nonce_methods.sendAndConfirmVersionedInstructions;
    pub const sendAndConfirmVersionedInstructionsWithOptions = nonce_methods.sendAndConfirmVersionedInstructionsWithOptions;
    pub const sendAndConfirmVersionedInstructionsWithConfig = nonce_methods.sendAndConfirmVersionedInstructionsWithConfig;
    pub const sendAndConfirmVersionedInstructionsWithBlockhashQuery = nonce_methods.sendAndConfirmVersionedInstructionsWithBlockhashQuery;
    pub const sendAndConfirmVersionedInstructionsWithSpinner = nonce_methods.sendAndConfirmVersionedInstructionsWithSpinner;
    pub const sendAndConfirmVersionedInstructionsWithSpinnerAndOptions = nonce_methods.sendAndConfirmVersionedInstructionsWithSpinnerAndOptions;
    pub const sendAndConfirmVersionedInstructionsWithSpinnerAndConfig = nonce_methods.sendAndConfirmVersionedInstructionsWithSpinnerAndConfig;
    pub const sendAndConfirmVersionedInstructionsWithBlockhashQueryWithSpinner = nonce_methods.sendAndConfirmVersionedInstructionsWithBlockhashQueryWithSpinner;
    pub const sendAndConfirmLegacyInstructionsWithSpinner = nonce_methods.sendAndConfirmLegacyInstructionsWithSpinner;
    pub const sendAndConfirmLegacyInstructionsWithSpinnerAndOptions = nonce_methods.sendAndConfirmLegacyInstructionsWithSpinnerAndOptions;
    pub const sendAndConfirmLegacyInstructionsWithSpinnerAndConfig = nonce_methods.sendAndConfirmLegacyInstructionsWithSpinnerAndConfig;
    pub const sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner = nonce_methods.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner;
    pub const buildInitializeNonceAccountSignedTransaction = nonce_methods.buildInitializeNonceAccountSignedTransaction;
    pub const buildInitializeNonceAccountSignedTransactionWithOptions = nonce_methods.buildInitializeNonceAccountSignedTransactionWithOptions;
    pub const buildInitializeNonceAccountSignedTransactionWithConfig = nonce_methods.buildInitializeNonceAccountSignedTransactionWithConfig;
    pub const buildInitializeNonceAccountTransaction = nonce_methods.buildInitializeNonceAccountTransaction;
    pub const buildInitializeNonceAccountTransactionWithOptions = nonce_methods.buildInitializeNonceAccountTransactionWithOptions;
    pub const buildInitializeNonceAccountTransactionWithConfig = nonce_methods.buildInitializeNonceAccountTransactionWithConfig;
    pub const sendInitializeNonceAccount = nonce_methods.sendInitializeNonceAccount;
    pub const sendInitializeNonceAccountWithOptions = nonce_methods.sendInitializeNonceAccountWithOptions;
    pub const sendInitializeNonceAccountWithConfig = nonce_methods.sendInitializeNonceAccountWithConfig;
    pub const initializeNonceAccount = nonce_methods.initializeNonceAccount;
    pub const initializeNonceAccountWithOptions = nonce_methods.initializeNonceAccountWithOptions;
    pub const initializeNonceAccountWithConfig = nonce_methods.initializeNonceAccountWithConfig;
    pub const buildAdvanceNonceAccountSignedTransaction = nonce_methods.buildAdvanceNonceAccountSignedTransaction;
    pub const buildAdvanceNonceAccountSignedTransactionWithOptions = nonce_methods.buildAdvanceNonceAccountSignedTransactionWithOptions;
    pub const buildAdvanceNonceAccountSignedTransactionWithConfig = nonce_methods.buildAdvanceNonceAccountSignedTransactionWithConfig;
    pub const buildAdvanceNonceAccountTransaction = nonce_methods.buildAdvanceNonceAccountTransaction;
    pub const buildAdvanceNonceAccountTransactionWithOptions = nonce_methods.buildAdvanceNonceAccountTransactionWithOptions;
    pub const buildAdvanceNonceAccountTransactionWithConfig = nonce_methods.buildAdvanceNonceAccountTransactionWithConfig;
    pub const sendAdvanceNonceAccount = nonce_methods.sendAdvanceNonceAccount;
    pub const sendAdvanceNonceAccountWithOptions = nonce_methods.sendAdvanceNonceAccountWithOptions;
    pub const sendAdvanceNonceAccountWithConfig = nonce_methods.sendAdvanceNonceAccountWithConfig;
    pub const advanceNonceAccount = nonce_methods.advanceNonceAccount;
    pub const advanceNonceAccountWithOptions = nonce_methods.advanceNonceAccountWithOptions;
    pub const advanceNonceAccountWithConfig = nonce_methods.advanceNonceAccountWithConfig;
    pub const buildAuthorizeNonceAccountSignedTransaction = nonce_methods.buildAuthorizeNonceAccountSignedTransaction;
    pub const buildAuthorizeNonceAccountSignedTransactionWithOptions = nonce_methods.buildAuthorizeNonceAccountSignedTransactionWithOptions;
    pub const buildAuthorizeNonceAccountSignedTransactionWithConfig = nonce_methods.buildAuthorizeNonceAccountSignedTransactionWithConfig;
    pub const buildAuthorizeNonceAccountTransaction = nonce_methods.buildAuthorizeNonceAccountTransaction;
    pub const buildAuthorizeNonceAccountTransactionWithOptions = nonce_methods.buildAuthorizeNonceAccountTransactionWithOptions;
    pub const buildAuthorizeNonceAccountTransactionWithConfig = nonce_methods.buildAuthorizeNonceAccountTransactionWithConfig;
    pub const sendAuthorizeNonceAccount = nonce_methods.sendAuthorizeNonceAccount;
    pub const sendAuthorizeNonceAccountWithOptions = nonce_methods.sendAuthorizeNonceAccountWithOptions;
    pub const sendAuthorizeNonceAccountWithConfig = nonce_methods.sendAuthorizeNonceAccountWithConfig;
    pub const authorizeNonceAccount = nonce_methods.authorizeNonceAccount;
    pub const authorizeNonceAccountWithOptions = nonce_methods.authorizeNonceAccountWithOptions;
    pub const authorizeNonceAccountWithConfig = nonce_methods.authorizeNonceAccountWithConfig;
    pub const buildWithdrawNonceAccountSignedTransaction = nonce_methods.buildWithdrawNonceAccountSignedTransaction;
    pub const buildWithdrawNonceAccountSignedTransactionWithOptions = nonce_methods.buildWithdrawNonceAccountSignedTransactionWithOptions;
    pub const buildWithdrawNonceAccountSignedTransactionWithConfig = nonce_methods.buildWithdrawNonceAccountSignedTransactionWithConfig;
    pub const buildWithdrawNonceAccountTransaction = nonce_methods.buildWithdrawNonceAccountTransaction;
    pub const buildWithdrawNonceAccountTransactionWithOptions = nonce_methods.buildWithdrawNonceAccountTransactionWithOptions;
    pub const buildWithdrawNonceAccountTransactionWithConfig = nonce_methods.buildWithdrawNonceAccountTransactionWithConfig;
    pub const sendWithdrawNonceAccount = nonce_methods.sendWithdrawNonceAccount;
    pub const sendWithdrawNonceAccountWithOptions = nonce_methods.sendWithdrawNonceAccountWithOptions;
    pub const sendWithdrawNonceAccountWithConfig = nonce_methods.sendWithdrawNonceAccountWithConfig;
    pub const withdrawNonceAccount = nonce_methods.withdrawNonceAccount;
    pub const withdrawNonceAccountWithOptions = nonce_methods.withdrawNonceAccountWithOptions;
    pub const withdrawNonceAccountWithConfig = nonce_methods.withdrawNonceAccountWithConfig;
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
    pub const buildVersionedTransferSignedTransaction = transfer_methods.buildVersionedTransferSignedTransaction;
    pub const buildVersionedTransferSignedTransactionWithOptions = transfer_methods.buildVersionedTransferSignedTransactionWithOptions;
    pub const buildVersionedTransferSignedTransactionWithConfig = transfer_methods.buildVersionedTransferSignedTransactionWithConfig;
    pub const buildNonceTransferSignedTransaction = transfer_methods.buildNonceTransferSignedTransaction;
    pub const buildTransferSignedTransactionWithOptions = transfer_methods.buildTransferSignedTransactionWithOptions;
    pub const buildNonceTransferSignedTransactionWithOptions = transfer_methods.buildNonceTransferSignedTransactionWithOptions;
    pub const buildTransferSignedTransactionWithConfig = transfer_methods.buildTransferSignedTransactionWithConfig;
    pub const buildNonceTransferSignedTransactionWithConfig = transfer_methods.buildNonceTransferSignedTransactionWithConfig;
    pub const buildTransferTransaction = transfer_methods.buildTransferTransaction;
    pub const buildVersionedTransferTransaction = transfer_methods.buildVersionedTransferTransaction;
    pub const buildVersionedTransferTransactionWithOptions = transfer_methods.buildVersionedTransferTransactionWithOptions;
    pub const buildVersionedTransferTransactionWithConfig = transfer_methods.buildVersionedTransferTransactionWithConfig;
    pub const buildNonceTransferTransaction = transfer_methods.buildNonceTransferTransaction;
    pub const buildTransferTransactionWithOptions = transfer_methods.buildTransferTransactionWithOptions;
    pub const buildNonceTransferTransactionWithOptions = transfer_methods.buildNonceTransferTransactionWithOptions;
    pub const buildTransferTransactionWithConfig = transfer_methods.buildTransferTransactionWithConfig;
    pub const buildNonceTransferTransactionWithConfig = transfer_methods.buildNonceTransferTransactionWithConfig;
    pub const sendTransfer = transfer_methods.sendTransfer;
    pub const sendVersionedTransfer = transfer_methods.sendVersionedTransfer;
    pub const sendVersionedTransferWithOptions = transfer_methods.sendVersionedTransferWithOptions;
    pub const sendVersionedTransferWithConfig = transfer_methods.sendVersionedTransferWithConfig;
    pub const sendNonceTransfer = transfer_methods.sendNonceTransfer;
    pub const sendTransferWithOptions = transfer_methods.sendTransferWithOptions;
    pub const sendNonceTransferWithOptions = transfer_methods.sendNonceTransferWithOptions;
    pub const sendTransferWithConfig = transfer_methods.sendTransferWithConfig;
    pub const sendNonceTransferWithConfig = transfer_methods.sendNonceTransferWithConfig;
    pub const transfer = transfer_methods.transfer;
    pub const versionedTransfer = transfer_methods.versionedTransfer;
    pub const versionedTransferWithOptions = transfer_methods.versionedTransferWithOptions;
    pub const versionedTransferWithConfig = transfer_methods.versionedTransferWithConfig;
    pub const nonceTransfer = transfer_methods.nonceTransfer;
    pub const transferWithOptions = transfer_methods.transferWithOptions;
    pub const nonceTransferWithOptions = transfer_methods.nonceTransferWithOptions;
    pub const transferWithConfig = transfer_methods.transferWithConfig;
    pub const nonceTransferWithConfig = transfer_methods.nonceTransferWithConfig;

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
    pub const sendAndConfirmTransactionWithSpinner = transaction_methods.sendAndConfirmTransactionWithSpinner;
    pub const sendAndConfirmTransactionWithSpinnerAndCommitment = transaction_methods.sendAndConfirmTransactionWithSpinnerAndCommitment;
    pub const sendAndConfirmTransactionWithSpinnerAndConfig = transaction_methods.sendAndConfirmTransactionWithSpinnerAndConfig;
    pub const sendAndConfirmTransactionWithSpinnerAndCommitmentAndConfig = transaction_methods.sendAndConfirmTransactionWithSpinnerAndCommitmentAndConfig;
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
    pub const confirmTransactionWithSpinner = transaction_methods.confirmTransactionWithSpinner;
    pub const confirmTransactionWithSpinnerAndTimeouts = transaction_methods.confirmTransactionWithSpinnerAndTimeouts;
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
    pub const sendTransactionAndConfirmTypedWithSpinner = transaction_methods.sendTransactionAndConfirmTypedWithSpinner;
    pub const sendAndConfirmVersionedTransactionTyped = transaction_methods.sendAndConfirmVersionedTransactionTyped;
    pub const sendAndConfirmVersionedTransactionTypedWithSpinner = transaction_methods.sendAndConfirmVersionedTransactionTypedWithSpinner;
    pub const sendAndConfirmLegacyTransaction = transaction_methods.sendAndConfirmLegacyTransaction;
    pub const sendAndConfirmLegacyTransactionWithSpinner = transaction_methods.sendAndConfirmLegacyTransactionWithSpinner;
    pub const sendAndConfirmVersionedTransaction = transaction_methods.sendAndConfirmVersionedTransaction;
    pub const sendAndConfirmVersionedTransactionWithSpinner = transaction_methods.sendAndConfirmVersionedTransactionWithSpinner;

    pub fn init(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, null, null, null);
    }

    pub fn new(allocator: Allocator, endpoint: []const u8) !RpcClient {
        return RpcClient.init(allocator, endpoint);
    }

    pub fn newMock(allocator: Allocator, responses: []const MockResponseType) !RpcClient {
        return lifecycle_methods.initMockClient(RpcClient, allocator, responses, null, null, null);
    }

    pub fn newMockWithCommitment(
        allocator: Allocator,
        responses: []const MockResponseType,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClient(RpcClient, allocator, responses, commitment, null, null);
    }

    pub fn newMockWithOptions(
        allocator: Allocator,
        responses: []const MockResponseType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return lifecycle_methods.initMockClientAndOptions(
            RpcClient,
            allocator,
            responses,
            options.endpoint,
            options.commitment,
            options.request_timeout_ms,
            options.confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithTimeout(
        allocator: Allocator,
        responses: []const MockResponseType,
        timeout_ms: u64,
    ) !RpcClient {
        return lifecycle_methods.initMockClient(RpcClient, allocator, responses, null, timeout_ms, null);
    }

    pub fn newMockWithHandler(allocator: Allocator, handler: MockRequestHandlerType) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(RpcClient, allocator, handler, null, null, null);
    }

    pub fn newMockWithHandlerAndTimeout(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        timeout_ms: u64,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(RpcClient, allocator, handler, null, timeout_ms, null);
    }

    pub fn newMockWithHandlerAndCommitment(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(RpcClient, allocator, handler, commitment, null, null);
    }

    pub fn newMockWithTimeoutAndCommitment(
        allocator: Allocator,
        responses: []const MockResponseType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClient(RpcClient, allocator, responses, commitment, timeout_ms, null);
    }

    pub fn newMockWithCommitmentAndTimeout(
        allocator: Allocator,
        responses: []const MockResponseType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithTimeoutAndCommitment(allocator, responses, timeout_ms, commitment);
    }

    pub fn newMockWithTimeouts(
        allocator: Allocator,
        responses: []const MockResponseType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return lifecycle_methods.initMockClient(
            RpcClient,
            allocator,
            responses,
            null,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithHandlerTimeouts(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(
            RpcClient,
            allocator,
            handler,
            null,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithHandlerAndCommitmentAndTimeout(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithHandlerAndTimeoutAndCommitment(allocator, handler, timeout_ms, commitment);
    }

    pub fn newMockWithHandlerAndTimeoutAndCommitment(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(
            RpcClient,
            allocator,
            handler,
            commitment,
            timeout_ms,
            null,
        );
    }

    pub fn newMockWithHandlerAndOptions(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandlerAndOptions(
            RpcClient,
            allocator,
            handler,
            options.endpoint,
            options.commitment,
            options.request_timeout_ms,
            options.confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithTimeoutsAndCommitment(
        allocator: Allocator,
        responses: []const MockResponseType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClient(
            RpcClient,
            allocator,
            responses,
            commitment,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithCommitmentAndTimeouts(
        allocator: Allocator,
        responses: []const MockResponseType,
        commitment: ?Commitment,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithTimeoutsAndCommitment(
            allocator,
            responses,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn newMockWithHandlerAndTimeoutsAndCommitment(
        allocator: Allocator,
        handler: MockRequestHandlerType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithHandler(
            RpcClient,
            allocator,
            handler,
            commitment,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithSender(allocator: Allocator, sender: MockSenderType) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(allocator, sender, .{});
    }

    pub fn newMockWithSenderAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(
            allocator,
            sender,
            .{ .commitment = commitment },
        );
    }

    pub fn newMockWithSenderAndTimeout(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(
            allocator,
            sender,
            .{ .request_timeout_ms = timeout_ms },
        );
    }

    pub fn newMockWithSenderAndTimeouts(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(
            allocator,
            sender,
            .{
                .request_timeout_ms = timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newMockWithSenderAndCommitmentAndTimeout(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndTimeoutAndCommitment(
            allocator,
            sender,
            timeout_ms,
            commitment,
        );
    }

    pub fn newMockWithSenderAndTimeoutAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(
            allocator,
            sender,
            .{
                .request_timeout_ms = timeout_ms,
                .commitment = commitment,
            },
        );
    }

    pub fn newMockWithSenderAndTimeoutsAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndOptions(
            allocator,
            sender,
            .{
                .commitment = commitment,
                .request_timeout_ms = timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newMockWithSenderAndCommitmentAndTimeouts(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newMockWithSenderAndTimeoutsAndCommitment(
            allocator,
            sender,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn newMockWithSenderAndOptions(
        allocator: Allocator,
        sender: MockSenderType,
        options: MockClientOptions,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithSender(
            RpcClient,
            allocator,
            sender,
            options.commitment,
            options.request_timeout_ms,
            options.confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newMockWithSenderAndRequestSenderOptions(
        allocator: Allocator,
        sender: MockSenderType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return lifecycle_methods.initMockClientWithSenderAndOptions(
            RpcClient,
            allocator,
            sender,
            options.endpoint,
            options.commitment,
            options.request_timeout_ms,
            options.confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newWithRequestSender(allocator: Allocator, sender: RequestSenderType) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(allocator, sender, .{});
    }

    pub fn newWithBorrowedMockSender(
        allocator: Allocator,
        sender: *MockSenderType,
    ) !RpcClient {
        return RpcClient.newWithRequestSender(
            allocator,
            RequestSender.fromMockSender(sender),
        );
    }

    pub fn newWithBorrowedMockSenderAndCommitment(
        allocator: Allocator,
        sender: *MockSenderType,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithBorrowedMockSenderAndOptions(
            allocator,
            sender,
            .{ .commitment = commitment },
        );
    }

    pub fn newWithBorrowedMockSenderAndTimeout(
        allocator: Allocator,
        sender: *MockSenderType,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithBorrowedMockSenderAndOptions(
            allocator,
            sender,
            .{ .request_timeout_ms = timeout_ms },
        );
    }

    pub fn newWithBorrowedMockSenderAndTimeouts(
        allocator: Allocator,
        sender: *MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndTimeouts(
            allocator,
            RequestSender.fromMockSender(sender),
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newWithBorrowedMockSenderAndCommitmentAndTimeout(
        allocator: Allocator,
        sender: *MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithBorrowedMockSenderAndTimeoutAndCommitment(
            allocator,
            sender,
            timeout_ms,
            commitment,
        );
    }

    pub fn newWithBorrowedMockSenderAndTimeoutAndCommitment(
        allocator: Allocator,
        sender: *MockSenderType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndTimeoutAndCommitment(
            allocator,
            RequestSender.fromMockSender(sender),
            timeout_ms,
            commitment,
        );
    }

    pub fn newWithBorrowedMockSenderAndCommitmentAndTimeouts(
        allocator: Allocator,
        sender: *MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithBorrowedMockSenderAndTimeoutsAndCommitment(
            allocator,
            sender,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn newWithBorrowedMockSenderAndTimeoutsAndCommitment(
        allocator: Allocator,
        sender: *MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            RequestSender.fromMockSender(sender),
            .{
                .commitment = commitment,
                .request_timeout_ms = timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithBorrowedMockSenderAndOptions(
        allocator: Allocator,
        sender: *MockSenderType,
        options: MockClientOptions,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            RequestSender.fromMockSender(sender),
            .{
                .commitment = options.commitment,
                .request_timeout_ms = options.request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = options.confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithBorrowedMockSenderAndRequestSenderOptions(
        allocator: Allocator,
        sender: *MockSenderType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            RequestSender.fromMockSender(sender),
            .{
                .endpoint = options.endpoint,
                .commitment = options.commitment,
                .request_timeout_ms = options.request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = options.confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithOwnedMockSender(
        allocator: Allocator,
        sender: MockSenderType,
    ) !RpcClient {
        return RpcClient.newWithRequestSender(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
        );
    }

    pub fn newWithOwnedMockSenderAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithOwnedMockSenderAndOptions(
            allocator,
            sender,
            .{ .commitment = commitment },
        );
    }

    pub fn newWithOwnedMockSenderAndTimeout(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithOwnedMockSenderAndOptions(
            allocator,
            sender,
            .{ .request_timeout_ms = timeout_ms },
        );
    }

    pub fn newWithOwnedMockSenderAndTimeouts(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndTimeouts(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newWithOwnedMockSenderAndCommitmentAndTimeout(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithOwnedMockSenderAndTimeoutAndCommitment(
            allocator,
            sender,
            timeout_ms,
            commitment,
        );
    }

    pub fn newWithOwnedMockSenderAndTimeoutAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndTimeoutAndCommitment(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
            timeout_ms,
            commitment,
        );
    }

    pub fn newWithOwnedMockSenderAndCommitmentAndTimeouts(
        allocator: Allocator,
        sender: MockSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithOwnedMockSenderAndTimeoutsAndCommitment(
            allocator,
            sender,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
            commitment,
        );
    }

    pub fn newWithOwnedMockSenderAndTimeoutsAndCommitment(
        allocator: Allocator,
        sender: MockSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
            .{
                .commitment = commitment,
                .request_timeout_ms = timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithOwnedMockSenderAndOptions(
        allocator: Allocator,
        sender: MockSenderType,
        options: MockClientOptions,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
            .{
                .commitment = options.commitment,
                .request_timeout_ms = options.request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = options.confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithOwnedMockSenderAndRequestSenderOptions(
        allocator: Allocator,
        sender: MockSenderType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            try RequestSender.fromOwnedMockSender(allocator, sender),
            .{
                .endpoint = options.endpoint,
                .commitment = options.commitment,
                .request_timeout_ms = options.request_timeout_ms,
                .confirm_transaction_initial_timeout_ms = options.confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithRequestSenderAndCommitment(
        allocator: Allocator,
        sender: RequestSenderType,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            sender,
            .{ .commitment = commitment },
        );
    }

    pub fn newWithRequestSenderAndTimeout(
        allocator: Allocator,
        sender: RequestSenderType,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            sender,
            .{ .request_timeout_ms = timeout_ms },
        );
    }

    pub fn newWithRequestSenderAndTimeouts(
        allocator: Allocator,
        sender: RequestSenderType,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            sender,
            .{
                .request_timeout_ms = timeout_ms,
                .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
            },
        );
    }

    pub fn newWithRequestSenderAndCommitmentAndTimeout(
        allocator: Allocator,
        sender: RequestSenderType,
        commitment: ?Commitment,
        timeout_ms: u64,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            sender,
            .{
                .commitment = commitment,
                .request_timeout_ms = timeout_ms,
            },
        );
    }

    pub fn newWithRequestSenderAndTimeoutAndCommitment(
        allocator: Allocator,
        sender: RequestSenderType,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return RpcClient.newWithRequestSenderAndOptions(
            allocator,
            sender,
            .{
                .request_timeout_ms = timeout_ms,
                .commitment = commitment,
            },
        );
    }

    pub fn newWithRequestSenderAndOptions(
        allocator: Allocator,
        sender: RequestSenderType,
        options: RequestSenderOptions,
    ) !RpcClient {
        return lifecycle_methods.initClientWithRequestSender(
            RpcClient,
            allocator,
            options.endpoint,
            sender,
            options.commitment,
            options.request_timeout_ms,
            options.confirm_transaction_initial_timeout_ms,
        );
    }

    pub fn newWithCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment, null, null);
    }

    pub fn newWithTimeout(allocator: Allocator, endpoint: []const u8, timeout_ms: u64) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, null, timeout_ms, null);
    }

    pub fn newWithTimeoutAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment, timeout_ms, null);
    }

    pub fn newWithTimeoutsAndCommitment(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
        confirm_transaction_initial_timeout_ms: u64,
        commitment: ?Commitment,
    ) !RpcClient {
        return lifecycle_methods.initClient(
            RpcClient,
            allocator,
            endpoint,
            commitment,
            timeout_ms,
            confirm_transaction_initial_timeout_ms,
        );
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
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, commitment, null, null);
    }

    pub fn newSocketWithTimeout(
        allocator: Allocator,
        endpoint: []const u8,
        timeout_ms: u64,
    ) !RpcClient {
        return lifecycle_methods.initClient(RpcClient, allocator, endpoint, null, timeout_ms, null);
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

    pub fn getInnerClient(self: *const RpcClient) *const std.http.Client {
        return &self.http_client;
    }

    pub fn getInnerClientMut(self: *RpcClient) *std.http.Client {
        return &self.http_client;
    }

    pub fn isMock(self: *const RpcClient) bool {
        return self.mock_sender != null;
    }

    pub fn hasRequestSender(self: *const RpcClient) bool {
        return self.request_sender != null and self.mock_sender == null;
    }

    pub fn mockResponseCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.responseCount() else 0;
    }

    pub fn mockRouteCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.routeCount() else 0;
    }

    pub fn mockMatchedRouteCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.matchedRouteCount() else 0;
    }

    pub fn mockRouteMatchCount(self: *const RpcClient, label: []const u8) usize {
        return if (self.mock_sender) |sender| sender.routeMatchCountForLabel(label) else 0;
    }

    pub fn mockPersistentRouteCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.persistentRouteCount() else 0;
    }

    pub fn mockPendingScriptedDispatchCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.pendingScriptedDispatchCount() else 0;
    }

    pub fn mockScriptMissCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.scriptMissCount() else 0;
    }

    pub fn mockRequestCount(self: *const RpcClient) usize {
        return if (self.mock_sender) |sender| sender.requestCount() else 0;
    }

    pub fn hasMockHandler(self: *const RpcClient) bool {
        return if (self.mock_sender) |sender| sender.hasHandler() else false;
    }

    pub fn requestSender(self: *RpcClient) !*RequestSenderType {
        if (self.mock_sender != null) return error.NoRequestSender;
        return if (self.request_sender) |*sender| sender else error.NoRequestSender;
    }

    pub fn getInnerRequestSender(self: *const RpcClient) !*const RequestSenderType {
        if (self.mock_sender != null) return error.NoRequestSender;
        return if (self.request_sender) |*sender| sender else error.NoRequestSender;
    }

    pub fn getInnerRequestSenderMut(self: *RpcClient) !*RequestSenderType {
        if (self.mock_sender != null) return error.NoRequestSender;
        return if (self.request_sender) |*sender| sender else error.NoRequestSender;
    }

    pub fn requestSenderConst(self: *const RpcClient) !*const RequestSenderType {
        if (self.mock_sender != null) return error.NoRequestSender;
        return if (self.request_sender) |*sender| sender else error.NoRequestSender;
    }

    pub fn mockSender(self: *RpcClient) !*MockSenderType {
        return if (self.mock_sender) |sender| sender else error.NotMockClient;
    }

    pub fn mockSenderConst(self: *const RpcClient) !*const MockSenderType {
        return if (self.mock_sender) |sender| sender else error.NotMockClient;
    }

    pub fn capturedMockRequests(self: *const RpcClient) []const MockRequestType {
        return if (self.mock_sender) |sender| sender.capturedRequests() else &.{};
    }

    pub fn lastMockScriptMissRequest(self: *const RpcClient) ?MockRequestViewType {
        return if (self.mock_sender) |sender| sender.lastScriptMissRequest() else null;
    }

    pub fn mockScriptSummaryAlloc(self: *const RpcClient, allocator: Allocator) ![]u8 {
        return if (self.mock_sender) |sender| sender.scriptSummaryAlloc(allocator) else allocator.dupe(u8, "not a mock client\n");
    }

    pub fn clearCapturedMockRequests(self: *RpcClient) void {
        if (self.mock_sender) |sender| sender.clearCapturedRequests();
    }

    pub fn clearMockResponses(self: *RpcClient) void {
        if (self.mock_sender) |sender| sender.clearResponses();
    }

    pub fn clearMockRoutes(self: *RpcClient) void {
        if (self.mock_sender) |sender| sender.clearRoutes();
    }

    pub fn replaceMockSender(self: *RpcClient, sender: MockSenderType) !void {
        if (self.mock_sender) |existing| {
            existing.deinit();
            self.allocator.destroy(existing);
            const replacement = try self.allocator.create(MockSenderType);
            replacement.* = sender;
            self.mock_sender = replacement;
            self.request_sender = lifecycle_methods.makeMockRequestSender(replacement);
            self.request_id = 1;
            self.transport_stats = .{};
            return;
        }

        return error.NotMockClient;
    }

    pub fn replaceRequestSender(self: *RpcClient, sender: RequestSenderType) !void {
        if (self.mock_sender != null) return error.NoRequestSender;
        if (self.request_sender) |existing| {
            existing.deinit(self.allocator);
            self.request_sender = sender;
            self.request_id = 1;
            self.transport_stats = .{};
            return;
        }

        return error.NoRequestSender;
    }

    pub fn setMockHandler(self: *RpcClient, handler: MockRequestHandlerType) !void {
        if (self.mock_sender) |sender| {
            sender.setHandler(handler);
            return;
        }

        return error.NotMockClient;
    }

    pub fn clearMockHandler(self: *RpcClient) !void {
        if (self.mock_sender) |sender| {
            sender.clearHandler();
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockResponse(self: *RpcClient, response: MockResponseType) !void {
        if (self.mock_sender) |sender| {
            try sender.pushResponse(response);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockJsonResponse(self: *RpcClient, response_body: []const u8) !void {
        if (self.mock_sender) |sender| {
            try sender.pushJsonResponse(response_body);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockResultJson(self: *RpcClient, result_json: []const u8) !void {
        if (self.mock_sender) |sender| {
            try sender.pushResultJson(result_json);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockStringResult(self: *RpcClient, value: []const u8) !void {
        if (self.mock_sender) |sender| {
            try sender.pushStringResult(value);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSlotResult(self: *RpcClient, slot: u64) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSlotResult(slot);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockBoolResult(self: *RpcClient, value: bool) !void {
        if (self.mock_sender) |sender| {
            try sender.pushBoolResult(value);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockNullResult(self: *RpcClient) !void {
        if (self.mock_sender) |sender| {
            try sender.pushNullResult();
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockBalanceResponse(
        self: *RpcClient,
        context_slot: u64,
        value: u64,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushBalanceResponse(context_slot, value);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockBalancePollResults(
        self: *RpcClient,
        steps: []const MockBalancePollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushBalancePollResults(steps);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockFeeForMessageResponse(
        self: *RpcClient,
        context_slot: u64,
        value: ?u64,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushFeeForMessageResponse(context_slot, value);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockTokenAmountResponse(
        self: *RpcClient,
        context_slot: u64,
        value: TokenAmountType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushTokenAmountResponse(context_slot, value);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockTokenLargestAccountsResponse(
        self: *RpcClient,
        context_slot: u64,
        accounts: []const TokenLargestAccountType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushTokenLargestAccountsResponse(context_slot, accounts);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockAccountInfoResponse(
        self: *RpcClient,
        context_slot: u64,
        account: ?AccountInfoType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushAccountInfoResponse(context_slot, account);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockUiAccountResponse(
        self: *RpcClient,
        context_slot: u64,
        account: ?JsonParsedAccountInfoType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushUiAccountResponse(context_slot, account);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockMultipleUiAccountsResponse(
        self: *RpcClient,
        context_slot: u64,
        accounts: []const ?JsonParsedAccountInfoType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushMultipleUiAccountsResponse(context_slot, accounts);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockProgramUiAccountsResponse(
        self: *RpcClient,
        context_slot: ?u64,
        accounts: []const JsonParsedProgramAccountType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushProgramUiAccountsResponse(context_slot, accounts);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockHealthOk(self: *RpcClient) !void {
        if (self.mock_sender) |sender| {
            try sender.pushHealthOk();
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSignatureResult(self: *RpcClient, signature: []const u8) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSignatureResult(signature);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSignatureStatusesResult(
        self: *RpcClient,
        context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSignatureStatusesResult(context_slot, statuses);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSingleSignatureStatusResult(
        self: *RpcClient,
        context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSingleSignatureStatusResult(context_slot, status);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSignatureStatusNotFound(self: *RpcClient, context_slot: u64) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSignatureStatusNotFound(context_slot);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSignatureStatusPollResults(
        self: *RpcClient,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSignatureStatusPollResults(steps);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSignatureObservationPollResults(
        self: *RpcClient,
        steps: []const MockSignatureObservationPollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSignatureObservationPollResults(steps);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockLatestBlockhashResponse(
        self: *RpcClient,
        context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushLatestBlockhashResponse(context_slot, blockhash, last_valid_block_height);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockLatestBlockhashSendAndSignatureStatusesFlow(
        self: *RpcClient,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        statuses_context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushLatestBlockhashSendAndSignatureStatusesFlow(
                latest_blockhash_context_slot,
                blockhash,
                last_valid_block_height,
                signature,
                statuses_context_slot,
                statuses,
            );
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockSendAndSignatureStatusPollFlow(
        self: *RpcClient,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushSendAndSignatureStatusPollFlow(signature, steps);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        self: *RpcClient,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushLatestBlockhashSendAndSignatureStatusPollFlow(
                latest_blockhash_context_slot,
                blockhash,
                last_valid_block_height,
                signature,
                steps,
            );
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockConfirmTransactionSpinnerFlow(
        self: *RpcClient,
        observation_steps: []const MockSignatureObservationPollStep,
        confirmation_steps: []const MockSignatureStatusPollStep,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushConfirmTransactionSpinnerFlow(
                observation_steps,
                confirmation_steps,
            );
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockLatestBlockhashSendAndSingleSignatureStatusFlow(
        self: *RpcClient,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushLatestBlockhashSendAndSingleSignatureStatusFlow(
                latest_blockhash_context_slot,
                blockhash,
                last_valid_block_height,
                signature,
                status_context_slot,
                status,
            );
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockLatestBlockhashSendAndStatusNotFoundFlow(
        self: *RpcClient,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushLatestBlockhashSendAndStatusNotFoundFlow(
                latest_blockhash_context_slot,
                blockhash,
                last_valid_block_height,
                signature,
                status_context_slot,
            );
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockRpcError(self: *RpcClient, rpc_error: MockRpcErrorType) !void {
        if (self.mock_sender) |sender| {
            try sender.pushRpcError(rpc_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockTransportError(self: *RpcClient, transport_error: MockTransportErrorType) !void {
        if (self.mock_sender) |sender| {
            try sender.pushTransportError(transport_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockRoute(self: *RpcClient, route: MockRouteType) !void {
        if (self.mock_sender) |sender| {
            try sender.pushRoute(route);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockRouteBuilder(self: *RpcClient, builder: MockRouteBuilder) !void {
        if (self.mock_sender) |sender| {
            try sender.pushRouteBuilder(builder);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockRouteBuilders(self: *RpcClient, builders: []const MockRouteBuilder) !void {
        if (self.mock_sender) |sender| {
            try sender.pushRouteBuilders(builders);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockOnceRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        response: MockResponseType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushOnceRoute(matcher, response);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockPersistentRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        response: MockResponseType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushPersistentRoute(matcher, response);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockResultRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        result_json: []const u8,
        remaining_uses: ?usize,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushResultRoute(matcher, result_json, remaining_uses);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockOnceResultRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        result_json: []const u8,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushOnceResultRoute(matcher, result_json);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockPersistentResultRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        result_json: []const u8,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushPersistentResultRoute(matcher, result_json);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockRpcErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        rpc_error: MockRpcErrorType,
        remaining_uses: ?usize,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushRpcErrorRoute(matcher, rpc_error, remaining_uses);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockOnceRpcErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        rpc_error: MockRpcErrorType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushOnceRpcErrorRoute(matcher, rpc_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockPersistentRpcErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        rpc_error: MockRpcErrorType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushPersistentRpcErrorRoute(matcher, rpc_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockTransportErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        transport_error: MockTransportErrorType,
        remaining_uses: ?usize,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushTransportErrorRoute(matcher, transport_error, remaining_uses);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockOnceTransportErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        transport_error: MockTransportErrorType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushOnceTransportErrorRoute(matcher, transport_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn pushMockPersistentTransportErrorRoute(
        self: *RpcClient,
        matcher: MockRequestMatcherType,
        transport_error: MockTransportErrorType,
    ) !void {
        if (self.mock_sender) |sender| {
            try sender.pushPersistentTransportErrorRoute(matcher, transport_error);
            return;
        }

        return error.NotMockClient;
    }

    pub fn getDefaultCommitment(self: *const RpcClient) ?Commitment {
        return self.default_commitment;
    }

    pub fn getRequestTimeoutMs(self: *const RpcClient) ?u64 {
        return self.request_timeout_ms;
    }

    pub fn getConfirmTransactionInitialTimeoutMs(self: *const RpcClient) ?u64 {
        return self.confirm_transaction_initial_timeout_ms;
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
