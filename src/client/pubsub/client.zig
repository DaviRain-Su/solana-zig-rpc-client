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
const BlockSubscribeFilter = pubsub_types.BlockSubscribeFilter;
const BlockSubscribeOptions = pubsub_types.BlockSubscribeOptions;
const PubsubCloseReason = pubsub_types.PubsubCloseReason;

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

fn connectWebsocketClient(
    allocator: Allocator,
    endpoint: []const u8,
    options: PubsubClientOptions,
) !websocket.Client {
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

    return ws_client;
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
    subscribe_method: []const u8,
    subscribe_params_json: []u8,
    unsubscribe_method: []const u8,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    queue: std.ArrayListUnmanaged([]u8) = .{},
    dropped_messages: usize = 0,
    closed: bool = false,
    close_reason: PubsubCloseReason = .none,
    last_error: ?RpcErrorDetail = null,

    const Self = @This();

    pub fn isClosed(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.closed;
    }

    pub fn queuedCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.queue.items.len;
    }

    pub fn receiver(self: *Self) PubsubReceiver {
        return .{ .subscription = self };
    }

    pub fn typedReceiver(self: *Self, comptime ValueType: type) TypedPubsubReceiver(ValueType) {
        return self.receiver().typedReceiver(ValueType);
    }

    pub fn droppedCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.dropped_messages;
    }

    pub fn closeReason(self: *Self) PubsubCloseReason {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.close_reason;
    }

    pub fn getLastError(self: *Self) ?RpcErrorDetail {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.last_error;
    }

    pub fn clearLastError(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.clearLastErrorLocked();
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

    pub fn recvTimeout(self: *Self, timeout_ms: u64) error{ Closed, Timeout }![]u8 {
        const timeout_ns = timeout_ms * std.time.ns_per_ms;
        const deadline = std.time.nanoTimestamp() + @as(i128, @intCast(timeout_ns));

        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.queue.items.len == 0 and !self.closed) {
            const now = std.time.nanoTimestamp();
            if (now >= deadline) return error.Timeout;

            const remaining_ns = @as(u64, @intCast(deadline - now));
            self.cond.timedWait(&self.mutex, remaining_ns) catch |err| switch (err) {
                error.Timeout => if (self.queue.items.len == 0) return error.Timeout,
            };
        }

        if (self.queue.items.len == 0) {
            return error.Closed;
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

    pub fn recvParsedTimeout(
        self: *Self,
        comptime ValueType: type,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(ValueType) {
        return pubsub_types.parseOwnedPubsubNotification(self.state.allocator, try self.recvTimeout(timeout_ms), ValueType);
    }

    pub fn recvSignatureNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.recvParsed(pubsub_types.SignatureNotificationValue);
    }

    pub fn tryRecvSignatureNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.tryRecvParsed(pubsub_types.SignatureNotificationValue);
    }

    pub fn recvSignatureSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationSummaryValue) {
        return self.recvParsed(pubsub_types.SignatureNotificationSummaryValue);
    }

    pub fn tryRecvSignatureSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationSummaryValue) {
        return self.tryRecvParsed(pubsub_types.SignatureNotificationSummaryValue);
    }

    pub fn recvAccountNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.recvParsed(pubsub_types.AccountNotificationValue);
    }

    pub fn tryRecvAccountNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.tryRecvParsed(pubsub_types.AccountNotificationValue);
    }

    pub fn recvAccountSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationSummaryValue) {
        return self.recvParsed(pubsub_types.AccountNotificationSummaryValue);
    }

    pub fn tryRecvAccountSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationSummaryValue) {
        return self.tryRecvParsed(pubsub_types.AccountNotificationSummaryValue);
    }

    pub fn recvLogsNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.recvParsed(pubsub_types.LogsNotificationValue);
    }

    pub fn tryRecvLogsNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.tryRecvParsed(pubsub_types.LogsNotificationValue);
    }

    pub fn recvLogsSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationSummaryValue) {
        return self.recvParsed(pubsub_types.LogsNotificationSummaryValue);
    }

    pub fn tryRecvLogsSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationSummaryValue) {
        return self.tryRecvParsed(pubsub_types.LogsNotificationSummaryValue);
    }

    pub fn recvProgramNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.recvParsed(pubsub_types.ProgramNotificationValue);
    }

    pub fn tryRecvProgramNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.tryRecvParsed(pubsub_types.ProgramNotificationValue);
    }

    pub fn recvProgramSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationSummaryValue) {
        return self.recvParsed(pubsub_types.ProgramNotificationSummaryValue);
    }

    pub fn tryRecvProgramSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationSummaryValue) {
        return self.tryRecvParsed(pubsub_types.ProgramNotificationSummaryValue);
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

    pub fn recvSlotsUpdatesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotsUpdatesNotificationValue) {
        return self.recvParsed(pubsub_types.SlotsUpdatesNotificationValue);
    }

    pub fn tryRecvSlotsUpdatesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SlotsUpdatesNotificationValue) {
        return self.tryRecvParsed(pubsub_types.SlotsUpdatesNotificationValue);
    }

    pub fn recvVoteNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.VoteNotificationValue) {
        return self.recvParsed(pubsub_types.VoteNotificationValue);
    }

    pub fn tryRecvVoteNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.VoteNotificationValue) {
        return self.tryRecvParsed(pubsub_types.VoteNotificationValue);
    }

    pub fn recvBlockNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationValue) {
        return self.recvParsed(pubsub_types.BlockNotificationValue);
    }

    pub fn tryRecvBlockNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationValue) {
        return self.tryRecvParsed(pubsub_types.BlockNotificationValue);
    }

    pub fn recvBlockSignaturesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSignaturesValue) {
        return self.recvParsed(pubsub_types.BlockNotificationSignaturesValue);
    }

    pub fn tryRecvBlockSignaturesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSignaturesValue) {
        return self.tryRecvParsed(pubsub_types.BlockNotificationSignaturesValue);
    }

    pub fn recvBlockAccountsNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationAccountsValue) {
        return self.recvParsed(pubsub_types.BlockNotificationAccountsValue);
    }

    pub fn tryRecvBlockAccountsNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationAccountsValue) {
        return self.tryRecvParsed(pubsub_types.BlockNotificationAccountsValue);
    }

    pub fn recvBlockTransactionSummariesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return self.recvParsed(pubsub_types.BlockNotificationTransactionSummariesValue);
    }

    pub fn tryRecvBlockTransactionSummariesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return self.tryRecvParsed(pubsub_types.BlockNotificationTransactionSummariesValue);
    }

    pub fn recvBlockSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSummaryValue) {
        return self.recvParsed(pubsub_types.BlockNotificationSummaryValue);
    }

    pub fn tryRecvBlockSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSummaryValue) {
        return self.tryRecvParsed(pubsub_types.BlockNotificationSummaryValue);
    }

    pub fn unsubscribe(self: *Self) !bool {
        return self.state.unsubscribe(self);
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.state.allocator;
        self.state.detachSubscription(self);

        self.mutex.lock();
        if (!self.closed) {
            self.closeLocked(.deinitialized);
        }
        for (self.queue.items) |message| {
            self.state.allocator.free(message);
        }
        self.clearLastErrorLocked();
        self.queue.deinit(self.state.allocator);
        self.mutex.unlock();

        self.state.allocator.free(self.subscribe_params_json);
        self.state.release();
        allocator.destroy(self);
    }

    fn push(self: *Self, allocator: Allocator, raw_message: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) return;

        const queue_limit = self.state.options.subscription_queue_limit;
        if (queue_limit != 0 and self.queue.items.len >= queue_limit) {
            switch (self.state.options.queue_overflow_policy) {
                .drop_oldest => {
                    const dropped = self.queue.orderedRemove(0);
                    allocator.free(dropped);
                    self.dropped_messages += 1;
                },
                .drop_newest => {
                    self.dropped_messages += 1;
                    return;
                },
                .close_subscription => {
                    self.dropped_messages += 1;
                    self.closeLocked(.queue_overflow);
                    return error.QueueOverflow;
                },
            }
        }

        try self.queue.append(allocator, try allocator.dupe(u8, raw_message));
        self.cond.signal();
    }

    fn closeLocked(self: *Self, reason: PubsubCloseReason) void {
        self.closed = true;
        if (self.close_reason == .none) {
            self.close_reason = reason;
        }
        self.cond.broadcast();
    }

    fn clearLastErrorLocked(self: *Self) void {
        if (self.last_error) |last_error| {
            self.state.allocator.free(last_error.message);
            self.last_error = null;
        }
    }

    fn setLastErrorLocked(self: *Self, code: i64, message: []const u8) void {
        self.clearLastErrorLocked();
        self.last_error = .{
            .code = code,
            .message = self.state.allocator.dupe(u8, message) catch return,
        };
    }
};

pub const PubsubReceiver = struct {
    subscription: *PubsubSubscription,

    const Self = @This();

    pub fn isClosed(self: *const Self) bool {
        return self.subscription.isClosed();
    }

    pub fn queuedCount(self: *const Self) usize {
        return self.subscription.queuedCount();
    }

    pub fn droppedCount(self: *const Self) usize {
        return self.subscription.droppedCount();
    }

    pub fn closeReason(self: *const Self) PubsubCloseReason {
        return self.subscription.closeReason();
    }

    pub fn typedReceiver(self: *const Self, comptime ValueType: type) TypedPubsubReceiver(ValueType) {
        return .{
            .subscription = self.subscription,
            .receiver = self.*,
        };
    }

    pub fn getLastError(self: *Self) ?RpcErrorDetail {
        return self.subscription.getLastError();
    }

    pub fn clearLastError(self: *Self) void {
        self.subscription.clearLastError();
    }

    pub fn unsubscribe(self: *Self) !bool {
        return self.subscription.unsubscribe();
    }

    pub fn rawSubscription(self: *const Self) *PubsubSubscription {
        return self.subscription;
    }

    pub fn recv(self: *Self) ![]u8 {
        return self.subscription.recv();
    }

    pub fn tryRecv(self: *Self) ?[]u8 {
        return self.subscription.tryRecv();
    }

    pub fn recvTimeout(self: *Self, timeout_ms: u64) error{ Closed, Timeout }![]u8 {
        return self.subscription.recvTimeout(timeout_ms);
    }

    pub fn recvParsed(self: *Self, comptime ValueType: type) !pubsub_types.OwnedPubsubNotification(ValueType) {
        return self.subscription.recvParsed(ValueType);
    }

    pub fn tryRecvParsed(self: *Self, comptime ValueType: type) !?pubsub_types.OwnedPubsubNotification(ValueType) {
        return self.subscription.tryRecvParsed(ValueType);
    }

    pub fn recvParsedTimeout(
        self: *Self,
        comptime ValueType: type,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(ValueType) {
        return self.subscription.recvParsedTimeout(ValueType, timeout_ms);
    }

    pub fn recvSignatureNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.subscription.recvSignatureNotification();
    }

    pub fn tryRecvSignatureNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.subscription.tryRecvSignatureNotification();
    }

    pub fn recvSignatureNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.SignatureNotificationValue, timeout_ms);
    }

    pub fn recvSignatureSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationSummaryValue) {
        return self.subscription.recvSignatureSummaryNotification();
    }

    pub fn tryRecvSignatureSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationSummaryValue) {
        return self.subscription.tryRecvParsed(pubsub_types.SignatureNotificationSummaryValue);
    }

    pub fn recvSignatureSummaryNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.SignatureNotificationSummaryValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.SignatureNotificationSummaryValue, timeout_ms);
    }

    pub fn recvAccountNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.subscription.recvAccountNotification();
    }

    pub fn tryRecvAccountNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.subscription.tryRecvAccountNotification();
    }

    pub fn recvAccountNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.AccountNotificationValue, timeout_ms);
    }

    pub fn recvAccountSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationSummaryValue) {
        return self.subscription.recvAccountSummaryNotification();
    }

    pub fn tryRecvAccountSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationSummaryValue) {
        return self.subscription.tryRecvParsed(pubsub_types.AccountNotificationSummaryValue);
    }

    pub fn recvAccountSummaryNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.AccountNotificationSummaryValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.AccountNotificationSummaryValue, timeout_ms);
    }

    pub fn recvLogsNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.subscription.recvLogsNotification();
    }

    pub fn tryRecvLogsNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.subscription.tryRecvLogsNotification();
    }

    pub fn recvLogsNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.LogsNotificationValue, timeout_ms);
    }

    pub fn recvLogsSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationSummaryValue) {
        return self.subscription.recvLogsSummaryNotification();
    }

    pub fn tryRecvLogsSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationSummaryValue) {
        return self.subscription.tryRecvParsed(pubsub_types.LogsNotificationSummaryValue);
    }

    pub fn recvLogsSummaryNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.LogsNotificationSummaryValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.LogsNotificationSummaryValue, timeout_ms);
    }

    pub fn recvProgramNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.subscription.recvProgramNotification();
    }

    pub fn tryRecvProgramNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.subscription.tryRecvProgramNotification();
    }

    pub fn recvProgramNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.ProgramNotificationValue, timeout_ms);
    }

    pub fn recvProgramSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationSummaryValue) {
        return self.subscription.recvProgramSummaryNotification();
    }

    pub fn tryRecvProgramSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationSummaryValue) {
        return self.subscription.tryRecvParsed(pubsub_types.ProgramNotificationSummaryValue);
    }

    pub fn recvProgramSummaryNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.ProgramNotificationSummaryValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.ProgramNotificationSummaryValue, timeout_ms);
    }

    pub fn recvSlotNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotNotificationValue) {
        return self.subscription.recvSlotNotification();
    }

    pub fn tryRecvSlotNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SlotNotificationValue) {
        return self.subscription.tryRecvSlotNotification();
    }

    pub fn recvSlotNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.SlotNotificationValue, timeout_ms);
    }

    pub fn recvRootNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.RootNotificationValue) {
        return self.subscription.recvRootNotification();
    }

    pub fn tryRecvRootNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.RootNotificationValue) {
        return self.subscription.tryRecvRootNotification();
    }

    pub fn recvRootNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.RootNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.RootNotificationValue, timeout_ms);
    }

    pub fn recvSlotsUpdatesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotsUpdatesNotificationValue) {
        return self.subscription.recvSlotsUpdatesNotification();
    }

    pub fn tryRecvSlotsUpdatesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.SlotsUpdatesNotificationValue) {
        return self.subscription.tryRecvSlotsUpdatesNotification();
    }

    pub fn recvSlotsUpdatesNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.SlotsUpdatesNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.SlotsUpdatesNotificationValue, timeout_ms);
    }

    pub fn recvVoteNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.VoteNotificationValue) {
        return self.subscription.recvVoteNotification();
    }

    pub fn tryRecvVoteNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.VoteNotificationValue) {
        return self.subscription.tryRecvVoteNotification();
    }

    pub fn recvVoteNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.VoteNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.VoteNotificationValue, timeout_ms);
    }

    pub fn recvBlockNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationValue) {
        return self.subscription.recvBlockNotification();
    }

    pub fn tryRecvBlockNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationValue) {
        return self.subscription.tryRecvBlockNotification();
    }

    pub fn recvBlockNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.BlockNotificationValue, timeout_ms);
    }

    pub fn recvBlockSignaturesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSignaturesValue) {
        return self.subscription.recvBlockSignaturesNotification();
    }

    pub fn tryRecvBlockSignaturesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSignaturesValue) {
        return self.subscription.tryRecvParsed(pubsub_types.BlockNotificationSignaturesValue);
    }

    pub fn recvBlockSignaturesNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSignaturesValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.BlockNotificationSignaturesValue, timeout_ms);
    }

    pub fn recvBlockAccountsNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationAccountsValue) {
        return self.subscription.recvBlockAccountsNotification();
    }

    pub fn tryRecvBlockAccountsNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationAccountsValue) {
        return self.subscription.tryRecvParsed(pubsub_types.BlockNotificationAccountsValue);
    }

    pub fn recvBlockAccountsNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationAccountsValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.BlockNotificationAccountsValue, timeout_ms);
    }

    pub fn recvBlockTransactionSummariesNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return self.subscription.recvBlockTransactionSummariesNotification();
    }

    pub fn tryRecvBlockTransactionSummariesNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return self.subscription.tryRecvParsed(pubsub_types.BlockNotificationTransactionSummariesValue);
    }

    pub fn recvBlockTransactionSummariesNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.BlockNotificationTransactionSummariesValue, timeout_ms);
    }

    pub fn recvBlockSummaryNotification(self: *Self) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSummaryValue) {
        return self.subscription.recvBlockSummaryNotification();
    }

    pub fn tryRecvBlockSummaryNotification(self: *Self) !?pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSummaryValue) {
        return self.subscription.tryRecvParsed(pubsub_types.BlockNotificationSummaryValue);
    }

    pub fn recvBlockSummaryNotificationTimeout(
        self: *Self,
        timeout_ms: u64,
    ) !pubsub_types.OwnedPubsubNotification(pubsub_types.BlockNotificationSummaryValue) {
        return self.subscription.recvParsedTimeout(pubsub_types.BlockNotificationSummaryValue, timeout_ms);
    }
};

pub fn TypedPubsubReceiver(comptime ValueType: type) type {
    return struct {
        subscription: *PubsubSubscription,
        receiver: PubsubReceiver,

        const Self = @This();

        pub fn isClosed(self: *const Self) bool {
            return self.receiver.isClosed();
        }

        pub fn queuedCount(self: *const Self) usize {
            return self.receiver.queuedCount();
        }

        pub fn droppedCount(self: *const Self) usize {
            return self.receiver.droppedCount();
        }

        pub fn closeReason(self: *const Self) PubsubCloseReason {
            return self.receiver.closeReason();
        }

        pub fn getLastError(self: *Self) ?RpcErrorDetail {
            return self.receiver.getLastError();
        }

        pub fn clearLastError(self: *Self) void {
            self.receiver.clearLastError();
        }

        pub fn unsubscribe(self: *Self) !bool {
            return self.subscription.unsubscribe();
        }

        pub fn recv(self: *Self) !pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.recvParsed(ValueType);
        }

        pub fn tryRecv(self: *Self) !?pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.tryRecvParsed(ValueType);
        }

        pub fn recvTimeout(self: *Self, timeout_ms: u64) !pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.recvParsedTimeout(ValueType, timeout_ms);
        }

        pub fn rawSubscription(self: *const Self) *PubsubSubscription {
            return self.subscription;
        }

        pub fn rawReceiver(self: *const Self) PubsubReceiver {
            return self.receiver;
        }
    };
}

pub const PubsubSubscriptionWithReceiver = struct {
    subscription: *PubsubSubscription,
    receiver: PubsubReceiver,

    const Self = @This();

    pub fn isClosed(self: *const Self) bool {
        return self.subscription.isClosed();
    }

    pub fn queuedCount(self: *const Self) usize {
        return self.receiver.queuedCount();
    }

    pub fn droppedCount(self: *const Self) usize {
        return self.receiver.droppedCount();
    }

    pub fn closeReason(self: *const Self) PubsubCloseReason {
        return self.receiver.closeReason();
    }

    pub fn getLastError(self: *Self) ?RpcErrorDetail {
        return self.subscription.getLastError();
    }

    pub fn clearLastError(self: *Self) void {
        self.subscription.clearLastError();
    }

    pub fn typedReceiver(self: *Self, comptime ValueType: type) TypedPubsubReceiver(ValueType) {
        return self.receiver.typedReceiver(ValueType);
    }

    pub fn unsubscribe(self: *Self) !bool {
        return self.subscription.unsubscribe();
    }

    pub fn deinit(self: *Self) void {
        self.subscription.deinit();
        self.* = undefined;
    }
};

pub fn TypedPubsubSubscription(comptime ValueType: type) type {
    return struct {
        subscription: *PubsubSubscription,
        receiver: TypedPubsubReceiver(ValueType),

        const Self = @This();

        pub fn isClosed(self: *const Self) bool {
            return self.subscription.isClosed();
        }

        pub fn queuedCount(self: *const Self) usize {
            return self.receiver.queuedCount();
        }

        pub fn droppedCount(self: *const Self) usize {
            return self.receiver.droppedCount();
        }

        pub fn closeReason(self: *const Self) PubsubCloseReason {
            return self.receiver.closeReason();
        }

        pub fn getLastError(self: *Self) ?RpcErrorDetail {
            return self.receiver.getLastError();
        }

        pub fn clearLastError(self: *Self) void {
            self.receiver.clearLastError();
        }

        pub fn recv(self: *Self) !pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.recv();
        }

        pub fn tryRecv(self: *Self) !?pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.tryRecv();
        }

        pub fn recvTimeout(self: *Self, timeout_ms: u64) !pubsub_types.OwnedPubsubNotification(ValueType) {
            return self.receiver.recvTimeout(timeout_ms);
        }

        pub fn unsubscribe(self: *Self) !bool {
            return self.subscription.unsubscribe();
        }

        pub fn deinit(self: *Self) void {
            self.subscription.deinit();
            self.* = undefined;
        }

        pub fn rawSubscription(self: *const Self) *PubsubSubscription {
            return self.subscription;
        }

        pub fn rawReceiver(self: *const Self) TypedPubsubReceiver(ValueType) {
            return self.receiver;
        }
    };
}

const State = struct {
    allocator: Allocator,
    endpoint: []const u8,
    options: PubsubClientOptions,
    ws_client: websocket.Client,
    reader_thread: ?std.Thread = null,
    heartbeat_thread: ?std.Thread = null,
    ref_count: std.atomic.Value(usize) = std.atomic.Value(usize).init(1),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    next_request_id: u64 = 1,
    subscriptions: std.AutoHashMapUnmanaged(u64, *PubsubSubscription) = .{},
    pending_requests: std.AutoHashMapUnmanaged(u64, *PendingRequest) = .{},
    last_error: ?RpcErrorDetail = null,
    last_activity_ns: std.atomic.Value(i64) = std.atomic.Value(i64).init(0),
    last_ping_ns: std.atomic.Value(i64) = std.atomic.Value(i64).init(0),
    closed: bool = false,
    reconnecting: bool = false,
    reconnect_attempt: u32 = 0,
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

    fn markActivityNow(self: *State) void {
        self.last_activity_ns.store(@as(i64, @intCast(std.time.nanoTimestamp())), .monotonic);
    }

    fn resetHeartbeatState(self: *State) void {
        self.last_ping_ns.store(0, .monotonic);
        self.markActivityNow();
    }

    fn reconnectDelayMsLocked(self: *State) u32 {
        const base_delay_ms = self.options.reconnect_delay_ms;
        const factor = @max(@as(u32, self.options.reconnect_backoff_factor), 1);
        const max_delay_ms = self.options.reconnect_max_delay_ms orelse base_delay_ms;

        if (base_delay_ms == 0) return 0;

        var delay_ms: u64 = base_delay_ms;
        var remaining_attempts = self.reconnect_attempt;
        while (remaining_attempts > 0 and delay_ms < max_delay_ms) : (remaining_attempts -= 1) {
            delay_ms = @min(delay_ms * factor, @as(u64, max_delay_ms));
        }

        if (self.reconnect_attempt < std.math.maxInt(u32)) {
            self.reconnect_attempt += 1;
        }

        return @intCast(delay_ms);
    }

    fn markClosedLocked(self: *State, reason: PubsubCloseReason) void {
        self.closed = true;
        self.reconnecting = false;

        var subscription_it = self.subscriptions.valueIterator();
        while (subscription_it.next()) |subscription| {
            subscription.*.mutex.lock();
            subscription.*.closeLocked(reason);
            subscription.*.mutex.unlock();
        }

        var pending_it = self.pending_requests.valueIterator();
        while (pending_it.next()) |pending| {
            pending.*.completed = true;
        }
        self.cond.broadcast();
    }

    fn failPendingRequestsLocked(self: *State) void {
        var pending_it = self.pending_requests.valueIterator();
        while (pending_it.next()) |pending| {
            if (pending.*.error_message == null) {
                pending.*.error_message = self.allocator.dupe(u8, "websocket connection closed") catch null;
            }
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
        self.markClosedLocked(.client_shutdown);
        const thread = self.reader_thread;
        self.reader_thread = null;
        const heartbeat_thread = self.heartbeat_thread;
        self.heartbeat_thread = null;
        self.failPendingRequestsLocked();
        self.cond.broadcast();
        self.mutex.unlock();

        self.ws_client.close(.{}) catch {};
        if (thread) |reader_thread| {
            reader_thread.join();
        }
        if (heartbeat_thread) |active_heartbeat_thread| {
            active_heartbeat_thread.join();
        }
        self.ws_client.deinit();
    }

    pub fn serverMessage(self: *State, data: []u8) !void {
        self.markActivityNow();
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

    pub fn serverPing(self: *State, data: []u8) !void {
        self.markActivityNow();
        self.mutex.lock();
        self.reconnect_attempt = 0;
        self.mutex.unlock();
        try self.ws_client.writePong(data);
    }

    pub fn serverPong(self: *State, data: []u8) !void {
        _ = data;
        self.markActivityNow();
        self.mutex.lock();
        self.reconnect_attempt = 0;
        self.mutex.unlock();
    }

    pub fn close(self: *State) void {
        self.handleReadLoopClose() catch {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.closed) return;
            self.failPendingRequestsLocked();
            self.markClosedLocked(.transport_closed);
        };
    }

    fn handleReadLoopClose(self: *State) !void {
        self.mutex.lock();
        if (self.shutdown_started or self.closed or !self.options.auto_reconnect) {
            if (!self.closed) {
                self.failPendingRequestsLocked();
                self.markClosedLocked(if (self.shutdown_started) .client_shutdown else .transport_closed);
            }
            self.mutex.unlock();
            return;
        }

        if (self.reconnecting) {
            self.mutex.unlock();
            return;
        }

        self.reconnecting = true;
        self.reader_thread = null;
        self.failPendingRequestsLocked();
        self.mutex.unlock();

        const old_client = self.ws_client;
        var owned_old_client = old_client;
        owned_old_client.deinit();

        while (true) {
            self.mutex.lock();
            if (self.shutdown_started or self.closed) {
                self.reconnecting = false;
                self.cond.broadcast();
                self.mutex.unlock();
                return error.Closed;
            }
            const reconnect_delay_ms = self.reconnectDelayMsLocked();
            self.mutex.unlock();

            if (reconnect_delay_ms > 0) {
                std.Thread.sleep(@as(u64, reconnect_delay_ms) * std.time.ns_per_ms);
            }

            var new_client = connectWebsocketClient(self.allocator, self.endpoint, self.options) catch |err| {
                self.mutex.lock();
                if (!self.closed and !self.shutdown_started) {
                    self.setLastError(-1, @errorName(err));
                }
                self.mutex.unlock();
                continue;
            };

            self.mutex.lock();
            if (self.shutdown_started or self.closed) {
                self.reconnecting = false;
                self.cond.broadcast();
                self.mutex.unlock();
                new_client.deinit();
                return error.Closed;
            }

            self.ws_client = new_client;
            self.reader_thread = try self.ws_client.readLoopInNewThread(self);
            try self.resubscribeAllLocked();
            self.reconnecting = false;
            self.resetHeartbeatState();
            self.cond.broadcast();
            self.mutex.unlock();
            return;
        }
    }

    fn resubscribeAllLocked(self: *State) !void {
        var subscriptions = std.ArrayListUnmanaged(*PubsubSubscription){};
        defer subscriptions.deinit(self.allocator);

        var it = self.subscriptions.valueIterator();
        while (it.next()) |subscription| {
            try subscriptions.append(self.allocator, subscription.*);
        }

        self.subscriptions.clearRetainingCapacity();

        for (subscriptions.items) |subscription| {
            subscription.id = 0;
            try self.resubscribeExisting(subscription);
        }
    }

    fn resubscribeExisting(self: *State, subscription: *PubsubSubscription) !void {
        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        self.mutex.unlock();
        defer self.mutex.lock();

        try self.sendRequestInternal(subscription.subscribe_method, subscription.subscribe_params_json, pending, false);
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
            if (pending.subscription) |subscription| {
                subscription.mutex.lock();
                subscription.setLastErrorLocked(code, message);
                subscription.mutex.unlock();
            }
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
                    subscription.mutex.lock();
                    defer subscription.mutex.unlock();
                    subscription.clearLastErrorLocked();

                    if (subscription.closed and subscription.close_reason == .unsubscribed) {
                        subscription.id = 0;
                    } else {
                        subscription.id = subscription_id;
                        try self.subscriptions.put(self.allocator, subscription_id, subscription);
                    }
                }
            },
            .unsubscribe => {
                const unsubscribe_ok = try jsonValueToBool(result_value);
                pending.unsubscribe_ok = unsubscribe_ok;
                if (pending.subscription) |subscription| {
                    subscription.mutex.lock();
                    defer subscription.mutex.unlock();
                    if (unsubscribe_ok) {
                        subscription.clearLastErrorLocked();
                        if (subscription.id != 0) {
                            _ = self.subscriptions.remove(subscription.id);
                        }
                        subscription.closeLocked(.unsubscribed);
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
        self.reconnect_attempt = 0;

        const subscription = self.subscriptions.get(subscription_id) orelse return;
        subscription.push(self.allocator, raw_message) catch |err| switch (err) {
            error.QueueOverflow => {
                _ = self.subscriptions.remove(subscription_id);
            },
            else => return err,
        };
    }

    fn sendRequest(
        self: *State,
        method: []const u8,
        params_json: []const u8,
        pending: *PendingRequest,
    ) !void {
        return self.sendRequestInternal(method, params_json, pending, true);
    }

    fn sendRequestInternal(
        self: *State,
        method: []const u8,
        params_json: []const u8,
        pending: *PendingRequest,
        wait_for_reconnect: bool,
    ) !void {
        self.mutex.lock();
        while (wait_for_reconnect and self.reconnecting and !self.closed) {
            self.cond.wait(&self.mutex);
        }
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
            return switch (pending.kind) {
                .subscribe => error.SubscribeRpcError,
                .unsubscribe => error.UnsubscribeRpcError,
            };
        }
    }

    fn allocateSubscription(
        self: *State,
        subscribe_method: []const u8,
        subscribe_params_json: []u8,
        unsubscribe_method: []const u8,
    ) !*PubsubSubscription {
        const subscription = try self.allocator.create(PubsubSubscription);
        errdefer self.allocator.destroy(subscription);

        self.retain();
        errdefer self.release();

        subscription.* = .{
            .state = self,
            .subscribe_method = subscribe_method,
            .subscribe_params_json = subscribe_params_json,
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

    fn buildBlockSubscribeConfig(self: *State, options: BlockSubscribeOptions) ![]u8 {
        var out = std.io.Writer.Allocating.init(self.allocator);
        errdefer out.deinit();

        try out.writer.writeByte('{');
        var wrote_field = false;

        if (options.commitment) |value| {
            try out.writer.writeAll("\"commitment\":");
            try appendJsonValue(&out.writer, rpc_types.commitmentToString(value));
            wrote_field = true;
        }

        if (options.encoding) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"encoding\":");
            try appendJsonValue(&out.writer, rpc_types.transactionEncodingToString(value));
            wrote_field = true;
        }

        if (options.transaction_details) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"transactionDetails\":");
            try appendJsonValue(&out.writer, rpc_types.transactionDetailsToString(value));
            wrote_field = true;
        }

        if (options.max_supported_transaction_version) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"maxSupportedTransactionVersion\":");
            try appendJsonValue(&out.writer, value);
            wrote_field = true;
        }

        if (options.show_rewards) |value| {
            if (wrote_field) try out.writer.writeByte(',');
            try out.writer.writeAll("\"showRewards\":");
            try appendJsonValue(&out.writer, value);
        }

        try out.writer.writeByte('}');
        return try out.toOwnedSlice();
    }

    fn subscribeSignature(self: *State, signature: []const u8, options: SignatureSubscribeOptions) !*PubsubSubscription {
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
        const subscription = self.allocateSubscription("signatureSubscribe", params_json, "signatureUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("signatureSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeAccount(
        self: *State,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !*PubsubSubscription {
        const config_json = try self.buildSubscribeConfig(options.commitment, options.encoding, null);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[\"{s}\",{s}]",
            .{ account, config_json },
        );
        const subscription = self.allocateSubscription("accountSubscribe", params_json, "accountUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("accountSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeLogs(
        self: *State,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !*PubsubSubscription {
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
        const subscription = self.allocateSubscription("logsSubscribe", params_json, "logsUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("logsSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeProgram(
        self: *State,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !*PubsubSubscription {
        const config_json = try self.buildProgramSubscribeConfig(options);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[\"{s}\",{s}]",
            .{ program_id, config_json },
        );
        const subscription = self.allocateSubscription("programSubscribe", params_json, "programUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("programSubscribe", params_json, pending);
        return subscription;
    }

    fn subscribeSlot(self: *State) !*PubsubSubscription {
        const params_json = try self.allocator.dupe(u8, "[]");
        const subscription = self.allocateSubscription("slotSubscribe", params_json, "slotUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

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
        const params_json = try self.allocator.dupe(u8, "[]");
        const subscription = self.allocateSubscription("rootSubscribe", params_json, "rootUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("rootSubscribe", "[]", pending);
        return subscription;
    }

    fn subscribeSlotsUpdates(self: *State) !*PubsubSubscription {
        const params_json = try self.allocator.dupe(u8, "[]");
        const subscription = self.allocateSubscription("slotsUpdatesSubscribe", params_json, "slotsUpdatesUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("slotsUpdatesSubscribe", "[]", pending);
        return subscription;
    }

    fn subscribeVote(self: *State) !*PubsubSubscription {
        const params_json = try self.allocator.dupe(u8, "[]");
        const subscription = self.allocateSubscription("voteSubscribe", params_json, "voteUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("voteSubscribe", "[]", pending);
        return subscription;
    }

    fn subscribeBlock(
        self: *State,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !*PubsubSubscription {
        const filter_json = switch (filter) {
            .all => try self.allocator.dupe(u8, "\"all\""),
            .mentions_account_or_program => |mention| try std.fmt.allocPrint(
                self.allocator,
                "{{\"mentionsAccountOrProgram\":\"{s}\"}}",
                .{mention},
            ),
        };
        defer self.allocator.free(filter_json);

        const config_json = try self.buildBlockSubscribeConfig(options);
        defer self.allocator.free(config_json);

        const params_json = try std.fmt.allocPrint(
            self.allocator,
            "[{s},{s}]",
            .{ filter_json, config_json },
        );
        const subscription = self.allocateSubscription("blockSubscribe", params_json, "blockUnsubscribe") catch |err| {
            self.allocator.free(params_json);
            return err;
        };
        errdefer subscription.deinit();

        const pending = try self.allocator.create(PendingRequest);
        defer pending.deinit(self.allocator);
        pending.* = .{
            .kind = .subscribe,
            .subscription = subscription,
        };

        try self.sendRequest("blockSubscribe", params_json, pending);
        return subscription;
    }

    fn unsubscribe(self: *State, subscription: *PubsubSubscription) !bool {
        self.mutex.lock();

        if (subscription.closed and subscription.close_reason == .unsubscribed) {
            self.mutex.unlock();
            return false;
        }

        if (self.reconnecting or subscription.id == 0) {
            if (subscription.id != 0) {
                _ = self.subscriptions.remove(subscription.id);
                subscription.id = 0;
            }

            subscription.mutex.lock();
            subscription.clearLastErrorLocked();
            subscription.closeLocked(.unsubscribed);
            subscription.mutex.unlock();

            self.mutex.unlock();
            return true;
        }

        self.mutex.unlock();

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

    fn heartbeatLoop(self: *State) void {
        const interval_ms = self.options.heartbeat_interval_ms orelse return;
        const timeout_ms = self.options.heartbeat_timeout_ms orelse interval_ms * 3;
        const timeout_ns = @as(i128, @intCast(timeout_ms)) * std.time.ns_per_ms;

        while (true) {
            self.mutex.lock();
            if (self.shutdown_started or self.closed) {
                self.mutex.unlock();
                return;
            }

            self.cond.timedWait(&self.mutex, @as(u64, interval_ms) * std.time.ns_per_ms) catch |err| switch (err) {
                error.Timeout => {},
            };

            if (self.shutdown_started or self.closed) {
                self.mutex.unlock();
                return;
            }

            const reconnecting = self.reconnecting;
            const last_ping_ns = self.last_ping_ns.load(.monotonic);
            const last_activity_ns = self.last_activity_ns.load(.monotonic);
            self.mutex.unlock();

            if (reconnecting) continue;

            const now_ns = @as(i64, @intCast(std.time.nanoTimestamp()));
            if (last_ping_ns != 0 and last_activity_ns < last_ping_ns) {
                if (@as(i128, now_ns - last_ping_ns) >= timeout_ns) {
                    self.ws_client.close(.{}) catch {};
                }
                continue;
            }

            var ping_payload = [_]u8{ 'p', 'i', 'n', 'g' };
            self.last_ping_ns.store(now_ns, .monotonic);
            self.ws_client.writePing(ping_payload[0..]) catch {
                self.ws_client.close(.{}) catch {};
            };
        }
    }

    fn heartbeatLoopThread(self: *State) void {
        self.heartbeatLoop();
    }
};

pub const PubsubClient = struct {
    state: *State,

    const Self = @This();

    fn typedSubscription(
        comptime ValueType: type,
        subscription: *PubsubSubscription,
    ) TypedPubsubSubscription(ValueType) {
        return .{
            .subscription = subscription,
            .receiver = subscription.typedReceiver(ValueType),
        };
    }

    pub fn init(allocator: Allocator, endpoint: []const u8) !Self {
        return Self.initWithOptions(allocator, endpoint, .{});
    }

    pub fn initWithOptions(
        allocator: Allocator,
        endpoint: []const u8,
        options: PubsubClientOptions,
    ) !Self {
        var ws_client = try connectWebsocketClient(allocator, endpoint, options);
        errdefer ws_client.deinit();

        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        state.* = .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .options = options,
            .ws_client = ws_client,
        };
        errdefer allocator.free(state.endpoint);

        state.resetHeartbeatState();
        state.reader_thread = try state.ws_client.readLoopInNewThread(state);
        if (options.heartbeat_interval_ms != null) {
            state.heartbeat_thread = try std.Thread.spawn(.{}, State.heartbeatLoopThread, .{state});
        }
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

    pub fn isReconnecting(self: *const Self) bool {
        self.state.mutex.lock();
        defer self.state.mutex.unlock();
        return self.state.reconnecting;
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

    pub fn signatureSubscribeWithReceiver(
        self: *Self,
        signature: []const u8,
        options: SignatureSubscribeOptions,
    ) !PubsubSubscriptionWithReceiver {
        const subscription = try self.signatureSubscribe(signature, options);
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn signatureSubscribeTyped(
        self: *Self,
        signature: []const u8,
        options: SignatureSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.SignatureNotificationValue) {
        return typedSubscription(pubsub_types.SignatureNotificationValue, try self.signatureSubscribe(signature, options));
    }

    pub fn signatureSubscribeSummaryTyped(
        self: *Self,
        signature: []const u8,
        options: SignatureSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.SignatureNotificationSummaryValue) {
        return typedSubscription(pubsub_types.SignatureNotificationSummaryValue, try self.signatureSubscribe(signature, options));
    }

    pub fn accountSubscribe(
        self: *Self,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeAccount(account, options);
    }

    pub fn accountSubscribeWithReceiver(
        self: *Self,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !PubsubSubscriptionWithReceiver {
        const subscription = try self.accountSubscribe(account, options);
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn accountSubscribeTyped(
        self: *Self,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.AccountNotificationValue) {
        return typedSubscription(pubsub_types.AccountNotificationValue, try self.accountSubscribe(account, options));
    }

    pub fn accountSubscribeSummaryTyped(
        self: *Self,
        account: []const u8,
        options: AccountSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.AccountNotificationSummaryValue) {
        return typedSubscription(pubsub_types.AccountNotificationSummaryValue, try self.accountSubscribe(account, options));
    }

    pub fn logsSubscribe(
        self: *Self,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeLogs(filter, options);
    }

    pub fn logsSubscribeWithReceiver(
        self: *Self,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !PubsubSubscriptionWithReceiver {
        const subscription = try self.logsSubscribe(filter, options);
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn logsSubscribeTyped(
        self: *Self,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.LogsNotificationValue) {
        return typedSubscription(pubsub_types.LogsNotificationValue, try self.logsSubscribe(filter, options));
    }

    pub fn logsSubscribeSummaryTyped(
        self: *Self,
        filter: LogsSubscribeFilter,
        options: LogsSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.LogsNotificationSummaryValue) {
        return typedSubscription(pubsub_types.LogsNotificationSummaryValue, try self.logsSubscribe(filter, options));
    }

    pub fn programSubscribe(
        self: *Self,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeProgram(program_id, options);
    }

    pub fn programSubscribeWithReceiver(
        self: *Self,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !PubsubSubscriptionWithReceiver {
        const subscription = try self.programSubscribe(program_id, options);
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn programSubscribeTyped(
        self: *Self,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.ProgramNotificationValue) {
        return typedSubscription(pubsub_types.ProgramNotificationValue, try self.programSubscribe(program_id, options));
    }

    pub fn programSubscribeSummaryTyped(
        self: *Self,
        program_id: []const u8,
        options: ProgramSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.ProgramNotificationSummaryValue) {
        return typedSubscription(pubsub_types.ProgramNotificationSummaryValue, try self.programSubscribe(program_id, options));
    }

    pub fn slotSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeSlot();
    }

    pub fn slotSubscribeWithReceiver(self: *Self) !PubsubSubscriptionWithReceiver {
        const subscription = try self.slotSubscribe();
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn slotSubscribeTyped(self: *Self) !TypedPubsubSubscription(pubsub_types.SlotNotificationValue) {
        return typedSubscription(pubsub_types.SlotNotificationValue, try self.slotSubscribe());
    }

    pub fn rootSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeRoot();
    }

    pub fn rootSubscribeWithReceiver(self: *Self) !PubsubSubscriptionWithReceiver {
        const subscription = try self.rootSubscribe();
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn rootSubscribeTyped(self: *Self) !TypedPubsubSubscription(pubsub_types.RootNotificationValue) {
        return typedSubscription(pubsub_types.RootNotificationValue, try self.rootSubscribe());
    }

    pub fn slotsUpdatesSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeSlotsUpdates();
    }

    pub fn slotsUpdatesSubscribeWithReceiver(self: *Self) !PubsubSubscriptionWithReceiver {
        const subscription = try self.slotsUpdatesSubscribe();
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn slotsUpdatesSubscribeTyped(self: *Self) !TypedPubsubSubscription(pubsub_types.SlotsUpdatesNotificationValue) {
        return typedSubscription(pubsub_types.SlotsUpdatesNotificationValue, try self.slotsUpdatesSubscribe());
    }

    pub fn voteSubscribe(self: *Self) !*PubsubSubscription {
        return self.state.subscribeVote();
    }

    pub fn voteSubscribeWithReceiver(self: *Self) !PubsubSubscriptionWithReceiver {
        const subscription = try self.voteSubscribe();
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn voteSubscribeTyped(self: *Self) !TypedPubsubSubscription(pubsub_types.VoteNotificationValue) {
        return typedSubscription(pubsub_types.VoteNotificationValue, try self.voteSubscribe());
    }

    pub fn blockSubscribe(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !*PubsubSubscription {
        return self.state.subscribeBlock(filter, options);
    }

    pub fn blockSubscribeWithReceiver(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !PubsubSubscriptionWithReceiver {
        const subscription = try self.blockSubscribe(filter, options);
        return .{ .subscription = subscription, .receiver = subscription.receiver() };
    }

    pub fn blockSubscribeTyped(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.BlockNotificationValue) {
        return typedSubscription(pubsub_types.BlockNotificationValue, try self.blockSubscribe(filter, options));
    }

    pub fn blockSubscribeSignaturesTyped(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.BlockNotificationSignaturesValue) {
        return typedSubscription(pubsub_types.BlockNotificationSignaturesValue, try self.blockSubscribe(filter, options));
    }

    pub fn blockSubscribeAccountsTyped(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.BlockNotificationAccountsValue) {
        return typedSubscription(pubsub_types.BlockNotificationAccountsValue, try self.blockSubscribe(filter, options));
    }

    pub fn blockSubscribeTransactionSummariesTyped(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.BlockNotificationTransactionSummariesValue) {
        return typedSubscription(pubsub_types.BlockNotificationTransactionSummariesValue, try self.blockSubscribe(filter, options));
    }

    pub fn blockSubscribeSummaryTyped(
        self: *Self,
        filter: BlockSubscribeFilter,
        options: BlockSubscribeOptions,
    ) !TypedPubsubSubscription(pubsub_types.BlockNotificationSummaryValue) {
        return typedSubscription(pubsub_types.BlockNotificationSummaryValue, try self.blockSubscribe(filter, options));
    }

    pub fn unsubscribe(self: *Self, subscription: *PubsubSubscription) !bool {
        return self.state.unsubscribe(subscription);
    }
};
