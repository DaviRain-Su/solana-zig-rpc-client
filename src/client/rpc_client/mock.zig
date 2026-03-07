const std = @import("std");

const Allocator = std.mem.Allocator;

pub const MockTransportError = enum {
    timeout,
    connection_reset,
    http_error,
};

pub const MockResponse = union(enum) {
    json: []const u8,
    transport_error: MockTransportError,
};

pub const MockRequestView = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,
};

pub const MockHandlerResponse = union(enum) {
    json: []u8,
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

pub const MockSender = struct {
    allocator: Allocator,
    responses: std.ArrayListUnmanaged(MockResponse) = .{},
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
            switch (response) {
                .json => |value| self.allocator.free(value),
                .transport_error => {},
            }
        }
        self.responses.deinit(self.allocator);

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
            switch (response) {
                .json => |value| self.allocator.free(value),
                .transport_error => {},
            }
        }
        self.responses.clearRetainingCapacity();
    }

    pub fn pushResponse(self: *MockSender, response: MockResponse) !void {
        try self.responses.append(self.allocator, switch (response) {
            .json => |value| .{ .json = try self.allocator.dupe(u8, value) },
            .transport_error => |value| .{ .transport_error = value },
        });
    }

    pub fn pushJsonResponse(self: *MockSender, response_body: []const u8) !void {
        try self.pushResponse(.{ .json = response_body });
    }

    pub fn pushTransportError(self: *MockSender, transport_error: MockTransportError) !void {
        try self.pushResponse(.{ .transport_error = transport_error });
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

    fn dequeueQueuedResponse(self: *MockSender) ![]u8 {
        if (self.responses.items.len == 0) return error.MockResponseExhausted;

        const response = self.responses.orderedRemove(0);
        return switch (response) {
            .json => |value| @constCast(value),
            .transport_error => |value| switch (value) {
                .timeout => error.Timeout,
                .connection_reset => error.ConnectionResetByPeer,
                .http_error => error.HttpError,
            },
        };
    }

    pub fn sendRequest(
        self: *MockSender,
        id: u64,
        method: []const u8,
        params_json: []const u8,
        request_body: []const u8,
    ) ![]u8 {
        try self.captureRequest(id, method, params_json, request_body);
        return try self.dequeueQueuedResponse();
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
            return try self.dequeueQueuedResponse();
        }

        return try self.handleWithCallback(id, method, params_json, request_body);
    }
};
