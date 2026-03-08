const std = @import("std");
const rpc_types = @import("../rpc_types.zig");

const Allocator = std.mem.Allocator;
const AccountInfo = rpc_types.AccountInfo;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const TokenAmount = rpc_types.TokenAmount;
const TokenLargestAccount = rpc_types.TokenLargestAccount;

pub const MockRpcError = struct {
    code: i64,
    message: []const u8,
    data_json: ?[]const u8 = null,

    pub fn dupe(self: MockRpcError, allocator: Allocator) !MockRpcError {
        return .{
            .code = self.code,
            .message = try allocator.dupe(u8, self.message),
            .data_json = if (self.data_json) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: MockRpcError, allocator: Allocator) void {
        allocator.free(self.message);
        if (self.data_json) |value| allocator.free(value);
    }
};

pub const MockTransportError = enum {
    timeout,
    connection_reset,
    http_error,
};

pub const MockResponse = union(enum) {
    json: []const u8,
    result_json: []const u8,
    rpc_error: MockRpcError,
    transport_error: MockTransportError,
};

pub const MockRequestView = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,
};

pub const MockSignatureStatus = rpc_types.SignatureStatus;

pub const MockSignatureStatusPollStep = struct {
    context_slot: u64,
    status: ?MockSignatureStatus,
};

pub const MockSignatureObservationPollStep = struct {
    context_slot: u64,
    status: ?MockSignatureStatus,
    blockhash_still_valid: ?bool = null,
};

pub const MockBalancePollStep = struct {
    context_slot: u64,
    value: u64,
};

pub const MockRequestMatcher = struct {
    method: ?[]const u8 = null,
    params_json_contains: ?[]const u8 = null,
    request_body_contains: ?[]const u8 = null,

    pub fn dupe(self: MockRequestMatcher, allocator: Allocator) !MockRequestMatcher {
        return .{
            .method = if (self.method) |value| try allocator.dupe(u8, value) else null,
            .params_json_contains = if (self.params_json_contains) |value| try allocator.dupe(u8, value) else null,
            .request_body_contains = if (self.request_body_contains) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: MockRequestMatcher, allocator: Allocator) void {
        if (self.method) |value| allocator.free(value);
        if (self.params_json_contains) |value| allocator.free(value);
        if (self.request_body_contains) |value| allocator.free(value);
    }

    pub fn matches(self: MockRequestMatcher, request: MockRequestView) bool {
        if (self.method) |value| {
            if (!std.mem.eql(u8, request.method, value)) return false;
        }
        if (self.params_json_contains) |value| {
            if (std.mem.indexOf(u8, request.params_json, value) == null) return false;
        }
        if (self.request_body_contains) |value| {
            if (std.mem.indexOf(u8, request.request_body, value) == null) return false;
        }
        return true;
    }
};

pub const MockHandlerResponse = union(enum) {
    json: []u8,
    result_json: []u8,
    rpc_error: MockRpcError,
    transport_error: MockTransportError,
};

pub const MockRequestHandler = struct {
    context: ?*anyopaque = null,
    callback: *const fn (context: ?*anyopaque, allocator: Allocator, request: MockRequestView) anyerror!MockHandlerResponse,
};

pub const MockRequest = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,

    pub fn deinit(self: MockRequest, allocator: Allocator) void {
        allocator.free(self.method);
        allocator.free(self.params_json);
        allocator.free(self.request_body);
    }
};

const MockRouteMatchCount = struct {
    label: []const u8,
    count: usize,
};

fn cloneResponse(allocator: Allocator, response: MockResponse) !MockResponse {
    return switch (response) {
        .json => |value| .{ .json = try allocator.dupe(u8, value) },
        .result_json => |value| .{ .result_json = try allocator.dupe(u8, value) },
        .rpc_error => |value| .{ .rpc_error = try value.dupe(allocator) },
        .transport_error => |value| .{ .transport_error = value },
    };
}

fn freeResponse(allocator: Allocator, response: MockResponse) void {
    switch (response) {
        .json => |value| allocator.free(value),
        .result_json => |value| allocator.free(value),
        .rpc_error => |value| value.deinit(allocator),
        .transport_error => {},
    }
}

fn formatResultEnvelope(allocator: Allocator, request_id: u64, result_json: []const u8) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

fn encodeJsonString(allocator: Allocator, value: []const u8) ![]u8 {
    var out = std.io.Writer.Allocating.init(allocator);
    errdefer out.deinit();

    try out.writer.writeByte('"');
    for (value) |byte| {
        switch (byte) {
            '"' => try out.writer.writeAll("\\\""),
            '\\' => try out.writer.writeAll("\\\\"),
            '\n' => try out.writer.writeAll("\\n"),
            '\r' => try out.writer.writeAll("\\r"),
            '\t' => try out.writer.writeAll("\\t"),
            else => {
                if (byte < 0x20) {
                    try out.writer.print("\\u{X:0>4}", .{@as(u8, byte)});
                } else {
                    try out.writer.writeByte(byte);
                }
            },
        }
    }
    try out.writer.writeByte('"');

    const encoded = try allocator.dupe(u8, out.written());
    out.deinit();
    return encoded;
}

fn formatRpcErrorEnvelope(allocator: Allocator, request_id: u64, rpc_error: MockRpcError) ![]u8 {
    const encoded_message = try encodeJsonString(allocator, rpc_error.message);
    defer allocator.free(encoded_message);

    return if (rpc_error.data_json) |data_json|
        try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":{},\"message\":{s},\"data\":{s}}},\"id\":{}}}",
            .{ rpc_error.code, encoded_message, data_json, request_id },
        )
    else
        try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":{},\"message\":{s}}},\"id\":{}}}",
            .{ rpc_error.code, encoded_message, request_id },
        );
}

fn writeEncodedJsonString(writer: *std.Io.Writer, allocator: Allocator, value: []const u8) !void {
    const encoded = try encodeJsonString(allocator, value);
    defer allocator.free(encoded);
    try writer.writeAll(encoded);
}

fn writeOptionalU64Json(writer: *std.Io.Writer, value: ?u64) !void {
    if (value) |unwrapped| {
        try writer.print("{}", .{unwrapped});
    } else {
        try writer.writeAll("null");
    }
}

fn writeOptionalF64Json(writer: *std.Io.Writer, value: ?f64) !void {
    if (value) |unwrapped| {
        try writer.print("{d}", .{unwrapped});
    } else {
        try writer.writeAll("null");
    }
}

fn writeTokenAmountJson(writer: *std.Io.Writer, allocator: Allocator, value: TokenAmount) !void {
    try writer.writeAll("{\"amount\":");
    try writeEncodedJsonString(writer, allocator, value.amount);
    try writer.print(",\"decimals\":{},\"uiAmount\":", .{value.decimals});
    try writeOptionalF64Json(writer, value.ui_amount);
    try writer.writeAll(",\"uiAmountString\":");
    try writeEncodedJsonString(writer, allocator, value.ui_amount_string);
    try writer.writeByte('}');
}

fn writeAccountInfoJson(writer: *std.Io.Writer, allocator: Allocator, account: AccountInfo) !void {
    try writer.writeAll("{\"data\":");
    if (account.data) |data| {
        try writer.writeByte('[');
        try writeEncodedJsonString(writer, allocator, data);
        try writer.writeByte(',');
        try writeEncodedJsonString(writer, allocator, account.data_encoding orelse "base64");
        try writer.writeByte(']');
    } else {
        try writer.writeAll("null");
    }
    try writer.print(
        ",\"executable\":{s},\"lamports\":{},\"owner\":",
        .{ if (account.executable) "true" else "false", account.lamports },
    );
    try writeEncodedJsonString(writer, allocator, account.owner);
    try writer.writeAll(",\"rentEpoch\":");
    try writeOptionalU64Json(writer, account.rent_epoch);
    try writer.writeAll(",\"space\":");
    try writeOptionalU64Json(writer, account.space);
    try writer.writeByte('}');
}

fn writeJsonParsedAccountInfoJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    account: JsonParsedAccountInfo,
) !void {
    try writer.writeAll("{\"data\":");
    if (account.data_json.len == 0) {
        try writer.writeAll("null");
    } else {
        try writer.writeAll(account.data_json);
    }
    try writer.print(
        ",\"executable\":{s},\"lamports\":{},\"owner\":",
        .{ if (account.executable) "true" else "false", account.lamports },
    );
    try writeEncodedJsonString(writer, allocator, account.owner);
    try writer.writeAll(",\"rentEpoch\":");
    try writeOptionalU64Json(writer, account.rent_epoch);
    try writer.writeAll(",\"space\":");
    try writeOptionalU64Json(writer, account.space);
    try writer.writeByte('}');
}

fn writeJsonParsedProgramAccountJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    account: JsonParsedProgramAccount,
) !void {
    try writer.writeAll("{\"pubkey\":");
    try writeEncodedJsonString(writer, allocator, account.pubkey);
    try writer.writeAll(",\"account\":");
    try writeJsonParsedAccountInfoJson(writer, allocator, account.account);
    try writer.writeByte('}');
}

pub const MockRoute = struct {
    label: ?[]const u8 = null,
    matcher: MockRequestMatcher = .{},
    response: MockResponse,
    remaining_uses: ?usize = 1,
    match_count: usize = 0,

    pub fn once(matcher: MockRequestMatcher, response: MockResponse) MockRoute {
        return .{
            .matcher = matcher,
            .response = response,
            .remaining_uses = 1,
        };
    }

    pub fn onceNamed(label: []const u8, matcher: MockRequestMatcher, response: MockResponse) MockRoute {
        return .{
            .label = label,
            .matcher = matcher,
            .response = response,
            .remaining_uses = 1,
        };
    }

    pub fn persistent(matcher: MockRequestMatcher, response: MockResponse) MockRoute {
        return .{
            .matcher = matcher,
            .response = response,
            .remaining_uses = null,
        };
    }

    pub fn persistentNamed(label: []const u8, matcher: MockRequestMatcher, response: MockResponse) MockRoute {
        return .{
            .label = label,
            .matcher = matcher,
            .response = response,
            .remaining_uses = null,
        };
    }

    pub fn named(
        label: []const u8,
        matcher: MockRequestMatcher,
        response: MockResponse,
        remaining_uses: ?usize,
    ) MockRoute {
        return .{
            .label = label,
            .matcher = matcher,
            .response = response,
            .remaining_uses = remaining_uses,
        };
    }

    pub fn isPersistent(self: MockRoute) bool {
        return self.remaining_uses == null;
    }

    pub fn pendingDispatchCount(self: MockRoute) usize {
        return self.remaining_uses orelse 0;
    }

    pub fn dupe(self: MockRoute, allocator: Allocator) !MockRoute {
        return .{
            .label = if (self.label) |value| try allocator.dupe(u8, value) else null,
            .matcher = try self.matcher.dupe(allocator),
            .response = try cloneResponse(allocator, self.response),
            .remaining_uses = self.remaining_uses,
            .match_count = self.match_count,
        };
    }

    pub fn deinit(self: MockRoute, allocator: Allocator) void {
        if (self.label) |value| allocator.free(value);
        self.matcher.deinit(allocator);
        freeResponse(allocator, self.response);
    }
};

pub const MockRouteBuilder = struct {
    label_value: ?[]const u8 = null,
    matcher_value: MockRequestMatcher = .{},
    response_value: ?MockResponse = null,
    remaining_uses_value: ?usize = 1,

    pub fn init() MockRouteBuilder {
        return .{};
    }

    pub fn label(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        var next = self;
        next.label_value = value;
        return next;
    }

    pub fn method(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        var next = self;
        next.matcher_value.method = value;
        return next;
    }

    pub fn rpcRequest(self: MockRouteBuilder, request: rpc_types.RpcRequest) MockRouteBuilder {
        return self.method(request.method);
    }

    pub fn paramsJsonContains(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        var next = self;
        next.matcher_value.params_json_contains = value;
        return next;
    }

    pub fn commitment(self: MockRouteBuilder, value: ?rpc_types.Commitment) MockRouteBuilder {
        if (value) |commitment_value| {
            return self.paramsJsonContains(rpc_types.commitmentToString(commitment_value));
        }
        return self;
    }

    pub fn requestBodyContains(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        var next = self;
        next.matcher_value.request_body_contains = value;
        return next;
    }

    pub fn matchGetSlot(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSlot).commitment(commitment_value);
    }

    pub fn matchGetHealth(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getHealth);
    }

    pub fn matchGetBlockCommitment(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlockCommitment);
    }

    pub fn matchGetBlockHeight(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlockHeight);
    }

    pub fn matchGetBlockProduction(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlockProduction);
    }

    pub fn matchGetBlockTime(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlockTime);
    }

    pub fn matchGetBlocks(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlocks);
    }

    pub fn matchGetBlocksWithLimit(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlocksWithLimit);
    }

    pub fn matchGetClusterNodes(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getClusterNodes);
    }

    pub fn matchGetFeatureActivationSlot(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getFeatureActivationSlot);
    }

    pub fn matchGetAccountInfo(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getAccountInfo).commitment(commitment_value);
    }

    pub fn matchGetBalance(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBalance).commitment(commitment_value);
    }

    pub fn matchGetFeeForMessage(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getFeeForMessage).commitment(commitment_value);
    }

    pub fn matchGetFirstAvailableBlock(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getFirstAvailableBlock);
    }

    pub fn matchGetInflationGovernor(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getInflationGovernor);
    }

    pub fn matchGetInflationRate(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getInflationRate);
    }

    pub fn matchGetInflationReward(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getInflationReward);
    }

    pub fn matchGetLargestAccounts(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getLargestAccounts);
    }

    pub fn matchGetBlock(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getBlock).commitment(commitment_value);
    }

    pub fn matchGetMaxRetransmitSlot(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getMaxRetransmitSlot);
    }

    pub fn matchGetMaxShredInsertSlot(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getMaxShredInsertSlot);
    }

    pub fn matchGetMinimumBalanceForRentExemption(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getMinimumBalanceForRentExemption);
    }

    pub fn matchGetMultipleAccounts(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getMultipleAccounts);
    }

    pub fn matchGetProgramAccounts(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getProgramAccounts);
    }

    pub fn matchGetRecentPerformanceSamples(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getRecentPerformanceSamples);
    }

    pub fn matchGetRecentPrioritizationFees(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getRecentPrioritizationFees);
    }

    pub fn matchGetLatestBlockhash(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getLatestBlockhash).commitment(commitment_value);
    }

    pub fn matchGetStakeMinimumDelegation(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getStakeMinimumDelegation);
    }

    pub fn matchGetTokenAccountBalance(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTokenAccountBalance);
    }

    pub fn matchGetTokenAccountsByDelegate(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTokenAccountsByDelegate);
    }

    pub fn matchGetTokenAccountsByOwner(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTokenAccountsByOwner);
    }

    pub fn matchGetTokenLargestAccounts(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTokenLargestAccounts);
    }

    pub fn matchGetTokenSupply(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTokenSupply);
    }

    pub fn matchGetSignatureStatuses(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSignatureStatuses).commitment(commitment_value);
    }

    pub fn matchGetSignaturesForAddress(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSignaturesForAddress).commitment(commitment_value);
    }

    pub fn matchGetSlotLeaders(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSlotLeaders);
    }

    pub fn matchGetTransaction(self: MockRouteBuilder, commitment_value: ?rpc_types.Commitment) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTransaction).commitment(commitment_value);
    }

    pub fn matchGetEpochInfo(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getEpochInfo);
    }

    pub fn matchGetEpochSchedule(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getEpochSchedule);
    }

    pub fn matchGetGenesisHash(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getGenesisHash);
    }

    pub fn matchGetHighestSnapshotSlot(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getHighestSnapshotSlot);
    }

    pub fn matchGetIdentity(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getIdentity);
    }

    pub fn matchGetLeaderSchedule(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getLeaderSchedule);
    }

    pub fn matchGetMinimumLedgerSlot(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.minimumLedgerSlot);
    }

    pub fn matchGetSlotLeader(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSlotLeader);
    }

    pub fn matchGetSupply(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getSupply);
    }

    pub fn matchGetTransactionCount(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getTransactionCount);
    }

    pub fn matchGetVoteAccounts(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getVoteAccounts);
    }

    pub fn matchIsBlockhashValid(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.isBlockhashValid);
    }

    pub fn matchGetVersion(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.getVersion);
    }

    pub fn matchRequestAirdrop(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.requestAirdrop);
    }

    pub fn matchSendTransaction(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.sendTransaction);
    }

    pub fn matchSimulateTransaction(self: MockRouteBuilder) MockRouteBuilder {
        return self.rpcRequest(rpc_types.RpcRequest.simulateTransaction);
    }

    pub fn response(self: MockRouteBuilder, value: MockResponse) MockRouteBuilder {
        var next = self;
        next.response_value = value;
        return next;
    }

    pub fn json(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        return self.response(.{ .json = value });
    }

    pub fn resultJson(self: MockRouteBuilder, value: []const u8) MockRouteBuilder {
        return self.response(.{ .result_json = value });
    }

    pub fn rpcError(self: MockRouteBuilder, value: MockRpcError) MockRouteBuilder {
        return self.response(.{ .rpc_error = value });
    }

    pub fn transportError(self: MockRouteBuilder, value: MockTransportError) MockRouteBuilder {
        return self.response(.{ .transport_error = value });
    }

    pub fn uses(self: MockRouteBuilder, value: ?usize) MockRouteBuilder {
        var next = self;
        next.remaining_uses_value = value;
        return next;
    }

    pub fn once(self: MockRouteBuilder) MockRouteBuilder {
        return self.uses(1);
    }

    pub fn persistent(self: MockRouteBuilder) MockRouteBuilder {
        return self.uses(null);
    }

    pub fn build(self: MockRouteBuilder) !MockRoute {
        return .{
            .label = self.label_value,
            .matcher = self.matcher_value,
            .response = self.response_value orelse return error.MockRouteResponseRequired,
            .remaining_uses = self.remaining_uses_value,
        };
    }
};

pub const MockSender = struct {
    allocator: Allocator,
    responses: std.ArrayListUnmanaged(MockResponse) = .{},
    routes: std.ArrayListUnmanaged(MockRoute) = .{},
    route_match_counts: std.ArrayListUnmanaged(MockRouteMatchCount) = .{},
    requests: std.ArrayListUnmanaged(MockRequest) = .{},
    handler: ?MockRequestHandler = null,
    matched_route_count: usize = 0,
    script_miss_count: usize = 0,
    last_script_miss_request_index: ?usize = null,

    pub fn init(allocator: Allocator) MockSender {
        return .{ .allocator = allocator };
    }

    pub fn initWithHandler(allocator: Allocator, handler: MockRequestHandler) MockSender {
        return .{
            .allocator = allocator,
            .handler = handler,
        };
    }

    pub fn initSequence(allocator: Allocator, responses: []const MockResponse) !MockSender {
        var sender = MockSender.init(allocator);
        errdefer sender.deinit();

        for (responses) |response| {
            try sender.pushResponse(response);
        }

        return sender;
    }

    pub fn deinit(self: *MockSender) void {
        for (self.responses.items) |response| {
            freeResponse(self.allocator, response);
        }
        self.responses.deinit(self.allocator);

        for (self.routes.items) |route| {
            route.deinit(self.allocator);
        }
        self.routes.deinit(self.allocator);

        for (self.route_match_counts.items) |entry| {
            self.allocator.free(entry.label);
        }
        self.route_match_counts.deinit(self.allocator);

        for (self.requests.items) |request| {
            request.deinit(self.allocator);
        }
        self.requests.deinit(self.allocator);
    }

    pub fn hasHandler(self: *const MockSender) bool {
        return self.handler != null;
    }

    pub fn setHandler(self: *MockSender, handler: MockRequestHandler) void {
        self.handler = handler;
    }

    pub fn clearHandler(self: *MockSender) void {
        self.handler = null;
    }

    pub fn clearResponses(self: *MockSender) void {
        for (self.responses.items) |response| {
            freeResponse(self.allocator, response);
        }
        self.responses.clearRetainingCapacity();
    }

    pub fn pushResponse(self: *MockSender, response: MockResponse) !void {
        try self.responses.append(self.allocator, try cloneResponse(self.allocator, response));
    }

    pub fn pushJsonResponse(self: *MockSender, response_body: []const u8) !void {
        try self.pushResponse(.{ .json = response_body });
    }

    pub fn pushStringResult(self: *MockSender, value: []const u8) !void {
        const encoded = try encodeJsonString(self.allocator, value);
        defer self.allocator.free(encoded);
        try self.pushResultJson(encoded);
    }

    pub fn pushSlotResult(self: *MockSender, slot: u64) !void {
        const result_json = try std.fmt.allocPrint(self.allocator, "{}", .{slot});
        defer self.allocator.free(result_json);
        try self.pushResultJson(result_json);
    }

    pub fn pushBoolResult(self: *MockSender, value: bool) !void {
        try self.pushResultJson(if (value) "true" else "false");
    }

    pub fn pushNullResult(self: *MockSender) !void {
        try self.pushResultJson("null");
    }

    pub fn pushBalanceResponse(self: *MockSender, context_slot: u64, value: u64) !void {
        const result_json = try std.fmt.allocPrint(
            self.allocator,
            "{{\"context\":{{\"slot\":{}}},\"value\":{}}}",
            .{ context_slot, value },
        );
        defer self.allocator.free(result_json);
        try self.pushResultJson(result_json);
    }

    pub fn pushBalancePollResults(self: *MockSender, steps: []const MockBalancePollStep) !void {
        for (steps) |step| {
            try self.pushBalanceResponse(step.context_slot, step.value);
        }
    }

    pub fn pushFeeForMessageResponse(self: *MockSender, context_slot: u64, value: ?u64) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":", .{context_slot});
        try writeOptionalU64Json(&out.writer, value);
        try out.writer.writeByte('}');

        try self.pushResultJson(out.written());
    }

    pub fn pushTokenAmountResponse(
        self: *MockSender,
        context_slot: u64,
        value: TokenAmount,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":", .{context_slot});
        try writeTokenAmountJson(&out.writer, self.allocator, value);
        try out.writer.writeByte('}');

        try self.pushResultJson(out.written());
    }

    pub fn pushTokenLargestAccountsResponse(
        self: *MockSender,
        context_slot: u64,
        accounts: []const TokenLargestAccount,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":[", .{context_slot});
        for (accounts, 0..) |account, index| {
            if (index != 0) try out.writer.writeByte(',');
            try out.writer.writeAll("{\"address\":");
            try writeEncodedJsonString(&out.writer, self.allocator, account.address);
            try out.writer.writeAll(",\"amount\":");
            try writeEncodedJsonString(&out.writer, self.allocator, account.amount.amount);
            try out.writer.print(",\"decimals\":{},\"uiAmount\":", .{account.amount.decimals});
            try writeOptionalF64Json(&out.writer, account.amount.ui_amount);
            try out.writer.writeAll(",\"uiAmountString\":");
            try writeEncodedJsonString(&out.writer, self.allocator, account.amount.ui_amount_string);
            try out.writer.writeByte('}');
        }
        try out.writer.writeAll("]}");

        try self.pushResultJson(out.written());
    }

    pub fn pushAccountInfoResponse(
        self: *MockSender,
        context_slot: u64,
        account: ?AccountInfo,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":", .{context_slot});
        if (account) |value| {
            try writeAccountInfoJson(&out.writer, self.allocator, value);
        } else {
            try out.writer.writeAll("null");
        }
        try out.writer.writeByte('}');

        try self.pushResultJson(out.written());
    }

    pub fn pushUiAccountResponse(
        self: *MockSender,
        context_slot: u64,
        account: ?JsonParsedAccountInfo,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":", .{context_slot});
        if (account) |value| {
            try writeJsonParsedAccountInfoJson(&out.writer, self.allocator, value);
        } else {
            try out.writer.writeAll("null");
        }
        try out.writer.writeByte('}');

        try self.pushResultJson(out.written());
    }

    pub fn pushMultipleUiAccountsResponse(
        self: *MockSender,
        context_slot: u64,
        accounts: []const ?JsonParsedAccountInfo,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":[", .{context_slot});
        for (accounts, 0..) |maybe_account, index| {
            if (index != 0) try out.writer.writeByte(',');
            if (maybe_account) |account| {
                try writeJsonParsedAccountInfoJson(&out.writer, self.allocator, account);
            } else {
                try out.writer.writeAll("null");
            }
        }
        try out.writer.writeAll("]}");

        try self.pushResultJson(out.written());
    }

    pub fn pushProgramUiAccountsResponse(
        self: *MockSender,
        context_slot: ?u64,
        accounts: []const JsonParsedProgramAccount,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        if (context_slot) |slot| {
            try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":[", .{slot});
        } else {
            try out.writer.writeByte('[');
        }
        for (accounts, 0..) |account, index| {
            if (index != 0) try out.writer.writeByte(',');
            try writeJsonParsedProgramAccountJson(&out.writer, self.allocator, account);
        }
        if (context_slot != null) {
            try out.writer.writeAll("]}");
        } else {
            try out.writer.writeByte(']');
        }

        try self.pushResultJson(out.written());
    }

    pub fn pushHealthOk(self: *MockSender) !void {
        try self.pushStringResult("ok");
    }

    pub fn pushSignatureResult(self: *MockSender, signature: []const u8) !void {
        try self.pushStringResult(signature);
    }

    pub fn pushSignatureStatusesResult(
        self: *MockSender,
        context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        var out = std.io.Writer.Allocating.init(self.allocator);
        defer out.deinit();

        try out.writer.print("{{\"context\":{{\"slot\":{}}},\"value\":[", .{context_slot});
        for (statuses, 0..) |maybe_status, index| {
            if (index != 0) try out.writer.writeByte(',');

            if (maybe_status) |status| {
                try out.writer.writeByte('{');

                if (status.slot) |slot| {
                    try out.writer.print("\"slot\":{},", .{slot});
                } else {
                    try out.writer.writeAll("\"slot\":null,");
                }

                if (status.confirmations) |confirmations| {
                    try out.writer.print("\"confirmations\":{},", .{confirmations});
                } else {
                    try out.writer.writeAll("\"confirmations\":null,");
                }

                if (status.confirmation_status) |confirmation_status| {
                    const encoded_status = try encodeJsonString(self.allocator, confirmation_status);
                    defer self.allocator.free(encoded_status);
                    try out.writer.print("\"confirmationStatus\":{s},", .{encoded_status});
                } else {
                    try out.writer.writeAll("\"confirmationStatus\":null,");
                }

                if (status.has_error) {
                    try out.writer.writeAll("\"err\":{}");
                } else {
                    try out.writer.writeAll("\"err\":null");
                }
                try out.writer.writeByte('}');
            } else {
                try out.writer.writeAll("null");
            }
        }
        try out.writer.writeAll("]}");

        try self.pushResultJson(out.written());
    }

    pub fn pushSingleSignatureStatusResult(
        self: *MockSender,
        context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        const statuses = [_]?MockSignatureStatus{status};
        try self.pushSignatureStatusesResult(context_slot, statuses[0..]);
    }

    pub fn pushSignatureStatusNotFound(self: *MockSender, context_slot: u64) !void {
        try self.pushSingleSignatureStatusResult(context_slot, null);
    }

    pub fn pushSignatureStatusPollResults(
        self: *MockSender,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        for (steps) |step| {
            try self.pushSingleSignatureStatusResult(step.context_slot, step.status);
        }
    }

    pub fn pushSignatureObservationPollResults(
        self: *MockSender,
        steps: []const MockSignatureObservationPollStep,
    ) !void {
        for (steps) |step| {
            try self.pushSingleSignatureStatusResult(step.context_slot, step.status);
            if (step.status == null) {
                if (step.blockhash_still_valid) |value| {
                    try self.pushBoolResult(value);
                }
            }
        }
    }

    pub fn pushLatestBlockhashResponse(
        self: *MockSender,
        context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
    ) !void {
        const result_json = try std.fmt.allocPrint(
            self.allocator,
            "{{\"context\":{{\"slot\":{}}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":{}}}}}",
            .{ context_slot, blockhash, last_valid_block_height },
        );
        defer self.allocator.free(result_json);
        try self.pushResultJson(result_json);
    }

    pub fn pushSendAndSignatureStatusPollFlow(
        self: *MockSender,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        try self.pushSignatureResult(signature);
        try self.pushSignatureStatusPollResults(steps);
    }

    pub fn pushLatestBlockhashSendAndSignatureStatusesFlow(
        self: *MockSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        statuses_context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        try self.pushLatestBlockhashResponse(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
        );
        try self.pushSignatureResult(signature);
        try self.pushSignatureStatusesResult(statuses_context_slot, statuses);
    }

    pub fn pushLatestBlockhashSendAndSignatureStatusPollFlow(
        self: *MockSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        try self.pushLatestBlockhashResponse(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
        );
        try self.pushSendAndSignatureStatusPollFlow(signature, steps);
    }

    pub fn pushConfirmTransactionSpinnerFlow(
        self: *MockSender,
        observation_steps: []const MockSignatureObservationPollStep,
        confirmation_steps: []const MockSignatureStatusPollStep,
    ) !void {
        try self.pushSignatureObservationPollResults(observation_steps);
        try self.pushSignatureStatusPollResults(confirmation_steps);
    }

    pub fn pushLatestBlockhashSendAndSingleSignatureStatusFlow(
        self: *MockSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        try self.pushLatestBlockhashResponse(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
        );
        try self.pushSignatureResult(signature);
        try self.pushSingleSignatureStatusResult(status_context_slot, status);
    }

    pub fn pushLatestBlockhashSendAndStatusNotFoundFlow(
        self: *MockSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
    ) !void {
        try self.pushLatestBlockhashSendAndSingleSignatureStatusFlow(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
            signature,
            status_context_slot,
            null,
        );
    }

    pub fn pushResultJson(self: *MockSender, result_json: []const u8) !void {
        try self.pushResponse(.{ .result_json = result_json });
    }

    pub fn pushRpcError(self: *MockSender, rpc_error: MockRpcError) !void {
        try self.pushResponse(.{ .rpc_error = rpc_error });
    }

    pub fn pushTransportError(self: *MockSender, transport_error: MockTransportError) !void {
        try self.pushResponse(.{ .transport_error = transport_error });
    }

    pub fn clearRoutes(self: *MockSender) void {
        for (self.routes.items) |route| {
            route.deinit(self.allocator);
        }
        self.routes.clearRetainingCapacity();
    }

    pub fn pushRoute(self: *MockSender, route: MockRoute) !void {
        try self.routes.append(self.allocator, try route.dupe(self.allocator));
    }

    pub fn pushRouteBuilder(self: *MockSender, builder: MockRouteBuilder) !void {
        try self.pushRoute(try builder.build());
    }

    pub fn pushRouteBuilders(self: *MockSender, builders: []const MockRouteBuilder) !void {
        for (builders) |builder| {
            try self.pushRouteBuilder(builder);
        }
    }

    pub fn pushOnceRoute(self: *MockSender, matcher: MockRequestMatcher, response: MockResponse) !void {
        try self.pushRoute(.once(matcher, response));
    }

    pub fn pushPersistentRoute(self: *MockSender, matcher: MockRequestMatcher, response: MockResponse) !void {
        try self.pushRoute(.persistent(matcher, response));
    }

    pub fn pushResultRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
        remaining_uses: ?usize,
    ) !void {
        try self.pushRoute(.{
            .matcher = matcher,
            .response = .{ .result_json = result_json },
            .remaining_uses = remaining_uses,
        });
    }

    pub fn pushOnceResultRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
    ) !void {
        try self.pushOnceRoute(matcher, .{ .result_json = result_json });
    }

    pub fn pushPersistentResultRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
    ) !void {
        try self.pushPersistentRoute(matcher, .{ .result_json = result_json });
    }

    pub fn pushRpcErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
        remaining_uses: ?usize,
    ) !void {
        try self.pushRoute(.{
            .matcher = matcher,
            .response = .{ .rpc_error = rpc_error },
            .remaining_uses = remaining_uses,
        });
    }

    pub fn pushOnceRpcErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
    ) !void {
        try self.pushOnceRoute(matcher, .{ .rpc_error = rpc_error });
    }

    pub fn pushPersistentRpcErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
    ) !void {
        try self.pushPersistentRoute(matcher, .{ .rpc_error = rpc_error });
    }

    pub fn pushTransportErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
        remaining_uses: ?usize,
    ) !void {
        try self.pushRoute(.{
            .matcher = matcher,
            .response = .{ .transport_error = transport_error },
            .remaining_uses = remaining_uses,
        });
    }

    pub fn pushOnceTransportErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
    ) !void {
        try self.pushOnceRoute(matcher, .{ .transport_error = transport_error });
    }

    pub fn pushPersistentTransportErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
    ) !void {
        try self.pushPersistentRoute(matcher, .{ .transport_error = transport_error });
    }

    pub fn capturedRequests(self: *const MockSender) []const MockRequest {
        return self.requests.items;
    }

    pub fn clearCapturedRequests(self: *MockSender) void {
        for (self.requests.items) |request| {
            request.deinit(self.allocator);
        }
        self.requests.clearRetainingCapacity();
        self.last_script_miss_request_index = null;
    }

    pub fn responseCount(self: *const MockSender) usize {
        return self.responses.items.len;
    }

    pub fn routeCount(self: *const MockSender) usize {
        return self.routes.items.len;
    }

    pub fn matchedRouteCount(self: *const MockSender) usize {
        return self.matched_route_count;
    }

    pub fn routeMatchCountForLabel(self: *const MockSender, label: []const u8) usize {
        for (self.route_match_counts.items) |entry| {
            if (std.mem.eql(u8, entry.label, label)) return entry.count;
        }
        return 0;
    }

    pub fn persistentRouteCount(self: *const MockSender) usize {
        var count: usize = 0;
        for (self.routes.items) |route| {
            if (route.isPersistent()) count += 1;
        }
        return count;
    }

    pub fn pendingScriptedDispatchCount(self: *const MockSender) usize {
        var count = self.responses.items.len;
        for (self.routes.items) |route| {
            count += route.pendingDispatchCount();
        }
        return count;
    }

    pub fn scriptMissCount(self: *const MockSender) usize {
        return self.script_miss_count;
    }

    pub fn lastScriptMissRequest(self: *const MockSender) ?MockRequestView {
        const index = self.last_script_miss_request_index orelse return null;
        const request = self.requests.items[index];
        return .{
            .id = request.id,
            .method = request.method,
            .params_json = request.params_json,
            .request_body = request.request_body,
        };
    }

    pub fn requestCount(self: *const MockSender) usize {
        return self.requests.items.len;
    }

    pub fn scriptSummaryAlloc(self: *const MockSender, allocator: Allocator) ![]u8 {
        var out = std.io.Writer.Allocating.init(allocator);
        errdefer out.deinit();

        try out.writer.print(
            "responses_remaining={}\nroutes_remaining={}\npersistent_routes_remaining={}\npending_scripted_dispatches={}\nmatched_route_count={}\nscript_miss_count={}\n",
            .{
                self.responseCount(),
                self.routeCount(),
                self.persistentRouteCount(),
                self.pendingScriptedDispatchCount(),
                self.matchedRouteCount(),
                self.scriptMissCount(),
            },
        );

        if (self.lastScriptMissRequest()) |request| {
            try out.writer.print(
                "last_script_miss: id={} method={s}\n",
                .{ request.id, request.method },
            );
        }

        if (self.route_match_counts.items.len > 0) {
            try out.writer.writeAll("route_match_counts:\n");
            for (self.route_match_counts.items) |entry| {
                try out.writer.print("  {s}: {}\n", .{ entry.label, entry.count });
            }
        }

        if (self.routes.items.len > 0) {
            try out.writer.writeAll("remaining_routes:\n");
            for (self.routes.items, 0..) |route, index| {
                const label = route.label orelse "<unlabeled>";
                const method = route.matcher.method orelse "<any>";
                if (route.remaining_uses) |remaining| {
                    try out.writer.print(
                        "  [{}] label={s} method={s} pending={} matched={}\n",
                        .{ index, label, method, remaining, route.match_count },
                    );
                } else {
                    try out.writer.print(
                        "  [{}] label={s} method={s} pending=persistent matched={}\n",
                        .{ index, label, method, route.match_count },
                    );
                }
            }
        }

        const summary = try allocator.dupe(u8, out.written());
        out.deinit();
        return summary;
    }

    fn captureRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) !void {
        try self.requests.append(self.allocator, .{
            .id = id,
            .method = try self.allocator.dupe(u8, method),
            .params_json = try self.allocator.dupe(u8, params_json),
            .request_body = try self.allocator.dupe(u8, request_body),
        });
    }

    fn noteScriptMiss(self: *MockSender) void {
        self.script_miss_count += 1;
        self.last_script_miss_request_index = self.requests.items.len - 1;
    }

    fn incrementRouteLabelMatchCount(self: *MockSender, label: []const u8) !void {
        for (self.route_match_counts.items) |*entry| {
            if (std.mem.eql(u8, entry.label, label)) {
                entry.count += 1;
                return;
            }
        }

        try self.route_match_counts.append(self.allocator, .{
            .label = try self.allocator.dupe(u8, label),
            .count = 1,
        });
    }

    fn dequeueQueuedResponse(self: *MockSender, request_id: u64) ![]u8 {
        if (self.responses.items.len == 0) return error.MockResponseExhausted;

        const response = self.responses.orderedRemove(0);
        return switch (response) {
            .json => |value| @constCast(value),
            .result_json => |value| {
                defer self.allocator.free(value);
                return try formatResultEnvelope(self.allocator, request_id, value);
            },
            .rpc_error => |value| {
                defer value.deinit(self.allocator);
                return try formatRpcErrorEnvelope(self.allocator, request_id, value);
            },
            .transport_error => |value| switch (value) {
                .timeout => error.Timeout,
                .connection_reset => error.ConnectionResetByPeer,
                .http_error => error.HttpError,
            },
        };
    }

    fn maybeUseRoute(
        self: *MockSender,
        request: MockRequestView,
    ) !?[]u8 {
        for (self.routes.items, 0..) |*route, index| {
            if (route.remaining_uses) |remaining| {
                if (remaining == 0) continue;
            }
            if (!route.matcher.matches(request)) continue;

            const response = try cloneResponse(self.allocator, route.response);
            defer freeResponse(self.allocator, response);
            self.matched_route_count += 1;
            route.match_count += 1;
            if (route.label) |label| {
                try self.incrementRouteLabelMatchCount(label);
            }

            const should_remove = if (route.remaining_uses) |remaining| remaining <= 1 else false;
            if (route.remaining_uses) |remaining| {
                if (remaining > 1) {
                    route.remaining_uses = remaining - 1;
                }
            }

            if (should_remove) {
                var owned_route = self.routes.orderedRemove(index);
                owned_route.deinit(self.allocator);
            }

            const encoded: []u8 = switch (response) {
                .json => |value| try self.allocator.dupe(u8, value),
                .result_json => |value| try formatResultEnvelope(self.allocator, request.id, value),
                .rpc_error => |value| try formatRpcErrorEnvelope(self.allocator, request.id, value),
                .transport_error => |value| switch (value) {
                    .timeout => return error.Timeout,
                    .connection_reset => return error.ConnectionResetByPeer,
                    .http_error => return error.HttpError,
                },
            };

            return encoded;
        }

        return null;
    }

    pub fn sendRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        return try self.dispatchRequest(id, method, params_json, request_body);
    }

    fn handleWithCallback(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        const handler = self.handler orelse return error.MockResponseExhausted;
        const response = try handler.callback(handler.context, self.allocator, .{
            .id = id,
            .method = method,
            .params_json = params_json,
            .request_body = request_body,
        });

        return switch (response) {
            .json => |value| value,
            .result_json => |value| {
                defer self.allocator.free(value);
                return try formatResultEnvelope(self.allocator, id, value);
            },
            .rpc_error => |value| {
                defer value.deinit(self.allocator);
                return try formatRpcErrorEnvelope(self.allocator, id, value);
            },
            .transport_error => |value| switch (value) {
                .timeout => error.Timeout,
                .connection_reset => error.ConnectionResetByPeer,
                .http_error => error.HttpError,
            },
        };
    }

    pub fn dispatchRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        try self.captureRequest(id, method, params_json, request_body);

        if (self.responses.items.len > 0) {
            return try self.dequeueQueuedResponse(id);
        }

        if (try self.maybeUseRoute(.{
            .id = id,
            .method = method,
            .params_json = params_json,
            .request_body = request_body,
        })) |response| {
            return response;
        }

        self.noteScriptMiss();
        return try self.handleWithCallback(id, method, params_json, request_body);
    }
};
