const std = @import("std");
const client = @import("solana_client_zig");
const websocket = @import("websocket");

fn reservePort() !u16 {
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    return listener.listen_address.getPort();
}

const TestApp = struct {
    allocator: std.mem.Allocator,
    signature_unsubscribe_seen: bool = false,
    account_unsubscribe_seen: bool = false,
    program_unsubscribe_seen: bool = false,
    slot_unsubscribe_seen: bool = false,
    root_unsubscribe_seen: bool = false,
};

const TestHandler = struct {
    conn: *websocket.Conn,
    app: *TestApp,

    pub fn init(_: *const websocket.Handshake, conn: *websocket.Conn, app: *TestApp) !TestHandler {
        return .{
            .conn = conn,
            .app = app,
        };
    }

    pub fn clientMessage(self: *TestHandler, data: []u8) !void {
        const ParsedRequest = struct {
            id: u64,
            method: []const u8,
        };

        var parsed = try std.json.parseFromSlice(ParsedRequest, self.app.allocator, data, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (std.mem.eql(u8, parsed.value.method, "signatureSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":41,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification = if (std.mem.indexOf(u8, data, "\"enableReceivedNotification\":true") != null)
                "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":\"receivedSignature\",\"subscription\":41}}"
            else
                "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":{\"context\":{\"slot\":99},\"value\":{\"err\":null}},\"subscription\":41}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "signatureUnsubscribe")) {
            self.app.signature_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "logsSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":52,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":123},\"value\":{\"signature\":\"5h6x\",\"err\":null,\"logs\":[\"program log: hi\"]}},\"subscription\":52}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "logsUnsubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "accountSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":61,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"accountNotification\",\"params\":{\"result\":{\"context\":{\"slot\":321},\"value\":{\"data\":{\"program\":\"nonce\",\"parsed\":{\"type\":\"initialized\"}},\"executable\":false,\"lamports\":777,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":4,\"space\":80}},\"subscription\":61}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "accountUnsubscribe")) {
            self.app.account_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "programSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":62,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"programNotification\",\"params\":{\"result\":{\"context\":{\"slot\":444},\"value\":{\"pubkey\":\"7YttLkHDoNj9wyQkL8vL7h4sQ6x9x1Fs6sT4m7G4S3xX\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\"}},\"executable\":false,\"lamports\":999,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":8,\"space\":165}}},\"subscription\":62}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "programUnsubscribe")) {
            self.app.program_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "slotSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":71,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"slotNotification\",\"params\":{\"result\":{\"parent\":11,\"root\":9,\"slot\":12},\"subscription\":71}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "slotUnsubscribe")) {
            self.app.slot_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "rootSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":72,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"rootNotification\",\"params\":{\"result\":456,\"subscription\":72}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "rootUnsubscribe")) {
            self.app.root_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }
    }
};

test "root.PubsubClient signatureSubscribe receives notifications and unsubscribes" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.signatureSubscribe(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .commitment = .confirmed },
    );
    defer subscription.deinit();

    var notification = try subscription.recvParsed(client.SignatureNotificationValue);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 99), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.err == null);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubClient logsSubscribe parses log notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.logsSubscribe(
        .{ .mentions = "11111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscription.deinit();

    var notification = try subscription.recvParsed(client.LogsNotificationValue);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 52), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 123), notification.notification.context_slot);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.signature);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.logs.len);
    try std.testing.expectEqualStrings("program log: hi", notification.notification.value.logs[0]);

    try std.testing.expect(try subscription.unsubscribe());
}

test "root.PubsubClient signatureSubscribe parses receivedSignature notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.signatureSubscribe(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .enable_received_notification = true },
    );
    defer subscription.deinit();

    var notification = try subscription.recvSignatureNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, null), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.received_signature);
    try std.testing.expect(notification.notification.value.err == null);
}

test "root.PubsubClient accountSubscribe receives typed account notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.accountSubscribe(
        "11111111111111111111111111111111",
        .{ .commitment = .processed, .encoding = .json_parsed },
    );
    defer subscription.deinit();

    var notification = try subscription.recvAccountNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 61), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 321), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 777), notification.notification.value.lamports);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", notification.notification.value.owner);
    try std.testing.expectEqual(@as(?u64, 4), notification.notification.value.rentEpoch);
    try std.testing.expectEqual(@as(?u64, 80), notification.notification.value.space);
    try std.testing.expect(notification.notification.value.data == .object);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.account_unsubscribe_seen);
}

test "root.PubsubClient programSubscribe receives typed program notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.programSubscribe(
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
        .{
            .commitment = .confirmed,
            .encoding = .json_parsed,
            .data_size = 165,
            .memcmp_offset = 32,
            .memcmp_bytes = "11111111111111111111111111111111",
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvProgramNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 62), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 444), notification.notification.context_slot);
    try std.testing.expectEqualStrings("7YttLkHDoNj9wyQkL8vL7h4sQ6x9x1Fs6sT4m7G4S3xX", notification.notification.value.pubkey);
    try std.testing.expectEqual(@as(u64, 999), notification.notification.value.account.lamports);
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", notification.notification.value.account.owner);
    try std.testing.expectEqual(@as(?u64, 8), notification.notification.value.account.rentEpoch);
    try std.testing.expectEqual(@as(?u64, 165), notification.notification.value.account.space);
    try std.testing.expect(notification.notification.value.account.data == .object);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.program_unsubscribe_seen);
}

test "root.PubsubClient slotSubscribe receives slot notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.slotSubscribe();
    defer subscription.deinit();

    var notification = try subscription.recvSlotNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 71), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, null), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 11), notification.notification.value.parent);
    try std.testing.expectEqual(@as(u64, 9), notification.notification.value.root);
    try std.testing.expectEqual(@as(u64, 12), notification.notification.value.slot);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.slot_unsubscribe_seen);
}

test "root.PubsubClient rootSubscribe receives root notifications" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{ .allocator = std.testing.allocator };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.init(std.testing.allocator, endpoint);
    defer pubsub.deinit();

    const subscription = try pubsub.rootSubscribe();
    defer subscription.deinit();

    var notification = try subscription.recvRootNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 72), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, null), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 456), notification.notification.value);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.root_unsubscribe_seen);
}
