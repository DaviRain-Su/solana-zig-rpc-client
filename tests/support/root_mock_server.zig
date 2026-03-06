const std = @import("std");

const Allocator = std.mem.Allocator;

fn acceptMockRootConnection(listener: *std.net.Server) ?std.net.Server.Connection {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = listener.stream.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    const ready = std.posix.poll(&poll_fds, 500) catch return null;
    if (ready == 0) return null;
    if (poll_fds[0].revents & std.posix.POLL.IN != std.posix.POLL.IN) return null;

    return listener.accept() catch return null;
}

pub fn runMockRootServer(listener: *std.net.Server, allocator: Allocator, response_body: []const u8) void {
    var connection = acceptMockRootConnection(listener) orelse return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var request_body_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&request_body_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request.respond(response_body, .{}) catch return;
}

pub fn runMockRootServerSequence(listener: *std.net.Server, allocator: Allocator, response_bodies: []const []const u8) void {
    for (response_bodies) |response_body| {
        var connection = acceptMockRootConnection(listener) orelse return;
        defer connection.stream.close();

        var receive_buffer: [4096]u8 = undefined;
        var request_body_buffer: [4096]u8 = undefined;
        var send_buffer: [4096]u8 = undefined;
        var connection_reader = connection.stream.reader(&receive_buffer);
        var connection_writer = connection.stream.writer(&send_buffer);
        var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

        var request = http_server.receiveHead() catch return;
        const body_length = request.head.content_length orelse 0;
        const request_body_reader = request.readerExpectNone(&request_body_buffer);
        const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
        defer allocator.free(request_body);

        request.respond(response_body, .{}) catch return;
    }
}

pub fn runMockRootServerCaptureSequence(
    listener: *std.net.Server,
    allocator: Allocator,
    request_captures: *std.ArrayList([]u8),
    response_bodies: []const []const u8,
) void {
    for (response_bodies) |response_body| {
        var connection = acceptMockRootConnection(listener) orelse return;
        defer connection.stream.close();

        var receive_buffer: [4096]u8 = undefined;
        var request_body_buffer: [4096]u8 = undefined;
        var send_buffer: [4096]u8 = undefined;
        var connection_reader = connection.stream.reader(&receive_buffer);
        var connection_writer = connection.stream.writer(&send_buffer);
        var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

        var request = http_server.receiveHead() catch return;
        const body_length = request.head.content_length orelse 0;
        const request_body_reader = request.readerExpectNone(&request_body_buffer);
        const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
        defer allocator.free(request_body);

        const request_body_copy = allocator.dupe(u8, request_body) catch return;
        request_captures.append(allocator, request_body_copy) catch {
            allocator.free(request_body_copy);
            return;
        };

        request.respond(response_body, .{}) catch return;
    }
}
