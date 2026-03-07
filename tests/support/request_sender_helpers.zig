const std = @import("std");
const client = @import("solana_client_zig");

pub const MockHandlerContext = struct {
    call_count: usize = 0,
};

pub const RequestSenderContext = struct {
    call_count: usize = 0,
    deinit_count: usize = 0,
    saw_confirmed_commitment: bool = false,
    last_request_id: u64 = 0,
    base_slot: u64 = 0,
    error_code: i64 = -32055,
};

fn rpcJsonResponse(allocator: std.mem.Allocator, request_id: u64, result_json: []const u8) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

pub fn dynamicMockHandler(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.MockRequestView,
) !client.MockHandlerResponse {
    const context: *MockHandlerContext = @ptrCast(@alignCast(context_ptr.?));
    context.call_count += 1;

    if (std.mem.eql(u8, request.method, "getSlot")) {
        const slot: u64 = if (std.mem.indexOf(u8, request.params_json, "\"finalized\"") != null) 789 else 456;
        return .{ .json = try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"result\":{},\"id\":{}}}",
            .{ slot, request.id },
        ) };
    }

    if (std.mem.eql(u8, request.method, "getHealth")) {
        return .{ .json = try rpcJsonResponse(allocator, request.id, "\"ok\"") };
    }

    return .{ .transport_error = .http_error };
}

pub fn timeoutMockHandler(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.MockRequestView,
) !client.MockHandlerResponse {
    _ = context_ptr;
    _ = allocator;
    _ = request;
    return .{ .transport_error = .timeout };
}

pub fn structuredMockHandler(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.MockRequestView,
) !client.MockHandlerResponse {
    const context: *MockHandlerContext = @ptrCast(@alignCast(context_ptr.?));
    context.call_count += 1;

    if (std.mem.eql(u8, request.method, "getSlot")) {
        return .{ .result_json = try std.fmt.allocPrint(allocator, "{}", .{request.id * 100}) };
    }

    return .{ .rpc_error = .{
        .code = -32000,
        .message = try allocator.dupe(u8, "mock handler rejected request"),
        .data_json = try allocator.dupe(u8, "{\"method\":\"unexpected\"}"),
    } };
}

pub fn customRequestSender(
    context_ptr: ?*anyopaque,
    allocator: std.mem.Allocator,
    request: client.RequestSenderRequest,
) ![]u8 {
    const context: *RequestSenderContext = @ptrCast(@alignCast(context_ptr.?));
    context.call_count += 1;
    context.last_request_id = request.id;
    if (std.mem.indexOf(u8, request.params_json, "\"confirmed\"") != null) {
        context.saw_confirmed_commitment = true;
    }

    if (std.mem.eql(u8, request.method, "getSlot")) {
        const result_json = try std.fmt.allocPrint(allocator, "{}", .{context.base_slot + request.id});
        defer allocator.free(result_json);
        return try client.encodeJsonRpcResultEnvelope(allocator, request.id, result_json);
    }

    return try client.encodeJsonRpcErrorEnvelope(allocator, request.id, .{
        .code = context.error_code,
        .message = "custom sender rejected request",
        .data_json = "{\"method\":\"unexpected\"}",
    });
}

pub fn customRequestSenderDeinit(context_ptr: ?*anyopaque, allocator: std.mem.Allocator) void {
    _ = allocator;
    const context: *RequestSenderContext = @ptrCast(@alignCast(context_ptr.?));
    context.deinit_count += 1;
}
