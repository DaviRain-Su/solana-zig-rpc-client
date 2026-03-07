const std = @import("std");
const json = std.json;
const websocket = @import("websocket");
const rpc_types = @import("../rpc_types.zig");
const pubsub_types = @import("./types.zig");

const Allocator = std.mem.Allocator;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const Commitment = rpc_types.Commitment;
const PubsubClientOptions = pubsub_types.PubsubClientOptions;
const PubsubAccountEncoding = pubsub_types.PubsubAccountEncoding;
const SignatureSubscribeOptions = pubsub_types.SignatureSubscribeOptions;
const AccountSubscribeOptions = pubsub_types.AccountSubscribeOptions;
const LogsSubscribeFilter = pubsub_types.LogsSubscribeFilter;
const LogsSubscribeOptions = pubsub_types.LogsSubscribeOptions;
const ProgramSubscribeOptions = pubsub_types.ProgramSubscribeOptions;

fn jsonValueToU64(value: json.Value) !u64 {
    return switch (value) {
        .integer => |integer| std.math.cast(u64, integer) orelse error.InvalidResponse,
        .number_string => |number| try std.fmt.parseInt(u64, number, 10),
        else => error.InvalidResponse,
    };
}

fn jsonValueToBool(value: json.Value) !bool {
    return switch (value) {
        .bool => |boolean| boolean,
        else => error.InvalidResponse,
    };
}

fn appendJsonValue(writer: anytype, value: anytype) !void {
    try json.Stringify.value(value, .{}, writer);
}

const PendingRequest = struct {
    kind: enum {
        subscribe,
        unsubscribe,
    },
    subscription: ?*PubsubSubscription = null,
    completed: bool = false,
    subscription_id: ?u64 = null,
    unsubscribe_ok: ?bool = null,
    error_code: i64 = 0,
    error_message: ?[]u8 = null,

    fn deinit(self: *PendingRequest, allocator: Allocator) void {
        if (self.error_message) |message| {
            allocator.free(message);
        }
        allocator.destroy(self);
    }
};

pub const PubsubSubscription = struct {
    state: *State,
    id: u64 = 0,
    unsubscribe_method: []const u8,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    queue: std.ArrayListUnmanaged([]u8) = .{},
    closed: bool = false,

    const Self = @This();

    pub fn isClosed(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.closed;
    }

    pub fn recv(self: *Self) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.queue.items.len == 0 and !self.closed) {
            self.cond.wait(&self.mutex);
        }

        if (self.queue.items.len == 0) {
            return error.Closed;
        }

        return self.queue.orderedRemove(0);
    }

    pub fn tryRecv(self: *Self) ?[]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.queue.items.len == 0) {
            return null;
        }

        return self.queue.orderedRemove(0);
    }

    pub fn recvParsed(self: *Self, comptime ValueType: type) !pubsub_types.OwnedPubsubNotification(ValueType) {
        return pubsub_types.parseOwnedPubsubNotification(self.state.allocator, try self.recv(), ValueType);
    }

    pub fn tryRecvParsed(self: *Self, comptime ValueType: type) !?pubsub_types.OwnedPubsubNotification(ValueType) {
        const raw_message = self.tryRecv() orelse return null;
        return pubsub_types.parseOwnedPubsubNotification(self.state.allocator, raw_message, ValueType);
    }

    pub fn recvSignatureNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.recvParsed(pubsub_types.SignatureNotificationValue);
    }

    pub fn tryRecvSignatureNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.tryRecvParsed(pubsub_types.SignatureNotificationValue);
    }

    pub fn recvAccountNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.recvParsed(pubsub_types.AccountNotificationValue);
    }

    pub fn tryRecvAccountNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.tryRecvParsed(pubsub_types.AccountNotificationValue);
    }

    pub fn recvLogsNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.recvParsed(pubsub_types.LogsNotificationValue);
    }

    pub fn tryRecvLogsNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.tryRecvParsed(pubsub_types.LogsNotificationValue);
    }

    pub fn recvProgramNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.recvParsed(pubsub_types.ProgramNotificationValue);
    }

    pub fn tryRecvProgramNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.tryRecvParsed(pubsub_types.ProgramNotificationValue);
    }

    pub fn recvSlotNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotNotificationValue) {
        return self.recvParsed(pubsub_types.SlotNotificationValue);
    }

    pub fn tryRecvSlotNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SlotNotificationValue) {
        return self.tryRecvParsed(pubsub_types.SlotNotificationValue);
    }

    pub fn recvRootNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.RootNotificationValue) {
        return self.recvParsed(pubsub_types.RootNotificationValue);
    }

    pub fn tryRecvRootNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.RootNotificationValue) {
        return self.tryRecvParsed(pubsub_types.RootNotificationValue);
    }

    pub fn unsubscribe(self: *Self) !bool {
        return self.state.unsubscribe(self);
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.state.allocator;
        self.state.detachSubscription(self);

        self.mutex.lock();
        self.closed = true;
        self.cond.broadcast();
        for (self.queue.items) |message| {
            self.state.allocator.free(message);
        }
        self.queue.deinit(self.state.allocator);
        self.mutex.unlock();

        self.state.release();
        allocator.destroy(self);
    }

    fn push(self: *Self, allocator: Allocator, raw_message: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) return;
        try self.queue.append(allocator, try allocator.dupe(u8, raw_message));
        self.cond.signal();
    }

    fn closeLocked(self: *Self) void {
        self.closed = true;
        self.cond.broadcast();
    }
};

const State = struct {
    allocator: Allocator,
    endpoint: []const u8,
    ws_client: websocket.Client,
    reader_thread: ?std.Thread = null,
    ref_count: std.atomic.Value(usize) = std.atomic.Value(usize).init(1),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    next_request_id: u64 = 1,
    subscriptions: std.AutoHashMapUnmanaged(u64, *PubsubSubscription) = .{},
    pending_requests: std.AutoHashMapUnmanaged(u64, *PendingRequest) = .{},
    last_error: ?RpcErrorDetail = null,
    closed: bool = false,
    shutdown_started: bool = false,

    fn retain(self: *State) void {
        _ = self.ref_count.fetchAdd(1, .monotonic);
    }

    fn release(self: *State) void {
        if (self.ref_count.fetchSub(1, .acq_rel) == 1) {
            self.finalFree();
        }
    }

    fn finalFree(self: *State) void {
        self.clearLastError();
        self.subscriptions.deinit(self.allocator);
        var pending_it = self.pending_requests.valueIterator();
        while (pending_it.next()) |pending| {
            pending.*.deinit(self.allocator);
        }
        self.pending_requests.deinit(self.allocator);
        self.allocator.free(self.endpoint);
        self.allocator.destroy(self);
    }

    fn clearLastError(self: *State) void {
        if (self.last_error) |last_error| {
            self.allocator.free(last_error.message);
            self.last_error = null;
        }
    }

    fn setLastError(self: *State, code: i64, message: []const u8) void {
        self.clearLastError();
        self.last_error = .{
            .code = code,
            .message = self.allocator.dupe(u8, message) catch return,
        };
    }

    fn markClosedLocked(self: *State) void {
        self.closed = true;

        var subscription_it = self.subscriptions.valueIterator();
        while (subscription_it.next()) |subscription| {
            subscription.*.mutex.lock();
            subscription.*.closeLocked();
            subscription.*.mutex.unlock();
        }

        var pending_it = self.pending_requests.valueIterator();
        while (pending_it.next()) |pending| {
            pending.*.completed = true;
        }
        self.cond.broadcast();
    }

    fn shutdown(self: *State) void {
        self.mutex.lock();
        if (self.shutdown_started) {
            self.mutex.unlock();
            return;
        }

        self.shutdown_started = true;
        self.markClosedLocked();
        const thread = self.reader_thread;
        self.reader_thread = null;
        self.mutex.unlock();

        self.ws_client.close(.{}) catch {};
        if (thread) |reader_thread| {
            reader_thread.join();
        }
        self.ws_client.deinit();
    }

    pub fn serverMessage(self: *State, data: []u8) !void {
        const parsed = try json.parseFromSlice(json.Value, self.allocator, data, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.object.get("id")) |id_value| {
            try self.handleResponse(id_value, parsed.value);
            return;
        }

        if (parsed.value.object.get("params")) |_| {
            try self.handleNotification(parsed.value, data);
        }
    }

    pub fn close(self: *State) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) return;
        self.markClosedLocked();
    }

    fn handleResponse(self: *State, id_value: json.Value, root: json.Value) !void {
        const request_id = try jsonValueToU64(id_value);

        self.mutex.lock();
        defer self.mutex.unlock();

        const pending = self.pending_requests.get(request_id) orelse return;

        if (root.object.get("error")) |error_value| {
            if (error_value != .object) return error.InvalidResponse;
            const code_value = error_value.object.get("code") orelse return error.InvalidResponse;
            const message_value = error_value.object.get("message") orelse return error.InvalidResponse;

            const code = switch (code_value) {
                .integer => |integer| integer,
                else => return error.InvalidResponse,
            };
            const message = switch (message_value) {
                .string => |string| string,
                else => return error.InvalidResponse,
            };

            pending.error_code = code;
            pending.error_message = try self.allocator.dupe(u8, message);
            self.setLastError(code, message);
            pending.completed = true;
            self.cond.broadcast();
            return;
        }

        const result_value = root.object.get("result") orelse return error.InvalidResponse;
        switch (pending.kind) {
            .subscribe => {
                const subscription_id = try jsonValueToU64(result_value);
                pending.subscription_id = subscription_id;
                if (pending.subscription) |subscription| {
                    subscription.id = subscription_id;
                    try self.subscriptions.put(self.allocator, subscription_id, subscription);
                }
            },
            .unsubscribe => {
                const unsubscribe_ok = try jsonValueToBool(result_value);
                pending.unsubscribe_ok = unsubscribe_ok;
                if (unsubscribe_ok) {
                    if (pending.subscription) |subscription| {
                        if (subscription.id != 0) {
                            _ = self.subscriptions.remove(subscription.id);
                        }
                        subscription.mutex.lock();
                        subscription.closeLocked();
                        subscription.mutex.unlock();
                    }
                }
            },
        }

        pending.completed = true;
        self.cond.broadcast();
    }

    fn handleNotification(self: *State, root: json.Value, raw_message: []const u8) !void {
        const params = root.object.get("params") orelse return error.InvalidResponse;
        if (params != .object) return error.InvalidResponse;

        const subscription_value = params.object.get("subscription") orelse return error.InvalidResponse;
        const subscription_id = try jsonValueToU64(subscription_value);

        self.mutex.lock();
        defer self.mutex.unlock();

        const subscription = self.subscriptions.get(subscription_id) orelse return;
        try subscription.push(self.allocator, raw_message);
    }

    fn sendRequest(
        self: *State,
        method: []const u8,
        params_json: []const u8,
        pending: *PendingRequest,
    ) !void {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return error.Closed;
        }

        const request_id = self.next_request_id;
        self.next_request_id +%= 1;
        try self.pending_requests.put(self.allocator, request_id, pending);
        self.mutex.unlock();
        errdefer {
            self.mutex.lock();
            _ = self.pending_requests.remove(request_id);
            self.mutex.unlock();
        }

        const request_json = try std.fmt.allocPrint(
            self.allocator,
            "{{\"jsonrpc\":\"2.0\",\"id\":{},\"method\":\"{s}\",\"params\":{s}}}",
            .{ request_id, method, params_json },
        );
        defer self.allocator.free(request_json);

        try self.ws_client.writeText(request_json);
        try self.awaitPendingRequest(request_id, pending);
    }

    fn awaitPendingRequest(self: *State, request_id: u64, pending: *PendingRequest) !void {
        self.mutex.lock();
        while (!pending.completed and !self.closed) {
            self.cond.wait(&self.mutex);
        }
        _ = self.pending_requests.remove(request_id);
        self.mutex.unlock();

        if (!pending.completed) {
            return error.Closed;
        }

        if (pending.error_message != null) {
            return error.RpcError;
        }
    }

    fn allocateSubscription(self: *State, unsubscribe_method: []const u8) !*PubsubSubscription {
        const subscription = try self.allocator.create(PubsubSubscription);
        errdefer self.allocator.destroy(subscription);

        self.retain();
        errdefer self.release();

        subscription.* = .{
            .state = self,
            .unsubscribe_method = unsubscribe_method,
        };
        return subscription;
    }

    fn buildSubscribeConfig(
        self: *State,
        commitment: ?Commitment,
        encoding: ?PubsubAccountEncoding,
        enable_received_notification: ?bool,
    ) ![]u8 {
        var out = std.io.Writer.Allocating.init(self.allocator);
        errdefer out.deinit();

        try out.writer.writeByte('{');
        var wrote_field = false;

        if (commitment) |value| {
            try out.writer.writeAll("\"commitment\":");
            try appendJsonValue(&out.writer, rpc_types.commitmentToString(value));
            wrote_field = true;
        }

        if (encoding) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"encoding\":");
            try appendJsonValue(&out.writer, pubsub_types.pubsubAccountEncodingToString(value));
            wrote_field = true;
        }

        if (enable_received_notification) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"enableReceivedNotification\":");
            try appendJsonValue(&out.writer, value);
        }

        try out.writer.writeByte('}');
        return try out.toOwnedSlice();
    }

    fn buildProgramSubscribeConfig(self: *State, options: ProgramSubscribeOptions) ![]u8 {
        if ((options.memcmp_offset == null) != (options.memcmp_bytes == null)) {
            return error.InvalidProgramSubscribeOptions;
        }

        var out = std.io.Writer.Allocating.init(self.allocator);
        errdefer out.deinit();

        try out.writer.writeByte('{');
        var wrote_field = false;

        if (options.commitment) |value| {
            try out.writer.writeAll("\"commitment\":");
            try appendJsonValue(&out.writer, rpc_types.commitmentToString(value));
            wrote_field = true;
        }

        if (wrote_field) try out.writer.writeByte(',');
        try out.writer.writeAll("\"encoding\":");
        try appendJsonValue(&out.writer, pubsub_types.pubsubAccountEncodingToString(options.encoding));
        wrote_field = true;

        if (options.data_size != null or options.memcmp_offset != null) {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"filters\":[");

            var wrote_filter = false;
            if (options.data_size) |data_size| {
                try out.writer.writeAll("{\"dataSize\":");
                try appendJsonValue(&out.writer, data_size);
                try out.writer.writeByte('}');
                wrote_filter = true;
            }

            if (options.memcmp_offset) |offset| {
                if (wrote_filter) try out.writer.writeByte(',');
                try out.writer.writeAll("{\"memcmp\":{\"offset\":");
                try appendJsonValue(&out.writer, offset);
                try out.writer.writeAll(",\"bytes\":");
                try appendJsonValue(&out.writer, options.memcmp_bytes.?);
                try out.writer.writeAll("}}");
            }

            try out.writer.writeByte(']');
        }

        try out.writer.writeByte('}');
        return try out.toOwnedSlice();
    }

    fn subscribeSignature(self: *State, signature: []const u8, options: SignatureSubscribeOptions) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("signatureUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        const config_json = try self.buildSubscribeConfig(
            options.commitment,
            null,
            options.enable_received_notification,
        );
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[\"{s}\",{s}]",
            .{ signature, config_json },
        );
        defer self.allocator.free(params_json);

        try self.sendRequest("signatureSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeAccount(
        self: *State,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("accountUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        const config_json = try self.buildSubscribeConfig(options.commitment, options.encoding, null);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[\"{s}\",{s}]",
            .{ account, config_json },
        );
        defer self.allocator.free(params_json);

        try self.sendRequest("accountSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeLogs(
        self: *State,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("logsUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        const filter_json = switch (filter) {
            .all => try self.allocator.dupe(u8, "\"all\""),
            .all_with_votes => try self.allocator.dupe(u8, "\"allWithVotes\""),
            .mentions => |mentions| try std.fmt.allocPrint(
                self.allocator,
                "{{\"mentions\":[\"{s}\"]}}",
                .{mentions},
            ),
        };
        defer self.allocator.free(filter_json);

        const config_json = try self.buildSubscribeConfig(options.commitment, null, null);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[{s},{s}]",
            .{ filter_json, config_json },
        );
        defer self.allocator.free(params_json);

        try self.sendRequest("logsSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeProgram(
        self: *State,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("programUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        const config_json = try self.buildProgramSubscribeConfig(options);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[\"{s}\",{s}]",
            .{ program_id, config_json },
        );
        defer self.allocator.free(params_json);

        try self.sendRequest("programSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeSlot(self: *State) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("slotUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("slotSubscribe", "[]", pending);
        return subscription;
    }

    fn subscribeRoot(self: *State) !*PubsubSubscription {
        const subscription = try self.allocateSubscription("rootUnsubscribe");

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("rootSubscribe", "[]", pending);
        return subscription;
    }

    fn unsubscribe(self: *State, subscription: *PubsubSubscription) !bool {
        if (subscription.id == 0) return false;

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .unsubscribe,
            .subscription = subscription,
        };

        const params_json = try std.fmt.allocPrint(self.allocator, "[{}]", .{subscription.id});
        defer self.allocator.free(params_json);

        try self.sendRequest(subscription.unsubscribe_method, params_json, pending);
        return pending.unsubscribe_ok orelse false;
    }

    fn detachSubscription(self: *State, subscription: *PubsubSubscription) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (subscription.id != 0) {
            if (self.subscriptions.get(subscription.id)) |active| {
                if (active == subscription) {
                    _ = self.subscriptions.remove(subscription.id);
                }
            }
        }
    }
};

pub const PubsubClient = struct {
    state: *State,

    const Self = @This();

    pub fn init(allocator: Allocator, endpoint: []const u8) !Self {
        return Self.initWithOptions(allocator, endpoint, .{});
    }

    pub fn initWithOptions(
        allocator: Allocator,
        endpoint: []const u8,
        options: PubsubClientOptions,
    ) !Self {
        var parse_arena = std.heap.ArenaAllocator.init(allocator);
        defer parse_arena.deinit();

        const uri = try std.Uri.parse(endpoint);
        const tls = switch (std.ascii.eqlIgnoreCase(uri.scheme, "wss")) {
            true => true,
            false => if (std.ascii.eqlIgnoreCase(uri.scheme, "ws")) false else return error.InvalidPubsubEndpoint,
        };

        const host = try uri.getHostAlloc(parse_arena.allocator());
        const port: u16 = uri.port orelse if (tls) 443 else 80;
        const path_component = if (uri.path.isEmpty()) "/" else try uri.path.toRawMaybeAlloc(parse_arena.allocator());
        const request_path = if (uri.query) |query|
            try std.fmt.allocPrint(parse_arena.allocator(), "{s}?{f}", .{ path_component, std.fmt.alt(query, .formatRaw) })
        else
            try parse_arena.allocator().dupe(u8, path_component);
        const host_header = try std.fmt.allocPrint(parse_arena.allocator(), "Host: {s}:{d}", .{ host, port });

        var ws_client = try websocket.Client.init(allocator, .{
            .host = host,
            .port = port,
            .tls = tls,
            .max_size = options.max_message_size,
            .buffer_size = options.buffer_size,
        });
        errdefer ws_client.deinit();

        if (options.write_timeout_ms) |write_timeout_ms| {
            try ws_client.writeTimeout(write_timeout_ms);
        }

        try ws_client.handshake(request_path, .{
            .timeout_ms = options.handshake_timeout_ms,
            .headers = host_header,
        });

        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        state.* = .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .ws_client = ws_client,
        };
        errdefer allocator.free(state.endpoint);

        state.reader_thread = try state.ws_client.readLoopInNewThread(state);
        return .{ .state = state };
    }

    pub fn deinit(self: *Self) void {
        self.state.shutdown();
        self.state.release();
        self.* = undefined;
    }

    pub fn url(self: *const Self) []const u8 {
        return self.state.endpoint;
    }

    pub fn getLastError(self: *const Self) ?RpcErrorDetail {
        return self.state.last_error;
    }

    pub fn clearLastError(self: *Self) void {
        self.state.mutex.lock();
        defer self.state.mutex.unlock();
        self.state.clearLastError();
    }

    pub fn signatureSubscribe(
        self: *Self,
        signature: []const u8,
        options: SignatureSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeSignature(signature, options);
    }

    pub fn accountSubscribe(
        self: *Self,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeAccount(account, options);
    }

    pub fn logsSubscribe(
        self: *Self,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeLogs(filter, options);
    }

    pub fn programSubscribe(
        self: *Self,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeProgram(program_id, options);
    }

    pub fn slotSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeSlot();
    }

    pub fn rootSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeRoot();
    }

    pub fn unsubscribe(self: *Self, subscription: *PubsubSubscription) !bool {
        return self.state.unsubscribe(subscription);
    }
};
