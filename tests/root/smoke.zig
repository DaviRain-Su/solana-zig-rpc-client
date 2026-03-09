const std = @import("std");
const client = @import("solana_client_zig");
const mock_sender_assertions = @import("mock_sender_assertions");
const request_sender_test_support = @import("request_sender_test_support");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

const MockHandlerContext = request_sender_test_support.MockHandlerContext;
const RequestSenderContext = request_sender_test_support.RequestSenderContext;
const dynamicMockHandler = request_sender_test_support.dynamicMockHandler;
const timeoutMockHandler = request_sender_test_support.timeoutMockHandler;
const structuredMockHandler = request_sender_test_support.structuredMockHandler;
const customRequestSender = request_sender_test_support.customRequestSender;
const customRequestSenderDeinit = request_sender_test_support.customRequestSenderDeinit;

fn runDelayedRootServer(listener: *std.net.Server, allocator: std.mem.Allocator, delay_ms: u64, response_body: []const u8) void {
    var connection = listener.accept() catch return;
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

    std.Thread.sleep(delay_ms * std.time.ns_per_ms);
    request.respond(response_body, .{}) catch return;
}

fn createListener() !std.net.Server {
    const endpoint = std.net.Address.parseIp("127.0.0.1", 0) catch |err| {
        return err;
    };
    const server_listener = endpoint.listen(.{}) catch |err| switch (err) {
        error.AccessDenied => return error.SkipZigTest,
        else => return err,
    };
    return server_listener;
}

test "root.new constructors initialize endpoint" {
    const allocator = std.testing.allocator;
    const endpoint = "http://127.0.0.1:8899";

    var rpc = try client.RpcClient.new(allocator, endpoint);
    defer rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, rpc.url());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
    try std.testing.expect(rpc.getRequestTimeoutMs() == null);
    try std.testing.expect(rpc.getConfirmTransactionInitialTimeoutMs() == null);

    var commitment_rpc = try client.RpcClient.newWithCommitment(allocator, endpoint, .confirmed);
    defer commitment_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, commitment_rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, commitment_rpc.getDefaultCommitment().?);
    try std.testing.expect(commitment_rpc.getRequestTimeoutMs() == null);
    try std.testing.expect(commitment_rpc.getConfirmTransactionInitialTimeoutMs() == null);

    var timeout_rpc = try client.RpcClient.newWithTimeout(allocator, endpoint, 5_000);
    defer timeout_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, timeout_rpc.url());
    try std.testing.expect(timeout_rpc.getDefaultCommitment() == null);
    try std.testing.expectEqual(@as(?u64, 5_000), timeout_rpc.getRequestTimeoutMs());
    try std.testing.expect(timeout_rpc.getConfirmTransactionInitialTimeoutMs() == null);

    var timeout_commitment_rpc = try client.RpcClient.newWithTimeoutAndCommitment(
        allocator,
        endpoint,
        5_000,
        .confirmed,
    );
    defer timeout_commitment_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, timeout_commitment_rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, timeout_commitment_rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_000), timeout_commitment_rpc.getRequestTimeoutMs());
    try std.testing.expect(timeout_commitment_rpc.getConfirmTransactionInitialTimeoutMs() == null);

    var timeouts_commitment_rpc = try client.RpcClient.newWithTimeoutsAndCommitment(
        allocator,
        endpoint,
        5_000,
        10_000,
        .confirmed,
    );
    defer timeouts_commitment_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, timeouts_commitment_rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, timeouts_commitment_rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_000), timeouts_commitment_rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 10_000), timeouts_commitment_rpc.getConfirmTransactionInitialTimeoutMs());

    var sender_rpc = try client.RpcClient.newSender(allocator, endpoint);
    defer sender_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, sender_rpc.url());
    try std.testing.expect(sender_rpc.getDefaultCommitment() == null);

    var socket_rpc = try client.RpcClient.newSocket(allocator, endpoint);
    defer socket_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, socket_rpc.url());
    try std.testing.expect(socket_rpc.getDefaultCommitment() == null);

    var socket_commitment_rpc = try client.RpcClient.newSocketWithCommitment(allocator, endpoint, .finalized);
    defer socket_commitment_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, socket_commitment_rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, socket_commitment_rpc.getDefaultCommitment().?);

    var socket_timeout_rpc = try client.RpcClient.newSocketWithTimeout(allocator, endpoint, 5_000);
    defer socket_timeout_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, socket_timeout_rpc.url());
    try std.testing.expect(socket_timeout_rpc.getDefaultCommitment() == null);
    try std.testing.expectEqual(@as(?u64, 5_000), socket_timeout_rpc.getRequestTimeoutMs());
    try std.testing.expect(socket_timeout_rpc.getConfirmTransactionInitialTimeoutMs() == null);
}

test "root.inner accessors expose inner client handles" {
    const allocator = std.testing.allocator;

    var sender_context = RequestSenderContext{ .base_slot = 1000 };
    var rpc_with_sender = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &sender_context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc_with_sender.deinit();

    const inner_client = rpc_with_sender.getInnerClient();
    try std.testing.expect(inner_client.allocator.ptr == allocator.ptr);
    try std.testing.expect(rpc_with_sender.getInnerClientMut().allocator.ptr == allocator.ptr);

    const inner_sender = try rpc_with_sender.getInnerRequestSender();
    const inner_sender_mut = try rpc_with_sender.getInnerRequestSenderMut();
    const request_sender = try rpc_with_sender.requestSender();
    try std.testing.expectEqual(@as(usize, @intFromPtr(inner_sender)), @as(usize, @intFromPtr(request_sender)));
    try std.testing.expectEqual(@as(usize, @intFromPtr(inner_sender_mut)), @as(usize, @intFromPtr(request_sender)));

    const slot = try rpc_with_sender.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1001), slot);

    var rpc_mock = try client.RpcClient.newMock(allocator, &.{});
    defer rpc_mock.deinit();

    try std.testing.expect(rpc_mock.getInnerClient().allocator.ptr == allocator.ptr);
    try std.testing.expectError(error.NoRequestSender, rpc_mock.requestSender());
    try std.testing.expectError(error.NoRequestSender, rpc_mock.getInnerRequestSender());
}

test "root.newWithCommitment applies default commitment to null params" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithCommitment(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":123,\"id\":1}" },
        },
        .finalized,
    );
    defer rpc.deinit();

    _ = try rpc.getSlot(null);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getSlot", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.newMockWithTimeout preserves timeout and supports null commitment" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithTimeout(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":555,\"id\":1}" },
        },
        1234,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 1234), rpc.getRequestTimeoutMs());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
    try std.testing.expectEqual(@as(u64, 555), try rpc.getSlot(.processed));
}

test "root.newMockWithCommitmentAndTimeout preserves both options" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithCommitmentAndTimeout(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":444,\"id\":1}" },
        },
        .processed,
        4321,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 4321), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(u64, 444), try rpc.getSlot(.processed));
}

test "root.newMockWithOptions customizes endpoint and request/confirm timeout" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithOptions(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":555,\"id\":1}" },
        },
        .{
            .endpoint = "custom://mock-options",
            .commitment = .confirmed,
            .request_timeout_ms = 1_000,
            .confirm_transaction_initial_timeout_ms = 2_000,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 1_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 2_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 555), slot);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"confirmed\"") != null);
}

test "root.newMockAndRequestSenderOptions aliases newMockWithOptions" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockAndRequestSenderOptions(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":556,\"id\":1}" },
        },
        .{
            .endpoint = "custom://mock-request-sender-options",
            .commitment = .processed,
            .request_timeout_ms = 1_010,
            .confirm_transaction_initial_timeout_ms = 2_010,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-request-sender-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 1_010), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 2_010), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 556), slot);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"processed\"") != null);
}

test "root.newMockWithTimeouts sets request and confirm initial timeout" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithTimeouts(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":222,\"id\":1}" },
        },
        5000,
        9876,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 5000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 9876), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
}

test "root.newMockWithCommitmentAndTimeouts preserves both timeout values" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMockWithCommitmentAndTimeouts(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":333,\"id\":1}" },
        },
        .confirmed,
        500,
        600,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 600), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(u64, 333), try rpc.getSlot(.confirmed));
}

test "root.newMockWithHandlerAndTimeout applies timeout" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerAndTimeout(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        4321,
    );
    defer rpc.deinit();

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(?u64, 4321), rpc.getRequestTimeoutMs());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
}

test "root.newMockWithHandlerAndOptions customizes endpoint and timeout options" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerAndOptions(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://mock-handler-options",
            .commitment = .processed,
            .request_timeout_ms = 3_000,
            .confirm_transaction_initial_timeout_ms = 4_000,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-handler-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 3_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 4_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"processed\"") != null);
}

test "root.newMockWithHandlerAndRequestSenderOptions aliases newMockWithHandlerAndOptions" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerAndRequestSenderOptions(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://mock-handler-request-sender-options",
            .commitment = .confirmed,
            .request_timeout_ms = 3_010,
            .confirm_transaction_initial_timeout_ms = 4_010,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-handler-request-sender-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 3_010), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 4_010), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"confirmed\"") != null);
}

test "root.newMockHandler aliases newMockWithHandler" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockHandler(allocator, .{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });
    defer rpc.deinit();

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newMockHandlerAndRequestSenderOptions aliases newMockWithHandlerAndRequestSenderOptions" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockHandlerAndRequestSenderOptions(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://mock-handler-alias-options",
            .commitment = .processed,
            .request_timeout_ms = 3_020,
            .confirm_transaction_initial_timeout_ms = 4_020,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-handler-alias-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 3_020), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 4_020), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newMockHandlerAndCommitmentAndTimeouts preserves alias semantics" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockHandlerAndCommitmentAndTimeouts(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .confirmed,
        3_030,
        4_030,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 3_030), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 4_030), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newMockWithHandlerAndCommitmentAndTimeout applies commitment and timeout" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerAndCommitmentAndTimeout(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .confirmed,
        1111,
    );
    defer rpc.deinit();

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expectEqual(@as(?u64, 1111), rpc.getRequestTimeoutMs());
}

test "root.newMockWithHandlerTimeouts sets timeout and confirm timeout" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerTimeouts(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        6000,
        7000,
    );
    defer rpc.deinit();

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expectEqual(@as(?u64, 6000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7000), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
}

test "root.getTransportStats tracks request metrics" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":123,\"id\":1}" },
    });
    defer rpc.deinit();

    const before = rpc.getTransportStats();
    try std.testing.expectEqual(@as(usize, 0), before.request_count);

    _ = try rpc.getSlot(.confirmed);

    const after = rpc.getTransportStats();
    try std.testing.expect(after.request_count > before.request_count);
    try std.testing.expect(after.elapsed_time_ms >= before.elapsed_time_ms);
}

test "root.newWithTimeout applies real transport timeout" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":123,"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runDelayedRootServer, .{ &listener, allocator, 200, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.newWithTimeout(allocator, rpc_url, 50);
    defer rpc.deinit();

    try std.testing.expectError(error.Timeout, rpc.getSlot(null));
}

test "root.sendRaw serializes params without manual json assembly" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":123,\"id\":1}" },
    });
    defer rpc.deinit();

    const response = try rpc.sendRaw("getSlot", .{.{ .commitment = "finalized" }});
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"result\":123") != null);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getSlot", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.sendJsonRpc parses typed result and keeps owned slices alive" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"solana-core\":\"2.1.0\"},\"id\":1}" },
    });
    defer rpc.deinit();

    const VersionResult = struct {
        @"solana-core": []const u8 = "",
    };

    var result = try rpc.sendJsonRpc("getVersion", .{}, VersionResult);
    defer result.deinit();

    try std.testing.expectEqualStrings("2.1.0", result.value.@"solana-core");
    try std.testing.expect(std.mem.indexOf(u8, result.response_body, "\"solana-core\":\"2.1.0\"") != null);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getVersion", rpc.capturedMockRequests()[0].method);
}

test "root.sendTyped uses RpcRequest helpers" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"ok\",\"id\":1}" },
    });
    defer rpc.deinit();

    var result = try rpc.sendTyped(client.RpcRequest.getHealth, .{}, []const u8);
    defer result.deinit();

    try std.testing.expectEqualStrings("ok", result.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getHealth", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("[]", rpc.capturedMockRequests()[0].params_json);
}

test "root.newMock returns queued responses and captures requests" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":123,\"id\":1}" },
    });
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expectEqualStrings("mock://local", rpc.url());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 123), slot);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());

    const requests = rpc.capturedMockRequests();
    try std.testing.expectEqual(@as(usize, 1), requests.len);
    try std.testing.expectEqual(@as(u64, 1), requests[0].id);
    try std.testing.expectEqualStrings("getSlot", requests[0].method);
    try std.testing.expectEqualStrings("[{\"commitment\":\"confirmed\"}]", requests[0].params_json);
    try std.testing.expect(std.mem.indexOf(u8, requests[0].request_body, "\"method\":\"getSlot\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, requests[0].request_body, "\"id\":1") != null);

    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":\"ok\",\"id\":2}");
    var result = try rpc.sendTyped(client.RpcRequest.getHealth, .{}, []const u8);
    defer result.deinit();

    try std.testing.expectEqualStrings("ok", result.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqual(@as(usize, 0), rpc.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 2), rpc.getTransportStats().request_count);
}

test "root.newMockWithCommitment applies default commitment and can clear captures" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMockWithCommitment(
        allocator,
        &.{
            .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":456,\"id\":1}" },
        },
        .finalized,
    );
    defer rpc.deinit();

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 456), slot);
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);

    const requests = rpc.capturedMockRequests();
    try std.testing.expectEqual(@as(usize, 1), requests.len);
    try std.testing.expectEqualStrings("[{\"commitment\":\"finalized\"}]", requests[0].params_json);

    rpc.clearCapturedMockRequests();
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.newMock supports mock transport errors" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .transport_error = .timeout },
        .{ .transport_error = .http_error },
    });
    defer rpc.deinit();

    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));
    try std.testing.expectError(error.HttpError, rpc.getHealth());
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
}

test "root.newMockWithHandler synthesizes responses and captures requests" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandlerAndCommitment(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .finalized,
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 789), slot);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);

    try std.testing.expectEqual(@as(usize, 2), handler_context.call_count);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());

    const requests = rpc.capturedMockRequests();
    try std.testing.expectEqualStrings("getSlot", requests[0].method);
    try std.testing.expectEqualStrings("[{\"commitment\":\"finalized\"}]", requests[0].params_json);
    try std.testing.expectEqualStrings("getHealth", requests[1].method);
}

test "root.mock sender queued responses override handler until exhausted" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandler(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
    );
    defer rpc.deinit();

    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":123,\"id\":1}");
    try std.testing.expectEqual(@as(usize, 1), rpc.mockResponseCount());

    const first_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 123), first_slot);
    try std.testing.expectEqual(@as(usize, 0), handler_context.call_count);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockResponseCount());

    const second_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 456), second_slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);

    rpc.clearMockResponses();
    try std.testing.expectEqual(@as(usize, 0), rpc.mockResponseCount());
}

test "root.setMockHandler and clearMockHandler mutate mock transport behavior" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try std.testing.expect(!rpc.hasMockHandler());

    try rpc.setMockHandler(.{
        .callback = timeoutMockHandler,
    });
    try std.testing.expect(rpc.hasMockHandler());
    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));

    try rpc.clearMockHandler();
    try std.testing.expect(!rpc.hasMockHandler());
    try std.testing.expectError(error.MockResponseExhausted, rpc.getHealth());
}

test "root.RequestSender.fromMockSender supports mutable mock helpers" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&sender),
    );
    defer rpc.deinit();

    try rpc.setMockHandler(.{
        .callback = timeoutMockHandler,
    });
    try std.testing.expect(rpc.hasMockHandler());
    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));

    try rpc.clearMockHandler();
    try std.testing.expect(!rpc.hasMockHandler());

    try rpc.pushMockSlotResult(654);
    try rpc.pushMockHealthOk();

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 654), slot);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.newMockWithSenderAndOptions accepts prebuilt sender and structured mock responses" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(123);
    try sender.pushRpcError(.{
        .code = -32001,
        .message = "mock balance unavailable",
        .data_json = "{\"retryAfterMs\":25}",
    });

    var rpc = try client.RpcClient.newMockWithSenderAndOptions(allocator, sender, .{
        .commitment = .confirmed,
        .request_timeout_ms = 55,
        .confirm_transaction_initial_timeout_ms = 89,
    });
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 55), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 89), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 123), slot);

    try std.testing.expectError(
        error.RpcError,
        rpc.getBalance("Address11111111111111111111111111111111", null),
    );
    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32001), last_error.code);
    try std.testing.expectEqualStrings("mock balance unavailable", last_error.message);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
}

test "root.newMockWithSenderAndRequestSenderOptions customizes endpoint and mock options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(654);

    var rpc = try client.RpcClient.newMockWithSenderAndRequestSenderOptions(
        allocator,
        sender,
        .{
            .endpoint = "custom://mock-sender-options",
            .commitment = .confirmed,
            .request_timeout_ms = 9_000,
            .confirm_transaction_initial_timeout_ms = 11_000,
        },
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expectEqualStrings("custom://mock-sender-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 9_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 11_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 654), slot);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"confirmed\"") != null);
}

test "root.newMockSender aliases newMockWithSender" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(655);

    var rpc = try client.RpcClient.newMockSender(allocator, sender);
    defer rpc.deinit();

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 655), slot);
}

test "root.newMockSenderAndRequestSenderOptions aliases newMockWithSenderAndRequestSenderOptions" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(656);

    var rpc = try client.RpcClient.newMockSenderAndRequestSenderOptions(
        allocator,
        sender,
        .{
            .endpoint = "custom://mock-sender-request-sender-options",
            .commitment = .confirmed,
            .request_timeout_ms = 33,
            .confirm_transaction_initial_timeout_ms = 66,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-sender-request-sender-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 33), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 66), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 656), slot);
}

test "root.newMockSenderAndCommitmentAndTimeouts preserves alias semantics" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(657);

    var rpc = try client.RpcClient.newMockSenderAndCommitmentAndTimeouts(
        allocator,
        sender,
        .processed,
        34,
        68,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 34), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 68), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 657), slot);
}

test "root.newMockWithSenderAndCommitment applies commitment default" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(123);

    var rpc = try client.RpcClient.newMockWithSenderAndCommitment(
        allocator,
        sender,
        .confirmed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expect(rpc.getRequestTimeoutMs() == null);

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 123), slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.newMockWithSenderAndTimeout preserves timeout settings" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newMockWithSenderAndTimeout(
        allocator,
        sender,
        12_345,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 12_345), rpc.getRequestTimeoutMs());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.newMockWithSenderAndTimeouts forwards both timeout values" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(345);

    var rpc = try client.RpcClient.newMockWithSenderAndTimeouts(
        allocator,
        sender,
        5_000,
        8_000,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 5_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 8_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 345), slot);
}

test "root.newMockWithSenderAndCommitmentAndTimeouts aliases timeout/commitment order" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newMockWithSenderAndCommitmentAndTimeouts(
        allocator,
        sender,
        .processed,
        1_234,
        4_567,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 1_234), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 4_567), rpc.getConfirmTransactionInitialTimeoutMs());
    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.mock common response helpers cover common RPC methods" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const blockhash = "Blockhash111111111111111111111111111111111111";
    const signature = "Sig111111111111111111111111111111111111111111111111111111111111111111";

    try rpc.pushMockSlotResult(321);
    try rpc.pushMockHealthOk();
    try rpc.pushMockLatestBlockhashResponse(44, blockhash, 77);
    try rpc.pushMockSignatureResult(signature);

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 321), slot);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);

    const latest = try rpc.getLatestBlockhashResponse(.confirmed);
    defer allocator.free(latest.value.blockhash);
    try std.testing.expectEqual(@as(u64, 44), latest.context_slot);
    try std.testing.expectEqualStrings(blockhash, latest.value.blockhash);
    try std.testing.expectEqual(@as(u64, 77), latest.value.last_valid_block_height);

    const send_signature = try rpc.send("SignedTransactionBase64==");
    defer allocator.free(send_signature);
    try std.testing.expectEqualStrings(signature, send_signature);

    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getSlot", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getHealth", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[2].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[3].method);
    try mock_sender_assertions.expectMockRpcScriptSatisfied(&rpc);
}

test "root.mockSender exposes mutable scripted sender state" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMockWithSenderAndOptions(
        allocator,
        client.MockSender.init(allocator),
        .{},
    );
    defer rpc.deinit();

    var sender = try rpc.mockSender();
    try sender.pushHealthOk();
    try sender.pushTransportError(.connection_reset);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
    try std.testing.expectError(error.ConnectionResetByPeer, rpc.getSlot(.processed));

    sender = try rpc.mockSender();
    sender.clearCapturedRequests();
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.mock handler supports structured result and rpc error helpers" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandler(
        allocator,
        .{
            .context = &handler_context,
            .callback = structuredMockHandler,
        },
    );
    defer rpc.deinit();

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 100), slot);

    try std.testing.expectError(error.RpcError, rpc.getHealth());
    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32000), last_error.code);
    try std.testing.expectEqualStrings("mock handler rejected request", last_error.message);
    try std.testing.expectEqual(@as(usize, 2), handler_context.call_count);
}

test "root.newWithRequestSenderAndOptions injects generic request sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 600,
        .error_code = -32077,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
            allocator,
            client.RequestSender.initWithDeinit(
                &context,
                customRequestSender,
                customRequestSenderDeinit,
            ),
            .{
                .endpoint = "custom://sender",
                .commitment = .confirmed,
                .request_timeout_ms = 21,
                .confirm_transaction_initial_timeout_ms = 34,
            },
        );
        defer rpc.deinit();

        try std.testing.expect(!rpc.isMock());
        try std.testing.expect(rpc.hasRequestSender());
        try std.testing.expectEqualStrings("custom://sender", rpc.url());
        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 21), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 34), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 601), slot);
        try std.testing.expect(context.saw_confirmed_commitment);

        try std.testing.expectError(error.RpcError, rpc.getHealth());
        const last_error = rpc.getLastError() orelse return error.TestExpectedError;
        try std.testing.expectEqual(@as(i64, -32077), last_error.code);
        try std.testing.expectEqualStrings("custom sender rejected request", last_error.message);
        try std.testing.expectEqual(@as(usize, 2), context.call_count);
    }

    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);
}

test "root.newWithMockRequestSender creates request-sender-backed mock client from responses" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newWithMockRequestSender(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockSlotResult(1125);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1125), slot);
}

test "root.newWithMockRequestSenderAndOptions customizes endpoint and mock request sender options" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newWithMockRequestSenderAndOptions(
        allocator,
        &.{},
        .{
            .endpoint = "custom://mock-request-sender",
            .commitment = .confirmed,
            .request_timeout_ms = 4_250,
            .confirm_transaction_initial_timeout_ms = 7_250,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-request-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_250), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_250), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
}

test "root.newWithMockRequestSenderAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newWithMockRequestSenderAndRequestSenderOptions(
        allocator,
        &.{},
        .{
            .endpoint = "custom://mock-request-sender-alias",
            .commitment = .processed,
            .request_timeout_ms = 4_255,
            .confirm_transaction_initial_timeout_ms = 7_255,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-request-sender-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_255), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_255), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
}

test "root.newWithMockRequestSenderWithHandler installs request-sender-backed mock handler" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithMockRequestSenderWithHandler(allocator, .{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newWithMockRequestSenderWithHandlerAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithMockRequestSenderWithHandlerAndRequestSenderOptions(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://mock-request-handler-alias",
            .commitment = .confirmed,
            .request_timeout_ms = 4_850,
            .confirm_transaction_initial_timeout_ms = 7_850,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-request-handler-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_850), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_850), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newWithMockRequestSenderAndCommitmentAndTimeouts preserves commitment-first alias semantics" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newWithMockRequestSenderAndCommitmentAndTimeouts(
        allocator,
        &.{},
        .confirmed,
        4_600,
        7_600,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_600), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_600), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
}

test "root.newWithMockRequestSenderAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newWithMockRequestSenderAndTimeoutsAndCommitment(
        allocator,
        &.{},
        4_700,
        7_700,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_700), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_700), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
}

test "root.newWithMockRequestSenderWithHandlerAndCommitmentAndTimeouts preserves commitment-first alias semantics" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithMockRequestSenderWithHandlerAndCommitmentAndTimeouts(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .confirmed,
        4_800,
        7_800,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_800), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_800), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newWithMockRequestSenderWithHandlerAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithMockRequestSenderWithHandlerAndTimeoutsAndCommitment(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        4_900,
        7_900,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_900), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_900), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.newWithMockRequestSenderWithSenderAndCommitmentAndTimeouts preserves commitment-first alias semantics" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(801);

    var rpc = try client.RpcClient.newWithMockRequestSenderWithSenderAndCommitmentAndTimeouts(
        allocator,
        sender,
        .confirmed,
        5_000,
        8_000,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 8_000), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 801), slot);
}

test "root.newWithMockRequestSenderWithSenderAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(802);

    var rpc = try client.RpcClient.newWithMockRequestSenderWithSenderAndTimeoutsAndCommitment(
        allocator,
        sender,
        5_100,
        8_100,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_100), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 8_100), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 802), slot);
}

test "root.newWithMockRequestSenderWithSenderAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(803);

    var rpc = try client.RpcClient.newWithMockRequestSenderWithSenderAndRequestSenderOptions(
        allocator,
        sender,
        .{
            .endpoint = "custom://mock-request-sender-with-sender-alias",
            .commitment = .finalized,
            .request_timeout_ms = 5_150,
            .confirm_transaction_initial_timeout_ms = 8_150,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://mock-request-sender-with-sender-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_150), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 8_150), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 803), slot);
}

test "root.newWithRequestSenderAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1110 };

    var rpc = try client.RpcClient.newWithRequestSenderAndRequestSenderOptions(
        allocator,
        client.RequestSender.init(&context, customRequestSender),
        .{
            .endpoint = "custom://request-sender-alias",
            .commitment = .confirmed,
            .request_timeout_ms = 4_300,
            .confirm_transaction_initial_timeout_ms = 7_300,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://request-sender-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_300), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_300), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1111), slot);
    try std.testing.expect(context.saw_confirmed_commitment);
}

test "root.newRequestSender aliases newWithRequestSender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1115 };

    var rpc = try client.RpcClient.newRequestSender(
        allocator,
        client.RequestSender.init(&context, customRequestSender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isCallbackRequestSenderClient());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1116), slot);
}

test "root.newRequestSenderAndRequestSenderOptions aliases newWithRequestSenderAndRequestSenderOptions" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1120 };

    var rpc = try client.RpcClient.newRequestSenderAndRequestSenderOptions(
        allocator,
        client.RequestSender.init(&context, customRequestSender),
        .{
            .endpoint = "custom://request-sender-short-alias",
            .commitment = .processed,
            .request_timeout_ms = 4_310,
            .confirm_transaction_initial_timeout_ms = 7_310,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://request-sender-short-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_310), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_310), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1121), slot);
}

test "root.newWithRequestCallbackAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1710 };

    var rpc = try client.RpcClient.newWithRequestCallbackAndRequestSenderOptions(
        allocator,
        &context,
        customRequestSender,
        .{
            .endpoint = "custom://request-callback-alias",
            .commitment = .finalized,
            .request_timeout_ms = 22,
            .confirm_transaction_initial_timeout_ms = 35,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://request-callback-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 22), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 35), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1711), slot);
    try std.testing.expect(context.saw_finalized_commitment);
}

test "root.newWithRequestCallbackAndDeinitAndRequestSenderOptions aliases AndOptions" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1720 };

    {
        var rpc = try client.RpcClient.newWithRequestCallbackAndDeinitAndRequestSenderOptions(
            allocator,
            &context,
            customRequestSender,
            countingRequestSenderDeinit,
            .{
                .endpoint = "custom://request-callback-deinit-alias",
                .commitment = .confirmed,
                .request_timeout_ms = 23,
                .confirm_transaction_initial_timeout_ms = 36,
            },
        );
        defer rpc.deinit();

        try std.testing.expectEqualStrings("custom://request-callback-deinit-alias", rpc.url());
        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 23), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 36), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1721), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }

    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);
}

test "root.newWithRequestSenderAndCommitment applies commitment default" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1100,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndCommitment(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
            .confirmed,
        );
        defer rpc.deinit();

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1101), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }
}

test "root.newWithRequestSenderAndTimeouts forwards both request and confirm timeout" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1200,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndTimeouts(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
            5_000,
            10_000,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(@as(?u64, 5_000), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 10_000), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(.processed);
        try std.testing.expectEqual(@as(u64, 1201), slot);
    }
}

test "root.newWithRequestCallbackAndOptions accepts raw callback with request sender options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1250,
    };

    {
        var rpc = try client.RpcClient.newWithRequestCallbackAndOptions(
            allocator,
            &context,
            customRequestSender,
            .{
                .endpoint = "custom://callback",
                .commitment = .confirmed,
                .request_timeout_ms = 5_500,
                .confirm_transaction_initial_timeout_ms = 8_500,
            },
        );
        defer rpc.deinit();

        try std.testing.expectEqualStrings("custom://callback", rpc.url());
        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 5_500), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 8_500), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1251), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }
}

test "root.newWithRequestCallbackAndDeinitAndOptions deinitializes callback sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1275,
    };

    {
        var rpc = try client.RpcClient.newWithRequestCallbackAndDeinitAndOptions(
            allocator,
            &context,
            customRequestSender,
            customRequestSenderDeinit,
            .{
                .endpoint = "custom://callback-deinit",
            },
        );
        defer rpc.deinit();

        const slot = try rpc.getSlot(.processed);
        try std.testing.expectEqual(@as(u64, 1276), slot);
    }

    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);
}

test "root.newWithRequestCallbackAndTimeoutsAndCommitment preserves timeout-first callback alias semantics" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1280,
    };

    {
        var rpc = try client.RpcClient.newWithRequestCallbackAndTimeoutsAndCommitment(
            allocator,
            &context,
            customRequestSender,
            6_250,
            9_250,
            .processed,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 6_250), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 9_250), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1281), slot);
    }
}

test "root.newWithRequestCallbackAndDeinitAndCommitmentAndTimeouts deinitializes callback alias" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1290,
    };

    {
        var rpc = try client.RpcClient.newWithRequestCallbackAndDeinitAndCommitmentAndTimeouts(
            allocator,
            &context,
            customRequestSender,
            customRequestSenderDeinit,
            .confirmed,
            6_750,
            9_750,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 6_750), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 9_750), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1291), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }

    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);
}

test "root.newWithRequestSenderAndCommitmentAndTimeouts preserves commitment-first alias semantics" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1300,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndCommitmentAndTimeouts(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
            .confirmed,
            6_000,
            11_000,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 6_000), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 11_000), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1301), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }
}

test "root.newRequestSenderAndCommitmentAndTimeouts preserves short alias semantics" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1305,
    };

    {
        var rpc = try client.RpcClient.newRequestSenderAndCommitmentAndTimeouts(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
            .confirmed,
            6_260,
            9_260,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 6_260), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 9_260), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1306), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
    }
}

test "root.newWithRequestSenderAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1400,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndTimeoutsAndCommitment(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
            7_000,
            12_000,
            .processed,
        );
        defer rpc.deinit();

        try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
        try std.testing.expectEqual(@as(?u64, 7_000), rpc.getRequestTimeoutMs());
        try std.testing.expectEqual(@as(?u64, 12_000), rpc.getConfirmTransactionInitialTimeoutMs());

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 1401), slot);
    }
}

test "root.replaceRequestSender resets stats and deinitializes previous sender" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 700 };
    var second_context = RequestSenderContext{ .base_slot = 900 };

    var rpc = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &first_context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc.deinit();

    const first_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 701), first_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.getTransportStats().request_count);
    try std.testing.expectEqual(@as(u64, 1), first_context.last_request_id);

    try rpc.replaceRequestSender(
        client.RequestSender.initWithDeinit(
            &second_context,
            customRequestSender,
            customRequestSenderDeinit,
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
    try std.testing.expect(rpc.hasRequestSender());

    const second_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 901), second_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.getTransportStats().request_count);
    try std.testing.expectEqual(@as(u64, 1), second_context.last_request_id);
}

test "root.replaceRequestSenderAndRequestSenderOptions updates sender and runtime options" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 720 };
    var second_context = RequestSenderContext{ .base_slot = 920 };

    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.initWithDeinit(&first_context, customRequestSender, customRequestSenderDeinit),
        .{
            .endpoint = "custom://first-request-sender",
            .commitment = .processed,
            .request_timeout_ms = 41,
            .confirm_transaction_initial_timeout_ms = 61,
        },
    );
    defer rpc.deinit();

    _ = try rpc.getSlot(null);

    try rpc.replaceRequestSenderAndRequestSenderOptions(
        client.RequestSender.initWithDeinit(&second_context, customRequestSender, customRequestSenderDeinit),
        .{
            .endpoint = "custom://second-request-sender",
            .commitment = .confirmed,
            .request_timeout_ms = 42,
            .confirm_transaction_initial_timeout_ms = 62,
        },
    );

    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
    try std.testing.expectEqualStrings("custom://second-request-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 42), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 62), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expectEqual(@as(usize, 0), rpc.getTransportStats().request_count);

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 921), slot);
    try std.testing.expect(second_context.saw_confirmed_commitment);
}

test "root.setRequestCallback converts plain client to callback request sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1450 };

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    rpc.setRequestCallback(&context, customRequestSender);

    try std.testing.expect(rpc.isCallbackRequestSenderClient());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1451), slot);
}

test "root.setRequestCallbackAndRequestSenderOptions converts plain client and updates runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1455 };

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    rpc.setRequestCallbackAndRequestSenderOptions(
        &context,
        customRequestSender,
        .{
            .endpoint = "custom://set-request-callback",
            .commitment = .finalized,
            .request_timeout_ms = 43,
            .confirm_transaction_initial_timeout_ms = 63,
        },
    );

    try std.testing.expect(rpc.isCallbackRequestSenderClient());
    try std.testing.expectEqualStrings("custom://set-request-callback", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 43), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 63), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1456), slot);
    try std.testing.expect(context.saw_finalized_commitment);
}

test "root.replaceRequestCallbackAndDeinit resets stats and deinitializes previous callback sender" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 1460 };
    var second_context = RequestSenderContext{ .base_slot = 1470 };

    var rpc = try client.RpcClient.newWithRequestCallbackAndDeinit(
        allocator,
        &first_context,
        customRequestSender,
        customRequestSenderDeinit,
    );
    defer rpc.deinit();

    const first_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1461), first_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.getTransportStats().request_count);

    try rpc.replaceRequestCallbackAndDeinit(
        &second_context,
        customRequestSender,
        customRequestSenderDeinit,
    );

    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
    try std.testing.expect(rpc.isCallbackRequestSenderClient());

    const second_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1471), second_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.getTransportStats().request_count);
}

test "root.replaceWithBorrowedMockSender swaps in borrowed mock sender" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 1500 };
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(1701);

    var rpc = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &first_context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc.deinit();

    const first_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1501), first_slot);

    try rpc.replaceWithBorrowedMockSender(&sender);

    const replacement_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1701), replacement_slot);
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
}

test "root.replaceWithBorrowedMockSenderAndRequestSenderOptions updates runtime options" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 1510 };
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(1711);

    var rpc = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &first_context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc.deinit();

    try rpc.replaceWithBorrowedMockSenderAndRequestSenderOptions(
        &sender,
        .{
            .endpoint = "custom://replace-borrowed-mock-sender",
            .commitment = .confirmed,
            .request_timeout_ms = 46,
            .confirm_transaction_initial_timeout_ms = 66,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://replace-borrowed-mock-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 46), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 66), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 1711), slot);
}

test "root.replaceWithOwnedMockSender swaps in owned mock sender" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 1600 };

    var rpc = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &first_context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc.deinit();

    const first_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1601), first_slot);

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(1801);
    try rpc.replaceWithOwnedMockSender(sender);

    const replacement_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 1801), replacement_slot);
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
}

test "root.replaceWithOwnedMockSenderAndRequestSenderOptions updates runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1610 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.initWithDeinit(
            &context,
            customRequestSender,
            customRequestSenderDeinit,
        ),
    );
    defer rpc.deinit();

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(1811);

    try rpc.replaceWithOwnedMockSenderAndRequestSenderOptions(
        sender,
        .{
            .endpoint = "custom://replace-owned-mock-sender",
            .commitment = .confirmed,
            .request_timeout_ms = 49,
            .confirm_transaction_initial_timeout_ms = 69,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://replace-owned-mock-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 49), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 69), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1811), slot);
}

test "root.replaceWithMock converts request sender client to owned mock-backed sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1810 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMock(&.{});
    try rpc.pushMockSlotResult(1811);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1811), slot);
}

test "root.replaceWithMockAndRequestSenderOptions updates runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1815 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockAndRequestSenderOptions(
        &.{ .{ .result_json = "1812" } },
        .{
            .endpoint = "custom://replace-mock",
            .commitment = .confirmed,
            .request_timeout_ms = 53,
            .confirm_transaction_initial_timeout_ms = 73,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://replace-mock", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 53), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 73), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1812), slot);
}

test "root.replaceWithMockSender converts request sender client to direct mock client" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1816 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(1813);

    try rpc.replaceWithMockSender(sender);

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expect(!rpc.hasRequestSender());
    try std.testing.expectError(error.NoRequestSender, rpc.requestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1813), slot);
}

test "root.replaceWithMockHandler installs owned handler-backed sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1820 };
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockHandler(.{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.replaceWithMockSenderAndRequestSenderOptions updates direct mock runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1826 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(1814);

    try rpc.replaceWithMockSenderAndRequestSenderOptions(
        sender,
        .{
            .endpoint = "custom://replace-mock-sender-direct",
            .commitment = .processed,
            .request_timeout_ms = 55,
            .confirm_transaction_initial_timeout_ms = 75,
        },
    );

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expectEqualStrings("custom://replace-mock-sender-direct", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 55), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 75), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(!rpc.hasRequestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1814), slot);
}

test "root.replaceWithMockHandlerAndRequestSenderOptions updates runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1825 };
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockHandlerAndRequestSenderOptions(
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://replace-mock-handler",
            .commitment = .finalized,
            .request_timeout_ms = 54,
            .confirm_transaction_initial_timeout_ms = 74,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://replace-mock-handler", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 54), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 74), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.replaceWithMockRequestSender converts callback client to request-sender-backed mock sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1830 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockRequestSender(&.{});
    try rpc.pushMockSlotResult(1831);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 1831), slot);
}

test "root.replaceWithMockRequestSenderWithHandlerAndRequestSenderOptions updates runtime options" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1845 };
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.initWithDeinit(&context, customRequestSender, customRequestSenderDeinit),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockRequestSenderWithHandlerAndRequestSenderOptions(
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://replace-mock-request-handler",
            .commitment = .confirmed,
            .request_timeout_ms = 44,
            .confirm_transaction_initial_timeout_ms = 64,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://replace-mock-request-handler", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 44), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 64), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.replaceWithMockRequestSenderWithHandler installs request-sender-backed mock handler" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1840 };
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try rpc.replaceWithMockRequestSenderWithHandler(.{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.setRequestSender converts plain client to request sender client" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 2000 };

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    rpc.setRequestSender(client.RequestSender.init(
        &context,
        customRequestSender,
    ));

    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expect(!rpc.isMock());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 2001), slot);
}

test "root.setBorrowedMockSender converts plain client to mock-backed request sender" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(2101);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    rpc.setBorrowedMockSender(&sender);

    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasMockRequestSender());
    try std.testing.expectEqual(@intFromPtr(&sender), @intFromPtr(try rpc.requestSenderMockSender()));

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2101), slot);
}

test "root.setBorrowedMockSenderAndRequestSenderOptions converts plain client and updates runtime options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(2102);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    rpc.setBorrowedMockSenderAndRequestSenderOptions(
        &sender,
        .{
            .endpoint = "custom://set-borrowed-mock-sender",
            .commitment = .finalized,
            .request_timeout_ms = 47,
            .confirm_transaction_initial_timeout_ms = 67,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://set-borrowed-mock-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 47), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 67), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2102), slot);
}

test "root.setMock converts plain client to direct mock client from response queue" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMock(&.{});
    try rpc.pushMockSlotResult(2151);

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2151), slot);
}

test "root.setMockAndRequestSenderOptions converts plain client to direct mock client and updates runtime options" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockAndRequestSenderOptions(
        &.{ .{ .result_json = "2152" } },
        .{
            .endpoint = "custom://set-mock-direct",
            .commitment = .confirmed,
            .request_timeout_ms = 50,
            .confirm_transaction_initial_timeout_ms = 70,
        },
    );

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expectEqualStrings("custom://set-mock-direct", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 50), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 70), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2152), slot);
}

test "root.setMockWithHandler converts plain client to direct handler-backed mock client" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockWithHandler(.{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.setMockWithHandlerAndRequestSenderOptions converts plain client to direct handler-backed mock client and updates runtime options" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockWithHandlerAndRequestSenderOptions(
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
        .{
            .endpoint = "custom://set-mock-handler-direct",
            .commitment = .finalized,
            .request_timeout_ms = 51,
            .confirm_transaction_initial_timeout_ms = 71,
        },
    );

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expectEqualStrings("custom://set-mock-handler-direct", rpc.url());
    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 51), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 71), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.setMockRequestSender converts plain client to request-sender-backed mock client" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockRequestSender(&.{});
    try rpc.pushMockSlotResult(2161);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2161), slot);
}

test "root.setMockRequestSenderWithSenderAndRequestSenderOptions converts plain client and updates runtime options" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(2162);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockRequestSenderWithSenderAndRequestSenderOptions(
        sender,
        .{
            .endpoint = "custom://set-mock-request-sender-with-sender",
            .commitment = .processed,
            .request_timeout_ms = 45,
            .confirm_transaction_initial_timeout_ms = 65,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://set-mock-request-sender-with-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 45), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 65), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2162), slot);
}

test "root.setMockRequestSenderWithHandler converts plain client to request-sender-backed mock handler" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockRequestSenderWithHandler(.{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expect(rpc.hasMockHandler());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.setRequestSender converts direct mock client to generic request sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 2200 };

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    rpc.setRequestSender(client.RequestSender.init(
        &context,
        customRequestSender,
    ));

    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expect(!rpc.isMock());
    try std.testing.expectError(error.NotMockClient, rpc.mockSender());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 2201), slot);
}

test "root.setOwnedMockSenderAndRequestSenderOptions converts plain client and updates runtime options" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(2202);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setOwnedMockSenderAndRequestSenderOptions(
        sender,
        .{
            .endpoint = "custom://set-owned-mock-sender",
            .commitment = .processed,
            .request_timeout_ms = 48,
            .confirm_transaction_initial_timeout_ms = 68,
        },
    );

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expectEqualStrings("custom://set-owned-mock-sender", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 48), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 68), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2202), slot);
}

test "root.setMockSender converts plain client to direct mock client" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(2301);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockSender(sender);

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(!rpc.hasRequestSender());
    try std.testing.expectError(error.NoRequestSender, rpc.requestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2301), slot);
}

test "root.setMockSenderAndRequestSenderOptions converts plain client to direct mock client and updates runtime options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(2302);

    var rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer rpc.deinit();

    try rpc.setMockSenderAndRequestSenderOptions(
        sender,
        .{
            .endpoint = "custom://set-mock-sender-direct",
            .commitment = .processed,
            .request_timeout_ms = 52,
            .confirm_transaction_initial_timeout_ms = 72,
        },
    );

    try std.testing.expect(rpc.isDirectMockClient());
    try std.testing.expectEqualStrings("custom://set-mock-sender-direct", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 52), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 72), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2302), slot);
}

test "root.setMockSender converts request sender client to direct mock client" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 2400 };
    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newWithRequestSender(allocator, client.RequestSender.initWithDeinit(
        &context,
        customRequestSender,
        customRequestSenderDeinit,
    ));
    defer rpc.deinit();

    try rpc.setMockSender(sender);

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(!rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.backend state helpers distinguish transport kinds" {
    const allocator = std.testing.allocator;
    var request_sender_context = RequestSenderContext{ .base_slot = 2500 };
    var borrowed_mock_sender = client.MockSender.init(allocator);
    defer borrowed_mock_sender.deinit();
    var direct_mock_sender = client.MockSender.init(allocator);
    try direct_mock_sender.pushSlotResult(2601);

    var http_rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer http_rpc.deinit();
    try std.testing.expectEqual(client.RpcClient.BackendKind.http, http_rpc.backendKind());
    try std.testing.expect(http_rpc.isHttpTransportClient());
    try std.testing.expect(!http_rpc.isMock());
    try std.testing.expect(!http_rpc.isDirectMockClient());
    try std.testing.expect(!http_rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(!http_rpc.isCallbackRequestSenderClient());

    var request_sender_rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &request_sender_context,
            customRequestSender,
        ),
    );
    defer request_sender_rpc.deinit();
    try std.testing.expectEqual(client.RpcClient.BackendKind.callback_request_sender, request_sender_rpc.backendKind());
    try std.testing.expect(!request_sender_rpc.isHttpTransportClient());
    try std.testing.expect(!request_sender_rpc.isMock());
    try std.testing.expect(!request_sender_rpc.isDirectMockClient());
    try std.testing.expect(!request_sender_rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(request_sender_rpc.isCallbackRequestSenderClient());

    var borrowed_mock_rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&borrowed_mock_sender),
    );
    defer borrowed_mock_rpc.deinit();
    try std.testing.expectEqual(client.RpcClient.BackendKind.request_sender_backed_mock, borrowed_mock_rpc.backendKind());
    try std.testing.expect(!borrowed_mock_rpc.isHttpTransportClient());
    try std.testing.expect(borrowed_mock_rpc.isMock());
    try std.testing.expect(!borrowed_mock_rpc.isDirectMockClient());
    try std.testing.expect(borrowed_mock_rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(!borrowed_mock_rpc.isCallbackRequestSenderClient());

    var direct_mock_rpc = try client.RpcClient.new(allocator, "http://127.0.0.1:8899");
    defer direct_mock_rpc.deinit();
    try direct_mock_rpc.setMockSender(direct_mock_sender);
    try std.testing.expectEqual(client.RpcClient.BackendKind.direct_mock, direct_mock_rpc.backendKind());
    try std.testing.expect(!direct_mock_rpc.isHttpTransportClient());
    try std.testing.expect(direct_mock_rpc.isMock());
    try std.testing.expect(direct_mock_rpc.isDirectMockClient());
    try std.testing.expect(!direct_mock_rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(!direct_mock_rpc.isCallbackRequestSenderClient());

    const slot = try direct_mock_rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 2601), slot);
}

test "root.RequestSender kind helpers distinguish callback borrowed and owned mock senders" {
    const allocator = std.testing.allocator;
    var callback_context = RequestSenderContext{ .base_slot = 3400 };
    var borrowed_mock = client.MockSender.init(allocator);
    defer borrowed_mock.deinit();
    var owned_mock = client.MockSender.init(allocator);
    try owned_mock.pushSlotResult(1);

    const callback_sender = client.RequestSender.init(
        &callback_context,
        customRequestSender,
    );
    try std.testing.expectEqual(client.RequestSender.Kind.callback, callback_sender.kind());
    try std.testing.expect(callback_sender.isCallbackSender());
    try std.testing.expect(!callback_sender.isMockSender());
    try std.testing.expect(!callback_sender.isBorrowedMockSender());
    try std.testing.expect(!callback_sender.isOwnedMockSender());

    const borrowed_sender = client.RequestSender.fromMockSender(&borrowed_mock);
    try std.testing.expectEqual(client.RequestSender.Kind.borrowed_mock, borrowed_sender.kind());
    try std.testing.expect(!borrowed_sender.isCallbackSender());
    try std.testing.expect(borrowed_sender.isMockSender());
    try std.testing.expect(borrowed_sender.isBorrowedMockSender());
    try std.testing.expect(!borrowed_sender.isOwnedMockSender());

    var owned_sender = try client.RequestSender.fromOwnedMockSender(allocator, owned_mock);
    defer owned_sender.deinit(allocator);
    try std.testing.expectEqual(client.RequestSender.Kind.owned_mock, owned_sender.kind());
    try std.testing.expect(!owned_sender.isCallbackSender());
    try std.testing.expect(owned_sender.isMockSender());
    try std.testing.expect(!owned_sender.isBorrowedMockSender());
    try std.testing.expect(owned_sender.isOwnedMockSender());
}

test "root.RequestSender constructor aliases preserve callback and mock kinds" {
    const allocator = std.testing.allocator;
    var callback_context = RequestSenderContext{ .base_slot = 3410 };
    var callback_deinit_context = RequestSenderContext{ .base_slot = 3420 };
    var borrowed_mock = client.MockSender.init(allocator);
    defer borrowed_mock.deinit();
    var owned_mock = client.MockSender.init(allocator);
    try owned_mock.pushSlotResult(1);

    const callback_sender = client.RequestSender.initCallback(
        &callback_context,
        customRequestSender,
    );
    try std.testing.expectEqual(client.RequestSender.Kind.callback, callback_sender.kind());

    var callback_deinit_sender = client.RequestSender.initCallbackWithDeinit(
        &callback_deinit_context,
        customRequestSender,
        customRequestSenderDeinit,
    );
    try std.testing.expectEqual(client.RequestSender.Kind.callback, callback_deinit_sender.kind());
    callback_deinit_sender.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), callback_deinit_context.deinit_count);

    const borrowed_sender = client.RequestSender.initBorrowedMockSender(&borrowed_mock);
    try std.testing.expectEqual(client.RequestSender.Kind.borrowed_mock, borrowed_sender.kind());

    var owned_sender = try client.RequestSender.initOwnedMockSender(allocator, owned_mock);
    defer owned_sender.deinit(allocator);
    try std.testing.expectEqual(client.RequestSender.Kind.owned_mock, owned_sender.kind());
}

test "root.RequestSender.initMock creates owned mock-backed sender" {
    const allocator = std.testing.allocator;

    var request_sender = try client.RequestSender.initMock(allocator, &.{});
    try std.testing.expectEqual(client.RequestSender.Kind.owned_mock, request_sender.kind());
    try request_sender.pushMockSlotResult(3501);

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 3501), slot);
}

test "root.RequestSender.initMockWithHandler creates owned handler-backed sender" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var request_sender = try client.RequestSender.initMockWithHandler(allocator, .{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });
    try std.testing.expectEqual(client.RequestSender.Kind.owned_mock, request_sender.kind());
    try std.testing.expect(request_sender.hasMockHandler());

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.RequestSender.initMockWithSender wraps prebuilt mock sender" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var request_sender = try client.RequestSender.initMockWithSender(allocator, sender);
    try std.testing.expectEqual(client.RequestSender.Kind.owned_mock, request_sender.kind());

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.RequestSender.fromMockSender exposes mock surface through RpcClient" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(321);

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&sender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
    try std.testing.expectEqual(@intFromPtr(&sender), @intFromPtr(try rpc.mockSender()));

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 321), slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqual(@as(usize, 1), rpc.capturedMockRequests().len);

    rpc.clearCapturedMockRequests();
    try std.testing.expectEqual(@as(usize, 0), rpc.capturedMockRequests().len);
}

test "root.RequestSender.fromOwnedMockSender preserves mock surface and replaceMockSender" {
    const allocator = std.testing.allocator;
    var scripted_sender = client.MockSender.init(allocator);
    try scripted_sender.pushSlotResult(777);

    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        try client.RequestSender.fromOwnedMockSender(allocator, scripted_sender),
        .{
            .endpoint = "custom://owned-mock",
        },
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockResponseCount());

    const first_slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 777), first_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());

    var replacement = client.MockSender.init(allocator);
    try replacement.pushSlotResult(888);
    try rpc.replaceMockSender(replacement);

    try std.testing.expect(rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());

    const second_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 888), second_slot);
}

test "root.requestSenderMockSender exposes borrowed mock sender through request sender path" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&sender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.hasMockRequestSender());
    try std.testing.expectEqual(@intFromPtr(&sender), @intFromPtr(try rpc.requestSenderMockSender()));
    try std.testing.expectEqual(@intFromPtr(&sender), @intFromPtr(try rpc.requestSenderMockSenderConst()));
}

test "root.requestSenderMockSender rejects non-mock request sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 1900 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try std.testing.expect(!rpc.hasMockRequestSender());
    try std.testing.expectError(error.NotMockSender, rpc.requestSenderMockSender());
    try std.testing.expectError(error.NotMockSender, rpc.requestSenderMockSenderConst());
}

test "root.RequestSender mock helpers expose borrowed mock sender surface" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var request_sender = client.RequestSender.fromMockSender(&mock_sender);
    try std.testing.expect(request_sender.isMockSender());
    try std.testing.expect(!request_sender.hasMockHandler());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRequestCount());

    try request_sender.setMockHandler(.{
        .callback = timeoutMockHandler,
    });
    try std.testing.expect(request_sender.hasMockHandler());

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();
    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));

    try request_sender.clearMockHandler();
    try std.testing.expect(!request_sender.hasMockHandler());
    try request_sender.pushMockSlotResult(2701);
    try request_sender.pushMockHealthOk();
    try std.testing.expectEqual(@as(usize, 2), request_sender.mockResponseCount());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 2701), slot);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);

    try std.testing.expectEqual(@as(usize, 3), request_sender.mockRequestCount());
    try std.testing.expectEqual(@as(usize, 3), request_sender.capturedMockRequests().len);

    try request_sender.clearCapturedMockRequests();
    try std.testing.expectEqual(@as(usize, 0), request_sender.capturedMockRequests().len);
}

test "root.RequestSender mock helpers reject callback request sender" {
    var context = RequestSenderContext{ .base_slot = 2800 };
    var request_sender = client.RequestSender.init(
        &context,
        customRequestSender,
    );

    try std.testing.expect(!request_sender.isMockSender());
    try std.testing.expect(!request_sender.hasMockHandler());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRequestCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.capturedMockRequests().len);
    try std.testing.expectError(error.NotMockSender, request_sender.setMockHandler(.{
        .callback = timeoutMockHandler,
    }));
    try std.testing.expectError(error.NotMockSender, request_sender.pushMockSlotResult(1));
    try std.testing.expectError(error.NotMockSender, request_sender.pushMockRouteBuilder(
        client.MockRouteBuilder.init()
            .label("slot")
            .matchGetSlot(.processed)
            .resultJson("1")
            .once(),
    ));
    try std.testing.expectError(error.NotMockSender, request_sender.clearCapturedMockRequests());
}

test "root.RequestSender route helpers expose scripted route surface" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var request_sender = client.RequestSender.fromMockSender(&mock_sender);
    try request_sender.pushMockRouteBuilder(
        client.MockRouteBuilder.init()
            .label("finalized-slot")
            .matchGetSlot(.finalized)
            .resultJson("301")
            .once(),
    );
    try request_sender.pushMockRouteBuilders(&.{
        client.MockRouteBuilder.init()
            .label("processed-slot")
            .matchGetSlot(.processed)
            .resultJson("302")
            .once(),
        client.MockRouteBuilder.init()
            .label("health")
            .matchGetHealth()
            .resultJson("\"ok\"")
            .once(),
    });

    try std.testing.expectEqual(@as(usize, 3), request_sender.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockMatchedRouteCount());
    try std.testing.expectEqual(@as(usize, 3), request_sender.mockPendingScriptedDispatchCount());

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    const finalized_slot = try rpc.getSlot(.finalized);
    const processed_slot = try rpc.getSlot(.processed);
    const health = try rpc.getHealth();
    defer allocator.free(health);

    try std.testing.expectEqual(@as(u64, 301), finalized_slot);
    try std.testing.expectEqual(@as(u64, 302), processed_slot);
    try std.testing.expectEqualStrings("ok", health);

    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 3), request_sender.mockMatchedRouteCount());
    try std.testing.expectEqual(@as(usize, 1), request_sender.mockRouteMatchCount("finalized-slot"));
    try std.testing.expectEqual(@as(usize, 1), request_sender.mockRouteMatchCount("processed-slot"));
    try std.testing.expectEqual(@as(usize, 1), request_sender.mockRouteMatchCount("health"));
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockPendingScriptedDispatchCount());
}

test "root.mock_sender_assertions supports RequestSender" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var request_sender = client.RequestSender.fromMockSender(&mock_sender);
    try request_sender.pushMockRouteBuilder(
        client.MockRouteBuilder.init()
            .label("finalized-slot")
            .matchGetSlot(.finalized)
            .resultJson("401")
            .once(),
    );

    try mock_sender_assertions.expectMockRequestSenderPendingScriptedDispatchCount(&request_sender, 1);
    try mock_sender_assertions.expectMockRequestSenderMatchedRouteCount(&request_sender, 0);

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 401), slot);

    try mock_sender_assertions.expectMockRequestSenderRouteMatchCount(&request_sender, "finalized-slot", 1);
    try mock_sender_assertions.expectMockRequestSenderScriptSatisfied(&request_sender);
}

test "root.RequestSender queue helpers mirror common RpcClient mock response helpers" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var request_sender = client.RequestSender.fromMockSender(&mock_sender);
    try request_sender.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":311,\"id\":1}");
    try request_sender.pushMockStringResult("ok");
    try request_sender.pushMockRpcError(.{
        .code = -32031,
        .message = "mock request sender rejected request",
    });
    try request_sender.pushMockTransportError(.timeout);

    var rpc = try client.RpcClient.newWithRequestSender(allocator, request_sender);
    defer rpc.deinit();

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 311), slot);

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);

    try std.testing.expectError(error.RpcError, rpc.getHealth());
    const rpc_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32031), rpc_error.code);
    try std.testing.expectEqualStrings("mock request sender rejected request", rpc_error.message);

    try std.testing.expectError(error.Timeout, rpc.getHealth());
    try std.testing.expectEqual(@as(usize, 4), request_sender.mockRequestCount());
}

test "root.RequestSender.replaceWithBorrowedMockSender mutates RpcClient backend" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3100 };
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isCallbackRequestSenderClient());

    const sender = try rpc.requestSender();
    sender.replaceWithBorrowedMockSender(allocator, &mock_sender);
    try sender.pushMockSlotResult(3101);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 3101), slot);
}

test "root.RequestSender.replace mutates RpcClient backend back to callback sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3200 };
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();
    try mock_sender.pushSlotResult(999);

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&mock_sender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const sender = try rpc.requestSender();
    sender.replace(allocator, client.RequestSender.init(
        &context,
        customRequestSender,
    ));

    try std.testing.expect(rpc.isCallbackRequestSenderClient());
    try std.testing.expect(!rpc.isMock());
    try std.testing.expectError(error.NotMockSender, sender.pushMockSlotResult(1));

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 3201), slot);
}

test "root.RequestSender.replaceWithOwnedMockSender installs owned mock sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3300 };
    var owned_mock_sender = client.MockSender.init(allocator);
    try owned_mock_sender.pushHealthOk();

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    const sender = try rpc.requestSender();
    try sender.replaceWithOwnedMockSender(allocator, owned_mock_sender);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.RequestSender.replaceWithMockSender aliases owned mock sender replacement" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3310 };
    var owned_mock_sender = client.MockSender.init(allocator);
    try owned_mock_sender.pushSlotResult(3311);

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    const sender = try rpc.requestSender();
    try sender.replaceWithMockSender(allocator, owned_mock_sender);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 3311), slot);
}

test "root.RequestSender.initMockSender aliases owned mock sender constructor" {
    const allocator = std.testing.allocator;
    var owned_mock_sender = client.MockSender.init(allocator);
    try owned_mock_sender.pushSlotResult(3312);

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        try client.RequestSender.initMockSender(allocator, owned_mock_sender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 3312), slot);
}

test "root.RequestSender.replaceWithCallback mutates RpcClient backend to callback sender" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();
    try mock_sender.pushSlotResult(1);
    var callback_context = RequestSenderContext{ .base_slot = 3350 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&mock_sender),
    );
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());

    const sender = try rpc.requestSender();
    sender.replaceWithCallback(allocator, &callback_context, customRequestSender);

    try std.testing.expect(rpc.isCallbackRequestSenderClient());
    try std.testing.expect(!rpc.isMock());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 3351), slot);
}

test "root.RequestSender.replaceWithCallbackAndDeinit deinitializes previous callback sender" {
    const allocator = std.testing.allocator;
    var first_context = RequestSenderContext{ .base_slot = 3360 };
    var second_context = RequestSenderContext{ .base_slot = 3370 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.initWithDeinit(
            &first_context,
            customRequestSender,
            customRequestSenderDeinit,
        ),
    );
    defer rpc.deinit();

    const sender = try rpc.requestSender();
    sender.replaceWithCallbackAndDeinit(
        allocator,
        &second_context,
        customRequestSender,
        customRequestSenderDeinit,
    );

    try std.testing.expectEqual(@as(usize, 1), first_context.deinit_count);
    try std.testing.expect(rpc.isCallbackRequestSenderClient());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 3371), slot);
}

test "root.RequestSender.replaceWithMock converts callback sender to owned mock sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3380 };

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    const sender = try rpc.requestSender();
    try sender.replaceWithMock(allocator, &.{});
    try sender.pushMockSlotResult(3381);

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 3381), slot);
}

test "root.RequestSender.replaceWithMockHandler installs owned handler-backed sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3390 };
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.init(
            &context,
            customRequestSender,
        ),
    );
    defer rpc.deinit();

    const sender = try rpc.requestSender();
    try sender.replaceWithMockHandler(allocator, .{
        .context = &handler_context,
        .callback = dynamicMockHandler,
    });

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 789), slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.RequestSender mock script helpers expose pending counts and summary" {
    const allocator = std.testing.allocator;
    var mock_sender = client.MockSender.init(allocator);
    defer mock_sender.deinit();

    var request_sender = client.RequestSender.fromMockSender(&mock_sender);
    try request_sender.pushMockSlotResult(2901);
    try request_sender.pushMockHealthOk();

    try std.testing.expectEqual(@as(usize, 2), request_sender.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 2), request_sender.mockPendingScriptedDispatchCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockScriptMissCount());
    try std.testing.expect(request_sender.lastMockScriptMissRequest() == null);

    const summary = try request_sender.mockScriptSummaryAlloc(allocator);
    defer allocator.free(summary);
    try std.testing.expect(summary.len > 0);

    try request_sender.clearMockResponses();
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockResponseCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockPendingScriptedDispatchCount());

    try request_sender.clearMockRoutes();
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockMatchedRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockPersistentRouteCount());
}

test "root.RequestSender mock script helpers return inert values for callback sender" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{ .base_slot = 3000 };
    var request_sender = client.RequestSender.init(
        &context,
        customRequestSender,
    );

    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockMatchedRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockRouteMatchCount("missing"));
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockPersistentRouteCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockPendingScriptedDispatchCount());
    try std.testing.expectEqual(@as(usize, 0), request_sender.mockScriptMissCount());
    try std.testing.expect(request_sender.lastMockScriptMissRequest() == null);

    const summary = try request_sender.mockScriptSummaryAlloc(allocator);
    defer allocator.free(summary);
    try std.testing.expectEqualStrings("not a mock sender\n", summary);

    try std.testing.expectError(error.NotMockSender, request_sender.clearMockResponses());
    try std.testing.expectError(error.NotMockSender, request_sender.clearMockRoutes());
}

test "root.RequestSender.fromMockSender borrows scripted mock sender state" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();

    try sender.pushResultJson("321");

    {
        var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
            allocator,
            client.RequestSender.fromMockSender(&sender),
            .{
                .endpoint = "custom://borrowed-mock",
                .commitment = .processed,
            },
        );
        defer rpc.deinit();

        try std.testing.expect(!rpc.isMock());
        try std.testing.expect(rpc.hasRequestSender());
        try std.testing.expectEqualStrings("custom://borrowed-mock", rpc.url());
        try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);

        const slot = try rpc.getSlot(null);
        try std.testing.expectEqual(@as(u64, 321), slot);
        try std.testing.expectEqual(@as(usize, 1), sender.requestCount());
        try std.testing.expectEqualStrings("getSlot", sender.capturedRequests()[0].method);
        try std.testing.expect(std.mem.indexOf(u8, sender.capturedRequests()[0].params_json, "\"processed\"") != null);
    }

    try sender.pushResultJson("654");

    var second_rpc = try client.RpcClient.newWithRequestSender(
        allocator,
        client.RequestSender.fromMockSender(&sender),
    );
    defer second_rpc.deinit();

    const second_slot = try second_rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 654), second_slot);
    try std.testing.expectEqual(@as(usize, 2), sender.requestCount());
}

test "root.newWithBorrowedMockSender borrows scripted mock sender state" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(333);

    var rpc = try client.RpcClient.newWithBorrowedMockSender(
        allocator,
        &sender,
    );
    defer rpc.deinit();

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 333), slot);
    try std.testing.expect(!rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
    try std.testing.expectEqual(@as(usize, 1), sender.requestCount());
    try std.testing.expectEqualStrings("getSlot", sender.capturedRequests()[0].method);
}

test "root.newWithBorrowedMockSenderAndCommitment forwards default commitment" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(444);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndCommitment(
        allocator,
        &sender,
        .confirmed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 444), slot);
    try std.testing.expect(std.mem.indexOf(u8, sender.capturedRequests()[0].params_json, "\"confirmed\"") != null);
}

test "root.newWithBorrowedMockSenderAndTimeout forwards request timeout" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(445);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndTimeout(
        allocator,
        &sender,
        6_500,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 6_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, null), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 445), slot);
}

test "root.newWithBorrowedMockSenderAndTimeouts forwards both timeout values" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(446);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndTimeouts(
        allocator,
        &sender,
        7_500,
        14_500,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 7_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 14_500), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 446), slot);
}

test "root.newWithBorrowedMockSenderAndRequestSenderOptions customizes endpoint and timeouts" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(447);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndRequestSenderOptions(
        allocator,
        &sender,
        .{
            .endpoint = "custom://borrowed-options",
            .commitment = .confirmed,
            .request_timeout_ms = 9_500,
            .confirm_transaction_initial_timeout_ms = 10_500,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://borrowed-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 9_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 10_500), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 447), slot);
}

test "root.newWithBorrowedMockSenderAndCommitmentAndTimeout forwards commitment and timeout" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(444);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndCommitmentAndTimeout(
        allocator,
        &sender,
        .confirmed,
        5_000,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 5_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, null), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 444), slot);
    try std.testing.expect(std.mem.indexOf(u8, sender.capturedRequests()[0].params_json, "\"confirmed\"") != null);
}

test "root.newWithBorrowedMockSenderAndTimeoutAndCommitment preserves order and options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(555);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndTimeoutAndCommitment(
        allocator,
        &sender,
        6_000,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 6_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, null), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 555), slot);
}

test "root.newWithBorrowedMockSenderAndOptions applies all constructor options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(666);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndOptions(
        allocator,
        &sender,
        .{
            .commitment = .finalized,
            .request_timeout_ms = 8_000,
            .confirm_transaction_initial_timeout_ms = 12_000,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.finalized, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 8_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 12_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 666), slot);
    try std.testing.expect(std.mem.indexOf(u8, sender.capturedRequests()[0].params_json, "\"finalized\"") != null);
}

test "root.newWithBorrowedMockSenderAndCommitmentAndTimeouts applies all options regardless argument order" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(701);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndCommitmentAndTimeouts(
        allocator,
        &sender,
        .confirmed,
        7_000,
        12_000,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 7_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 12_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 701), slot);
}

test "root.newWithBorrowedMockSenderAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(702);

    var rpc = try client.RpcClient.newWithBorrowedMockSenderAndTimeoutsAndCommitment(
        allocator,
        &sender,
        8_000,
        13_000,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 8_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 13_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 702), slot);
}

test "root.newBorrowedMockSender aliases borrowed mock sender constructor" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(703);

    var rpc = try client.RpcClient.newBorrowedMockSender(allocator, &sender);
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 703), slot);
}

test "root.newBorrowedMockSenderAndRequestSenderOptions aliases borrowed request-sender constructor" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();
    try sender.pushSlotResult(704);

    var rpc = try client.RpcClient.newBorrowedMockSenderAndRequestSenderOptions(
        allocator,
        &sender,
        .{
            .endpoint = "custom://borrowed-mock-sender-alias",
            .commitment = .confirmed,
            .request_timeout_ms = 8_100,
            .confirm_transaction_initial_timeout_ms = 9_100,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://borrowed-mock-sender-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 8_100), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 9_100), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.confirmed);
    try std.testing.expectEqual(@as(u64, 704), slot);
}

test "root.newWithOwnedMockSenderAndRequestSenderOptions customizes endpoint and timeouts" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(891);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndRequestSenderOptions(
        allocator,
        sender,
        .{
            .endpoint = "custom://owned-options",
            .commitment = .processed,
            .request_timeout_ms = 6_500,
            .confirm_transaction_initial_timeout_ms = 7_500,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://owned-options", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 6_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 7_500), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 891), slot);
}

test "root.newWithOwnedMockSender transfers ownership of scripted sender state" {
    const allocator = std.testing.allocator;

    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newWithOwnedMockSender(
        allocator,
        sender,
    );
    defer rpc.deinit();

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
    try std.testing.expect(!rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());
}

test "root.newWithOwnedMockSenderAndCommitment forwards default commitment" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(888);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndCommitment(
        allocator,
        sender,
        .processed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 888), slot);
}

test "root.newWithOwnedMockSenderAndTimeout forwards request timeout" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(889);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndTimeout(
        allocator,
        sender,
        8_500,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 8_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, null), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 889), slot);
}

test "root.newWithOwnedMockSenderAndTimeouts forwards both timeout values" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(890);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndTimeouts(
        allocator,
        sender,
        8_900,
        16_900,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(@as(?u64, 8_900), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 16_900), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 890), slot);
}

test "root.newWithOwnedMockSenderAndCommitmentAndTimeouts forwards all options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(777);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndCommitmentAndTimeouts(
        allocator,
        sender,
        .confirmed,
        7_000,
        15_000,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 7_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 15_000), rpc.getConfirmTransactionInitialTimeoutMs());
    try std.testing.expect(!rpc.isMock());
    try std.testing.expect(rpc.hasRequestSender());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 777), slot);
}

test "root.newWithOwnedMockSenderAndTimeoutsAndCommitment preserves timeout-first alias semantics" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(888);

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndTimeoutsAndCommitment(
        allocator,
        sender,
        4_500,
        6_500,
        .confirmed,
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.confirmed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 4_500), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 6_500), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 888), slot);
}

test "root.newWithOwnedMockSenderAndOptions applies all constructor options" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushHealthOk();

    var rpc = try client.RpcClient.newWithOwnedMockSenderAndOptions(
        allocator,
        sender,
        .{
            .commitment = .processed,
            .request_timeout_ms = 9_000,
            .confirm_transaction_initial_timeout_ms = 10_000,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 9_000), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 10_000), rpc.getConfirmTransactionInitialTimeoutMs());

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.newOwnedMockSender aliases owned mock sender constructor" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(8891);

    var rpc = try client.RpcClient.newOwnedMockSender(allocator, sender);
    defer rpc.deinit();

    try std.testing.expect(rpc.isRequestSenderBackedMockClient());
    try std.testing.expect(rpc.isMock());

    const slot = try rpc.getSlot(null);
    try std.testing.expectEqual(@as(u64, 8891), slot);
}

test "root.newOwnedMockSenderAndRequestSenderOptions aliases owned request-sender constructor" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    try sender.pushSlotResult(8892);

    var rpc = try client.RpcClient.newOwnedMockSenderAndRequestSenderOptions(
        allocator,
        sender,
        .{
            .endpoint = "custom://owned-mock-sender-alias",
            .commitment = .processed,
            .request_timeout_ms = 8_200,
            .confirm_transaction_initial_timeout_ms = 9_200,
        },
    );
    defer rpc.deinit();

    try std.testing.expectEqualStrings("custom://owned-mock-sender-alias", rpc.url());
    try std.testing.expectEqual(client.Commitment.processed, rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 8_200), rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 9_200), rpc.getConfirmTransactionInitialTimeoutMs());

    const slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 8892), slot);
}

test "root.RequestSender.fromOwnedMockSender supports scripted sender replacement" {
    const allocator = std.testing.allocator;
    var replacement_context = RequestSenderContext{ .base_slot = 800 };
    var scripted_sender = client.MockSender.init(allocator);
    try scripted_sender.pushResultRoute(.{
        .method = "getSlot",
        .params_json_contains = "\"finalized\"",
    }, "777", 1);

    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        try client.RequestSender.fromOwnedMockSender(allocator, scripted_sender),
        .{
            .endpoint = "custom://owned-mock",
        },
    );
    defer rpc.deinit();

    const scripted_slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 777), scripted_slot);
    try std.testing.expect(rpc.hasRequestSender());

    try rpc.replaceRequestSender(
        client.RequestSender.initWithDeinit(
            &replacement_context,
            customRequestSender,
            customRequestSenderDeinit,
        ),
    );

    const replacement_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 801), replacement_slot);
    try std.testing.expectEqual(@as(usize, 1), replacement_context.call_count);
}

test "root.RequestSender.init accepts raw context + callback pair" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 900,
        .error_code = -32030,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSender(
            allocator,
            client.RequestSender.init(
                &context,
                customRequestSender,
            ),
        );
        defer rpc.deinit();

        const slot = try rpc.getSlot(.confirmed);
        try std.testing.expectEqual(@as(u64, 901), slot);
        try std.testing.expect(context.saw_confirmed_commitment);
        try std.testing.expect(context.call_count > 0);
        try std.testing.expectError(error.RpcError, rpc.getBalance("Address11111111111111111111111111111111", null));
    }

    try std.testing.expectEqual(@as(usize, 0), context.deinit_count);
}

test "root.RequestSender.initWithDeinit runs deinit callback" {
    const allocator = std.testing.allocator;
    var context = RequestSenderContext{
        .base_slot = 1000,
        .error_code = -32031,
    };

    {
        var rpc = try client.RpcClient.newWithRequestSender(
            allocator,
            client.RequestSender.initWithDeinit(
                &context,
                customRequestSender,
                customRequestSenderDeinit,
            ),
        );
        defer rpc.deinit();

        const slot = try rpc.getSlot(.processed);
        try std.testing.expectEqual(@as(u64, 1001), slot);
        try std.testing.expectEqual(@as(usize, 1), context.call_count);
    }

    try std.testing.expectEqual(@as(usize, 1), context.deinit_count);
}

test "root.MockSender tracks pending scripted dispatches and persistent routes" {
    const allocator = std.testing.allocator;
    var sender = client.MockSender.init(allocator);
    defer sender.deinit();

    try sender.pushResultJson("123");
    try sender.pushResultJson("456");
    try sender.pushResultRoute(.{
        .method = "getHealth",
    }, "\"ok\"", 3);
    try sender.pushPersistentRpcErrorRoute(.{
        .method = "getSlot",
    }, .{
        .code = -32022,
        .message = "slot unavailable",
    });

    try mock_sender_assertions.expectMockSenderPendingScriptedDispatchCount(&sender, 5);
    try std.testing.expectEqual(@as(usize, 1), sender.persistentRouteCount());
    try mock_sender_assertions.expectMockSenderMatchedRouteCount(&sender, 0);
}

test "root.MockRouteBuilder builds matcher fields and requires a response" {
    const route = try client.MockRouteBuilder.init()
        .label("body-match")
        .matchSendTransaction()
        .paramsJsonContains("\"base64\"")
        .requestBodyContains("\"id\":9")
        .transportError(.http_error)
        .uses(2)
        .build();

    try std.testing.expectEqualStrings("body-match", route.label.?);
    try std.testing.expectEqualStrings("sendTransaction", route.matcher.method.?);
    try std.testing.expectEqualStrings("\"base64\"", route.matcher.params_json_contains.?);
    try std.testing.expectEqualStrings("\"id\":9", route.matcher.request_body_contains.?);
    try std.testing.expectEqual(@as(?usize, 2), route.remaining_uses);
    try std.testing.expect(route.response == .transport_error);
    try std.testing.expectEqual(client.MockTransportError.http_error, route.response.transport_error);

    const rpc_route = try client.MockRouteBuilder.init()
        .label("slot-finalized")
        .matchGetSlot(.finalized)
        .resultJson("999")
        .once()
        .build();
    try std.testing.expectEqualStrings("getSlot", rpc_route.matcher.method.?);
    try std.testing.expectEqualStrings("finalized", rpc_route.matcher.params_json_contains.?);

    try std.testing.expectError(
        error.MockRouteResponseRequired,
        client.MockRouteBuilder.init()
            .matchGetSlot(null)
            .once()
            .build(),
    );
}

test "root.MockRouteBuilder adds common rpc request matchers" {
    const finalized_route = try client.MockRouteBuilder.init()
        .matchGetBlock(.finalized)
        .resultJson("{}")
        .build();

    const processed_route = try client.MockRouteBuilder.init()
        .matchGetBalance(.processed)
        .resultJson("{}")
        .build();

    const account_route = try client.MockRouteBuilder.init()
        .matchGetAccountInfo(null)
        .resultJson("{}")
        .build();

    const signature_statuses_route = try client.MockRouteBuilder.init()
        .matchGetSignatureStatuses(null)
        .resultJson("{}")
        .build();

    const signature_for_address_route = try client.MockRouteBuilder.init()
        .matchGetSignaturesForAddress(null)
        .resultJson("{}")
        .build();

    const transaction_route = try client.MockRouteBuilder.init()
        .matchGetTransaction(null)
        .resultJson("{}")
        .build();

    const slot_leaders_route = try client.MockRouteBuilder.init()
        .matchGetSlotLeaders()
        .resultJson("[]")
        .build();

    const airdrop_route = try client.MockRouteBuilder.init()
        .matchRequestAirdrop()
        .resultJson("\"signature\"")
        .build();

    const identity_route = try client.MockRouteBuilder.init()
        .matchGetIdentity()
        .resultJson("{\"identity\":\"ABC\"}")
        .build();

    const version_route = try client.MockRouteBuilder.init()
        .matchGetVersion()
        .resultJson("\"test-version\"")
        .build();

    const supply_route = try client.MockRouteBuilder.init()
        .matchGetSupply()
        .resultJson("{\"context\":{\"slot\":1},\"value\":{}}")
        .build();

    const epoch_info_route = try client.MockRouteBuilder.init()
        .matchGetEpochInfo()
        .resultJson("{}")
        .build();

    const slot_leader_route = try client.MockRouteBuilder.init()
        .matchGetSlotLeader()
        .resultJson("\"slotLeader\"")
        .build();
    const latest_performance_samples_route = try client.MockRouteBuilder.init()
        .matchGetRecentPerformanceSamples()
        .resultJson("[]")
        .build();
    const token_supply_route = try client.MockRouteBuilder.init()
        .matchGetTokenSupply()
        .resultJson("{\"context\":{\"slot\":2},\"value\":{}}")
        .build();
    try std.testing.expectEqualStrings("getBlock", finalized_route.matcher.method.?);
    try std.testing.expectEqualStrings("finalized", finalized_route.matcher.params_json_contains.?);
    try std.testing.expectEqualStrings("getBalance", processed_route.matcher.method.?);
    try std.testing.expectEqualStrings("processed", processed_route.matcher.params_json_contains.?);
    try std.testing.expectEqualStrings("getAccountInfo", account_route.matcher.method.?);
    try std.testing.expectEqualStrings("getSignatureStatuses", signature_statuses_route.matcher.method.?);
    try std.testing.expectEqualStrings("getSignaturesForAddress", signature_for_address_route.matcher.method.?);
    try std.testing.expectEqualStrings("getTransaction", transaction_route.matcher.method.?);
    try std.testing.expectEqualStrings("getSlotLeaders", slot_leaders_route.matcher.method.?);
    try std.testing.expectEqualStrings("requestAirdrop", airdrop_route.matcher.method.?);
    try std.testing.expectEqualStrings("getIdentity", identity_route.matcher.method.?);
    try std.testing.expectEqualStrings("getVersion", version_route.matcher.method.?);
    try std.testing.expectEqualStrings("getSupply", supply_route.matcher.method.?);
    try std.testing.expectEqualStrings("getEpochInfo", epoch_info_route.matcher.method.?);
    try std.testing.expectEqualStrings("getSlotLeader", slot_leader_route.matcher.method.?);
    try std.testing.expectEqualStrings("minimumLedgerSlot", (try client.MockRouteBuilder.init()
        .matchGetMinimumLedgerSlot()
        .resultJson("0")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getLeaderSchedule", (try client.MockRouteBuilder.init()
        .matchGetLeaderSchedule()
        .resultJson("{}")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getGenesisHash", (try client.MockRouteBuilder.init()
        .matchGetGenesisHash()
        .resultJson("\"hash\"")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getHighestSnapshotSlot", (try client.MockRouteBuilder.init()
        .matchGetHighestSnapshotSlot()
        .resultJson("0")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getEpochSchedule", (try client.MockRouteBuilder.init()
        .matchGetEpochSchedule()
        .resultJson("{}")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getTransactionCount", (try client.MockRouteBuilder.init()
        .matchGetTransactionCount()
        .resultJson("0")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getRecentPerformanceSamples", latest_performance_samples_route.matcher.method.?);
    try std.testing.expectEqualStrings("getTokenSupply", token_supply_route.matcher.method.?);
    try std.testing.expectEqualStrings("getBlocksWithLimit", (try client.MockRouteBuilder.init()
        .matchGetBlocksWithLimit()
        .resultJson("[]")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getBlockCommitment", (try client.MockRouteBuilder.init()
        .matchGetBlockCommitment()
        .resultJson("{}")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getInflationRate", (try client.MockRouteBuilder.init()
        .matchGetInflationRate()
        .resultJson("{}")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("simulateTransaction", (try client.MockRouteBuilder.init()
        .matchSimulateTransaction()
        .resultJson("{}")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("isBlockhashValid", (try client.MockRouteBuilder.init()
        .matchIsBlockhashValid()
        .resultJson("true")
        .build()).matcher.method.?);
    try std.testing.expectEqualStrings("getVoteAccounts", (try client.MockRouteBuilder.init()
        .matchGetVoteAccounts()
        .resultJson("[]")
        .build()).matcher.method.?);
    try std.testing.expect(airdrop_route.matcher.params_json_contains == null);
}

test "root.mock routes match by method and params fragment" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandler(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
    );
    defer rpc.deinit();

    try rpc.pushMockResultRoute(.{
        .method = "getSlot",
        .params_json_contains = "\"finalized\"",
    }, "999", 1);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());

    const finalized_slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 999), finalized_slot);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), handler_context.call_count);

    const processed_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 456), processed_slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
}

test "root.mock route helpers expose match counts and pending scripted dispatches" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockRoute(try client.MockRouteBuilder.init()
        .label("finalized-slot")
        .matchGetSlot(.finalized)
        .resultJson("111")
        .once()
        .build());
    try rpc.pushMockRoute(try client.MockRouteBuilder.init()
        .label("processed-timeout")
        .matchGetSlot(.processed)
        .transportError(.timeout)
        .uses(2)
        .build());
    try rpc.pushMockRoute(try client.MockRouteBuilder.init()
        .label("health-error")
        .matchGetHealth()
        .rpcError(.{
            .code = -32012,
            .message = "health unavailable",
        })
        .persistent()
        .build());

    try std.testing.expectEqual(@as(usize, 3), rpc.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockPersistentRouteCount());
    try mock_sender_assertions.expectMockRpcPendingScriptedDispatchCount(&rpc, 3);
    try mock_sender_assertions.expectMockRpcMatchedRouteCount(&rpc, 0);

    const finalized_slot = try rpc.getSlot(.finalized);
    try std.testing.expectEqual(@as(u64, 111), finalized_slot);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRouteCount());
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "finalized-slot", 1);
    try mock_sender_assertions.expectMockRpcMatchedRouteCount(&rpc, 1);
    try mock_sender_assertions.expectMockRpcPendingScriptedDispatchCount(&rpc, 2);

    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRouteCount());
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "processed-timeout", 1);
    try mock_sender_assertions.expectMockRpcMatchedRouteCount(&rpc, 2);
    try mock_sender_assertions.expectMockRpcPendingScriptedDispatchCount(&rpc, 1);

    try std.testing.expectError(error.Timeout, rpc.getSlot(.processed));
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "processed-timeout", 2);
    try mock_sender_assertions.expectMockRpcMatchedRouteCount(&rpc, 3);
    try mock_sender_assertions.expectMockRpcScriptExhausted(&rpc);

    try std.testing.expectError(error.RpcError, rpc.getHealth());
    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32012), last_error.code);
    try std.testing.expectEqualStrings("health unavailable", last_error.message);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 1), rpc.mockPersistentRouteCount());
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "health-error", 1);
    try mock_sender_assertions.expectMockRpcMatchedRouteCount(&rpc, 4);
    try mock_sender_assertions.expectMockRpcScriptExhausted(&rpc);

    const script_summary = try rpc.mockScriptSummaryAlloc(allocator);
    defer allocator.free(script_summary);
    try std.testing.expect(std.mem.indexOf(u8, script_summary, "health-error: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, script_summary, "remaining_routes:") != null);
}

test "root.MockRouteBuilder can be pushed directly as a mock route" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockRouteBuilder(
        client.MockRouteBuilder.init()
            .label("finalized-slot")
            .matchGetSlot(.finalized)
            .resultJson("111")
            .once(),
    );

    try rpc.pushMockRouteBuilders(&.{
        client.MockRouteBuilder.init()
            .label("processed-slot")
            .matchGetSlot(.processed)
            .resultJson("222")
            .once(),
        client.MockRouteBuilder.init()
            .label("health")
            .matchGetHealth()
            .resultJson("\"ok\"")
            .once(),
    });

    const finalized_slot = try rpc.getSlot(.finalized);
    const processed_slot = try rpc.getSlot(.processed);
    const health = try rpc.getHealth();
    defer allocator.free(health);

    try std.testing.expectEqual(@as(u64, 111), finalized_slot);
    try std.testing.expectEqual(@as(u64, 222), processed_slot);
    try std.testing.expectEqualStrings("ok", health);

    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "finalized-slot", 1);
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "processed-slot", 1);
    try mock_sender_assertions.expectMockRpcRouteMatchCount(&rpc, "health", 1);
    try mock_sender_assertions.expectMockRpcPendingScriptedDispatchCount(&rpc, 0);
}

test "root.mock routes can be reused and cleared explicitly" {
    const allocator = std.testing.allocator;

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockRpcErrorRoute(.{
        .method = "getHealth",
    }, .{
        .code = -32009,
        .message = "health unavailable",
        .data_json = "{\"reason\":\"warming_up\"}",
    }, null);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());

    try std.testing.expectError(error.RpcError, rpc.getHealth());
    var last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32009), last_error.code);
    try std.testing.expectEqualStrings("health unavailable", last_error.message);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());

    try std.testing.expectError(error.RpcError, rpc.getHealth());
    last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32009), last_error.code);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());

    rpc.clearMockRoutes();
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRouteCount());
    try std.testing.expectError(error.MockResponseExhausted, rpc.getHealth());
}

test "root.mock transport prefers queue then route then handler" {
    const allocator = std.testing.allocator;
    var handler_context = MockHandlerContext{};

    var rpc = try client.RpcClient.newMockWithHandler(
        allocator,
        .{
            .context = &handler_context,
            .callback = dynamicMockHandler,
        },
    );
    defer rpc.deinit();

    try rpc.pushMockResultRoute(.{
        .method = "getSlot",
        .params_json_contains = "\"processed\"",
    }, "333", 1);
    try rpc.pushMockResultJson("111");

    const queued_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 111), queued_slot);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), handler_context.call_count);
    try mock_sender_assertions.expectMockRpcNoScriptMisses(&rpc);

    const routed_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 333), routed_slot);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRouteCount());
    try std.testing.expectEqual(@as(usize, 0), handler_context.call_count);
    try mock_sender_assertions.expectMockRpcNoScriptMisses(&rpc);

    const handled_slot = try rpc.getSlot(.processed);
    try std.testing.expectEqual(@as(u64, 456), handled_slot);
    try std.testing.expectEqual(@as(usize, 1), handler_context.call_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockScriptMissCount());
    try mock_sender_assertions.expectMockRpcLastScriptMissMethod(&rpc, "getSlot");
}
