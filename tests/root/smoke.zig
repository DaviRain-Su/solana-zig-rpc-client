const std = @import("std");
const client = @import("solana_client_zig");

const MockHandlerContext = struct {
    call_count: usize = 0,
};

fn rpcJsonResponse(allocator: std.mem.Allocator, request_id: u64, result_json: []const u8) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

fn dynamicMockHandler(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.MockRequestView,
) !client.MockHandlerResponse {
    const context: *MockHandlerContext = @ptrCast(@alignCast(context_ptr.?));
    context.call_count += 1;

    if (std.mem.eql(u8, request.method, "getSlot")) {
        const slot: u64 = if (std.mem.indexOf(u8, request.params_json, "\"finalized\"") != null) 789 else 456;
        return .{ .json = try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"result\":{},\"id\":{}}}",
            .{ slot, request.id },
        ) };
    }

    if (std.mem.eql(u8, request.method, "getHealth")) {
        return .{ .json = try rpcJsonResponse(allocator, request.id, "\"ok\"") };
    }

    return .{ .transport_error = .http_error };
}

fn timeoutMockHandler(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.MockRequestView,
) !client.MockHandlerResponse {
    _ = context_ptr;
    _ = allocator;
    _ = request;
    return .{ .transport_error = .timeout };
}

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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
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
