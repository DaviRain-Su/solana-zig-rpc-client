const std = @import("std");

const Allocator = std.mem.Allocator;

pub const MockRpcError = struct {
    code: i64,
    message: []const u8,
    data_json: ?[]const u8 = null,

    pub fn dupe(self: MockRpcError, allocator: Allocator) !MockRpcError {
        return .{
            .code = self.code,
            .message = try allocator.dupe(u8, self.message),
            .data_json = if (self.data_json) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: MockRpcError, allocator: Allocator) void {
        allocator.free(self.message);
        if (self.data_json) |value| allocator.free(value);
    }
};

pub const MockTransportError = enum {
    timeout,
    connection_reset,
    http_error,
};

pub const MockResponse = union(enum) {
    json: []const u8,
    result_json: []const u8,
    rpc_error: MockRpcError,
    transport_error: MockTransportError,
};

pub const MockRequestView = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,
};

pub const MockRequestMatcher = struct {
    method: ?[]const u8 = null,
    params_json_contains: ?[]const u8 = null,
    request_body_contains: ?[]const u8 = null,

    pub fn dupe(self: MockRequestMatcher, allocator: Allocator) !MockRequestMatcher {
        return .{
            .method = if (self.method) |value| try allocator.dupe(u8, value) else null,
            .params_json_contains = if (self.params_json_contains) |value| try allocator.dupe(u8, value) else null,
            .request_body_contains = if (self.request_body_contains) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: MockRequestMatcher, allocator: Allocator) void {
        if (self.method) |value| allocator.free(value);
        if (self.params_json_contains) |value| allocator.free(value);
        if (self.request_body_contains) |value| allocator.free(value);
    }

    pub fn matches(self: MockRequestMatcher, request: MockRequestView) bool {
        if (self.method) |value| {
            if (!std.mem.eql(u8, request.method, value)) return false;
        }
        if (self.params_json_contains) |value| {
            if (std.mem.indexOf(u8, request.params_json, value) == null) return false;
        }
        if (self.request_body_contains) |value| {
            if (std.mem.indexOf(u8, request.request_body, value) == null) return false;
        }
        return true;
    }
};

pub const MockHandlerResponse = union(enum) {
    json: []u8,
    result_json: []u8,
    rpc_error: MockRpcError,
    transport_error: MockTransportError,
};

pub const MockRequestHandler = struct {
    context: ?*anyopaque = null,
    callback: *const fn (context: ?*anyopaque, allocator: Allocator, request: MockRequestView) anyerror!MockHandlerResponse,
};

pub const MockRequest = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,

    pub fn deinit(self: MockRequest, allocator: Allocator) void {
        allocator.free(self.method);
        allocator.free(self.params_json);
        allocator.free(self.request_body);
    }
};

fn cloneResponse(allocator: Allocator, response: MockResponse) !MockResponse {
    return switch (response) {
        .json => |value| .{ .json = try allocator.dupe(u8, value) },
        .result_json => |value| .{ .result_json = try allocator.dupe(u8, value) },
        .rpc_error => |value| .{ .rpc_error = try value.dupe(allocator) },
        .transport_error => |value| .{ .transport_error = value },
    };
}

fn freeResponse(allocator: Allocator, response: MockResponse) void {
    switch (response) {
        .json => |value| allocator.free(value),
        .result_json => |value| allocator.free(value),
        .rpc_error => |value| value.deinit(allocator),
        .transport_error => {},
    }
}

fn formatResultEnvelope(allocator: Allocator, request_id: u64, result_json: []const u8) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

fn encodeJsonString(allocator: Allocator, value: []const u8) ![]u8 {
    var out = std.io.Writer.Allocating.init(allocator);
    errdefer out.deinit();

    try out.writer.writeByte('"');
    for (value) |byte| {
        switch (byte) {
            '"' => try out.writer.writeAll("\\\""),
            '\\' => try out.writer.writeAll("\\\\"),
            '\n' => try out.writer.writeAll("\\n"),
            '\r' => try out.writer.writeAll("\\r"),
            '\t' => try out.writer.writeAll("\\t"),
            else => {
                if (byte < 0x20) {
                    try out.writer.print("\\u{X:0>4}", .{@as(u8, byte)});
                } else {
                    try out.writer.writeByte(byte);
                }
            },
        }
    }
    try out.writer.writeByte('"');

    const encoded = try allocator.dupe(u8, out.written());
    out.deinit();
    return encoded;
}

fn formatRpcErrorEnvelope(allocator: Allocator, request_id: u64, rpc_error: MockRpcError) ![]u8 {
    const encoded_message = try encodeJsonString(allocator, rpc_error.message);
    defer allocator.free(encoded_message);

    return if (rpc_error.data_json) |data_json|
        try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":{},\"message\":{s},\"data\":{s}}},\"id\":{}}}",
            .{ rpc_error.code, encoded_message, data_json, request_id },
        )
    else
        try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":{},\"message\":{s}}},\"id\":{}}}",
            .{ rpc_error.code, encoded_message, request_id },
        );
}

pub const MockRoute = struct {
    matcher: MockRequestMatcher = .{},
    response: MockResponse,
    remaining_uses: ?usize = 1,

    pub fn dupe(self: MockRoute, allocator: Allocator) !MockRoute {
        return .{
            .matcher = try self.matcher.dupe(allocator),
            .response = try cloneResponse(allocator, self.response),
            .remaining_uses = self.remaining_uses,
        };
    }

    pub fn deinit(self: MockRoute, allocator: Allocator) void {
        self.matcher.deinit(allocator);
        freeResponse(allocator, self.response);
    }
};

pub const MockSender = struct {
    allocator: Allocator,
    responses: std.ArrayListUnmanaged(MockResponse) = .{},
    routes: std.ArrayListUnmanaged(MockRoute) = .{},
    requests: std.ArrayListUnmanaged(MockRequest) = .{},
    handler: ?MockRequestHandler = null,

    pub fn init(allocator: Allocator) MockSender {
        return .{ .allocator = allocator };
    }

    pub fn initWithHandler(allocator: Allocator, handler: MockRequestHandler) MockSender {
        return .{
            .allocator = allocator,
            .handler = handler,
        };
    }

    pub fn initSequence(allocator: Allocator, responses: []const MockResponse) !MockSender {
        var sender = MockSender.init(allocator);
        errdefer sender.deinit();

        for (responses) |response| {
            try sender.pushResponse(response);
        }

        return sender;
    }

    pub fn deinit(self: *MockSender) void {
        for (self.responses.items) |response| {
            freeResponse(self.allocator, response);
        }
        self.responses.deinit(self.allocator);

        for (self.routes.items) |route| {
            route.deinit(self.allocator);
        }
        self.routes.deinit(self.allocator);

        for (self.requests.items) |request| {
            request.deinit(self.allocator);
        }
        self.requests.deinit(self.allocator);
    }

    pub fn hasHandler(self: *const MockSender) bool {
        return self.handler != null;
    }

    pub fn setHandler(self: *MockSender, handler: MockRequestHandler) void {
        self.handler = handler;
    }

    pub fn clearHandler(self: *MockSender) void {
        self.handler = null;
    }

    pub fn clearResponses(self: *MockSender) void {
        for (self.responses.items) |response| {
            freeResponse(self.allocator, response);
        }
        self.responses.clearRetainingCapacity();
    }

    pub fn pushResponse(self: *MockSender, response: MockResponse) !void {
        try self.responses.append(self.allocator, try cloneResponse(self.allocator, response));
    }

    pub fn pushJsonResponse(self: *MockSender, response_body: []const u8) !void {
        try self.pushResponse(.{ .json = response_body });
    }

    pub fn pushResultJson(self: *MockSender, result_json: []const u8) !void {
        try self.pushResponse(.{ .result_json = result_json });
    }

    pub fn pushRpcError(self: *MockSender, rpc_error: MockRpcError) !void {
        try self.pushResponse(.{ .rpc_error = rpc_error });
    }

    pub fn pushTransportError(self: *MockSender, transport_error: MockTransportError) !void {
        try self.pushResponse(.{ .transport_error = transport_error });
    }

    pub fn clearRoutes(self: *MockSender) void {
        for (self.routes.items) |route| {
            route.deinit(self.allocator);
        }
        self.routes.clearRetainingCapacity();
    }

    pub fn pushRoute(self: *MockSender, route: MockRoute) !void {
        try self.routes.append(self.allocator, try route.dupe(self.allocator));
    }

    pub fn pushResultRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        result_json: []const u8,
        remaining_uses: ?usize,
    ) !void {
        try self.pushRoute(.{
            .matcher = matcher,
            .response = .{ .result_json = result_json },
            .remaining_uses = remaining_uses,
        });
    }

    pub fn pushRpcErrorRoute(
        self: *MockSender,
        matcher: MockRequestMatcher,
        rpc_error: MockRpcError,
        remaining_uses: ?usize,
    ) !void {
        try self.pushRoute(.{
            .matcher = matcher,
            .response = .{ .rpc_error = rpc_error },
            .remaining_uses = remaining_uses,
        });
    }

    pub fn capturedRequests(self: *const MockSender) []const MockRequest {
        return self.requests.items;
    }

    pub fn clearCapturedRequests(self: *MockSender) void {
        for (self.requests.items) |request| {
            request.deinit(self.allocator);
        }
        self.requests.clearRetainingCapacity();
    }

    pub fn responseCount(self: *const MockSender) usize {
        return self.responses.items.len;
    }

    pub fn routeCount(self: *const MockSender) usize {
        return self.routes.items.len;
    }

    pub fn requestCount(self: *const MockSender) usize {
        return self.requests.items.len;
    }

    fn captureRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) !void {
        try self.requests.append(self.allocator, .{
            .id = id,
            .method = try self.allocator.dupe(u8, method),
            .params_json = try self.allocator.dupe(u8, params_json),
            .request_body = try self.allocator.dupe(u8, request_body),
        });
    }

    fn dequeueQueuedResponse(self: *MockSender, request_id: u64) ![]u8 {
        if (self.responses.items.len == 0) return error.MockResponseExhausted;

        const response = self.responses.orderedRemove(0);
        return switch (response) {
            .json => |value| @constCast(value),
            .result_json => |value| {
                defer self.allocator.free(value);
                return try formatResultEnvelope(self.allocator, request_id, value);
            },
            .rpc_error => |value| {
                defer value.deinit(self.allocator);
                return try formatRpcErrorEnvelope(self.allocator, request_id, value);
            },
            .transport_error => |value| switch (value) {
                .timeout => error.Timeout,
                .connection_reset => error.ConnectionResetByPeer,
                .http_error => error.HttpError,
            },
        };
    }

    fn maybeUseRoute(
        self: *MockSender,
        request: MockRequestView,
    ) !?[]u8 {
        for (self.routes.items, 0..) |*route, index| {
            if (!route.matcher.matches(request)) continue;

            const response = try cloneResponse(self.allocator, route.response);
            defer freeResponse(self.allocator, response);

            const should_remove = if (route.remaining_uses) |remaining| remaining <= 1 else false;
            if (route.remaining_uses) |remaining| {
                if (remaining > 1) {
                    route.remaining_uses = remaining - 1;
                }
            }

            const encoded: []u8 = switch (response) {
                .json => |value| try self.allocator.dupe(u8, value),
                .result_json => |value| try formatResultEnvelope(self.allocator, request.id, value),
                .rpc_error => |value| try formatRpcErrorEnvelope(self.allocator, request.id, value),
                .transport_error => |value| switch (value) {
                    .timeout => return error.Timeout,
                    .connection_reset => return error.ConnectionResetByPeer,
                    .http_error => return error.HttpError,
                },
            };

            if (should_remove) {
                var owned_route = self.routes.orderedRemove(index);
                owned_route.deinit(self.allocator);
            }

            return encoded;
        }

        return null;
    }

    pub fn sendRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        return try self.dispatchRequest(id, method, params_json, request_body);
    }

    fn handleWithCallback(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        const handler = self.handler orelse return error.MockResponseExhausted;
        const response = try handler.callback(handler.context, self.allocator, .{
            .id = id,
            .method = method,
            .params_json = params_json,
            .request_body = request_body,
        });

        return switch (response) {
            .json => |value| value,
            .result_json => |value| {
                defer self.allocator.free(value);
                return try formatResultEnvelope(self.allocator, id, value);
            },
            .rpc_error => |value| {
                defer value.deinit(self.allocator);
                return try formatRpcErrorEnvelope(self.allocator, id, value);
            },
            .transport_error => |value| switch (value) {
                .timeout => error.Timeout,
                .connection_reset => error.ConnectionResetByPeer,
                .http_error => error.HttpError,
            },
        };
    }

    pub fn dispatchRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        try self.captureRequest(id, method, params_json, request_body);

        if (self.responses.items.len > 0) {
            return try self.dequeueQueuedResponse(id);
        }

        if (try self.maybeUseRoute(.{
            .id = id,
            .method = method,
            .params_json = params_json,
            .request_body = request_body,
        })) |response| {
            return response;
        }

        return try self.handleWithCallback(id, method, params_json, request_body);
    }
};
