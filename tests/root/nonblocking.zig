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

test "root.NonblockingRpcClient getBalanceAsync returns waitable balance response" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":55},\"value\":444},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getBalanceAsync(.processed);
    try std.testing.expect(!task.isDone());

    const balance = try task.wait();
    try std.testing.expectEqual(@as(u64, 55), balance.context_slot);
    try std.testing.expectEqual(@as(u64, 444), balance.value);
}

test "root.NonblockingRpcClient getBlockTimeAsync returns waitable block time" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":123456789,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getBlockTimeAsync();
    try std.testing.expect(!task.isDone());

    const block_time = try task.wait();
    try std.testing.expectEqual(@as(?i64, 123456789), block_time);
}

test "root.NonblockingRpcClient getHealthAsync returns owned health string" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":\"ok\",\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getHealthAsync();
    try std.testing.expect(!task.isDone());

    const health = try task.wait();
    defer allocator.free(health);
    try std.testing.expectEqualStrings("ok", health);
}

test "root.NonblockingRpcClient getTransactionCountAsync returns waitable count" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":777,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTransactionCountAsync(.processed);
    try std.testing.expect(!task.isDone());

    const transaction_count = try task.wait();
    try std.testing.expectEqual(@as(u64, 777), transaction_count);
}

test "root.NonblockingRpcClient getFirstAvailableBlockAsync returns waitable slot" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":888,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getFirstAvailableBlockAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const first_available_block = try task.wait();
    try std.testing.expectEqual(@as(u64, 888), first_available_block);
}

test "root.NonblockingRpcClient getStakeMinimumDelegationAsync returns waitable lamports" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":999,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.newWithCommitment(allocator, endpoint, .finalized);
    defer rpc.deinit();

    const task = try rpc.getStakeMinimumDelegationAsync(null);
    try std.testing.expect(!task.isDone());

    const stake_minimum_delegation = try task.wait();
    try std.testing.expectEqual(@as(u64, 999), stake_minimum_delegation);
}

test "root.NonblockingRpcClient getEpochInfoAsync returns waitable epoch info" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":11},\"value\":{\"absoluteSlot\":101,\"blockHeight\":202,\"epoch\":3,\"slotIndex\":4,\"slotsInEpoch\":5}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getEpochInfoAsync(.processed);
    try std.testing.expect(!task.isDone());

    const epoch_info = try task.wait();
    try std.testing.expectEqual(@as(?u64, 101), epoch_info.absolute_slot);
    try std.testing.expectEqual(@as(?u64, 202), epoch_info.block_height);
    try std.testing.expectEqual(@as(?u64, 3), epoch_info.epoch);
    try std.testing.expectEqual(@as(?u64, 4), epoch_info.slot_index);
    try std.testing.expectEqual(@as(?u64, 5), epoch_info.slots_in_epoch);
}

test "root.NonblockingRpcClient getSlotLeaderAsync returns owned leader" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":\"Leader11111111111111111111111111111111111\",\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getSlotLeaderAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const slot_leader = try task.wait();
    defer allocator.free(slot_leader);
    try std.testing.expectEqualStrings("Leader11111111111111111111111111111111111", slot_leader);
}

test "root.NonblockingRpcClient getVersionAsync returns owned version string" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"solana-core\":\"2.1.0\"},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getVersionAsync();
    try std.testing.expect(!task.isDone());

    const version = try task.wait();
    defer allocator.free(version);
    try std.testing.expectEqualStrings("2.1.0", version);
}

test "root.NonblockingRpcClient getMinimumLedgerSlotAsync returns waitable slot" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":1001,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMinimumLedgerSlotAsync();
    try std.testing.expect(!task.isDone());

    const minimum_ledger_slot = try task.wait();
    try std.testing.expectEqual(@as(u64, 1001), minimum_ledger_slot);
}

test "root.NonblockingRpcClient getMaxRetransmitSlotAsync returns waitable slot" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":1002,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMaxRetransmitSlotAsync();
    try std.testing.expect(!task.isDone());

    const max_retransmit_slot = try task.wait();
    try std.testing.expectEqual(@as(u64, 1002), max_retransmit_slot);
}

test "root.NonblockingRpcClient getMaxShredInsertSlotAsync returns waitable slot" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":1003,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMaxShredInsertSlotAsync();
    try std.testing.expect(!task.isDone());

    const max_shred_insert_slot = try task.wait();
    try std.testing.expectEqual(@as(u64, 1003), max_shred_insert_slot);
}

test "root.NonblockingRpcClient getLatestBlockhashResponseAsync returns owned response" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":77},\"value\":{\"blockhash\":\"resp-abc\",\"lastValidBlockHeight\":1234}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLatestBlockhashResponseAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const latest_response = try task.wait();
    defer allocator.free(latest_response.value.blockhash);
    try std.testing.expectEqual(@as(u64, 77), latest_response.context_slot);
    try std.testing.expectEqualStrings("resp-abc", latest_response.value.blockhash);
    try std.testing.expectEqual(@as(u64, 1234), latest_response.value.last_valid_block_height);
}

test "root.NonblockingRpcClient getEpochScheduleAsync returns waitable schedule" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"firstNormalSlot\":10,\"firstNormalEpoch\":20,\"leaderScheduleSlotOffset\":30,\"slotsPerEpoch\":40,\"warmup\":true},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getEpochScheduleAsync();
    try std.testing.expect(!task.isDone());

    const epoch_schedule = try task.wait();
    try std.testing.expectEqual(@as(u64, 10), epoch_schedule.first_normal_slot);
    try std.testing.expectEqual(@as(u64, 20), epoch_schedule.first_normal_epoch);
    try std.testing.expectEqual(@as(u64, 30), epoch_schedule.leader_schedule_slot_offset);
    try std.testing.expectEqual(@as(u64, 40), epoch_schedule.slots_per_epoch);
    try std.testing.expect(epoch_schedule.warmup);
}

test "root.NonblockingRpcClient getIdentityAsync returns owned identity string" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"identity\":\"Identity1111111111111111111111111111111111\"},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getIdentityAsync();
    try std.testing.expect(!task.isDone());

    const identity = try task.wait();
    defer allocator.free(identity);
    try std.testing.expectEqualStrings("Identity1111111111111111111111111111111111", identity);
}

test "root.NonblockingRpcClient getFeatureActivationSlotAsync returns optional slot" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":4242,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getFeatureActivationSlotAsync(.processed);
    try std.testing.expect(!task.isDone());

    const activation_slot = try task.wait();
    try std.testing.expectEqual(@as(?u64, 4242), activation_slot);
}

test "root.NonblockingRpcClient getNewLatestBlockhashAsync returns owned new blockhash" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":88},\"value\":{\"blockhash\":\"new-blockhash\",\"lastValidBlockHeight\":555}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getNewLatestBlockhashAsync();
    try std.testing.expect(!task.isDone());

    const blockhash = try task.wait();
    defer allocator.free(blockhash);
    try std.testing.expectEqualStrings("new-blockhash", blockhash);
}
