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
    try sender.pushBoolResult(false);

    var rpc = try client.RpcClient.newWithOwnedMockSender(
        allocator,
        sender,
    );
    defer rpc.deinit();

    const health = try rpc.getHealth();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("false", health);
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
