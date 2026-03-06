const rpc_types = @import("../rpc_types.zig");

const OwnedRpcResult = rpc_types.OwnedRpcResult;
const RpcRequest = rpc_types.RpcRequest;

pub fn sendRaw(self: anytype, method: []const u8, params: anytype) ![]u8 {
    const params_json = try self.serializeParams(params);
    defer self.allocator.free(params_json);

    return try self.sendRequest(method, params_json);
}

pub fn sendJsonRpc(self: anytype, method: []const u8, params: anytype, comptime ResultType: type) !OwnedRpcResult(ResultType) {
    const response = try self.sendRaw(method, params);
    return try self.parseOwnedResponse(response, ResultType);
}

pub fn sendTyped(self: anytype, request: RpcRequest, params: anytype, comptime ResultType: type) !OwnedRpcResult(ResultType) {
    return try self.sendJsonRpc(request.method, params, ResultType);
}
