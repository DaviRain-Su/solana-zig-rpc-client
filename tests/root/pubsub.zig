const std = @import("std");
const client = @import("solana_client_zig");
const websocket = @import("websocket");

fn reservePort() !u16 {
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    return listener.listen_address.getPort();
}

fn waitForQueuedCount(subscription: *client.PubsubSubscription, expected: usize, timeout_ms: u64) !void {
    const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ms * std.time.ns_per_ms));
    while (std.time.nanoTimestamp() < deadline) {
        if (subscription.queuedCount() == expected) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn waitForClosed(subscription: *client.PubsubSubscription, timeout_ms: u64) !void {
    const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ms * std.time.ns_per_ms));
    while (std.time.nanoTimestamp() < deadline) {
        if (subscription.isClosed()) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn waitForReconnecting(pubsub: *const client.PubsubClient, timeout_ms: u64) !void {
    const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ms * std.time.ns_per_ms));
    while (std.time.nanoTimestamp() < deadline) {
        if (pubsub.isReconnecting()) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn waitForHeartbeatPingCount(app: *TestApp, expected: usize, timeout_ms: u64) !void {
    const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ms * std.time.ns_per_ms));
    while (std.time.nanoTimestamp() < deadline) {
        app.mutex.lock();
        const ping_count = app.heartbeat_ping_count;
        app.mutex.unlock();
        if (ping_count >= expected) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn waitForBackoffReconnectCount(app: *TestApp, expected: usize, timeout_ms: u64) !void {
    const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ms * std.time.ns_per_ms));
    while (std.time.nanoTimestamp() < deadline) {
        app.mutex.lock();
        const reconnect_count = app.reconnect_backoff_subscribe_count;
        app.mutex.unlock();
        if (reconnect_count >= expected) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
    return error.Timeout;
}

fn reconnectBackoffTime(app: *TestApp, index: usize) i64 {
    app.mutex.lock();
    defer app.mutex.unlock();
    return app.reconnect_backoff_subscribe_times_ns[index];
}

const TestApp = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    signature_unsubscribe_seen: bool = false,
    logs_unsubscribe_seen: bool = false,
    account_unsubscribe_seen: bool = false,
    program_unsubscribe_seen: bool = false,
    slot_unsubscribe_seen: bool = false,
    root_unsubscribe_seen: bool = false,
    slots_updates_unsubscribe_seen: bool = false,
    vote_unsubscribe_seen: bool = false,
    block_unsubscribe_seen: bool = false,
    reconnect_signature_subscribe_count: usize = 0,
    reconnect_cancel_signature_subscribe_count: usize = 0,
    heartbeat_ping_count: usize = 0,
    reply_to_client_ping: bool = true,
    reconnect_backoff_subscribe_count: usize = 0,
    reconnect_backoff_subscribe_times_ns: [4]i64 = .{ 0, 0, 0, 0 },
    signature_subscribe_error_seen: bool = false,
    signature_unsubscribe_error_seen: bool = false,
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
            if (std.mem.indexOf(u8, data, "SubscribeError11111111111111111111111111111111") != null) {
                self.app.signature_subscribe_error_seen = true;
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":-32010,\"message\":\"signature subscribe failed\"}},\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);
                return;
            }

            if (std.mem.indexOf(u8, data, "Reconnect1111111111111111111111111111111111111") != null) {
                self.app.reconnect_signature_subscribe_count += 1;
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":{},\"id\":{}}}",
                    .{ 140 + self.app.reconnect_signature_subscribe_count, parsed.value.id },
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                if (self.app.reconnect_signature_subscribe_count == 1) {
                    const notification =
                        "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":{\"context\":{\"slot\":501},\"value\":{\"err\":null}},\"subscription\":141}}";
                    try self.conn.write(notification);
                    try self.conn.close(.{});
                } else {
                    const notification =
                        "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":{\"context\":{\"slot\":777},\"value\":{\"err\":null}},\"subscription\":142}}";
                    try self.conn.write(notification);
                }
                return;
            }

            if (std.mem.indexOf(u8, data, "ReconnectCancel1111111111111111111111111111111") != null) {
                self.app.reconnect_cancel_signature_subscribe_count += 1;
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":{},\"id\":{}}}",
                    .{ 340 + self.app.reconnect_cancel_signature_subscribe_count, parsed.value.id },
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                if (self.app.reconnect_cancel_signature_subscribe_count == 1) {
                    try self.conn.close(.{});
                }
                return;
            }

            if (std.mem.indexOf(u8, data, "UnsubError1111111111111111111111111111111111") != null) {
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":145,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);
                return;
            }

            if (std.mem.indexOf(u8, data, "BackoffReconnect11111111111111111111111111111") != null) {
                self.app.mutex.lock();
                self.app.reconnect_backoff_subscribe_count += 1;
                const reconnect_count = self.app.reconnect_backoff_subscribe_count;
                if (reconnect_count < self.app.reconnect_backoff_subscribe_times_ns.len) {
                    self.app.reconnect_backoff_subscribe_times_ns[reconnect_count] = @as(i64, @intCast(std.time.nanoTimestamp()));
                }
                self.app.mutex.unlock();

                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":{},\"id\":{}}}",
                    .{ 240 + reconnect_count, parsed.value.id },
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                if (reconnect_count < 3) {
                    std.Thread.sleep(10 * std.time.ns_per_ms);
                    try self.conn.close(.{});
                } else {
                    const notification =
                        "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":{\"context\":{\"slot\":888},\"value\":{\"err\":null}},\"subscription\":243}}";
                    try self.conn.write(notification);
                }
                return;
            }

            if (std.mem.indexOf(u8, data, "ErrorSig11111111111111111111111111111111111111") != null) {
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":43,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notification =
                    "{\"jsonrpc\":\"2.0\",\"method\":\"signatureNotification\",\"params\":{\"result\":{\"context\":{\"slot\":199},\"value\":{\"err\":{\"InstructionError\":[1,{\"Custom\":6001}]}}},\"subscription\":43}}";
                try self.conn.write(notification);
                return;
            }

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
            if (std.mem.indexOf(u8, data, "\"params\":[145]") != null) {
                self.app.signature_unsubscribe_error_seen = true;
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":-32011,\"message\":\"signature unsubscribe failed\"}},\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);
                return;
            }

            if (std.mem.indexOf(u8, data, "\"params\":[142]") != null) {
                self.app.signature_unsubscribe_seen = true;
            }
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
            if (std.mem.indexOf(u8, data, "BurstDrop111111111111111111111111111111111111") != null) {
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":54,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notifications = [_][]const u8{
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":201},\"value\":{\"signature\":\"drop1\",\"err\":null,\"logs\":[\"program log: 1\"]}},\"subscription\":54}}",
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":202},\"value\":{\"signature\":\"drop2\",\"err\":null,\"logs\":[\"program log: 2\"]}},\"subscription\":54}}",
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":203},\"value\":{\"signature\":\"drop3\",\"err\":null,\"logs\":[\"program log: 3\"]}},\"subscription\":54}}",
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":204},\"value\":{\"signature\":\"drop4\",\"err\":null,\"logs\":[\"program log: 4\"]}},\"subscription\":54}}",
                };
                for (notifications) |notification| {
                    try self.conn.write(notification);
                }
                return;
            }

            if (std.mem.indexOf(u8, data, "BurstClose11111111111111111111111111111111111") != null) {
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":55,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notifications = [_][]const u8{
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":301},\"value\":{\"signature\":\"close1\",\"err\":null,\"logs\":[\"program log: keep\"]}},\"subscription\":55}}",
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":302},\"value\":{\"signature\":\"close2\",\"err\":null,\"logs\":[\"program log: overflow\"]}},\"subscription\":55}}",
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":303},\"value\":{\"signature\":\"close3\",\"err\":null,\"logs\":[\"program log: ignored\"]}},\"subscription\":55}}",
                };
                for (notifications) |notification| {
                    try self.conn.write(notification);
                }
                return;
            }

            if (std.mem.indexOf(u8, data, "Err111111111111111111111111111111111111111") != null) {
                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":53,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notification =
                    "{\"jsonrpc\":\"2.0\",\"method\":\"logsNotification\",\"params\":{\"result\":{\"context\":{\"slot\":124},\"value\":{\"signature\":\"7err\",\"err\":{\"InstructionError\":[0,\"InvalidArgument\"]},\"logs\":[\"program log: fail\",\"program consumed 1 of 200000 compute units\"]}},\"subscription\":53}}";
                try self.conn.write(notification);
                return;
            }

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
            self.app.logs_unsubscribe_seen = true;
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
                "{\"jsonrpc\":\"2.0\",\"method\":\"accountNotification\",\"params\":{\"result\":{\"context\":{\"slot\":321},\"value\":{\"data\":{\"program\":\"nonce\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth1111111111111111111111111111111111111\",\"blockhash\":\"NonceBlockhash111111111111111111111111111111\",\"lamportsPerSignature\":5000}}},\"executable\":false,\"lamports\":777,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":4,\"space\":80}},\"subscription\":61}}";
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
                "{\"jsonrpc\":\"2.0\",\"method\":\"programNotification\",\"params\":{\"result\":{\"context\":{\"slot\":444},\"value\":{\"pubkey\":\"7YttLkHDoNj9wyQkL8vL7h4sQ6x9x1Fs6sT4m7G4S3xX\",\"account\":{\"data\":{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{\"mint\":\"Mint111111111111111111111111111111111111111\",\"owner\":\"Owner1111111111111111111111111111111111111\",\"state\":\"initialized\",\"tokenAmount\":{\"amount\":\"42\",\"decimals\":9,\"uiAmountString\":\"0.000000042\"}}}},\"executable\":false,\"lamports\":999,\"owner\":\"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA\",\"rentEpoch\":8,\"space\":165}}},\"subscription\":62}}";
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

        if (std.mem.eql(u8, parsed.value.method, "slotsUpdatesSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":73,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"slotsUpdatesNotification\",\"params\":{\"result\":{\"parent\":44,\"slot\":45,\"timestamp\":1710000000,\"type\":\"frozen\",\"stats\":{\"maxTransactionsPerEntry\":64,\"numFailedTransactions\":2,\"numSuccessfulTransactions\":10,\"numTransactionEntries\":3}},\"subscription\":73}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "slotsUpdatesUnsubscribe")) {
            self.app.slots_updates_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "voteSubscribe")) {
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":74,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"voteNotification\",\"params\":{\"result\":{\"hash\":\"7fK4nkmxQZ7QBY9Lfe1dSDA6n9yM4eGJdJm1Qf8E2QpN\",\"slots\":[101,102],\"timestamp\":1710000100,\"signature\":\"5h6x\",\"votePubkey\":\"Vote111111111111111111111111111111111111111\"},\"subscription\":74}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "voteUnsubscribe")) {
            self.app.vote_unsubscribe_seen = true;
            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":true,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "blockSubscribe")) {
            try std.testing.expect(std.mem.indexOf(u8, data, "\"mentionsAccountOrProgram\":\"11111111111111111111111111111111\"") != null);
            try std.testing.expect(std.mem.indexOf(u8, data, "\"commitment\":\"finalized\"") != null);
            try std.testing.expect(std.mem.indexOf(u8, data, "\"encoding\":\"json\"") != null);
            try std.testing.expect(std.mem.indexOf(u8, data, "\"maxSupportedTransactionVersion\":0") != null);
            if (std.mem.indexOf(u8, data, "\"transactionDetails\":\"accounts\"") != null) {
                try std.testing.expect(std.mem.indexOf(u8, data, "\"showRewards\":false") != null);

                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":77,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notification =
                    "{\"jsonrpc\":\"2.0\",\"method\":\"blockNotification\",\"params\":{\"result\":{\"context\":{\"slot\":907},\"value\":{\"slot\":906,\"err\":null,\"block\":{\"blockhash\":\"AccountsBlockhash1111111111111111111111111111\",\"previousBlockhash\":\"AccountsPrev111111111111111111111111111111\",\"parentSlot\":905,\"blockHeight\":601,\"blockTime\":1710000300,\"transactions\":[{\"transaction\":{\"signatures\":[\"accsig1\"],\"accountKeys\":[{\"pubkey\":\"11111111111111111111111111111111\",\"signer\":true,\"writable\":true,\"source\":\"transaction\"},{\"pubkey\":\"Lookup1111111111111111111111111111111111111\",\"signer\":false,\"writable\":false,\"source\":\"lookupTable\"}]}}],\"rewards\":[]}}},\"subscription\":77}}";
                try self.conn.write(notification);
                return;
            }

            if (std.mem.indexOf(u8, data, "\"transactionDetails\":\"full\"") != null) {
                try std.testing.expect(std.mem.indexOf(u8, data, "\"showRewards\":true") != null);

                const response = try std.fmt.allocPrint(
                    self.app.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"result\":76,\"id\":{}}}",
                    .{parsed.value.id},
                );
                defer self.app.allocator.free(response);
                try self.conn.write(response);

                const notification =
                    "{\"jsonrpc\":\"2.0\",\"method\":\"blockNotification\",\"params\":{\"result\":{\"context\":{\"slot\":905},\"value\":{\"slot\":904,\"err\":null,\"block\":{\"blockhash\":\"FullBlockhash11111111111111111111111111111111\",\"previousBlockhash\":\"FullPrev11111111111111111111111111111111111\",\"parentSlot\":903,\"blockHeight\":502,\"blockTime\":1710000200,\"transactions\":[{\"version\":\"legacy\",\"meta\":{\"err\":null,\"fee\":5000,\"logMessages\":[\"program log: one\",\"program log: two\"]},\"transaction\":{\"signatures\":[\"9abc\",\"9def\"],\"message\":{\"accountKeys\":[\"11111111111111111111111111111111\",\"Sysvar1111111111111111111111111111111111111\",\"Program111111111111111111111111111111111111\"],\"instructions\":[{\"programIdIndex\":2,\"accounts\":[0,1],\"data\":\"3Bxs4M\"},{\"programIdIndex\":2,\"accounts\":[1],\"data\":\"7Z\"}],\"addressTableLookups\":[{\"accountKey\":\"LookupTable1111111111111111111111111111111\",\"writableIndexes\":[0],\"readonlyIndexes\":[1]}]}}},{\"version\":0,\"meta\":{\"err\":{\"InstructionError\":[1,{\"Custom\":6001}]},\"fee\":7000,\"logMessages\":[\"program log: fail\"],\"loadedAddresses\":{\"writable\":[\"LoadedWritable11111111111111111111111111111\"],\"readonly\":[\"LoadedReadonly1111111111111111111111111111\",\"LoadedReadonly2222222222222222222222222222\"]}},\"transaction\":{\"signatures\":[\"7xyz\"],\"message\":{\"accountKeys\":[\"FeePayer11111111111111111111111111111111111\"],\"instructions\":[{\"programIdIndex\":0,\"accounts\":[0],\"data\":\"9Q\"}],\"addressTableLookups\":[]}}}],\"rewards\":[{\"pubkey\":\"Reward111111111111111111111111111111111111\"}]}}},\"subscription\":76}}";
                try self.conn.write(notification);
                return;
            }

            try std.testing.expect(std.mem.indexOf(u8, data, "\"transactionDetails\":\"signatures\"") != null);
            try std.testing.expect(std.mem.indexOf(u8, data, "\"showRewards\":false") != null);

            const response = try std.fmt.allocPrint(
                self.app.allocator,
                "{{\"jsonrpc\":\"2.0\",\"result\":75,\"id\":{}}}",
                .{parsed.value.id},
            );
            defer self.app.allocator.free(response);
            try self.conn.write(response);

            const notification =
                "{\"jsonrpc\":\"2.0\",\"method\":\"blockNotification\",\"params\":{\"result\":{\"context\":{\"slot\":901},\"value\":{\"slot\":900,\"err\":null,\"block\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"previousBlockhash\":\"Prev111111111111111111111111111111111111111\",\"parentSlot\":899,\"transactions\":[{\"transaction\":{\"signatures\":[\"5h6x\"]}}],\"rewards\":[]}}},\"subscription\":75}}";
            try self.conn.write(notification);
            return;
        }

        if (std.mem.eql(u8, parsed.value.method, "blockUnsubscribe")) {
            self.app.block_unsubscribe_seen = true;
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

    pub fn clientPing(self: *TestHandler, data: []u8) !void {
        self.app.mutex.lock();
        self.app.heartbeat_ping_count += 1;
        const reply_to_client_ping = self.app.reply_to_client_ping;
        self.app.mutex.unlock();

        if (reply_to_client_ping) {
            try self.conn.writeFrame(.pong, data);
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

test "root.PubsubClient signatureSubscribe surfaces RPC subscribe errors" {
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

    try std.testing.expectError(
        error.SubscribeRpcError,
        pubsub.signatureSubscribe(
            "SubscribeError11111111111111111111111111111111",
            .{},
        ),
    );

    try std.testing.expect(app.signature_subscribe_error_seen);
    const last_error = pubsub.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32010), last_error.code);
    try std.testing.expectEqualStrings("signature subscribe failed", last_error.message);
}

test "root.PubsubSubscription unsubscribe surfaces RPC errors and leaves subscription active" {
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
        "UnsubError1111111111111111111111111111111111",
        .{},
    );
    defer subscription.deinit();

    try std.testing.expectError(error.UnsubscribeRpcError, subscription.unsubscribe());
    try std.testing.expect(app.signature_unsubscribe_error_seen);
    try std.testing.expect(!subscription.isClosed());
    try std.testing.expectEqual(client.PubsubCloseReason.none, subscription.closeReason());

    const subscription_error = subscription.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32011), subscription_error.code);
    try std.testing.expectEqualStrings("signature unsubscribe failed", subscription_error.message);

    const client_error = pubsub.getLastError() orelse return error.TestExpectedError;
    try std.testing.expectEqual(@as(i64, -32011), client_error.code);
    try std.testing.expectEqualStrings("signature unsubscribe failed", client_error.message);

    const close_result = subscription.closeResult();
    try std.testing.expectEqual(client.PubsubCloseReason.none, close_result.reason);
    try std.testing.expectEqual(@as(usize, 0), close_result.dropped_messages);
    try std.testing.expect(close_result.last_error != null);
    try std.testing.expectEqual(@as(i64, -32011), close_result.last_error.?.code);
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

test "root.PubsubSubscription parses signature summary notifications" {
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
        "ErrorSig11111111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer subscription.deinit();

    var notification = try subscription.recvSignatureSummaryNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 43), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 199), notification.notification.context_slot);
    try std.testing.expect(!notification.notification.value.receivedSignature);
    try std.testing.expect(notification.notification.value.hasError);
    try std.testing.expectEqualStrings(
        "{\"InstructionError\":[1,{\"Custom\":6001}]}",
        notification.notification.value.errJson.?,
    );
}

test "root.PubsubReceiver parses logs summary notifications with error payloads" {
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
        .{ .mentions = "Err111111111111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscription.deinit();

    var receiver = subscription.receiver();
    var notification = try receiver.recvLogsSummaryNotificationTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 53), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 124), notification.notification.context_slot);
    try std.testing.expectEqualStrings("7err", notification.notification.value.signature);
    try std.testing.expect(notification.notification.value.hasError);
    try std.testing.expectEqualStrings(
        "{\"InstructionError\":[0,\"InvalidArgument\"]}",
        notification.notification.value.errJson.?,
    );
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.logsCount);
    try std.testing.expectEqualStrings("program log: fail", notification.notification.value.firstLog.?);
}

test "root.PubsubSubscription drops oldest notifications when queue limit is exceeded" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .subscription_queue_limit = 2,
        .queue_overflow_policy = .drop_oldest,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.logsSubscribe(
        .{ .mentions = "BurstDrop111111111111111111111111111111111111" },
        .{},
    );
    defer subscription.deinit();

    try waitForQueuedCount(subscription, 2, 1000);
    try std.testing.expectEqual(@as(usize, 2), subscription.queuedCount());
    try std.testing.expectEqual(@as(usize, 2), subscription.droppedCount());
    try std.testing.expectEqual(client.PubsubCloseReason.none, subscription.closeReason());

    var first = try subscription.recvLogsNotification();
    defer first.deinit();
    var second = try subscription.recvLogsNotification();
    defer second.deinit();

    try std.testing.expectEqualStrings("drop3", first.notification.value.signature);
    try std.testing.expectEqualStrings("drop4", second.notification.value.signature);
    try std.testing.expectEqualStrings("program log: 3", first.notification.value.logs[0]);
    try std.testing.expectEqualStrings("program log: 4", second.notification.value.logs[0]);
}

test "root.PubsubSubscription can close on queue overflow" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .subscription_queue_limit = 1,
        .queue_overflow_policy = .close_subscription,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.logsSubscribe(
        .{ .mentions = "BurstClose11111111111111111111111111111111111" },
        .{},
    );
    defer subscription.deinit();

    try waitForClosed(subscription, 1000);
    try std.testing.expect(subscription.isClosed());
    try std.testing.expectEqual(@as(usize, 1), subscription.queuedCount());
    try std.testing.expectEqual(@as(usize, 1), subscription.droppedCount());
    try std.testing.expectEqual(client.PubsubCloseReason.queue_overflow, subscription.closeReason());

    var first = try subscription.recvLogsNotification();
    defer first.deinit();
    try std.testing.expectEqualStrings("close1", first.notification.value.signature);
    try std.testing.expectError(error.Closed, subscription.recv());
}

test "root.PubsubClient heartbeat sends websocket ping frames" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .heartbeat_interval_ms = 20,
        .heartbeat_timeout_ms = 80,
    });
    defer pubsub.deinit();

    try waitForHeartbeatPingCount(&app, 1, 1000);

    app.mutex.lock();
    const ping_count = app.heartbeat_ping_count;
    app.mutex.unlock();
    try std.testing.expect(ping_count >= 1);
}

test "root.PubsubClient heartbeat timeout closes subscriptions when server stops replying to ping" {
    const port = try reservePort();
    var server = try websocket.Server(TestHandler).init(std.testing.allocator, .{
        .port = port,
        .address = "127.0.0.1",
    });
    defer server.deinit();

    var app = TestApp{
        .allocator = std.testing.allocator,
        .reply_to_client_ping = false,
    };
    const server_thread = try server.listenInNewThread(&app);
    defer server_thread.join();
    defer server.stop();

    const endpoint = try std.fmt.allocPrint(std.testing.allocator, "ws://127.0.0.1:{d}/", .{port});
    defer std.testing.allocator.free(endpoint);

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .heartbeat_interval_ms = 20,
        .heartbeat_timeout_ms = 40,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.rootSubscribe();
    defer subscription.deinit();

    try waitForHeartbeatPingCount(&app, 1, 1000);
    try waitForClosed(subscription, 1000);
    try std.testing.expectEqual(client.PubsubCloseReason.transport_closed, subscription.closeReason());
}

test "root.PubsubClient reconnect backoff increases delay across retries" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .auto_reconnect = true,
        .reconnect_delay_ms = 20,
        .reconnect_backoff_factor = 2,
        .reconnect_max_delay_ms = 40,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.signatureSubscribe(
        "BackoffReconnect11111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer subscription.deinit();

    try waitForBackoffReconnectCount(&app, 3, 2000);

    var notification = try subscription.recvParsedTimeout(client.SignatureNotificationValue, 2000);
    defer notification.deinit();
    try std.testing.expectEqual(@as(?u64, 888), notification.notification.context_slot);

    const first_time_ns = reconnectBackoffTime(&app, 1);
    const second_time_ns = reconnectBackoffTime(&app, 2);
    const third_time_ns = reconnectBackoffTime(&app, 3);

    try std.testing.expect(second_time_ns > first_time_ns);
    try std.testing.expect(third_time_ns > second_time_ns);
    try std.testing.expect(second_time_ns - first_time_ns >= 15 * std.time.ns_per_ms);
    try std.testing.expect(third_time_ns - second_time_ns >= 30 * std.time.ns_per_ms);
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

test "root.PubsubClient accountSubscribe parses account summary notifications" {
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

    var notification = try subscription.recvAccountSummaryNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 61), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 321), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 777), notification.notification.value.lamports);
    try std.testing.expectEqualStrings("11111111111111111111111111111111", notification.notification.value.owner);
    try std.testing.expectEqual(@as(?u64, 4), notification.notification.value.rentEpoch);
    try std.testing.expectEqual(@as(?u64, 80), notification.notification.value.space);
    try std.testing.expect(notification.notification.value.dataSummary != null);
    try std.testing.expectEqualStrings("nonce", notification.notification.value.dataSummary.?.program.?);
    try std.testing.expectEqualStrings("initialized", notification.notification.value.dataSummary.?.parsedType.?);
    try std.testing.expect(notification.notification.value.dataSummary.?.info != null);
    try std.testing.expectEqualStrings("Auth1111111111111111111111111111111111111", notification.notification.value.dataSummary.?.info.?.authority.?);
    try std.testing.expectEqualStrings("NonceBlockhash111111111111111111111111111111", notification.notification.value.dataSummary.?.info.?.blockhash.?);
    try std.testing.expectEqual(@as(?u64, 5000), notification.notification.value.dataSummary.?.info.?.lamportsPerSignature);
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

test "root.PubsubClient programSubscribe parses program summary notifications" {
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

    var notification = try subscription.recvProgramSummaryNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 62), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 444), notification.notification.context_slot);
    try std.testing.expectEqualStrings("7YttLkHDoNj9wyQkL8vL7h4sQ6x9x1Fs6sT4m7G4S3xX", notification.notification.value.pubkey);
    try std.testing.expectEqual(@as(u64, 999), notification.notification.value.account.lamports);
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", notification.notification.value.account.owner);
    try std.testing.expect(notification.notification.value.account.dataSummary != null);
    try std.testing.expectEqualStrings("spl-token", notification.notification.value.account.dataSummary.?.program.?);
    try std.testing.expectEqualStrings("account", notification.notification.value.account.dataSummary.?.parsedType.?);
    try std.testing.expect(notification.notification.value.account.dataSummary.?.info != null);
    try std.testing.expectEqualStrings("Mint111111111111111111111111111111111111111", notification.notification.value.account.dataSummary.?.info.?.mint.?);
    try std.testing.expectEqualStrings("Owner1111111111111111111111111111111111111", notification.notification.value.account.dataSummary.?.info.?.owner.?);
    try std.testing.expectEqualStrings("initialized", notification.notification.value.account.dataSummary.?.info.?.state.?);
    try std.testing.expectEqualStrings("42", notification.notification.value.account.dataSummary.?.info.?.tokenAmountAmount.?);
    try std.testing.expectEqual(@as(?u8, 9), notification.notification.value.account.dataSummary.?.info.?.tokenAmountDecimals);
    try std.testing.expectEqualStrings("0.000000042", notification.notification.value.account.dataSummary.?.info.?.tokenAmountUiAmountString.?);
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

test "root.PubsubSubscription receiver view supports typed receive and timeout" {
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

    var receiver = subscription.receiver();
    try std.testing.expect(receiver.queuedCount() <= 1);

    var notification = try receiver.recvRootNotificationTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 72), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 456), notification.notification.value);
    try std.testing.expectEqual(@as(usize, 0), receiver.queuedCount());
    try std.testing.expectError(error.Timeout, receiver.recvTimeout(10));

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.root_unsubscribe_seen);
}

test "root.PubsubClient slotsUpdatesSubscribe receives slots update notifications" {
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

    const subscription = try pubsub.slotsUpdatesSubscribe();
    defer subscription.deinit();

    var notification = try subscription.recvSlotsUpdatesNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 73), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, null), notification.notification.context_slot);
    try std.testing.expectEqualStrings("frozen", notification.notification.value.type);
    try std.testing.expectEqual(@as(u64, 44), notification.notification.value.parent.?);
    try std.testing.expectEqual(@as(u64, 45), notification.notification.value.slot);
    try std.testing.expectEqual(@as(i64, 1710000000), notification.notification.value.timestamp);
    try std.testing.expect(notification.notification.value.stats != null);
    try std.testing.expectEqual(@as(u64, 64), notification.notification.value.stats.?.maxTransactionsPerEntry);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.slots_updates_unsubscribe_seen);
}

test "root.PubsubClient voteSubscribe receives vote notifications" {
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

    const subscription = try pubsub.voteSubscribe();
    defer subscription.deinit();

    var notification = try subscription.recvVoteNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 74), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, null), notification.notification.context_slot);
    try std.testing.expectEqualStrings("7fK4nkmxQZ7QBY9Lfe1dSDA6n9yM4eGJdJm1Qf8E2QpN", notification.notification.value.hash);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.slots.len);
    try std.testing.expectEqual(@as(u64, 101), notification.notification.value.slots[0]);
    try std.testing.expectEqual(@as(u64, 102), notification.notification.value.slots[1]);
    try std.testing.expectEqual(@as(?i64, 1710000100), notification.notification.value.timestamp);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.signature);
    try std.testing.expectEqualStrings("Vote111111111111111111111111111111111111111", notification.notification.value.votePubkey);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.vote_unsubscribe_seen);
}

test "root.PubsubClient blockSubscribe receives block notifications" {
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

    const subscription = try pubsub.blockSubscribe(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvBlockNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 901), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expect(notification.notification.value.block != null);

    const block = notification.notification.value.block.?;
    try std.testing.expect(block == .object);
    try std.testing.expectEqualStrings(
        "Blockhash111111111111111111111111111111111111",
        block.object.get("blockhash").?.string,
    );
    try std.testing.expectEqual(@as(i64, 899), block.object.get("parentSlot").?.integer);
    try std.testing.expectEqual(@as(usize, 1), block.object.get("transactions").?.array.items.len);
    try std.testing.expectEqual(@as(usize, 0), block.object.get("rewards").?.array.items.len);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.block_unsubscribe_seen);
}

test "root.PubsubSubscription parses block summary notifications" {
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

    const subscription = try pubsub.blockSubscribe(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvBlockSummaryNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 901), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqualStrings(
        "Blockhash111111111111111111111111111111111111",
        notification.notification.value.block.?.blockhash,
    );
    try std.testing.expectEqualStrings(
        "Prev111111111111111111111111111111111111111",
        notification.notification.value.block.?.previousBlockhash.?,
    );
    try std.testing.expectEqual(@as(u64, 899), notification.notification.value.block.?.parentSlot);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactionsCount);
    try std.testing.expectEqual(@as(?usize, 0), notification.notification.value.block.?.rewardsCount);
}

test "root.PubsubSubscription parses block signatures notifications" {
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

    const subscription = try pubsub.blockSubscribe(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvBlockSignaturesNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 901), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(!notification.notification.value.hasError);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqualStrings(
        "Blockhash111111111111111111111111111111111111",
        notification.notification.value.block.?.blockhash,
    );
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqual(@as(?usize, 0), notification.notification.value.block.?.rewardsCount);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.block.?.transactions[0].signatures.len);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.block.?.transactions[0].signatures[0]);
}

test "root.PubsubSubscription parses block accounts notifications" {
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

    const subscription = try pubsub.blockSubscribe(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .accounts,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvBlockAccountsNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 77), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 907), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 906), notification.notification.value.slot);
    try std.testing.expect(!notification.notification.value.hasError);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqualStrings(
        "AccountsBlockhash1111111111111111111111111111",
        notification.notification.value.block.?.blockhash,
    );
    try std.testing.expectEqual(@as(?u64, 601), notification.notification.value.block.?.blockHeight);
    try std.testing.expectEqual(@as(?i64, 1710000300), notification.notification.value.block.?.blockTime);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqualStrings("accsig1", notification.notification.value.block.?.transactions[0].signatures[0]);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.block.?.transactions[0].accountKeys.len);
    try std.testing.expectEqualStrings(
        "11111111111111111111111111111111",
        notification.notification.value.block.?.transactions[0].accountKeys[0].pubkey,
    );
    try std.testing.expect(notification.notification.value.block.?.transactions[0].accountKeys[0].signer);
    try std.testing.expect(notification.notification.value.block.?.transactions[0].accountKeys[0].writable);
    try std.testing.expectEqualStrings(
        "transaction",
        notification.notification.value.block.?.transactions[0].accountKeys[0].source.?,
    );
    try std.testing.expectEqualStrings(
        "Lookup1111111111111111111111111111111111111",
        notification.notification.value.block.?.transactions[0].accountKeys[1].pubkey,
    );
    try std.testing.expect(!notification.notification.value.block.?.transactions[0].accountKeys[1].signer);
    try std.testing.expect(!notification.notification.value.block.?.transactions[0].accountKeys[1].writable);
    try std.testing.expectEqualStrings(
        "lookupTable",
        notification.notification.value.block.?.transactions[0].accountKeys[1].source.?,
    );
}

test "root.PubsubSubscription parses block transaction summary notifications" {
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

    const subscription = try pubsub.blockSubscribe(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .full,
            .max_supported_transaction_version = 0,
            .show_rewards = true,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvBlockTransactionSummariesNotification();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 76), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 905), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 904), notification.notification.value.slot);
    try std.testing.expect(!notification.notification.value.hasError);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqualStrings(
        "FullBlockhash11111111111111111111111111111111",
        notification.notification.value.block.?.blockhash,
    );
    try std.testing.expectEqual(@as(?u64, 502), notification.notification.value.block.?.blockHeight);
    try std.testing.expectEqual(@as(?i64, 1710000200), notification.notification.value.block.?.blockTime);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.rewardsCount);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqual(@as(u64, 904), notification.notification.value.block.?.transactions[0].slot);
    try std.testing.expectEqual(@as(?i64, 1710000200), notification.notification.value.block.?.transactions[0].block_time);
    try std.testing.expectEqualStrings("legacy", notification.notification.value.block.?.transactions[0].version.?);
    try std.testing.expectEqual(@as(?usize, 2), notification.notification.value.block.?.transactions[0].signature_count);
    try std.testing.expectEqual(@as(?usize, 3), notification.notification.value.block.?.transactions[0].account_key_count);
    try std.testing.expectEqual(@as(?usize, 2), notification.notification.value.block.?.transactions[0].instruction_count);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactions[0].address_table_lookup_count);
    try std.testing.expectEqual(@as(?usize, null), notification.notification.value.block.?.transactions[0].loaded_address_count);
    try std.testing.expectEqual(@as(?u64, 5000), notification.notification.value.block.?.transactions[0].fee);
    try std.testing.expectEqual(@as(?usize, 2), notification.notification.value.block.?.transactions[0].log_messages_count);
    try std.testing.expect(!notification.notification.value.block.?.transactions[0].has_error);
    try std.testing.expectEqualStrings("0", notification.notification.value.block.?.transactions[1].version.?);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactions[1].account_key_count);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactions[1].instruction_count);
    try std.testing.expectEqual(@as(?usize, 0), notification.notification.value.block.?.transactions[1].address_table_lookup_count);
    try std.testing.expectEqual(@as(?usize, 3), notification.notification.value.block.?.transactions[1].loaded_address_count);
    try std.testing.expect(notification.notification.value.block.?.transactions[1].has_error);
    try std.testing.expectEqualStrings(
        "{\"InstructionError\":[1,{\"Custom\":6001}]}",
        notification.notification.value.block.?.transactions[1].error_json.?,
    );
}

test "root.PubsubClient subscribeWithReceiver convenience returns handle and receiver" {
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

    var subscribed = try pubsub.logsSubscribeWithReceiver(
        .{ .mentions = "11111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscribed.subscription.deinit();

    var notification = try subscribed.recvLogsNotificationTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 52), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 123), notification.notification.context_slot);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.signature);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.logs.len);

    try std.testing.expectEqual(@as(u64, 52), subscribed.subscriptionId());
    try std.testing.expectEqual(@as(usize, 0), subscribed.queuedCount());
    try std.testing.expect(subscribed.rawReceiver().rawSubscription() == subscribed.subscription);
    try std.testing.expect(!subscribed.isClosed());
    try std.testing.expect(try subscribed.unsubscribe());
    try std.testing.expect(subscribed.isClosed());
}

test "root.PubsubSubscriptionWithReceiver forwards generic receive helpers" {
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

    var subscribed = try pubsub.logsSubscribeWithReceiver(
        .{ .mentions = "11111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscribed.subscription.deinit();

    var notification = try subscribed.recvParsedTimeout(client.LogsNotificationValue, 1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 52), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 123), notification.notification.context_slot);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.signature);
    try std.testing.expect(subscribed.rawReceiver().rawSubscription() == subscribed.subscription);
    try std.testing.expectEqual(@as(usize, 0), subscribed.queuedCount());
    try std.testing.expectError(error.Timeout, subscribed.recvTimeout(10));

    try std.testing.expect(try subscribed.unsubscribe());
    try std.testing.expect(subscribed.isClosed());
}

test "root.PubsubSubscription typedReceiver provides typed receive and lifecycle access" {
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

    var receiver = subscription.typedReceiver(client.SignatureNotificationValue);
    var notification = try receiver.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 99), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expectEqual(@as(u64, 41), receiver.subscriptionId());
    try std.testing.expect(receiver.rawSubscription() == subscription);
    try std.testing.expect(receiver.rawReceiver().rawSubscription() == subscription);
    try std.testing.expectEqual(@as(usize, 0), receiver.queuedCount());
    try std.testing.expectError(error.Timeout, receiver.recvTimeout(10));

    try std.testing.expect(try receiver.unsubscribe());
    try std.testing.expect(subscription.isClosed());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, receiver.closeReason());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubSubscriptionWithReceiver typedReceiver shares receiver lifecycle" {
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

    var subscribed = try pubsub.logsSubscribeWithReceiver(
        .{ .mentions = "Err111111111111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscribed.subscription.deinit();

    var typed_receiver = subscribed.typedReceiver(client.LogsNotificationSummaryValue);
    var notification = try typed_receiver.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 53), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 124), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.hasError);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.logsCount);
    try std.testing.expectEqualStrings("program log: fail", notification.notification.value.firstLog.?);
    try std.testing.expect(typed_receiver.rawSubscription() == subscribed.subscription);
    try std.testing.expect(subscribed.receiver.rawSubscription() == subscribed.subscription);
    try std.testing.expectEqual(@as(usize, 0), typed_receiver.queuedCount());

    try std.testing.expect(try typed_receiver.unsubscribe());
    try std.testing.expect(subscribed.isClosed());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, subscribed.closeReason());
    try std.testing.expect(app.logs_unsubscribe_seen);
}

test "root.PubsubSubscription waitClosedTimeout reports unsubscribe close reason" {
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

    try std.testing.expectError(error.Timeout, subscription.waitClosedTimeout(10));
    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, try subscription.waitClosedTimeout(1000));
    const close_result = try subscription.waitClosedResultTimeout(1000);
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, close_result.reason);
    try std.testing.expectEqual(@as(usize, 0), close_result.dropped_messages);
    try std.testing.expect(close_result.last_error == null);
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubClient signatureSubscribeWithTypedReceiver returns typed handle and receiver" {
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

    var subscribed = try pubsub.signatureSubscribeWithTypedReceiver(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .commitment = .confirmed },
    );
    defer subscribed.deinit();

    var notification = try subscribed.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 99), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expectEqual(@as(u64, 41), subscribed.subscriptionId());
    try std.testing.expect(subscribed.rawReceiver().rawSubscription() == subscribed.rawSubscription());
    try std.testing.expectEqual(@as(usize, 0), subscribed.queuedCount());
    try std.testing.expectError(error.Timeout, subscribed.recvTimeout(10));

    try std.testing.expect(try subscribed.unsubscribe());
    try std.testing.expect(subscribed.isClosed());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, subscribed.closeReason());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.TypedPubsubSubscriptionWithReceiver waitClosedTimeout reports unsubscribe close reason" {
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

    var subscribed = try pubsub.signatureSubscribeWithTypedReceiver(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .commitment = .confirmed },
    );
    defer subscribed.deinit();

    try std.testing.expectError(error.Timeout, subscribed.waitClosedTimeout(10));
    try std.testing.expect(try subscribed.unsubscribe());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, try subscribed.waitClosedTimeout(1000));
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubClient blockSubscribeSummaryWithTypedReceiver returns typed summary handle" {
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

    var subscribed = try pubsub.blockSubscribeSummaryWithTypedReceiver(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscribed.deinit();

    var notification = try subscribed.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactionsCount);
    try std.testing.expectEqual(@as(?usize, 0), notification.notification.value.block.?.rewardsCount);
    try std.testing.expect(subscribed.rawReceiver().rawSubscription() == subscribed.rawSubscription());
    try std.testing.expectEqual(@as(usize, 0), subscribed.queuedCount());

    try std.testing.expect(try subscribed.unsubscribe());
    try std.testing.expect(subscribed.isClosed());
    try std.testing.expect(app.block_unsubscribe_seen);
}

test "root.PubsubClient auto reconnects and re-subscribes active subscriptions" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .auto_reconnect = true,
        .reconnect_delay_ms = 0,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.signatureSubscribe(
        "Reconnect1111111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer subscription.deinit();

    var first_notification = try subscription.recvSignatureNotification();
    defer first_notification.deinit();
    try std.testing.expectEqual(@as(?u64, 501), first_notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 141), subscription.id);

    var second_notification = try subscription.recvSignatureNotification();
    defer second_notification.deinit();
    try std.testing.expectEqual(@as(?u64, 777), second_notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 142), subscription.id);
    try std.testing.expectEqual(@as(usize, 2), app.reconnect_signature_subscribe_count);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubSubscription unsubscribe during reconnect closes locally without waiting for ack" {
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

    var pubsub = try client.PubsubClient.initWithOptions(std.testing.allocator, endpoint, .{
        .auto_reconnect = true,
        .reconnect_delay_ms = 50,
    });
    defer pubsub.deinit();

    const subscription = try pubsub.signatureSubscribe(
        "ReconnectCancel1111111111111111111111111111111",
        .{},
    );
    defer subscription.deinit();

    try waitForReconnecting(&pubsub, 1000);
    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(subscription.isClosed());
    try std.testing.expectEqual(client.PubsubCloseReason.unsubscribed, subscription.closeReason());

    std.Thread.sleep(100 * std.time.ns_per_ms);
    try std.testing.expect(!app.signature_unsubscribe_seen);
    try std.testing.expectEqual(@as(usize, 1), app.reconnect_cancel_signature_subscribe_count);
}

test "root.PubsubClient typed subscription convenience returns typed channel" {
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

    var subscription = try pubsub.signatureSubscribeTyped(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .commitment = .confirmed },
    );
    defer subscription.deinit();

    var notification = try subscription.recv();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 99), notification.notification.context_slot);
    try std.testing.expect(notification.notification.value.err == null);
    try std.testing.expectEqual(@as(usize, 0), subscription.queuedCount());
    try std.testing.expectError(error.Timeout, subscription.recvTimeout(10));

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(subscription.isClosed());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubClient subscribeRawTyped provides pubsub escape hatch" {
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

    var subscription = try pubsub.subscribeRawTyped(
        client.SignatureNotificationValue,
        "signatureSubscribe",
        "[\"3vQB7B6MrGQZaxCuFg4oh\",{\"commitment\":\"confirmed\"}]",
        "signatureUnsubscribe",
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(?u64, 99), notification.notification.context_slot);
    try std.testing.expectEqual(@as(u64, 41), subscription.subscriptionId());

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(subscription.isClosed());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubSubscription typed convenience returns typed channel handle" {
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

    const raw_subscription = try pubsub.signatureSubscribe(
        "3vQB7B6MrGQZaxCuFg4oh",
        .{ .commitment = .confirmed },
    );
    defer raw_subscription.deinit();

    var subscription = raw_subscription.typed(client.SignatureNotificationValue);
    var notification = try subscription.recv();
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 41), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 41), subscription.subscriptionId());
    try std.testing.expect(subscription.rawSubscription() == raw_subscription);

    try std.testing.expect(try subscription.unsubscribe());
    try std.testing.expect(raw_subscription.isClosed());
    try std.testing.expect(app.signature_unsubscribe_seen);
}

test "root.PubsubClient logsSubscribeSummaryTyped returns typed logs summary channel" {
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

    var subscription = try pubsub.logsSubscribeSummaryTyped(
        .{ .mentions = "Err111111111111111111111111111111111111111" },
        .{ .commitment = .finalized },
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 53), notification.notification.subscription);
    try std.testing.expectEqualStrings("7err", notification.notification.value.signature);
    try std.testing.expect(notification.notification.value.hasError);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.logsCount);
    try std.testing.expectEqualStrings("program log: fail", notification.notification.value.firstLog.?);
}

test "root.PubsubClient programSubscribeSummaryTyped returns typed program summary channel" {
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

    var subscription = try pubsub.programSubscribeSummaryTyped(
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

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 62), notification.notification.subscription);
    try std.testing.expectEqualStrings("7YttLkHDoNj9wyQkL8vL7h4sQ6x9x1Fs6sT4m7G4S3xX", notification.notification.value.pubkey);
    try std.testing.expect(notification.notification.value.account.dataSummary != null);
    try std.testing.expectEqualStrings("spl-token", notification.notification.value.account.dataSummary.?.program.?);
    try std.testing.expectEqualStrings("account", notification.notification.value.account.dataSummary.?.parsedType.?);
    try std.testing.expect(notification.notification.value.account.dataSummary.?.info != null);
    try std.testing.expectEqualStrings("Mint111111111111111111111111111111111111111", notification.notification.value.account.dataSummary.?.info.?.mint.?);
    try std.testing.expectEqualStrings("Owner1111111111111111111111111111111111111", notification.notification.value.account.dataSummary.?.info.?.owner.?);
}

test "root.PubsubClient blockSubscribeSummaryTyped returns typed block summary channel" {
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

    var subscription = try pubsub.blockSubscribeSummaryTyped(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactionsCount);
    try std.testing.expectEqual(@as(?usize, 0), notification.notification.value.block.?.rewardsCount);
}

test "root.PubsubClient blockSubscribeSignaturesTyped returns typed block signatures channel" {
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

    var subscription = try pubsub.blockSubscribeSignaturesTyped(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .signatures,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 75), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 900), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqualStrings("5h6x", notification.notification.value.block.?.transactions[0].signatures[0]);
}

test "root.PubsubClient blockSubscribeAccountsTyped returns typed accounts channel" {
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

    var subscription = try pubsub.blockSubscribeAccountsTyped(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .accounts,
            .max_supported_transaction_version = 0,
            .show_rewards = false,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 77), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 906), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqual(@as(usize, 1), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.block.?.transactions[0].accountKeys.len);
    try std.testing.expectEqualStrings(
        "lookupTable",
        notification.notification.value.block.?.transactions[0].accountKeys[1].source.?,
    );
}

test "root.PubsubClient blockSubscribeTransactionSummariesTyped returns typed transaction summary channel" {
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

    var subscription = try pubsub.blockSubscribeTransactionSummariesTyped(
        .{ .mentions_account_or_program = "11111111111111111111111111111111" },
        .{
            .commitment = .finalized,
            .encoding = .json,
            .transaction_details = .full,
            .max_supported_transaction_version = 0,
            .show_rewards = true,
        },
    );
    defer subscription.deinit();

    var notification = try subscription.recvTimeout(1000);
    defer notification.deinit();

    try std.testing.expectEqual(@as(u64, 76), notification.notification.subscription);
    try std.testing.expectEqual(@as(u64, 904), notification.notification.value.slot);
    try std.testing.expect(notification.notification.value.block != null);
    try std.testing.expectEqual(@as(usize, 2), notification.notification.value.block.?.transactions.len);
    try std.testing.expectEqualStrings("legacy", notification.notification.value.block.?.transactions[0].version.?);
    try std.testing.expectEqual(@as(?usize, 3), notification.notification.value.block.?.transactions[0].account_key_count);
    try std.testing.expectEqual(@as(?usize, 2), notification.notification.value.block.?.transactions[0].instruction_count);
    try std.testing.expectEqual(@as(?usize, 1), notification.notification.value.block.?.transactions[0].address_table_lookup_count);
    try std.testing.expectEqualStrings("0", notification.notification.value.block.?.transactions[1].version.?);
    try std.testing.expectEqual(@as(?usize, 3), notification.notification.value.block.?.transactions[1].loaded_address_count);
    try std.testing.expect(notification.notification.value.block.?.transactions[1].has_error);
}
