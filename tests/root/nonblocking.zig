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

fn runDelayedRootServerAndCheckBodyContainsBoth(
    listener: *std.net.Server,
    allocator: std.mem.Allocator,
    delay_ms: u64,
    first_fragment: []const u8,
    second_fragment: []const u8,
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

    matched.* = std.mem.indexOf(u8, request_body, first_fragment) != null and
        std.mem.indexOf(u8, request_body, second_fragment) != null;

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

fn freeAccountInfo(allocator: std.mem.Allocator, account: client.AccountInfo) void {
    allocator.free(account.owner);
    if (account.data) |data| allocator.free(data);
    if (account.data_encoding) |encoding| allocator.free(encoding);
}

fn freeAccountInfoResponse(allocator: std.mem.Allocator, response: client.AccountInfoResponse) void {
    if (response.account) |account| freeAccountInfo(allocator, account);
}

fn freeMaybeAccountInfo(allocator: std.mem.Allocator, account: ?client.AccountInfo) void {
    if (account) |value| freeAccountInfo(allocator, value);
}

fn freeOptionalAccountInfos(allocator: std.mem.Allocator, accounts: []?client.AccountInfo) void {
    for (accounts) |account| {
        if (account) |value| freeAccountInfo(allocator, value);
    }
    allocator.free(accounts);
}

fn freeMultipleAccountsResponse(allocator: std.mem.Allocator, response: client.MultipleAccountsResponse) void {
    freeOptionalAccountInfos(allocator, response.accounts);
}

fn freeJsonParsedAccountInfo(allocator: std.mem.Allocator, account: client.JsonParsedAccountInfo) void {
    allocator.free(account.owner);
    allocator.free(account.data_json);
}

fn freeUiAccountResponse(allocator: std.mem.Allocator, response: client.UiAccountResponse) void {
    if (response.account) |account| freeJsonParsedAccountInfo(allocator, account);
}

fn freeMaybeUiAccount(allocator: std.mem.Allocator, account: ?client.JsonParsedAccountInfo) void {
    if (account) |value| freeJsonParsedAccountInfo(allocator, value);
}

fn freeOptionalUiAccounts(allocator: std.mem.Allocator, accounts: []?client.JsonParsedAccountInfo) void {
    for (accounts) |account| {
        if (account) |value| freeJsonParsedAccountInfo(allocator, value);
    }
    allocator.free(accounts);
}

fn freeMultipleUiAccountsResponse(allocator: std.mem.Allocator, response: client.MultipleUiAccountsResponse) void {
    freeOptionalUiAccounts(allocator, response.accounts);
}

fn freeProgramAccount(allocator: std.mem.Allocator, account: client.ProgramAccount) void {
    allocator.free(account.pubkey);
    freeAccountInfo(allocator, account.account);
}

fn freeProgramAccounts(allocator: std.mem.Allocator, accounts: []client.ProgramAccount) void {
    for (accounts) |account| freeProgramAccount(allocator, account);
    allocator.free(accounts);
}

fn freeProgramAccountsResponse(allocator: std.mem.Allocator, response: client.ProgramAccountsResponse) void {
    freeProgramAccounts(allocator, response.accounts);
}

fn freeJsonParsedProgramAccount(allocator: std.mem.Allocator, account: client.JsonParsedProgramAccount) void {
    allocator.free(account.pubkey);
    freeJsonParsedAccountInfo(allocator, account.account);
}

fn freeJsonParsedProgramAccounts(allocator: std.mem.Allocator, accounts: []client.JsonParsedProgramAccount) void {
    for (accounts) |account| freeJsonParsedProgramAccount(allocator, account);
    allocator.free(accounts);
}

fn freeJsonParsedProgramAccountsResponse(allocator: std.mem.Allocator, response: client.JsonParsedProgramAccountsResponse) void {
    freeJsonParsedProgramAccounts(allocator, response.accounts);
}

fn freeTokenAmount(allocator: std.mem.Allocator, amount: client.TokenAmount) void {
    allocator.free(amount.amount);
    allocator.free(amount.ui_amount_string);
}

fn freeTokenLargestAccounts(allocator: std.mem.Allocator, accounts: []client.TokenLargestAccount) void {
    for (accounts) |account| {
        allocator.free(account.address);
        freeTokenAmount(allocator, account.amount);
    }
    allocator.free(accounts);
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

test "root.NonblockingRpcClient getAccountInfoResponseAsync sends requested account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "AccountInfo9999999999999999999999999999999999";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":101},\"value\":{\"data\":[\"SGVsbG8=\",\"base64\"],\"executable\":false,\"lamports\":1234,\"owner\":\"Owner111111111111111111111111111111111111\",\"rentEpoch\":9,\"space\":5}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getAccountInfoResponseAsync(account, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeAccountInfoResponse(allocator, response);

    try std.testing.expectEqual(@as(u64, 101), response.context_slot);
    try std.testing.expect(response.account != null);
    try std.testing.expectEqual(@as(u64, 1234), response.account.?.lamports);
    try std.testing.expectEqualStrings("Owner111111111111111111111111111111111111", response.account.?.owner);
    try std.testing.expectEqualStrings("SGVsbG8=", response.account.?.data.?);
    try std.testing.expectEqualStrings("base64", response.account.?.data_encoding.?);
    try std.testing.expectEqual(@as(?u64, 9), response.account.?.rent_epoch);
    try std.testing.expectEqual(@as(?u64, 5), response.account.?.space);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getAccountInfoAsync sends requested account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "AccountInfoDirect1111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":111},\"value\":{\"data\":[\"RGlyZWN0\",\"base64\"],\"executable\":true,\"lamports\":4321,\"owner\":\"Owner222222222222222222222222222222222222\",\"rentEpoch\":8,\"space\":6}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getAccountInfoAsync(account, .processed);
    try std.testing.expect(!task.isDone());

    const info = try task.wait();
    defer freeAccountInfo(allocator, info);

    try std.testing.expectEqual(@as(u64, 4321), info.lamports);
    try std.testing.expectEqualStrings("Owner222222222222222222222222222222222222", info.owner);
    try std.testing.expectEqualStrings("RGlyZWN0", info.data.?);
    try std.testing.expectEqualStrings("base64", info.data_encoding.?);
    try std.testing.expect(info.executable);
    try std.testing.expectEqual(@as(?u64, 8), info.rent_epoch);
    try std.testing.expectEqual(@as(?u64, 6), info.space);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getAccountDataAsync returns decoded account data" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "AccountData1111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":222},\"value\":{\"data\":[\"SGVsbG8=\",\"base64\"],\"executable\":false,\"lamports\":100,\"owner\":\"OwnerData1111111111111111111111111111111111\",\"rentEpoch\":1,\"space\":5}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getAccountDataAsync(account, .confirmed);
    try std.testing.expect(!task.isDone());

    const data = try task.wait();
    defer allocator.free(data);

    try std.testing.expectEqualStrings("Hello", data);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getAccountInfoMaybeAsync returns null for missing account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "MissingAccount11111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":202},\"value\":null},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getAccountInfoMaybeAsync(account, .confirmed);
    try std.testing.expect(!task.isDone());

    const info = try task.wait();
    defer freeMaybeAccountInfo(allocator, info);

    try std.testing.expect(info == null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getMultipleAccountsResponseAsync sends requested accounts" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const accounts = [_][]const u8{
        "MultiAcct11111111111111111111111111111111111",
        "MultiAcct22222222222222222222222222222222222",
    };
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        accounts[0],
        accounts[1],
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":303},\"value\":[{\"data\":[\"QUJD\",\"base64\"],\"executable\":false,\"lamports\":10,\"owner\":\"Owner333333333333333333333333333333333333\",\"rentEpoch\":1,\"space\":3},null]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMultipleAccountsResponseAsync(&accounts, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeMultipleAccountsResponse(allocator, response);

    try std.testing.expectEqual(@as(u64, 303), response.context_slot);
    try std.testing.expectEqual(@as(usize, 2), response.accounts.len);
    try std.testing.expect(response.accounts[0] != null);
    try std.testing.expectEqual(@as(u64, 10), response.accounts[0].?.lamports);
    try std.testing.expectEqualStrings("Owner333333333333333333333333333333333333", response.accounts[0].?.owner);
    try std.testing.expectEqualStrings("QUJD", response.accounts[0].?.data.?);
    try std.testing.expect(response.accounts[1] == null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getMultipleAccountsAsync returns optional account list" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const accounts = [_][]const u8{
        "MultiDirect111111111111111111111111111111111",
        "MultiDirect222222222222222222222222222222222",
    };
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        accounts[0],
        accounts[1],
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":404},\"value\":[null,{\"data\":[\"REVG\",\"base64\"],\"executable\":true,\"lamports\":20,\"owner\":\"Owner444444444444444444444444444444444444\",\"rentEpoch\":2,\"space\":6}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMultipleAccountsAsync(&accounts, .processed);
    try std.testing.expect(!task.isDone());

    const result = try task.wait();
    defer freeOptionalAccountInfos(allocator, result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expect(result[0] == null);
    try std.testing.expect(result[1] != null);
    try std.testing.expectEqual(@as(u64, 20), result[1].?.lamports);
    try std.testing.expect(result[1].?.executable);
    try std.testing.expectEqualStrings("Owner444444444444444444444444444444444444", result[1].?.owner);
    try std.testing.expectEqualStrings("REVG", result[1].?.data.?);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getUiAccountResponseAsync sends requested account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "UiAccount11111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":505},\"value\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":77,\"owner\":\"Owner555555555555555555555555555555555555\",\"rentEpoch\":4,\"space\":165}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getUiAccountResponseAsync(account, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeUiAccountResponse(allocator, response);

    try std.testing.expectEqual(@as(u64, 505), response.context_slot);
    try std.testing.expect(response.account != null);
    try std.testing.expectEqual(@as(u64, 77), response.account.?.lamports);
    try std.testing.expectEqualStrings("Owner555555555555555555555555555555555555", response.account.?.owner);
    try std.testing.expect(std.mem.indexOf(u8, response.account.?.data_json, "spl-token") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getUiAccountAsync returns parsed account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "UiAccountDirect1111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":606},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"account\"}},\"executable\":true,\"lamports\":88,\"owner\":\"Owner666666666666666666666666666666666666\",\"rentEpoch\":5,\"space\":42}},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getUiAccountAsync(account, .processed);
    try std.testing.expect(!task.isDone());

    const info = try task.wait();
    defer freeJsonParsedAccountInfo(allocator, info);

    try std.testing.expectEqual(@as(u64, 88), info.lamports);
    try std.testing.expectEqualStrings("Owner666666666666666666666666666666666666", info.owner);
    try std.testing.expect(info.executable);
    try std.testing.expect(std.mem.indexOf(u8, info.data_json, "\"system\"") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getUiAccountMaybeAsync returns null for missing account" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const account = "UiMissing11111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        account,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":707},\"value\":null},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getUiAccountMaybeAsync(account, .finalized);
    try std.testing.expect(!task.isDone());

    const info = try task.wait();
    defer freeMaybeUiAccount(allocator, info);

    try std.testing.expect(info == null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getMultipleUiAccountsResponseAsync sends requested accounts" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const accounts = [_][]const u8{
        "UiMulti111111111111111111111111111111111111",
        "UiMulti222222222222222222222222222222222222",
    };
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        accounts[0],
        accounts[1],
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":808},\"value\":[{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":99,\"owner\":\"Owner777777777777777777777777777777777777\",\"rentEpoch\":6,\"space\":99},null]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMultipleUiAccountsResponseAsync(&accounts, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeMultipleUiAccountsResponse(allocator, response);

    try std.testing.expectEqual(@as(u64, 808), response.context_slot);
    try std.testing.expectEqual(@as(usize, 2), response.accounts.len);
    try std.testing.expect(response.accounts[0] != null);
    try std.testing.expectEqual(@as(u64, 99), response.accounts[0].?.lamports);
    try std.testing.expect(std.mem.indexOf(u8, response.accounts[0].?.data_json, "spl-token") != null);
    try std.testing.expect(response.accounts[1] == null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getMultipleUiAccountsAsync returns optional parsed account list" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const accounts = [_][]const u8{
        "UiMultiDirect1111111111111111111111111111111",
        "UiMultiDirect2222222222222222222222222222222",
    };
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        accounts[0],
        accounts[1],
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":909},\"value\":[null,{\"data\":{\"program\":\"vote\",\"parsed\":{\"type\":\"vote\"}},\"executable\":true,\"lamports\":111,\"owner\":\"Owner888888888888888888888888888888888888\",\"rentEpoch\":7,\"space\":111}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getMultipleUiAccountsAsync(&accounts, .processed);
    try std.testing.expect(!task.isDone());

    const result = try task.wait();
    defer freeOptionalUiAccounts(allocator, result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expect(result[0] == null);
    try std.testing.expect(result[1] != null);
    try std.testing.expectEqual(@as(u64, 111), result[1].?.lamports);
    try std.testing.expect(result[1].?.executable);
    try std.testing.expect(std.mem.indexOf(u8, result[1].?.data_json, "\"vote\"") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getProgramAccountsResponseAsync sends requested program id" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const program_id = "Program111111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        program_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":[{\"pubkey\":\"ProgAcct1111111111111111111111111111111111\",\"account\":{\"data\":[\"QUJDRA==\",\"base64\"],\"executable\":false,\"lamports\":121,\"owner\":\"Owner999999999999999999999999999999999999\",\"rentEpoch\":3,\"space\":4}}],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getProgramAccountsResponseAsync(program_id, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeProgramAccountsResponse(allocator, response);

    try std.testing.expect(response.context_slot == null);
    try std.testing.expectEqual(@as(usize, 1), response.accounts.len);
    try std.testing.expectEqualStrings("ProgAcct1111111111111111111111111111111111", response.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 121), response.accounts[0].account.lamports);
    try std.testing.expectEqualStrings("Owner999999999999999999999999999999999999", response.accounts[0].account.owner);
    try std.testing.expectEqualStrings("QUJDRA==", response.accounts[0].account.data.?);
    try std.testing.expectEqualStrings("base64", response.accounts[0].account.data_encoding.?);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getProgramAccountsAsync returns program accounts" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const program_id = "Program222222222222222222222222222222222222";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        program_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":[{\"pubkey\":\"ProgAcct2222222222222222222222222222222222\",\"account\":{\"data\":[\"REVG\",\"base64\"],\"executable\":true,\"lamports\":222,\"owner\":\"OwnerAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\",\"rentEpoch\":4,\"space\":3}}],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getProgramAccountsAsync(program_id, .processed);
    try std.testing.expect(!task.isDone());

    const accounts = try task.wait();
    defer freeProgramAccounts(allocator, accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("ProgAcct2222222222222222222222222222222222", accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 222), accounts[0].account.lamports);
    try std.testing.expect(accounts[0].account.executable);
    try std.testing.expectEqualStrings("OwnerAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accounts[0].account.owner);
    try std.testing.expectEqualStrings("REVG", accounts[0].account.data.?);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getProgramUiAccountsResponseAsync sends requested program id" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const program_id = "ProgramUi11111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        program_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":[{\"pubkey\":\"UiProgAcct11111111111111111111111111111111\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"mint\"}},\"executable\":false,\"lamports\":333,\"owner\":\"OwnerBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\",\"rentEpoch\":5,\"space\":82}}],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getProgramUiAccountsResponseAsync(program_id, .confirmed);
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer freeJsonParsedProgramAccountsResponse(allocator, response);

    try std.testing.expect(response.context_slot == null);
    try std.testing.expectEqual(@as(usize, 1), response.accounts.len);
    try std.testing.expectEqualStrings("UiProgAcct11111111111111111111111111111111", response.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 333), response.accounts[0].account.lamports);
    try std.testing.expectEqualStrings("OwnerBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", response.accounts[0].account.owner);
    try std.testing.expect(std.mem.indexOf(u8, response.accounts[0].account.data_json, "spl-token") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getProgramUiAccountsAsync returns parsed program accounts" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const program_id = "ProgramUi22222222222222222222222222222222222";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        program_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":[{\"pubkey\":\"UiProgAcct22222222222222222222222222222222\",\"account\":{\"data\":{\"program\":\"vote\",\"parsed\":{\"type\":\"vote\"}},\"executable\":true,\"lamports\":444,\"owner\":\"OwnerCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC\",\"rentEpoch\":6,\"space\":120}}],\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getProgramUiAccountsAsync(program_id, .processed);
    try std.testing.expect(!task.isDone());

    const accounts = try task.wait();
    defer freeJsonParsedProgramAccounts(allocator, accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("UiProgAcct22222222222222222222222222222222", accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 444), accounts[0].account.lamports);
    try std.testing.expect(accounts[0].account.executable);
    try std.testing.expectEqualStrings("OwnerCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", accounts[0].account.owner);
    try std.testing.expect(std.mem.indexOf(u8, accounts[0].account.data_json, "\"vote\"") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getTokenAccountsByOwnerAsync sends owner and filter" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const owner = "OwnerToken1111111111111111111111111111111111";
    const mint = "MintToken11111111111111111111111111111111111";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        owner,
        mint,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1001},\"value\":[{\"pubkey\":\"TokenAcctByOwner111111111111111111111111111\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":555,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":8,\"space\":165}}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTokenAccountsByOwnerAsync(owner, .{ .mint = mint }, .confirmed);
    try std.testing.expect(!task.isDone());

    const accounts = try task.wait();
    defer freeJsonParsedProgramAccounts(allocator, accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("TokenAcctByOwner111111111111111111111111111", accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 555), accounts[0].account.lamports);
    try std.testing.expect(std.mem.indexOf(u8, accounts[0].account.data_json, "spl-token") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient getTokenAccountsByDelegateAsync sends delegate and filter" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const delegate = "DelegateToken11111111111111111111111111111111";
    const token_program_id = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        delegate,
        token_program_id,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1002},\"value\":[{\"pubkey\":\"TokenAcctByDelegate1111111111111111111111111\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":666,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":9,\"space\":165}}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTokenAccountsByDelegateAsync(delegate, .{ .program_id = token_program_id }, .processed);
    try std.testing.expect(!task.isDone());

    const accounts = try task.wait();
    defer freeJsonParsedProgramAccounts(allocator, accounts);

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("TokenAcctByDelegate1111111111111111111111111", accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 666), accounts[0].account.lamports);
    try std.testing.expect(std.mem.indexOf(u8, accounts[0].account.data_json, "spl-token") != null);
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

test "root.NonblockingRpcClient getTokenLargestAccountsAsync sends requested mint" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    const mint = "MintLargest9999999999999999999999999999999999";
    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContains, .{
        &listener,
        allocator,
        200,
        mint,
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":99},\"value\":[{\"address\":\"LargestToken1111111111111111111111111111111\",\"amount\":\"1000\",\"decimals\":2,\"uiAmount\":10.0,\"uiAmountString\":\"10\"},{\"address\":\"LargestToken2222222222222222222222222222222\",\"amount\":\"2500\",\"decimals\":2,\"uiAmount\":25.0,\"uiAmountString\":\"25\"}]},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.getTokenLargestAccountsAsync(mint, .confirmed);
    try std.testing.expect(!task.isDone());

    const accounts = try task.wait();
    defer freeTokenLargestAccounts(allocator, accounts);

    try std.testing.expectEqual(@as(usize, 2), accounts.len);
    try std.testing.expectEqualStrings("LargestToken1111111111111111111111111111111", accounts[0].address);
    try std.testing.expectEqualStrings("1000", accounts[0].amount.amount);
    try std.testing.expectEqual(@as(u8, 2), accounts[0].amount.decimals);
    try std.testing.expectEqual(@as(?f64, 10.0), accounts[0].amount.ui_amount);
    try std.testing.expectEqualStrings("10", accounts[0].amount.ui_amount_string);
    try std.testing.expectEqualStrings("LargestToken2222222222222222222222222222222", accounts[1].address);
    try std.testing.expectEqualStrings("2500", accounts[1].amount.amount);
    try std.testing.expectEqual(@as(?f64, 25.0), accounts[1].amount.ui_amount);
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

test "root.NonblockingRpcClient sendRawAsync sends custom method and params" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        "customMethod",
        "CustomParam111",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":{\"ok\":true},\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.sendRawAsync("customMethod", .{"CustomParam111"});
    try std.testing.expect(!task.isDone());

    const response = try task.wait();
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"ok\":true") != null);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient sendJsonRpcAsync parses owned result" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        "customJsonMethod",
        "JsonParam222",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":\"json-ok\",\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.sendJsonRpcAsync("customJsonMethod", .{"JsonParam222"}, []const u8);
    try std.testing.expect(!task.isDone());

    var result = try task.wait();
    defer result.deinit();

    try std.testing.expectEqualStrings("json-ok", result.value);
    try std.testing.expect(matched);
}

test "root.NonblockingRpcClient sendTypedAsync uses request method" {
    const allocator = std.testing.allocator;
    var listener = try createListener();
    defer listener.deinit();

    const port = listener.listen_address.getPort();
    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(endpoint);

    var matched = false;
    var server_thread = try std.Thread.spawn(.{}, runDelayedRootServerAndCheckBodyContainsBoth, .{
        &listener,
        allocator,
        200,
        "customTypedMethod",
        "TypedParam333",
        &matched,
        "{\"jsonrpc\":\"2.0\",\"result\":333,\"id\":1}",
    });
    defer server_thread.join();

    var rpc = try client.NonblockingRpcClient.new(allocator, endpoint);
    defer rpc.deinit();

    const task = try rpc.sendTypedAsync(client.RpcRequest.custom("customTypedMethod"), .{"TypedParam333"}, u64);
    try std.testing.expect(!task.isDone());

    var result = try task.wait();
    defer result.deinit();

    try std.testing.expectEqual(@as(u64, 333), result.value);
    try std.testing.expect(matched);
}
