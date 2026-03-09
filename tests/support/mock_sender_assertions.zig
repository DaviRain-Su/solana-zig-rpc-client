const std = @import("std");
const client = @import("solana_client_zig");

fn printMockSenderSummary(sender: *const client.MockSender) !void {
    const summary = try sender.scriptSummaryAlloc(std.testing.allocator);
    defer std.testing.allocator.free(summary);
    std.debug.print("mock sender summary:\n{s}", .{summary});
}

fn printMockRpcSummary(rpc: *const client.RpcClient) !void {
    const summary = try rpc.mockScriptSummaryAlloc(std.testing.allocator);
    defer std.testing.allocator.free(summary);
    std.debug.print("mock rpc summary:\n{s}", .{summary});
}

fn printMockRequestSenderSummary(sender: *const client.RequestSender) !void {
    const summary = try sender.mockScriptSummaryAlloc(std.testing.allocator);
    defer std.testing.allocator.free(summary);
    std.debug.print("mock request sender summary:\n{s}", .{summary});
}

pub fn expectMockSenderPendingScriptedDispatchCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.pendingScriptedDispatchCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.pendingScriptedDispatchCount());
}

pub fn expectMockSenderRequestCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.requestCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.requestCount());
}

pub fn expectMockSenderResponseCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.responseCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.responseCount());
}

pub fn expectMockSenderRouteCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.routeCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.routeCount());
}

pub fn expectMockSenderPersistentRouteCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.persistentRouteCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.persistentRouteCount());
}

pub fn expectMockSenderMatchedRouteCount(
    sender: *const client.MockSender,
    expected: usize,
) !void {
    if (sender.matchedRouteCount() != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.matchedRouteCount());
}

pub fn expectMockSenderRouteMatchCount(
    sender: *const client.MockSender,
    label: []const u8,
    expected: usize,
) !void {
    if (sender.routeMatchCountForLabel(label) != expected) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.routeMatchCountForLabel(label));
}

pub fn expectMockSenderScriptExhausted(sender: *const client.MockSender) !void {
    try expectMockSenderPendingScriptedDispatchCount(sender, 0);
}

pub fn expectMockSenderNoScriptMisses(sender: *const client.MockSender) !void {
    if (sender.scriptMissCount() != 0) {
        try printMockSenderSummary(sender);
    }
    try std.testing.expectEqual(@as(usize, 0), sender.scriptMissCount());
}

pub fn expectMockSenderLastScriptMissMethod(
    sender: *const client.MockSender,
    expected_method: []const u8,
) !void {
    const method = sender.lastScriptMissMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockSenderLastCapturedRequestMethod(
    sender: *const client.MockSender,
    expected_method: []const u8,
) !void {
    const method = sender.lastCapturedRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockSenderLastCapturedRequestId(
    sender: *const client.MockSender,
    expected_id: u64,
) !void {
    const id = sender.lastCapturedRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockSenderFirstCapturedRequestMethod(
    sender: *const client.MockSender,
    expected_method: []const u8,
) !void {
    const method = sender.firstCapturedRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockSenderFirstCapturedRequestId(
    sender: *const client.MockSender,
    expected_id: u64,
) !void {
    const id = sender.firstCapturedRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockSenderFirstCapturedRequestParamsJsonContains(
    sender: *const client.MockSender,
    expected_fragment: []const u8,
) !void {
    const params_json = sender.firstCapturedRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockSenderFirstCapturedRequestBodyContains(
    sender: *const client.MockSender,
    expected_fragment: []const u8,
) !void {
    const request_body = sender.firstCapturedRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockSenderLastCapturedRequestParamsJsonContains(
    sender: *const client.MockSender,
    expected_fragment: []const u8,
) !void {
    const params_json = sender.lastCapturedRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockSenderLastCapturedRequestBodyContains(
    sender: *const client.MockSender,
    expected_fragment: []const u8,
) !void {
    const request_body = sender.lastCapturedRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockSenderScriptSatisfied(sender: *const client.MockSender) !void {
    try expectMockSenderScriptExhausted(sender);
    try expectMockSenderNoScriptMisses(sender);
}

pub fn expectMockRequestSenderPendingScriptedDispatchCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockPendingScriptedDispatchCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockPendingScriptedDispatchCount());
}

pub fn expectMockRequestSenderRequestCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockRequestCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockRequestCount());
}

pub fn expectMockRequestSenderResponseCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockResponseCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockResponseCount());
}

pub fn expectMockRequestSenderRouteCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockRouteCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockRouteCount());
}

pub fn expectMockRequestSenderPersistentRouteCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockPersistentRouteCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockPersistentRouteCount());
}

pub fn expectMockRequestSenderMatchedRouteCount(
    sender: *const client.RequestSender,
    expected: usize,
) !void {
    if (sender.mockMatchedRouteCount() != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockMatchedRouteCount());
}

pub fn expectMockRequestSenderRouteMatchCount(
    sender: *const client.RequestSender,
    label: []const u8,
    expected: usize,
) !void {
    if (sender.mockRouteMatchCount(label) != expected) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(expected, sender.mockRouteMatchCount(label));
}

pub fn expectMockRequestSenderScriptExhausted(sender: *const client.RequestSender) !void {
    try expectMockRequestSenderPendingScriptedDispatchCount(sender, 0);
}

pub fn expectMockRequestSenderNoScriptMisses(sender: *const client.RequestSender) !void {
    if (sender.mockScriptMissCount() != 0) {
        try printMockRequestSenderSummary(sender);
    }
    try std.testing.expectEqual(@as(usize, 0), sender.mockScriptMissCount());
}

pub fn expectMockRequestSenderLastScriptMissMethod(
    sender: *const client.RequestSender,
    expected_method: []const u8,
) !void {
    const method = sender.lastMockScriptMissMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRequestSenderLastCapturedRequestMethod(
    sender: *const client.RequestSender,
    expected_method: []const u8,
) !void {
    const method = sender.lastCapturedMockRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRequestSenderLastCapturedRequestId(
    sender: *const client.RequestSender,
    expected_id: u64,
) !void {
    const id = sender.lastCapturedMockRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockRequestSenderFirstCapturedRequestMethod(
    sender: *const client.RequestSender,
    expected_method: []const u8,
) !void {
    const method = sender.firstCapturedMockRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRequestSenderFirstCapturedRequestId(
    sender: *const client.RequestSender,
    expected_id: u64,
) !void {
    const id = sender.firstCapturedMockRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockRequestSenderFirstCapturedRequestParamsJsonContains(
    sender: *const client.RequestSender,
    expected_fragment: []const u8,
) !void {
    const params_json = sender.firstCapturedMockRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockRequestSenderFirstCapturedRequestBodyContains(
    sender: *const client.RequestSender,
    expected_fragment: []const u8,
) !void {
    const request_body = sender.firstCapturedMockRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockRequestSenderLastCapturedRequestParamsJsonContains(
    sender: *const client.RequestSender,
    expected_fragment: []const u8,
) !void {
    const params_json = sender.lastCapturedMockRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockRequestSenderLastCapturedRequestBodyContains(
    sender: *const client.RequestSender,
    expected_fragment: []const u8,
) !void {
    const request_body = sender.lastCapturedMockRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockRequestSenderScriptSatisfied(sender: *const client.RequestSender) !void {
    try expectMockRequestSenderScriptExhausted(sender);
    try expectMockRequestSenderNoScriptMisses(sender);
}

pub fn expectMockRpcPendingScriptedDispatchCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockPendingScriptedDispatchCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockPendingScriptedDispatchCount());
}

pub fn expectMockRpcRequestCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockRequestCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockRequestCount());
}

pub fn expectMockRpcResponseCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockResponseCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockResponseCount());
}

pub fn expectMockRpcRouteCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockRouteCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockRouteCount());
}

pub fn expectMockRpcPersistentRouteCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockPersistentRouteCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockPersistentRouteCount());
}

pub fn expectMockRpcMatchedRouteCount(
    rpc: *const client.RpcClient,
    expected: usize,
) !void {
    if (rpc.mockMatchedRouteCount() != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockMatchedRouteCount());
}

pub fn expectMockRpcRouteMatchCount(
    rpc: *const client.RpcClient,
    label: []const u8,
    expected: usize,
) !void {
    if (rpc.mockRouteMatchCount(label) != expected) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(expected, rpc.mockRouteMatchCount(label));
}

pub fn expectMockRpcScriptExhausted(rpc: *const client.RpcClient) !void {
    try expectMockRpcPendingScriptedDispatchCount(rpc, 0);
}

pub fn expectMockRpcNoScriptMisses(rpc: *const client.RpcClient) !void {
    if (rpc.mockScriptMissCount() != 0) {
        try printMockRpcSummary(rpc);
    }
    try std.testing.expectEqual(@as(usize, 0), rpc.mockScriptMissCount());
}

pub fn expectMockRpcLastScriptMissMethod(
    rpc: *const client.RpcClient,
    expected_method: []const u8,
) !void {
    const method = rpc.lastMockScriptMissMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRpcLastCapturedRequestMethod(
    rpc: *const client.RpcClient,
    expected_method: []const u8,
) !void {
    const method = rpc.lastCapturedMockRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRpcLastCapturedRequestId(
    rpc: *const client.RpcClient,
    expected_id: u64,
) !void {
    const id = rpc.lastCapturedMockRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockRpcFirstCapturedRequestMethod(
    rpc: *const client.RpcClient,
    expected_method: []const u8,
) !void {
    const method = rpc.firstCapturedMockRequestMethod() orelse return error.TestExpectedError;
    try std.testing.expectEqualStrings(expected_method, method);
}

pub fn expectMockRpcFirstCapturedRequestId(
    rpc: *const client.RpcClient,
    expected_id: u64,
) !void {
    const id = rpc.firstCapturedMockRequestId() orelse return error.TestExpectedError;
    try std.testing.expectEqual(expected_id, id);
}

pub fn expectMockRpcFirstCapturedRequestParamsJsonContains(
    rpc: *const client.RpcClient,
    expected_fragment: []const u8,
) !void {
    const params_json = rpc.firstCapturedMockRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockRpcFirstCapturedRequestBodyContains(
    rpc: *const client.RpcClient,
    expected_fragment: []const u8,
) !void {
    const request_body = rpc.firstCapturedMockRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockRpcLastCapturedRequestParamsJsonContains(
    rpc: *const client.RpcClient,
    expected_fragment: []const u8,
) !void {
    const params_json = rpc.lastCapturedMockRequestParamsJson() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, params_json, expected_fragment) != null);
}

pub fn expectMockRpcLastCapturedRequestBodyContains(
    rpc: *const client.RpcClient,
    expected_fragment: []const u8,
) !void {
    const request_body = rpc.lastCapturedMockRequestBody() orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, request_body, expected_fragment) != null);
}

pub fn expectMockRpcScriptSatisfied(rpc: *const client.RpcClient) !void {
    try expectMockRpcScriptExhausted(rpc);
    try expectMockRpcNoScriptMisses(rpc);
}
