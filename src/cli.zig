const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Commitment = enum {
    processed,
    confirmed,
    finalized,
};

pub fn printUsage(out: *std.Io.Writer) !void {
    try out.print(
        "Usage:\n" ++
            "  solana_client_zig [--rpc <url>] latest-blockhash\n" ++
            "  solana_client_zig [--rpc <url>] status <signature>\n" ++
            "  solana_client_zig [--rpc <url>] signature-status <signature>\n" ++
            "  solana_client_zig [--rpc <url>] signature-statuses <signature-1> [signature-2 ...]\n" ++
            "  solana_client_zig [--rpc <url>] send-transaction <signed-tx-base64>\n" ++
            "  solana_client_zig [--rpc <url>] send-transaction-and-confirm <signed-tx-base64>\n" ++
            "  solana_client_zig [--rpc <url>] slot\n" ++
            "  solana_client_zig [--rpc <url>] block-height\n" ++
            "  solana_client_zig [--rpc <url>] transaction-count\n" ++
            "  solana_client_zig [--rpc <url>] balance <account>\n" ++
            "  solana_client_zig [--rpc <url>] request-airdrop <account> <lamports>\n" ++
            "  solana_client_zig [--rpc <url>] minimum-rent-exemption <bytes>\n" ++
            "  solana_client_zig [--rpc <url>] version\n" ++
            "  solana_client_zig [--rpc <url>] epoch-info\n" ++
            "  solana_client_zig [--rpc <url>] health\n" ++
            "  solana_client_zig [--rpc <url>] genesis-hash\n" ++
            "  solana_client_zig [--rpc <url>] supply\n" ++
            "  solana_client_zig [--rpc <url>] epoch-schedule\n" ++
            "  solana_client_zig [--rpc <url>] inflation-rate\n" ++
            "  solana_client_zig [--rpc <url>] block-time <slot>\n" ++
            "  solana_client_zig [--rpc <url>] fee-for-message <base64-message>\n" ++
            "  solana_client_zig [--rpc <url>] recent-performance-samples [limit]\n" ++
            "  solana_client_zig [--rpc <url>] highest-snapshot-slot\n" ++
            "  solana_client_zig [--rpc <url>] blocks <start-slot> [end-slot]\n" ++
            "  solana_client_zig [--rpc <url>] slot-leaders <start-slot> <limit>\n" ++
            "  solana_client_zig [--rpc <url>] recent-prioritization-fees\n" ++
            "  solana_client_zig [--rpc <url>] cluster-nodes\n" ++
            "  solana_client_zig [--rpc <url>] leader-schedule [slot] [identity]\n" ++
            "  solana_client_zig [--rpc <url>] identity\n" ++
            "  solana_client_zig [--rpc <url>] vote-accounts\n" ++
            "  solana_client_zig [--rpc <url>] block-production\n" ++
            "  solana_client_zig [--rpc <url>] inflation-governor\n" ++
            "  solana_client_zig [--rpc <url>] minimum-ledger-slot\n" ++
            "  solana_client_zig [--rpc <url>] max-retransmit-slot\n" ++
            "  solana_client_zig [--rpc <url>] max-shred-insert-slot\n" ++
            "  solana_client_zig [--rpc <url>] first-available-block\n" ++
            "  solana_client_zig [--rpc <url>] blockhash-valid <blockhash>\n" ++
            "\n" ++
            "Optional flags:\n" ++
            "  --rpc <url>             RPC endpoint to use\n" ++
            "  --commitment <level>     processed|confirmed|finalized\n" ++
            "  --timeout-ms <ms>        Signature wait timeout (status and send-transaction-and-confirm)\n" ++
            "  --poll-ms <ms>           Poll interval in ms (status and send-transaction-and-confirm)\n" ++
            "  --skip-preflight         Skip tx preflight checks (send commands)\n" ++
            "  --max-retries <count>    Max tx retries before giving up\n" ++
            "  --preflight-commitment <level>  Commitment for tx preflight checks\n",
        .{},
    );
}

pub fn parseCommitment(value: []const u8) ?Commitment {
    if (std.mem.eql(u8, value, "processed")) return .processed;
    if (std.mem.eql(u8, value, "confirmed")) return .confirmed;
    if (std.mem.eql(u8, value, "finalized")) return .finalized;
    return null;
}

pub const ParsedArgs = struct {
    command: Command,
    rpc_url: []const u8,
    signature: ?[]const u8,
    account: ?[]const u8,
    blockhash_arg: ?[]const u8,
    slot_arg: ?[]const u8,
    blocks_end_slot_arg: ?[]const u8,
    message_arg: ?[]const u8,
    slot_leaders_limit_arg: ?[]const u8,
    performance_limit_arg: ?[]const u8,
    leader_schedule_slot_arg: ?[]const u8,
    leader_schedule_identity_arg: ?[]const u8,
    lamports_arg: ?[]const u8,
    rent_bytes_arg: ?[]const u8,
    signed_tx_arg: ?[]const u8,
    signature_statuses: std.ArrayListUnmanaged([]const u8),
    commitment: ?Commitment,
    status_timeout_ms: u64,
    status_poll_ms: u64,
    send_skip_preflight: bool,
    send_max_retries: ?u32,
    send_preflight_commitment: ?Commitment,

    pub fn deinit(self: *ParsedArgs, allocator: Allocator) void {
        self.signature_statuses.deinit(allocator);
    }
};

pub fn parseCliArgs(allocator: Allocator, args: []const []const u8) !ParsedArgs {
    var parsed = ParsedArgs{
        .command = .latest_blockhash,
        .rpc_url = "https://api.mainnet-beta.solana.com",
        .signature = null,
        .account = null,
        .blockhash_arg = null,
        .slot_arg = null,
        .blocks_end_slot_arg = null,
        .message_arg = null,
        .slot_leaders_limit_arg = null,
        .performance_limit_arg = null,
        .leader_schedule_slot_arg = null,
        .leader_schedule_identity_arg = null,
        .lamports_arg = null,
        .rent_bytes_arg = null,
        .signed_tx_arg = null,
        .signature_statuses = .{},
        .commitment = null,
        .status_timeout_ms = 30_000,
        .status_poll_ms = 500,
        .send_skip_preflight = false,
        .send_max_retries = null,
        .send_preflight_commitment = null,
    };

    var index: usize = 0;
    while (index < args.len) {
        const arg = args[index];
        index += 1;

        if (std.mem.eql(u8, arg, "--rpc")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.rpc_url = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--commitment")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.commitment = parseCommitment(args[index]) orelse return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--timeout-ms")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.status_timeout_ms = std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--poll-ms")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.status_poll_ms = std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--skip-preflight")) {
            parsed.send_skip_preflight = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--max-retries")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.send_max_retries = std.fmt.parseInt(u32, args[index], 10) catch return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--preflight-commitment")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.send_preflight_commitment = parseCommitment(args[index]) orelse return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "latest-blockhash")) {
            parsed.command = .latest_blockhash;
            continue;
        }

        if (std.mem.eql(u8, arg, "status")) {
            parsed.command = .status;
            continue;
        }

        if (std.mem.eql(u8, arg, "signature-status")) {
            parsed.command = .signature_status;
            continue;
        }

        if (std.mem.eql(u8, arg, "signature-statuses")) {
            parsed.command = .signature_statuses;
            continue;
        }

        if (std.mem.eql(u8, arg, "send-transaction")) {
            parsed.command = .send_transaction;
            continue;
        }

        if (std.mem.eql(u8, arg, "send-transaction-and-confirm")) {
            parsed.command = .send_transaction_and_confirm;
            continue;
        }

        if (std.mem.eql(u8, arg, "slot")) {
            parsed.command = .slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-height")) {
            parsed.command = .block_height;
            continue;
        }

        if (std.mem.eql(u8, arg, "transaction-count")) {
            parsed.command = .transaction_count;
            continue;
        }

        if (std.mem.eql(u8, arg, "balance")) {
            parsed.command = .balance;
            continue;
        }

        if (std.mem.eql(u8, arg, "request-airdrop")) {
            parsed.command = .request_airdrop;
            continue;
        }

        if (std.mem.eql(u8, arg, "minimum-rent-exemption")) {
            parsed.command = .minimum_rent_exemption;
            continue;
        }

        if (std.mem.eql(u8, arg, "version")) {
            parsed.command = .version;
            continue;
        }

        if (std.mem.eql(u8, arg, "epoch-info")) {
            parsed.command = .epoch_info;
            continue;
        }

        if (std.mem.eql(u8, arg, "health")) {
            parsed.command = .health;
            continue;
        }

        if (std.mem.eql(u8, arg, "genesis-hash")) {
            parsed.command = .genesis_hash;
            continue;
        }

        if (std.mem.eql(u8, arg, "supply")) {
            parsed.command = .supply;
            continue;
        }

        if (std.mem.eql(u8, arg, "epoch-schedule")) {
            parsed.command = .epoch_schedule;
            continue;
        }

        if (std.mem.eql(u8, arg, "inflation-rate")) {
            parsed.command = .inflation_rate;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-time")) {
            parsed.command = .block_time;
            continue;
        }

        if (std.mem.eql(u8, arg, "fee-for-message")) {
            parsed.command = .fee_for_message;
            continue;
        }

        if (std.mem.eql(u8, arg, "recent-performance-samples")) {
            parsed.command = .recent_performance_samples;
            continue;
        }

        if (std.mem.eql(u8, arg, "blocks")) {
            parsed.command = .blocks;
            continue;
        }

        if (std.mem.eql(u8, arg, "slot-leaders")) {
            parsed.command = .slot_leaders;
            continue;
        }

        if (std.mem.eql(u8, arg, "recent-prioritization-fees")) {
            parsed.command = .recent_prioritization_fees;
            continue;
        }

        if (std.mem.eql(u8, arg, "cluster-nodes")) {
            parsed.command = .cluster_nodes;
            continue;
        }

        if (std.mem.eql(u8, arg, "leader-schedule")) {
            parsed.command = .leader_schedule;
            continue;
        }

        if (std.mem.eql(u8, arg, "identity")) {
            parsed.command = .identity;
            continue;
        }

        if (std.mem.eql(u8, arg, "vote-accounts")) {
            parsed.command = .vote_accounts;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-production")) {
            parsed.command = .block_production;
            continue;
        }

        if (std.mem.eql(u8, arg, "inflation-governor")) {
            parsed.command = .inflation_governor;
            continue;
        }

        if (std.mem.eql(u8, arg, "minimum-ledger-slot")) {
            parsed.command = .minimum_ledger_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "max-retransmit-slot")) {
            parsed.command = .max_retransmit_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "max-shred-insert-slot")) {
            parsed.command = .max_shred_insert_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "highest-snapshot-slot")) {
            parsed.command = .highest_snapshot_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "first-available-block")) {
            parsed.command = .first_available_block;
            continue;
        }

        if (std.mem.eql(u8, arg, "blockhash-valid")) {
            parsed.command = .blockhash_valid;
            continue;
        }

        switch (parsed.command) {
            .latest_blockhash, .slot, .block_height, .transaction_count, .version, .epoch_info, .health, .genesis_hash, .supply, .epoch_schedule, .inflation_rate, .highest_snapshot_slot, .first_available_block, .recent_prioritization_fees, .identity, .cluster_nodes, .vote_accounts, .block_production, .inflation_governor, .minimum_ledger_slot, .max_retransmit_slot, .max_shred_insert_slot => return error.InvalidCli,

            .status, .signature_status => if (parsed.signature == null) {
                parsed.signature = arg;
            } else {
                return error.InvalidCli;
            },

            .signature_statuses => {
                parsed.signature_statuses.append(allocator, arg) catch return error.InvalidCli;
            },

            .send_transaction, .send_transaction_and_confirm => if (parsed.signed_tx_arg == null) {
                parsed.signed_tx_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .balance => if (parsed.account == null) {
                parsed.account = arg;
            } else {
                return error.InvalidCli;
            },

            .request_airdrop => if (parsed.account == null) {
                parsed.account = arg;
            } else if (parsed.lamports_arg == null) {
                parsed.lamports_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .minimum_rent_exemption => if (parsed.rent_bytes_arg == null) {
                parsed.rent_bytes_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .blockhash_valid => if (parsed.blockhash_arg == null) {
                parsed.blockhash_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .block_time => if (parsed.slot_arg == null) {
                parsed.slot_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .fee_for_message => if (parsed.message_arg == null) {
                parsed.message_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .recent_performance_samples => if (parsed.performance_limit_arg == null) {
                parsed.performance_limit_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .blocks => if (parsed.slot_arg == null) {
                parsed.slot_arg = arg;
            } else if (parsed.blocks_end_slot_arg == null) {
                parsed.blocks_end_slot_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .slot_leaders => if (parsed.slot_arg == null) {
                parsed.slot_arg = arg;
            } else if (parsed.slot_leaders_limit_arg == null) {
                parsed.slot_leaders_limit_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .leader_schedule => if (parsed.leader_schedule_slot_arg == null) {
                parsed.leader_schedule_slot_arg = arg;
            } else if (parsed.leader_schedule_identity_arg == null) {
                parsed.leader_schedule_identity_arg = arg;
            } else {
                return error.InvalidCli;
            },
        }
    }

    return parsed;
}

pub const Command = enum {
    latest_blockhash,
    status,
    signature_status,
    signature_statuses,
    send_transaction,
    send_transaction_and_confirm,
    slot,
    block_height,
    transaction_count,
    balance,
    request_airdrop,
    minimum_rent_exemption,
    blockhash_valid,
    version,
    epoch_info,
    health,
    genesis_hash,
    supply,
    epoch_schedule,
    inflation_rate,
    block_time,
    blocks,
    slot_leaders,
    recent_prioritization_fees,
    cluster_nodes,
    identity,
    leader_schedule,
    vote_accounts,
    block_production,
    inflation_governor,
    minimum_ledger_slot,
    max_retransmit_slot,
    max_shred_insert_slot,
    fee_for_message,
    recent_performance_samples,
    highest_snapshot_slot,
    first_available_block,
};

test "cli.printUsage text compiles" {
    var out = std.io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();
    try printUsage(&out.writer);
    try std.testing.expect(out.written().len > 0);
}

test "cli.printUsage includes new commands" {
    var out = std.io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();
    try printUsage(&out.writer);

    const usage = out.written();
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-status <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-statuses <signature-1> [signature-2 ...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "cluster-nodes") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "leader-schedule [slot] [identity]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "vote-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-production") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-status") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction-and-confirm <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--skip-preflight") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--max-retries <count>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--preflight-commitment") != null);
}

test "cli.parseCliArgs parses send-transaction with preflight options" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-transaction",
        "--skip-preflight",
        "--max-retries",
        "3",
        "--preflight-commitment",
        "confirmed",
        "signed-raw-transaction",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_transaction, parsed.command);
    try std.testing.expectEqualStrings("signed-raw-transaction", parsed.signed_tx_arg orelse "");
    try std.testing.expectEqual(true, parsed.send_skip_preflight);
    try std.testing.expectEqual(@as(u32, 3), parsed.send_max_retries orelse 0);
    try std.testing.expectEqual(Commitment.confirmed, parsed.send_preflight_commitment orelse .processed);
}

test "cli.parseCliArgs parses status timeout flags" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "status",
        "signature-value",
        "--timeout-ms",
        "10000",
        "--poll-ms",
        "100",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.status, parsed.command);
    try std.testing.expectEqualStrings("signature-value", parsed.signature orelse "");
    try std.testing.expectEqual(@as(u64, 10000), parsed.status_timeout_ms);
    try std.testing.expectEqual(@as(u64, 100), parsed.status_poll_ms);
}

test "cli.parseCliArgs collects multiple signatures" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "signature-statuses",
        "sig-1",
        "sig-2",
        "sig-3",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.signature_statuses, parsed.command);
    try std.testing.expectEqual(@as(usize, 3), parsed.signature_statuses.items.len);
    try std.testing.expectEqualStrings("sig-2", parsed.signature_statuses.items[1]);
}

test "cli.parseCliArgs errors on unknown positional argument" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{ "block-height", "unexpected" }),
    );
}
