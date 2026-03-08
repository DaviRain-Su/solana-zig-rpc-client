const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

test "root.blockTime params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{123456};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123456") != null);
}

test "root.getBlock params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{123};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);

    const with_commitment = .{ 123, .{ .commitment = client.commitmentToString(.finalized) } };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getBlockCommitment params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{321};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "321") != null);
}

test "root.getBlockWithOptions params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        456,
        .{
            .commitment = client.commitmentToString(.confirmed),
            .encoding = client.transactionEncodingToString(.jsonParsed),
            .transactionDetails = client.transactionDetailsToString(.signatures),
            .rewards = false,
            .maxSupportedTransactionVersion = @as(u8, 0),
        },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "456") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"transactionDetails\":\"signatures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"rewards\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxSupportedTransactionVersion\":0") != null);
}

test "root.getTransaction params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        "5h6xSignature111111111111111111111111111111111111",
        .{
            .commitment = client.commitmentToString(.finalized),
            .encoding = client.transactionEncodingToString(.json),
            .maxSupportedTransactionVersion = @as(u8, 0),
        },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"5h6xSignature111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxSupportedTransactionVersion\":0") != null);
}

test "root.parseGetBlockResponse parses block object" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"blockHeight\":123,\"parentSlot\":456},\"id\":1}";
    const block = try rpc.parseGetBlockResponse(body);
    defer allocator.free(block.?);

    try std.testing.expect(block != null);
    try std.testing.expect(std.mem.indexOf(u8, block.?, "\"blockHeight\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, block.?, "\"parentSlot\":456") != null);
}

test "root.parseGetBlockResponse handles null block" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const block = try rpc.parseGetBlockResponse(body);

    try std.testing.expect(block == null);
}

test "root.parseGetBlockResponse propagates rpc error" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32600,\"message\":\"invalid request\"}}";

    try std.testing.expectError(error.RpcError, rpc.parseGetBlockResponse(body));

    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32600), last_error.code);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "invalid request"));
}

test "root.parseGetBlockResponse clears last error on successful parse" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const rpc_error_body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32000,\"message\":\"not found\"}}";

    _ = rpc.parseGetBlockResponse(rpc_error_body) catch {};
    try std.testing.expect(rpc.getLastError() != null);

    const success_body = "{\"jsonrpc\":\"2.0\",\"result\":{\"blockHeight\":789},\"id\":1}";
    const block = try rpc.parseGetBlockResponse(success_body);
    defer allocator.free(block.?);

    try std.testing.expect(rpc.getLastError() == null);
    try std.testing.expect(block != null);
}

test "root.parseGetTransactionResponse parses transaction object" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":123,\"version\":0},\"id\":1}";
    const transaction = try rpc.parseGetTransactionResponse(body);
    defer allocator.free(transaction.?);

    try std.testing.expect(transaction != null);
    try std.testing.expect(std.mem.indexOf(u8, transaction.?, "\"slot\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, transaction.?, "\"version\":0") != null);
}

test "root.parseGetTransactionResponse handles null transaction" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const transaction = try rpc.parseGetTransactionResponse(body);

    try std.testing.expect(transaction == null);
}

test "root.summarizeBlockJson extracts block summary" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const block_json =
        \\{"blockhash":"Blockhash111111111111111111111111111111111111","previousBlockhash":"Prev111111111111111111111111111111111111111","parentSlot":456,"blockHeight":123,"blockTime":1700000000,"transactions":[{"transaction":{}},{"transaction":{}}],"rewards":[{},{}]}
    ;

    const summary = try rpc.summarizeBlockJson(block_json);
    defer rpc.freeOwnedBlockSummary(summary);

    try std.testing.expectEqualStrings("Blockhash111111111111111111111111111111111111", summary.blockhash orelse "");
    try std.testing.expectEqualStrings("Prev111111111111111111111111111111111111111", summary.previous_blockhash orelse "");
    try std.testing.expectEqual(@as(u64, 456), summary.parent_slot);
    try std.testing.expectEqual(@as(?u64, 123), summary.block_height);
    try std.testing.expectEqual(@as(?i64, 1700000000), summary.block_time);
    try std.testing.expectEqual(@as(?usize, 2), summary.transaction_count);
    try std.testing.expectEqual(@as(?usize, 2), summary.rewards_count);
}

test "root.getBlockSummaryWithOptions fetches and summarizes block" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"previousBlockhash\":\"Prev111111111111111111111111111111111111111\",\"parentSlot\":88,\"blockHeight\":77,\"blockTime\":1700000200,\"transactions\":[{}],\"rewards\":[]},\"id\":1}" },
    });
    defer rpc.deinit();

    const summary = try rpc.getBlockSummaryWithOptions(88, null);
    try std.testing.expect(summary != null);
    defer rpc.freeOwnedBlockSummary(summary.?);

    try std.testing.expectEqual(@as(u64, 88), summary.?.parent_slot);
    try std.testing.expectEqual(@as(?u64, 77), summary.?.block_height);
    try std.testing.expectEqual(@as(?usize, 1), summary.?.transaction_count);
    try std.testing.expectEqual(@as(?usize, 0), summary.?.rewards_count);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getBlock", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "88") != null);
}

test "root.summarizeTransactionJson extracts transaction summary" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const transaction_json =
        \\{"slot":123,"blockTime":1700000100,"version":"legacy","meta":{"err":{"InstructionError":[0,{"Custom":1}]},"fee":5000,"logMessages":["a","b","c"]},"transaction":{"signatures":["sig1","sig2"]}}
    ;

    const summary = try rpc.summarizeTransactionJson(transaction_json);
    defer rpc.freeOwnedTransactionSummary(summary);

    try std.testing.expectEqual(@as(u64, 123), summary.slot);
    try std.testing.expectEqual(@as(?i64, 1700000100), summary.block_time);
    try std.testing.expectEqualStrings("legacy", summary.version orelse "");
    try std.testing.expectEqual(@as(?usize, 2), summary.signature_count);
    try std.testing.expectEqual(@as(?u64, 5000), summary.fee);
    try std.testing.expectEqual(@as(?usize, 3), summary.log_messages_count);
    try std.testing.expect(summary.has_error);
    try std.testing.expect(summary.error_json != null);
}

test "root.getTransactionSummaryWithOptions fetches and summarizes transaction" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":55,\"blockTime\":1700000300,\"version\":0,\"meta\":{\"err\":null,\"fee\":7000,\"logMessages\":[\"a\",\"b\"]},\"transaction\":{\"signatures\":[\"sig-1\"]}},\"id\":1}" },
    });
    defer rpc.deinit();

    const summary = try rpc.getTransactionSummaryWithOptions("Signature111111111111111111111111111111111111", null);
    try std.testing.expect(summary != null);
    defer rpc.freeOwnedTransactionSummary(summary.?);

    try std.testing.expectEqual(@as(u64, 55), summary.?.slot);
    try std.testing.expectEqual(@as(?u64, 7000), summary.?.fee);
    try std.testing.expectEqual(@as(?usize, 2), summary.?.log_messages_count);
    try std.testing.expectEqual(@as(?usize, 1), summary.?.signature_count);
    try std.testing.expect(!summary.?.has_error);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"Signature111111111111111111111111111111111111\"") != null);
}

test "root.captureRpcError stores rpc error detail" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32005,\"message\":\"custom rpc error\"}}";

    try std.testing.expectError(error.RpcError, rpc.captureRpcError(body));

    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32005), last_error.code);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "custom rpc error"));
}

test "root.captureRpcError clears stale error on success" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const error_body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32001,\"message\":\"stale error\"}}";
    try std.testing.expectError(error.RpcError, rpc.captureRpcError(error_body));
    try std.testing.expect(rpc.getLastError() != null);

    const ok_body = "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":[]}";
    try rpc.captureRpcError(ok_body);
    try std.testing.expect(rpc.getLastError() == null);
}

test "root.getFeeForMessage params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{ "base64-message", .{ .commitment = client.commitmentToString(.finalized) } };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"base64-message\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getFeeForMessageResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":5000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee_response = try rpc.getFeeForMessageResponse("AQAB", .processed);
    try std.testing.expectEqual(@as(u64, 123), fee_response.context_slot);
    try std.testing.expectEqual(@as(?u64, 5000), fee_response.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"AQAB\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForMessageTyped serializes typed legacy message" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const transfer = client.SystemProgram.transfer(
        client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]client.Instruction{transfer.instruction()};
    const message = client.LegacyMessage{
        .payer = client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
    };
    const encoded_message = try message.toBase64(allocator);
    defer allocator.free(encoded_message);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":5000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForMessageTyped(message, .processed);
    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, "\"method\":\"getFeeForMessage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, "\"commitment\":\"processed\"") != null);
}
