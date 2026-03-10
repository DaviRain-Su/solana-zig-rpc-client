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

fn runDelayedRootServerAndCheckBodyContains(
    listener: *std.net.Server,
    allocator: std.mem.Allocator,
    delay_ms: u64,
    expected_fragment: []const u8,
    matched: *bool,
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

    matched.* = std.mem.indexOf(u8, request_body, expected_fragment) != null;

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

fn freeSupply(allocator: std.mem.Allocator, supply: client.Supply) void {
    if (supply.non_circulating_accounts) |accounts| {
        for (accounts) |account| allocator.free(account);
        allocator.free(accounts);
    }
}

fn freeLargestAccounts(allocator: std.mem.Allocator, accounts: []client.LargestAccount) void {
    for (accounts) |account| allocator.free(account.address);
    allocator.free(accounts);
}

fn freeTokenAmount(allocator: std.mem.Allocator, amount: client.TokenAmount) void {
    allocator.free(amount.amount);
    allocator.free(amount.ui_amount_string);
}

fn freeClusterNodes(allocator: std.mem.Allocator, nodes: []client.ClusterNode) void {
    for (nodes) |node| {
        if (node.gossip) |value| allocator.free(value);
        allocator.free(node.pubkey);
        if (node.rpc) |value| allocator.free(value);
        if (node.tpu) |value| allocator.free(value);
        if (node.version) |value| allocator.free(value);
    }
    allocator.free(nodes);
}

fn freeVoteAccounts(allocator: std.mem.Allocator, vote_accounts: client.VoteAccounts) void {
    for (vote_accounts.current) |account| {
        allocator.free(account.vote_pubkey);
        allocator.free(account.node_pubkey);
        if (account.epoch_credits) |credits| allocator.free(credits);
    }
    allocator.free(vote_accounts.current);

    for (vote_accounts.delinquent) |account| {
        allocator.free(account.vote_pubkey);
        allocator.free(account.node_pubkey);
        if (account.epoch_credits) |credits| allocator.free(credits);
    }
    allocator.free(vote_accounts.delinquent);
}

fn freeLeaderSchedule(allocator: std.mem.Allocator, schedule: []client.LeaderSchedule) void {
    for (schedule) |entry| {
        allocator.free(entry.identity);
        allocator.free(entry.slots);
    }
    allocator.free(schedule);
}

fn freeBlockProduction(allocator: std.mem.Allocator, production: client.BlockProduction) void {
    for (production.by_identity) |entry| {
        allocator.free(entry.identity);
    }
    allocator.free(production.by_identity);
}

fn freeStringList(allocator: std.mem.Allocator, values: [][]const u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
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

test "root.NonblockingRpcClient getBalanceForAddressAsync sends requested address" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const address = "BalanceCustom111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        address,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":66},\"value\":777},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getBalanceForAddressAsync(address, .confirmed);
    try std.testing.expect(!task.isDone());

    const balance = try task.wait();
    try std.testing.expectEqual(@as(u64, 66), balance.context_slot);
    try std.testing.expectEqual(@as(u64, 777), balance.value);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getTokenAccountBalanceAsync sends requested token account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const token_account = "TokenAcct77777777777777777777777777777777777";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        token_account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":77},\"value\":{\"amount\":\"12345\",\"decimals\":6,\"uiAmount\":0.012345,\"uiAmountString\":\"0.012345\"}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTokenAccountBalanceAsync(token_account, .processed);
    try std.testing.expect(!task.isDone());

    const amount = try task.wait();
    defer freeTokenAmount(allocator, amount);

    try std.testing.expectEqualStrings("12345", amount.amount);
    try std.testing.expectEqual(@as(u8, 6), amount.decimals);
    try std.testing.expectEqual(@as(?f64, 0.012345), amount.ui_amount);
    try std.testing.expectEqualStrings("0.012345", amount.ui_amount_string);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getTokenSupplyAsync sends requested mint" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const mint = "Mint888888888888888888888888888888888888888";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        mint,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":88},\"value\":{\"amount\":\"5000000\",\"decimals\":6,\"uiAmount\":5.0,\"uiAmountString\":\"5\"}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTokenSupplyAsync(mint, .confirmed);
    try std.testing.expect(!task.isDone());

    const amount = try task.wait();
    defer freeTokenAmount(allocator, amount);

    try std.testing.expectEqualStrings("5000000", amount.amount);
    try std.testing.expectEqual(@as(u8, 6), amount.decimals);
    try std.testing.expectEqual(@as(?f64, 5.0), amount.ui_amount);
    try std.testing.expectEqualStrings("5", amount.ui_amount_string);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getSupplyAsync returns waitable supply" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":99},\"value\":{\"total\":1000,\"circulating\":700,\"nonCirculating\":300,\"nonCirculatingAccounts\":[\"SupplyAcct1111111111111111111111111111111\",\"SupplyAcct2222222222222222222222222222222\"]}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getSupplyAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const supply = try task.wait();
    defer freeSupply(allocator, supply);

    try std.testing.expectEqual(@as(u64, 1000), supply.total);
    try std.testing.expectEqual(@as(u64, 700), supply.circulating);
    try std.testing.expectEqual(@as(u64, 300), supply.non_circulating);
    try std.testing.expectEqual(@as(usize, 2), supply.non_circulating_accounts.?.len);
    try std.testing.expectEqualStrings("SupplyAcct1111111111111111111111111111111", supply.non_circulating_accounts.?[0]);
}

test "root.NonblockingRpcClient getLargestAccountsAsync returns waitable largest accounts" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        "getLargestAccounts",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":[{\"address\":\"Largest11111111111111111111111111111111111\",\"lamports\":999},{\"address\":\"Largest22222222222222222222222222222222222\",\"lamports\":555}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLargestAccountsAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const largest_accounts = try task.wait();
    defer freeLargestAccounts(allocator, largest_accounts);

    try std.testing.expectEqual(@as(usize, 2), largest_accounts.len);
    try std.testing.expectEqualStrings("Largest11111111111111111111111111111111111", largest_accounts[0].address);
    try std.testing.expectEqual(@as(u64, 999), largest_accounts[0].lamports);
    try std.testing.expectEqualStrings("Largest22222222222222222222222222222222222", largest_accounts[1].address);
    try std.testing.expectEqual(@as(u64, 555), largest_accounts[1].lamports);
    try std.testing.expect(matched);
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

test "root.NonblockingRpcClient getBlockTimeForSlotAsync sends requested slot" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        "\"params\":[999]",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":999999,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getBlockTimeForSlotAsync(999);
    try std.testing.expect(!task.isDone());

    const block_time = try task.wait();
    try std.testing.expectEqual(@as(?i64, 999999), block_time);
    try std.testing.expect(matched);
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

test "root.NonblockingRpcClient getClusterNodesAsync returns waitable cluster nodes" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":[{\"featureSet\":1,\"gossip\":\"127.0.0.1:1234\",\"pubkey\":\"Node1111111111111111111111111111111111111\",\"rpc\":\"127.0.0.1:8899\",\"shredVersion\":2,\"tpu\":\"127.0.0.1:9000\",\"version\":\"1.18.0\"}],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getClusterNodesAsync();
    try std.testing.expect(!task.isDone());

    const cluster_nodes = try task.wait();
    defer freeClusterNodes(allocator, cluster_nodes);

    try std.testing.expectEqual(@as(usize, 1), cluster_nodes.len);
    try std.testing.expectEqual(@as(u64, 1), cluster_nodes[0].feature_set);
    try std.testing.expectEqualStrings("Node1111111111111111111111111111111111111", cluster_nodes[0].pubkey);
    try std.testing.expectEqualStrings("127.0.0.1:1234", cluster_nodes[0].gossip.?);
    try std.testing.expectEqualStrings("127.0.0.1:8899", cluster_nodes[0].rpc.?);
    try std.testing.expectEqualStrings("127.0.0.1:9000", cluster_nodes[0].tpu.?);
    try std.testing.expectEqualStrings("1.18.0", cluster_nodes[0].version.?);
}

test "root.NonblockingRpcClient getVoteAccountsAsync returns waitable vote accounts" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"current\":[{\"votePubkey\":\"Vote1111111111111111111111111111111111111\",\"nodePubkey\":\"NodeVote1111111111111111111111111111111111\",\"activatedStake\":123,\"commission\":5,\"epochCredits\":[[1,2,3]],\"lastVote\":9,\"epochVoteAccount\":true,\"rootSlot\":7}],\"delinquent\":[{\"votePubkey\":\"Vote2222222222222222222222222222222222222\",\"nodePubkey\":\"NodeVote2222222222222222222222222222222222\",\"activatedStake\":456,\"commission\":8,\"epochCredits\":null,\"lastVote\":11,\"epochVoteAccount\":false,\"rootSlot\":null}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getVoteAccountsAsync();
    try std.testing.expect(!task.isDone());

    const vote_accounts = try task.wait();
    defer freeVoteAccounts(allocator, vote_accounts);

    try std.testing.expectEqual(@as(usize, 1), vote_accounts.current.len);
    try std.testing.expectEqual(@as(usize, 1), vote_accounts.delinquent.len);
    try std.testing.expectEqualStrings("Vote1111111111111111111111111111111111111", vote_accounts.current[0].vote_pubkey);
    try std.testing.expectEqual(@as(u64, 123), vote_accounts.current[0].activated_stake);
    try std.testing.expect(vote_accounts.current[0].epoch_vote_account);
    try std.testing.expectEqual(@as(usize, 1), vote_accounts.current[0].epoch_credits.?.len);
    try std.testing.expectEqual(@as(u64, 1), vote_accounts.current[0].epoch_credits.?[0].epoch);
    try std.testing.expectEqualStrings("Vote2222222222222222222222222222222222222", vote_accounts.delinquent[0].vote_pubkey);
    try std.testing.expectEqual(@as(u64, 456), vote_accounts.delinquent[0].activated_stake);
    try std.testing.expect(!vote_accounts.delinquent[0].epoch_vote_account);
    try std.testing.expect(vote_accounts.delinquent[0].epoch_credits == null);
}

test "root.NonblockingRpcClient getLeaderScheduleAsync returns waitable leader schedule" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"Leader111111111111111111111111111111111111\":[10,20,30]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLeaderScheduleAsync(.processed);
    try std.testing.expect(!task.isDone());

    const leader_schedule = try task.wait();
    defer if (leader_schedule) |value| freeLeaderSchedule(allocator, value);

    try std.testing.expect(leader_schedule != null);
    try std.testing.expectEqual(@as(usize, 1), leader_schedule.?.len);
    try std.testing.expectEqualStrings("Leader111111111111111111111111111111111111", leader_schedule.?[0].identity);
    try std.testing.expectEqual(@as(usize, 3), leader_schedule.?[0].slots.len);
    try std.testing.expectEqual(@as(u64, 10), leader_schedule.?[0].slots[0]);
    try std.testing.expectEqual(@as(u64, 30), leader_schedule.?[0].slots[2]);
}

test "root.NonblockingRpcClient getLeaderScheduleForSlotAsync sends requested slot" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        "\"params\":[444]",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"Leader444444444444444444444444444444444444\":[44,45]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLeaderScheduleForSlotAsync(444);
    try std.testing.expect(!task.isDone());

    const leader_schedule = try task.wait();
    defer if (leader_schedule) |value| freeLeaderSchedule(allocator, value);

    try std.testing.expect(leader_schedule != null);
    try std.testing.expectEqualStrings("Leader444444444444444444444444444444444444", leader_schedule.?[0].identity);
    try std.testing.expectEqual(@as(u64, 44), leader_schedule.?[0].slots[0]);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getLeaderScheduleForIdentityAsync sends requested identity" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const identity = "LeaderIdentity55555555555555555555555555555555";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        identity,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"LeaderIdentity55555555555555555555555555555555\":[55,56]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getLeaderScheduleForIdentityAsync(identity, .finalized);
    try std.testing.expect(!task.isDone());

    const leader_schedule = try task.wait();
    defer if (leader_schedule) |value| freeLeaderSchedule(allocator, value);

    try std.testing.expect(leader_schedule != null);
    try std.testing.expectEqual(@as(usize, 1), leader_schedule.?.len);
    try std.testing.expectEqualStrings(identity, leader_schedule.?[0].identity);
    try std.testing.expectEqual(@as(u64, 55), leader_schedule.?[0].slots[0]);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getBlockProductionAsync returns waitable block production" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"byIdentity\":{\"BlockProducer1111111111111111111111111111111\":[12,9]},\"range\":{\"firstSlot\":100,\"lastSlot\":120}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getBlockProductionAsync(.confirmed);
    try std.testing.expect(!task.isDone());

    const block_production = try task.wait();
    defer freeBlockProduction(allocator, block_production);

    try std.testing.expectEqual(@as(u64, 100), block_production.first_slot);
    try std.testing.expectEqual(@as(u64, 120), block_production.last_slot);
    try std.testing.expectEqual(@as(usize, 1), block_production.by_identity.len);
    try std.testing.expectEqualStrings("BlockProducer1111111111111111111111111111111", block_production.by_identity[0].identity);
    try std.testing.expectEqual(@as(u64, 12), block_production.by_identity[0].leader_slots);
    try std.testing.expectEqual(@as(u64, 9), block_production.by_identity[0].blocks);
}

test "root.NonblockingRpcClient isBlockhashValidAsync sends requested blockhash" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const blockhash = "CustomBlockhash66666666666666666666666666666666";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        blockhash,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.isBlockhashValidAsync(blockhash, .processed);
    try std.testing.expect(!task.isDone());

    const is_valid = try task.wait();
    try std.testing.expect(is_valid);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getSlotLeadersAsync sends requested range" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        "\"params\":[500,3]",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":[\"LeaderA11111111111111111111111111111111111\",\"LeaderB22222222222222222222222222222222222\"],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getSlotLeadersAsync(500, 3);
    try std.testing.expect(!task.isDone());

    const slot_leaders = try task.wait();
    defer freeStringList(allocator, slot_leaders);

    try std.testing.expectEqual(@as(usize, 2), slot_leaders.len);
    try std.testing.expectEqualStrings("LeaderA11111111111111111111111111111111111", slot_leaders[0]);
    try std.testing.expectEqualStrings("LeaderB22222222222222222222222222222222222", slot_leaders[1]);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getHighestSnapshotSlotAsync returns waitable snapshot slots" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"full\":111,\"incremental\":222},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getHighestSnapshotSlotAsync();
    try std.testing.expect(!task.isDone());

    const snapshot_slots = try task.wait();
    try std.testing.expectEqual(@as(?u64, 111), snapshot_slots.full);
    try std.testing.expectEqual(@as(?u64, 222), snapshot_slots.incremental);
}

test "root.NonblockingRpcClient getInflationRateAsync returns waitable rate" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"total\":1.1,\"validator\":2.2,\"foundation\":3.3,\"epoch\":4},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getInflationRateAsync();
    try std.testing.expect(!task.isDone());

    const inflation_rate = try task.wait();
    try std.testing.expectEqual(@as(f64, 1.1), inflation_rate.total);
    try std.testing.expectEqual(@as(f64, 2.2), inflation_rate.validator);
    try std.testing.expectEqual(@as(f64, 3.3), inflation_rate.foundation);
    try std.testing.expectEqual(@as(u64, 4), inflation_rate.epoch);
}

test "root.NonblockingRpcClient getInflationGovernorAsync returns waitable governor" {
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
        "{\"jsonrpc\":\"2.0\",\"result\":{\"foundation\":1.5,\"foundationTerm\":2.5,\"initial\":3.5,\"taper\":4.5,\"terminal\":5.5},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getInflationGovernorAsync();
    try std.testing.expect(!task.isDone());

    const inflation_governor = try task.wait();
    try std.testing.expectEqual(@as(f64, 1.5), inflation_governor.foundation);
    try std.testing.expectEqual(@as(f64, 2.5), inflation_governor.foundation_term);
    try std.testing.expectEqual(@as(f64, 3.5), inflation_governor.initial);
    try std.testing.expectEqual(@as(f64, 4.5), inflation_governor.taper);
    try std.testing.expectEqual(@as(f64, 5.5), inflation_governor.terminal);
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

test "root.NonblockingRpcClient getFeatureActivationSlotForFeatureAsync sends requested feature id" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const feature_id = "FeatureCustom11111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        feature_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":5252,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getFeatureActivationSlotForFeatureAsync(feature_id, .processed);
    try std.testing.expect(!task.isDone());

    const activation_slot = try task.wait();
    try std.testing.expectEqual(@as(?u64, 5252), activation_slot);
    try std.testing.expect(matched);
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
