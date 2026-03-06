const std = @import("std");
const client = @import("solana_client_zig");
const root_test_support = @import("root_test_support");

const runMockRootServer = root_test_support.runMockRootServer;
const runMockRootServerCaptureSequence = root_test_support.runMockRootServerCaptureSequence;

test "root.getNonceAccountResponse parses nonce account from jsonParsed account data" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":55},"value":{"data":{"program":"system","parsed":{"type":"initialized","info":{"authority":"Auth111111111111111111111111111111111111","blockhash":"NonceBlockhash1111111111111111111111111111","feeCalculator":{"lamportsPerSignature":5000}}},"space":80},"executable":false,"lamports":123456,"owner":"11111111111111111111111111111111","rentEpoch":0,"space":80}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const response = try rpc.getNonceAccountResponse("Nonce11111111111111111111111111111111111", .confirmed);
    try std.testing.expectEqual(@as(u64, 55), response.context_slot);
    try std.testing.expect(response.account != null);

    const nonce_account = response.account.?;
    defer rpc.freeOwnedNonceAccount(nonce_account);

    try std.testing.expectEqualStrings("Auth111111111111111111111111111111111111", nonce_account.authority);
    try std.testing.expectEqualStrings("NonceBlockhash1111111111111111111111111111", nonce_account.blockhash);
    try std.testing.expectEqual(@as(?u64, 5000), nonce_account.lamports_per_signature);
}

test "root.getNonceBlockhash returns owned blockhash copy" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":56},"value":{"data":{"program":"system","parsed":{"type":"initialized","info":{"authority":"Auth111111111111111111111111111111111111","blockhash":"NonceBlockhash2222222222222222222222222222","feeCalculator":{"lamportsPerSignature":5001}}},"space":80},"executable":false,"lamports":123456,"owner":"11111111111111111111111111111111","rentEpoch":0,"space":80}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const blockhash = try rpc.getNonceBlockhash("Nonce11111111111111111111111111111111111", .finalized);
    defer allocator.free(blockhash);

    try std.testing.expectEqualStrings("NonceBlockhash2222222222222222222222222222", blockhash);
}

test "root.resolveBlockhashQuery resolves cluster, fixed, and nonce account sources" {
    const allocator = std.testing.allocator;

    var fixed_rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer fixed_rpc.deinit();

    const fixed = try fixed_rpc.resolveBlockhashQuery(.{ .fixed = "FixedBlockhash11111111111111111111111111111" });
    defer fixed_rpc.freeOwnedResolvedBlockhash(fixed);
    try std.testing.expectEqual(client.BlockhashQuerySource.fixed, fixed.source);
    try std.testing.expectEqualStrings("FixedBlockhash11111111111111111111111111111", fixed.blockhash);
    try std.testing.expect(fixed.context_slot == null);
    try std.testing.expect(fixed.last_valid_block_height == null);

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":{"blockhash":"LatestBlockhash1111111111111111111111111111","lastValidBlockHeight":999}},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":88},"value":{"data":{"program":"system","parsed":{"type":"initialized","info":{"authority":"Auth111111111111111111111111111111111111","blockhash":"NonceResolvedBlockhash11111111111111111111","feeCalculator":{"lamportsPerSignature":5002}}},"space":80},"executable":false,"lamports":123456,"owner":"11111111111111111111111111111111","rentEpoch":0,"space":80}},"id":2}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const cluster = try rpc.resolveBlockhashQuery(.{ .cluster = .{ .commitment = .confirmed } });
    defer rpc.freeOwnedResolvedBlockhash(cluster);
    try std.testing.expectEqual(client.BlockhashQuerySource.cluster, cluster.source);
    try std.testing.expectEqualStrings("LatestBlockhash1111111111111111111111111111", cluster.blockhash);
    try std.testing.expectEqual(@as(?u64, 77), cluster.context_slot);
    try std.testing.expectEqual(@as(?u64, 999), cluster.last_valid_block_height);

    const nonce = try rpc.resolveBlockhashQuery(.{
        .nonce_account = .{
            .pubkey = "Nonce11111111111111111111111111111111111",
            .commitment = .finalized,
        },
    });
    defer rpc.freeOwnedResolvedBlockhash(nonce);
    try std.testing.expectEqual(client.BlockhashQuerySource.nonce_account, nonce.source);
    try std.testing.expectEqualStrings("NonceResolvedBlockhash11111111111111111111", nonce.blockhash);
    try std.testing.expectEqual(@as(?u64, 88), nonce.context_slot);
    try std.testing.expect(nonce.last_valid_block_height == null);

    try std.testing.expectEqual(@as(usize, 2), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getLatestBlockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"getAccountInfo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"commitment\":\"finalized\"") != null);
}
