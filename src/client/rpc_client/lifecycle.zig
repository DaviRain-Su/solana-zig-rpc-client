const std = @import("std");
const rpc_types = @import("../rpc_types.zig");

const Commitment = rpc_types.Commitment;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const TransportStats = rpc_types.TransportStats;

pub fn initClient(
    comptime ClientType: type,
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    default_commitment: ?Commitment,
) !ClientType {
    return ClientType{
        .allocator = allocator,
        .endpoint = try allocator.dupe(u8, endpoint),
        .http_client = .{ .allocator = allocator },
        .request_id = 1,
        .default_commitment = default_commitment,
        .last_error = null,
        .transport_stats = .{},
    };
}

pub fn deinit(self: anytype) void {
    clearLastError(self);
    self.http_client.deinit();
    self.allocator.free(self.endpoint);
}

pub fn url(self: anytype) []const u8 {
    return self.endpoint;
}

pub fn getLastError(self: anytype) ?RpcErrorDetail {
    return self.last_error;
}

pub fn getTransportStats(self: anytype) TransportStats {
    return self.transport_stats;
}

pub fn clearLastError(self: anytype) void {
    if (self.last_error) |last| {
        self.allocator.free(last.message);
        self.last_error = null;
    }
}
