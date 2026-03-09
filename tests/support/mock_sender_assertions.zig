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

pub fn expectMockRpcScriptSatisfied(rpc: *const client.RpcClient) !void {
    try expectMockRpcScriptExhausted(rpc);
    try expectMockRpcNoScriptMisses(rpc);
}
