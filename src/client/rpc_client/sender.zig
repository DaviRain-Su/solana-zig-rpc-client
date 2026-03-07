const std = @import("std");
const mock_methods = @import("./mock.zig");

const Allocator = std.mem.Allocator;
const MockSender = mock_methods.MockSender;

pub const RequestSenderRequest = struct {
    id: u64,
    method: []const u8,
    params_json: []const u8,
    request_body: []const u8,
};

pub const RequestSender = struct {
    context: ?*anyopaque = null,
    callback: *const fn (context: ?*anyopaque, allocator: Allocator, request: RequestSenderRequest) anyerror![]u8,
    deinit_callback: ?*const fn (context: ?*anyopaque, allocator: Allocator) void = null,

    pub fn fromMockSender(sender: *MockSender) RequestSender {
        return .{
            .context = sender,
            .callback = mockSenderRequestCallback,
        };
    }

    pub fn fromOwnedMockSender(allocator: Allocator, sender: MockSender) !RequestSender {
        var owned_sender = sender;
        errdefer owned_sender.deinit();

        const sender_ptr = try allocator.create(MockSender);
        sender_ptr.* = owned_sender;
        return .{
            .context = sender_ptr,
            .callback = mockSenderRequestCallback,
            .deinit_callback = ownedMockSenderDeinit,
        };
    }

    pub fn deinit(self: RequestSender, allocator: Allocator) void {
        if (self.deinit_callback) |callback| callback(self.context, allocator);
    }
};

fn mockSenderRequestCallback(
    context_ptr: ?*anyopaque,
    allocator: Allocator,
    request: RequestSenderRequest,
) ![]u8 {
    _ = allocator;
    const sender: *MockSender = @ptrCast(@alignCast(context_ptr.?));
    return sender.dispatchRequest(request.id, request.method, request.params_json, request.request_body);
}

fn ownedMockSenderDeinit(context_ptr: ?*anyopaque, allocator: Allocator) void {
    const sender: *MockSender = @ptrCast(@alignCast(context_ptr.?));
    sender.deinit();
    allocator.destroy(sender);
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

pub fn encodeJsonRpcResultEnvelope(
    allocator: Allocator,
    request_id: u64,
    result_json: []const u8,
) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{s},\"id\":{}}}",
        .{ result_json, request_id },
    );
}

pub fn encodeJsonRpcErrorEnvelope(
    allocator: Allocator,
    request_id: u64,
    rpc_error: mock_methods.MockRpcError,
) ![]u8 {
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
