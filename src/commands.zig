const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");

const Allocator = std.mem.Allocator;

pub fn runCommand(allocator: Allocator, rpc: *client.RpcClient, args: *const cli.ParsedArgs) !void {
    const command = args.command;
    const signature = args.signature;
    const account = args.account;
    const blockhash_arg = args.blockhash_arg;
    const slot_arg = args.slot_arg;
    const blocks_end_slot_arg = args.blocks_end_slot_arg;
    const message_arg = args.message_arg;
    const slot_leaders_limit_arg = args.slot_leaders_limit_arg;
    const performance_limit_arg = args.performance_limit_arg;
    const leader_schedule_slot_arg = args.leader_schedule_slot_arg;
    const leader_schedule_identity_arg = args.leader_schedule_identity_arg;
    const lamports_arg = args.lamports_arg;
    const rent_bytes_arg = args.rent_bytes_arg;
    const signed_tx_arg = args.signed_tx_arg;
    const signature_statuses = args.signature_statuses;
    const commitment = toClientCommitment(args.commitment);
    const status_timeout_ms = args.status_timeout_ms;
    const status_poll_ms = args.status_poll_ms;
    const send_skip_preflight = args.send_skip_preflight;
    const send_max_retries = args.send_max_retries;
    const send_preflight_commitment = toClientCommitment(args.send_preflight_commitment);

    const is_send_command = command == .send_transaction or command == .send_transaction_and_confirm;
    if ((send_skip_preflight or send_max_retries != null or send_preflight_commitment != null) and !is_send_command) {
        std.debug.print(
            "error: send options (--skip-preflight, --max-retries, --preflight-commitment) require send-transaction or send-transaction-and-confirm\n",
            .{},
        );
        return error.InvalidCli;
    }

    if ((status_timeout_ms != 30_000 or status_poll_ms != 500) and command != .status and command != .send_transaction_and_confirm) {
        std.debug.print("error: status options (--timeout-ms, --poll-ms) require status or send-transaction-and-confirm\n", .{});
        return error.InvalidCli;
    }

    switch (command) {
        .latest_blockhash => {
            const blockhash = try rpc.getLatestBlockhash(commitment);
            defer allocator.free(blockhash.blockhash);
            std.debug.print(
                "Latest blockhash: {s}\nLast valid height: {}\n",
                .{ blockhash.blockhash, blockhash.last_valid_block_height },
            );
        },

        .status => {
            const signature_value = signature orelse {
                std.debug.print("error: status requires <signature>\n", .{});
                return error.InvalidCli;
            };
            try rpc.waitForSignatureStatus(signature_value, commitment, status_timeout_ms, status_poll_ms);
            std.debug.print("signature confirmed\n", .{});
        },

        .signature_status => {
            const signature_value = signature orelse {
                std.debug.print("error: signature-status requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const status_info = try rpc.getSignatureStatus(signature_value, commitment);
            defer if (status_info.confirmation_status) |value| allocator.free(value);

            std.debug.print(
                "signature status: has_error={s} slot={} confirmations={} confirmation={s}\n",
                .{
                    if (status_info.has_error) "true" else "false",
                    if (status_info.slot) |value| value else 0,
                    if (status_info.confirmations) |value| value else 0,
                    if (status_info.confirmation_status) |value| value else "unknown",
                },
            );
        },

        .signature_statuses => {
            if (signature_statuses.items.len == 0) {
                std.debug.print("error: signature-statuses requires at least one signature\n", .{});
                return error.InvalidCli;
            }

            const statuses = try rpc.getSignatureStatuses(signature_statuses.items, commitment);
            defer {
                for (statuses) |status| {
                    if (status) |entry| {
                        if (entry.confirmation_status) |value| allocator.free(value);
                    }
                }
                allocator.free(statuses);
            }

            std.debug.print("signature statuses: {}\n", .{statuses.len});
            for (statuses, 0..) |status, index| {
                const signature_value = signature_statuses.items[index];

                if (status == null) {
                    std.debug.print("  [{}] {s}: not found\n", .{ index, signature_value });
                    continue;
                }

                const entry = status.?;
                std.debug.print(
                    "  [{}] {s}: error={s} slot={} confirmations={} confirmation={s}\n",
                    .{
                        index,
                        signature_value,
                        if (entry.has_error) "true" else "false",
                        if (entry.slot) |value| value else 0,
                        if (entry.confirmations) |value| value else 0,
                        if (entry.confirmation_status) |value| value else "unknown",
                    },
                );
            }
        },

        .send_transaction => {
            const tx = signed_tx_arg orelse {
                std.debug.print("error: send-transaction requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const options = if (send_skip_preflight or send_max_retries != null or send_preflight_commitment != null)
                client.SendTransactionOptions{
                    .skip_preflight = send_skip_preflight,
                    .preflight_commitment = send_preflight_commitment,
                    .max_retries = send_max_retries,
                }
            else
                null;

            const tx_signature = try rpc.sendTransaction(tx, options);
            defer allocator.free(tx_signature);

            std.debug.print("signature: {s}\n", .{tx_signature});
        },

        .send_transaction_and_confirm => {
            const tx = signed_tx_arg orelse {
                std.debug.print("error: send-transaction-and-confirm requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const options = if (send_skip_preflight or send_max_retries != null or send_preflight_commitment != null)
                client.SendTransactionOptions{
                    .skip_preflight = send_skip_preflight,
                    .preflight_commitment = send_preflight_commitment,
                    .max_retries = send_max_retries,
                }
            else
                null;

            const tx_signature = try rpc.sendTransactionAndConfirm(tx, options, commitment, status_timeout_ms, status_poll_ms);
            defer allocator.free(tx_signature);

            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        },

        .slot => {
            const slot = try rpc.getSlot(commitment);
            std.debug.print("slot: {}\n", .{slot});
        },

        .block_height => {
            const height = try rpc.getBlockHeight(commitment);
            std.debug.print("block-height: {}\n", .{height});
        },

        .transaction_count => {
            const count = try rpc.getTransactionCount(commitment);
            std.debug.print("transaction-count: {}\n", .{count});
        },

        .balance => {
            const account_value = account orelse return error.InvalidCli;
            const balance = try rpc.getBalance(account_value, commitment);
            std.debug.print("balance for {s}: {}\n", .{ account_value, balance });
        },

        .request_airdrop => {
            const account_value = account orelse return error.InvalidCli;
            const lamports_txt = lamports_arg orelse return error.InvalidCli;
            const lamports = std.fmt.parseInt(u64, lamports_txt, 10) catch return error.InvalidCli;
            const signature_value = try rpc.requestAirdrop(account_value, lamports, commitment);
            defer allocator.free(signature_value);
            std.debug.print("airdrop signature: {s}\n", .{signature_value});
        },

        .minimum_rent_exemption => {
            const rent_bytes_txt = rent_bytes_arg orelse return error.InvalidCli;
            const data_length = std.fmt.parseInt(u64, rent_bytes_txt, 10) catch return error.InvalidCli;
            const lamports = try rpc.minimumBalanceForRentExemption(data_length, commitment);
            std.debug.print("minimum rent exemption: {}\n", .{lamports});
        },

        .version => {
            const version = try rpc.getVersion();
            defer allocator.free(version);
            std.debug.print("version: {s}\n", .{version});
        },

        .epoch_info => {
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
        },

        .health => {
            const health = try rpc.getHealth();
            defer allocator.free(health);
            std.debug.print("health: {s}\n", .{health});
        },

        .genesis_hash => {
            const genesis_hash = try rpc.getGenesisHash();
            defer allocator.free(genesis_hash);
            std.debug.print("genesis hash: {s}\n", .{genesis_hash});
        },

        .first_available_block => {
            const first_block = try rpc.getFirstAvailableBlock(commitment);
            std.debug.print("first available block: {}\n", .{first_block});
        },

        .epoch_schedule => {
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
        },

        .inflation_rate => {
            const rate = try rpc.getInflationRate();
            std.debug.print(
                "inflation rate: total={d:.2} validator={d:.2} foundation={d:.2} epoch={}\n",
                .{ rate.total, rate.validator, rate.foundation, rate.epoch },
            );
        },

        .block_time => {
            const slot_text = slot_arg orelse return error.InvalidCli;
            const slot = std.fmt.parseInt(u64, slot_text, 10) catch return error.InvalidCli;
            const block_time = try rpc.getBlockTime(slot);
            if (block_time) |value| {
                std.debug.print("block time for slot {}: {}\n", .{ slot, value });
            } else {
                std.debug.print("block time for slot {}: unavailable\n", .{slot});
            }
        },

        .blocks => {
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
        },

        .slot_leaders => {
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
        },

        .recent_prioritization_fees => {
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
        },

        .cluster_nodes => {
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
                if (node.gossip) |value| std.debug.print("      gossip={s}\n", .{value});
                if (node.rpc) |value| std.debug.print("      rpc={s}\n", .{value});
                if (node.tpu) |value| std.debug.print("      tpu={s}\n", .{value});
                if (node.version) |value| std.debug.print("      version={s}\n", .{value});
            }
        },

        .leader_schedule => {
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
        },

        .vote_accounts => {
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
                    "  [{}] current vote={s} node={s} stake={} commission={} last_vote={} root_slot={}\n",
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
                    "  [{}] delinquent vote={s} node={s} stake={} commission={} last_vote={} root_slot={}\n",
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
        },

        .block_production => {
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
        },

        .identity => {
            const identity = try rpc.getIdentity();
            defer allocator.free(identity);
            std.debug.print("identity: {s}\n", .{identity});
        },

        .inflation_governor => {
            const governor = try rpc.getInflationGovernor();
            std.debug.print(
                "inflation governor: foundation={d:.4} foundation_term={d:.4} initial={d:.4} taper={d:.4} terminal={d:.4}\n",
                .{ governor.foundation, governor.foundation_term, governor.initial, governor.taper, governor.terminal },
            );
        },

        .minimum_ledger_slot => {
            const slot = try rpc.getMinimumLedgerSlot();
            std.debug.print("minimum ledger slot: {}\n", .{slot});
        },

        .max_retransmit_slot => {
            const slot = try rpc.getMaxRetransmitSlot();
            std.debug.print("max retransmit slot: {}\n", .{slot});
        },

        .max_shred_insert_slot => {
            const slot = try rpc.getMaxShredInsertSlot();
            std.debug.print("max shred insert slot: {}\n", .{slot});
        },

        .fee_for_message => {
            const message = message_arg orelse return error.InvalidCli;
            const fee = try rpc.getFeeForMessage(message, commitment);
            if (fee.value) |value| {
                std.debug.print("fee for message: {}\n", .{value});
            } else {
                std.debug.print("fee for message: unavailable\n", .{});
            }
        },

        .recent_performance_samples => {
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
        },

        .highest_snapshot_slot => {
            const slots = try rpc.getHighestSnapshotSlot();
            std.debug.print(
                "highest snapshot slot: full={?d} incremental={?d}\n",
                .{ slots.full, slots.incremental },
            );
        },

        .supply => {
            const supply = try rpc.getSupply(commitment);
            std.debug.print(
                "supply: total={} circulating={} non-circulating={}\n",
                .{ supply.total, supply.circulating, supply.non_circulating },
            );
        },

        .blockhash_valid => {
            const blockhash_value = blockhash_arg orelse return error.InvalidCli;
            const is_valid = try rpc.isBlockhashValid(blockhash_value, commitment);
            std.debug.print("blockhash {s} valid: {s}\n", .{ blockhash_value, if (is_valid) "true" else "false" });
        },
    }
}

fn toClientCommitment(value: ?cli.Commitment) ?client.Commitment {
    if (value) |commitment| {
        return switch (commitment) {
            .processed => client.Commitment.processed,
            .confirmed => client.Commitment.confirmed,
            .finalized => client.Commitment.finalized,
        };
    }
    return null;
}

test "runCommand validates send options on non-send commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "latest-blockhash",
        "--skip-preflight",
        "--max-retries",
        "1",
        "--preflight-commitment",
        "confirmed",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates status options on non-status commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "latest-blockhash",
        "--timeout-ms",
        "1200",
        "--poll-ms",
        "300",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}
