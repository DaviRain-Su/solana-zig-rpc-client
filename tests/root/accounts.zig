const std = @import("std");
const client = @import("solana_client_zig");

test "root.getAccount wrappers return decoded account info" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":12},\"value\":{\"data\":[\"\",\"base64\"],\"executable\":false,\"lamports\":1234,\"owner\":\"Owner1111111111111111111111111111111111\",\"rentEpoch\":8,\"space\":64}},\"id\":1}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":12},\"value\":{\"data\":[\"\",\"base64\"],\"executable\":false,\"lamports\":1234,\"owner\":\"Owner1111111111111111111111111111111111\",\"rentEpoch\":8,\"space\":64}},\"id\":2}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":12},\"value\":{\"data\":[\"\",\"base64\"],\"executable\":false,\"lamports\":1234,\"owner\":\"Owner1111111111111111111111111111111111\",\"rentEpoch\":8,\"space\":64}},\"id\":3}" },
    });
    defer rpc.deinit();

    const account_1 = (try rpc.getAccount("Address11111111111111111111111111111111")) orelse
        return error.TestExpectedEqual;
    defer rpc.freeOwnedAccountInfo(account_1);
    try std.testing.expectEqual(@as(u64, 1234), account_1.lamports);

    const account_2 = (try rpc.getAccountWithCommitment(
        "Address11111111111111111111111111111111",
        .confirmed,
    )) orelse return error.TestExpectedEqual;
    defer rpc.freeOwnedAccountInfo(account_2);
    try std.testing.expectEqual(@as(u64, 1234), account_2.lamports);

    const account_3 = (try rpc.getAccountWithConfig(
        "Address11111111111111111111111111111111",
        client.AccountQueryOptions{ .commitment = .confirmed },
    )) orelse return error.TestExpectedEqual;
    defer rpc.freeOwnedAccountInfo(account_3);
    try std.testing.expectEqual(@as(u64, 1234), account_3.lamports);
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[2].method);
}

test "root.getAccountInfo params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment_json = try rpc.serializeAccountParams(
        "Address11111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment_json = try rpc.serializeAccountParams(
        "Address11111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);

    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_options_json = try rpc.serializeAccountParams(
        "Address11111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 42,
            .encoding = .base64,
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(with_options_json);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"minContextSlot\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_options_json, "\"length\":32") != null);
}

test "root.getUiAccount params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params_json = try rpc.serializeUiAccountParams(
        "Address11111111111111111111111111111111",
        .{
            .commitment = .confirmed,
            .min_context_slot = 55,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":55") != null);
}

test "root.getAccountInfoMaybeWithOptions returns null when account missing" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1},\"value\":null},\"id\":1}" },
    });
    defer rpc.deinit();

    const maybe_info = try rpc.getAccountInfoMaybeWithOptions("Address11111111111111111111111111111111", null);
    try std.testing.expect(maybe_info == null);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.getAccountInfoResponseWithOptions preserves context slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":42},\"value\":{\"data\":[\"\",\"base64\"],\"executable\":false,\"lamports\":99,\"owner\":\"Owner1111111111111111111111111111111111\",\"rentEpoch\":7,\"space\":0}},\"id\":1}" },
    });
    defer rpc.deinit();

    const info_response = try rpc.getAccountInfoResponseWithOptions("Address11111111111111111111111111111111", null);
    try std.testing.expectEqual(@as(u64, 42), info_response.context_slot);
    try std.testing.expect(info_response.account != null);

    const info = info_response.account.?;
    defer rpc.freeOwnedAccountInfo(info);

    try std.testing.expectEqual(@as(u64, 99), info.lamports);
    try std.testing.expectEqualStrings("Owner1111111111111111111111111111111111", info.owner);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.getUiAccountWithOptions returns account not found when account missing" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1},\"value\":null},\"id\":1}" },
    });
    defer rpc.deinit();

    try std.testing.expectError(
        error.AccountNotFound,
        rpc.getUiAccountWithOptions("Address11111111111111111111111111111111", null),
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.getMultipleUiAccountsResponseWithOptions preserves context slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":77},\"value\":[{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":1,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":2,\"space\":165},null]},\"id\":1}" },
    });
    defer rpc.deinit();

    const infos_response = try rpc.getMultipleUiAccountsResponseWithOptions(&.{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    }, null);
    defer {
        for (infos_response.accounts) |maybe_info| {
            if (maybe_info) |info| {
                rpc.allocator.free(info.owner);
                rpc.allocator.free(info.data_json);
            }
        }
        rpc.allocator.free(infos_response.accounts);
    }

    try std.testing.expectEqual(@as(u64, 77), infos_response.context_slot);
    try std.testing.expectEqual(@as(usize, 2), infos_response.accounts.len);
    try std.testing.expect(infos_response.accounts[0] != null);
    try std.testing.expect(infos_response.accounts[1] == null);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getMultipleAccounts", rpc.capturedMockRequests()[0].method);
}

test "root.getMultipleUiAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const params_json = try rpc.serializeMultipleUiAccountsParams(addresses[0..], .{
        .commitment = .finalized,
        .min_context_slot = 77,
    });
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"Address22222222222222222222222222222222\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":77") != null);
}

test "root.getMultipleAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const addresses = [_][]const u8{
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    };

    const without_commitment_json = try rpc.serializeMultipleAccountsParams(addresses[0..], null);
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address22222222222222222222222222222222\"") != null);

    const with_commitment_json = try rpc.serializeMultipleAccountsParams(
        addresses[0..],
        .{
            .commitment = .finalized,
            .min_context_slot = 88,
            .encoding = .base58,
            .data_slice_offset = 4,
            .data_slice_length = 16,
        },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"minContextSlot\":88") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"encoding\":\"base58\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"offset\":4") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"length\":16") != null);
}

test "root.getProgramAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment_json = try rpc.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Program1111111111111111111111111111111111\"") != null);

    const with_commitment_json = try rpc.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);

    const with_filters_json = try rpc.serializeProgramAccountsParams(
        "Program1111111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 99,
            .with_context = true,
            .sort_results = true,
            .data_size = 165,
            .memcmp_offset = 32,
            .memcmp_bytes = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(with_filters_json);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"minContextSlot\":99") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"withContext\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "sortResults") == null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"dataSize\":165") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"offset\":32") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"bytes\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"length\":32") != null);
}

test "root.getProgramUiAccounts params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params = .{
        "Program1111111111111111111111111111111111",
        .{
            .commitment = client.commitmentToString(.processed),
            .encoding = "jsonParsed",
        },
    };
    const params_json = try rpc.serializeParams(params);
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getProgramUiAccountsWithOptions params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params_json = try rpc.serializeProgramUiAccountsParams(
        "Program1111111111111111111111111111111111",
        .{
            .commitment = .finalized,
            .min_context_slot = 111,
            .with_context = true,
            .sort_results = true,
            .data_size = 165,
            .memcmp_offset = 32,
            .memcmp_bytes = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            .data_slice_offset = 0,
            .data_slice_length = 32,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":111") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"withContext\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "sortResults") == null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"dataSize\":165") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"offset\":32") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"bytes\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"dataSlice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"length\":32") != null);
}

test "root.getProgramUiAccountsWithConfig returns parsed program accounts" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":[{\"pubkey\":\"ProgramAcct1111111111111111111111111111111111\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{\"mint\":\"Mint1111111111111111111111111111111111\"}}},\"executable\":false,\"lamports\":123,\"owner\":\"Owner1111111111111111111111111111111111\",\"rentEpoch\":9,\"space\":165}}],\"id\":1}" },
    });
    defer rpc.deinit();

    const accounts = try rpc.getProgramUiAccountsWithConfig(
        "Program1111111111111111111111111111111111",
        client.ProgramAccountsQueryOptions{ .commitment = .confirmed },
    );
    defer {
        for (accounts) |entry| {
            rpc.allocator.free(entry.account.owner);
            rpc.allocator.free(entry.account.data_json);
            rpc.allocator.free(entry.pubkey);
        }
        rpc.allocator.free(accounts);
    }

    try std.testing.expectEqual(@as(usize, 1), accounts.len);
    try std.testing.expectEqualStrings("ProgramAcct1111111111111111111111111111111111", accounts[0].pubkey);
    try std.testing.expectEqual(@as(u64, 123), accounts[0].account.lamports);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getProgramAccounts", rpc.capturedMockRequests()[0].method);
}
