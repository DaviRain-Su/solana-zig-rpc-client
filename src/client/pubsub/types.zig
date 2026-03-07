const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

pub const PubsubClientOptions = struct {
    handshake_timeout_ms: u32 = 10_000,
    write_timeout_ms: ?u32 = null,
    max_message_size: usize = 256 * 1024,
    buffer_size: usize = 8 * 1024,
    heartbeat_interval_ms: ?u32 = null,
    heartbeat_timeout_ms: ?u32 = null,
    subscription_queue_limit: usize = 256,
    queue_overflow_policy: PubsubQueueOverflowPolicy = .drop_oldest,
    auto_reconnect: bool = false,
    reconnect_delay_ms: u32 = 250,
    reconnect_backoff_factor: u8 = 2,
    reconnect_max_delay_ms: ?u32 = null,
    reconnect_max_attempts: ?u32 = null,
};

pub const PubsubQueueOverflowPolicy = enum {
    drop_oldest,
    drop_newest,
    close_subscription,
};

pub const PubsubCloseReason = enum {
    none,
    unsubscribed,
    transport_closed,
    client_shutdown,
    queue_overflow,
    deinitialized,
};

pub const PubsubCloseResult = struct {
    reason: PubsubCloseReason,
    dropped_messages: usize = 0,
    last_error: ?rpc_types.RpcErrorDetail = null,
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

pub const SlotSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
};

pub const ProgramSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
    encoding: PubsubAccountEncoding = .json_parsed,
    data_size: ?u64 = null,
    memcmp_offset: ?u64 = null,
    memcmp_bytes: ?[]const u8 = null,
};

pub const BlockSubscribeFilter = union(enum) {
    all,
    mentions_account_or_program: []const u8,
};

pub const BlockSubscribeOptions = struct {
    commitment: ?rpc_types.Commitment = null,
    encoding: ?rpc_types.TransactionEncoding = null,
    transaction_details: ?rpc_types.TransactionDetails = null,
    max_supported_transaction_version: ?u8 = null,
    show_rewards: ?bool = null,
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

pub const SignatureNotificationSummaryValue = struct {
    receivedSignature: bool = false,
    hasError: bool = false,
    errJson: ?[]const u8 = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !@This() {
        return switch (source) {
            .string => |value| blk: {
                if (std.mem.eql(u8, value, "receivedSignature")) {
                    break :blk .{
                        .receivedSignature = true,
                        .hasError = false,
                        .errJson = null,
                    };
                }
                return error.InvalidEnumTag;
            },
            .object => blk: {
                const err_json = if (source.object.get("err")) |err_value|
                    try summarizeErrorValue(allocator, err_value)
                else
                    null;
                break :blk .{
                    .receivedSignature = false,
                    .hasError = err_json != null,
                    .errJson = err_json,
                };
            },
            else => error.UnexpectedToken,
        };
    }
};

pub const AccountNotificationValue = rpc_types.RpcJsonParsedAccountInfoResult;

pub const ParsedAccountDataSummary = struct {
    program: ?[]const u8 = null,
    parsedType: ?[]const u8 = null,
    info: ?ParsedAccountInfoSummary = null,
};

pub const ParsedAccountInfoSummary = struct {
    authority: ?[]const u8 = null,
    blockhash: ?[]const u8 = null,
    lamportsPerSignature: ?u64 = null,
    mint: ?[]const u8 = null,
    owner: ?[]const u8 = null,
    state: ?[]const u8 = null,
    tokenAmountAmount: ?[]const u8 = null,
    tokenAmountDecimals: ?u8 = null,
    tokenAmountUiAmountString: ?[]const u8 = null,
};

pub const AccountNotificationSummaryValue = struct {
    lamports: u64 = 0,
    owner: []const u8 = "",
    executable: bool = false,
    rentEpoch: ?u64 = null,
    space: ?u64 = null,
    dataSummary: ?ParsedAccountDataSummary = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            data: json.Value = .null,
            executable: bool = false,
            lamports: u64 = 0,
            owner: []const u8 = "",
            rentEpoch: ?u64 = null,
            space: ?u64 = null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        return .{
            .lamports = parsed.lamports,
            .owner = parsed.owner,
            .executable = parsed.executable,
            .rentEpoch = parsed.rentEpoch,
            .space = parsed.space,
            .dataSummary = summarizeParsedAccountData(parsed.data),
        };
    }
};

pub const LogsNotificationValue = struct {
    signature: []const u8 = "",
    err: ?json.Value = null,
    logs: []const []const u8 = &.{},
};

pub const LogsNotificationSummaryValue = struct {
    signature: []const u8 = "",
    hasError: bool = false,
    errJson: ?[]const u8 = null,
    logsCount: usize = 0,
    firstLog: ?[]const u8 = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const parsed = try json.parseFromValueLeaky(LogsNotificationValue, allocator, source, options);
        return .{
            .signature = parsed.signature,
            .hasError = parsed.err != null,
            .errJson = if (parsed.err) |err_value|
                try summarizeErrorValue(allocator, err_value)
            else
                null,
            .logsCount = parsed.logs.len,
            .firstLog = if (parsed.logs.len > 0) parsed.logs[0] else null,
        };
    }
};

pub const ProgramNotificationValue = rpc_types.RpcJsonParsedProgramAccountResult;

pub const ProgramNotificationSummaryValue = struct {
    pubkey: []const u8 = "",
    account: AccountNotificationSummaryValue = .{},

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            pubkey: []const u8 = "",
            account: json.Value = .null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        return .{
            .pubkey = parsed.pubkey,
            .account = try json.parseFromValueLeaky(AccountNotificationSummaryValue, allocator, parsed.account, options),
        };
    }
};

pub const SlotNotificationValue = struct {
    parent: u64 = 0,
    root: u64 = 0,
    slot: u64 = 0,
};

pub const SlotsUpdatesStats = struct {
    maxTransactionsPerEntry: u64 = 0,
    numFailedTransactions: u64 = 0,
    numSuccessfulTransactions: u64 = 0,
    numTransactionEntries: u64 = 0,
};

pub const SlotsUpdatesNotificationValue = struct {
    err: ?[]const u8 = null,
    parent: ?u64 = null,
    slot: u64 = 0,
    stats: ?SlotsUpdatesStats = null,
    timestamp: i64 = 0,
    type: []const u8 = "",
};

pub const RootNotificationValue = u64;

pub const BlockNotificationValue = struct {
    slot: u64 = 0,
    err: ?json.Value = null,
    block: ?json.Value = null,
};

pub const BlockNotificationBlockSummary = struct {
    blockhash: []const u8 = "",
    previousBlockhash: ?[]const u8 = null,
    parentSlot: u64 = 0,
    blockHeight: ?u64 = null,
    blockTime: ?i64 = null,
    transactionsCount: ?usize = null,
    rewardsCount: ?usize = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            blockhash: []const u8 = "",
            previousBlockhash: ?[]const u8 = null,
            parentSlot: u64 = 0,
            blockHeight: ?u64 = null,
            blockTime: ?i64 = null,
            transactions: ?[]json.Value = null,
            rewards: ?[]json.Value = null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        return .{
            .blockhash = parsed.blockhash,
            .previousBlockhash = parsed.previousBlockhash,
            .parentSlot = parsed.parentSlot,
            .blockHeight = parsed.blockHeight,
            .blockTime = parsed.blockTime,
            .transactionsCount = if (parsed.transactions) |value| value.len else null,
            .rewardsCount = if (parsed.rewards) |value| value.len else null,
        };
    }
};

pub const BlockNotificationSummaryValue = struct {
    slot: u64 = 0,
    err: ?json.Value = null,
    block: ?BlockNotificationBlockSummary = null,
};

pub const BlockNotificationTransactionSignatures = struct {
    signatures: []const []const u8 = &.{},
};

pub const BlockNotificationParsedAccountKey = struct {
    pubkey: []const u8 = "",
    writable: bool = false,
    signer: bool = false,
    source: ?[]const u8 = null,
};

pub const BlockNotificationTransactionAccounts = struct {
    signatures: []const []const u8 = &.{},
    accountKeys: []const BlockNotificationParsedAccountKey = &.{},
};

pub const BlockNotificationSignaturesBlock = struct {
    blockhash: []const u8 = "",
    previousBlockhash: ?[]const u8 = null,
    parentSlot: u64 = 0,
    blockHeight: ?u64 = null,
    blockTime: ?i64 = null,
    transactions: []const BlockNotificationTransactionSignatures = &.{},
    rewardsCount: ?usize = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const ParsedTransaction = struct {
            transaction: struct {
                signatures: []const []const u8 = &.{},
            } = .{},
        };
        const Parsed = struct {
            blockhash: []const u8 = "",
            previousBlockhash: ?[]const u8 = null,
            parentSlot: u64 = 0,
            blockHeight: ?u64 = null,
            blockTime: ?i64 = null,
            transactions: ?[]json.Value = null,
            rewards: ?[]json.Value = null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const transactions = if (parsed.transactions) |values| blk: {
            const result = try allocator.alloc(BlockNotificationTransactionSignatures, values.len);
            for (values, 0..) |value, index| {
                const parsed_transaction = try json.parseFromValueLeaky(ParsedTransaction, allocator, value, options);
                result[index] = .{
                    .signatures = parsed_transaction.transaction.signatures,
                };
            }
            break :blk result;
        } else &.{};

        return .{
            .blockhash = parsed.blockhash,
            .previousBlockhash = parsed.previousBlockhash,
            .parentSlot = parsed.parentSlot,
            .blockHeight = parsed.blockHeight,
            .blockTime = parsed.blockTime,
            .transactions = transactions,
            .rewardsCount = if (parsed.rewards) |value| value.len else null,
        };
    }
};

pub const BlockNotificationSignaturesValue = struct {
    slot: u64 = 0,
    hasError: bool = false,
    errJson: ?[]const u8 = null,
    block: ?BlockNotificationSignaturesBlock = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            slot: u64 = 0,
            err: json.Value = .null,
            block: json.Value = .null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const err_json = try summarizeErrorValue(allocator, parsed.err);
        return .{
            .slot = parsed.slot,
            .hasError = err_json != null,
            .errJson = err_json,
            .block = if (parsed.block == .null)
                null
            else
                try json.parseFromValueLeaky(BlockNotificationSignaturesBlock, allocator, parsed.block, options),
        };
    }
};

pub const BlockNotificationAccountsBlock = struct {
    blockhash: []const u8 = "",
    previousBlockhash: ?[]const u8 = null,
    parentSlot: u64 = 0,
    blockHeight: ?u64 = null,
    blockTime: ?i64 = null,
    transactions: []const BlockNotificationTransactionAccounts = &.{},
    rewardsCount: ?usize = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const ParsedAccountKey = struct {
            pubkey: []const u8 = "",
            writable: bool = false,
            signer: bool = false,
            source: ?[]const u8 = null,
        };
        const ParsedTransaction = struct {
            transaction: struct {
                signatures: []const []const u8 = &.{},
                accountKeys: []const ParsedAccountKey = &.{},
            } = .{},
        };
        const Parsed = struct {
            blockhash: []const u8 = "",
            previousBlockhash: ?[]const u8 = null,
            parentSlot: u64 = 0,
            blockHeight: ?u64 = null,
            blockTime: ?i64 = null,
            transactions: ?[]json.Value = null,
            rewards: ?[]json.Value = null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const transactions = if (parsed.transactions) |values| blk: {
            const result = try allocator.alloc(BlockNotificationTransactionAccounts, values.len);
            for (values, 0..) |value, index| {
                const parsed_transaction = try json.parseFromValueLeaky(ParsedTransaction, allocator, value, options);
                const account_keys = try allocator.alloc(BlockNotificationParsedAccountKey, parsed_transaction.transaction.accountKeys.len);
                for (parsed_transaction.transaction.accountKeys, 0..) |account_key, account_index| {
                    account_keys[account_index] = .{
                        .pubkey = account_key.pubkey,
                        .writable = account_key.writable,
                        .signer = account_key.signer,
                        .source = account_key.source,
                    };
                }
                result[index] = .{
                    .signatures = parsed_transaction.transaction.signatures,
                    .accountKeys = account_keys,
                };
            }
            break :blk result;
        } else &.{};

        return .{
            .blockhash = parsed.blockhash,
            .previousBlockhash = parsed.previousBlockhash,
            .parentSlot = parsed.parentSlot,
            .blockHeight = parsed.blockHeight,
            .blockTime = parsed.blockTime,
            .transactions = transactions,
            .rewardsCount = if (parsed.rewards) |value| value.len else null,
        };
    }
};

pub const BlockNotificationAccountsValue = struct {
    slot: u64 = 0,
    hasError: bool = false,
    errJson: ?[]const u8 = null,
    block: ?BlockNotificationAccountsBlock = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            slot: u64 = 0,
            err: json.Value = .null,
            block: json.Value = .null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const err_json = try summarizeErrorValue(allocator, parsed.err);
        return .{
            .slot = parsed.slot,
            .hasError = err_json != null,
            .errJson = err_json,
            .block = if (parsed.block == .null)
                null
            else
                try json.parseFromValueLeaky(BlockNotificationAccountsBlock, allocator, parsed.block, options),
        };
    }
};

pub const BlockNotificationTransactionSummary = struct {
    slot: u64 = 0,
    block_time: ?i64 = null,
    version: ?[]const u8 = null,
    signature_count: ?usize = null,
    account_key_count: ?usize = null,
    instruction_count: ?usize = null,
    address_table_lookup_count: ?usize = null,
    loaded_address_count: ?usize = null,
    fee: ?u64 = null,
    log_messages_count: ?usize = null,
    has_error: bool = false,
    error_json: ?[]const u8 = null,
};

pub const BlockNotificationTransactionSummariesBlock = struct {
    blockhash: []const u8 = "",
    previousBlockhash: ?[]const u8 = null,
    parentSlot: u64 = 0,
    blockHeight: ?u64 = null,
    blockTime: ?i64 = null,
    transactions: []const BlockNotificationTransactionSummary = &.{},
    rewardsCount: ?usize = null,

    pub fn parseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        slot: u64,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            blockhash: []const u8 = "",
            previousBlockhash: ?[]const u8 = null,
            parentSlot: u64 = 0,
            blockHeight: ?u64 = null,
            blockTime: ?i64 = null,
            transactions: ?[]json.Value = null,
            rewards: ?[]json.Value = null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const transactions = if (parsed.transactions) |values| blk: {
            const result = try allocator.alloc(BlockNotificationTransactionSummary, values.len);
            for (values, 0..) |value, index| {
                result[index] = try summarizeTransactionValue(allocator, value, slot, parsed.blockTime, options);
            }
            break :blk result;
        } else &.{};

        return .{
            .blockhash = parsed.blockhash,
            .previousBlockhash = parsed.previousBlockhash,
            .parentSlot = parsed.parentSlot,
            .blockHeight = parsed.blockHeight,
            .blockTime = parsed.blockTime,
            .transactions = transactions,
            .rewardsCount = if (parsed.rewards) |value| value.len else null,
        };
    }
};

pub const BlockNotificationTransactionSummariesValue = struct {
    slot: u64 = 0,
    hasError: bool = false,
    errJson: ?[]const u8 = null,
    block: ?BlockNotificationTransactionSummariesBlock = null,

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !@This() {
        const Parsed = struct {
            slot: u64 = 0,
            err: json.Value = .null,
            block: json.Value = .null,
        };

        const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
        const err_json = try summarizeErrorValue(allocator, parsed.err);
        return .{
            .slot = parsed.slot,
            .hasError = err_json != null,
            .errJson = err_json,
            .block = if (parsed.block == .null)
                null
            else
                try BlockNotificationTransactionSummariesBlock.parseFromValue(
                    allocator,
                    parsed.block,
                    parsed.slot,
                    options,
                ),
        };
    }
};

pub const VoteNotificationValue = struct {
    hash: []const u8 = "",
    slots: []const u64 = &.{},
    timestamp: ?i64 = null,
    signature: []const u8 = "",
    votePubkey: []const u8 = "",
};

fn summarizeParsedAccountData(source: json.Value) ?ParsedAccountDataSummary {
    if (source != .object) return null;

    var summary: ParsedAccountDataSummary = .{};
    if (source.object.get("program")) |program_value| {
        if (program_value == .string) {
            summary.program = program_value.string;
        }
    }

    if (source.object.get("parsed")) |parsed_value| {
        if (parsed_value == .object) {
            if (parsed_value.object.get("type")) |type_value| {
                if (type_value == .string) {
                    summary.parsedType = type_value.string;
                }
            }

            if (parsed_value.object.get("info")) |info_value| {
                summary.info = summarizeParsedAccountInfo(info_value);
            }
        }
    }

    if (summary.program == null and summary.parsedType == null and summary.info == null) return null;
    return summary;
}

fn summarizeErrorValue(allocator: std.mem.Allocator, value: json.Value) !?[]const u8 {
    return switch (value) {
        .null => null,
        .string => |text| try allocator.dupe(u8, text),
        else => try json.Stringify.valueAlloc(allocator, value, .{}),
    };
}

fn summarizeTransactionValue(
    allocator: std.mem.Allocator,
    source: json.Value,
    slot: u64,
    block_time: ?i64,
    options: json.ParseOptions,
) !BlockNotificationTransactionSummary {
    const Parsed = struct {
        version: ?json.Value = null,
        meta: ?struct {
            err: json.Value = .null,
            fee: ?u64 = null,
            logMessages: ?[]json.Value = null,
            loadedAddresses: ?struct {
                writable: ?[]json.Value = null,
                readonly: ?[]json.Value = null,
            } = null,
        } = null,
        transaction: ?struct {
            signatures: []const []const u8 = &.{},
            message: ?struct {
                accountKeys: ?[]json.Value = null,
                instructions: ?[]json.Value = null,
                addressTableLookups: ?[]json.Value = null,
            } = null,
        } = null,
    };

    const parsed = try json.parseFromValueLeaky(Parsed, allocator, source, options);
    const error_json = if (parsed.meta) |meta|
        try summarizeErrorValue(allocator, meta.err)
    else
        null;

    return .{
        .slot = slot,
        .block_time = block_time,
        .version = if (parsed.version) |value| try summarizeErrorValue(allocator, value) else null,
        .signature_count = if (parsed.transaction) |transaction| transaction.signatures.len else null,
        .account_key_count = if (parsed.transaction) |transaction|
            if (transaction.message) |message|
                if (message.accountKeys) |account_keys| account_keys.len else null
            else
                null
        else
            null,
        .instruction_count = if (parsed.transaction) |transaction|
            if (transaction.message) |message|
                if (message.instructions) |instructions| instructions.len else null
            else
                null
        else
            null,
        .address_table_lookup_count = if (parsed.transaction) |transaction|
            if (transaction.message) |message|
                if (message.addressTableLookups) |lookups| lookups.len else null
            else
                null
        else
            null,
        .loaded_address_count = if (parsed.meta) |meta|
            if (meta.loadedAddresses) |loaded_addresses|
                (if (loaded_addresses.writable) |writable| writable.len else 0) +
                    (if (loaded_addresses.readonly) |readonly| readonly.len else 0)
            else
                null
        else
            null,
        .fee = if (parsed.meta) |meta| meta.fee else null,
        .log_messages_count = if (parsed.meta) |meta|
            if (meta.logMessages) |logs| logs.len else null
        else
            null,
        .has_error = error_json != null,
        .error_json = error_json,
    };
}

fn summarizeParsedAccountInfo(source: json.Value) ?ParsedAccountInfoSummary {
    if (source != .object) return null;

    var summary: ParsedAccountInfoSummary = .{};

    if (source.object.get("authority")) |value| {
        if (value == .string) summary.authority = value.string;
    }
    if (source.object.get("blockhash")) |value| {
        if (value == .string) summary.blockhash = value.string;
    }
    if (source.object.get("lamportsPerSignature")) |value| {
        switch (value) {
            .integer => |integer| summary.lamportsPerSignature = std.math.cast(u64, integer),
            .number_string => |number| summary.lamportsPerSignature = std.fmt.parseInt(u64, number, 10) catch null,
            else => {},
        }
    }
    if (source.object.get("mint")) |value| {
        if (value == .string) summary.mint = value.string;
    }
    if (source.object.get("owner")) |value| {
        if (value == .string) summary.owner = value.string;
    }
    if (source.object.get("state")) |value| {
        if (value == .string) summary.state = value.string;
    }
    if (source.object.get("tokenAmount")) |value| {
        if (value == .object) {
            if (value.object.get("amount")) |amount_value| {
                if (amount_value == .string) summary.tokenAmountAmount = amount_value.string;
            }
            if (value.object.get("decimals")) |decimals_value| {
                switch (decimals_value) {
                    .integer => |integer| summary.tokenAmountDecimals = std.math.cast(u8, integer),
                    .number_string => |number| summary.tokenAmountDecimals = std.fmt.parseInt(u8, number, 10) catch null,
                    else => {},
                }
            }
            if (value.object.get("uiAmountString")) |ui_amount_string_value| {
                if (ui_amount_string_value == .string) summary.tokenAmountUiAmountString = ui_amount_string_value.string;
            }
        }
    }

    if (summary.authority == null and
        summary.blockhash == null and
        summary.lamportsPerSignature == null and
        summary.mint == null and
        summary.owner == null and
        summary.state == null and
        summary.tokenAmountAmount == null and
        summary.tokenAmountDecimals == null and
        summary.tokenAmountUiAmountString == null)
    {
        return null;
    }

    return summary;
}

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
