const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");

const Allocator = std.mem.Allocator;

pub fn runCommand(allocator: Allocator, rpc: *client.RpcClient, args: *const cli.ParsedArgs) !void {
    const command = args.command;
    const signature = args.signature;
    const account = args.account;
    const expected_balance_arg = args.expected_balance_arg;
    const airdrop_recent_blockhash_arg = args.airdrop_recent_blockhash_arg;
    const account_data_slice_length_arg = args.account_data_slice_length_arg;
    const account_data_slice_offset_arg = args.account_data_slice_offset_arg;
    const account_encoding_arg = args.account_encoding_arg;
    const blockhash_arg = args.blockhash_arg;
    const block_production_identity_arg = args.block_production_identity_arg;
    const block_production_first_slot_arg = args.block_production_first_slot_arg;
    const block_production_last_slot_arg = args.block_production_last_slot_arg;
    const confirmation_blocks_arg = args.confirmation_blocks_arg;
    const delinquent_slot_distance_arg = args.delinquent_slot_distance_arg;
    const encoding_arg = args.encoding_arg;
    const epoch_arg = args.epoch_arg;
    const feature_key_arg = args.feature_key_arg;
    const largest_filter_arg = args.largest_filter_arg;
    const max_supported_transaction_version_arg = args.max_supported_transaction_version_arg;
    const min_context_slot_arg = args.min_context_slot_arg;
    const program_data_size_arg = args.program_data_size_arg;
    const program_data_slice_length_arg = args.program_data_slice_length_arg;
    const program_data_slice_offset_arg = args.program_data_slice_offset_arg;
    const program_memcmp_bytes_arg = args.program_memcmp_bytes_arg;
    const program_memcmp_offset_arg = args.program_memcmp_offset_arg;
    const program_sort_results = args.program_sort_results;
    const with_context = args.program_with_context;
    const signatures_for_address_arg = args.signatures_for_address_arg;
    const signatures_for_address_before_arg = args.signatures_for_address_before_arg;
    const signatures_for_address_until_arg = args.signatures_for_address_until_arg;
    const signatures_for_address_limit_arg = args.signatures_for_address_limit_arg;
    const rewards_arg = args.rewards_arg;
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
    const simulation_account_encoding_arg = args.simulation_account_encoding_arg;
    const simulation_min_context_slot_arg = args.simulation_min_context_slot_arg;
    const supply_exclude_non_circulating_accounts_list = args.supply_exclude_non_circulating_accounts_list;
    const token_program_id_arg = args.token_program_id_arg;
    const transaction_details_arg = args.transaction_details_arg;
    const vote_pubkey_arg = args.vote_pubkey_arg;
    const signature_statuses = args.signature_statuses;
    const multiple_accounts = args.multiple_accounts;
    const simulation_accounts = args.simulation_accounts;
    const blocks_limit_arg = args.blocks_limit_arg;
    const commitment = toClientCommitment(args.commitment);
    const status_timeout_ms = args.status_timeout_ms;
    const status_poll_ms = args.status_poll_ms;
    const timeout_ms_overridden = args.timeout_ms_overridden;
    const poll_ms_overridden = args.poll_ms_overridden;
    const search_transaction_history = args.search_transaction_history;
    const send_skip_preflight = args.send_skip_preflight;
    const simulate_inner_instructions = args.simulate_inner_instructions;
    const simulate_replace_recent_blockhash = args.simulate_replace_recent_blockhash;
    const simulate_sig_verify = args.simulate_sig_verify;
    const vote_keep_unstaked_delinquents = args.vote_keep_unstaked_delinquents;
    const send_max_retries = args.send_max_retries;
    const send_preflight_commitment = toClientCommitment(args.send_preflight_commitment);

    const is_balance_wait_command = command == .poll_balance or command == .wait_for_balance;
    const is_send_command = command == .send_transaction or command == .send_transaction_and_confirm;
    const is_account_min_context_command = command == .account_data or
        command == .account_info or
        command == .ui_account or
        command == .multiple_accounts or
        command == .multiple_ui_accounts or
        command == .program_accounts or
        command == .program_ui_accounts or
        command == .token_account;
    const is_with_context_command = command == .latest_blockhash or
        command == .balance or
        command == .account_info or
        command == .ui_account or
        command == .multiple_accounts or
        command == .multiple_ui_accounts or
        command == .program_accounts or
        command == .program_ui_accounts or
        command == .token_account_balance or
        command == .token_supply or
        command == .token_largest_accounts or
        command == .fee_for_message;
    const effective_timeout_ms = if (timeout_ms_overridden)
        status_timeout_ms
    else if (is_balance_wait_command)
        client.default_balance_poll_timeout_ms
    else
        status_timeout_ms;
    const effective_poll_ms = if (poll_ms_overridden)
        status_poll_ms
    else if (is_balance_wait_command)
        client.default_balance_poll_interval_ms
    else
        status_poll_ms;
    if ((send_skip_preflight or send_max_retries != null or send_preflight_commitment != null) and !is_send_command) {
        std.debug.print(
            "error: send options (--skip-preflight, --max-retries, --preflight-commitment) require send-transaction or send-transaction-and-confirm\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (airdrop_recent_blockhash_arg != null and command != .request_airdrop) {
        std.debug.print("error: --airdrop-recent-blockhash requires request-airdrop\n", .{});
        return error.InvalidCli;
    }

    if ((timeout_ms_overridden or poll_ms_overridden) and command != .status and command != .poll_balance and command != .wait_for_balance and command != .send_transaction_and_confirm and command != .poll_for_signature_confirmation) {
        std.debug.print("error: wait options (--timeout-ms, --poll-ms) require status, poll-balance, wait-for-balance, poll-for-signature-confirmation, or send-transaction-and-confirm\n", .{});
        return error.InvalidCli;
    }

    if (search_transaction_history and
        command != .status and
        command != .confirm_transaction and
        command != .signature_status and
        command != .signature_statuses and
        command != .blocks_since_signature_confirmation and
        command != .poll_for_signature_confirmation and
        command != .send_transaction_and_confirm)
    {
        std.debug.print(
            "error: --search-transaction-history requires status, confirm-transaction, signature-status, signature-statuses, blocks-since-signature-confirmation, poll-for-signature-confirmation, or send-transaction-and-confirm\n",
            .{},
        );
        return error.InvalidCli;
    }

    if ((signatures_for_address_before_arg != null or signatures_for_address_until_arg != null or signatures_for_address_limit_arg != null) and
        command != .signatures_for_address)
    {
        std.debug.print("error: --before, --until, --limit are only supported by signatures-for-address\n", .{});
        return error.InvalidCli;
    }

    if (min_context_slot_arg != null and !is_send_command and command != .signatures_for_address and !is_account_min_context_command) {
        std.debug.print(
            "error: --min-context-slot requires send commands, signatures-for-address, or account/program queries\n",
            .{},
        );
        return error.InvalidCli;
    }

    if ((simulate_sig_verify or simulate_replace_recent_blockhash) and command != .simulate_transaction) {
        std.debug.print("error: --sig-verify and --replace-recent-blockhash require simulate-transaction\n", .{});
        return error.InvalidCli;
    }

    if ((simulate_inner_instructions or simulation_account_encoding_arg != null or simulation_min_context_slot_arg != null or simulation_accounts.items.len > 0) and
        command != .simulate_transaction)
    {
        std.debug.print(
            "error: simulation query options require simulate-transaction\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (simulation_account_encoding_arg != null and simulation_accounts.items.len == 0) {
        std.debug.print("error: --simulation-account-encoding requires at least one --simulation-account\n", .{});
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

    const is_transaction_query_command = command == .block or command == .transaction;
    if ((encoding_arg != null or max_supported_transaction_version_arg != null) and !is_transaction_query_command) {
        std.debug.print("error: --encoding and --max-supported-transaction-version require block or transaction\n", .{});
        return error.InvalidCli;
    }

    if ((transaction_details_arg != null or rewards_arg != null) and command != .block) {
        std.debug.print("error: --transaction-details and --rewards require block\n", .{});
        return error.InvalidCli;
    }

    if (epoch_arg != null and command != .inflation_reward) {
        std.debug.print("error: --epoch requires inflation-reward\n", .{});
        return error.InvalidCli;
    }

    if ((vote_pubkey_arg != null or vote_keep_unstaked_delinquents or delinquent_slot_distance_arg != null) and command != .vote_accounts) {
        std.debug.print("error: vote account filters require vote-accounts\n", .{});
        return error.InvalidCli;
    }

    if (largest_filter_arg != null and command != .largest_accounts) {
        std.debug.print("error: --largest-filter requires largest-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((block_production_identity_arg != null or block_production_first_slot_arg != null or block_production_last_slot_arg != null) and command != .block_production) {
        std.debug.print("error: block production filters require block-production\n", .{});
        return error.InvalidCli;
    }

    if (with_context and !is_with_context_command) {
        std.debug.print(
            "error: --with-context requires latest-blockhash, balance, fee-for-message, token-account-balance, token-supply, token-largest-accounts, account-info, ui-account, multiple-accounts, multiple-ui-accounts, program-accounts, or program-ui-accounts\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (supply_exclude_non_circulating_accounts_list and command != .supply) {
        std.debug.print("error: --exclude-non-circulating-accounts-list requires supply\n", .{});
        return error.InvalidCli;
    }

    const has_program_accounts_filters = program_data_size_arg != null or
        program_memcmp_offset_arg != null or
        program_memcmp_bytes_arg != null or
        program_data_slice_offset_arg != null or
        program_data_slice_length_arg != null or
        program_sort_results;
    if (has_program_accounts_filters and command != .program_accounts and command != .program_ui_accounts) {
        std.debug.print("error: program account filters require program-accounts or program-ui-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((program_memcmp_offset_arg == null) != (program_memcmp_bytes_arg == null)) {
        std.debug.print("error: --program-memcmp-offset and --program-memcmp-bytes must be used together\n", .{});
        return error.InvalidCli;
    }

    if ((program_data_slice_offset_arg == null) != (program_data_slice_length_arg == null)) {
        std.debug.print("error: --program-data-slice-offset and --program-data-slice-length must be used together\n", .{});
        return error.InvalidCli;
    }

    const has_account_query_filters = account_encoding_arg != null or
        account_data_slice_offset_arg != null or
        account_data_slice_length_arg != null;
    if (has_account_query_filters and command != .account_info and command != .multiple_accounts) {
        std.debug.print("error: account query filters require account-info or multiple-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((account_data_slice_offset_arg == null) != (account_data_slice_length_arg == null)) {
        std.debug.print("error: --account-data-slice-offset and --account-data-slice-length must be used together\n", .{});
        return error.InvalidCli;
    }

    const min_context_slot = if (min_context_slot_arg) |raw|
        std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli
    else
        null;

    switch (command) {
        .latest_blockhash => {
            if (with_context) {
                const blockhash_response = try rpc.getLatestBlockhashResponse(commitment);
                defer allocator.free(blockhash_response.value.blockhash);
                std.debug.print("latest blockhash context slot: {}\n", .{blockhash_response.context_slot});
                std.debug.print(
                    "Latest blockhash: {s}\nLast valid height: {}\n",
                    .{ blockhash_response.value.blockhash, blockhash_response.value.last_valid_block_height },
                );
            } else {
                const blockhash = try rpc.getLatestBlockhash(commitment);
                defer allocator.free(blockhash.blockhash);
                std.debug.print(
                    "Latest blockhash: {s}\nLast valid height: {}\n",
                    .{ blockhash.blockhash, blockhash.last_valid_block_height },
                );
            }
        },

        .status => {
            const signature_value = signature orelse {
                std.debug.print("error: status requires <signature>\n", .{});
                return error.InvalidCli;
            };
            try rpc.waitForSignatureStatus(signature_value, commitment, search_transaction_history, status_timeout_ms, status_poll_ms);
            std.debug.print("signature confirmed\n", .{});
        },

        .confirm_transaction => {
            const signature_value = signature orelse {
                std.debug.print("error: confirm-transaction requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const confirmed = try rpc.confirmTransaction(signature_value, commitment, search_transaction_history);
            std.debug.print("signature {s} confirmed: {s}\n", .{ signature_value, if (confirmed) "true" else "false" });
        },

        .signature_status => {
            const signature_value = signature orelse {
                std.debug.print("error: signature-status requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const status_request_options = if (search_transaction_history or commitment != null)
                client.SignatureStatusesQueryOptions{
                    .search_transaction_history = search_transaction_history,
                    .commitment = commitment,
                }
            else
                null;
            const status_info = try rpc.getSignatureStatusWithOptions(signature_value, status_request_options);
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

            const signature_status_options = if (search_transaction_history or commitment != null)
                client.SignatureStatusesQueryOptions{
                    .search_transaction_history = search_transaction_history,
                    .commitment = commitment,
                }
            else
                null;
            const statuses = try rpc.getSignatureStatusesWithOptions(
                signature_statuses.items,
                signature_status_options,
            );
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

        .poll_for_signature_confirmation => {
            const signature_value = signature orelse {
                std.debug.print("error: poll-for-signature-confirmation requires <signature> <min-confirmed-blocks>\n", .{});
                return error.InvalidCli;
            };
            const min_confirmed_blocks = if (confirmation_blocks_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else {
                std.debug.print("error: poll-for-signature-confirmation requires <signature> <min-confirmed-blocks>\n", .{});
                return error.InvalidCli;
            };

            const confirmed_blocks = try rpc.pollForSignatureConfirmationWithCommitmentAndTimeouts(
                signature_value,
                min_confirmed_blocks,
                commitment,
                search_transaction_history,
                status_timeout_ms,
                status_poll_ms,
            );
            std.debug.print(
                "signature {s} reached {} confirmed blocks (target={})\n",
                .{ signature_value, confirmed_blocks, min_confirmed_blocks },
            );
        },

        .blocks_since_signature_confirmation => {
            const signature_value = signature orelse {
                std.debug.print("error: blocks-since-signature-confirmation requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const confirmed_blocks = try rpc.getNumBlocksSinceSignatureConfirmationWithCommitment(
                signature_value,
                commitment,
                search_transaction_history,
            );
            std.debug.print("signature {s} confirmed blocks: {}\n", .{ signature_value, confirmed_blocks });
        },

        .send_transaction => {
            const tx = signed_tx_arg orelse {
                std.debug.print("error: send-transaction requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const options = if (send_skip_preflight or send_max_retries != null or send_preflight_commitment != null or min_context_slot != null)
                client.SendTransactionOptions{
                    .skip_preflight = send_skip_preflight,
                    .preflight_commitment = send_preflight_commitment,
                    .max_retries = send_max_retries,
                    .min_context_slot = min_context_slot,
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

            const options = if (send_skip_preflight or send_max_retries != null or send_preflight_commitment != null or min_context_slot != null)
                client.SendTransactionOptions{
                    .skip_preflight = send_skip_preflight,
                    .preflight_commitment = send_preflight_commitment,
                    .max_retries = send_max_retries,
                    .min_context_slot = min_context_slot,
                }
            else
                null;

            const tx_signature = try rpc.sendTransactionAndConfirm(
                tx,
                options,
                commitment,
                search_transaction_history,
                status_timeout_ms,
                status_poll_ms,
            );
            defer allocator.free(tx_signature);

            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        },

        .simulate_transaction => {
            const tx = signed_tx_arg orelse {
                std.debug.print("error: simulate-transaction requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const simulation_account_encoding = if (simulation_account_encoding_arg) |value|
                parseAccountEncoding(value) orelse return error.InvalidCli
            else
                null;
            const simulation_min_context_slot = if (simulation_min_context_slot_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const simulation_accounts_options = if (simulation_accounts.items.len > 0)
                client.SimulationAccountsOptions{
                    .addresses = simulation_accounts.items,
                    .encoding = simulation_account_encoding,
                }
            else
                null;

            const options = if (simulate_sig_verify or
                simulate_replace_recent_blockhash or
                simulate_inner_instructions or
                commitment != null or
                simulation_min_context_slot != null or
                simulation_accounts_options != null)
                client.SimulateTransactionOptions{
                    .sig_verify = simulate_sig_verify,
                    .replace_recent_blockhash = simulate_replace_recent_blockhash,
                    .commitment = commitment,
                    .min_context_slot = simulation_min_context_slot,
                    .inner_instructions = simulate_inner_instructions,
                    .accounts = simulation_accounts_options,
                }
            else
                null;

            const simulation = try rpc.simulateTransaction(tx, options);
            defer freeSimulatedTransaction(allocator, simulation);

            std.debug.print(
                "simulation: slot={} err={s} fee={?d} units_consumed={?d} loaded_accounts_data_size={?d}\n",
                .{
                    simulation.context_slot,
                    if (simulation.err_json) |value| value else "null",
                    simulation.fee,
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

            if (simulation.accounts) |accounts| {
                std.debug.print("accounts: {}\n", .{accounts.len});
                for (accounts, 0..) |maybe_info, index| {
                    if (maybe_info) |info| {
                        std.debug.print(
                            "  [{}] lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                            .{ index, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                        );
                        if (info.data) |value| {
                            std.debug.print("      data({s}) size={}\n", .{ info.data_encoding orelse "unknown", value.len });
                        } else {
                            std.debug.print("      data: unavailable\n", .{});
                        }
                    } else {
                        std.debug.print("  [{}] not found\n", .{index});
                    }
                }
            } else {
                std.debug.print("accounts: 0\n", .{});
            }

            if (simulation.return_data) |value| {
                std.debug.print(
                    "return data: program_id={s} encoding={s} size={}\n",
                    .{ value.program_id, value.data_encoding orelse "unknown", if (value.data) |data| data.len else @as(usize, 0) },
                );
            } else {
                std.debug.print("return data: unavailable\n", .{});
            }

            if (simulation.inner_instructions_json) |value| {
                std.debug.print("inner instructions: {s}\n", .{value});
            } else {
                std.debug.print("inner instructions: unavailable\n", .{});
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

        .transaction => {
            const signature_value = signature orelse {
                std.debug.print("error: transaction requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const encoding = if (encoding_arg) |value| parseTransactionEncoding(value) orelse return error.InvalidCli else null;
            const max_supported_transaction_version = if (max_supported_transaction_version_arg) |value|
                std.fmt.parseInt(u8, value, 10) catch return error.InvalidCli
            else
                null;
            const options = if (encoding != null or max_supported_transaction_version != null or commitment != null)
                client.TransactionQueryOptions{
                    .commitment = commitment,
                    .encoding = encoding,
                    .max_supported_transaction_version = max_supported_transaction_version,
                }
            else
                null;

            const transaction = try rpc.getTransaction(signature_value, options);
            if (transaction) |value| {
                defer allocator.free(value);
                const summary = try rpc.summarizeTransactionJson(value);
                defer rpc.freeOwnedTransactionSummary(summary);

                std.debug.print(
                    "transaction {s}: slot={} block_time={?d} version={s} signatures={?d} fee={?d} log_messages={?d} has_error={s}\n",
                    .{
                        signature_value,
                        summary.slot,
                        summary.block_time,
                        summary.version orelse "unknown",
                        summary.signature_count,
                        summary.fee,
                        summary.log_messages_count,
                        if (summary.has_error) "true" else "false",
                    },
                );
                if (summary.error_json) |error_json| {
                    std.debug.print("  error: {s}\n", .{error_json});
                }
                std.debug.print("  raw: {s}\n", .{value});
            } else {
                std.debug.print("transaction {s}: not found\n", .{signature_value});
            }
        },

        .balance => {
            const account_value = account orelse return error.InvalidCli;
            if (with_context) {
                const balance_response = try rpc.getBalanceResponse(account_value, commitment);
                std.debug.print("balance context slot: {}\n", .{balance_response.context_slot});
                std.debug.print("balance for {s}: {}\n", .{ account_value, balance_response.value });
            } else {
                const balance = try rpc.getBalance(account_value, commitment);
                std.debug.print("balance for {s}: {}\n", .{ account_value, balance });
            }
        },

        .poll_balance => {
            const account_value = account orelse return error.InvalidCli;
            const balance = try rpc.pollGetBalanceWithCommitmentAndTimeouts(
                account_value,
                commitment,
                effective_timeout_ms,
                effective_poll_ms,
            );
            std.debug.print("polled balance for {s}: {}\n", .{ account_value, balance });
        },

        .wait_for_balance => {
            const account_value = account orelse return error.InvalidCli;
            const expected_balance = if (expected_balance_arg) |raw|
                std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli
            else {
                std.debug.print("error: wait-for-balance requires <expected-lamports>\n", .{});
                return error.InvalidCli;
            };

            const balance = try rpc.waitForBalanceWithCommitmentAndTimeouts(
                account_value,
                expected_balance,
                commitment,
                effective_timeout_ms,
                effective_poll_ms,
            );
            std.debug.print("balance for {s} reached {}\n", .{ account_value, balance });
        },

        .account_data => {
            const account_value = account orelse return error.InvalidCli;
            const data = (if (min_context_slot != null or commitment != null)
                rpc.getAccountDataWithOptions(account_value, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                })
            else
                rpc.getAccountData(account_value, commitment)) catch |err| switch (err) {
                error.AccountNotFound => {
                    std.debug.print("account data for {s}: not found\n", .{account_value});
                    return;
                },
                else => return err,
            };
            defer allocator.free(data);

            std.debug.print("account data for {s}: {} bytes\n", .{ account_value, data.len });
            std.debug.print("{x}\n", .{data});
        },

        .account_info => {
            const account_value = account orelse return error.InvalidCli;
            const encoding = if (account_encoding_arg) |value| parseAccountQueryEncoding(value) orelse return error.InvalidCli else null;
            const data_slice_offset = if (account_data_slice_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_length = if (account_data_slice_length_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;

            if (encoding) |value| {
                switch (value) {
                    .json_parsed => {
                        if (data_slice_offset != null or data_slice_length != null) {
                            std.debug.print("error: --account-data-slice-* are not supported with --account-encoding jsonParsed\n", .{});
                            return error.InvalidCli;
                        }

                        if (with_context) {
                            const info_response = try rpc.getUiAccountResponseWithOptions(account_value, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                            });
                            std.debug.print("account info context slot: {}\n", .{info_response.context_slot});

                            const info = info_response.account orelse {
                                std.debug.print("account info for {s}: not found\n", .{account_value});
                                return;
                            };
                            defer freeJsonParsedAccountInfo(allocator, info);

                            std.debug.print(
                                "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                            );
                            std.debug.print("  data(jsonParsed): {s}\n", .{info.data_json});
                        } else {
                            const info = rpc.getUiAccountWithOptions(account_value, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                            }) catch |err| switch (err) {
                                error.AccountNotFound => {
                                    std.debug.print("account info for {s}: not found\n", .{account_value});
                                    return;
                                },
                                else => return err,
                            };
                            defer freeJsonParsedAccountInfo(allocator, info);

                            std.debug.print(
                                "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                            );
                            std.debug.print("  data(jsonParsed): {s}\n", .{info.data_json});
                        }
                    },
                    .raw => |raw_encoding| {
                        if (with_context) {
                            const info_response = try rpc.getAccountInfoResponseWithOptions(account_value, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                                .encoding = raw_encoding,
                                .data_slice_offset = data_slice_offset,
                                .data_slice_length = data_slice_length,
                            });
                            std.debug.print("account info context slot: {}\n", .{info_response.context_slot});

                            const info = info_response.account orelse {
                                std.debug.print("account info for {s}: not found\n", .{account_value});
                                return;
                            };
                            defer freeAccountInfo(allocator, info);

                            std.debug.print(
                                "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                            );
                            if (info.data) |entry| {
                                std.debug.print("  data({s}) size={}\n", .{ info.data_encoding orelse "unknown", entry.len });
                            } else {
                                std.debug.print("  data: unavailable\n", .{});
                            }
                        } else {
                            const info = rpc.getAccountInfoWithOptions(account_value, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                                .encoding = raw_encoding,
                                .data_slice_offset = data_slice_offset,
                                .data_slice_length = data_slice_length,
                            }) catch |err| switch (err) {
                                error.AccountNotFound => {
                                    std.debug.print("account info for {s}: not found\n", .{account_value});
                                    return;
                                },
                                else => return err,
                            };
                            defer freeAccountInfo(allocator, info);

                            std.debug.print(
                                "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                            );
                            if (info.data) |entry| {
                                std.debug.print("  data({s}) size={}\n", .{ info.data_encoding orelse "unknown", entry.len });
                            } else {
                                std.debug.print("  data: unavailable\n", .{});
                            }
                        }
                    },
                }

                return;
            }

            if (with_context) {
                const info_response = try rpc.getAccountInfoResponseWithOptions(
                    account_value,
                    if (data_slice_offset != null or data_slice_length != null or commitment != null or min_context_slot != null)
                        client.AccountQueryOptions{
                            .commitment = commitment,
                            .min_context_slot = min_context_slot,
                            .encoding = null,
                            .data_slice_offset = data_slice_offset,
                            .data_slice_length = data_slice_length,
                        }
                    else
                        null,
                );
                std.debug.print("account info context slot: {}\n", .{info_response.context_slot});

                const info = info_response.account orelse {
                    std.debug.print("account info for {s}: not found\n", .{account_value});
                    return;
                };
                defer freeAccountInfo(allocator, info);

                std.debug.print(
                    "account info for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                );
                if (info.data) |value| {
                    std.debug.print("  data({s}) size={}\n", .{ info.data_encoding orelse "unknown", value.len });
                } else {
                    std.debug.print("  data: unavailable\n", .{});
                }
                return;
            }

            const info = if (data_slice_offset != null or data_slice_length != null or commitment != null or min_context_slot != null)
                rpc.getAccountInfoWithOptions(account_value, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                    .encoding = null,
                    .data_slice_offset = data_slice_offset,
                    .data_slice_length = data_slice_length,
                }) catch |err| switch (err) {
                    error.AccountNotFound => {
                        std.debug.print("account info for {s}: not found\n", .{account_value});
                        return;
                    },
                    else => return err,
                }
            else
                rpc.getAccountInfo(account_value, commitment) catch |err| switch (err) {
                    error.AccountNotFound => {
                        std.debug.print("account info for {s}: not found\n", .{account_value});
                        return;
                    },
                    else => return err,
                };
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

        .ui_account => {
            const account_value = account orelse return error.InvalidCli;
            if (with_context) {
                const info_response = try rpc.getUiAccountResponseWithOptions(
                    account_value,
                    if (min_context_slot != null or commitment != null)
                        client.UiAccountQueryOptions{
                            .commitment = commitment,
                            .min_context_slot = min_context_slot,
                        }
                    else
                        null,
                );
                std.debug.print("ui account context slot: {}\n", .{info_response.context_slot});

                const info = info_response.account orelse {
                    std.debug.print("ui account for {s}: not found\n", .{account_value});
                    return;
                };
                defer freeJsonParsedAccountInfo(allocator, info);

                std.debug.print(
                    "ui account for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                );
                std.debug.print("  data(jsonParsed): {s}\n", .{info.data_json});
                return;
            }

            const info = (if (min_context_slot != null or commitment != null)
                rpc.getUiAccountWithOptions(account_value, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                })
            else
                rpc.getUiAccount(account_value, commitment)) catch |err| switch (err) {
                error.AccountNotFound => {
                    std.debug.print("ui account for {s}: not found\n", .{account_value});
                    return;
                },
                else => return err,
            };
            defer freeJsonParsedAccountInfo(allocator, info);

            std.debug.print(
                "ui account for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                .{ account_value, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
            );
            std.debug.print("  data(jsonParsed): {s}\n", .{info.data_json});
        },

        .multiple_accounts => {
            if (multiple_accounts.items.len == 0) {
                std.debug.print("error: multiple-accounts requires at least one account\n", .{});
                return error.InvalidCli;
            }

            const encoding = if (account_encoding_arg) |value| parseAccountQueryEncoding(value) orelse return error.InvalidCli else null;
            const data_slice_offset = if (account_data_slice_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_length = if (account_data_slice_length_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;

            if (encoding) |value| {
                switch (value) {
                    .json_parsed => {
                        if (data_slice_offset != null or data_slice_length != null) {
                            std.debug.print("error: --account-data-slice-* are not supported with --account-encoding jsonParsed\n", .{});
                            return error.InvalidCli;
                        }

                        const infos_response = if (with_context)
                            try rpc.getMultipleUiAccountsResponseWithOptions(multiple_accounts.items, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                            })
                        else
                            client.MultipleUiAccountsResponse{
                                .context_slot = 0,
                                .accounts = try rpc.getMultipleUiAccountsWithOptions(multiple_accounts.items, .{
                                    .commitment = commitment,
                                    .min_context_slot = min_context_slot,
                                }),
                            };
                        const infos = infos_response.accounts;
                        defer {
                            for (infos) |maybe_info| {
                                if (maybe_info) |info| freeJsonParsedAccountInfo(allocator, info);
                            }
                            allocator.free(infos);
                        }

                        if (with_context) {
                            std.debug.print("multiple accounts context slot: {}\n", .{infos_response.context_slot});
                        }
                        std.debug.print("multiple accounts: {}\n", .{infos.len});
                        for (infos, 0..) |maybe_info, index| {
                            const address = multiple_accounts.items[index];
                            if (maybe_info) |info| {
                                std.debug.print(
                                    "  [{}] {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                    .{ index, address, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                                );
                                std.debug.print("      data(jsonParsed): {s}\n", .{info.data_json});
                            } else {
                                std.debug.print("  [{}] {s}: not found\n", .{ index, address });
                            }
                        }
                    },
                    .raw => |raw_encoding| {
                        const infos_response = if (with_context)
                            try rpc.getMultipleAccountsResponseWithOptions(multiple_accounts.items, .{
                                .commitment = commitment,
                                .min_context_slot = min_context_slot,
                                .encoding = raw_encoding,
                                .data_slice_offset = data_slice_offset,
                                .data_slice_length = data_slice_length,
                            })
                        else
                            client.MultipleAccountsResponse{
                                .context_slot = 0,
                                .accounts = try rpc.getMultipleAccountsWithOptions(multiple_accounts.items, .{
                                    .commitment = commitment,
                                    .min_context_slot = min_context_slot,
                                    .encoding = raw_encoding,
                                    .data_slice_offset = data_slice_offset,
                                    .data_slice_length = data_slice_length,
                                }),
                            };
                        const infos = infos_response.accounts;
                        defer {
                            for (infos) |maybe_info| {
                                if (maybe_info) |info| freeAccountInfo(allocator, info);
                            }
                            allocator.free(infos);
                        }

                        if (with_context) {
                            std.debug.print("multiple accounts context slot: {}\n", .{infos_response.context_slot});
                        }
                        std.debug.print("multiple accounts: {}\n", .{infos.len});
                        for (infos, 0..) |maybe_info, index| {
                            const address = multiple_accounts.items[index];
                            if (maybe_info) |info| {
                                std.debug.print(
                                    "  [{}] {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                                    .{ index, address, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                                );
                                if (info.data) |entry| {
                                    std.debug.print("      data({s}) size={}\n", .{ info.data_encoding orelse "unknown", entry.len });
                                }
                            } else {
                                std.debug.print("  [{}] {s}: not found\n", .{ index, address });
                            }
                        }
                    },
                }

                return;
            }

            const infos_response = if (with_context)
                try rpc.getMultipleAccountsResponseWithOptions(
                    multiple_accounts.items,
                    if (data_slice_offset != null or data_slice_length != null or commitment != null or min_context_slot != null)
                        client.AccountQueryOptions{
                            .commitment = commitment,
                            .min_context_slot = min_context_slot,
                            .encoding = null,
                            .data_slice_offset = data_slice_offset,
                            .data_slice_length = data_slice_length,
                        }
                    else
                        null,
                )
            else if (data_slice_offset != null or data_slice_length != null or commitment != null or min_context_slot != null)
                client.MultipleAccountsResponse{
                    .context_slot = 0,
                    .accounts = try rpc.getMultipleAccountsWithOptions(multiple_accounts.items, .{
                        .commitment = commitment,
                        .min_context_slot = min_context_slot,
                        .encoding = null,
                        .data_slice_offset = data_slice_offset,
                        .data_slice_length = data_slice_length,
                    }),
                }
            else
                client.MultipleAccountsResponse{
                    .context_slot = 0,
                    .accounts = try rpc.getMultipleAccounts(multiple_accounts.items, commitment),
                };
            const infos = infos_response.accounts;
            defer {
                for (infos) |maybe_info| {
                    if (maybe_info) |info| freeAccountInfo(allocator, info);
                }
                allocator.free(infos);
            }

            if (with_context) {
                std.debug.print("multiple accounts context slot: {}\n", .{infos_response.context_slot});
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

        .multiple_ui_accounts => {
            if (multiple_accounts.items.len == 0) {
                std.debug.print("error: multiple-ui-accounts requires at least one account\n", .{});
                return error.InvalidCli;
            }

            const infos_response = if (with_context)
                try rpc.getMultipleUiAccountsResponseWithOptions(
                    multiple_accounts.items,
                    if (min_context_slot != null or commitment != null)
                        client.UiAccountQueryOptions{
                            .commitment = commitment,
                            .min_context_slot = min_context_slot,
                        }
                    else
                        null,
                )
            else if (min_context_slot != null or commitment != null)
                client.MultipleUiAccountsResponse{
                    .context_slot = 0,
                    .accounts = try rpc.getMultipleUiAccountsWithOptions(multiple_accounts.items, .{
                        .commitment = commitment,
                        .min_context_slot = min_context_slot,
                    }),
                }
            else
                client.MultipleUiAccountsResponse{
                    .context_slot = 0,
                    .accounts = try rpc.getMultipleUiAccounts(multiple_accounts.items, commitment),
                };
            const infos = infos_response.accounts;
            defer {
                for (infos) |maybe_info| {
                    if (maybe_info) |info| freeJsonParsedAccountInfo(allocator, info);
                }
                allocator.free(infos);
            }

            if (with_context) {
                std.debug.print("multiple ui accounts context slot: {}\n", .{infos_response.context_slot});
            }
            std.debug.print("multiple ui accounts: {}\n", .{infos.len});
            for (infos, 0..) |maybe_info, index| {
                const address = multiple_accounts.items[index];
                if (maybe_info) |info| {
                    std.debug.print(
                        "  [{}] {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                        .{ index, address, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
                    );
                    std.debug.print("      data(jsonParsed): {s}\n", .{info.data_json});
                } else {
                    std.debug.print("  [{}] {s}: not found\n", .{ index, address });
                }
            }
        },

        .program_ui_accounts => {
            const program_id = account orelse return error.InvalidCli;
            const data_size = if (program_data_size_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const memcmp_offset = if (program_memcmp_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_offset = if (program_data_slice_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_length = if (program_data_slice_length_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const entries_response = if (data_size != null or memcmp_offset != null or data_slice_offset != null or commitment != null or min_context_slot != null or with_context or program_sort_results)
                try rpc.getProgramUiAccountsResponseWithOptions(program_id, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                    .with_context = with_context,
                    .sort_results = program_sort_results,
                    .data_size = data_size,
                    .memcmp_offset = memcmp_offset,
                    .memcmp_bytes = program_memcmp_bytes_arg,
                    .data_slice_offset = data_slice_offset,
                    .data_slice_length = data_slice_length,
                })
            else
                client.JsonParsedProgramAccountsResponse{
                    .context_slot = null,
                    .accounts = try rpc.getProgramUiAccounts(program_id, commitment),
                };
            const entries = entries_response.accounts;
            defer {
                for (entries) |entry| {
                    freeJsonParsedProgramAccount(allocator, entry);
                }
                allocator.free(entries);
            }

            if (entries.len == 0) {
                std.debug.print("no program ui accounts found for {s}\n", .{program_id});
                return;
            }

            if (with_context) {
                const slot = entries_response.context_slot orelse return error.InvalidResponse;
                std.debug.print("program ui accounts context slot: {}\n", .{slot});
            }
            std.debug.print("program ui accounts for {s}: {}\n", .{ program_id, entries.len });
            for (entries, 0..) |entry, index| {
                std.debug.print(
                    "  [{}] pubkey={s} lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                    .{ index, entry.pubkey, entry.account.lamports, if (entry.account.executable) "true" else "false", entry.account.owner, entry.account.rent_epoch, entry.account.space },
                );
                std.debug.print("      data(jsonParsed): {s}\n", .{entry.account.data_json});
            }
        },

        .program_accounts => {
            const program_id = account orelse return error.InvalidCli;
            const data_size = if (program_data_size_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const memcmp_offset = if (program_memcmp_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_offset = if (program_data_slice_offset_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const data_slice_length = if (program_data_slice_length_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const accounts_response = if (data_size != null or memcmp_offset != null or data_slice_offset != null or commitment != null or min_context_slot != null or with_context or program_sort_results)
                try rpc.getProgramAccountsResponseWithOptions(program_id, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                    .with_context = with_context,
                    .sort_results = program_sort_results,
                    .data_size = data_size,
                    .memcmp_offset = memcmp_offset,
                    .memcmp_bytes = program_memcmp_bytes_arg,
                    .data_slice_offset = data_slice_offset,
                    .data_slice_length = data_slice_length,
                })
            else
                client.ProgramAccountsResponse{
                    .context_slot = null,
                    .accounts = try rpc.getProgramAccounts(program_id, commitment),
                };
            const accounts_for_program = accounts_response.accounts;
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

            if (with_context) {
                const slot = accounts_response.context_slot orelse return error.InvalidResponse;
                std.debug.print("program accounts context slot: {}\n", .{slot});
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
            const signature_value = if (airdrop_recent_blockhash_arg != null or commitment != null)
                try rpc.requestAirdropWithOptions(account_value, lamports, .{
                    .commitment = commitment,
                    .recent_blockhash = airdrop_recent_blockhash_arg,
                })
            else
                try rpc.requestAirdrop(account_value, lamports, commitment);
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

        .inflation_reward => {
            if (multiple_accounts.items.len == 0) {
                std.debug.print("error: inflation-reward requires at least one address\n", .{});
                return error.InvalidCli;
            }

            const epoch = if (epoch_arg) |value| std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli else null;
            const rewards = try rpc.getInflationReward(multiple_accounts.items, epoch, commitment);
            defer allocator.free(rewards);

            std.debug.print("inflation rewards: {}\n", .{rewards.len});
            for (rewards, 0..) |maybe_reward, index| {
                const address = multiple_accounts.items[index];
                if (maybe_reward) |reward| {
                    std.debug.print(
                        "  [{}] {s}: epoch={} effective_slot={} amount={} post_balance={} commission={?d}\n",
                        .{ index, address, reward.epoch, reward.effective_slot, reward.amount, reward.post_balance, reward.commission },
                    );
                } else {
                    std.debug.print("  [{}] {s}: unavailable\n", .{ index, address });
                }
            }
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

        .block_commitment => {
            const slot_text = slot_arg orelse return error.InvalidCli;
            const slot = std.fmt.parseInt(u64, slot_text, 10) catch return error.InvalidCli;
            const result = try rpc.getBlockCommitment(slot);
            defer freeBlockCommitment(allocator, result);

            std.debug.print("block commitment for slot {}: total_stake={}\n", .{ slot, result.total_stake });
            if (result.commitment) |commitment_values| {
                std.debug.print("commitment entries: {}\n", .{commitment_values.len});
                for (commitment_values, 0..) |value, index| {
                    std.debug.print("  [{}] {}\n", .{ index, value });
                }
            } else {
                std.debug.print("commitment entries: unavailable\n", .{});
            }
        },

        .block => {
            const slot_text = slot_arg orelse return error.InvalidCli;
            const slot = std.fmt.parseInt(u64, slot_text, 10) catch return error.InvalidCli;
            const encoding = if (encoding_arg) |value| parseTransactionEncoding(value) orelse return error.InvalidCli else null;
            const transaction_details = if (transaction_details_arg) |value| parseTransactionDetails(value) orelse return error.InvalidCli else null;
            const rewards = if (rewards_arg) |value| parseBoolArg(value) orelse return error.InvalidCli else null;
            const max_supported_transaction_version = if (max_supported_transaction_version_arg) |value|
                std.fmt.parseInt(u8, value, 10) catch return error.InvalidCli
            else
                null;
            const block = if (encoding != null or transaction_details != null or rewards != null or max_supported_transaction_version != null)
                try rpc.getBlockWithOptions(slot, client.BlockQueryOptions{
                    .commitment = commitment,
                    .encoding = encoding,
                    .transaction_details = transaction_details,
                    .rewards = rewards,
                    .max_supported_transaction_version = max_supported_transaction_version,
                })
            else
                try rpc.getBlock(slot, commitment);
            if (block) |value| {
                defer allocator.free(value);
                const summary = try rpc.summarizeBlockJson(value);
                defer rpc.freeOwnedBlockSummary(summary);

                std.debug.print(
                    "block {}: parent_slot={} block_height={?d} block_time={?d} transactions={?d} rewards={?d}\n",
                    .{ slot, summary.parent_slot, summary.block_height, summary.block_time, summary.transaction_count, summary.rewards_count },
                );
                if (summary.blockhash) |blockhash| {
                    std.debug.print("  blockhash: {s}\n", .{blockhash});
                }
                if (summary.previous_blockhash) |previous_blockhash| {
                    std.debug.print("  previous_blockhash: {s}\n", .{previous_blockhash});
                }
                std.debug.print("  raw: {s}\n", .{value});
            } else {
                std.debug.print("block {}: not found\n", .{slot});
            }
        },

        .slot_leader => {
            const leader = try rpc.getSlotLeader(commitment);
            defer allocator.free(leader);
            std.debug.print("slot leader: {s}\n", .{leader});
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
            const fees = try rpc.getRecentPrioritizationFees(if (multiple_accounts.items.len > 0) multiple_accounts.items else null);
            defer allocator.free(fees);

            if (fees.len == 0) {
                std.debug.print("no recent prioritization fees\n", .{});
                return;
            }

            if (multiple_accounts.items.len > 0) {
                std.debug.print("recent prioritization fees for {} accounts: {}\n", .{ multiple_accounts.items.len, fees.len });
            } else {
                std.debug.print("recent prioritization fees: {}\n", .{fees.len});
            }
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
            const delinquent_slot_distance = if (delinquent_slot_distance_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const accounts = if (commitment != null or vote_pubkey_arg != null or vote_keep_unstaked_delinquents or delinquent_slot_distance != null)
                try rpc.getVoteAccountsWithOptions(.{
                    .commitment = commitment,
                    .vote_pubkey = vote_pubkey_arg,
                    .keep_unstaked_delinquents = if (vote_keep_unstaked_delinquents) true else null,
                    .delinquent_slot_distance = delinquent_slot_distance,
                })
            else
                try rpc.getVoteAccounts();
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
            const first_slot = if (block_production_first_slot_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            const last_slot = if (block_production_last_slot_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else
                null;
            if (last_slot != null and first_slot == null) {
                std.debug.print("error: --range-last-slot requires --range-first-slot\n", .{});
                return error.InvalidCli;
            }
            if (first_slot != null and last_slot != null and last_slot.? < first_slot.?) {
                std.debug.print("error: --range-last-slot must be >= --range-first-slot\n", .{});
                return error.InvalidCli;
            }

            const production = if (commitment != null or block_production_identity_arg != null or first_slot != null or last_slot != null)
                try rpc.getBlockProductionWithOptions(.{
                    .commitment = commitment,
                    .identity = block_production_identity_arg,
                    .first_slot = first_slot,
                    .last_slot = last_slot,
                })
            else
                try rpc.getBlockProduction(commitment);
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
            if (with_context) {
                const fee_response = try rpc.getFeeForMessageResponse(message, commitment);
                std.debug.print("fee context slot: {}\n", .{fee_response.context_slot});
                if (fee_response.value) |value| {
                    std.debug.print("fee for message: {}\n", .{value});
                } else {
                    std.debug.print("fee for message: unavailable\n", .{});
                }
            } else {
                const fee = try rpc.getFeeForMessage(message, commitment);
                if (fee.value) |value| {
                    std.debug.print("fee for message: {}\n", .{value});
                } else {
                    std.debug.print("fee for message: unavailable\n", .{});
                }
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
            const supply = if (supply_exclude_non_circulating_accounts_list)
                try rpc.getSupplyWithOptions(.{
                    .commitment = commitment,
                    .exclude_non_circulating_accounts_list = true,
                })
            else
                try rpc.getSupply(commitment);
            defer freeSupply(allocator, supply);
            std.debug.print(
                "supply: total={} circulating={} non-circulating={} non-circulating-accounts={}\n",
                .{
                    supply.total,
                    supply.circulating,
                    supply.non_circulating,
                    if (supply.non_circulating_accounts) |accounts| accounts.len else @as(usize, 0),
                },
            );
        },

        .largest_accounts => {
            const filter = if (largest_filter_arg) |value| parseLargestAccountsFilter(value) orelse return error.InvalidCli else null;
            const largest_accounts = if (filter != null)
                try rpc.getLargestAccountsWithOptions(.{
                    .commitment = commitment,
                    .filter = filter,
                })
            else
                try rpc.getLargestAccounts(commitment);
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
            if (with_context) {
                const amount_response = try rpc.getTokenAccountBalanceResponse(token_account, commitment);
                defer freeTokenAmount(allocator, amount_response.value);
                std.debug.print("token account balance context slot: {}\n", .{amount_response.context_slot});
                std.debug.print(
                    "token account balance for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                    .{
                        token_account,
                        amount_response.value.amount,
                        amount_response.value.decimals,
                        amount_response.value.ui_amount,
                        amount_response.value.ui_amount_string,
                    },
                );
            } else {
                const amount = try rpc.getTokenAccountBalance(token_account, commitment);
                defer freeTokenAmount(allocator, amount);

                std.debug.print(
                    "token account balance for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                    .{ token_account, amount.amount, amount.decimals, amount.ui_amount, amount.ui_amount_string },
                );
            }
        },

        .token_account => {
            const token_account = account orelse return error.InvalidCli;
            const info = (if (min_context_slot != null or commitment != null)
                rpc.getTokenAccountWithOptions(token_account, .{
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                })
            else
                rpc.getTokenAccount(token_account, commitment)) catch |err| switch (err) {
                error.AccountNotFound => {
                    std.debug.print("token account for {s}: not found\n", .{token_account});
                    return;
                },
                else => return err,
            };
            defer freeJsonParsedAccountInfo(allocator, info);

            std.debug.print(
                "token account for {s}: lamports={} executable={s} owner={s} rent_epoch={?d} space={?d}\n",
                .{ token_account, info.lamports, if (info.executable) "true" else "false", info.owner, info.rent_epoch, info.space },
            );
            std.debug.print("  data(jsonParsed): {s}\n", .{info.data_json});
        },

        .token_supply => {
            const mint = account orelse return error.InvalidCli;
            if (with_context) {
                const supply_response = try rpc.getTokenSupplyResponse(mint, commitment);
                defer freeTokenAmount(allocator, supply_response.value);
                std.debug.print("token supply context slot: {}\n", .{supply_response.context_slot});
                std.debug.print(
                    "token supply for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                    .{
                        mint,
                        supply_response.value.amount,
                        supply_response.value.decimals,
                        supply_response.value.ui_amount,
                        supply_response.value.ui_amount_string,
                    },
                );
            } else {
                const amount = try rpc.getTokenSupply(mint, commitment);
                defer freeTokenAmount(allocator, amount);

                std.debug.print(
                    "token supply for {s}: amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                    .{ mint, amount.amount, amount.decimals, amount.ui_amount, amount.ui_amount_string },
                );
            }
        },

        .token_largest_accounts => {
            const mint = account orelse return error.InvalidCli;
            if (with_context) {
                const response = try rpc.getTokenLargestAccountsResponse(mint, commitment);
                defer {
                    for (response.value) |entry| {
                        allocator.free(entry.address);
                        freeTokenAmount(allocator, entry.amount);
                    }
                    allocator.free(response.value);
                }

                std.debug.print("token largest accounts context slot: {}\n", .{response.context_slot});

                if (response.value.len == 0) {
                    std.debug.print("no token largest accounts found for {s}\n", .{mint});
                    return;
                }

                std.debug.print("token largest accounts for {s}: {}\n", .{ mint, response.value.len });
                for (response.value, 0..) |entry, index| {
                    std.debug.print(
                        "  [{}] address={s} amount={s} decimals={} ui_amount={?d} ui_amount_string={s}\n",
                        .{ index, entry.address, entry.amount.amount, entry.amount.decimals, entry.amount.ui_amount, entry.amount.ui_amount_string },
                    );
                }
            } else {
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
            const signatures = try rpc.getSignaturesForAddressWithOptions(
                address,
                .{
                    .before = signatures_for_address_before_arg,
                    .until = signatures_for_address_until_arg,
                    .limit = limit,
                    .commitment = commitment,
                    .min_context_slot = min_context_slot,
                },
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

fn freeJsonParsedProgramAccount(allocator: Allocator, entry: client.JsonParsedProgramAccount) void {
    allocator.free(entry.pubkey);
    freeJsonParsedAccountInfo(allocator, entry.account);
}

fn freeSimulatedTransaction(allocator: Allocator, simulation: client.SimulatedTransaction) void {
    if (simulation.accounts) |accounts| {
        for (accounts) |maybe_info| {
            if (maybe_info) |info| freeAccountInfo(allocator, info);
        }
        allocator.free(accounts);
    }
    if (simulation.err_json) |value| allocator.free(value);
    if (simulation.inner_instructions_json) |value| allocator.free(value);
    if (simulation.logs) |logs| {
        for (logs) |entry| allocator.free(entry);
        allocator.free(logs);
    }
    if (simulation.replacement_blockhash) |value| allocator.free(value.blockhash);
    if (simulation.return_data) |value| {
        allocator.free(value.program_id);
        if (value.data) |entry| allocator.free(entry);
        if (value.data_encoding) |entry| allocator.free(entry);
    }
}

fn freeBlockCommitment(allocator: Allocator, commitment: client.BlockCommitment) void {
    if (commitment.commitment) |values| allocator.free(values);
}

fn freeSupply(allocator: Allocator, supply: client.Supply) void {
    if (supply.non_circulating_accounts) |accounts| {
        for (accounts) |entry| allocator.free(entry);
        allocator.free(accounts);
    }
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

fn parseTransactionEncoding(value: []const u8) ?client.TransactionEncoding {
    if (std.mem.eql(u8, value, "json")) return .json;
    if (std.mem.eql(u8, value, "jsonParsed")) return .jsonParsed;
    if (std.mem.eql(u8, value, "base58")) return .base58;
    if (std.mem.eql(u8, value, "base64")) return .base64;
    return null;
}

fn parseTransactionDetails(value: []const u8) ?client.TransactionDetails {
    if (std.mem.eql(u8, value, "full")) return .full;
    if (std.mem.eql(u8, value, "accounts")) return .accounts;
    if (std.mem.eql(u8, value, "signatures")) return .signatures;
    if (std.mem.eql(u8, value, "none")) return .none;
    return null;
}

fn parseBoolArg(value: []const u8) ?bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return null;
}

fn parseLargestAccountsFilter(value: []const u8) ?client.LargestAccountsFilter {
    if (std.mem.eql(u8, value, "circulating")) return .circulating;
    if (std.mem.eql(u8, value, "non-circulating")) return .non_circulating;
    return null;
}

const AccountQueryEncoding = union(enum) {
    raw: client.AccountEncoding,
    json_parsed,
};

fn parseAccountQueryEncoding(value: []const u8) ?AccountQueryEncoding {
    if (std.mem.eql(u8, value, "base58")) return .{ .raw = .base58 };
    if (std.mem.eql(u8, value, "base64")) return .{ .raw = .base64 };
    if (std.mem.eql(u8, value, "jsonParsed")) return .json_parsed;
    return null;
}

fn parseAccountEncoding(value: []const u8) ?client.AccountEncoding {
    if (std.mem.eql(u8, value, "base58")) return .base58;
    if (std.mem.eql(u8, value, "base64")) return .base64;
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

fn acceptMockConnection(listener: *std.net.Server) ?std.net.Server.Connection {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = listener.stream.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    const ready = std.posix.poll(&poll_fds, 500) catch return null;
    if (ready == 0) return null;
    if (poll_fds[0].revents & std.posix.POLL.IN != std.posix.POLL.IN) return null;

    return listener.accept() catch return null;
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

    var connection = acceptMockConnection(listener) orelse return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var request_body_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&request_body_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request_capture.appendSlice(allocator, request_body) catch return;
    request.respond(response_body, .{}) catch return;
}

fn runMockTransactionServer(
    listener: *std.net.Server,
    allocator: Allocator,
    request_capture: *std.ArrayList(u8),
    response_body: []const u8,
) void {
    var connection = acceptMockConnection(listener) orelse return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var request_body_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&request_body_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request_capture.appendSlice(allocator, request_body) catch return;
    request.respond(response_body, .{}) catch return;
}

fn runMockBalanceServer(
    listener: *std.net.Server,
    allocator: Allocator,
    request_capture: *std.ArrayList(u8),
    response_body: []const u8,
) void {
    var connection = acceptMockConnection(listener) orelse return;
    defer connection.stream.close();

    var receive_buffer: [4096]u8 = undefined;
    var request_body_buffer: [4096]u8 = undefined;
    var send_buffer: [4096]u8 = undefined;
    var connection_reader = connection.stream.reader(&receive_buffer);
    var connection_writer = connection.stream.writer(&send_buffer);
    var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

    var request = http_server.receiveHead() catch return;
    const body_length = request.head.content_length orelse 0;
    const request_body_reader = request.readerExpectNone(&request_body_buffer);
    const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
    defer allocator.free(request_body);

    request_capture.appendSlice(allocator, request_body) catch return;
    request.respond(response_body, .{}) catch return;
}

fn runMockRequestSequenceServer(
    listener: *std.net.Server,
    allocator: Allocator,
    request_captures: *std.ArrayList([]u8),
    response_bodies: []const []const u8,
) void {
    for (response_bodies) |response_body| {
        var connection = acceptMockConnection(listener) orelse return;
        defer connection.stream.close();

        var receive_buffer: [4096]u8 = undefined;
        var request_body_buffer: [4096]u8 = undefined;
        var send_buffer: [4096]u8 = undefined;
        var connection_reader = connection.stream.reader(&receive_buffer);
        var connection_writer = connection.stream.writer(&send_buffer);
        var http_server = std.http.Server.init(connection_reader.interface(), &connection_writer.interface);

        var request = http_server.receiveHead() catch return;
        const body_length = request.head.content_length orelse 0;
        const request_body_reader = request.readerExpectNone(&request_body_buffer);
        const request_body = request_body_reader.readAlloc(allocator, @intCast(body_length)) catch return;
        defer allocator.free(request_body);

        const request_body_copy = allocator.dupe(u8, request_body) catch return;
        request_captures.append(allocator, request_body_copy) catch {
            allocator.free(request_body_copy);
            return;
        };

        request.respond(response_body, .{}) catch return;
    }
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

fn expectGetTransactionRequest(
    allocator: Allocator,
    body: []const u8,
    expected_signature: []const u8,
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

    try std.testing.expectEqualStrings("getTransaction", request.method);
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
        .string => |value| try std.testing.expectEqualStrings(expected_signature, value),
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

fn expectGetBalanceRequest(
    allocator: Allocator,
    body: []const u8,
    expected_account: []const u8,
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

    try std.testing.expectEqualStrings("getBalance", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_account, value),
        else => return error.InvalidResponse,
    }

    switch (params.items[1]) {
        .object => |obj| {
            const commitment_value = obj.get("commitment") orelse return error.InvalidResponse;
            if (expected_commitment) |expected| {
                switch (commitment_value) {
                    .string => |value| try std.testing.expectEqualStrings(expected, value),
                    else => return error.InvalidResponse,
                }
            } else {
                switch (commitment_value) {
                    .null => {},
                    else => return error.InvalidResponse,
                }
            }
        },
        else => return error.InvalidResponse,
    }
}

fn expectGetTokenAccountBalanceRequest(
    allocator: Allocator,
    body: []const u8,
    expected_token_account: []const u8,
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

    try std.testing.expectEqualStrings("getTokenAccountBalance", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    const expected_params_len = if (expected_commitment) |_| @as(usize, 2) else @as(usize, 1);
    try std.testing.expectEqual(expected_params_len, params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_token_account, value),
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

fn expectGetTokenSupplyRequest(
    allocator: Allocator,
    body: []const u8,
    expected_mint: []const u8,
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

    try std.testing.expectEqualStrings("getTokenSupply", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    const expected_params_len = if (expected_commitment) |_| @as(usize, 2) else @as(usize, 1);
    try std.testing.expectEqual(expected_params_len, params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_mint, value),
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

fn expectGetTokenLargestAccountsRequest(
    allocator: Allocator,
    body: []const u8,
    expected_mint: []const u8,
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

    try std.testing.expectEqualStrings("getTokenLargestAccounts", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    const expected_params_len = if (expected_commitment) |_| @as(usize, 2) else @as(usize, 1);
    try std.testing.expectEqual(expected_params_len, params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_mint, value),
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

fn expectGetLatestBlockhashRequest(
    allocator: Allocator,
    body: []const u8,
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

    try std.testing.expectEqualStrings("getLatestBlockhash", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    try std.testing.expectEqual(@as(usize, 1), params.items.len);
    switch (params.items[0]) {
        .object => |obj| {
            const commitment_value = obj.get("commitment") orelse return error.InvalidResponse;
            if (expected_commitment) |expected| {
                switch (commitment_value) {
                    .string => |value| try std.testing.expectEqualStrings(expected, value),
                    else => return error.InvalidResponse,
                }
            } else {
                switch (commitment_value) {
                    .null => {},
                    else => return error.InvalidResponse,
                }
            }
        },
        else => return error.InvalidResponse,
    }
}

fn expectGetFeeForMessageRequest(
    allocator: Allocator,
    body: []const u8,
    expected_message: []const u8,
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

    try std.testing.expectEqualStrings("getFeeForMessage", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    try std.testing.expectEqual(@as(usize, 2), params.items.len);
    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_message, value),
        else => return error.InvalidResponse,
    }

    switch (params.items[1]) {
        .object => |obj| {
            const commitment_value = obj.get("commitment") orelse return error.InvalidResponse;
            if (expected_commitment) |expected| {
                switch (commitment_value) {
                    .string => |value| try std.testing.expectEqualStrings(expected, value),
                    else => return error.InvalidResponse,
                }
            } else {
                switch (commitment_value) {
                    .null => {},
                    else => return error.InvalidResponse,
                }
            }
        },
        else => return error.InvalidResponse,
    }
}

fn expectGetSignatureStatusesRequest(
    allocator: Allocator,
    body: []const u8,
    expected_signatures: []const []const u8,
    expected_search_transaction_history: bool,
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

    try std.testing.expectEqualStrings("getSignatureStatuses", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    const expected_has_options = expected_search_transaction_history or expected_commitment != null;
    if (expected_has_options) {
        try std.testing.expectEqual(@as(usize, 2), params.items.len);
    } else {
        try std.testing.expectEqual(@as(usize, 1), params.items.len);
    }

    const signatures = switch (params.items[0]) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(expected_signatures.len, signatures.items.len);

    for (expected_signatures, 0..) |expected, index| {
        switch (signatures.items[index]) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    }

    if (!expected_has_options) return;

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };

    if (expected_search_transaction_history) {
        const search_transaction_history_value = options.get("searchTransactionHistory") orelse return error.InvalidResponse;
        switch (search_transaction_history_value) {
            .bool => |value| try std.testing.expect(value),
            else => return error.InvalidResponse,
        }
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    }
}

fn expectRequestAirdropRequest(
    allocator: Allocator,
    body: []const u8,
    expected_account: []const u8,
    expected_lamports: u64,
    expected_commitment: ?[]const u8,
    expected_recent_blockhash: ?[]const u8,
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

    try std.testing.expectEqualStrings("requestAirdrop", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };

    const expected_params_len = if (expected_commitment != null or expected_recent_blockhash != null)
        @as(usize, 3)
    else
        @as(usize, 2);
    try std.testing.expectEqual(expected_params_len, params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_account, value),
        else => return error.InvalidResponse,
    }

    switch (params.items[1]) {
        .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected_lamports)), value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment != null or expected_recent_blockhash != null) {
        const options = switch (params.items[2]) {
            .object => |obj| obj,
            else => return error.InvalidResponse,
        };

        if (expected_commitment) |expected| {
            const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
            switch (commitment_value) {
                .string => |value| try std.testing.expectEqualStrings(expected, value),
                else => return error.InvalidResponse,
            }
        } else {
            switch (options.get("commitment") orelse return error.InvalidResponse) {
                .null => {},
                else => return error.InvalidResponse,
            }
        }

        if (expected_recent_blockhash) |expected| {
            const recent_blockhash_value = options.get("recentBlockhash") orelse return error.InvalidResponse;
            switch (recent_blockhash_value) {
                .string => |value| try std.testing.expectEqualStrings(expected, value),
                else => return error.InvalidResponse,
            }
        } else {
            switch (options.get("recentBlockhash") orelse return error.InvalidResponse) {
                .null => {},
                else => return error.InvalidResponse,
            }
        }
    }
}

fn expectGetAccountInfoRequest(
    allocator: Allocator,
    body: []const u8,
    expected_account: []const u8,
    expected_method: []const u8,
    expected_commitment: ?[]const u8,
    expected_min_context_slot: ?u64,
    expected_encoding: ?[]const u8,
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

    try std.testing.expectEqualStrings(expected_method, request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_account, value),
        else => return error.InvalidResponse,
    }

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };

    if (expected_encoding) |expected| {
        const encoding_value = options.get("encoding") orelse return error.InvalidResponse;
        switch (encoding_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("commitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |expected| {
        const min_context_slot_value = options.get("minContextSlot") orelse return error.InvalidResponse;
        switch (min_context_slot_value) {
            .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected)), value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }
}

fn expectGetMultipleAccountsRequest(
    allocator: Allocator,
    body: []const u8,
    expected_accounts: []const []const u8,
    expected_method: []const u8,
    expected_commitment: ?[]const u8,
    expected_min_context_slot: ?u64,
    expected_encoding: []const u8,
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

    try std.testing.expectEqualStrings(expected_method, request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    const accounts = switch (params.items[0]) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(expected_accounts.len, accounts.items.len);

    for (expected_accounts, 0..) |expected, index| {
        switch (accounts.items[index]) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    }

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };

    const encoding_value = options.get("encoding") orelse return error.InvalidResponse;
    switch (encoding_value) {
        .string => |value| try std.testing.expectEqualStrings(expected_encoding, value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("commitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |expected| {
        const min_context_slot_value = options.get("minContextSlot") orelse return error.InvalidResponse;
        switch (min_context_slot_value) {
            .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected)), value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }
}

fn expectGetProgramUiAccountsRequest(
    allocator: Allocator,
    body: []const u8,
    expected_program_id: []const u8,
    expected_commitment: ?[]const u8,
    expected_with_context: bool,
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

    try std.testing.expectEqualStrings("getProgramAccounts", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_program_id, value),
        else => return error.InvalidResponse,
    }

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };

    const encoding_value = options.get("encoding") orelse return error.InvalidResponse;
    switch (encoding_value) {
        .string => |value| try std.testing.expectEqualStrings("jsonParsed", value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("commitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    const with_context_value = options.get("withContext") orelse return error.InvalidResponse;
    switch (with_context_value) {
        .bool => |value| try std.testing.expectEqual(expected_with_context, value),
        else => return error.InvalidResponse,
    }
}

fn expectGetUiAccountRequest(
    allocator: Allocator,
    body: []const u8,
    expected_account: []const u8,
    expected_commitment: ?[]const u8,
    expected_min_context_slot: ?u64,
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

    try std.testing.expectEqualStrings("getAccountInfo", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    switch (params.items[0]) {
        .string => |value| try std.testing.expectEqualStrings(expected_account, value),
        else => return error.InvalidResponse,
    }

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };

    const encoding_value = options.get("encoding") orelse return error.InvalidResponse;
    switch (encoding_value) {
        .string => |value| try std.testing.expectEqualStrings("jsonParsed", value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("commitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |expected| {
        const min_context_slot_value = options.get("minContextSlot") orelse return error.InvalidResponse;
        switch (min_context_slot_value) {
            .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected)), value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }
}

fn expectGetMultipleUiAccountsRequest(
    allocator: Allocator,
    body: []const u8,
    expected_accounts: []const []const u8,
    expected_commitment: ?[]const u8,
    expected_min_context_slot: ?u64,
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

    try std.testing.expectEqualStrings("getMultipleAccounts", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    const accounts = switch (params.items[0]) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(expected_accounts.len, accounts.items.len);

    for (expected_accounts, 0..) |expected, index| {
        switch (accounts.items[index]) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    }

    const options = switch (params.items[1]) {
        .object => |obj| obj,
        else => return error.InvalidResponse,
    };
    const encoding_value = options.get("encoding") orelse return error.InvalidResponse;
    switch (encoding_value) {
        .string => |value| try std.testing.expectEqualStrings("jsonParsed", value),
        else => return error.InvalidResponse,
    }

    if (expected_commitment) |expected| {
        const commitment_value = options.get("commitment") orelse return error.InvalidResponse;
        switch (commitment_value) {
            .string => |value| try std.testing.expectEqualStrings(expected, value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("commitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |expected| {
        const min_context_slot_value = options.get("minContextSlot") orelse return error.InvalidResponse;
        switch (min_context_slot_value) {
            .integer => |value| try std.testing.expectEqual(@as(i64, @intCast(expected)), value),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }
}

test "runCommand validates send options on non-send commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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

test "runCommand rejects search transaction history on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--search-transaction-history",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates poll-for-signature-confirmation requires blocks" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "poll-for-signature-confirmation",
        "signature-value",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates poll-for-signature-confirmation blocks int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "poll-for-signature-confirmation",
        "signature-value",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects min context slot on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--min-context-slot",
        "123",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates send min context slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "send-transaction",
        "--min-context-slot",
        "bogus",
        "signed-raw-transaction",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates account query min context slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "account-info",
        "--min-context-slot",
        "bogus",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates wait-for-balance requires expected lamports" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "wait-for-balance",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand balance with context prints slot and value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":12},\"value\":345},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "balance",
        "--with-context",
        "--commitment",
        "confirmed",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetBalanceRequest(allocator, request_capture.items, "Address11111111111111111111111111111111", "confirmed");
    try std.testing.expectEqualStrings(
        "balance context slot: 12\nbalance for Address11111111111111111111111111111111: 345\n",
        captured,
    );
}

test "runCommand poll-balance prints value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":15},\"value\":678},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "poll-balance",
        "--timeout-ms",
        "1000",
        "--poll-ms",
        "50",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetBalanceRequest(allocator, request_capture.items, "Address11111111111111111111111111111111", null);
    try std.testing.expectEqualStrings(
        "polled balance for Address11111111111111111111111111111111: 678\n",
        captured,
    );
}

test "runCommand latest-blockhash with context prints slot and value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":44},\"value\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"lastValidBlockHeight\":77}},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "latest-blockhash",
        "--with-context",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetLatestBlockhashRequest(allocator, request_capture.items, "confirmed");
    try std.testing.expectEqualStrings(
        "latest blockhash context slot: 44\nLatest blockhash: Blockhash111111111111111111111111111111111111\nLast valid height: 77\n",
        captured,
    );
}

test "runCommand fee-for-message with context prints slot and value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":88},\"value\":5000},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "fee-for-message",
        "--with-context",
        "--commitment",
        "finalized",
        "AQAB",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetFeeForMessageRequest(allocator, request_capture.items, "AQAB", "finalized");
    try std.testing.expectEqualStrings(
        "fee context slot: 88\nfee for message: 5000\n",
        captured,
    );
}

test "runCommand token-account-balance with context prints slot and value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":{"amount":"1234.560000","decimals":6,"uiAmount":12.3456,"uiAmountString":"12.3456"}}, "id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "token-account-balance",
        "--with-context",
        "--commitment",
        "confirmed",
        "TokenAcct1111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetTokenAccountBalanceRequest(allocator, request_capture.items, "TokenAcct1111111111111111111111111111111", "confirmed");
    try std.testing.expectEqualStrings(
        "token account balance context slot: 12\n" ++
            "token account balance for TokenAcct1111111111111111111111111111111: amount=1234.560000 decimals=6 ui_amount=12.3456 ui_amount_string=12.3456\n",
        captured,
    );
}

test "runCommand token-supply with context prints slot and value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":{"amount":"1000000","decimals":9,"uiAmount":1e-3,"uiAmountString":"0.001"}}, "id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "token-supply",
        "--with-context",
        "--commitment",
        "finalized",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetTokenSupplyRequest(allocator, request_capture.items, "Mint111111111111111111111111111111111111", "finalized");
    try std.testing.expectEqualStrings(
        "token supply context slot: 77\n" ++
            "token supply for Mint111111111111111111111111111111111111: amount=1000000 decimals=9 ui_amount=0.001 ui_amount_string=0.001\n",
        captured,
    );
}

test "runCommand token-largest-accounts with context prints slot and entries" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":99},"value":[{"address":"Owner111111111111111111111111111111111111","amount":"100","decimals":2,"uiAmount":1,"uiAmountString":"1"},{"address":"Owner222222222222222222222222222222222222","amount":"200","decimals":2,"uiAmount":2,"uiAmountString":"2"}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "token-largest-accounts",
        "--with-context",
        "--commitment",
        "confirmed",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetTokenLargestAccountsRequest(allocator, request_capture.items, "Mint111111111111111111111111111111111111", "confirmed");
    try std.testing.expect(std.mem.indexOf(u8, captured, "token largest accounts context slot: 99\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "token largest accounts for Mint111111111111111111111111111111111111: 2\n") != null);
    try std.testing.expect(
        std.mem.indexOf(u8, captured, "  [0] address=Owner111111111111111111111111111111111111 amount=100 decimals=2 ui_amount=1 ui_amount_string=1\n") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, captured, "  [1] address=Owner222222222222222222222222222222222222 amount=200 decimals=2 ui_amount=2 ui_amount_string=2\n") != null,
    );
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

test "runCommand block prints summary and raw json" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"previousBlockhash\":\"Prev111111111111111111111111111111111111111\",\"parentSlot\":99,\"blockHeight\":100,\"blockTime\":1700000400,\"transactions\":[{},{}],\"rewards\":[{}]},\"id\":1}";
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
        "100",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 4096);
    defer allocator.free(captured);

    try expectGetBlockRequest(allocator, request_capture.items, 100, null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "block 100: parent_slot=99 block_height=100 block_time=1700000400 transactions=2 rewards=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  blockhash: Blockhash111111111111111111111111111111111111") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  previous_blockhash: Prev111111111111111111111111111111111111111") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  raw: {") != null);
}

test "runCommand transaction prints summary and raw json" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"slot\":55,\"blockTime\":1700000500,\"version\":\"legacy\",\"meta\":{\"err\":{\"InstructionError\":[0,{\"Custom\":1}]},\"fee\":7000,\"logMessages\":[\"a\",\"b\"]},\"transaction\":{\"signatures\":[\"sig-1\",\"sig-2\"]}},\"id\":1}";
    const server_thread = try std.Thread.spawn(.{}, runMockTransactionServer, .{ &listener, allocator, &request_capture, response_body });
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

    const signature_value = "5h6xSignature111111111111111111111111111111111111";
    var parsed = try cli.parseCliArgs(allocator, &.{
        "transaction",
        signature_value,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 4096);
    defer allocator.free(captured);

    try expectGetTransactionRequest(allocator, request_capture.items, signature_value, null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "transaction 5h6xSignature111111111111111111111111111111111111: slot=55 block_time=1700000500 version=legacy signatures=2 fee=7000 log_messages=2 has_error=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  error: {\"InstructionError\":[0,{\"Custom\":1}]}") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  raw: {") != null);
}

test "runCommand status waits for signature status with search history and commitment" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| {
            allocator.free(request);
        }
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":[null]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":78},"value":[{"slot":78,"confirmations":1,"confirmationStatus":"confirmed","err":null}]},"id":2}
        ,
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRequestSequenceServer, .{ &listener, allocator, &request_captures, &response_bodies });
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
        "status",
        "--search-transaction-history",
        "--commitment",
        "confirmed",
        "--timeout-ms",
        "200",
        "--poll-ms",
        "10",
        "Sig111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_captures.items[0],
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        request_captures.items[1],
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try std.testing.expectEqual(@as(usize, 2), request_captures.items.len);
    try std.testing.expectEqualStrings("signature confirmed\n", captured);
}

test "runCommand confirm-transaction respects commitment" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":44},"value":[{"slot":44,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "confirm-transaction",
        "--search-transaction-history",
        "--commitment",
        "confirmed",
        "Sig111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_capture.items,
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try std.testing.expectEqualStrings("signature Sig111111111111111111111111111111111111 confirmed: false\n", captured);
}

test "runCommand signature-status prints status" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":55},"value":[{"slot":55,"confirmations":7,"confirmationStatus":"confirmed","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "signature-status",
        "--commitment",
        "confirmed",
        "Sig111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_capture.items,
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        false,
        "confirmed",
    );
    try std.testing.expectEqualStrings(
        "signature status: has_error=false slot=55 confirmations=7 confirmation=confirmed\n",
        captured,
    );
}

test "runCommand signature-statuses prints per-signature output" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":61},"value":[null,{"slot":61,"confirmations":2,"confirmationStatus":"confirmed","err":null},{"slot":62,"confirmations":4,"confirmationStatus":"processed","err":{"InstructionError":0}}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "signature-statuses",
        "--search-transaction-history",
        "SigA111111111111111111111111111111111111",
        "SigB111111111111111111111111111111111111",
        "SigC111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_capture.items,
        &[_][]const u8{ "SigA111111111111111111111111111111111111", "SigB111111111111111111111111111111111111", "SigC111111111111111111111111111111111111" },
        true,
        null,
    );
    try std.testing.expect(std.mem.indexOf(u8, captured, "signature statuses: 3\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] SigA111111111111111111111111111111111111: not found\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [1] SigB111111111111111111111111111111111111: error=false slot=61 confirmations=2 confirmation=confirmed\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [2] SigC111111111111111111111111111111111111: error=true slot=62 confirmations=4 confirmation=processed\n") != null);
}

test "runCommand poll-for-signature-confirmation polls until min confirmed blocks" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| {
            allocator.free(request);
        }
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":[{"slot":77,"confirmations":1,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":78},"value":[{"slot":78,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":2}
        ,
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRequestSequenceServer, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "poll-for-signature-confirmation",
        "--search-transaction-history",
        "--commitment",
        "confirmed",
        "--timeout-ms",
        "200",
        "--poll-ms",
        "10",
        "Sig111111111111111111111111111111111111",
        "2",
    });
    defer parsed.deinit(allocator);

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_captures.items[0],
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        request_captures.items[1],
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try std.testing.expectEqual(@as(usize, 2), request_captures.items.len);
    try std.testing.expectEqualStrings(
        "signature Sig111111111111111111111111111111111111 reached 2 confirmed blocks (target=2)\n",
        captured,
    );
}

test "runCommand blocks-since-signature-confirmation prints confirmations" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":88},"value":[{"slot":88,"confirmations":9,"confirmationStatus":"finalized","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
    defer server_thread.join();

    const endpoint = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{}", .{port});
    defer allocator.free(endpoint);

    var rpc = try client.RpcClient.init(allocator, endpoint);
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "blocks-since-signature-confirmation",
        "--commitment",
        "confirmed",
        "Sig111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetSignatureStatusesRequest(
        allocator,
        request_capture.items,
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        false,
        "confirmed",
    );
    try std.testing.expectEqualStrings(
        "signature Sig111111111111111111111111111111111111 confirmed blocks: 9\n",
        captured,
    );
}

test "runCommand request-airdrop uses default params" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":"Sig111111111111111111111111111111111111111111111111111111111111111111","id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "request-airdrop",
        "Address11111111111111111111111111111111",
        "9999",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectRequestAirdropRequest(
        allocator,
        request_capture.items,
        "Address11111111111111111111111111111111",
        9999,
        null,
        null,
    );
    try std.testing.expectEqualStrings(
        "airdrop signature: Sig111111111111111111111111111111111111111111111111111111111111111111\n",
        captured,
    );
}

test "runCommand request-airdrop with commitment and recent blockhash passes both" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":"Sig111111111111111111111111111111111111111111111111111111111111111111","id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "request-airdrop",
        "--commitment",
        "confirmed",
        "--airdrop-recent-blockhash",
        "RecentBlockhash11111111111111111111111111",
        "Address11111111111111111111111111111111",
        "9999",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectRequestAirdropRequest(
        allocator,
        request_capture.items,
        "Address11111111111111111111111111111111",
        9999,
        "confirmed",
        "RecentBlockhash11111111111111111111111111",
    );
    try std.testing.expectEqualStrings(
        "airdrop signature: Sig111111111111111111111111111111111111111111111111111111111111111111\n",
        captured,
    );
}

test "runCommand account-data decodes base64 and prints hex" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":15},"value":{"data":["AQID","base64"],"executable":false,"lamports":200,"owner":"Owner1111111111111111111111111111111111","rentEpoch":1,"space":3}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "account-data",
        "--commitment",
        "finalized",
        "--min-context-slot",
        "123",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetAccountInfoRequest(
        allocator,
        request_capture.items,
        "Address11111111111111111111111111111111",
        "getAccountInfo",
        "finalized",
        123,
        "base64",
    );
    try std.testing.expectEqualStrings(
        "account data for Address11111111111111111111111111111111: 3 bytes\n010203\n",
        captured,
    );
}

test "runCommand ui-account prints parsed account details" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":77},"value":{"data":{"program":"system","parsed":{"type":"account"}}, "executable":false,"lamports":111,"owner":"Owner1111111111111111111111111111111111","rentEpoch":3,"space":64}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "ui-account",
        "--with-context",
        "--commitment",
        "confirmed",
        "--min-context-slot",
        "99",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectGetUiAccountRequest(
        allocator,
        request_capture.items,
        "Address11111111111111111111111111111111",
        "confirmed",
        99,
    );
    try std.testing.expect(std.mem.indexOf(u8, captured, "ui account context slot: 77\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "ui account for Address11111111111111111111111111111111: lamports=111 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=3 space=64\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  data(jsonParsed):") != null);
}

test "runCommand multiple-ui-accounts prints parsed entries and not found" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":66},"value":[{"data":{"program":"system","parsed":{"type":"account","info":{}}},"executable":false,"lamports":11,"owner":"Owner1111111111111111111111111111111111","rentEpoch":1,"space":65},null]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "multiple-ui-accounts",
        "--with-context",
        "--commitment",
        "confirmed",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try expectGetMultipleUiAccountsRequest(
        allocator,
        request_capture.items,
        &[_][]const u8{ "Address11111111111111111111111111111111", "Address22222222222222222222222222222222" },
        "confirmed",
        null,
    );
    try std.testing.expect(std.mem.indexOf(u8, captured, "multiple ui accounts context slot: 66\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "multiple ui accounts: 2\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] Address11111111111111111111111111111111: lamports=11 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=1 space=65\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [1] Address22222222222222222222222222222222: not found\n") != null);
}

test "runCommand program-ui-accounts prints ui program accounts" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":55},"value":[{"pubkey":"Acct11111111111111111111111111111111","account":{"data":{"program":"system","parsed":{"type":"account","info":{}}},"executable":false,"lamports":101,"owner":"Owner1111111111111111111111111111111111","rentEpoch":2,"space":128}}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "program-ui-accounts",
        "--with-context",
        "--commitment",
        "confirmed",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try expectGetProgramUiAccountsRequest(
        allocator,
        request_capture.items,
        "Program1111111111111111111111111111111111",
        "confirmed",
        true,
    );
    try std.testing.expect(std.mem.indexOf(u8, captured, "program ui accounts context slot: 55\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "program ui accounts for Program1111111111111111111111111111111111: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] pubkey=Acct11111111111111111111111111111111 lamports=101 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=2 space=128\n") != null);
}

test "runCommand token-account prints parsed account details" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();
    var request_capture = std.ArrayList(u8).empty;
    defer request_capture.deinit(allocator);

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":44},"value":{"data":{"program":"spl-token","parsed":{"type":"account","info":{}}},"executable":false,"lamports":77,"owner":"Owner1111111111111111111111111111111111","rentEpoch":4,"space":165}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockBalanceServer, .{ &listener, allocator, &request_capture, response_body });
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
        "token-account",
        "--min-context-slot",
        "44",
        "TokenAcct1111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try expectGetAccountInfoRequest(
        allocator,
        request_capture.items,
        "TokenAcct1111111111111111111111111111111",
        "getAccountInfo",
        null,
        44,
        "jsonParsed",
    );
    try std.testing.expect(std.mem.indexOf(u8, captured, "token account for TokenAcct1111111111111111111111111111111: lamports=77 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=4 space=165\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  data(jsonParsed): ") != null);
}

test "runCommand validates status options on non-status commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block-commitment requires slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-commitment",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block-commitment slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-commitment",
        "not-a-slot",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "status",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signature-status requires signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signature-status",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates signature-statuses requires at least one signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signature-statuses",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates request-airdrop requires account" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "request-airdrop",
        "Address11111111111111111111111111111111",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects airdrop recent blockhash on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--airdrop-recent-blockhash",
        "RecentBlockhash1111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates minimum-rent-exemption requires bytes" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "minimum-rent-exemption",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates minimum-rent-exemption bytes int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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

test "runCommand validates signatures-for-address min context slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "signatures-for-address",
        "Address11111111111111111111111111111111",
        "--min-context-slot",
        "not-a-number",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects signatures-for-address filters on non-signatures-for-address commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--before",
        "BeforeSig",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects transaction query flags on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--encoding",
        "json",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects epoch flag on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--epoch",
        "42",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects vote account filters on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--vote-pubkey",
        "Vote111111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects largest filter on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--largest-filter",
        "circulating",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects block production filters on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--block-production-identity",
        "Identity1111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects supply exclude list flag on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--exclude-non-circulating-accounts-list",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects program account filters on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--program-data-size",
        "165",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects account query filters on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--account-encoding",
        "base64",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects simulation query filters on unsupported commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--simulation-account",
        "Account11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects simulation account encoding without accounts" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "simulate-transaction",
        "--simulation-account-encoding",
        "base64",
        "signed-raw-transaction",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects incomplete program memcmp filter" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
        "--program-memcmp-offset",
        "32",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects incomplete account data slice filter" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "account-info",
        "Address11111111111111111111111111111111",
        "--account-data-slice-offset",
        "0",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects account data slice with jsonParsed encoding" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "account-info",
        "Address11111111111111111111111111111111",
        "--account-encoding",
        "jsonParsed",
        "--account-data-slice-offset",
        "0",
        "--account-data-slice-length",
        "32",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects incomplete program data slice filter" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
        "--program-data-slice-offset",
        "0",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects block-only flags on transaction command" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "transaction",
        "5h6xSignature111111111111111111111111111111111111",
        "--rewards",
        "true",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates transaction requires signature" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "transaction",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates inflation reward requires address" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "inflation-reward",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates inflation reward epoch int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "inflation-reward",
        "--epoch",
        "not-a-number",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates transaction encoding" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "transaction",
        "5h6xSignature111111111111111111111111111111111111",
        "--encoding",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates simulation account encoding" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "simulate-transaction",
        "--simulation-account",
        "Account11111111111111111111111111111111",
        "--simulation-account-encoding",
        "bogus",
        "signed-raw-transaction",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates simulation min context slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "simulate-transaction",
        "--simulation-min-context-slot",
        "bogus",
        "signed-raw-transaction",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block rewards bool" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "123",
        "--rewards",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates vote account delinquent slot distance int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "vote-accounts",
        "--delinquent-slot-distance",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block production first slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-production",
        "--range-first-slot",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates program account data size int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
        "--program-data-size",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates account query encoding" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "multiple-accounts",
        "--account-encoding",
        "bogus",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand rejects with-context outside supported queries" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "slot",
        "--with-context",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates account query data slice offset int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "account-info",
        "Address11111111111111111111111111111111",
        "--account-data-slice-offset",
        "bogus",
        "--account-data-slice-length",
        "32",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates program account memcmp offset int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
        "--program-memcmp-offset",
        "bogus",
        "--program-memcmp-bytes",
        "abc",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block production last slot int" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-production",
        "--range-first-slot",
        "100",
        "--range-last-slot",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block production last slot requires first slot" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-production",
        "--range-last-slot",
        "200",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates block production slot range ordering" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block-production",
        "--range-first-slot",
        "300",
        "--range-last-slot",
        "200",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates largest accounts filter value" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "largest-accounts",
        "--largest-filter",
        "bogus",
    });
    defer parsed.deinit(allocator);

    try std.testing.expectError(error.InvalidCli, runCommand(allocator, &rpc, &parsed));
}

test "runCommand validates simulate options on non-simulate commands" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
    var rpc = try client.RpcClient.init(allocator, "http://127.0.0.1:1");
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
