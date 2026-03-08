const std = @import("std");
const rpc_types = @import("../rpc_types.zig");
const mock_methods = @import("./mock.zig");
const sender_methods = @import("./sender.zig");

const Commitment = rpc_types.Commitment;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const TransportStats = rpc_types.TransportStats;
const MockResponse = mock_methods.MockResponse;
const MockRequestHandler = mock_methods.MockRequestHandler;
const MockSender = mock_methods.MockSender;
const RequestSender = sender_methods.RequestSender;

pub fn makeMockRequestSender(sender: *MockSender) RequestSender {
    return RequestSender.fromMockSender(sender);
}

pub fn initClient(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    return ClientType{
        .allocator = allocator,
        .endpoint = try allocator.dupe(u8, endpoint),
        .http_client = .{ .allocator = allocator },
        .request_sender = null,
        .mock_sender = null,
        .request_id = 1,
        .default_commitment = default_commitment,
        .request_timeout_ms = request_timeout_ms,
        .confirm_transaction_initial_timeout_ms = confirm_transaction_initial_timeout_ms,
        .last_error = null,
        .transport_stats = .{},
    };
}

pub fn initMockClient(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    responses: []const MockResponse,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    var client = try initClient(
        ClientType,
        allocator,
        "mock://local",
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    errdefer client.deinit();

    const sender_value = try MockSender.initSequence(allocator, responses);
    errdefer {
        var owned = sender_value;
        owned.deinit();
    }
    const sender_ptr = try allocator.create(MockSender);
    errdefer allocator.destroy(sender_ptr);
    sender_ptr.* = sender_value;
    client.mock_sender = sender_ptr;
    client.request_sender = makeMockRequestSender(sender_ptr);
    return client;
}

pub fn initMockClientWithHandler(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    handler: MockRequestHandler,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    var client = try initClient(
        ClientType,
        allocator,
        "mock://local",
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    errdefer client.deinit();

    const sender_ptr = try allocator.create(MockSender);
    errdefer allocator.destroy(sender_ptr);
    sender_ptr.* = MockSender.initWithHandler(allocator, handler);
    client.mock_sender = sender_ptr;
    client.request_sender = makeMockRequestSender(sender_ptr);
    return client;
}

pub fn initMockClientWithSender(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    sender: MockSender,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    return initMockClientWithSenderAndOptions(
        ClientType,
        allocator,
        sender,
        "mock://local",
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
}

pub fn initMockClientWithSenderAndOptions(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    sender: MockSender,
    endpoint: []const u8,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    var client = try initClient(
        ClientType,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    errdefer client.deinit();

    const sender_ptr = try allocator.create(MockSender);
    errdefer allocator.destroy(sender_ptr);
    sender_ptr.* = sender;
    client.mock_sender = sender_ptr;
    client.request_sender = makeMockRequestSender(sender_ptr);
    return client;
}

pub fn initClientWithRequestSender(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    sender: RequestSender,
    default_commitment: ?Commitment,
    request_timeout_ms: ?u64,
    confirm_transaction_initial_timeout_ms: ?u64,
) !ClientType {
    var client = try initClient(
        ClientType,
        allocator,
        endpoint,
        default_commitment,
        request_timeout_ms,
        confirm_transaction_initial_timeout_ms,
    );
    errdefer client.deinit();

    client.request_sender = sender;
    return client;
}

pub fn deinit(self: anytype) void {
    clearLastError(self);
    if (self.mock_sender) |sender| {
        sender.deinit();
        self.allocator.destroy(sender);
        self.mock_sender = null;
        self.request_sender = null;
    } else if (self.request_sender) |request_sender| {
        request_sender.deinit(self.allocator);
        self.request_sender = null;
    }
    self.http_client.deinit();
    self.allocator.free(self.endpoint);
}

pub fn url(self: anytype) []const u8 {
    return self.endpoint;
}

pub fn getLastError(self: anytype) ?RpcErrorDetail {
    return self.last_error;
}

pub fn getTransportStats(self: anytype) TransportStats {
    return self.transport_stats;
}

pub fn clearLastError(self: anytype) void {
    if (self.last_error) |last| {
        self.allocator.free(last.message);
        self.last_error = null;
    }
}
