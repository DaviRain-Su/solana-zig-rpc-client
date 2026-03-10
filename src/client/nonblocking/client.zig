const std = @import("std");
const rpc_client = @import("../rpc_client/client.zig");
const lifecycle_methods = @import("../rpc_client/lifecycle.zig");
const rpc_types = @import("../rpc_types.zig");

const Allocator = std.mem.Allocator;
const BalanceResponse = rpc_types.BalanceResponse;
const BlockProduction = rpc_types.BlockProduction;
const ClusterNode = rpc_types.ClusterNode;
const Commitment = rpc_types.Commitment;
const EpochSchedule = rpc_types.EpochSchedule;
const EpochInfo = rpc_types.EpochInfo;
const InflationGovernor = rpc_types.InflationGovernor;
const InflationRate = rpc_types.InflationRate;
const LatestBlockhash = rpc_types.LatestBlockhash;
const LatestBlockhashResponse = rpc_types.LatestBlockhashResponse;
const LeaderSchedule = rpc_types.LeaderSchedule;
const SnapshotSlots = rpc_types.SnapshotSlots;
const Supply = rpc_types.Supply;
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
    pub const SupplyTask = AsyncTask(Supply, runGetSupply);
    pub const EpochInfoTask = AsyncTask(EpochInfo, runGetEpochInfo);
    pub const EpochScheduleTask = AsyncTask(EpochSchedule, runGetEpochSchedule);
    pub const FeatureActivationSlotTask = AsyncTask(?u64, runGetFeatureActivationSlot);
    pub const BlockTimeTask = AsyncTask(?i64, runGetBlockTime);
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
    pub const BlockProductionTask = AsyncTask(BlockProduction, runGetBlockProduction);
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
