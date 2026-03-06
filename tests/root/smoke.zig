const std = @import("std");
const client = @import("solana_client_zig");
const root_test_support = @import("root_test_support");

const runMockRootServer = root_test_support.runMockRootServer;
const runMockRootServerCaptureSequence = root_test_support.runMockRootServerCaptureSequence;

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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":123,"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.newWithCommitment(allocator, rpc_url, .finalized);
    defer rpc.deinit();

    _ = try rpc.getSlot(null);

    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getSlot\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"finalized\"") != null);
}

test "root.getTransportStats tracks request metrics" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":123,"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":123,"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const response = try rpc.sendRaw("getSlot", .{.{ .commitment = "finalized" }});
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"result\":123") != null);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getSlot\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"finalized\"") != null);
}

test "root.sendJsonRpc parses typed result and keeps owned slices alive" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"solana-core":"2.1.0"},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const VersionResult = struct {
        @"solana-core": []const u8 = "",
    };

    var result = try rpc.sendJsonRpc("getVersion", .{}, VersionResult);
    defer result.deinit();

    try std.testing.expectEqualStrings("2.1.0", result.value.@"solana-core");
    try std.testing.expect(std.mem.indexOf(u8, result.response_body, "\"solana-core\":\"2.1.0\"") != null);
}

test "root.sendTyped uses RpcRequest helpers" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"ok","id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    var result = try rpc.sendTyped(client.RpcRequest.getHealth, .{}, []const u8);
    defer result.deinit();

    try std.testing.expectEqualStrings("ok", result.value);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getHealth\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"params\":[]") != null);
}
