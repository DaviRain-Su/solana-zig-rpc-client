const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const RpcErrorDetail = rpc_types.RpcErrorDetail;

fn clearLastErrorState(self: anytype) void {
    if (self.last_error) |last| {
        self.allocator.free(last.message);
        self.last_error = null;
    }
}

pub fn serializeParams(self: anytype, value: anytype) ![]u8 {
    return try json.Stringify.valueAlloc(self.allocator, value, .{});
}

pub fn parseResponse(self: anytype, body: []const u8, comptime ResultType: type) !ResultType {
    clearLastErrorState(self);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?ResultType = null,
        @"error": ?RpcErrorDetail = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.@"error" != null) {
        const err = parsed.value.@"error".?;
        self.last_error = RpcErrorDetail{
            .code = err.code,
            .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
        };
        return error.RpcError;
    }

    return parsed.value.result orelse error.InvalidResponse;
}

pub fn captureRpcError(self: anytype, body: []const u8) !void {
    clearLastErrorState(self);

    const ParsedEnvelope = struct {
        @"error": ?RpcErrorDetail = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.@"error") |err| {
        self.last_error = RpcErrorDetail{
            .code = err.code,
            .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
        };
        return error.RpcError;
    }
}
