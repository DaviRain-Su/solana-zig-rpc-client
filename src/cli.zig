const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Commitment = enum {
    processed,
    confirmed,
    finalized,
};

pub const usage_text =
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
    "  solana_client_zig [--rpc <url>] account-info <account>\n" ++
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
    "  solana_client_zig [--rpc <url>] block <slot>\n" ++
    "  solana_client_zig [--rpc <url>] blocks-with-limit <start-slot> <limit>\n" ++
    "  solana_client_zig [--rpc <url>] signatures-for-address <address> [--before <signature>] [--until <signature>] [--limit <count>]\n" ++
    "  solana_client_zig [--rpc <url>] feature-activation-slot <feature-pubkey>\n" ++
    "  solana_client_zig [--rpc <url>] stake-minimum-delegation\n" ++
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
    "  --before <signature>     Filter signatures after this older signature (signatures-for-address)\n" ++
    "  --until <signature>      Stop at this oldest signature (signatures-for-address)\n" ++
    "  --limit <count>          Maximum results to return (signatures-for-address)\n" ++
    "  --skip-preflight         Skip tx preflight checks (send commands)\n" ++
    "  --max-retries <count>    Max tx retries before giving up\n" ++
    "  --preflight-commitment <level>  Commitment for tx preflight checks\n";

pub fn printUsage(out: *std.Io.Writer) !void {
    try out.print("{s}", .{usage_text});
}

pub fn parseCommitment(value: []const u8) ?Commitment {
    if (std.mem.eql(u8, value, "processed")) return .processed;
    if (std.mem.eql(u8, value, "confirmed")) return .confirmed;
    if (std.mem.eql(u8, value, "finalized")) return .finalized;
    return null;
}

pub const ParsedArgs = struct {
    command: Command,
    has_command: bool,
    show_usage: bool,
    rpc_url: []const u8,
    signature: ?[]const u8,
    account: ?[]const u8,
    blockhash_arg: ?[]const u8,
    feature_key_arg: ?[]const u8,
    signatures_for_address_arg: ?[]const u8,
    signatures_for_address_before_arg: ?[]const u8,
    signatures_for_address_until_arg: ?[]const u8,
    signatures_for_address_limit_arg: ?[]const u8,
    slot_arg: ?[]const u8,
    blocks_end_slot_arg: ?[]const u8,
    blocks_limit_arg: ?[]const u8,
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
        .has_command = false,
        .show_usage = false,
        .rpc_url = "https://api.mainnet-beta.solana.com",
        .signature = null,
        .account = null,
        .blockhash_arg = null,
        .feature_key_arg = null,
        .signatures_for_address_arg = null,
        .signatures_for_address_before_arg = null,
        .signatures_for_address_until_arg = null,
        .signatures_for_address_limit_arg = null,
        .slot_arg = null,
        .blocks_end_slot_arg = null,
        .blocks_limit_arg = null,
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

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            parsed.show_usage = true;
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

        if (std.mem.eql(u8, arg, "--before")) {
            if (index >= args.len or parsed.signatures_for_address_before_arg != null) return error.InvalidCli;
            parsed.signatures_for_address_before_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--until")) {
            if (index >= args.len or parsed.signatures_for_address_until_arg != null) return error.InvalidCli;
            parsed.signatures_for_address_until_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--limit")) {
            if (index >= args.len or parsed.signatures_for_address_limit_arg != null) return error.InvalidCli;
            parsed.signatures_for_address_limit_arg = args[index];
            index += 1;
            continue;
        }

        if (!parsed.has_command) {
            if (std.mem.eql(u8, arg, "latest-blockhash")) {
                parsed.command = .latest_blockhash;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "status")) {
                parsed.command = .status;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "signature-status")) {
                parsed.command = .signature_status;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "signature-statuses")) {
                parsed.command = .signature_statuses;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "send-transaction")) {
                parsed.command = .send_transaction;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "send-transaction-and-confirm")) {
                parsed.command = .send_transaction_and_confirm;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "slot")) {
                parsed.command = .slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "block-height")) {
                parsed.command = .block_height;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "transaction-count")) {
                parsed.command = .transaction_count;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "balance")) {
                parsed.command = .balance;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "request-airdrop")) {
                parsed.command = .request_airdrop;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "account-info")) {
                parsed.command = .account_info;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "minimum-rent-exemption")) {
                parsed.command = .minimum_rent_exemption;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "version")) {
                parsed.command = .version;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "epoch-info")) {
                parsed.command = .epoch_info;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "health")) {
                parsed.command = .health;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "genesis-hash")) {
                parsed.command = .genesis_hash;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "supply")) {
                parsed.command = .supply;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "epoch-schedule")) {
                parsed.command = .epoch_schedule;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "inflation-rate")) {
                parsed.command = .inflation_rate;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "block-time")) {
                parsed.command = .block_time;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "block")) {
                parsed.command = .block;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "fee-for-message")) {
                parsed.command = .fee_for_message;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "recent-performance-samples")) {
                parsed.command = .recent_performance_samples;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "blocks")) {
                parsed.command = .blocks;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "blocks-with-limit")) {
                parsed.command = .blocks_with_limit;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "slot-leaders")) {
                parsed.command = .slot_leaders;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "recent-prioritization-fees")) {
                parsed.command = .recent_prioritization_fees;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "cluster-nodes")) {
                parsed.command = .cluster_nodes;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "leader-schedule")) {
                parsed.command = .leader_schedule;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "identity")) {
                parsed.command = .identity;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "vote-accounts")) {
                parsed.command = .vote_accounts;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "block-production")) {
                parsed.command = .block_production;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "inflation-governor")) {
                parsed.command = .inflation_governor;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "minimum-ledger-slot")) {
                parsed.command = .minimum_ledger_slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "max-retransmit-slot")) {
                parsed.command = .max_retransmit_slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "max-shred-insert-slot")) {
                parsed.command = .max_shred_insert_slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "highest-snapshot-slot")) {
                parsed.command = .highest_snapshot_slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "first-available-block")) {
                parsed.command = .first_available_block;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "blockhash-valid")) {
                parsed.command = .blockhash_valid;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "feature-activation-slot")) {
                parsed.command = .feature_activation_slot;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "signatures-for-address")) {
                parsed.command = .signatures_for_address;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "stake-minimum-delegation")) {
                parsed.command = .stake_minimum_delegation;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "help")) {
                parsed.show_usage = true;
                parsed.has_command = true;
                continue;
            }
        }

        switch (parsed.command) {
            .latest_blockhash, .slot, .block_height, .transaction_count, .version, .epoch_info, .health, .genesis_hash, .supply, .epoch_schedule, .inflation_rate, .highest_snapshot_slot, .first_available_block, .recent_prioritization_fees, .identity, .cluster_nodes, .vote_accounts, .block_production, .inflation_governor, .minimum_ledger_slot, .max_retransmit_slot, .max_shred_insert_slot => return error.InvalidCli,

            .stake_minimum_delegation => return error.InvalidCli,

            .signatures_for_address => if (parsed.signatures_for_address_arg == null) {
                parsed.signatures_for_address_arg = arg;
            } else {
                return error.InvalidCli;
            },

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

            .account_info => if (parsed.account == null) {
                parsed.account = arg;
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

            .feature_activation_slot => if (parsed.feature_key_arg == null) {
                parsed.feature_key_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .block_time => if (parsed.slot_arg == null) {
                parsed.slot_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .block => if (parsed.slot_arg == null) {
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

            .blocks_with_limit => if (parsed.slot_arg == null) {
                parsed.slot_arg = arg;
            } else if (parsed.blocks_limit_arg == null) {
                parsed.blocks_limit_arg = arg;
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
    account_info,
    signatures_for_address,
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
    feature_activation_slot,
    blockhash_valid,
    version,
    stake_minimum_delegation,
    epoch_info,
    health,
    genesis_hash,
    supply,
    epoch_schedule,
    inflation_rate,
    block,
    block_time,
    blocks,
    blocks_with_limit,
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
    try std.testing.expect(std.mem.indexOf(u8, usage, "blocks-with-limit <start-slot> <limit>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "vote-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-production") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-status") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "feature-activation-slot <feature-pubkey>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signatures-for-address <address>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "stake-minimum-delegation") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "account-info <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction-and-confirm <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--skip-preflight") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--max-retries <count>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--preflight-commitment") != null);
}

test "cli.parseCliArgs leaves command unset for empty args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{});
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(!parsed.has_command);
    try std.testing.expect(!parsed.show_usage);
}

test "cli.parseCliArgs enables usage for help flag" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{"--help"});
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.show_usage);
    try std.testing.expect(!parsed.has_command);
}

test "cli.parseCliArgs does not reinterpret positional args as commands" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "account-info",
        "slot",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.account_info, parsed.command);
    try std.testing.expectEqualStrings("slot", parsed.account orelse "");
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

test "cli.parseCliArgs parses blocks-with-limit" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks-with-limit",
        "123",
        "25",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks_with_limit, parsed.command);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
    try std.testing.expectEqualStrings("25", parsed.blocks_limit_arg orelse "");
}

test "cli.parseCliArgs parses blocks-with-limit with commitment" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks-with-limit",
        "--commitment",
        "finalized",
        "123",
        "25",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks_with_limit, parsed.command);
    try std.testing.expectEqual(Commitment.finalized, parsed.commitment orelse .processed);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
    try std.testing.expectEqualStrings("25", parsed.blocks_limit_arg orelse "");
}

test "cli.parseCliArgs parses block" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "block",
        "123",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block, parsed.command);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
}

test "cli.parseCliArgs parses block with commitment" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "block",
        "123",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block, parsed.command);
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
}

test "cli.parseCliArgs parses block with commitment before command" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "--commitment",
        "confirmed",
        "block",
        "123",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block, parsed.command);
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
}

test "cli.parseCliArgs rejects block extra positional arg" {
    try std.testing.expectError(error.InvalidCli, parseCliArgs(std.testing.allocator, &.{
        "block",
        "123",
        "extra",
    }));
}

test "cli.parseCliArgs parses blocks" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks",
        "100",
        "200",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks, parsed.command);
    try std.testing.expectEqualStrings("100", parsed.slot_arg orelse "");
    try std.testing.expectEqualStrings("200", parsed.blocks_end_slot_arg orelse "");
}

test "cli.parseCliArgs parses blocks with commitment" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks",
        "100",
        "200",
        "--commitment",
        "finalized",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks, parsed.command);
    try std.testing.expectEqualStrings("100", parsed.slot_arg orelse "");
    try std.testing.expectEqualStrings("200", parsed.blocks_end_slot_arg orelse "");
    try std.testing.expectEqual(Commitment.finalized, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses blocks without end slot" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks",
        "100",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks, parsed.command);
    try std.testing.expectEqualStrings("100", parsed.slot_arg orelse "");
    try std.testing.expect(parsed.blocks_end_slot_arg == null);
}

test "cli.parseCliArgs rejects blocks-with-limit extra arg" {
    try std.testing.expectError(error.InvalidCli, parseCliArgs(std.testing.allocator, &.{
        "blocks-with-limit",
        "123",
        "25",
        "extra",
    }));
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

test "cli.parseCliArgs parses feature activation slot" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "feature-activation-slot",
        "Feature11111111111111111111111111111111111111111",
        "--commitment",
        "finalized",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.feature_activation_slot, parsed.command);
    try std.testing.expectEqualStrings("Feature11111111111111111111111111111111111111111", parsed.feature_key_arg orelse "");
    try std.testing.expectEqual(Commitment.finalized, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses account info" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "account-info",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.account_info, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses signatures for address" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "signatures-for-address",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.signatures_for_address, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.signatures_for_address_arg orelse "");
}

test "cli.parseCliArgs parses signatures-for-address filters" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "signatures-for-address",
        "--before",
        "BeforeSig",
        "--until",
        "UntilSig",
        "--limit",
        "50",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.signatures_for_address, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.signatures_for_address_arg orelse "");
    try std.testing.expectEqualStrings("BeforeSig", parsed.signatures_for_address_before_arg orelse "");
    try std.testing.expectEqualStrings("UntilSig", parsed.signatures_for_address_until_arg orelse "");
    try std.testing.expectEqualStrings("50", parsed.signatures_for_address_limit_arg orelse "");
}

test "cli.parseCliArgs rejects duplicate signatures-for-address before" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{
            "signatures-for-address",
            "Address11111111111111111111111111111111",
            "--before",
            "BeforeSig",
            "--before",
            "AnotherSig",
        }),
    );
}

test "cli.parseCliArgs rejects duplicate signatures-for-address until" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{
            "signatures-for-address",
            "Address11111111111111111111111111111111",
            "--until",
            "UntilSig",
            "--until",
            "AnotherSig",
        }),
    );
}

test "cli.parseCliArgs rejects duplicate signatures-for-address limit" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{
            "signatures-for-address",
            "--limit",
            "10",
            "--limit",
            "20",
            "Address11111111111111111111111111111111",
        }),
    );
}

test "cli.parseCliArgs parses stake minimum delegation" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "stake-minimum-delegation",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.stake_minimum_delegation, parsed.command);
}

test "cli.parseCliArgs errors on extra feature activation arg" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{
            "feature-activation-slot",
            "Feature11111111111111111111111111111111111111111",
            "unexpected",
        }),
    );
}

test "cli.parseCliArgs errors on unknown positional argument" {
    try std.testing.expectError(
        error.InvalidCli,
        parseCliArgs(std.testing.allocator, &.{ "block-height", "unexpected" }),
    );
}
