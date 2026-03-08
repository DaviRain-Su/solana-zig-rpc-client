const std = @import("std");
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

test "root.balance params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        .{ .commitment = client.commitmentToString(.finalized) },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.requestAirdropWithBlockhash returns signature copy" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"Sig111111111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.requestAirdropWithBlockhash(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        9001,
        "RecentBlockhash1111111111111111111111111111",
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("requestAirdrop", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "9001") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"recentBlockhash\":\"RecentBlockhash1111111111111111111111111111\"") != null);
}

test "root.getTokenAccount returns parsed ui account" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":14},\"value\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{\"mint\":\"Mint1111111111111111111111111111111111\"}}},\"executable\":false,\"lamports\":99,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":42,\"space\":165}},\"id\":1}" },
    });
    defer rpc.deinit();

    const token_account = try rpc.getTokenAccount(
        "TokenAccount1111111111111111111111111111111111",
        .confirmed,
    );
    defer rpc.allocator.free(token_account.owner);
    defer rpc.allocator.free(token_account.data_json);

    try std.testing.expectEqual(@as(u64, 99), token_account.lamports);
    try std.testing.expectEqual(@as(bool, false), token_account.executable);
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", token_account.owner);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
}

test "root.ui and token account config aliases return same parsed account" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":14},\"value\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{\"mint\":\"Mint1111111111111111111111111111111111\"}}},\"executable\":false,\"lamports\":99,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":42,\"space\":165}},\"id\":1}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":14},\"value\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{\"mint\":\"Mint1111111111111111111111111111111111\"}}},\"executable\":false,\"lamports\":99,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":42,\"space\":165}},\"id\":2}" },
    });
    defer rpc.deinit();

    const ui_account = try rpc.getUiAccountWithConfig(
        "Address11111111111111111111111111111111",
        client.UiAccountQueryOptions{ .commitment = .confirmed },
    );
    defer rpc.allocator.free(ui_account.owner);
    defer rpc.allocator.free(ui_account.data_json);

    try std.testing.expectEqual(@as(u64, 99), ui_account.lamports);

    const token_account = try rpc.getTokenAccountWithConfig(
        "TokenAccount1111111111111111111111111111111111",
        client.UiAccountQueryOptions{ .commitment = .confirmed },
    );
    defer rpc.allocator.free(token_account.owner);
    defer rpc.allocator.free(token_account.data_json);

    try std.testing.expectEqual(@as(u64, 99), token_account.lamports);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[1].method);
}

test "root.getBalanceResponse preserves context slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockBalanceResponse(42, 9001);

    const balance_response = try rpc.getBalanceResponse("Address11111111111111111111111111111111", .confirmed);
    try std.testing.expectEqual(@as(u64, 42), balance_response.context_slot);
    try std.testing.expectEqual(@as(u64, 9001), balance_response.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getBalance", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.requestAirdrop params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const default_json = try rpc.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        null,
    );
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "12345") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"commitment\"") == null);

    const with_commitment_json = try rpc.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        .{ .commitment = .processed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);

    const with_blockhash_json = try rpc.serializeRequestAirdropParams(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        12345,
        .{ .recent_blockhash = "RecentBlockhash1111111111111111111111111111" },
    );
    defer allocator.free(with_blockhash_json);
    try std.testing.expect(std.mem.indexOf(u8, with_blockhash_json, "\"recentBlockhash\":\"RecentBlockhash1111111111111111111111111111\"") != null);
}

test "root.requestAirdropWithConfig returns signature copy" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"Sig111111111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.requestAirdropWithConfig(
        "7xKXtg2CWqQm6VfQn2Yf5q3r8JwM6n2vB8z8w1sT8k6",
        9001,
        .{
            .commitment = .processed,
            .recent_blockhash = "RecentBlockhash1111111111111111111111111111",
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("requestAirdrop", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"recentBlockhash\":\"RecentBlockhash1111111111111111111111111111\"") != null);
}

test "root.minimumBalanceForRentExemption params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        128,
        .{ .commitment = client.commitmentToString(.confirmed) },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "128") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getSupply params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{.{ .commitment = client.commitmentToString(.processed) }};
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);

    const with_option = .{.{
        .commitment = client.commitmentToString(.confirmed),
        .excludeNonCirculatingAccountsList = true,
    }};
    const with_option_json = try rpc.serializeParams(with_option);
    defer allocator.free(with_option_json);

    try std.testing.expect(std.mem.indexOf(u8, with_option_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_option_json, "\"excludeNonCirculatingAccountsList\":true") != null);
}

test "root.getLargestAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const no_commitment = .{};
    const no_commitment_json = try rpc.serializeParams(no_commitment);
    defer allocator.free(no_commitment_json);
    try std.testing.expect(std.mem.eql(u8, no_commitment_json, "[]"));

    const with_commitment = .{.{ .commitment = client.commitmentToString(.confirmed) }};
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_filter = .{.{
        .commitment = client.commitmentToString(.finalized),
        .filter = client.largestAccountsFilterToString(.non_circulating),
    }};
    const with_filter_json = try rpc.serializeParams(with_filter);
    defer allocator.free(with_filter_json);
    try std.testing.expect(std.mem.indexOf(u8, with_filter_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filter_json, "\"filter\":\"nonCirculating\"") != null);
}

test "root.getTokenAccountBalance params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment = .{"TokenAcct1111111111111111111111111111111"};
    const without_commitment_json = try rpc.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"TokenAcct1111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "TokenAcct1111111111111111111111111111111",
        .{ .commitment = client.commitmentToString(.processed) },
    };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"processed\"") != null);
}

test "root.getTokenSupply params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment = .{"Mint111111111111111111111111111111111111"};
    const without_commitment_json = try rpc.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Mint111111111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "Mint111111111111111111111111111111111111",
        .{ .commitment = client.commitmentToString(.finalized) },
    };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
}

test "root.getTokenLargestAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment = .{"Mint111111111111111111111111111111111111"};
    const without_commitment_json = try rpc.serializeParams(without_commitment);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Mint111111111111111111111111111111111111\"") != null);

    const with_commitment = .{
        "Mint111111111111111111111111111111111111",
        .{ .commitment = client.commitmentToString(.confirmed) },
    };
    const with_commitment_json = try rpc.serializeParams(with_commitment);
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getTokenAccountsByOwner params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const mint_filter = client.tokenAccountsFilterParams(.{ .mint = "Mint111111111111111111111111111111111111" });
    const mint_params = .{
        "Owner1111111111111111111111111111111111111",
        mint_filter,
        .{
            .commitment = client.commitmentToString(.confirmed),
            .encoding = "jsonParsed",
        },
    };
    const mint_params_json = try rpc.serializeParams(mint_params);
    defer allocator.free(mint_params_json);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"Owner1111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"mint\":\"Mint111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mint_params_json, "\"commitment\":\"confirmed\"") != null);

    const program_filter = client.tokenAccountsFilterParams(.{ .program_id = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" });
    const program_params = .{
        "Owner1111111111111111111111111111111111111",
        program_filter,
        .{ .commitment = null, .encoding = "jsonParsed" },
    };
    const program_params_json = try rpc.serializeParams(program_params);
    defer allocator.free(program_params_json);
    try std.testing.expect(std.mem.indexOf(u8, program_params_json, "\"programId\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
}

test "root.getTokenAccountsByDelegate params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        "Delegate11111111111111111111111111111111111",
        client.tokenAccountsFilterParams(.{ .mint = "Mint111111111111111111111111111111111111" }),
        .{
            .commitment = client.commitmentToString(.processed),
            .encoding = "jsonParsed",
        },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Delegate11111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"mint\":\"Mint111111111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}
