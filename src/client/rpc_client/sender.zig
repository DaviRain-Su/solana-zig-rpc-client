const std = @import("std");
const rpc_types = @import("../rpc_types.zig");
const mock_methods = @import("./mock.zig");

const Allocator = std.mem.Allocator;
const AccountInfo = rpc_types.AccountInfo;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const MockRequest = mock_methods.MockRequest;
const MockBalancePollStep = mock_methods.MockBalancePollStep;
const MockRequestHandler = mock_methods.MockRequestHandler;
const MockRequestView = mock_methods.MockRequestView;
const MockResponse = mock_methods.MockResponse;
const MockRequestMatcher = mock_methods.MockRequestMatcher;
const MockRoute = mock_methods.MockRoute;
const MockRouteBuilder = mock_methods.MockRouteBuilder;
const MockRpcError = mock_methods.MockRpcError;
const MockSender = mock_methods.MockSender;
const MockSignatureObservationPollStep = mock_methods.MockSignatureObservationPollStep;
const MockSignatureStatus = mock_methods.MockSignatureStatus;
const MockSignatureStatusPollStep = mock_methods.MockSignatureStatusPollStep;
const MockTransportError = mock_methods.MockTransportError;
const TokenAmount = rpc_types.TokenAmount;
const TokenLargestAccount = rpc_types.TokenLargestAccount;

pub const RequestSenderRequest = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,
};

pub const RequestSender = struct {
    pub const Kind = enum {
        callback,
        borrowed_mock,
        owned_mock,
    };
    pub const Callback = *const fn (context: ?*anyopaque, allocator: Allocator, request: RequestSenderRequest) anyerror![]u8;
    pub const DeinitCallback = *const fn (context: ?*anyopaque, allocator: Allocator) void;

    context: ?*anyopaque = null,
    callback: Callback,
    deinit_callback: ?DeinitCallback = null,

    pub fn init(
        context: ?*anyopaque,
        callback: Callback,
    ) RequestSender {
        return .{
            .context = context,
            .callback = callback,
        };
    }

    pub fn initWithDeinit(
        context: ?*anyopaque,
        callback: Callback,
        deinit_callback: DeinitCallback,
    ) RequestSender {
        return .{
            .context = context,
            .callback = callback,
            .deinit_callback = deinit_callback,
        };
    }

    pub fn initCallback(
        context: ?*anyopaque,
        callback: Callback,
    ) RequestSender {
        return RequestSender.init(context, callback);
    }

    pub fn initCallbackWithDeinit(
        context: ?*anyopaque,
        callback: Callback,
        deinit_callback: DeinitCallback,
    ) RequestSender {
        return RequestSender.initWithDeinit(context, callback, deinit_callback);
    }

    pub fn initCallbackDeinit(
        context: ?*anyopaque,
        callback: Callback,
        deinit_callback: DeinitCallback,
    ) RequestSender {
        return RequestSender.initCallbackWithDeinit(context, callback, deinit_callback);
    }

    pub fn initMock(allocator: Allocator, responses: []const MockResponse) !RequestSender {
        return try RequestSender.fromOwnedMockSender(
            allocator,
            try MockSender.initSequence(allocator, responses),
        );
    }

    pub fn initMockResponses(allocator: Allocator, responses: []const MockResponse) !RequestSender {
        return try RequestSender.initMock(allocator, responses);
    }

    pub fn initMockWithHandler(allocator: Allocator, handler: MockRequestHandler) !RequestSender {
        return try RequestSender.fromOwnedMockSender(
            allocator,
            MockSender.initWithHandler(allocator, handler),
        );
    }

    pub fn initMockHandler(allocator: Allocator, handler: MockRequestHandler) !RequestSender {
        return try RequestSender.initMockWithHandler(allocator, handler);
    }

    pub fn initMockWithSender(allocator: Allocator, sender: MockSender) !RequestSender {
        return try RequestSender.fromOwnedMockSender(allocator, sender);
    }

    pub fn initBorrowedMockSender(sender: *MockSender) RequestSender {
        return RequestSender.fromMockSender(sender);
    }

    pub fn initBorrowedMock(sender: *MockSender) RequestSender {
        return RequestSender.initBorrowedMockSender(sender);
    }

    pub fn initOwnedMockSender(allocator: Allocator, sender: MockSender) !RequestSender {
        return try RequestSender.fromOwnedMockSender(allocator, sender);
    }

    pub fn initOwnedMock(allocator: Allocator, sender: MockSender) !RequestSender {
        return try RequestSender.initOwnedMockSender(allocator, sender);
    }

    pub fn initMockSender(allocator: Allocator, sender: MockSender) !RequestSender {
        return try RequestSender.initOwnedMockSender(allocator, sender);
    }

    pub fn fromMockSender(sender: *MockSender) RequestSender {
        return .{
            .context = sender,
            .callback = mockSenderRequestCallback,
        };
    }

    pub fn fromOwnedMockSender(allocator: Allocator, sender: MockSender) !RequestSender {
        var owned_sender = sender;
        errdefer owned_sender.deinit();

        const sender_ptr = try allocator.create(MockSender);
        sender_ptr.* = owned_sender;
        return .{
            .context = sender_ptr,
            .callback = mockSenderRequestCallback,
            .deinit_callback = ownedMockSenderDeinit,
        };
    }

    pub fn replace(self: *RequestSender, allocator: Allocator, sender: RequestSender) void {
        self.deinit(allocator);
        self.* = sender;
    }

    pub fn replaceWithBorrowedMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: *MockSender,
    ) void {
        self.replace(allocator, RequestSender.fromMockSender(sender));
    }

    pub fn replaceBorrowedMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: *MockSender,
    ) void {
        self.replaceWithBorrowedMockSender(allocator, sender);
    }

    pub fn replaceBorrowedMock(
        self: *RequestSender,
        allocator: Allocator,
        sender: *MockSender,
    ) void {
        self.replaceBorrowedMockSender(allocator, sender);
    }

    pub fn replaceWithOwnedMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: MockSender,
    ) !void {
        const replacement = try RequestSender.fromOwnedMockSender(allocator, sender);
        self.replace(allocator, replacement);
    }

    pub fn replaceOwnedMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: MockSender,
    ) !void {
        try self.replaceWithOwnedMockSender(allocator, sender);
    }

    pub fn replaceOwnedMock(
        self: *RequestSender,
        allocator: Allocator,
        sender: MockSender,
    ) !void {
        try self.replaceOwnedMockSender(allocator, sender);
    }

    pub fn replaceWithMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: MockSender,
    ) !void {
        try self.replaceWithOwnedMockSender(allocator, sender);
    }

    pub fn replaceMockSender(
        self: *RequestSender,
        allocator: Allocator,
        sender: MockSender,
    ) !void {
        try self.replaceWithMockSender(allocator, sender);
    }

    pub fn replaceWithMock(self: *RequestSender, allocator: Allocator, responses: []const MockResponse) !void {
        try self.replaceWithOwnedMockSender(
            allocator,
            try MockSender.initSequence(allocator, responses),
        );
    }

    pub fn replaceMock(self: *RequestSender, allocator: Allocator, responses: []const MockResponse) !void {
        try self.replaceWithMock(allocator, responses);
    }

    pub fn replaceMockResponses(
        self: *RequestSender,
        allocator: Allocator,
        responses: []const MockResponse,
    ) !void {
        try self.replaceMock(allocator, responses);
    }

    pub fn replaceWithMockHandler(
        self: *RequestSender,
        allocator: Allocator,
        handler: MockRequestHandler,
    ) !void {
        try self.replaceWithOwnedMockSender(
            allocator,
            MockSender.initWithHandler(allocator, handler),
        );
    }

    pub fn replaceMockHandler(
        self: *RequestSender,
        allocator: Allocator,
        handler: MockRequestHandler,
    ) !void {
        try self.replaceWithMockHandler(allocator, handler);
    }

    pub fn replaceWithCallback(
        self: *RequestSender,
        allocator: Allocator,
        context: ?*anyopaque,
        callback: Callback,
    ) void {
        self.replace(allocator, RequestSender.init(context, callback));
    }

    pub fn replaceCallback(
        self: *RequestSender,
        allocator: Allocator,
        context: ?*anyopaque,
        callback: Callback,
    ) void {
        self.replaceWithCallback(allocator, context, callback);
    }

    pub fn replaceWithCallbackAndDeinit(
        self: *RequestSender,
        allocator: Allocator,
        context: ?*anyopaque,
        callback: Callback,
        deinit_callback: DeinitCallback,
    ) void {
        self.replace(allocator, RequestSender.initWithDeinit(context, callback, deinit_callback));
    }

    pub fn replaceCallbackAndDeinit(
        self: *RequestSender,
        allocator: Allocator,
        context: ?*anyopaque,
        callback: Callback,
        deinit_callback: DeinitCallback,
    ) void {
        self.replaceWithCallbackAndDeinit(allocator, context, callback, deinit_callback);
    }

    pub fn kind(self: RequestSender) Kind {
        if (self.callback != &mockSenderRequestCallback) return .callback;
        if (self.deinit_callback) |deinit_callback| {
            if (deinit_callback == &ownedMockSenderDeinit) return .owned_mock;
        }
        return .borrowed_mock;
    }

    pub fn isMockSender(self: RequestSender) bool {
        return self.kind() != .callback;
    }

    pub fn isBorrowedMockSender(self: RequestSender) bool {
        return self.kind() == .borrowed_mock;
    }

    pub fn isOwnedMockSender(self: RequestSender) bool {
        return self.kind() == .owned_mock;
    }

    pub fn isCallbackSender(self: RequestSender) bool {
        return self.kind() == .callback;
    }

    pub fn mockSender(self: *RequestSender) !*MockSender {
        if (!self.isMockSender() or self.context == null) return error.NotMockSender;
        return @ptrCast(@alignCast(self.context.?));
    }

    pub fn mockSenderConst(self: *const RequestSender) !*const MockSender {
        if (!self.isMockSender() or self.context == null) return error.NotMockSender;
        return @ptrCast(@alignCast(self.context.?));
    }

    pub fn hasMockHandler(self: *const RequestSender) bool {
        return if (self.mockSenderConst() catch null) |sender| sender.hasHandler() else false;
    }

    pub fn mockResponseCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.responseCount() else 0;
    }

    pub fn hasMockResponses(self: *const RequestSender) bool {
        return self.mockResponseCount() > 0;
    }

    pub fn mockRequestCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.requestCount() else 0;
    }

    pub fn hasCapturedMockRequests(self: *const RequestSender) bool {
        return self.capturedMockRequests().len > 0;
    }

    pub fn mockRouteCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.routeCount() else 0;
    }

    pub fn hasMockRoutes(self: *const RequestSender) bool {
        return self.mockRouteCount() > 0;
    }

    pub fn mockMatchedRouteCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.matchedRouteCount() else 0;
    }

    pub fn hasMatchedMockRoutes(self: *const RequestSender) bool {
        return self.mockMatchedRouteCount() > 0;
    }

    pub fn mockRouteMatchCount(self: *const RequestSender, label: []const u8) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.routeMatchCountForLabel(label) else 0;
    }

    pub fn hasMockRouteMatch(self: *const RequestSender, label: []const u8) bool {
        return self.mockRouteMatchCount(label) > 0;
    }

    pub fn mockPersistentRouteCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.persistentRouteCount() else 0;
    }

    pub fn hasPersistentMockRoutes(self: *const RequestSender) bool {
        return self.mockPersistentRouteCount() > 0;
    }

    pub fn mockPendingScriptedDispatchCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.pendingScriptedDispatchCount() else 0;
    }

    pub fn hasPendingMockScriptedDispatches(self: *const RequestSender) bool {
        return self.mockPendingScriptedDispatchCount() > 0;
    }

    pub fn isMockScriptExhausted(self: *const RequestSender) bool {
        return self.mockPendingScriptedDispatchCount() == 0;
    }

    pub fn mockScriptMissCount(self: *const RequestSender) usize {
        return if (self.mockSenderConst() catch null) |sender| sender.scriptMissCount() else 0;
    }

    pub fn hasMockScriptMisses(self: *const RequestSender) bool {
        return self.mockScriptMissCount() > 0;
    }

    pub fn isMockScriptSatisfied(self: *const RequestSender) bool {
        return self.isMockScriptExhausted() and !self.hasMockScriptMisses();
    }

    pub fn capturedMockRequests(self: *const RequestSender) []const MockRequest {
        return if (self.mockSenderConst() catch null) |sender| sender.capturedRequests() else &.{};
    }

    pub fn lastCapturedMockRequest(self: *const RequestSender) ?MockRequestView {
        return if (self.mockSenderConst() catch null) |sender| sender.lastCapturedRequest() else null;
    }

    pub fn lastCapturedMockRequestId(self: *const RequestSender) ?u64 {
        return if (self.lastCapturedMockRequest()) |request| request.id else null;
    }

    pub fn lastCapturedMockRequestMethod(self: *const RequestSender) ?[]const u8 {
        return if (self.lastCapturedMockRequest()) |request| request.method else null;
    }

    pub fn lastCapturedMockRequestParamsJson(self: *const RequestSender) ?[]const u8 {
        return if (self.lastCapturedMockRequest()) |request| request.params_json else null;
    }

    pub fn lastCapturedMockRequestBody(self: *const RequestSender) ?[]const u8 {
        return if (self.lastCapturedMockRequest()) |request| request.request_body else null;
    }

    pub fn lastMockScriptMissRequest(self: *const RequestSender) ?MockRequestView {
        return if (self.mockSenderConst() catch null) |sender| sender.lastScriptMissRequest() else null;
    }

    pub fn lastMockScriptMissMethod(self: *const RequestSender) ?[]const u8 {
        return if (self.lastMockScriptMissRequest()) |request| request.method else null;
    }

    pub fn mockScriptSummaryAlloc(self: *const RequestSender, allocator: Allocator) ![]u8 {
        return if (self.mockSenderConst() catch null) |sender| sender.scriptSummaryAlloc(allocator) else allocator.dupe(u8, "not a mock sender\n");
    }

    pub fn clearCapturedMockRequests(self: *RequestSender) !void {
        const sender = try self.mockSender();
        sender.clearCapturedRequests();
    }

    pub fn clearMockResponses(self: *RequestSender) !void {
        const sender = try self.mockSender();
        sender.clearResponses();
    }

    pub fn clearMockRoutes(self: *RequestSender) !void {
        const sender = try self.mockSender();
        sender.clearRoutes();
    }

    pub fn setMockHandler(self: *RequestSender, handler: MockRequestHandler) !void {
        const sender = try self.mockSender();
        sender.setHandler(handler);
    }

    pub fn clearMockHandler(self: *RequestSender) !void {
        const sender = try self.mockSender();
        sender.clearHandler();
    }

    pub fn pushMockResponse(self: *RequestSender, response: MockResponse) !void {
        const sender = try self.mockSender();
        try sender.pushResponse(response);
    }

    pub fn pushMockJsonResponse(self: *RequestSender, response_body: []const u8) !void {
        const sender = try self.mockSender();
        try sender.pushJsonResponse(response_body);
    }

    pub fn pushMockResultJson(self: *RequestSender, result_json: []const u8) !void {
        const sender = try self.mockSender();
        try sender.pushResultJson(result_json);
    }

    pub fn pushMockStringResult(self: *RequestSender, value: []const u8) !void {
        const sender = try self.mockSender();
        try sender.pushStringResult(value);
    }

    pub fn pushMockSlotResult(self: *RequestSender, slot: u64) !void {
        const sender = try self.mockSender();
        try sender.pushSlotResult(slot);
    }

    pub fn pushMockBoolResult(self: *RequestSender, value: bool) !void {
        const sender = try self.mockSender();
        try sender.pushBoolResult(value);
    }

    pub fn pushMockNullResult(self: *RequestSender) !void {
        const sender = try self.mockSender();
        try sender.pushNullResult();
    }

    pub fn pushMockBalanceResponse(
        self: *RequestSender,
        context_slot: u64,
        value: u64,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushBalanceResponse(context_slot, value);
    }

    pub fn pushMockBalancePollResults(
        self: *RequestSender,
        steps: []const MockBalancePollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushBalancePollResults(steps);
    }

    pub fn pushMockFeeForMessageResponse(
        self: *RequestSender,
        context_slot: u64,
        value: ?u64,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushFeeForMessageResponse(context_slot, value);
    }

    pub fn pushMockTokenAmountResponse(
        self: *RequestSender,
        context_slot: u64,
        value: TokenAmount,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushTokenAmountResponse(context_slot, value);
    }

    pub fn pushMockTokenLargestAccountsResponse(
        self: *RequestSender,
        context_slot: u64,
        accounts: []const TokenLargestAccount,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushTokenLargestAccountsResponse(context_slot, accounts);
    }

    pub fn pushMockAccountInfoResponse(
        self: *RequestSender,
        context_slot: u64,
        account: ?AccountInfo,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushAccountInfoResponse(context_slot, account);
    }

    pub fn pushMockUiAccountResponse(
        self: *RequestSender,
        context_slot: u64,
        account: ?JsonParsedAccountInfo,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushUiAccountResponse(context_slot, account);
    }

    pub fn pushMockMultipleUiAccountsResponse(
        self: *RequestSender,
        context_slot: u64,
        accounts: []const ?JsonParsedAccountInfo,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushMultipleUiAccountsResponse(context_slot, accounts);
    }

    pub fn pushMockProgramUiAccountsResponse(
        self: *RequestSender,
        context_slot: ?u64,
        accounts: []const JsonParsedProgramAccount,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushProgramUiAccountsResponse(context_slot, accounts);
    }

    pub fn pushMockHealthOk(self: *RequestSender) !void {
        const sender = try self.mockSender();
        try sender.pushHealthOk();
    }

    pub fn pushMockSignatureResult(self: *RequestSender, signature: []const u8) !void {
        const sender = try self.mockSender();
        try sender.pushSignatureResult(signature);
    }

    pub fn pushMockSignatureStatusesResult(
        self: *RequestSender,
        context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushSignatureStatusesResult(context_slot, statuses);
    }

    pub fn pushMockSingleSignatureStatusResult(
        self: *RequestSender,
        context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushSingleSignatureStatusResult(context_slot, status);
    }

    pub fn pushMockSignatureStatusNotFound(self: *RequestSender, context_slot: u64) !void {
        const sender = try self.mockSender();
        try sender.pushSignatureStatusNotFound(context_slot);
    }

    pub fn pushMockSignatureStatusPollResults(
        self: *RequestSender,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushSignatureStatusPollResults(steps);
    }

    pub fn pushMockSignatureObservationPollResults(
        self: *RequestSender,
        steps: []const MockSignatureObservationPollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushSignatureObservationPollResults(steps);
    }

    pub fn pushMockLatestBlockhashResponse(
        self: *RequestSender,
        context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushLatestBlockhashResponse(context_slot, blockhash, last_valid_block_height);
    }

    pub fn pushMockLatestBlockhashSendAndSignatureStatusesFlow(
        self: *RequestSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        statuses_context_slot: u64,
        statuses: []const ?MockSignatureStatus,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushLatestBlockhashSendAndSignatureStatusesFlow(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
            signature,
            statuses_context_slot,
            statuses,
        );
    }

    pub fn pushMockSendAndSignatureStatusPollFlow(
        self: *RequestSender,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushSendAndSignatureStatusPollFlow(signature, steps);
    }

    pub fn pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        self: *RequestSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        steps: []const MockSignatureStatusPollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushLatestBlockhashSendAndSignatureStatusPollFlow(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
            signature,
            steps,
        );
    }

    pub fn pushMockConfirmTransactionSpinnerFlow(
        self: *RequestSender,
        observation_steps: []const MockSignatureObservationPollStep,
        confirmation_steps: []const MockSignatureStatusPollStep,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushConfirmTransactionSpinnerFlow(observation_steps, confirmation_steps);
    }

    pub fn pushMockLatestBlockhashSendAndSingleSignatureStatusFlow(
        self: *RequestSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
        status: ?MockSignatureStatus,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushLatestBlockhashSendAndSingleSignatureStatusFlow(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
            signature,
            status_context_slot,
            status,
        );
    }

    pub fn pushMockLatestBlockhashSendAndStatusNotFoundFlow(
        self: *RequestSender,
        latest_blockhash_context_slot: u64,
        blockhash: []const u8,
        last_valid_block_height: u64,
        signature: []const u8,
        status_context_slot: u64,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushLatestBlockhashSendAndStatusNotFoundFlow(
            latest_blockhash_context_slot,
            blockhash,
            last_valid_block_height,
            signature,
            status_context_slot,
        );
    }

    pub fn pushMockRpcError(self: *RequestSender, rpc_error: MockRpcError) !void {
        const sender = try self.mockSender();
        try sender.pushRpcError(rpc_error);
    }

    pub fn pushMockTransportError(self: *RequestSender, transport_error: MockTransportError) !void {
        const sender = try self.mockSender();
        try sender.pushTransportError(transport_error);
    }

    pub fn pushMockRoute(self: *RequestSender, route: MockRoute) !void {
        const sender = try self.mockSender();
        try sender.pushRoute(route);
    }

    pub fn pushMockRouteBuilder(self: *RequestSender, builder: MockRouteBuilder) !void {
        const sender = try self.mockSender();
        try sender.pushRouteBuilder(builder);
    }

    pub fn pushMockRouteBuilders(self: *RequestSender, builders: []const MockRouteBuilder) !void {
        const sender = try self.mockSender();
        try sender.pushRouteBuilders(builders);
    }

    pub fn pushMockOnceRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        response: MockResponse,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushOnceRoute(matcher, response);
    }

    pub fn pushMockPersistentRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        response: MockResponse,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushPersistentRoute(matcher, response);
    }

    pub fn pushMockResultRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
        remaining_uses: ?usize,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushResultRoute(matcher, result_json, remaining_uses);
    }

    pub fn pushMockOnceResultRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushOnceResultRoute(matcher, result_json);
    }

    pub fn pushMockPersistentResultRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushPersistentResultRoute(matcher, result_json);
    }

    pub fn pushMockRpcErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
        remaining_uses: ?usize,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushRpcErrorRoute(matcher, rpc_error, remaining_uses);
    }

    pub fn pushMockOnceRpcErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushOnceRpcErrorRoute(matcher, rpc_error);
    }

    pub fn pushMockPersistentRpcErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushPersistentRpcErrorRoute(matcher, rpc_error);
    }

    pub fn pushMockTransportErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
        remaining_uses: ?usize,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushTransportErrorRoute(matcher, transport_error, remaining_uses);
    }

    pub fn pushMockOnceTransportErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushOnceTransportErrorRoute(matcher, transport_error);
    }

    pub fn pushMockPersistentTransportErrorRoute(
        self: *RequestSender,
        matcher: MockRequestMatcher,
        transport_error: MockTransportError,
    ) !void {
        const sender = try self.mockSender();
        try sender.pushPersistentTransportErrorRoute(matcher, transport_error);
    }

    pub fn deinit(self: RequestSender, allocator: Allocator) void {
        if (self.deinit_callback) |callback| callback(self.context, allocator);
    }
};

fn mockSenderRequestCallback(
    context_ptr: ?*anyopaque,
    allocator: Allocator,
    request: RequestSenderRequest,
) ![]u8 {
    _ = allocator;
    const sender: *MockSender = @ptrCast(@alignCast(context_ptr.?));
    return sender.dispatchRequest(request.id, request.method, request.params_json, request.request_body);
}

fn ownedMockSenderDeinit(context_ptr: ?*anyopaque, allocator: Allocator) void {
    const sender: *MockSender = @ptrCast(@alignCast(context_ptr.?));
    sender.deinit();
    allocator.destroy(sender);
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

pub fn encodeJsonRpcResultEnvelope(
    allocator: Allocator,
    request_id: u64,
    result_json: []const u8,
) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

pub fn encodeJsonRpcErrorEnvelope(
    allocator: Allocator,
    request_id: u64,
    rpc_error: mock_methods.MockRpcError,
) ![]u8 {
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
