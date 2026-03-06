const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");

const Allocator = std.mem.Allocator;

pub fn runCommand(allocator: Allocator, rpc: *client.RpcClient, args: *const cli.ParsedArgs) !void {
    const command = args.command;
    const signature = args.signature;
    const account = args.account;
    const blockhash_arg = args.blockhash_arg;
    const feature_key_arg = args.feature_key_arg;
    const signatures_for_address_arg = args.signatures_for_address_arg;
    const signatures_for_address_before_arg = args.signatures_for_address_before_arg;
    const signatures_for_address_until_arg = args.signatures_for_address_until_arg;
    const signatures_for_address_limit_arg = args.signatures_for_address_limit_arg;
    const slot_arg = args.slot_arg;
    const blocks_end_slot_arg = args.blocks_end_slot_arg;
    const message_arg = args.message_arg;
    const slot_leaders_limit_arg = args.slot_leaders_limit_arg;
    const performance_limit_arg = args.performance_limit_arg;
    const leader_schedule_slot_arg = args.leader_schedule_slot_arg;
    const leader_schedule_identity_arg = args.leader_schedule_identity_arg;
    const lamports_arg = args.lamports_arg;
    const mint_arg = args.mint_arg;
    const rent_bytes_arg = args.rent_bytes_arg;
    const signed_tx_arg = args.signed_tx_arg;
    const token_program_id_arg = args.token_program_id_arg;
    const signature_statuses = args.signature_statuses;
    const multiple_accounts = args.multiple_accounts;
    const blocks_limit_arg = args.blocks_limit_arg;
    const commitment = toClientCommitment(args.commitment);
    const status_timeout_ms = args.status_timeout_ms;
    const status_poll_ms = args.status_poll_ms;
    const send_skip_preflight = args.send_skip_preflight;
    const simulate_replace_recent_blockhash = args.simulate_replace_recent_blockhash;
    const simulate_sig_verify = args.simulate_sig_verify;
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

    if ((signatures_for_address_before_arg != null or signatures_for_address_until_arg != null or signatures_for_address_limit_arg != null) and
        command != .signatures_for_address)
    {
        std.debug.print("error: --before, --until, --limit are only supported by signatures-for-address\n", .{});
        return error.InvalidCli;
    }

    if ((simulate_sig_verify or simulate_replace_recent_blockhash) and command != .simulate_transaction) {
        std.debug.print("error: --sig-verify and --replace-recent-blockhash require simulate-transaction\n", .{});
        return error.InvalidCli;
    }

    const is_token_accounts_command = command == .token_accounts_by_owner or command == .token_accounts_by_delegate;
    if ((mint_arg != null or token_program_id_arg != null) and !is_token_accounts_command) {
        std.debug.print("error: --mint and --token-program-id are only supported by token-accounts-by-owner and token-accounts-by-delegate\n", .{});
        return error.InvalidCli;
    }

    if (is_token_accounts_command and mint_arg == null and token_program_id_arg == null) {
        std.debug.print("error: token account queries require exactly one filter: --mint or --token-program-id\n", .{});
        return error.InvalidCli;
    }

    if (is_token_accounts_command and mint_arg != null and token_program_id_arg != null) {
        std.debug.print("error: token account queries require exactly one filter: --mint or --token-program-id\n", .{});
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

        .simulate_transaction => {
            const tx = signed_tx_arg orelse {
                std.debug.print("error: simulate-transaction requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const options = if (simulate_sig_verify or simulate_replace_recent_blockhash or commitment != null)
                client.SimulateTransactionOptions{
                    .sig_verify = simulate_sig_verify,
                    .replace_recent_blockhash = simulate_replace_recent_blockhash,
                    .commitment = commitment,
                }
            else
                null;

            const simulation = try rpc.simulateTransaction(tx, options);
            defer freeSimulatedTransaction(allocator, simulation);

            std.debug.print(
                "simulation: err={s} units_consumed={?d} loaded_accounts_data_size={?d}\n",
                .{
                    if (simulation.err_json) |value| value else "null",
                    simulation.units_consumed,
                    simulation.loaded_accounts_data_size,
                },
            );

            if (simulation.replacement_blockhash) |value| {
                std.debug.print(
                    "replacement blockhash: {s} last_valid_block_height={}\n",
                    .{ value.blockhash, value.last_valid_block_height },
                );
            }

            if (simulation.logs) |logs| {
                std.debug.print("logs: {}\n", .{logs.len});
                for (logs, 0..) |entry, index| {
                    std.debug.print("  [{}] {s}\n", .{ index, entry });
                }
            } else {
                std.debug.print("logs: 0\n", .{});
            }
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

        .account_info => {
            const account_value = account orelse return error.InvalidCli;
            const info = try rpc.getAccountInfo(account_value, commitment);
            defer {
                freeAccountInfo(allocator, info);
            }

            std.debug.print(
                "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
            );
            if (info.data) |value| {
                std.debug.print("  data({s}) size={}\n", .{ info.data_encoding orelse "unknown", value.len });
            } else {
                std.debug.print("  data: unavailable\n", .{});
            }
        },

        .multiple_accounts => {
            if (multiple_accounts.items.len == 0) {
                std.debug.print("error: multiple-accounts requires at least one account\n", .{});
                return error.InvalidCli;
            }

            const infos = try rpc.getMultipleAccounts(multiple_accounts.items, commitment);
            defer {
                for (infos) |maybe_info| {
                    if (maybe_info) |info| freeAccountInfo(allocator, info);
                }
                allocator.free(infos);
            }

            std.debug.print("multiple accounts: {}\n", .{infos.len});
            for (infos, 0..) |maybe_info, index| {
                const address = multiple_accounts.items[index];
                if (maybe_info) |info| {
                    std.debug.print(
                        "  [{}] {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                        .{ index, address, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                    );
                    if (info.data) |value| {
                        std.debug.print("      data({s}) size={}\n", .{ info.data_encoding orelse "unknown", value.len });
                    }
                } else {
                    std.debug.print("  [{}] {s}: not found\n", .{ index, address });
                }
            }
        },

        .program_accounts => {
            const program_id = account orelse return error.InvalidCli;
            const accounts_for_program = try rpc.getProgramAccounts(program_id, commitment);
            defer {
                for (accounts_for_program) |entry| {
                    allocator.free(entry.pubkey);
                    freeAccountInfo(allocator, entry.account);
                }
                allocator.free(accounts_for_program);
            }

            if (accounts_for_program.len == 0) {
                std.debug.print("no program accounts found for {s}\n", .{program_id});
                return;
            }

            std.debug.print("program accounts for {s}: {}\n", .{ program_id, accounts_for_program.len });
            for (accounts_for_program, 0..) |entry, index| {
                std.debug.print(
                    "  [{}] pubkey={s} lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ index, entry.pubkey, entry.account.lamports, if (entry.account.executable) "true" else "false", entry.account.owner, entry.account.rent_epoch, entry.account.space },
                );
                if (entry.account.data) |value| {
                    std.debug.print("      data({s}) size={}\n", .{ entry.account.data_encoding orelse "unknown", value.len });
                }
            }
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

        .block => {
            const slot_text = slot_arg orelse return error.InvalidCli;
            const slot = std.fmt.parseInt(u64, slot_text, 10) catch return error.InvalidCli;

            const block = try rpc.getBlock(slot, commitment);
            if (block) |value| {
                defer allocator.free(value);
                std.debug.print("block {}: {s}\n", .{ slot, value });
            } else {
                std.debug.print("block {}: not found\n", .{slot});
            }
        },

        .blocks => {
            const start_slot_text = slot_arg orelse return error.InvalidCli;
            const start_slot = std.fmt.parseInt(u64, start_slot_text, 10) catch return error.InvalidCli;
            const end_slot = if (blocks_end_slot_arg) |raw| std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli else null;
            const blocks = try rpc.getBlocks(start_slot, end_slot, commitment);
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

        .blocks_with_limit => {
            const start_slot_text = slot_arg orelse return error.InvalidCli;
            const start_slot = std.fmt.parseInt(u64, start_slot_text, 10) catch return error.InvalidCli;
            const limit_text = blocks_limit_arg orelse return error.InvalidCli;
            const limit = std.fmt.parseInt(u64, limit_text, 10) catch return error.InvalidCli;

            const blocks = try rpc.getBlocksWithLimit(start_slot, limit, commitment);
            defer allocator.free(blocks);

            if (blocks.len == 0) {
                std.debug.print("no blocks found from slot {} with limit {}\n", .{ start_slot, limit });
                return;
            }

            std.debug.print("blocks with limit {} from slot {}: {}\n", .{ limit, start_slot, blocks.len });
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

        .largest_accounts => {
            const largest_accounts = try rpc.getLargestAccounts(commitment);
            defer {
                for (largest_accounts) |entry| {
                    allocator.free(entry.address);
                }
                allocator.free(largest_accounts);
            }

            if (largest_accounts.len == 0) {
                std.debug.print("no largest accounts found\n", .{});
                return;
            }

            std.debug.print("largest accounts: {}\n", .{largest_accounts.len});
            for (largest_accounts, 0..) |entry, index| {
                std.debug.print("  [{}] address={s} lamports={}\n", .{ index, entry.address, entry.lamports });
            }
        },

        .token_account_balance => {
            const token_account = account orelse return error.InvalidCli;
            const amount = try rpc.getTokenAccountBalance(token_account, commitment);
            defer freeTokenAmount(allocator, amount);

            std.debug.print(
                "token account balance for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                .{ token_account, amount.amount, amount.decimals, amount.ui_amount, amount.ui_amount_string },
            );
        },

        .token_supply => {
            const mint = account orelse return error.InvalidCli;
            const amount = try rpc.getTokenSupply(mint, commitment);
            defer freeTokenAmount(allocator, amount);

            std.debug.print(
                "token supply for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                .{ mint, amount.amount, amount.decimals, amount.ui_amount, amount.ui_amount_string },
            );
        },

        .token_largest_accounts => {
            const mint = account orelse return error.InvalidCli;
            const entries = try rpc.getTokenLargestAccounts(mint, commitment);
            defer {
                for (entries) |entry| {
                    allocator.free(entry.address);
                    freeTokenAmount(allocator, entry.amount);
                }
                allocator.free(entries);
            }

            if (entries.len == 0) {
                std.debug.print("no token largest accounts found for {s}\n", .{mint});
                return;
            }

            std.debug.print("token largest accounts for {s}: {}\n", .{ mint, entries.len });
            for (entries, 0..) |entry, index| {
                std.debug.print(
                    "  [{}] address={s} amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                    .{ index, entry.address, entry.amount.amount, entry.amount.decimals, entry.amount.ui_amount, entry.amount.ui_amount_string },
                );
            }
        },

        .token_accounts_by_owner => {
            const owner = account orelse return error.InvalidCli;
            const filter = toTokenAccountsFilter(mint_arg, token_program_id_arg) orelse return error.InvalidCli;
            const entries = try rpc.getTokenAccountsByOwner(owner, filter, commitment);
            defer {
                for (entries) |entry| {
                    allocator.free(entry.pubkey);
                    freeJsonParsedAccountInfo(allocator, entry.account);
                }
                allocator.free(entries);
            }

            if (entries.len == 0) {
                std.debug.print("no token accounts found for owner {s}\n", .{owner});
                return;
            }

            std.debug.print("token accounts for owner {s}: {}\n", .{ owner, entries.len });
            for (entries, 0..) |entry, index| {
                std.debug.print(
                    "  [{}] pubkey={s} lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ index, entry.pubkey, entry.account.lamports, if (entry.account.executable) "true" else "false", entry.account.owner, entry.account.rent_epoch, entry.account.space },
                );
                std.debug.print("      data(jsonParsed): {s}\n", .{entry.account.data_json});
            }
        },

        .token_accounts_by_delegate => {
            const delegate = account orelse return error.InvalidCli;
            const filter = toTokenAccountsFilter(mint_arg, token_program_id_arg) orelse return error.InvalidCli;
            const entries = try rpc.getTokenAccountsByDelegate(delegate, filter, commitment);
            defer {
                for (entries) |entry| {
                    allocator.free(entry.pubkey);
                    freeJsonParsedAccountInfo(allocator, entry.account);
                }
                allocator.free(entries);
            }

            if (entries.len == 0) {
                std.debug.print("no token accounts found for delegate {s}\n", .{delegate});
                return;
            }

            std.debug.print("token accounts for delegate {s}: {}\n", .{ delegate, entries.len });
            for (entries, 0..) |entry, index| {
                std.debug.print(
                    "  [{}] pubkey={s} lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ index, entry.pubkey, entry.account.lamports, if (entry.account.executable) "true" else "false", entry.account.owner, entry.account.rent_epoch, entry.account.space },
                );
                std.debug.print("      data(jsonParsed): {s}\n", .{entry.account.data_json});
            }
        },

        .blockhash_valid => {
            const blockhash_value = blockhash_arg orelse return error.InvalidCli;
            const is_valid = try rpc.isBlockhashValid(blockhash_value, commitment);
            std.debug.print("blockhash {s} valid: {s}\n", .{ blockhash_value, if (is_valid) "true" else "false" });
        },

        .signatures_for_address => {
            const address = signatures_for_address_arg orelse return error.InvalidCli;
            const limit = if (signatures_for_address_limit_arg) |raw| std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli else null;
            const signatures = try rpc.getSignaturesForAddress(
                address,
                signatures_for_address_before_arg,
                signatures_for_address_until_arg,
                limit,
                commitment,
            );
            defer {
                for (signatures) |signature_entry| {
                    allocator.free(signature_entry.signature);
                    if (signature_entry.confirmation_status) |status| allocator.free(status);
                    if (signature_entry.memo) |memo| allocator.free(memo);
                }
                allocator.free(signatures);
            }

            if (signatures.len == 0) {
                std.debug.print("no signatures found for {s}\n", .{address});
                return;
            }

            std.debug.print("signatures for {s}: {}\n", .{ address, signatures.len });
            for (signatures, 0..) |signature_entry, index| {
                std.debug.print(
                    "  [{}] signature={s} slot={} has_error={s} block_time={?d} confirmation={s}\n",
                    .{
                        index,
                        signature_entry.signature,
                        signature_entry.slot,
                        if (signature_entry.has_error) "true" else "false",
                        signature_entry.block_time,
                        if (signature_entry.confirmation_status) |status| status else "none",
                    },
                );
            }
        },

        .feature_activation_slot => {
            const feature_key = feature_key_arg orelse return error.InvalidCli;
            const slot = try rpc.getFeatureActivationSlot(feature_key, commitment);
            if (slot) |value| {
                std.debug.print("feature activation slot: {}\n", .{value});
            } else {
                std.debug.print("feature not activated\n", .{});
            }
        },

        .stake_minimum_delegation => {
            const minimum = try rpc.getStakeMinimumDelegation(commitment);
            std.debug.print("stake minimum delegation: {}\n", .{minimum});
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

fn freeAccountInfo(allocator: Allocator, info: client.AccountInfo) void {
    allocator.free(info.owner);
    if (info.data) |value| allocator.free(value);
    if (info.data_encoding) |value| allocator.free(value);
}

fn freeTokenAmount(allocator: Allocator, amount: client.TokenAmount) void {
    allocator.free(amount.amount);
    allocator.free(amount.ui_amount_string);
}

fn freeJsonParsedAccountInfo(allocator: Allocator, info: client.JsonParsedAccountInfo) void {
    allocator.free(info.owner);
    allocator.free(info.data_json);
}

fn freeSimulatedTransaction(allocator: Allocator, simulation: client.SimulatedTransaction) void {
    if (simulation.err_json) |value| allocator.free(value);
    if (simulation.logs) |logs| {
        for (logs) |entry| allocator.free(entry);
        allocator.free(logs);
    }
    if (simulation.replacement_blockhash) |value| allocator.free(value.blockhash);
}

fn toTokenAccountsFilter(mint_arg: ?[]const u8, token_program_id_arg: ?[]const u8) ?client.TokenAccountsFilter {
    if (mint_arg) |mint| {
        return .{ .mint = mint };
    }
    if (token_program_id_arg) |program_id| {
        return .{ .program_id = program_id };
    }
    return null;
}

fn runMockBlockServer(
    listener: *std.net.Server,
    allocator: Allocator,
    request_capture: *std.ArrayList(u8),
    response_body: []const u8,
) void {
    runMockBlockServerWithLifetime(listener, allocator, request_capture, response_body, false);
}

fn runMockBlockServerWithLifetime(
    listener: *std.net.Server,
    allocator: Allocator,
    request_capture: *std.ArrayList(u8),
    response_body: []const u8,
    close_listener: bool,
) void {
    if (!close_listener) {
        // keep alive for additional test requests in the same thread.
    } else {
        defer listener.deinit();
    }

    var connection = listener.accept() catch return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&receive_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request_capture.appendSlice(allocator, request_body) catch return;
    request.respond(response_body, .{}) catch return;
}

fn expectGetBlockRequest(
    allocator: Allocator,
    body: []const u8,
    expected_slot: u64,
    expected_commitment: ?[]const u8,
) !void {
    const ParsedRequest = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        method: []const u8 = "",
        params: std.json.Value = .null,
    };

    var parsed_request = try std.json.parseFromSlice(ParsedRequest, allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed_request.deinit();
    const request = parsed_request.value;

    try std.testing.expectEqualStrings("getBlock", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    try std.testing.expectEqual(
        if (expected_commitment != null) @as(usize, 2) else @as(usize, 1),
        params.items.len,
    );

    switch (params.items[0]) {
        .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected_slot)), value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment) |expected| {
        switch (params.items[1]) {
            .object => |obj| {
                const commitment_value = obj.get("commitment") orelse return error.InvalidResponse;
                switch (commitment_value) {
                    .string => |value| try std.testing.expectEqualStrings(expected, value),
                    else => return error.InvalidResponse,
                }
            },
            else => return error.InvalidResponse,
        }
    }
}

fn expectGetBlockRequestWithId(
    allocator: Allocator,
    body: []const u8,
    expected_id: u64,
    expected_slot: u64,
    expected_commitment: ?[]const u8,
) !void {
    const ParsedRequest = struct {
        id: u64 = 0,
    };

    try expectGetBlockRequest(allocator, body, expected_slot, expected_commitment);

    const parsed_request = try std.json.parseFromSlice(ParsedRequest, allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed_request.deinit();
    try std.testing.expectEqual(expected_id, parsed_request.value.id);
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

test "runCommand executes block command and sends getBlock request" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":123,\"blockhash\":\"abc\"},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBlockServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "123",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectGetBlockRequest(allocator, request_capture.items, 123, null);
}

test "runCommand executes block command with commitment and sends getBlock request" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":456,\"blockhash\":\"abc\"},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBlockServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "456",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectGetBlockRequest(allocator, request_capture.items, 456, "confirmed");
}

test "runCommand handles block not found" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBlockServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "789",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectGetBlockRequest(allocator, request_capture.items, 789, null);
}

test "runCommand sends increasing request ids for block calls" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_capture_1 = std.ArrayList(u8).empty;
    defer request_capture_1.deinit(allocator);

    const response_body_1 =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":111,\"blockhash\":\"abc\"},\"id\":1}";

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    {
        const server_thread = try std.Thread.spawn(.{}, runMockBlockServerWithLifetime, .{ &listener, allocator, &request_capture_1, response_body_1, false });
        defer server_thread.join();

        var parsed_first = try cli.parseCliArgs(allocator, &.{
            "block",
            "111",
        });
        defer parsed_first.deinit(allocator);

        try runCommand(allocator, &rpc, &parsed_first);
        try expectGetBlockRequestWithId(allocator, request_capture_1.items, 1, 111, null);
    }

    var request_capture_2 = std.ArrayList(u8).empty;
    defer request_capture_2.deinit(allocator);

    const response_body_2 =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":222,\"blockhash\":\"abc\"},\"id\":2}";

    {
        const server_thread = try std.Thread.spawn(.{}, runMockBlockServerWithLifetime, .{ &listener, allocator, &request_capture_2, response_body_2, false });
        defer server_thread.join();

        var parsed_second = try cli.parseCliArgs(allocator, &.{
            "block",
            "222",
        });
        defer parsed_second.deinit(allocator);

        try runCommand(allocator, &rpc, &parsed_second);
        try expectGetBlockRequestWithId(allocator, request_capture_2.items, 2, 222, null);
    }
}

test "runCommand block not found prints message" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body = "{\"jsonrpc\":\"2.0\",\"result\":null,\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBlockServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "789",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetBlockRequest(allocator, request_capture.items, 789, null);
    try std.testing.expectEqualStrings("block 789: not found\n", captured);
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

test "runCommand validates blocks-with-limit requires required args" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks-with-limit",
        "123",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates blocks-with-limit start slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks-with-limit",
        "not-a-slot",
        "25",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates blocks-with-limit limit int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks-with-limit",
        "123",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates blocks start slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks",
        "not-a-slot",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates blocks end slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks",
        "123",
        "not-a-slot",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates slot-leaders start slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot-leaders",
        "not-a-slot",
        "10",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates slot-leaders limit int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot-leaders",
        "100",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block-time slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-time",
        "not-a-slot",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block requires slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "not-a-slot",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates status requires signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "status",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signature-status requires signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signature-status",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signature-statuses requires at least one signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signature-statuses",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates request-airdrop requires account" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "request-airdrop",
        "1000",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates request-airdrop requires lamports" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "request-airdrop",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates request-airdrop lamports int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "request-airdrop",
        "Address11111111111111111111111111111111",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates minimum-rent-exemption requires bytes" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "minimum-rent-exemption",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates minimum-rent-exemption bytes int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "minimum-rent-exemption",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signatures-for-address requires address" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signatures-for-address",
        "--before",
        "BeforeSig",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signatures-for-address limit int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signatures-for-address",
        "Address11111111111111111111111111111111",
        "--limit",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects signatures-for-address filters on non-signatures-for-address commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--before",
        "BeforeSig",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates simulate options on non-simulate commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--sig-verify",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects token account filters on non-token-account queries" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--mint",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand requires token account filter for owner query" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "token-accounts-by-owner",
        "Owner1111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects conflicting token account filters" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "token-accounts-by-delegate",
        "Delegate11111111111111111111111111111111111",
        "--mint",
        "Mint111111111111111111111111111111111111",
        "--token-program-id",
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}
