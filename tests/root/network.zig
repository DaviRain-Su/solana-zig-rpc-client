const std = @import("std");
const client = @import("solana_client_zig");

test "root.getLatestBlockhash params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params_json = try rpc.serializeParams(.{struct {
        commitment: ?[]const u8 = "finalized",
    }{ .commitment = "finalized" }});
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getLatestBlockhashResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":9},\"value\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"lastValidBlockHeight\":55}},\"id\":1}" },
    });
    defer rpc.deinit();

    const blockhash_response = try rpc.getLatestBlockhashResponse(.confirmed);
    defer allocator.free(blockhash_response.value.blockhash);

    try std.testing.expectEqual(@as(u64, 9), blockhash_response.context_slot);
    try std.testing.expectEqualStrings("Blockhash111111111111111111111111111111111111", blockhash_response.value.blockhash);
    try std.testing.expectEqual(@as(u64, 55), blockhash_response.value.last_valid_block_height);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getNewLatestBlockhash waits for updated blockhash" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1},\"value\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"lastValidBlockHeight\":55}},\"id\":1}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":2},\"value\":{\"blockhash\":\"UpdatedBlockhash11111111111111111111111111111111\",\"lastValidBlockHeight\":56}},\"id\":2}" },
    });
    defer rpc.deinit();

    const latest = try rpc.getNewLatestBlockhash("Blockhash111111111111111111111111111111111111");
    defer allocator.free(latest);

    try std.testing.expectEqualStrings("UpdatedBlockhash11111111111111111111111111111111", latest);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[1].method);
}

test "root.featureActivationSlot params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        "Feature11111111111111111111111111111111111111111",
        .{ .commitment = client.commitmentToString(.processed) },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Feature11111111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.firstAvailableBlock params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{.{ .commitment = client.commitmentToString(.processed) }};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getStakeMinimumDelegation params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{.{ .commitment = client.commitmentToString(.confirmed) }};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.epochInfo params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{.{ .commitment = client.commitmentToString(.finalized) }};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.recentPerformanceSamples params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{999};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "999") != null);
}

test "root.getBlocks params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{ 123, 456 };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "456") != null);

    const with_end_only_commitment = .{ 123, 456, .{ .commitment = client.commitmentToString(.confirmed) } };
    const with_end_only_commitment_json = try rpc.serializeParams(with_end_only_commitment);
    defer allocator.free(with_end_only_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_end_only_commitment_json, "confirmed") != null);

    const with_commitment = .{ 123, .{ .commitment = client.commitmentToString(.finalized) } };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "finalized") != null);
}

test "root.getBlocksWithLimit params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{ 123, 25 };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "25") != null);

    const with_commitment = .{ 123, 25, .{ .commitment = client.commitmentToString(.finalized) } };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getInflationReward params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const no_config = .{addresses};
    const no_config_json = try rpc.serializeParams(no_config);
    defer allocator.free(no_config_json);
    try std.testing.expect(std.mem.indexOf(u8, no_config_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, no_config_json, "\"Address22222222222222222222222222222222\"") != null);

    const with_config = .{
        addresses,
        .{
            .commitment = client.commitmentToString(.confirmed),
            .epoch = @as(u64, 42),
        },
    };
    const with_config_json = try rpc.serializeParams(with_config);
    defer allocator.free(with_config_json);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"epoch\":42") != null);
}

test "root.getSlotLeaders params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{ 789, 5 };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "789") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "5") != null);
}

test "root.getSlotLeader params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const no_commitment = .{};
    const no_commitment_json = try rpc.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.eql(u8, no_commitment_json, "[]"));

    const with_commitment = .{.{ .commitment = client.commitmentToString(.processed) }};
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);
}

test "root.getRecentPrioritizationFees params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));

    const accounts = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };
    const filtered_params = .{accounts};
    const filtered_params_json = try rpc.serializeParams(filtered_params);
    defer allocator.free(filtered_params_json);

    try std.testing.expect(std.mem.indexOf(u8, filtered_params_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, filtered_params_json, "\"Address22222222222222222222222222222222\"") != null);
}

test "root.getIdentity params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getInflationGovernor params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getClusterNodes params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));
}

test "root.getLeaderSchedule params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const no_args = .{};
    const no_args_json = try rpc.serializeParams(no_args);
    defer allocator.free(no_args_json);
    try std.testing.expect(std.mem.eql(u8, no_args_json, "[]"));

    const slot_only = .{123};
    const slot_only_json = try rpc.serializeParams(slot_only);
    defer allocator.free(slot_only_json);
    try std.testing.expect(std.mem.indexOf(u8, slot_only_json, "123") != null);

    const slot_identity = .{ 123, .{ .identity = "ABC", .commitment = client.commitmentToString(.finalized) } };
    const slot_identity_json = try rpc.serializeParams(slot_identity);
    defer allocator.free(slot_identity_json);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "\"identity\":\"ABC\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, slot_identity_json, "\"commitment\":\"finalized\"") != null);

    const identity_only = .{.{ .identity = "DEF", .commitment = client.commitmentToString(.confirmed) }};
    const identity_only_json = try rpc.serializeParams(identity_only);
    defer allocator.free(identity_only_json);
    try std.testing.expect(std.mem.indexOf(u8, identity_only_json, "\"identity\":\"DEF\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, identity_only_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getVoteAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.eql(u8, params_json, "[]"));

    const with_config = .{.{
        .commitment = client.commitmentToString(.confirmed),
        .votePubkey = "Vote111111111111111111111111111111111111111",
        .keepUnstakedDelinquents = true,
        .delinquentSlotDistance = @as(u64, 128),
    }};
    const with_config_json = try rpc.serializeParams(with_config);
    defer allocator.free(with_config_json);

    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"votePubkey\":\"Vote111111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"keepUnstakedDelinquents\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"delinquentSlotDistance\":128") != null);
}

test "root.getBlockProduction params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const no_commitment = .{};
    const no_commitment_json = try rpc.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.eql(u8, no_commitment_json, "[]"));

    const with_commitment = .{.{ .commitment = client.commitmentToString(.processed) }};
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);

    const with_config = .{.{
        .commitment = client.commitmentToString(.confirmed),
        .identity = "Identity1111111111111111111111111111111111",
        .range = .{
            .firstSlot = @as(u64, 100),
            .lastSlot = @as(u64, 200),
        },
    }};
    const with_config_json = try rpc.serializeParams(with_config);
    defer allocator.free(with_config_json);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"identity\":\"Identity1111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"firstSlot\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_config_json, "\"lastSlot\":200") != null);
}
