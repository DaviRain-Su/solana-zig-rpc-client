const builtin = @import("builtin");
const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");

const Allocator = std.mem.Allocator;
const Ed25519 = std.crypto.sign.Ed25519;
const default_solana_keypair_path = cli.default_solana_keypair_path;
const command_test_support = if (builtin.is_test) @import("command_test_support") else struct {
    const SenderType = struct {};

    pub fn commandCapturedRequest(_: *const SenderType) []const u8 {
        unreachable;
    }

    pub fn commandCapturedRequestAt(_: *const SenderType, _: usize) []const u8 {
        unreachable;
    }

};
const mock_sender_assertions = if (builtin.is_test) @import("mock_sender_assertions") else struct {
    pub fn expectMockSenderLastCapturedRequestMethod(_: *const client.MockSender, _: []const u8) !void {
        unreachable;
    }

    pub fn expectMockSenderRequestCount(_: *const client.MockSender, _: usize) !void {
        unreachable;
    }

    pub fn expectMockSenderScriptSatisfied(_: *const client.MockSender) !void {
        unreachable;
    }
};
const CommandTestSender = if (builtin.is_test) command_test_support.CommandTestSender else command_test_support.SenderType;
const commandCapturedRequest = command_test_support.commandCapturedRequest;
const commandCapturedRequestAt = command_test_support.commandCapturedRequestAt;
const expectMockSenderLastCapturedRequestMethod = mock_sender_assertions.expectMockSenderLastCapturedRequestMethod;
const expectMockSenderRequestCount = mock_sender_assertions.expectMockSenderRequestCount;
const expectMockSenderScriptSatisfied = mock_sender_assertions.expectMockSenderScriptSatisfied;

fn reportInvalidCliMessage(comptime msg: []const u8, args: anytype) void {
    if (!builtin.is_test) {
        std.debug.print(msg, args);
    }
}

fn loadSecretKeyFromKeypairFile(allocator: Allocator, path: []const u8) ![]u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1 << 20);
    defer allocator.free(file_contents);

    const parsed = try std.json.parseFromSlice([]u8, allocator, file_contents, .{});
    defer parsed.deinit();

    if (parsed.value.len != Ed25519.SecretKey.encoded_length) {
        return error.InvalidSecretKeyLength;
    }

    return try allocator.dupe(u8, parsed.value);
}

fn defaultSolanaKeypairPathForHome(allocator: Allocator, home_dir: []const u8) ![]u8 {
    return try std.fs.path.join(allocator, &.{ home_dir, default_solana_keypair_path });
}

fn resolveTransferSenderKeypairPath(
    allocator: Allocator,
    sender_keypair_path_arg: ?[]const u8,
    default_sender_keypair_path_arg: ?[]const u8,
    home_dir: ?[]const u8,
) ![]u8 {
    if (sender_keypair_path_arg) |path| {
        return try expandUserPathForHome(allocator, path, home_dir);
    }

    if (default_sender_keypair_path_arg) |path| {
        return try expandUserPathForHome(allocator, path, home_dir);
    }

    const home = home_dir orelse return error.HomeDirectoryNotFound;
    return try defaultSolanaKeypairPathForHome(allocator, home);
}

fn expandUserPathForHome(allocator: Allocator, path: []const u8, home_dir: ?[]const u8) ![]u8 {
    if (std.mem.eql(u8, path, "~")) {
        const home = home_dir orelse return error.HomeDirectoryNotFound;
        return try allocator.dupe(u8, home);
    }

    if (std.mem.startsWith(u8, path, "~/")) {
        const home = home_dir orelse return error.HomeDirectoryNotFound;
        return try std.fs.path.join(allocator, &.{ home, path[2..] });
    }

    return try allocator.dupe(u8, path);
}

fn resolveTransferSenderSecretKey(
    allocator: Allocator,
    sender_keypair_path_arg: ?[]const u8,
    sender_secret_key_arg: ?[]const u8,
    default_sender_keypair_path_arg: ?[]const u8,
    home_dir: ?[]const u8,
) ![]u8 {
    if (sender_secret_key_arg) |value| {
        return try allocator.dupe(u8, value);
    }

    const keypair_path = try resolveTransferSenderKeypairPath(
        allocator,
        sender_keypair_path_arg,
        default_sender_keypair_path_arg,
        home_dir,
    );
    defer allocator.free(keypair_path);

    const sender_secret_key_bytes = try loadSecretKeyFromKeypairFile(allocator, keypair_path);
    defer allocator.free(sender_secret_key_bytes);

    return try client.encodeBase58(allocator, sender_secret_key_bytes);
}

const InstructionDataEncoding = enum {
    base64,
    hex,
    utf8,
};

const CliInstructionAccountMeta = struct {
    pubkey: []const u8,
    is_signer: bool = false,
    is_writable: bool = false,
};

const CliInstructionSpec = struct {
    program_id: []const u8,
    accounts: []const CliInstructionAccountMeta = &.{},
    data: ?[]const u8 = null,
    data_encoding: InstructionDataEncoding = .base64,
};

const CliAddressLookupTableSpec = struct {
    account_key: []const u8,
    addresses: []const []const u8 = &.{},
};

const CliSimulateInstructionsSpec = struct {
    payer_secret_key: ?[]const u8 = null,
    payer_keypair_path: ?[]const u8 = null,
    additional_signer_secret_keys: []const []const u8 = &.{},
    instructions: []const CliInstructionSpec = &.{},
    address_lookup_tables: []const CliAddressLookupTableSpec = &.{},
    recent_blockhash: ?[]const u8 = null,
};

const LoadedCliInstructionSpec = struct {
    payer: client.Pubkey,
    signers: []client.Keypair,
    owned_instructions: client.OwnedInstructions,
    address_lookup_tables: []client.AddressLookupTableAccount,

    fn deinit(self: *LoadedCliInstructionSpec, allocator: Allocator) void {
        for (self.address_lookup_tables) |table| {
            allocator.free(table.addresses);
        }
        allocator.free(self.address_lookup_tables);
        allocator.free(self.signers);
        self.owned_instructions.deinit(allocator);
        self.* = undefined;
    }
};

fn decodeCliInstructionData(
    allocator: Allocator,
    encoded: ?[]const u8,
    encoding: InstructionDataEncoding,
) ![]u8 {
    const value = encoded orelse return try allocator.alloc(u8, 0);

    return switch (encoding) {
        .utf8 => try allocator.dupe(u8, value),
        .base64 => blk: {
            const decoded_len = try std.base64.standard.Decoder.calcSizeForSlice(value);
            const decoded = try allocator.alloc(u8, decoded_len);
            errdefer allocator.free(decoded);
            try std.base64.standard.Decoder.decode(decoded, value);
            break :blk decoded;
        },
        .hex => blk: {
            const hex_value = if (std.mem.startsWith(u8, value, "0x") or std.mem.startsWith(u8, value, "0X"))
                value[2..]
            else
                value;
            if (hex_value.len % 2 != 0) return error.InvalidHexData;
            const decoded = try allocator.alloc(u8, hex_value.len / 2);
            errdefer allocator.free(decoded);
            _ = try std.fmt.hexToBytes(decoded, hex_value);
            break :blk decoded;
        },
    };
}

fn loadInstructionSpecSource(allocator: Allocator, arg: []const u8) ![]u8 {
    if (!std.mem.startsWith(u8, arg, "@")) {
        return try allocator.dupe(u8, arg);
    }

    const path_arg = arg[1..];
    if (path_arg.len == 0) return error.InvalidCli;

    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
    defer if (home_dir) |value| allocator.free(value);

    const expanded_path = try expandUserPathForHome(allocator, path_arg, home_dir);
    defer allocator.free(expanded_path);

    return try std.fs.cwd().readFileAlloc(allocator, expanded_path, 1 << 20);
}

fn resolveInstructionPayerKeypair(
    allocator: Allocator,
    spec: *const CliSimulateInstructionsSpec,
) !client.Keypair {
    if (spec.payer_secret_key != null and spec.payer_keypair_path != null) {
        return error.InvalidCli;
    }

    if (spec.payer_secret_key) |secret_key| {
        return try client.Keypair.fromBase58SecretKey(allocator, secret_key);
    }

    if (spec.payer_keypair_path) |path| {
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => null,
            else => return err,
        };
        defer if (home_dir) |value| allocator.free(value);

        const expanded_path = try expandUserPathForHome(allocator, path, home_dir);
        defer allocator.free(expanded_path);

        const secret_key_bytes = try loadSecretKeyFromKeypairFile(allocator, expanded_path);
        defer allocator.free(secret_key_bytes);

        return try client.Keypair.fromSecretKeySlice(secret_key_bytes);
    }

    return error.InvalidCli;
}

fn loadCliInstructionSpec(
    allocator: Allocator,
    spec: *const CliSimulateInstructionsSpec,
) !LoadedCliInstructionSpec {
    if (spec.instructions.len == 0) return error.InvalidCli;

    var loaded = LoadedCliInstructionSpec{
        .payer = undefined,
        .signers = undefined,
        .owned_instructions = .{ .instructions = undefined },
        .address_lookup_tables = undefined,
    };
    errdefer loaded.deinit(allocator);

    const payer_keypair = try resolveInstructionPayerKeypair(allocator, spec);
    loaded.payer = payer_keypair.public_key;

    loaded.signers = try allocator.alloc(client.Keypair, 1 + spec.additional_signer_secret_keys.len);
    loaded.signers[0] = payer_keypair;
    for (spec.additional_signer_secret_keys, 0..) |secret_key, index| {
        loaded.signers[index + 1] = try client.Keypair.fromBase58SecretKey(allocator, secret_key);
    }

    const instructions = try allocator.alloc(client.Instruction, spec.instructions.len);
    errdefer {
        for (instructions[0..spec.instructions.len]) |instruction| {
            allocator.free(instruction.accounts);
            allocator.free(instruction.data);
        }
        allocator.free(instructions);
    }

    for (spec.instructions, 0..) |instruction_spec, index| {
        const accounts = try allocator.alloc(client.AccountMeta, instruction_spec.accounts.len);
        errdefer allocator.free(accounts);
        for (instruction_spec.accounts, 0..) |account_spec, account_index| {
            accounts[account_index] = client.AccountMeta.init(
                try client.Pubkey.fromBase58(allocator, account_spec.pubkey),
                account_spec.is_signer,
                account_spec.is_writable,
            );
        }

        instructions[index] = .{
            .program_id = try client.Pubkey.fromBase58(allocator, instruction_spec.program_id),
            .accounts = accounts,
            .data = try decodeCliInstructionData(allocator, instruction_spec.data, instruction_spec.data_encoding),
        };
    }

    loaded.owned_instructions = .{ .instructions = instructions };
    loaded.address_lookup_tables = try allocator.alloc(client.AddressLookupTableAccount, spec.address_lookup_tables.len);
    errdefer allocator.free(loaded.address_lookup_tables);
    for (spec.address_lookup_tables, 0..) |table_spec, index| {
        const addresses = try allocator.alloc(client.Pubkey, table_spec.addresses.len);
        errdefer allocator.free(addresses);
        for (table_spec.addresses, 0..) |address_value, address_index| {
            addresses[address_index] = try client.Pubkey.fromBase58(allocator, address_value);
        }
        loaded.address_lookup_tables[index] = .{
            .account_key = try client.Pubkey.fromBase58(allocator, table_spec.account_key),
            .addresses = addresses,
        };
    }
    return loaded;
}

fn printSimulationResult(simulation: client.SimulatedTransaction) void {
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
}

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
    const instructions_spec_arg = args.instructions_spec_arg;
    const raw_rpc_method_arg = args.raw_rpc_method_arg;
    const raw_rpc_params_arg = args.raw_rpc_params_arg;
    const slot_leaders_limit_arg = args.slot_leaders_limit_arg;
    const performance_limit_arg = args.performance_limit_arg;
    const leader_schedule_slot_arg = args.leader_schedule_slot_arg;
    const leader_schedule_identity_arg = args.leader_schedule_identity_arg;
    const lamports_arg = args.lamports_arg;
    const mint_arg = args.mint_arg;
    const rent_bytes_arg = args.rent_bytes_arg;
    const sender_keypair_path_arg = args.sender_keypair_path_arg;
    const sender_secret_key_arg = args.sender_secret_key_arg;
    const default_sender_keypair_path_arg = args.default_sender_keypair_path;
    const signed_tx_arg = args.signed_tx_arg;
    const simulation_account_encoding_arg = args.simulation_account_encoding_arg;
    const simulation_min_context_slot_arg = args.simulation_min_context_slot_arg;
    const supply_exclude_non_circulating_accounts_list = args.supply_exclude_non_circulating_accounts_list;
    const token_program_id_arg = args.token_program_id_arg;
    const transfer_recent_blockhash_arg = args.transfer_recent_blockhash_arg;
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
    const is_send_command = command == .send_transaction or
        command == .send_transaction_and_confirm or
        command == .send_instructions or
        command == .send_instructions_and_confirm or
        command == .send_versioned_instructions or
        command == .send_versioned_instructions_and_confirm or
        command == .transfer;
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
        reportInvalidCliMessage(
            "error: send options (--skip-preflight, --max-retries, --preflight-commitment) require send-transaction, send-transaction-and-confirm, send-instructions, send-instructions-and-confirm, send-versioned-instructions, send-versioned-instructions-and-confirm, or transfer\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (airdrop_recent_blockhash_arg != null and command != .request_airdrop) {
        reportInvalidCliMessage("error: --airdrop-recent-blockhash requires request-airdrop\n", .{});
        return error.InvalidCli;
    }

    if (transfer_recent_blockhash_arg != null and command != .transfer) {
        reportInvalidCliMessage("error: --transfer-recent-blockhash requires transfer\n", .{});
        return error.InvalidCli;
    }

    if (sender_keypair_path_arg != null and command != .transfer) {
        reportInvalidCliMessage("error: --sender-keypair requires transfer\n", .{});
        return error.InvalidCli;
    }

    if ((timeout_ms_overridden or poll_ms_overridden) and command != .status and command != .poll_balance and command != .wait_for_balance and command != .send_transaction_and_confirm and command != .send_instructions_and_confirm and command != .send_versioned_instructions_and_confirm and command != .poll_for_signature_confirmation and command != .transfer) {
        reportInvalidCliMessage("error: wait options (--timeout-ms, --poll-ms) require status, poll-balance, wait-for-balance, poll-for-signature-confirmation, send-transaction-and-confirm, send-instructions-and-confirm, send-versioned-instructions-and-confirm, or transfer\n", .{});
        return error.InvalidCli;
    }

    if (search_transaction_history and
        command != .status and
        command != .confirm_transaction and
        command != .signature_status and
        command != .signature_statuses and
        command != .blocks_since_signature_confirmation and
        command != .poll_for_signature_confirmation and
        command != .send_transaction_and_confirm and
        command != .send_instructions_and_confirm and
        command != .send_versioned_instructions_and_confirm and
        command != .transfer)
    {
        reportInvalidCliMessage(
            "error: --search-transaction-history requires status, confirm-transaction, signature-status, signature-statuses, blocks-since-signature-confirmation, poll-for-signature-confirmation, send-transaction-and-confirm, send-instructions-and-confirm, send-versioned-instructions-and-confirm, or transfer\n",
            .{},
        );
        return error.InvalidCli;
    }

    if ((signatures_for_address_before_arg != null or signatures_for_address_until_arg != null or signatures_for_address_limit_arg != null) and
        command != .signatures_for_address)
    {
        reportInvalidCliMessage("error: --before, --until, --limit are only supported by signatures-for-address\n", .{});
        return error.InvalidCli;
    }

    if (min_context_slot_arg != null and !is_send_command and command != .signatures_for_address and !is_account_min_context_command) {
        reportInvalidCliMessage(
            "error: --min-context-slot requires send commands, signatures-for-address, or account/program queries\n",
            .{},
        );
        return error.InvalidCli;
    }

    const is_simulate_command = command == .simulate_transaction or command == .simulate_instructions or command == .simulate_versioned_instructions;
    if ((simulate_sig_verify or simulate_replace_recent_blockhash) and !is_simulate_command) {
        reportInvalidCliMessage("error: --sig-verify and --replace-recent-blockhash require simulate-transaction, simulate-instructions, or simulate-versioned-instructions\n", .{});
        return error.InvalidCli;
    }

    if ((simulate_inner_instructions or simulation_account_encoding_arg != null or simulation_min_context_slot_arg != null or simulation_accounts.items.len > 0) and
        !is_simulate_command)
    {
        reportInvalidCliMessage(
            "error: simulation query options require simulate-transaction, simulate-instructions, or simulate-versioned-instructions\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (simulation_account_encoding_arg != null and simulation_accounts.items.len == 0) {
        reportInvalidCliMessage("error: --simulation-account-encoding requires at least one --simulation-account\n", .{});
        return error.InvalidCli;
    }

    const is_token_accounts_command = command == .token_accounts_by_owner or command == .token_accounts_by_delegate;
    if ((mint_arg != null or token_program_id_arg != null) and !is_token_accounts_command) {
        reportInvalidCliMessage("error: --mint and --token-program-id are only supported by token-accounts-by-owner and token-accounts-by-delegate\n", .{});
        return error.InvalidCli;
    }

    if (is_token_accounts_command and mint_arg == null and token_program_id_arg == null) {
        reportInvalidCliMessage("error: token account queries require exactly one filter: --mint or --token-program-id\n", .{});
        return error.InvalidCli;
    }

    if (is_token_accounts_command and mint_arg != null and token_program_id_arg != null) {
        reportInvalidCliMessage("error: token account queries require exactly one filter: --mint or --token-program-id\n", .{});
        return error.InvalidCli;
    }

    const is_transaction_query_command = command == .block or command == .transaction;
    if ((encoding_arg != null or max_supported_transaction_version_arg != null) and !is_transaction_query_command) {
        reportInvalidCliMessage("error: --encoding and --max-supported-transaction-version require block or transaction\n", .{});
        return error.InvalidCli;
    }

    if ((transaction_details_arg != null or rewards_arg != null) and command != .block) {
        reportInvalidCliMessage("error: --transaction-details and --rewards require block\n", .{});
        return error.InvalidCli;
    }

    if (epoch_arg != null and command != .inflation_reward) {
        reportInvalidCliMessage("error: --epoch requires inflation-reward\n", .{});
        return error.InvalidCli;
    }

    if ((vote_pubkey_arg != null or vote_keep_unstaked_delinquents or delinquent_slot_distance_arg != null) and command != .vote_accounts) {
        reportInvalidCliMessage("error: vote account filters require vote-accounts\n", .{});
        return error.InvalidCli;
    }

    if (largest_filter_arg != null and command != .largest_accounts) {
        reportInvalidCliMessage("error: --largest-filter requires largest-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((block_production_identity_arg != null or block_production_first_slot_arg != null or block_production_last_slot_arg != null) and command != .block_production) {
        reportInvalidCliMessage("error: block production filters require block-production\n", .{});
        return error.InvalidCli;
    }

    if (with_context and !is_with_context_command) {
        reportInvalidCliMessage(
            "error: --with-context requires latest-blockhash, balance, fee-for-message, token-account-balance, token-supply, token-largest-accounts, account-info, ui-account, multiple-accounts, multiple-ui-accounts, program-accounts, or program-ui-accounts\n",
            .{},
        );
        return error.InvalidCli;
    }

    if (supply_exclude_non_circulating_accounts_list and command != .supply) {
        reportInvalidCliMessage("error: --exclude-non-circulating-accounts-list requires supply\n", .{});
        return error.InvalidCli;
    }

    const has_program_accounts_filters = program_data_size_arg != null or
        program_memcmp_offset_arg != null or
        program_memcmp_bytes_arg != null or
        program_data_slice_offset_arg != null or
        program_data_slice_length_arg != null or
        program_sort_results;
    if (has_program_accounts_filters and command != .program_accounts and command != .program_ui_accounts) {
        reportInvalidCliMessage("error: program account filters require program-accounts or program-ui-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((program_memcmp_offset_arg == null) != (program_memcmp_bytes_arg == null)) {
        reportInvalidCliMessage("error: --program-memcmp-offset and --program-memcmp-bytes must be used together\n", .{});
        return error.InvalidCli;
    }

    if ((program_data_slice_offset_arg == null) != (program_data_slice_length_arg == null)) {
        reportInvalidCliMessage("error: --program-data-slice-offset and --program-data-slice-length must be used together\n", .{});
        return error.InvalidCli;
    }

    const has_account_query_filters = account_encoding_arg != null or
        account_data_slice_offset_arg != null or
        account_data_slice_length_arg != null;
    if (has_account_query_filters and command != .account_info and command != .multiple_accounts) {
        reportInvalidCliMessage("error: account query filters require account-info or multiple-accounts\n", .{});
        return error.InvalidCli;
    }

    if ((account_data_slice_offset_arg == null) != (account_data_slice_length_arg == null)) {
        reportInvalidCliMessage("error: --account-data-slice-offset and --account-data-slice-length must be used together\n", .{});
        return error.InvalidCli;
    }

    const min_context_slot = if (min_context_slot_arg) |raw|
        std.fmt.parseInt(u64, raw, 10) catch return error.InvalidCli
    else
        null;

    const send_transaction_options = if (send_skip_preflight or send_max_retries != null or send_preflight_commitment != null or min_context_slot != null)
        client.SendTransactionOptions{
            .skip_preflight = send_skip_preflight,
            .preflight_commitment = send_preflight_commitment,
            .max_retries = send_max_retries,
            .min_context_slot = min_context_slot,
        }
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

        .new_latest_blockhash => {
            const blockhash = blockhash_arg orelse {
                reportInvalidCliMessage("error: new-latest-blockhash requires <blockhash>\n", .{});
                return error.InvalidCli;
            };

            const latest = try rpc.getNewLatestBlockhash(blockhash);
            defer allocator.free(latest);

            std.debug.print("Latest blockhash: {s}\n", .{latest});
        },

        .status => {
            const signature_value = signature orelse {
                reportInvalidCliMessage("error: status requires <signature>\n", .{});
                return error.InvalidCli;
            };
            try rpc.waitForSignatureStatus(signature_value, commitment, search_transaction_history, status_timeout_ms, status_poll_ms, false);
            std.debug.print("signature confirmed\n", .{});
        },

        .confirm_transaction => {
            const signature_value = signature orelse {
                reportInvalidCliMessage("error: confirm-transaction requires <signature>\n", .{});
                return error.InvalidCli;
            };
            const confirmed = try rpc.confirmTransaction(signature_value, commitment, search_transaction_history);
            std.debug.print("signature {s} confirmed: {s}\n", .{ signature_value, if (confirmed) "true" else "false" });
        },

        .signature_status => {
            const signature_value = signature orelse {
                reportInvalidCliMessage("error: signature-status requires <signature>\n", .{});
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
                reportInvalidCliMessage("error: signature-statuses requires at least one signature\n", .{});
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
                reportInvalidCliMessage("error: poll-for-signature-confirmation requires <signature> <min-confirmed-blocks>\n", .{});
                return error.InvalidCli;
            };
            const min_confirmed_blocks = if (confirmation_blocks_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else {
                reportInvalidCliMessage("error: poll-for-signature-confirmation requires <signature> <min-confirmed-blocks>\n", .{});
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
                reportInvalidCliMessage("error: blocks-since-signature-confirmation requires <signature>\n", .{});
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
                reportInvalidCliMessage("error: send-transaction requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const tx_signature = try rpc.sendTransaction(tx, send_transaction_options);
            defer allocator.free(tx_signature);

            std.debug.print("signature: {s}\n", .{tx_signature});
        },

        .send_transaction_and_confirm => {
            const tx = signed_tx_arg orelse {
                reportInvalidCliMessage("error: send-transaction-and-confirm requires <signed-tx-base64>\n", .{});
                return error.InvalidCli;
            };

            const tx_signature = try rpc.sendTransactionAndConfirm(
                tx,
                send_transaction_options,
                commitment,
                search_transaction_history,
                status_timeout_ms,
                status_poll_ms,
            );
            defer allocator.free(tx_signature);

            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        },

        .send_instructions => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: send-instructions requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: send-instructions spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: send-instructions spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: send-instructions spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

            const tx_signature = try rpc.sendLegacyInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.signers,
                .{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment orelse send_preflight_commitment else null,
                    .send_transaction_options = send_transaction_options,
                },
            );
            defer allocator.free(tx_signature);

            std.debug.print("signature: {s}\n", .{tx_signature});
        },

        .send_instructions_and_confirm => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: send-instructions-and-confirm requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: send-instructions-and-confirm spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: send-instructions-and-confirm spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: send-instructions-and-confirm spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

            const tx_signature = try rpc.sendAndConfirmLegacyInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.signers,
                .{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment orelse send_preflight_commitment else null,
                    .send_transaction_options = send_transaction_options,
                    .commitment = commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = status_timeout_ms,
                    .poll_interval_ms = status_poll_ms,
                },
            );
            defer allocator.free(tx_signature);

            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        },

        .send_versioned_instructions => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: send-versioned-instructions requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: send-versioned-instructions spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: send-versioned-instructions spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: send-versioned-instructions spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

            const tx_signature = try rpc.sendVersionedInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.address_lookup_tables,
                loaded.signers,
                .{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment orelse send_preflight_commitment else null,
                    .send_transaction_options = send_transaction_options,
                },
            );
            defer allocator.free(tx_signature);

            std.debug.print("signature: {s}\n", .{tx_signature});
        },

        .send_versioned_instructions_and_confirm => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: send-versioned-instructions-and-confirm requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: send-versioned-instructions-and-confirm spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: send-versioned-instructions-and-confirm spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: send-versioned-instructions-and-confirm spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

            const tx_signature = try rpc.sendAndConfirmVersionedInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.address_lookup_tables,
                loaded.signers,
                .{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment orelse send_preflight_commitment else null,
                    .send_transaction_options = send_transaction_options,
                    .commitment = commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = status_timeout_ms,
                    .poll_interval_ms = status_poll_ms,
                },
            );
            defer allocator.free(tx_signature);

            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        },

        .raw_rpc => {
            const method = raw_rpc_method_arg orelse {
                reportInvalidCliMessage("error: raw-rpc requires <method>\n", .{});
                return error.InvalidCli;
            };
            const params_json = raw_rpc_params_arg orelse "[]";

            const parsed_params = std.json.parseFromSlice(std.json.Value, allocator, params_json, .{}) catch {
                reportInvalidCliMessage("error: raw-rpc params must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            parsed_params.deinit();

            const response = try rpc.sendRequest(method, params_json);
            defer allocator.free(response);

            std.debug.print("{s}\n", .{response});
        },

        .transfer => {
            if (sender_secret_key_arg != null and sender_keypair_path_arg != null) {
                reportInvalidCliMessage("error: transfer accepts either --sender-keypair <path> or <sender-secret-key>, not both\n", .{});
                return error.InvalidCli;
            }

            const sender_secret_key = blk: {
                const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
                    error.EnvironmentVariableNotFound => null,
                    else => return err,
                };
                defer if (home_dir) |value| allocator.free(value);

                break :blk resolveTransferSenderSecretKey(
                    allocator,
                    sender_keypair_path_arg,
                    sender_secret_key_arg,
                    default_sender_keypair_path_arg,
                    home_dir,
                ) catch |err| switch (err) {
                    error.FileNotFound => {
                        var missing_path_allocated = true;
                        const missing_path = if (sender_keypair_path_arg) |path|
                            expandUserPathForHome(allocator, path, home_dir) catch return err
                        else if (default_sender_keypair_path_arg) |path|
                            expandUserPathForHome(allocator, path, home_dir) catch return err
                        else if (home_dir) |value|
                            defaultSolanaKeypairPathForHome(allocator, value) catch return err
                        else default_path_blk: {
                            missing_path_allocated = false;
                            break :default_path_blk default_solana_keypair_path;
                        };
                        defer if (missing_path_allocated) allocator.free(missing_path);

                        reportInvalidCliMessage("error: sender keypair file not found: {s}\n", .{missing_path});
                        return error.InvalidCli;
                    },
                    error.HomeDirectoryNotFound => {
                        reportInvalidCliMessage("error: HOME is not set; transfer requires --sender-keypair <path> or <sender-secret-key>\n", .{});
                        return error.InvalidCli;
                    },
                    error.InvalidSecretKeyLength => {
                        reportInvalidCliMessage("error: sender keypair file must contain {} secret-key bytes\n", .{Ed25519.SecretKey.encoded_length});
                        return error.InvalidCli;
                    },
                    else => {
                        if (sender_keypair_path_arg) |path| {
                            reportInvalidCliMessage("error: sender keypair file is not valid JSON byte array: {s}\n", .{path});
                        } else if (default_sender_keypair_path_arg) |path| {
                            reportInvalidCliMessage("error: default sender keypair file is not valid JSON byte array: {s}\n", .{path});
                        } else {
                            reportInvalidCliMessage("error: default sender keypair file is not valid JSON byte array: {s}\n", .{default_solana_keypair_path});
                        }
                        return error.InvalidCli;
                    },
                };
            };
            defer allocator.free(sender_secret_key);

            const destination = account orelse {
                reportInvalidCliMessage("error: transfer requires [--sender-keypair <path> | <sender-secret-key>] <destination> <lamports>\n", .{});
                return error.InvalidCli;
            };
            const lamports = if (lamports_arg) |value|
                std.fmt.parseInt(u64, value, 10) catch return error.InvalidCli
            else {
                reportInvalidCliMessage("error: transfer requires [--sender-keypair <path> | <sender-secret-key>] <destination> <lamports>\n", .{});
                return error.InvalidCli;
            };

            const tx_signature = try rpc.transferWithOptions(
                sender_secret_key,
                destination,
                lamports,
                .{
                    .recent_blockhash = transfer_recent_blockhash_arg,
                    .blockhash_commitment = if (transfer_recent_blockhash_arg == null) commitment orelse send_preflight_commitment else null,
                    .send_transaction_options = send_transaction_options,
                    .commitment = commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = status_timeout_ms,
                    .poll_interval_ms = status_poll_ms,
                },
            );
            defer allocator.free(tx_signature);

            std.debug.print("confirmed transfer signature: {s}\n", .{tx_signature});
        },

        .simulate_transaction => {
            const tx = signed_tx_arg orelse {
                reportInvalidCliMessage("error: simulate-transaction requires <signed-tx-base64>\n", .{});
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

            printSimulationResult(simulation);
        },

        .simulate_instructions => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: simulate-instructions requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: simulate-instructions spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: simulate-instructions spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: simulate-instructions spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

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
            const build_options = if (parsed_spec.value.recent_blockhash != null or commitment != null)
                client.LegacyInstructionsBuildOptions{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment else null,
                }
            else
                null;

            const simulation = try rpc.simulateLegacyInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.signers,
                build_options,
                options,
            );
            defer freeSimulatedTransaction(allocator, simulation);

            printSimulationResult(simulation);
        },

        .simulate_versioned_instructions => {
            const spec_arg = instructions_spec_arg orelse {
                reportInvalidCliMessage("error: simulate-versioned-instructions requires <instruction-spec-json>\n", .{});
                return error.InvalidCli;
            };
            const spec_source = loadInstructionSpecSource(allocator, spec_arg) catch {
                reportInvalidCliMessage("error: simulate-versioned-instructions spec must be valid JSON or @path\n", .{});
                return error.InvalidCli;
            };
            defer allocator.free(spec_source);

            const parsed_spec = std.json.parseFromSlice(CliSimulateInstructionsSpec, allocator, spec_source, .{
                .ignore_unknown_fields = true,
            }) catch {
                reportInvalidCliMessage("error: simulate-versioned-instructions spec must be valid JSON\n", .{});
                return error.InvalidCli;
            };
            defer parsed_spec.deinit();

            var loaded = loadCliInstructionSpec(allocator, &parsed_spec.value) catch {
                reportInvalidCliMessage("error: simulate-versioned-instructions spec is invalid\n", .{});
                return error.InvalidCli;
            };
            defer loaded.deinit(allocator);

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
            const build_options = if (parsed_spec.value.recent_blockhash != null or commitment != null)
                client.VersionedInstructionsBuildOptions{
                    .recent_blockhash = parsed_spec.value.recent_blockhash,
                    .blockhash_commitment = if (parsed_spec.value.recent_blockhash == null) commitment else null,
                }
            else
                null;

            const simulation = try rpc.simulateVersionedInstructionsWithOptions(
                loaded.payer,
                loaded.owned_instructions.instructions,
                loaded.address_lookup_tables,
                loaded.signers,
                build_options,
                options,
            );
            defer freeSimulatedTransaction(allocator, simulation);

            printSimulationResult(simulation);
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
                reportInvalidCliMessage("error: transaction requires <signature>\n", .{});
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
                reportInvalidCliMessage("error: wait-for-balance requires <expected-lamports>\n", .{});
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
                            reportInvalidCliMessage("error: --account-data-slice-* are not supported with --account-encoding jsonParsed\n", .{});
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
                reportInvalidCliMessage("error: multiple-accounts requires at least one account\n", .{});
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
                            reportInvalidCliMessage("error: --account-data-slice-* are not supported with --account-encoding jsonParsed\n", .{});
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
                reportInvalidCliMessage("error: multiple-ui-accounts requires at least one account\n", .{});
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
                reportInvalidCliMessage("error: inflation-reward requires at least one address\n", .{});
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
                reportInvalidCliMessage("error: --range-last-slot requires --range-first-slot\n", .{});
                return error.InvalidCli;
            }
            if (first_slot != null and last_slot != null and last_slot.? < first_slot.?) {
                reportInvalidCliMessage("error: --range-last-slot must be >= --range-first-slot\n", .{});
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

pub fn toClientCommitment(value: ?cli.Commitment) ?client.Commitment {
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

fn writeKeypairJsonFile(allocator: Allocator, path: []const u8, secret_key: []const u8) !void {
    if (std.fs.path.dirname(path)) |parent_path| {
        try std.fs.cwd().makePath(parent_path);
    }

    var keypair_json = std.io.Writer.Allocating.init(allocator);
    defer keypair_json.deinit();
    try keypair_json.writer.print("[", .{});
    for (secret_key, 0..) |byte, index| {
        if (index != 0) try keypair_json.writer.print(",", .{});
        try keypair_json.writer.print("{}", .{byte});
    }
    try keypair_json.writer.print("]", .{});

    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(keypair_json.written());
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

fn expectSendTransferTransactionRequest(
    allocator: Allocator,
    body: []const u8,
    expected_sender_public_key: [Ed25519.PublicKey.encoded_length]u8,
    expected_destination_public_key: [Ed25519.PublicKey.encoded_length]u8,
    expected_recent_blockhash: [32]u8,
    expected_lamports: u64,
    expected_skip_preflight: bool,
    expected_max_retries: ?u32,
    expected_preflight_commitment: ?[]const u8,
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

    try std.testing.expectEqualStrings("sendTransaction", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    const encoded_transaction = switch (params.items[0]) {
        .string => |value| value,
        else => return error.InvalidResponse,
    };

    const options = switch (params.items[1]) {
        .object => |value| value,
        else => return error.InvalidResponse,
    };

    switch (options.get("encoding") orelse return error.InvalidResponse) {
        .string => |value| try std.testing.expectEqualStrings("base64", value),
        else => return error.InvalidResponse,
    }
    switch (options.get("skipPreflight") orelse return error.InvalidResponse) {
        .bool => |value| try std.testing.expectEqual(expected_skip_preflight, value),
        else => return error.InvalidResponse,
    }

    if (expected_max_retries) |value| {
        switch (options.get("maxRetries") orelse return error.InvalidResponse) {
            .integer => |actual| try std.testing.expectEqual(@as(i64, @intCast(value)), actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("maxRetries") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_preflight_commitment) |value| {
        switch (options.get("preflightCommitment") orelse return error.InvalidResponse) {
            .string => |actual| try std.testing.expectEqualStrings(value, actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("preflightCommitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |value| {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .integer => |actual| try std.testing.expectEqual(@as(i64, @intCast(value)), actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    const tx_bytes_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded_transaction);
    const tx_bytes = try allocator.alloc(u8, tx_bytes_len);
    defer allocator.free(tx_bytes);
    try std.base64.standard.Decoder.decode(tx_bytes, encoded_transaction);

    try std.testing.expectEqual(@as(u8, 1), tx_bytes[0]);

    const signature_offset = 1;
    const signature_end = signature_offset + Ed25519.Signature.encoded_length;
    const signature_array: [Ed25519.Signature.encoded_length]u8 = tx_bytes[signature_offset..signature_end][0..Ed25519.Signature.encoded_length].*;
    const signature = Ed25519.Signature.fromBytes(signature_array);
    const message = tx_bytes[signature_end..];
    const sender_public_key = try Ed25519.PublicKey.fromBytes(expected_sender_public_key);
    try Ed25519.Signature.verify(signature, message, sender_public_key);

    try std.testing.expect(std.mem.eql(u8, message[4..36], &expected_sender_public_key));
    try std.testing.expect(std.mem.eql(u8, message[36..68], &expected_destination_public_key));
    try std.testing.expect(std.mem.eql(u8, message[100..132], &expected_recent_blockhash));
    try std.testing.expectEqual(@as(u8, 1), message[132]);
    try std.testing.expectEqual(@as(u8, 2), message[133]);
    try std.testing.expectEqual(@as(u8, 2), message[134]);
    try std.testing.expectEqual(@as(u8, 0), message[135]);
    try std.testing.expectEqual(@as(u8, 1), message[136]);
    try std.testing.expectEqual(@as(u8, 9), message[137]);
    try std.testing.expectEqual(@as(u8, 2), message[138]);
    try std.testing.expectEqual(expected_lamports, std.mem.readInt(u64, message[139..147], .little));
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

fn expectSendVersionedTransactionRequest(
    allocator: Allocator,
    body: []const u8,
    expected_skip_preflight: bool,
    expected_max_retries: ?u32,
    expected_preflight_commitment: ?[]const u8,
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

    try std.testing.expectEqualStrings("sendTransaction", request.method);
    try std.testing.expectEqualStrings("2.0", request.jsonrpc);

    const params = switch (request.params) {
        .array => |value| value,
        else => return error.InvalidResponse,
    };
    try std.testing.expectEqual(@as(usize, 2), params.items.len);

    const encoded_transaction = switch (params.items[0]) {
        .string => |value| value,
        else => return error.InvalidResponse,
    };
    const options = switch (params.items[1]) {
        .object => |value| value,
        else => return error.InvalidResponse,
    };

    switch (options.get("encoding") orelse return error.InvalidResponse) {
        .string => |value| try std.testing.expectEqualStrings("base64", value),
        else => return error.InvalidResponse,
    }
    switch (options.get("skipPreflight") orelse return error.InvalidResponse) {
        .bool => |value| try std.testing.expectEqual(expected_skip_preflight, value),
        else => return error.InvalidResponse,
    }

    if (expected_max_retries) |value| {
        switch (options.get("maxRetries") orelse return error.InvalidResponse) {
            .integer => |actual| try std.testing.expectEqual(@as(i64, @intCast(value)), actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("maxRetries") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_preflight_commitment) |value| {
        switch (options.get("preflightCommitment") orelse return error.InvalidResponse) {
            .string => |actual| try std.testing.expectEqualStrings(value, actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("preflightCommitment") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    if (expected_min_context_slot) |value| {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .integer => |actual| try std.testing.expectEqual(@as(i64, @intCast(value)), actual),
            else => return error.InvalidResponse,
        }
    } else {
        switch (options.get("minContextSlot") orelse return error.InvalidResponse) {
            .null => {},
            else => return error.InvalidResponse,
        }
    }

    const tx_bytes_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded_transaction);
    const tx_bytes = try allocator.alloc(u8, tx_bytes_len);
    defer allocator.free(tx_bytes);
    try std.base64.standard.Decoder.decode(tx_bytes, encoded_transaction);

    try std.testing.expect(tx_bytes.len > 1 + Ed25519.Signature.encoded_length);
    const message = tx_bytes[(1 + Ed25519.Signature.encoded_length)..];
    try std.testing.expect((message[0] & 0x80) == 0x80);
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
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushBalanceResponse(12, 345);
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{
            .endpoint = "command-test://balance",
        },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBalance");
    try expectGetBalanceRequest(allocator, commandCapturedRequest(&sender_context), "Address11111111111111111111111111111111", "confirmed");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "balance context slot: 12\nbalance for Address11111111111111111111111111111111: 345\n",
        captured,
    );
}

test "runCommand poll-balance prints value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushBalanceResponse(15, 678);
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{
            .endpoint = "command-test://poll-balance",
        },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBalance");
    try expectGetBalanceRequest(allocator, commandCapturedRequest(&sender_context), "Address11111111111111111111111111111111", null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "polled balance for Address11111111111111111111111111111111: 678\n",
        captured,
    );
}

test "runCommand latest-blockhash with context prints slot and value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushLatestBlockhashResponse(
        44,
        "Blockhash111111111111111111111111111111111111",
        77,
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://latest-blockhash" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getLatestBlockhash");
    try expectGetLatestBlockhashRequest(allocator, commandCapturedRequest(&sender_context), "confirmed");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "latest blockhash context slot: 44\nLatest blockhash: Blockhash111111111111111111111111111111111111\nLast valid height: 77\n",
        captured,
    );
}

test "runCommand new-latest-blockhash waits for updated value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushLatestBlockhashResponse(
        44,
        "Blockhash111111111111111111111111111111111111",
        77,
    );
    try sender_context.sender.pushLatestBlockhashResponse(
        45,
        "Blockhash222222222222222222222222222222222222",
        88,
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://new-latest-blockhash" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    var parsed = try cli.parseCliArgs(allocator, &.{
        "new-latest-blockhash",
        "Blockhash111111111111111111111111111111111111",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectGetLatestBlockhashRequest(allocator, commandCapturedRequestAt(&sender_context, 0), null);
    try expectGetLatestBlockhashRequest(allocator, commandCapturedRequestAt(&sender_context, 1), null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "Latest blockhash: Blockhash222222222222222222222222222222222222\n",
        captured,
    );
}

test "runCommand fee-for-message with context prints slot and value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushFeeForMessageResponse(88, 5000);
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://fee-for-message" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getFeeForMessage");
    try expectGetFeeForMessageRequest(allocator, commandCapturedRequest(&sender_context), "AQAB", "finalized");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "fee context slot: 88\nfee for message: 5000\n",
        captured,
    );
}

test "runCommand token-account-balance with context prints slot and value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushTokenAmountResponse(12, .{
        .amount = "1234.560000",
        .decimals = 6,
        .ui_amount = 12.3456,
        .ui_amount_string = "12.3456",
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://token-account-balance" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getTokenAccountBalance");
    try expectGetTokenAccountBalanceRequest(allocator, commandCapturedRequest(&sender_context), "TokenAcct1111111111111111111111111111111", "confirmed");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "token account balance context slot: 12\n" ++
            "token account balance for TokenAcct1111111111111111111111111111111: amount=1234.560000 decimals=6 ui_amount=12.3456 ui_amount_string=12.3456\n",
        captured,
    );
}

test "runCommand token-supply with context prints slot and value" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushTokenAmountResponse(77, .{
        .amount = "1000000",
        .decimals = 9,
        .ui_amount = 0.001,
        .ui_amount_string = "0.001",
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://token-supply" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getTokenSupply");
    try expectGetTokenSupplyRequest(allocator, commandCapturedRequest(&sender_context), "Mint111111111111111111111111111111111111", "finalized");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "token supply context slot: 77\n" ++
            "token supply for Mint111111111111111111111111111111111111: amount=1000000 decimals=9 ui_amount=0.001 ui_amount_string=0.001\n",
        captured,
    );
}

test "runCommand token-largest-accounts with context prints slot and entries" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushTokenLargestAccountsResponse(99, &.{
        .{
            .address = "Owner111111111111111111111111111111111111",
            .amount = .{
                .amount = "100",
                .decimals = 2,
                .ui_amount = 1,
                .ui_amount_string = "1",
            },
        },
        .{
            .address = "Owner222222222222222222222222222222222222",
            .amount = .{
                .amount = "200",
                .decimals = 2,
                .ui_amount = 2,
                .ui_amount_string = "2",
            },
        },
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://token-largest-accounts" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getTokenLargestAccounts");
    try expectGetTokenLargestAccountsRequest(allocator, commandCapturedRequest(&sender_context), "Mint111111111111111111111111111111111111", "confirmed");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
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
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("{\"slot\":123,\"blockhash\":\"abc\"}");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-basic" },
    );
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "123",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectGetBlockRequest(allocator, commandCapturedRequest(&sender_context), 123, null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
}

test "runCommand executes block command with commitment and sends getBlock request" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("{\"slot\":456,\"blockhash\":\"abc\"}");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-with-commitment" },
    );
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "456",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectGetBlockRequest(allocator, commandCapturedRequest(&sender_context), 456, "confirmed");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
}

test "runCommand handles block not found" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushNullResult();
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-not-found" },
    );
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "block",
        "789",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectGetBlockRequest(allocator, commandCapturedRequest(&sender_context), 789, null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
}

test "runCommand sends increasing request ids for block calls" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("{\"slot\":111,\"blockhash\":\"abc\"}");
    try sender_context.sender.pushResultJson("{\"slot\":222,\"blockhash\":\"abc\"}");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-request-ids" },
    );
    defer rpc.deinit();

    {
        var parsed_first = try cli.parseCliArgs(allocator, &.{
            "block",
            "111",
        });
        defer parsed_first.deinit(allocator);

        try runCommand(allocator, &rpc, &parsed_first);
        try expectGetBlockRequestWithId(allocator, commandCapturedRequestAt(&sender_context, 0), 1, 111, null);
    }

    {
        var parsed_second = try cli.parseCliArgs(allocator, &.{
            "block",
            "222",
        });
        defer parsed_second.deinit(allocator);

        try runCommand(allocator, &rpc, &parsed_second);
        try expectGetBlockRequestWithId(allocator, commandCapturedRequestAt(&sender_context, 1), 2, 222, null);
    }
    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
}

test "runCommand block not found prints message" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushNullResult();
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-not-found-print" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectGetBlockRequest(allocator, commandCapturedRequest(&sender_context), 789, null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings("block 789: not found\n", captured);
}

test "runCommand block prints summary and raw json" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson(
        "{\"blockhash\":\"Blockhash111111111111111111111111111111111111\",\"previousBlockhash\":\"Prev111111111111111111111111111111111111111\",\"parentSlot\":99,\"blockHeight\":100,\"blockTime\":1700000400,\"transactions\":[{},{}],\"rewards\":[{}]}",
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://block-summary" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getBlock");
    try expectGetBlockRequest(allocator, commandCapturedRequest(&sender_context), 100, null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "block 100: parent_slot=99 block_height=100 block_time=1700000400 transactions=2 rewards=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  blockhash: Blockhash111111111111111111111111111111111111") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  previous_blockhash: Prev111111111111111111111111111111111111111") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  raw: {") != null);
}

test "runCommand transaction prints summary and raw json" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson(
        "{\"slot\":55,\"blockTime\":1700000500,\"version\":\"legacy\",\"meta\":{\"err\":{\"InstructionError\":[0,{\"Custom\":1}]},\"fee\":7000,\"logMessages\":[\"a\",\"b\"]},\"transaction\":{\"signatures\":[\"sig-1\",\"sig-2\"]}}",
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://transaction-summary" },
    );
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

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getTransaction");
    try expectGetTransactionRequest(allocator, commandCapturedRequest(&sender_context), signature_value, null);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "transaction 5h6xSignature111111111111111111111111111111111111: slot=55 block_time=1700000500 version=legacy signatures=2 fee=7000 log_messages=2 has_error=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  error: {\"InstructionError\":[0,{\"Custom\":1}]}") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  raw: {") != null);
}

test "runCommand status waits for signature status with search history and commitment" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSignatureStatusPollResults(&.{
        .{ .context_slot = 77, .status = null },
        .{ .context_slot = 78, .status = .{
            .slot = 78,
            .confirmations = 1,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://status" },
    );
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
        commandCapturedRequestAt(&sender_context, 0),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 1),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings("signature confirmed\n", captured);
}

test "runCommand confirm-transaction respects commitment" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSingleSignatureStatusResult(44, .{
        .slot = 44,
        .confirmations = 1,
        .confirmation_status = "processed",
        .has_error = false,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://confirm-transaction" },
    );
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
        commandCapturedRequest(&sender_context),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings("signature Sig111111111111111111111111111111111111 confirmed: false\n", captured);
}

test "runCommand signature-status prints status" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSingleSignatureStatusResult(55, .{
        .slot = 55,
        .confirmations = 7,
        .confirmation_status = "confirmed",
        .has_error = false,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://signature-status" },
    );
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
        commandCapturedRequest(&sender_context),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        false,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "signature status: has_error=false slot=55 confirmations=7 confirmation=confirmed\n",
        captured,
    );
}

test "runCommand signature-statuses prints per-signature output" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSignatureStatusesResult(61, &.{
        null,
        .{
            .slot = 61,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        },
        .{
            .slot = 62,
            .confirmations = 4,
            .confirmation_status = "processed",
            .has_error = true,
        },
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://signature-statuses" },
    );
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
        commandCapturedRequest(&sender_context),
        &[_][]const u8{ "SigA111111111111111111111111111111111111", "SigB111111111111111111111111111111111111", "SigC111111111111111111111111111111111111" },
        true,
        null,
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "signature statuses: 3\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] SigA111111111111111111111111111111111111: not found\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [1] SigB111111111111111111111111111111111111: error=false slot=61 confirmations=2 confirmation=confirmed\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [2] SigC111111111111111111111111111111111111: error=true slot=62 confirmations=4 confirmation=processed\n") != null);
}

test "runCommand poll-for-signature-confirmation polls until min confirmed blocks" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSignatureStatusPollResults(&.{
        .{ .context_slot = 77, .status = .{
            .slot = 77,
            .confirmations = 1,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
        .{ .context_slot = 78, .status = .{
            .slot = 78,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://poll-signature-confirmation" },
    );
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
        commandCapturedRequestAt(&sender_context, 0),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 1),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        true,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "signature Sig111111111111111111111111111111111111 reached 2 confirmed blocks (target=2)\n",
        captured,
    );
}

test "runCommand blocks-since-signature-confirmation prints confirmations" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSingleSignatureStatusResult(88, .{
        .slot = 88,
        .confirmations = 9,
        .confirmation_status = "finalized",
        .has_error = false,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://blocks-since-signature-confirmation" },
    );
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
        commandCapturedRequest(&sender_context),
        &[_][]const u8{"Sig111111111111111111111111111111111111"},
        false,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "signature Sig111111111111111111111111111111111111 confirmed blocks: 9\n",
        captured,
    );
}

test "commands.expandUserPathForHome expands tilde prefixes" {
    const allocator = std.testing.allocator;

    const expanded_home = try expandUserPathForHome(allocator, "~", "/tmp/test-home");
    defer allocator.free(expanded_home);
    try std.testing.expectEqualStrings("/tmp/test-home", expanded_home);

    const expanded_nested = try expandUserPathForHome(allocator, "~/keys/id.json", "/tmp/test-home");
    defer allocator.free(expanded_nested);
    try std.testing.expectEqualStrings("/tmp/test-home/keys/id.json", expanded_nested);
}

test "commands.resolveTransferSenderSecretKey loads default Solana id.json" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const expected_secret_key = try client.encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(expected_secret_key);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/home", .{tmp.sub_path});
    defer allocator.free(home_path);

    const keypair_path = try std.fs.path.join(allocator, &.{ home_path, default_solana_keypair_path });
    defer allocator.free(keypair_path);
    try writeKeypairJsonFile(allocator, keypair_path, &sender_secret_key);

    const sender_secret_key_base58 = try resolveTransferSenderSecretKey(allocator, null, null, null, home_path);
    defer allocator.free(sender_secret_key_base58);

    try std.testing.expectEqualStrings(expected_secret_key, sender_secret_key_base58);
}

test "commands.resolveTransferSenderSecretKey expands sender keypair tilde path" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{9} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const expected_secret_key = try client.encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(expected_secret_key);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/home", .{tmp.sub_path});
    defer allocator.free(home_path);

    const keypair_path = try std.fs.path.join(allocator, &.{ home_path, "custom", "id.json" });
    defer allocator.free(keypair_path);
    try writeKeypairJsonFile(allocator, keypair_path, &sender_secret_key);

    const sender_secret_key_base58 = try resolveTransferSenderSecretKey(allocator, "~/custom/id.json", null, null, home_path);
    defer allocator.free(sender_secret_key_base58);

    try std.testing.expectEqualStrings(expected_secret_key, sender_secret_key_base58);
}

test "commands.resolveTransferSenderSecretKey loads configured default keypair path" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{11} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const expected_secret_key = try client.encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(expected_secret_key);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/home", .{tmp.sub_path});
    defer allocator.free(home_path);

    const keypair_path = try std.fs.path.join(allocator, &.{ home_path, "custom", "config-id.json" });
    defer allocator.free(keypair_path);
    try writeKeypairJsonFile(allocator, keypair_path, &sender_secret_key);

    const sender_secret_key_base58 = try resolveTransferSenderSecretKey(
        allocator,
        null,
        null,
        "~/custom/config-id.json",
        home_path,
    );
    defer allocator.free(sender_secret_key_base58);

    try std.testing.expectEqualStrings(expected_secret_key, sender_secret_key_base58);
}

test "runCommand transfer fetches blockhash builds transaction and confirms signature" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try client.encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try client.encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushLatestBlockhashSendAndSingleSignatureStatusFlow(
        44,
        recent_blockhash_base58,
        88,
        "Sig444444444444444444444444444444444444444444444444444444444444444444",
        45,
        .{
            .slot = 45,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        },
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{
            .endpoint = "command-test://transfer-flow",
        },
    );
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "transfer",
        "--commitment",
        "confirmed",
        "--search-transaction-history",
        "--skip-preflight",
        "--max-retries",
        "2",
        "--preflight-commitment",
        "confirmed",
        "--min-context-slot",
        "123",
        sender_secret_key_base58,
        destination_base58,
        "5000",
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

    try expectMockSenderRequestCount(&sender_context.sender, 3);
    try expectGetLatestBlockhashRequest(allocator, commandCapturedRequestAt(&sender_context, 0), "confirmed");
    try expectSendTransferTransactionRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 1),
        sender_key_pair.public_key.toBytes(),
        destination_public_key,
        recent_blockhash,
        5_000,
        true,
        2,
        "confirmed",
        123,
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 2),
        &[_][]const u8{"Sig444444444444444444444444444444444444444444444444444444444444444444"},
        true,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 3);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "confirmed transfer signature: Sig444444444444444444444444444444444444444444444444444444444444444444\n",
        captured,
    );
}

test "runCommand transfer accepts sender keypair file" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();

    const keypair_path = try std.fmt.allocPrint(
        allocator,
        ".zig-cache/test-transfer-keypair-{d}.json",
        .{std.time.nanoTimestamp()},
    );
    defer allocator.free(keypair_path);
    defer std.fs.cwd().deleteFile(keypair_path) catch {};
    try writeKeypairJsonFile(allocator, keypair_path, &sender_secret_key);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try client.encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x56} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSendAndSignatureStatusPollFlow(
        "Sig666666666666666666666666666666666666666666666666666666666666666666",
        &.{
            .{ .context_slot = 46, .status = .{
                .slot = 46,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{
            .endpoint = "command-test://transfer-existing-blockhash",
        },
    );
    defer rpc.deinit();

    var parsed = try cli.parseCliArgs(allocator, &.{
        "transfer",
        "--sender-keypair",
        keypair_path,
        "--transfer-recent-blockhash",
        recent_blockhash_base58,
        "--commitment",
        "confirmed",
        destination_base58,
        "5000",
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

    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectSendTransferTransactionRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 0),
        sender_key_pair.public_key.toBytes(),
        destination_public_key,
        recent_blockhash,
        5_000,
        false,
        null,
        null,
        null,
    );
    try expectGetSignatureStatusesRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 1),
        &[_][]const u8{"Sig666666666666666666666666666666666666666666666666666666666666666666"},
        false,
        "confirmed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "confirmed transfer signature: Sig666666666666666666666666666666666666666666666666666666666666666666\n",
        captured,
    );
}

test "runCommand request-airdrop uses default params" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSignatureResult(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://request-airdrop" },
    );
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
        commandCapturedRequest(&sender_context),
        "Address11111111111111111111111111111111",
        9999,
        null,
        null,
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "requestAirdrop");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "airdrop signature: Sig111111111111111111111111111111111111111111111111111111111111111111\n",
        captured,
    );
}

test "runCommand request-airdrop with commitment and recent blockhash passes both" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSignatureResult(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://request-airdrop-config" },
    );
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
        commandCapturedRequest(&sender_context),
        "Address11111111111111111111111111111111",
        9999,
        "confirmed",
        "RecentBlockhash11111111111111111111111111",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "requestAirdrop");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "airdrop signature: Sig111111111111111111111111111111111111111111111111111111111111111111\n",
        captured,
    );
}

test "runCommand account-data decodes base64 and prints hex" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushAccountInfoResponse(15, .{
        .data = "AQID",
        .data_encoding = "base64",
        .executable = false,
        .lamports = 200,
        .owner = "Owner1111111111111111111111111111111111",
        .rent_epoch = 1,
        .space = 3,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://account-data" },
    );
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
        commandCapturedRequest(&sender_context),
        "Address11111111111111111111111111111111",
        "getAccountInfo",
        "finalized",
        123,
        "base64",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getAccountInfo");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "account data for Address11111111111111111111111111111111: 3 bytes\n010203\n",
        captured,
    );
}

test "runCommand raw-rpc prints raw json response" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("{\"value\":123}");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://raw-rpc" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    var parsed = try cli.parseCliArgs(allocator, &.{
        "raw-rpc",
        "customMethod",
        "[\"CustomParam111\"]",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "customMethod");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "CustomParam111") != null);
    try std.testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"result\":{\"value\":123},\"id\":1}\n", captured);
}

test "runCommand raw-rpc defaults params to empty array" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("\"ok\"");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://raw-rpc-default" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    var parsed = try cli.parseCliArgs(allocator, &.{
        "raw-rpc",
        "getHealth",
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getHealth");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"params\":[]") != null);
    try std.testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"result\":\"ok\",\"id\":1}\n", captured);
}

test "runCommand simulate-instructions builds and simulates generic instruction spec" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson(
        \\{"context":{"slot":10},"value":{"accounts":[],"err":null,"fee":120,"unitsConsumed":42,"logs":["Program log: ok"]}}
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://simulate-instructions" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer = try client.Keypair.fromSecretKeyBytes(payer_secret_key);
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const payer_pubkey_base58 = try payer.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination = try client.Keypair.fromSecretKeyBytes(destination_raw.secret_key.toBytes());
    const destination_pubkey_base58 = try destination.public_key.toBase58(allocator);
    defer allocator.free(destination_pubkey_base58);

    var recent_blockhash_bytes: [32]u8 = undefined;
    for (&recent_blockhash_bytes, 0..) |*byte, index| byte.* = @intCast(index + 65);
    const recent_blockhash = try client.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{"payer_secret_key":"{s}","recent_blockhash":"{s}","instructions":[{{"program_id":"11111111111111111111111111111111","accounts":[{{"pubkey":"{s}","is_signer":true,"is_writable":true}},{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],"data":"ping","data_encoding":"utf8"}}]}}
        ,
        .{ payer_secret_key_base58, recent_blockhash, payer_pubkey_base58, destination_pubkey_base58 },
    );
    defer allocator.free(spec_json);
    const spec_path = try std.fmt.allocPrint(
        allocator,
        ".zig-cache/test-simulate-instructions-{d}.json",
        .{std.time.nanoTimestamp()},
    );
    defer allocator.free(spec_path);
    defer std.fs.cwd().deleteFile(spec_path) catch {};
    try std.fs.cwd().writeFile(.{ .sub_path = spec_path, .data = spec_json });
    const spec_arg = try std.fmt.allocPrint(allocator, "@{s}", .{spec_path});
    defer allocator.free(spec_arg);

    var parsed = try cli.parseCliArgs(allocator, &.{
        "simulate-instructions",
        "--sig-verify",
        "--inner-instructions",
        spec_arg,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "simulateTransaction");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"innerInstructions\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "simulation: slot=10 err=null fee=120 units_consumed=42") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "Program log: ok") != null);
}

test "runCommand send-instructions sends generic instruction spec" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson("\"Sig777777777777777777777777777777777777777777777777777777777777777777\"");
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://send-instructions" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer = try client.Keypair.fromSecretKeyBytes(payer_secret_key);
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const payer_pubkey_base58 = try payer.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination = try client.Keypair.fromSecretKeyBytes(destination_raw.secret_key.toBytes());
    const destination_pubkey_base58 = try destination.public_key.toBase58(allocator);
    defer allocator.free(destination_pubkey_base58);

    var recent_blockhash_bytes: [32]u8 = undefined;
    for (&recent_blockhash_bytes, 0..) |*byte, index| byte.* = @intCast(index + 65);
    const recent_blockhash = try client.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{"payer_secret_key":"{s}","recent_blockhash":"{s}","instructions":[{{"program_id":"11111111111111111111111111111111","accounts":[{{"pubkey":"{s}","is_signer":true,"is_writable":true}},{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],"data":"70696e67","data_encoding":"hex"}}]}}
        ,
        .{ payer_secret_key_base58, recent_blockhash, payer_pubkey_base58, destination_pubkey_base58 },
    );
    defer allocator.free(spec_json);

    var parsed = try cli.parseCliArgs(allocator, &.{
        "send-instructions",
        "--skip-preflight",
        "--max-retries",
        "2",
        "--preflight-commitment",
        "confirmed",
        spec_json,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "sendTransaction");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"maxRetries\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, commandCapturedRequest(&sender_context), "\"preflightCommitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings(
        "signature: Sig777777777777777777777777777777777777777777777777777777777777777777\n",
        captured,
    );
}

test "runCommand send-instructions-and-confirm confirms generic instruction spec" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSendAndSignatureStatusPollFlow(
        "Sig888888888888888888888888888888888888888888888888888888888888888888",
        &.{
            .{ .context_slot = 91, .status = .{
                .slot = 91,
                .confirmations = 1,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://send-instructions-and-confirm" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer = try client.Keypair.fromSecretKeyBytes(payer_secret_key);
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const payer_pubkey_base58 = try payer.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination = try client.Keypair.fromSecretKeyBytes(destination_raw.secret_key.toBytes());
    const destination_pubkey_base58 = try destination.public_key.toBase58(allocator);
    defer allocator.free(destination_pubkey_base58);

    var recent_blockhash_bytes: [32]u8 = undefined;
    for (&recent_blockhash_bytes, 0..) |*byte, index| byte.* = @intCast(index + 65);
    const recent_blockhash = try client.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{"payer_secret_key":"{s}","recent_blockhash":"{s}","instructions":[{{"program_id":"11111111111111111111111111111111","accounts":[{{"pubkey":"{s}","is_signer":true,"is_writable":true}},{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],"data":"ping","data_encoding":"utf8"}}]}}
        ,
        .{ payer_secret_key_base58, recent_blockhash, payer_pubkey_base58, destination_pubkey_base58 },
    );
    defer allocator.free(spec_json);

    var parsed = try cli.parseCliArgs(allocator, &.{
        "send-instructions-and-confirm",
        "--commitment",
        "confirmed",
        spec_json,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "confirmed signature: Sig888888888888888888888888888888888888888888888888888888888888888888\n",
        captured,
    );
}

test "runCommand simulate-versioned-instructions simulates with lookup tables" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushResultJson(
        \\{"context":{"slot":12},"value":{"accounts":[],"err":null,"fee":220,"unitsConsumed":99,"logs":["Program log: versioned"]}}
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://simulate-versioned-instructions" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer = try client.Keypair.fromSecretKeyBytes(payer_secret_key);
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const payer_pubkey_base58 = try payer.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);

    const lookup_account_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const lookup_account_bytes = lookup_account_raw.public_key.toBytes();
    const lookup_account_pubkey = try client.encodeBase58(allocator, &lookup_account_bytes);
    defer allocator.free(lookup_account_pubkey);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination = try client.Keypair.fromSecretKeyBytes(destination_raw.secret_key.toBytes());
    const destination_pubkey_base58 = try destination.public_key.toBase58(allocator);
    defer allocator.free(destination_pubkey_base58);

    var recent_blockhash_bytes: [32]u8 = undefined;
    for (&recent_blockhash_bytes, 0..) |*byte, index| byte.* = @intCast(index + 65);
    const recent_blockhash = try client.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{"payer_secret_key":"{s}","recent_blockhash":"{s}","address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],"instructions":[{{"program_id":"11111111111111111111111111111111","accounts":[{{"pubkey":"{s}","is_signer":true,"is_writable":true}},{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],"data":"ping","data_encoding":"utf8"}}]}}
        ,
        .{ payer_secret_key_base58, recent_blockhash, lookup_account_pubkey, destination_pubkey_base58, payer_pubkey_base58, destination_pubkey_base58 },
    );
    defer allocator.free(spec_json);

    var parsed = try cli.parseCliArgs(allocator, &.{
        "simulate-versioned-instructions",
        "--sig-verify",
        spec_json,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "simulateTransaction");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "simulation: slot=12 err=null fee=220 units_consumed=99") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "Program log: versioned") != null);
}

test "runCommand send-versioned-instructions-and-confirm confirms versioned instruction spec" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushSendAndSignatureStatusPollFlow(
        "Sig999999999999999999999999999999999999999999999999999999999999999999",
        &.{
            .{ .context_slot = 93, .status = .{
                .slot = 93,
                .confirmations = 1,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://send-versioned-instructions-and-confirm" },
    );
    defer rpc.deinit();

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer = try client.Keypair.fromSecretKeyBytes(payer_secret_key);
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const payer_pubkey_base58 = try payer.public_key.toBase58(allocator);
    defer allocator.free(payer_pubkey_base58);

    const lookup_account_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const lookup_account_bytes = lookup_account_raw.public_key.toBytes();
    const lookup_account_pubkey = try client.encodeBase58(allocator, &lookup_account_bytes);
    defer allocator.free(lookup_account_pubkey);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination = try client.Keypair.fromSecretKeyBytes(destination_raw.secret_key.toBytes());
    const destination_pubkey_base58 = try destination.public_key.toBase58(allocator);
    defer allocator.free(destination_pubkey_base58);

    var recent_blockhash_bytes: [32]u8 = undefined;
    for (&recent_blockhash_bytes, 0..) |*byte, index| byte.* = @intCast(index + 65);
    const recent_blockhash = try client.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{"payer_secret_key":"{s}","recent_blockhash":"{s}","address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],"instructions":[{{"program_id":"11111111111111111111111111111111","accounts":[{{"pubkey":"{s}","is_signer":true,"is_writable":true}},{{"pubkey":"{s}","is_signer":false,"is_writable":true}}],"data":"70696e67","data_encoding":"hex"}}]}}
        ,
        .{ payer_secret_key_base58, recent_blockhash, lookup_account_pubkey, destination_pubkey_base58, payer_pubkey_base58, destination_pubkey_base58 },
    );
    defer allocator.free(spec_json);

    var parsed = try cli.parseCliArgs(allocator, &.{
        "send-versioned-instructions-and-confirm",
        "--commitment",
        "confirmed",
        "--skip-preflight",
        spec_json,
    });
    defer parsed.deinit(allocator);

    try runCommand(allocator, &rpc, &parsed);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try expectMockSenderRequestCount(&sender_context.sender, 2);
    try expectSendVersionedTransactionRequest(
        allocator,
        commandCapturedRequestAt(&sender_context, 0),
        true,
        null,
        null,
        null,
    );
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getSignatureStatuses");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expectEqualStrings(
        "confirmed signature: Sig999999999999999999999999999999999999999999999999999999999999999999\n",
        captured,
    );
}

test "runCommand ui-account prints parsed account details" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushUiAccountResponse(77, .{
        .data_json = "{\"program\":\"system\",\"parsed\":{\"type\":\"account\"}}",
        .executable = false,
        .lamports = 111,
        .owner = "Owner1111111111111111111111111111111111",
        .rent_epoch = 3,
        .space = 64,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://ui-account" },
    );
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
        commandCapturedRequest(&sender_context),
        "Address11111111111111111111111111111111",
        "confirmed",
        99,
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderLastCapturedRequestMethod(&sender_context.sender, "getAccountInfo");
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "ui account context slot: 77\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "ui account for Address11111111111111111111111111111111: lamports=111 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=3 space=64\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  data(jsonParsed):") != null);
}

test "runCommand multiple-ui-accounts prints parsed entries and not found" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushMultipleUiAccountsResponse(66, &.{
        .{
            .data_json = "{\"program\":\"system\",\"parsed\":{\"type\":\"account\",\"info\":{}}}",
            .executable = false,
            .lamports = 11,
            .owner = "Owner1111111111111111111111111111111111",
            .rent_epoch = 1,
            .space = 65,
        },
        null,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://multiple-ui-accounts" },
    );
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
        commandCapturedRequest(&sender_context),
        &[_][]const u8{ "Address11111111111111111111111111111111", "Address22222222222222222222222222222222" },
        "confirmed",
        null,
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "multiple ui accounts context slot: 66\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "multiple ui accounts: 2\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] Address11111111111111111111111111111111: lamports=11 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=1 space=65\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [1] Address22222222222222222222222222222222: not found\n") != null);
}

test "runCommand program-ui-accounts prints ui program accounts" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushProgramUiAccountsResponse(55, &.{
        .{
            .pubkey = "Acct11111111111111111111111111111111",
            .account = .{
                .data_json = "{\"program\":\"system\",\"parsed\":{\"type\":\"account\",\"info\":{}}}",
                .executable = false,
                .lamports = 101,
                .owner = "Owner1111111111111111111111111111111111",
                .rent_epoch = 2,
                .space = 128,
            },
        },
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://program-ui-accounts" },
    );
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
        commandCapturedRequest(&sender_context),
        "Program1111111111111111111111111111111111",
        "confirmed",
        true,
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
    try std.testing.expect(std.mem.indexOf(u8, captured, "program ui accounts context slot: 55\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "program ui accounts for Program1111111111111111111111111111111111: 1\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, captured, "  [0] pubkey=Acct11111111111111111111111111111111 lamports=101 executable=false owner=Owner1111111111111111111111111111111111 rent_epoch=2 space=128\n") != null);
}

test "runCommand token-account prints parsed account details" {
    const allocator = std.testing.allocator;
    var sender_context = CommandTestSender.init(allocator);
    defer sender_context.deinit();
    try sender_context.sender.pushUiAccountResponse(44, .{
        .data_json = "{\"program\":\"spl-token\",\"parsed\":{\"type\":\"account\",\"info\":{}}}",
        .executable = false,
        .lamports = 77,
        .owner = "Owner1111111111111111111111111111111111",
        .rent_epoch = 4,
        .space = 165,
    });
    var rpc = try client.RpcClient.newWithRequestSenderAndOptions(
        allocator,
        client.RequestSender.fromMockSender(&sender_context.sender),
        .{ .endpoint = "command-test://token-account" },
    );
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
        commandCapturedRequest(&sender_context),
        "TokenAcct1111111111111111111111111111111",
        "getAccountInfo",
        null,
        44,
        "jsonParsed",
    );
    try expectMockSenderRequestCount(&sender_context.sender, 1);
    try expectMockSenderScriptSatisfied(&sender_context.sender);
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
