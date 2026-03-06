const std = @import("std");
const client = @import("solana_client_zig");

fn printUsage(out: *std.Io.Writer) !void {
    try out.print(
        "Usage:\n" ++
            "  solana_client_zig [--rpc <url>] latest-blockhash\n" ++
            "  solana_client_zig [--rpc <url>] status <signature>\n" ++
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
            "  --timeout-ms <ms>        Signature wait timeout (status command only)\n" ++
            "  --poll-ms <ms>           Poll interval in ms (status command only)\n",
        .{},
    );
}

fn parseCommitment(value: []const u8) ?client.Commitment {
    if (std.mem.eql(u8, value, "processed")) return .processed;
    if (std.mem.eql(u8, value, "confirmed")) return .confirmed;
    if (std.mem.eql(u8, value, "finalized")) return .finalized;
    return null;
}

const Command = enum {
    latest_blockhash,
    status,
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.next();

    var rpc_url: []const u8 = "https://api.mainnet-beta.solana.com";
    var command: Command = .latest_blockhash;
    var signature: ?[]const u8 = null;
    var account: ?[]const u8 = null;
    var blockhash_arg: ?[]const u8 = null;
    var slot_arg: ?[]const u8 = null;
    var blocks_end_slot_arg: ?[]const u8 = null;
    var message_arg: ?[]const u8 = null;
    var slot_leaders_limit_arg: ?[]const u8 = null;
    var performance_limit_arg: ?[]const u8 = null;
    var leader_schedule_slot_arg: ?[]const u8 = null;
    var leader_schedule_identity_arg: ?[]const u8 = null;
    var lamports_arg: ?[]const u8 = null;
    var rent_bytes_arg: ?[]const u8 = null;
    var commitment: ?client.Commitment = null;
    var status_timeout_ms: u64 = 30_000;
    var status_poll_ms: u64 = 500;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--rpc")) {
            rpc_url = args.next() orelse return error.InvalidCli;
            continue;
        }

        if (std.mem.eql(u8, arg, "--commitment")) {
            const value = args.next() orelse return error.InvalidCli;
            commitment = parseCommitment(value) orelse return error.InvalidCli;
            continue;
        }

        if (std.mem.eql(u8, arg, "--timeout-ms")) {
            const value = args.next() orelse return error.InvalidCli;
            status_timeout_ms = std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli;
            continue;
        }

        if (std.mem.eql(u8, arg, "--poll-ms")) {
            const value = args.next() orelse return error.InvalidCli;
            status_poll_ms = std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli;
            continue;
        }

        if (std.mem.eql(u8, arg, "latest-blockhash")) {
            command = .latest_blockhash;
            continue;
        }

        if (std.mem.eql(u8, arg, "status")) {
            command = .status;
            continue;
        }

        if (std.mem.eql(u8, arg, "slot")) {
            command = .slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-height")) {
            command = .block_height;
            continue;
        }

        if (std.mem.eql(u8, arg, "transaction-count")) {
            command = .transaction_count;
            continue;
        }

        if (std.mem.eql(u8, arg, "balance")) {
            command = .balance;
            continue;
        }

        if (std.mem.eql(u8, arg, "request-airdrop")) {
            command = .request_airdrop;
            continue;
        }

        if (std.mem.eql(u8, arg, "minimum-rent-exemption")) {
            command = .minimum_rent_exemption;
            continue;
        }

        if (std.mem.eql(u8, arg, "version")) {
            command = .version;
            continue;
        }

        if (std.mem.eql(u8, arg, "epoch-info")) {
            command = .epoch_info;
            continue;
        }

        if (std.mem.eql(u8, arg, "health")) {
            command = .health;
            continue;
        }

        if (std.mem.eql(u8, arg, "genesis-hash")) {
            command = .genesis_hash;
            continue;
        }

        if (std.mem.eql(u8, arg, "supply")) {
            command = .supply;
            continue;
        }

        if (std.mem.eql(u8, arg, "epoch-schedule")) {
            command = .epoch_schedule;
            continue;
        }

        if (std.mem.eql(u8, arg, "inflation-rate")) {
            command = .inflation_rate;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-time")) {
            command = .block_time;
            continue;
        }

        if (std.mem.eql(u8, arg, "fee-for-message")) {
            command = .fee_for_message;
            continue;
        }

        if (std.mem.eql(u8, arg, "recent-performance-samples")) {
            command = .recent_performance_samples;
            continue;
        }

        if (std.mem.eql(u8, arg, "blocks")) {
            command = .blocks;
            continue;
        }

        if (std.mem.eql(u8, arg, "slot-leaders")) {
            command = .slot_leaders;
            continue;
        }

        if (std.mem.eql(u8, arg, "recent-prioritization-fees")) {
            command = .recent_prioritization_fees;
            continue;
        }

        if (std.mem.eql(u8, arg, "cluster-nodes")) {
            command = .cluster_nodes;
            continue;
        }

        if (std.mem.eql(u8, arg, "leader-schedule")) {
            command = .leader_schedule;
            continue;
        }

        if (std.mem.eql(u8, arg, "identity")) {
            command = .identity;
            continue;
        }

        if (std.mem.eql(u8, arg, "vote-accounts")) {
            command = .vote_accounts;
            continue;
        }

        if (std.mem.eql(u8, arg, "block-production")) {
            command = .block_production;
            continue;
        }

        if (std.mem.eql(u8, arg, "inflation-governor")) {
            command = .inflation_governor;
            continue;
        }

        if (std.mem.eql(u8, arg, "minimum-ledger-slot")) {
            command = .minimum_ledger_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "max-retransmit-slot")) {
            command = .max_retransmit_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "max-shred-insert-slot")) {
            command = .max_shred_insert_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "highest-snapshot-slot")) {
            command = .highest_snapshot_slot;
            continue;
        }

        if (std.mem.eql(u8, arg, "first-available-block")) {
            command = .first_available_block;
            continue;
        }

        if (std.mem.eql(u8, arg, "blockhash-valid")) {
            command = .blockhash_valid;
            continue;
        }

        switch (command) {
            .latest_blockhash, .slot, .block_height, .transaction_count, .version, .epoch_info, .health, .genesis_hash, .supply, .epoch_schedule, .inflation_rate, .highest_snapshot_slot, .first_available_block, .recent_prioritization_fees, .identity, .leader_schedule, .cluster_nodes, .vote_accounts, .block_production, .inflation_governor, .minimum_ledger_slot, .max_retransmit_slot, .max_shred_insert_slot => return error.InvalidCli,

            .status => if (signature == null) {
                signature = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .balance => if (account == null) {
                account = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .request_airdrop => if (account == null) {
                account = arg;
                continue;
            } else if (lamports_arg == null) {
                lamports_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .minimum_rent_exemption => if (rent_bytes_arg == null) {
                rent_bytes_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .blockhash_valid => if (blockhash_arg == null) {
                blockhash_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .block_time => if (slot_arg == null) {
                slot_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .fee_for_message => if (message_arg == null) {
                message_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .recent_performance_samples => if (performance_limit_arg == null) {
                performance_limit_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .blocks => if (slot_arg == null) {
                slot_arg = arg;
                continue;
            } else if (blocks_end_slot_arg == null) {
                blocks_end_slot_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .slot_leaders => if (slot_arg == null) {
                slot_arg = arg;
                continue;
            } else if (slot_leaders_limit_arg == null) {
                slot_leaders_limit_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },

            .leader_schedule => if (leader_schedule_slot_arg == null) {
                leader_schedule_slot_arg = arg;
                continue;
            } else if (leader_schedule_identity_arg == null) {
                leader_schedule_identity_arg = arg;
                continue;
            } else {
                return error.InvalidCli;
            },
        }
    }

    var rpc = try client.RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    if (command == .latest_blockhash) {
        const blockhash = try rpc.getLatestBlockhash(commitment);
        defer allocator.free(blockhash.blockhash);
        std.debug.print(
            "Latest blockhash: {s}\nLast valid height: {}\n",
            .{ blockhash.blockhash, blockhash.last_valid_block_height },
        );
        return;
    }

    if (command == .status) {
        const signature_value = signature orelse return error.InvalidCli;
        try rpc.waitForSignatureStatus(signature_value, commitment, status_timeout_ms, status_poll_ms);
        std.debug.print("signature confirmed\n", .{});
        return;
    }

    if (command == .slot) {
        const slot = try rpc.getSlot(commitment);
        std.debug.print("slot: {}\n", .{slot});
        return;
    }

    if (command == .block_height) {
        const height = try rpc.getBlockHeight(commitment);
        std.debug.print("block-height: {}\n", .{height});
        return;
    }

    if (command == .transaction_count) {
        const count = try rpc.getTransactionCount(commitment);
        std.debug.print("transaction-count: {}\n", .{count});
        return;
    }

    if (command == .balance) {
        const account_value = account orelse return error.InvalidCli;
        const balance = try rpc.getBalance(account_value, commitment);
        std.debug.print("balance for {s}: {}\n", .{ account_value, balance });
        return;
    }

    if (command == .request_airdrop) {
        const account_value = account orelse return error.InvalidCli;
        const lamports_txt = lamports_arg orelse return error.InvalidCli;
        const lamports = std.fmt.parseInt(u64, lamports_txt, 10) catch return error.InvalidCli;
        const signature_value = try rpc.requestAirdrop(account_value, lamports, commitment);
        defer allocator.free(signature_value);
        std.debug.print("airdrop signature: {s}\n", .{signature_value});
        return;
    }

    if (command == .minimum_rent_exemption) {
        const rent_bytes_txt = rent_bytes_arg orelse return error.InvalidCli;
        const data_length = std.fmt.parseInt(u64, rent_bytes_txt, 10) catch return error.InvalidCli;
        const lamports = try rpc.minimumBalanceForRentExemption(data_length, commitment);
        std.debug.print("minimum rent exemption: {}\n", .{lamports});
        return;
    }

    if (command == .version) {
        const version = try rpc.getVersion();
        defer allocator.free(version);
        std.debug.print("version: {s}\n", .{version});
        return;
    }

    if (command == .epoch_info) {
        const epoch_info = try rpc.getEpochInfo(commitment);
        std.debug.print(
            "epoch info: epoch={?d} slot_index={?d} slots_in_epoch={?d} block_height={?d} absolute_slot={?d}\n",
            .{
                epoch_info.epoch,
                epoch_info.slot_index,
                epoch_info.slots_in_epoch,
                epoch_info.block_height,
                epoch_info.absolute_slot,
            },
        );
        return;
    }

    if (command == .health) {
        const health = try rpc.getHealth();
        defer allocator.free(health);
        std.debug.print("health: {s}\n", .{health});
        return;
    }

    if (command == .genesis_hash) {
        const genesis_hash = try rpc.getGenesisHash();
        defer allocator.free(genesis_hash);
        std.debug.print("genesis hash: {s}\n", .{genesis_hash});
        return;
    }

    if (command == .first_available_block) {
        const first_block = try rpc.getFirstAvailableBlock(commitment);
        std.debug.print("first available block: {}\n", .{first_block});
        return;
    }

    if (command == .epoch_schedule) {
        const schedule = try rpc.getEpochSchedule();
        std.debug.print(
            "epoch schedule: first_normal_slot={} first_normal_epoch={} leader_schedule_slot_offset={} slots_per_epoch={} warmup={}\n",
            .{
                schedule.first_normal_slot,
                schedule.first_normal_epoch,
                schedule.leader_schedule_slot_offset,
                schedule.slots_per_epoch,
                schedule.warmup,
            },
        );
        return;
    }

    if (command == .inflation_rate) {
        const rate = try rpc.getInflationRate();
        std.debug.print(
            "inflation rate: total={d:.2} validator={d:.2} foundation={d:.2} epoch={}\n",
            .{ rate.total, rate.validator, rate.foundation, rate.epoch },
        );
        return;
    }

    if (command == .block_time) {
        const slot_text = slot_arg orelse return error.InvalidCli;
        const slot = std.fmt.parseInt(u64, slot_text, 10) catch return error.InvalidCli;
        const block_time = try rpc.getBlockTime(slot);
        if (block_time) |value| {
            std.debug.print("block time for slot {}: {}\n", .{ slot, value });
        } else {
            std.debug.print("block time for slot {}: unavailable\n", .{slot});
        }
        return;
    }

    if (command == .blocks) {
        const start_slot_text = slot_arg orelse return error.InvalidCli;
        const start_slot = std.fmt.parseInt(u64, start_slot_text, 10) catch return error.InvalidCli;
        const end_slot = if (blocks_end_slot_arg) |raw| std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli else null;
        const blocks = try rpc.getBlocks(start_slot, end_slot);
        defer allocator.free(blocks);

        if (blocks.len == 0) {
            std.debug.print("no blocks found from slot {}\n", .{start_slot});
            return;
        }

        std.debug.print("blocks from {}: {}\n", .{ start_slot, blocks.len });
        for (blocks, 0..) |slot_value, index| {
            std.debug.print("  [{}] slot={}\n", .{ index, slot_value });
        }
        return;
    }

    if (command == .recent_prioritization_fees) {
        const fees = try rpc.getRecentPrioritizationFees();
        defer allocator.free(fees);

        if (fees.len == 0) {
            std.debug.print("no recent prioritization fees\n", .{});
            return;
        }

        std.debug.print("recent prioritization fees: {}\n", .{fees.len});
        for (fees, 0..) |fee, index| {
            std.debug.print("  [{}] slot={} fee={}\n", .{ index, fee.slot, fee.prioritization_fee });
        }
        return;
    }

    if (command == .cluster_nodes) {
        const nodes = try rpc.getClusterNodes();
        defer {
            for (nodes) |node| {
                allocator.free(node.pubkey);
                if (node.gossip) |value| allocator.free(value);
                if (node.rpc) |value| allocator.free(value);
                if (node.tpu) |value| allocator.free(value);
                if (node.version) |value| allocator.free(value);
            }
            allocator.free(nodes);
        }

        if (nodes.len == 0) {
            std.debug.print("no cluster nodes found\n", .{});
            return;
        }

        std.debug.print("cluster nodes: {}\n", .{nodes.len});
        for (nodes, 0..) |node, index| {
            std.debug.print(
                "  [{}] pubkey={s} feature_set={} shred_version={}\n",
                .{ index, node.pubkey, node.feature_set, node.shred_version },
            );
            if (node.gossip) |value| std.debug.print("      gossip={}\n", .{value});
            if (node.rpc) |value| std.debug.print("      rpc={}\n", .{value});
            if (node.tpu) |value| std.debug.print("      tpu={}\n", .{value});
            if (node.version) |value| std.debug.print("      version={}\n", .{value});
        }
        return;
    }

    if (command == .leader_schedule) {
        var schedule_slot: ?u64 = null;
        var schedule_identity: ?[]const u8 = null;

        if (leader_schedule_slot_arg) |first| {
            schedule_slot = std.fmt.parseInt(u64, first, 10) catch null;
            if (schedule_slot == null) {
                schedule_identity = first;
            } else if (leader_schedule_identity_arg) |identity| {
                schedule_identity = identity;
            }
        }

        if (leader_schedule_slot_arg != null and schedule_slot == null and leader_schedule_identity_arg != null) {
            return error.InvalidCli;
        }

        const schedule = try rpc.getLeaderSchedule(schedule_slot, schedule_identity, commitment);
        defer {
            if (schedule) |leaders| {
                for (leaders) |leader| {
                    allocator.free(leader.identity);
                    allocator.free(leader.slots);
                }
                allocator.free(leaders);
            }
        }

        if (schedule == null) {
            std.debug.print("no leader schedule found\n", .{});
            return;
        }

        const leaders = schedule orelse return;
        if (leaders.len == 0) {
            std.debug.print("no leader schedule entries found\n", .{});
            return;
        }

        std.debug.print("leader schedule entries: {}\n", .{leaders.len});
        for (leaders, 0..) |leader, index| {
            std.debug.print("  [{}] identity={s} slots={}", .{ index, leader.identity, leader.slots.len });
            for (leader.slots, 0..) |slot, slot_index| {
                std.debug.print(" {}", .{slot});
                if (slot_index + 1 == leader.slots.len) {
                    std.debug.print("\n", .{});
                }
            }
        }
        return;
    }

    if (command == .vote_accounts) {
        const accounts = try rpc.getVoteAccounts();
        defer {
            for (accounts.current) |vote_account| {
                allocator.free(vote_account.vote_pubkey);
                allocator.free(vote_account.node_pubkey);
                if (vote_account.epoch_credits) |credits| {
                    allocator.free(credits);
                }
            }
            allocator.free(accounts.current);

            for (accounts.delinquent) |vote_account| {
                allocator.free(vote_account.vote_pubkey);
                allocator.free(vote_account.node_pubkey);
                if (vote_account.epoch_credits) |credits| {
                    allocator.free(credits);
                }
            }
            allocator.free(accounts.delinquent);
        }

        std.debug.print(
            "vote accounts: current={} delinquent={}\n",
            .{ accounts.current.len, accounts.delinquent.len },
        );
        for (accounts.current, 0..) |vote_account, index| {
            std.debug.print(
                "  [{}] current vote={} node={} stake={} commission={} last_vote={} root_slot={}\n",
                .{
                    index,
                    vote_account.vote_pubkey,
                    vote_account.node_pubkey,
                    vote_account.activated_stake,
                    vote_account.commission,
                    if (vote_account.last_vote) |value| value else 0,
                    if (vote_account.root_slot) |value| value else 0,
                },
            );
        }

        for (accounts.delinquent, 0..) |vote_account, index| {
            std.debug.print(
                "  [{}] delinquent vote={} node={} stake={} commission={} last_vote={} root_slot={}\n",
                .{
                    index,
                    vote_account.vote_pubkey,
                    vote_account.node_pubkey,
                    vote_account.activated_stake,
                    vote_account.commission,
                    if (vote_account.last_vote) |value| value else 0,
                    if (vote_account.root_slot) |value| value else 0,
                },
            );
        }
        return;
    }

    if (command == .block_production) {
        const production = try rpc.getBlockProduction(commitment);
        defer {
            for (production.by_identity) |identity| {
                allocator.free(identity.identity);
            }
            allocator.free(production.by_identity);
        }

        std.debug.print(
            "block production: first_slot={} last_slot={} entries={}\n",
            .{ production.first_slot, production.last_slot, production.by_identity.len },
        );
        for (production.by_identity, 0..) |entry, index| {
            std.debug.print(
                "  [{}] identity={s} leader_slots={} blocks={}\n",
                .{ index, entry.identity, entry.leader_slots, entry.blocks },
            );
        }
        return;
    }

    if (command == .identity) {
        const identity = try rpc.getIdentity();
        defer allocator.free(identity);
        std.debug.print("identity: {s}\n", .{identity});
        return;
    }

    if (command == .inflation_governor) {
        const governor = try rpc.getInflationGovernor();
        std.debug.print(
            "inflation governor: foundation={d:.4} foundation_term={d:.4} initial={d:.4} taper={d:.4} terminal={d:.4}\n",
            .{ governor.foundation, governor.foundation_term, governor.initial, governor.taper, governor.terminal },
        );
        return;
    }

    if (command == .minimum_ledger_slot) {
        const slot = try rpc.getMinimumLedgerSlot();
        std.debug.print("minimum ledger slot: {}\n", .{slot});
        return;
    }

    if (command == .max_retransmit_slot) {
        const slot = try rpc.getMaxRetransmitSlot();
        std.debug.print("max retransmit slot: {}\n", .{slot});
        return;
    }

    if (command == .max_shred_insert_slot) {
        const slot = try rpc.getMaxShredInsertSlot();
        std.debug.print("max shred insert slot: {}\n", .{slot});
        return;
    }

    if (command == .slot_leaders) {
        const start_slot_text = slot_arg orelse return error.InvalidCli;
        const start_slot = std.fmt.parseInt(u64, start_slot_text, 10) catch return error.InvalidCli;
        const limit_text = slot_leaders_limit_arg orelse return error.InvalidCli;
        const limit = std.fmt.parseInt(u64, limit_text, 10) catch return error.InvalidCli;

        const leaders = try rpc.getSlotLeaders(start_slot, limit);
        defer {
            for (leaders) |leader| {
                allocator.free(leader);
            }
            allocator.free(leaders);
        }

        if (leaders.len == 0) {
            std.debug.print("no slot leaders found\n", .{});
            return;
        }

        std.debug.print("slot leaders from slot {} (limit {}):\n", .{ start_slot, limit });
        for (leaders, 0..) |leader, index| {
            std.debug.print("  [{}] {s}\n", .{ index, leader });
        }
        return;
    }

    if (command == .fee_for_message) {
        const message = message_arg orelse return error.InvalidCli;
        const fee = try rpc.getFeeForMessage(message, commitment);
        if (fee.value) |value| {
            std.debug.print("fee for message: {}\n", .{value});
        } else {
            std.debug.print("fee for message: unavailable\n", .{});
        }
        return;
    }

    if (command == .recent_performance_samples) {
        const limit = if (performance_limit_arg) |raw| std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli else null;
        const samples = try rpc.getRecentPerformanceSamples(limit);
        defer allocator.free(samples);

        if (samples.len == 0) {
            std.debug.print("no recent performance samples\n", .{});
            return;
        }

        std.debug.print("recent performance samples: {}\n", .{samples.len});
        for (samples, 0..) |sample, index| {
            std.debug.print(
                "  [{}] slot={} tx={} slots={} period={}s non_vote_slots={}\n",
                .{ index, sample.slot, sample.num_transactions, sample.num_slots, sample.sample_period_secs, sample.num_non_vote_slots },
            );
        }
        return;
    }

    if (command == .highest_snapshot_slot) {
        const slots = try rpc.getHighestSnapshotSlot();
        std.debug.print(
            "highest snapshot slot: full={?d} incremental={?d}\n",
            .{ slots.full, slots.incremental },
        );
        return;
    }

    if (command == .supply) {
        const supply = try rpc.getSupply(commitment);
        std.debug.print(
            "supply: total={} circulating={} non-circulating={}\n",
            .{ supply.total, supply.circulating, supply.non_circulating },
        );
        return;
    }

    if (command == .blockhash_valid) {
        const blockhash_value = blockhash_arg orelse return error.InvalidCli;
        const is_valid = try rpc.isBlockhashValid(blockhash_value, commitment);
        std.debug.print("blockhash {s} valid: {s}\n", .{ blockhash_value, if (is_valid) "true" else "false" });
        return;
    }

    return error.InvalidCli;
}

test "printUsage text compiles" {
    var out = std.io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();
    try printUsage(&out.writer);
    try std.testing.expect(out.written().len > 0);
}

test "printUsage includes new commands" {
    var out = std.io.Writer.Allocating.init(std.testing.allocator);
    defer out.deinit();
    try printUsage(&out.writer);

    const usage = out.written();
    try std.testing.expect(std.mem.indexOf(u8, usage, "cluster-nodes") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "leader-schedule [slot] [identity]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "vote-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-production") != null);
}
