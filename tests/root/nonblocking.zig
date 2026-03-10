const std = @import("std");
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

fn runDelayedRootServer(
    listener: *std.net.Server,
    allocator: std.mem.Allocator,
    delay_ms: u64,
    response_body: []const u8,
) void {
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

test "root.NonblockingRpcClient constructors initialize endpoint and options" {
    const allocator = std.testing.allocator;
    const endpoint = "http://127.0.0.1:8899";

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, rpc.url());
    try std.testing.expect(rpc.getDefaultCommitment() == null);
    try std.testing.expect(rpc.getRequestTimeoutMs() == null);
    try std.testing.expect(rpc.getConfirmTransactionInitialTimeoutMs() == null);

    var options_rpc = try client.NonblockingRpcClient.newWithOptions(allocator, .{
        .endpoint = endpoint,
        .commitment = .confirmed,
        .request_timeout_ms = 111,
        .confirm_transaction_initial_timeout_ms = 222,
    });
    defer options_rpc.deinit();
    try std.testing.expectEqualStrings(endpoint, options_rpc.url());
    try std.testing.expectEqual(client.Commitment.confirmed, options_rpc.getDefaultCommitment().?);
    try std.testing.expectEqual(@as(?u64, 111), options_rpc.getRequestTimeoutMs());
    try std.testing.expectEqual(@as(?u64, 222), options_rpc.getConfirmTransactionInitialTimeoutMs());
}

test "root.NonblockingRpcClient getSlotAsync returns waitable result independent of client lifetime" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServer, .{
        &listener,
        allocator,
        200,
        "{\"jsonrpc\":\"2.0\",\"result\":321,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.newWithTimeoutsAndCommitment(
        allocator,
        endpoint,
        1_000,
        2_000,
        .confirmed,
    );
    const task = try rpc.getSlotAsync(null);
    try std.testing.expect(!task.isDone());
    rpc.deinit();

    const slot = try task.wait();
    try std.testing.expectEqual(@as(u64, 321), slot);
}

test "root.NonblockingRpcClient getLatestBlockhashAsync returns owned blockhash" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServer, .{
        &listener,
        allocator,
        200,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":77},\"value\":{\"blockhash\":\"abc\",\"lastValidBlockHeight\":999}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLatestBlockhashAsync(.processed);
    try std.testing.expect(!task.isDone());

    const latest = try task.wait();
    defer allocator.free(latest.blockhash);
    try std.testing.expectEqualStrings("abc", latest.blockhash);
    try std.testing.expectEqual(@as(u64, 999), latest.last_valid_block_height);
}

test "root.NonblockingRpcClient getBlockHeightAsync returns waitable result" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServer, .{
        &listener,
        allocator,
        200,
        "{\"jsonrpc\":\"2.0\",\"result\":654,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.newWithCommitment(allocator, endpoint, .finalized);
    defer rpc.deinit();

    const task = try rpc.getBlockHeightAsync(null);
    try std.testing.expect(!task.isDone());

    const block_height = try task.wait();
    try std.testing.expectEqual(@as(u64, 654), block_height);
}

test "root.NonblockingRpcClient getGenesisHashAsync returns owned hash" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServer, .{
        &listener,
        allocator,
        200,
        "{\"jsonrpc\":\"2.0\",\"result\":\"Genesis1111111111111111111111111111111111\",\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getGenesisHashAsync();
    try std.testing.expect(!task.isDone());

    const genesis_hash = try task.wait();
    defer allocator.free(genesis_hash);
    try std.testing.expectEqualStrings("Genesis1111111111111111111111111111111111", genesis_hash);
}
