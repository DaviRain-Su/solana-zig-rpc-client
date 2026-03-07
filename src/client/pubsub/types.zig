const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

pub const PubsubClientOptions = struct {
    handshake_timeout_ms: u32 = 10_000,
    write_timeout_ms: ?u32 = null,
    max_message_size: usize = 256 * 1024,
    buffer_size: usize = 8 * 1024,
};

pub const SignatureSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
    enable_received_notification: bool = false,
};

pub const PubsubAccountEncoding = enum {
    base58,
    base64,
    json_parsed,
};

pub fn pubsubAccountEncodingToString(encoding: PubsubAccountEncoding) []const u8 {
    return switch (encoding) {
        .base58 => "base58",
        .base64 => "base64",
        .json_parsed => "jsonParsed",
    };
}

pub const AccountSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
    encoding: PubsubAccountEncoding = .json_parsed,
};

pub const LogsSubscribeFilter = union(enum) {
    all,
    all_with_votes,
    mentions: []const u8,
};

pub const LogsSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
};

pub const ProgramSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
    encoding: PubsubAccountEncoding = .json_parsed,
    data_size: ?u64 = null,
    memcmp_offset: ?u64 = null,
    memcmp_bytes: ?[]const u8 = null,
};

pub const PubsubContext = struct {
    slot: u64 = 0,
};

pub const SignatureNotificationValue = struct {
    received_signature: bool = false,
    err: ?json.Value = null,

    pub fn jsonParseFromValue(
        _: std.mem.Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !@This() {
        return switch (source) {
            .string => |value| blk: {
                if (std.mem.eql(u8, value, "receivedSignature")) {
                    break :blk .{ .received_signature = true, .err = null };
                }
                return error.InvalidEnumTag;
            },
            .object => .{
                .received_signature = false,
                .err = if (source.object.get("err")) |err_value|
                    switch (err_value) {
                        .null => null,
                        else => err_value,
                    }
                else
                    null,
            },
            else => error.UnexpectedToken,
        };
    }
};

pub const AccountNotificationValue = rpc_types.RpcJsonParsedAccountInfoResult;

pub const LogsNotificationValue = struct {
    signature: []const u8 = "",
    err: ?json.Value = null,
    logs: []const []const u8 = &.{},
};

pub const ProgramNotificationValue = rpc_types.RpcJsonParsedProgramAccountResult;

pub const SlotNotificationValue = struct {
    parent: u64 = 0,
    root: u64 = 0,
    slot: u64 = 0,
};

pub const RootNotificationValue = u64;

pub fn PubsubNotification(comptime ValueType: type) type {
    return struct {
        subscription: u64 = 0,
        context_slot: ?u64 = null,
        value: ValueType,
    };
}

pub fn OwnedPubsubNotification(comptime ValueType: type) type {
    return struct {
        allocator: std.mem.Allocator,
        arena: std.heap.ArenaAllocator,
        raw_message: []u8,
        notification: PubsubNotification(ValueType),

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.allocator.free(self.raw_message);
            self.* = undefined;
        }
    };
}

pub fn parseOwnedPubsubNotification(
    allocator: std.mem.Allocator,
    raw_message: []u8,
    comptime ValueType: type,
) !OwnedPubsubNotification(ValueType) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    errdefer allocator.free(raw_message);

    const Envelope = struct {
        params: struct {
            subscription: u64 = 0,
            result: json.Value = .null,
        },
    };

    const parsed = try json.parseFromSliceLeaky(
        Envelope,
        arena.allocator(),
        raw_message,
        .{ .ignore_unknown_fields = true },
    );

    var context_slot: ?u64 = null;
    var notification_value_source = parsed.params.result;
    if (notification_value_source == .object) {
        if (notification_value_source.object.get("value")) |value| {
            notification_value_source = value;
            if (notification_value_source != .null) {
                if (parsed.params.result.object.get("context")) |context_value| {
                    if (context_value == .object) {
                        if (context_value.object.get("slot")) |slot_value| {
                            context_slot = switch (slot_value) {
                                .integer => |integer| std.math.cast(u64, integer) orelse return error.InvalidResponse,
                                .number_string => |number| try std.fmt.parseInt(u64, number, 10),
                                else => return error.InvalidResponse,
                            };
                        }
                    }
                }
            }
        }
    }

    const parsed_value = try json.parseFromValueLeaky(
        ValueType,
        arena.allocator(),
        notification_value_source,
        .{ .ignore_unknown_fields = true },
    );

    return .{
        .allocator = allocator,
        .arena = arena,
        .raw_message = raw_message,
        .notification = .{
            .subscription = parsed.params.subscription,
            .context_slot = context_slot,
            .value = parsed_value,
        },
    };
}
