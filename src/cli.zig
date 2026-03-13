const std = @import("std");
const clap = @import("clap");

const Allocator = std.mem.Allocator;

const ParsedTopLevelCommand = union(enum) {
    help,
    command: Command,
};

comptime {
    @setEvalBranchQuota(20_000);
}

const cli_params = clap.parseParamsComptime(
    \\-h, --help
    \\    --rpc <string>...
    \\    --commitment <commitment>...
    \\    --timeout-ms <u64>...
    \\    --poll-ms <u64>...
    \\    --skip-preflight
    \\    --search-transaction-history
    \\    --json
    \\    --sig-verify
    \\    --replace-recent-blockhash
    \\    --inner-instructions
    \\    --keep-unstaked-delinquents
    \\    --exclude-non-circulating-accounts-list
    \\    --max-retries <u32>...
    \\    --min-context-slot <string>...
    \\    --epoch <string>...
    \\    --encoding <string>...
    \\    --max-supported-transaction-version <string>...
    \\    --transaction-details <string>...
    \\    --rewards <string>...
    \\    --vote-pubkey <string>...
    \\    --delinquent-slot-distance <string>...
    \\    --largest-filter <string>...
    \\    --block-production-identity <string>...
    \\    --range-first-slot <string>...
    \\    --range-last-slot <string>...
    \\    --program-data-size <string>...
    \\    --program-memcmp-offset <string>...
    \\    --program-memcmp-bytes <string>...
    \\    --program-data-slice-offset <string>...
    \\    --program-data-slice-length <string>...
    \\    --with-context
    \\    --sort-results
    \\    --account-encoding <string>...
    \\    --account-data-slice-offset <string>...
    \\    --account-data-slice-length <string>...
    \\    --simulation-account <string>...
    \\    --simulation-account-encoding <string>...
    \\    --simulation-min-context-slot <string>...
    \\    --preflight-commitment <commitment>...
    \\    --airdrop-recent-blockhash <string>...
    \\    --recent-blockhash <string>...
    \\    --sender-keypair <string>...
    \\    --sender-secret-key <string>...
    \\    --additional-signer-secret-key <string>...
    \\    --invoke-mode <string>...
    \\    --no-mode-fallback
    \\    --program-id <string>...
    \\    --data-schema-json <string>...
    \\    --args-json <string>...
    \\    --schema-encoding <string>...
    \\    --idl-args-json <string>...
    \\    --accounts-json <string>...
    \\    --account <string>...
    \\    --remaining-account <string>...
    \\    --remaining-accounts-json <string>...
    \\    --nonce-account <string>...
    \\    --nonce-authority-keypair <string>...
    \\    --transfer-recent-blockhash <string>...
    \\    --before <string>...
    \\    --until <string>...
    \\    --limit <string>...
    \\    --mint <string>...
    \\    --token-program-id <string>...
    \\<command>
    \\<arg>...
    \\
);

const cli_parsers = .{
    .string = clap.parsers.string,
    .commitment = clap.parsers.enumeration(Commitment),
    .u64 = clap.parsers.int(u64, 10),
    .u32 = clap.parsers.int(u32, 10),
    .command = parseTopLevelCommand,
    .arg = clap.parsers.string,
};

const cli_option_help_params = clap.parseParamsComptime(
    \\-h, --help                              Display this help and exit.
    \\    --rpc <url>                         RPC endpoint to use (default: Solana CLI config json_rpc_url or mainnet-beta)
    \\    --commitment <level>                processed|confirmed|finalized (default: Solana CLI config commitment when present)
    \\    --timeout-ms <ms>                   Wait timeout (status, poll/wait balance, poll-for-signature-confirmation, send-transaction-and-confirm)
    \\    --poll-ms <ms>                      Poll interval in ms (status, poll/wait balance, poll-for-signature-confirmation, send-transaction-and-confirm)
    \\    --before <signature>                Filter signatures after this older signature (signatures-for-address)
    \\    --until <signature>                 Stop at this oldest signature (signatures-for-address)
    \\    --limit <count>                     Maximum results to return (signatures-for-address)
    \\    --min-context-slot <slot>           Minimum context slot (send commands, signatures-for-address, account/program queries, or token-account)
    \\    --search-transaction-history        Search transaction history for status and confirmation queries
    \\    --json                             Print invoke, explain, preview, validate, or prepare command output as JSON
    \\    --skip-preflight                    Skip tx preflight checks (send commands)
    \\    --sig-verify                        Verify signatures during simulation (simulate-transaction)
    \\    --replace-recent-blockhash          Replace recent blockhash during simulation
    \\    --inner-instructions                Include inner instructions in simulation results
    \\    --simulation-account <pubkey>       Include account data in simulation results
    \\    --simulation-account-encoding <mode> base58|base64 for simulation account results
    \\    --simulation-min-context-slot <slot> Minimum context slot for simulate-transaction
    \\    --max-retries <count>               Max tx retries before giving up
    \\    --preflight-commitment <level>      Commitment for tx preflight checks
    \\    --airdrop-recent-blockhash <blockhash> Recent blockhash override for request-airdrop
    \\    --sender-keypair <path>             Transfer/program-invoke/idl/send-instructions/simulate-instructions/simulate-program-invoke/simulate-idl-invoke/simulate-versioned-program-invoke/simulate-versioned-idl-invoke payer keypair JSON file (default: Solana CLI config keypair_path or ~/.config/solana/id.json)
    \\    --sender-secret-key <sender-secret-key> Transfer/program-invoke/idl/send-instructions/simulate-instructions/simulate-program-invoke/simulate-idl-invoke/simulate-versioned-program-invoke/simulate-versioned-idl-invoke payer secret key (base58)
    \\    --additional-signer-secret-key <additional-signer-secret-key> Additional signer secret key (base58, repeatable)
    \\    --invoke-mode <mode>               Preferred invocation mode: auto|legacy|versioned (invoke/explain/preview/validate/prepare commands)
    \\    --no-mode-fallback                 Disable automatic legacy/versioned fallback for invoke/explain/preview/validate/prepare commands
    \\    --data-schema-json <json|@path>    Program-invoke instruction data schema JSON (used with --args-json)
    \\    --args-json <json|@path>           Program-invoke instruction args JSON (used with --data-schema-json)
    \\    --schema-encoding <encoding>       Program-invoke schema encoding (currently borsh)
    \\    --transfer-recent-blockhash <blockhash> Recent blockhash override for transfer
    \\    --epoch <epoch>                     Epoch override for inflation-reward
    \\    --encoding <mode>                   json|jsonParsed|base58|base64 (block and transaction)
    \\    --max-supported-transaction-version <n> Max supported tx version (block and transaction)
    \\    --transaction-details <mode>        full|accounts|signatures|none (block)
    \\    --rewards <true|false>              Include rewards in block response
    \\    --vote-pubkey <pubkey>              Filter vote-accounts by vote pubkey
    \\    --keep-unstaked-delinquents         Keep unstaked delinquents in vote-accounts
    \\    --delinquent-slot-distance <n>      Delinquent slot distance for vote-accounts
    \\    --largest-filter <mode>             circulating|non-circulating (largest-accounts)
    \\    --block-production-identity <pubkey> Filter block-production by identity
    \\    --range-first-slot <slot>           First slot for block-production range
    \\    --range-last-slot <slot>            Last slot for block-production range
    \\    --exclude-non-circulating-accounts-list Exclude non-circulating account list from supply
    \\    --program-data-size <bytes>         Filter program-accounts and program-ui-accounts by account data size
    \\    --program-memcmp-offset <offset>    Memcmp offset for program-accounts and program-ui-accounts
    \\    --program-memcmp-bytes <bytes>      Memcmp bytes for program-accounts and program-ui-accounts
    \\    --program-data-slice-offset <offset> Data slice offset for program-accounts and program-ui-accounts
    \\    --program-data-slice-length <length> Data slice length for program-accounts and program-ui-accounts
    \\    --with-context                      Include RPC context in latest-blockhash, balance, fee-for-message, token-account-balance, token-supply, token-largest-accounts, account, and program queries
    \\    --sort-results                      Sort program account results by pubkey locally
    \\    --account-encoding <mode>           base58|base64|jsonParsed for account-info and multiple-accounts
    \\    --account-data-slice-offset <offset> Data slice offset for account-info and multiple-accounts
    \\    --account-data-slice-length <length> Data slice length for account-info and multiple-accounts
    \\    --mint <mint>                       Token account filter by mint (token-accounts-by-*)
    \\    --token-program-id <program-id>     Token account filter by token program (token-accounts-by-*)
);

const instruction_command_positionals_params = clap.parseParamsComptime(
    \\<instruction-spec-json|@path>
    \\<extra>...
    \\
);

const invocation_spec_command_positionals_params = clap.parseParamsComptime(
    \\<invocation-spec-json|@path>
    \\<extra>...
    \\
);

const idl_invoke_command_positionals_params = clap.parseParamsComptime(
    \\<idl-json|@path>
    \\<instruction-name>
    \\<additional-signer-keypair-paths-json|@path>
    \\<address-lookup-tables-json|@path>
    \\<extra>...
    \\
);

const program_invoke_command_positionals_params = clap.parseParamsComptime(
    \\<program-id>
    \\<accounts-json|@path>
    \\<data|@path>
    \\<data-encoding>
    \\<additional-signer-keypair-paths-json|@path>
    \\<address-lookup-tables-json|@path>
    \\<extra>...
    \\
);

const signature_command_positionals_params = clap.parseParamsComptime(
    \\<signature>
    \\<extra>...
    \\
);

const signature_list_command_positionals_params = clap.parseParamsComptime(
    \\<signature>...
    \\
);

const account_command_positionals_params = clap.parseParamsComptime(
    \\<account>
    \\<extra>...
    \\
);

const account_lamports_command_positionals_params = clap.parseParamsComptime(
    \\<account>
    \\<lamports>
    \\<extra>...
    \\
);

const account_expected_balance_command_positionals_params = clap.parseParamsComptime(
    \\<account>
    \\<expected-lamports>
    \\<extra>...
    \\
);

const address_list_command_positionals_params = clap.parseParamsComptime(
    \\<address>...
    \\
);

const blockhash_command_positionals_params = clap.parseParamsComptime(
    \\<blockhash>
    \\<extra>...
    \\
);

const feature_pubkey_command_positionals_params = clap.parseParamsComptime(
    \\<feature-pubkey>
    \\<extra>...
    \\
);

const slot_command_positionals_params = clap.parseParamsComptime(
    \\<slot>
    \\<extra>...
    \\
);

const message_command_positionals_params = clap.parseParamsComptime(
    \\<base64-message>
    \\<extra>...
    \\
);

const bytes_command_positionals_params = clap.parseParamsComptime(
    \\<bytes>
    \\<extra>...
    \\
);

const blocks_command_positionals_params = clap.parseParamsComptime(
    \\<start-slot>
    \\<end-slot>
    \\<extra>...
    \\
);

const slot_limit_command_positionals_params = clap.parseParamsComptime(
    \\<start-slot>
    \\<limit>
    \\<extra>...
    \\
);

const leader_schedule_command_positionals_params = clap.parseParamsComptime(
    \\<slot>
    \\<identity>
    \\<extra>...
    \\
);

const raw_rpc_command_positionals_params = clap.parseParamsComptime(
    \\<method>
    \\<params-json>
    \\<extra>...
    \\
);

const recent_performance_samples_command_positionals_params = clap.parseParamsComptime(
    \\<limit>
    \\<extra>...
    \\
);

const instruction_command_usage_params = clap.parseParamsComptime(
    \\    --sender-keypair <path>
    \\    --sender-secret-key <sender-secret-key>
    \\    --recent-blockhash <base58>
    \\<instruction-spec-json|@path>
    \\
);

const program_invoke_command_usage_params = clap.parseParamsComptime(
    \\    --sender-keypair <path>
    \\    --sender-secret-key <sender-secret-key>
    \\    --recent-blockhash <base58>
    \\    --nonce-account <pubkey>
    \\    --nonce-authority-keypair <path>
    \\    --data-schema-json <json|@path>
    \\    --args-json <json|@path>
    \\    --schema-encoding <encoding>
    \\<program-id>
    \\<accounts-json|@path>
    \\
);

const idl_invoke_command_usage_params = clap.parseParamsComptime(
    \\    --sender-keypair <path>
    \\    --sender-secret-key <sender-secret-key>
    \\    --recent-blockhash <base58>
    \\    --program-id <pubkey>
    \\    --nonce-account <pubkey>
    \\    --nonce-authority-keypair <path>
    \\    --idl-args-json <json|@path>
    \\    --accounts-json <json|@path>
    \\    --account <name=pubkey>...
    \\    --remaining-account <pubkey[,is_signer,is_writable]>...
    \\    --remaining-accounts-json <json|@path>
    \\<idl-json|@path>
    \\<instruction-name>
    \\
);

const signed_transaction_command_positionals_params = clap.parseParamsComptime(
    \\<signed-tx-base64>
    \\<extra>...
    \\
);

const signatures_for_address_command_positionals_params = clap.parseParamsComptime(
    \\<address>
    \\<extra>...
    \\
);

const poll_for_signature_confirmation_command_positionals_params = clap.parseParamsComptime(
    \\<signature>
    \\<min-confirmed-blocks>
    \\<extra>...
    \\
);

const transfer_with_default_sender_command_positionals_params = clap.parseParamsComptime(
    \\<sender-secret-key>
    \\<destination>
    \\<lamports>
    \\<extra>...
    \\
);

const transfer_with_explicit_sender_command_positionals_params = clap.parseParamsComptime(
    \\<destination>
    \\<lamports>
    \\<extra>...
    \\
);

const positional_only_parsers = .{
    .string = clap.parsers.string,
    .@"instruction-spec-json|@path" = clap.parsers.string,
    .extra = clap.parsers.string,
    .@"idl-json|@path" = clap.parsers.string,
    .@"instruction-name" = clap.parsers.string,
    .@"additional-signer-keypair-paths-json|@path" = clap.parsers.string,
    .@"address-lookup-tables-json|@path" = clap.parsers.string,
    .@"program-id" = clap.parsers.string,
    .@"accounts-json|@path" = clap.parsers.string,
    .@"data|@path" = clap.parsers.string,
    .@"data-encoding" = clap.parsers.string,
    .signature = clap.parsers.string,
    .account = clap.parsers.string,
    .lamports = clap.parsers.string,
    .@"expected-lamports" = clap.parsers.string,
    .address = clap.parsers.string,
    .blockhash = clap.parsers.string,
    .@"feature-pubkey" = clap.parsers.string,
    .slot = clap.parsers.string,
    .@"base64-message" = clap.parsers.string,
    .bytes = clap.parsers.string,
    .@"start-slot" = clap.parsers.string,
    .@"end-slot" = clap.parsers.string,
    .limit = clap.parsers.string,
    .method = clap.parsers.string,
    .@"params-json" = clap.parsers.string,
    .identity = clap.parsers.string,
    .@"signed-tx-base64" = clap.parsers.string,
    .@"min-confirmed-blocks" = clap.parsers.string,
    .destination = clap.parsers.string,
    .@"sender-secret-key" = clap.parsers.string,
};

pub const default_solana_rpc_url = "https://api.mainnet-beta.solana.com";
pub const default_solana_cli_config_path = ".config/solana/cli/config.yml";
pub const default_solana_keypair_path = ".config/solana/id.json";
const usage_command_line_prefix = "  solana_client_zig [--rpc <url>] ";

pub const Commitment = enum {
    processed,
    confirmed,
    finalized,
};

pub const SolanaCliConfig = struct {
    path: ?[]u8 = null,
    json_rpc_url: ?[]u8 = null,
    websocket_url: ?[]u8 = null,
    keypair_path: ?[]u8 = null,
    commitment: ?Commitment = null,

    pub fn deinit(self: *SolanaCliConfig, allocator: Allocator) void {
        if (self.path) |value| allocator.free(value);
        if (self.json_rpc_url) |value| allocator.free(value);
        if (self.websocket_url) |value| allocator.free(value);
        if (self.keypair_path) |value| allocator.free(value);
        self.* = .{};
    }
};

pub const SolanaCliConfigLoadOptions = struct {
    home_dir: ?[]const u8 = null,
    config_path_override: ?[]const u8 = null,
};

const signature_command_usage_params = clap.parseParamsComptime(
    \\<signature>
    \\
);

const signature_statuses_command_usage_params = clap.parseParamsComptime(
    \\<signature-1>
    \\
);

const account_command_usage_params = clap.parseParamsComptime(
    \\<account>
    \\
);

const start_slot_command_usage_params = clap.parseParamsComptime(
    \\<start-slot>
    \\
);

const account_lamports_command_usage_params = clap.parseParamsComptime(
    \\<account>
    \\<lamports>
    \\
);

const account_expected_balance_command_usage_params = clap.parseParamsComptime(
    \\<account>
    \\<expected-lamports>
    \\
);

const signed_transaction_command_usage_params = clap.parseParamsComptime(
    \\<signed-tx-base64>
    \\
);

const blockhash_command_usage_params = clap.parseParamsComptime(
    \\<blockhash>
    \\
);

const feature_pubkey_command_usage_params = clap.parseParamsComptime(
    \\<feature-pubkey>
    \\
);

const slot_command_usage_params = clap.parseParamsComptime(
    \\<slot>
    \\
);

const start_slot_limit_command_usage_params = clap.parseParamsComptime(
    \\<start-slot>
    \\<limit>
    \\
);

const poll_for_signature_confirmation_command_usage_params = clap.parseParamsComptime(
    \\<signature>
    \\<min-confirmed-blocks>
    \\
);

const message_command_usage_params = clap.parseParamsComptime(
    \\<base64-message>
    \\
);

const bytes_command_usage_params = clap.parseParamsComptime(
    \\<bytes>
    \\
);

const raw_rpc_command_usage_params = clap.parseParamsComptime(
    \\<method>
    \\
);

const account_list_command_usage_params = clap.parseParamsComptime(
    \\<account-1>
    \\
);

const program_id_command_usage_params = clap.parseParamsComptime(
    \\<program-id>
    \\
);

const address_command_usage_params = clap.parseParamsComptime(
    \\<address>
    \\
);

const token_account_command_usage_params = clap.parseParamsComptime(
    \\<token-account>
    \\
);

const mint_command_usage_params = clap.parseParamsComptime(
    \\<mint>
    \\
);

const owner_command_usage_params = clap.parseParamsComptime(
    \\<owner>
    \\
);

const delegate_command_usage_params = clap.parseParamsComptime(
    \\<delegate>
    \\
);

const inflation_reward_command_usage_params = clap.parseParamsComptime(
    \\<address-1>
    \\
);

const signatures_for_address_usage_option_params = clap.parseParamsComptime(
    \\    --before <signature>
    \\    --until <signature>
    \\    --limit <count>
    \\
);

const inflation_reward_usage_option_params = clap.parseParamsComptime(
    \\    --epoch <epoch>
    \\
);

pub fn printUsage(out: *std.Io.Writer) !void {
    try out.writeAll("Quick usage:\n  solana_client_zig ");
    try clap.usage(out, clap.Help, &cli_params);
    try out.writeAll("\n\nUsage:\n");

    try writeCommandUsageSection(out);
    try out.writeAll("\nOptional flags:\n");
    try clap.help(out, clap.Help, &cli_option_help_params, .{});
}

pub fn printCommandUsage(out: *std.Io.Writer, command: Command) !void {
    try out.writeAll("Usage:\n");
    try writeCommandUsageEntry(out, commandUsageEntry(command));
    try out.writeAll("\nOptional flags:\n");
    try clap.help(out, clap.Help, &cli_option_help_params, .{});
}

pub fn printUsageToFile(file: std.fs.File) !void {
    var buf: [2048]u8 = undefined;
    var writer = file.writer(&buf);
    try printUsage(&writer.interface);
    try writer.interface.flush();
}

pub fn printCommandUsageToFile(file: std.fs.File, command: Command) !void {
    var buf: [2048]u8 = undefined;
    var writer = file.writer(&buf);
    try printCommandUsage(&writer.interface, command);
    try writer.interface.flush();
}

pub fn parseCommitment(value: []const u8) ?Commitment {
    if (std.mem.eql(u8, value, "processed")) return .processed;
    if (std.mem.eql(u8, value, "confirmed")) return .confirmed;
    if (std.mem.eql(u8, value, "finalized")) return .finalized;
    return null;
}

fn writeCommandName(out: *std.Io.Writer, command: Command) !void {
    for (@tagName(command)) |char| {
        try out.writeByte(if (char == '_') '-' else char);
    }
}

fn commandNameEql(arg: []const u8, command: Command) bool {
    const tag_name = @tagName(command);
    if (arg.len != tag_name.len) return false;

    for (tag_name, arg) |expected_char, actual_char| {
        if ((if (expected_char == '_') '-' else expected_char) != actual_char) return false;
    }

    return true;
}

fn writeCommandUsageLine(out: *std.Io.Writer, command: Command, comptime params: []const clap.Param(clap.Help), suffix: ?[]const u8) !void {
    try out.writeAll(usage_command_line_prefix);
    try writeCommandName(out, command);
    try out.writeAll(" ");
    try clap.usage(out, clap.Help, params);
    if (suffix) |value| try out.writeAll(value);
    try out.writeByte('\n');
}

fn writeCommandUsageLineWithOptionSuffix(
    out: *std.Io.Writer,
    command: Command,
    comptime positional_params: []const clap.Param(clap.Help),
    positional_suffix: ?[]const u8,
    comptime option_params: []const clap.Param(clap.Help),
) !void {
    try out.writeAll(usage_command_line_prefix);
    try writeCommandName(out, command);
    try out.writeAll(" ");
    try clap.usage(out, clap.Help, positional_params);
    if (positional_suffix) |value| try out.writeAll(value);
    if (option_params.len != 0) {
        try out.writeAll(" ");
        try clap.usage(out, clap.Help, option_params);
    }
    try out.writeByte('\n');
}

fn writeCommandUsageLiteralSuffix(out: *std.Io.Writer, command: Command, suffix: ?[]const u8) !void {
    try out.writeAll(usage_command_line_prefix);
    try writeCommandName(out, command);
    if (suffix) |value| {
        if (value.len != 0) {
            try out.writeAll(" ");
            try out.writeAll(value);
        }
    }
    try out.writeByte('\n');
}

const CommandUsageStyle = enum {
    literal,
    signature,
    signature_list,
    signed_transaction,
    instruction,
    invocation_spec,
    program_invoke,
    idl_invoke,
    raw_rpc,
    account,
    account_expected_balance,
    account_lamports,
    account_list,
    program_id,
    token_account,
    mint,
    owner_token_accounts,
    delegate_token_accounts,
    address_history,
    inflation_reward,
    poll_for_signature_confirmation,
    bytes,
    blockhash,
    feature_pubkey,
    slot,
    base64_message,
    start_slot_limit,
    start_slot,
};

const CommandPositionalStyle = enum {
    instruction,
    idl_invoke_legacy,
    idl_invoke_versioned,
    program_invoke_legacy,
    program_invoke_versioned,
    transfer,
    signature,
    signature_list,
    signatures_for_address,
    poll_for_signature_confirmation,
    signed_transaction,
    raw_rpc,
    account,
    account_expected_balance,
    account_lamports,
    address_list,
    bytes,
    blockhash,
    feature_pubkey,
    slot,
    message,
    recent_performance_samples,
    blocks,
    start_slot_limit,
    leader_schedule,
};

const CommandUsageEntry = struct {
    command: Command,
    style: CommandUsageStyle,
    suffix: ?[]const u8 = null,
    parse_style: ?CommandPositionalStyle = null,
};

const command_usage_entries = [_]CommandUsageEntry{
    .{ .command = .latest_blockhash, .style = .literal },
    .{ .command = .new_latest_blockhash, .style = .blockhash, .parse_style = .blockhash },
    .{ .command = .status, .style = .signature, .parse_style = .signature },
    .{ .command = .confirm_transaction, .style = .signature, .parse_style = .signature },
    .{ .command = .signature_status, .style = .signature, .parse_style = .signature },
    .{ .command = .signature_statuses, .style = .signature_list, .suffix = " [signature-2 ...]", .parse_style = .signature_list },
    .{ .command = .send_transaction, .style = .signed_transaction, .parse_style = .signed_transaction },
    .{ .command = .send_transaction_and_confirm, .style = .signed_transaction, .parse_style = .signed_transaction },
    .{ .command = .send_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .send_instructions_and_confirm, .style = .instruction, .parse_style = .instruction },
    .{ .command = .send_versioned_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .send_versioned_instructions_and_confirm, .style = .instruction, .parse_style = .instruction },
    .{ .command = .invoke_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .invoke_instructions_and_confirm, .style = .instruction, .parse_style = .instruction },
    .{ .command = .invoke_instructions_simulate, .style = .instruction, .parse_style = .instruction },
    .{ .command = .preview_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .explain_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .validate_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .prepare_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .estimate_instructions_fee, .style = .instruction, .parse_style = .instruction },
    .{ .command = .spec_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .invoke_spec, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .invoke_spec_and_confirm, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .invoke_spec_simulate, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .preview_spec, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .explain_spec, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .validate_spec, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .prepare_spec, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .estimate_spec_fee, .style = .invocation_spec, .parse_style = .instruction },
    .{ .command = .send_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]", .parse_style = .program_invoke_legacy },
    .{ .command = .send_program_invoke_and_confirm, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]", .parse_style = .program_invoke_legacy },
    .{ .command = .send_versioned_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .send_versioned_program_invoke_and_confirm, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .invoke_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .invoke_program_invoke_and_confirm, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .invoke_program_invoke_simulate, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .preview_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .explain_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .validate_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .prepare_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .estimate_program_invoke_fee, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .spec_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .transfer, .style = .literal, .suffix = "[--sender-keypair <path> | <sender-secret-key>] <destination> <lamports>", .parse_style = .transfer },
    .{ .command = .simulate_transaction, .style = .signed_transaction, .parse_style = .signed_transaction },
    .{ .command = .simulate_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .simulate_versioned_instructions, .style = .instruction, .parse_style = .instruction },
    .{ .command = .simulate_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]", .parse_style = .program_invoke_legacy },
    .{ .command = .simulate_versioned_program_invoke, .style = .program_invoke, .suffix = " [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .program_invoke_versioned },
    .{ .command = .simulate_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path]", .parse_style = .idl_invoke_legacy },
    .{ .command = .simulate_versioned_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .send_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path]", .parse_style = .idl_invoke_legacy },
    .{ .command = .send_idl_invoke_and_confirm, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path]", .parse_style = .idl_invoke_legacy },
    .{ .command = .send_versioned_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .send_versioned_idl_invoke_and_confirm, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .invoke_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .invoke_idl_invoke_and_confirm, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .invoke_idl_invoke_simulate, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .preview_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .explain_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .validate_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .prepare_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .estimate_idl_invoke_fee, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .spec_idl_invoke, .style = .idl_invoke, .suffix = " [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]", .parse_style = .idl_invoke_versioned },
    .{ .command = .raw_rpc, .style = .raw_rpc, .suffix = " [params-json]", .parse_style = .raw_rpc },
    .{ .command = .slot, .style = .literal },
    .{ .command = .block_height, .style = .literal },
    .{ .command = .transaction_count, .style = .literal },
    .{ .command = .transaction, .style = .signature, .parse_style = .signature },
    .{ .command = .balance, .style = .account, .parse_style = .account },
    .{ .command = .poll_balance, .style = .account, .parse_style = .account },
    .{ .command = .wait_for_balance, .style = .account_expected_balance, .parse_style = .account_expected_balance },
    .{ .command = .account_info, .style = .account, .parse_style = .account },
    .{ .command = .account_data, .style = .account, .parse_style = .account },
    .{ .command = .ui_account, .style = .account, .parse_style = .account },
    .{ .command = .multiple_accounts, .style = .account_list, .suffix = " [account-2 ...]", .parse_style = .address_list },
    .{ .command = .multiple_ui_accounts, .style = .account_list, .suffix = " [account-2 ...]", .parse_style = .address_list },
    .{ .command = .program_accounts, .style = .program_id, .parse_style = .account },
    .{ .command = .program_ui_accounts, .style = .program_id, .parse_style = .account },
    .{ .command = .request_airdrop, .style = .account_lamports, .parse_style = .account_lamports },
    .{ .command = .minimum_rent_exemption, .style = .bytes, .parse_style = .bytes },
    .{ .command = .version, .style = .literal },
    .{ .command = .epoch_info, .style = .literal },
    .{ .command = .health, .style = .literal },
    .{ .command = .genesis_hash, .style = .literal },
    .{ .command = .inflation_reward, .style = .inflation_reward, .suffix = " [address-2 ...]", .parse_style = .address_list },
    .{ .command = .supply, .style = .literal },
    .{ .command = .epoch_schedule, .style = .literal },
    .{ .command = .inflation_rate, .style = .literal },
    .{ .command = .block_time, .style = .slot, .parse_style = .slot },
    .{ .command = .block_commitment, .style = .slot, .parse_style = .slot },
    .{ .command = .block, .style = .slot, .parse_style = .slot },
    .{ .command = .blocks_with_limit, .style = .start_slot_limit, .parse_style = .start_slot_limit },
    .{ .command = .poll_for_signature_confirmation, .style = .poll_for_signature_confirmation, .parse_style = .poll_for_signature_confirmation },
    .{ .command = .blocks_since_signature_confirmation, .style = .signature, .parse_style = .signature },
    .{ .command = .signatures_for_address, .style = .address_history, .parse_style = .signatures_for_address },
    .{ .command = .feature_activation_slot, .style = .feature_pubkey, .parse_style = .feature_pubkey },
    .{ .command = .stake_minimum_delegation, .style = .literal },
    .{ .command = .largest_accounts, .style = .literal },
    .{ .command = .token_account_balance, .style = .token_account, .parse_style = .account },
    .{ .command = .token_account, .style = .token_account, .parse_style = .account },
    .{ .command = .token_supply, .style = .mint, .parse_style = .account },
    .{ .command = .token_largest_accounts, .style = .mint, .parse_style = .account },
    .{ .command = .token_accounts_by_owner, .style = .owner_token_accounts, .suffix = " (--mint <mint> | --token-program-id <program-id>)", .parse_style = .account },
    .{ .command = .token_accounts_by_delegate, .style = .delegate_token_accounts, .suffix = " (--mint <mint> | --token-program-id <program-id>)", .parse_style = .account },
    .{ .command = .fee_for_message, .style = .base64_message, .parse_style = .message },
    .{ .command = .recent_performance_samples, .style = .literal, .suffix = "[limit]", .parse_style = .recent_performance_samples },
    .{ .command = .highest_snapshot_slot, .style = .literal },
    .{ .command = .blocks, .style = .start_slot, .suffix = " [end-slot]", .parse_style = .blocks },
    .{ .command = .slot_leader, .style = .literal },
    .{ .command = .slot_leaders, .style = .start_slot_limit, .parse_style = .start_slot_limit },
    .{ .command = .recent_prioritization_fees, .style = .literal, .suffix = "[account-1 ...]", .parse_style = .address_list },
    .{ .command = .cluster_nodes, .style = .literal },
    .{ .command = .leader_schedule, .style = .literal, .suffix = "[slot] [identity]", .parse_style = .leader_schedule },
    .{ .command = .identity, .style = .literal },
    .{ .command = .vote_accounts, .style = .literal },
    .{ .command = .block_production, .style = .literal },
    .{ .command = .inflation_governor, .style = .literal },
    .{ .command = .minimum_ledger_slot, .style = .literal },
    .{ .command = .max_retransmit_slot, .style = .literal },
    .{ .command = .max_shred_insert_slot, .style = .literal },
    .{ .command = .first_available_block, .style = .literal },
    .{ .command = .blockhash_valid, .style = .blockhash, .parse_style = .blockhash },
};

fn writeCommandUsageEntry(out: *std.Io.Writer, entry: CommandUsageEntry) !void {
    switch (entry.style) {
        .literal => try writeCommandUsageLiteralSuffix(out, entry.command, entry.suffix),
        .signature => try writeCommandUsageLine(out, entry.command, &signature_command_usage_params, entry.suffix),
        .signature_list => try writeCommandUsageLine(out, entry.command, &signature_statuses_command_usage_params, entry.suffix),
        .signed_transaction => try writeCommandUsageLine(out, entry.command, &signed_transaction_command_usage_params, entry.suffix),
        .instruction => try writeCommandUsageLine(out, entry.command, &instruction_command_usage_params, entry.suffix),
        .invocation_spec => try writeCommandUsageLine(out, entry.command, &invocation_spec_command_positionals_params, entry.suffix),
        .program_invoke => try writeCommandUsageLine(out, entry.command, &program_invoke_command_usage_params, entry.suffix),
        .idl_invoke => try writeCommandUsageLine(out, entry.command, &idl_invoke_command_usage_params, entry.suffix),
        .raw_rpc => try writeCommandUsageLine(out, entry.command, &raw_rpc_command_usage_params, entry.suffix),
        .account => try writeCommandUsageLine(out, entry.command, &account_command_usage_params, entry.suffix),
        .account_expected_balance => try writeCommandUsageLine(out, entry.command, &account_expected_balance_command_usage_params, entry.suffix),
        .account_lamports => try writeCommandUsageLine(out, entry.command, &account_lamports_command_usage_params, entry.suffix),
        .account_list => try writeCommandUsageLine(out, entry.command, &account_list_command_usage_params, entry.suffix),
        .program_id => try writeCommandUsageLine(out, entry.command, &program_id_command_usage_params, entry.suffix),
        .token_account => try writeCommandUsageLine(out, entry.command, &token_account_command_usage_params, entry.suffix),
        .mint => try writeCommandUsageLine(out, entry.command, &mint_command_usage_params, entry.suffix),
        .owner_token_accounts => try writeCommandUsageLine(out, entry.command, &owner_command_usage_params, entry.suffix),
        .delegate_token_accounts => try writeCommandUsageLine(out, entry.command, &delegate_command_usage_params, entry.suffix),
        .address_history => try writeCommandUsageLineWithOptionSuffix(out, entry.command, &address_command_usage_params, entry.suffix, &signatures_for_address_usage_option_params),
        .inflation_reward => try writeCommandUsageLineWithOptionSuffix(out, entry.command, &inflation_reward_command_usage_params, entry.suffix, &inflation_reward_usage_option_params),
        .poll_for_signature_confirmation => try writeCommandUsageLine(out, entry.command, &poll_for_signature_confirmation_command_usage_params, entry.suffix),
        .bytes => try writeCommandUsageLine(out, entry.command, &bytes_command_usage_params, entry.suffix),
        .blockhash => try writeCommandUsageLine(out, entry.command, &blockhash_command_usage_params, entry.suffix),
        .feature_pubkey => try writeCommandUsageLine(out, entry.command, &feature_pubkey_command_usage_params, entry.suffix),
        .slot => try writeCommandUsageLine(out, entry.command, &slot_command_usage_params, entry.suffix),
        .base64_message => try writeCommandUsageLine(out, entry.command, &message_command_usage_params, entry.suffix),
        .start_slot_limit => try writeCommandUsageLine(out, entry.command, &start_slot_limit_command_usage_params, entry.suffix),
        .start_slot => try writeCommandUsageLine(out, entry.command, &start_slot_command_usage_params, entry.suffix),
    }
}

fn writeCommandUsageSection(out: *std.Io.Writer) !void {
    for (command_usage_entries) |entry| {
        try writeCommandUsageEntry(out, entry);
    }
}

fn commandUsageEntry(command: Command) CommandUsageEntry {
    inline for (command_usage_entries) |entry| {
        if (entry.command == command) return entry;
    }

    unreachable;
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

pub fn defaultSolanaCliConfigPathForHome(allocator: Allocator, home_dir: []const u8) ![]u8 {
    return try std.fs.path.join(allocator, &.{ home_dir, default_solana_cli_config_path });
}

fn trimYamlValue(raw_value: []const u8) []const u8 {
    var value = std.mem.trim(u8, raw_value, " \t\r");
    if (value.len == 0) return value;

    if (value[0] != '"' and value[0] != '\'') {
        if (std.mem.indexOf(u8, value, " #")) |index| {
            value = std.mem.trimRight(u8, value[0..index], " \t");
        }
    }

    if (value.len >= 2) {
        const first = value[0];
        const last = value[value.len - 1];
        if ((first == '"' and last == '"') or (first == '\'' and last == '\'')) {
            value = value[1 .. value.len - 1];
        }
    }

    return value;
}

fn parseTopLevelYamlKeyValue(line: []const u8) ?struct { key: []const u8, value: []const u8 } {
    const trimmed = std.mem.trim(u8, line, " \t\r");
    if (trimmed.len == 0) return null;
    if (trimmed[0] == '#') return null;
    if (std.mem.eql(u8, trimmed, "---")) return null;
    if (line.len > 0 and (line[0] == ' ' or line[0] == '\t')) return null;

    const colon_index = std.mem.indexOfScalar(u8, trimmed, ':') orelse return null;
    const key = std.mem.trim(u8, trimmed[0..colon_index], " \t\r");
    if (key.len == 0) return null;

    return .{
        .key = key,
        .value = trimYamlValue(trimmed[colon_index + 1 ..]),
    };
}

pub fn loadDefaultSolanaCliConfig(allocator: Allocator, options: SolanaCliConfigLoadOptions) !SolanaCliConfig {
    const config_path = if (options.config_path_override) |override_path|
        try expandUserPathForHome(allocator, override_path, options.home_dir)
    else if (options.home_dir) |home_dir|
        try defaultSolanaCliConfigPathForHome(allocator, home_dir)
    else
        return .{};
    errdefer allocator.free(config_path);

    const file_contents = std.fs.cwd().readFileAlloc(allocator, config_path, 1 << 20) catch |err| switch (err) {
        error.FileNotFound => {
            allocator.free(config_path);
            return .{};
        },
        else => return err,
    };
    defer allocator.free(file_contents);

    var config = SolanaCliConfig{
        .path = config_path,
    };
    errdefer config.deinit(allocator);

    var line_iterator = std.mem.splitScalar(u8, file_contents, '\n');
    while (line_iterator.next()) |line| {
        const entry = parseTopLevelYamlKeyValue(line) orelse continue;
        if (std.mem.eql(u8, entry.key, "json_rpc_url")) {
            if (config.json_rpc_url) |value| allocator.free(value);
            if (entry.value.len != 0) config.json_rpc_url = try allocator.dupe(u8, entry.value);
            continue;
        }

        if (std.mem.eql(u8, entry.key, "websocket_url")) {
            if (config.websocket_url) |value| allocator.free(value);
            if (entry.value.len != 0) config.websocket_url = try allocator.dupe(u8, entry.value);
            continue;
        }

        if (std.mem.eql(u8, entry.key, "keypair_path")) {
            if (config.keypair_path) |value| allocator.free(value);
            if (entry.value.len != 0) config.keypair_path = try allocator.dupe(u8, entry.value);
            continue;
        }

        if (std.mem.eql(u8, entry.key, "commitment")) {
            config.commitment = parseCommitment(entry.value);
            continue;
        }
    }

    return config;
}

pub fn applySolanaCliConfigDefaults(parsed: *ParsedArgs, config: *const SolanaCliConfig) void {
    if (!parsed.rpc_url_overridden) {
        if (config.json_rpc_url) |rpc_url| parsed.rpc_url = rpc_url;
    }

    if (parsed.commitment == null) {
        parsed.commitment = config.commitment;
    }

    if (config.keypair_path) |keypair_path| {
        parsed.default_sender_keypair_path = keypair_path;
    }
}

pub const ParsedArgs = struct {
    command: Command,
    help_command: ?Command,
    has_command: bool,
    show_usage: bool,
    rpc_url: []const u8,
    rpc_url_overridden: bool,
    signature: ?[]const u8,
    account: ?[]const u8,
    expected_balance_arg: ?[]const u8,
    airdrop_recent_blockhash_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    account_data_slice_length_arg: ?[]const u8,
    account_data_slice_offset_arg: ?[]const u8,
    account_encoding_arg: ?[]const u8,
    blockhash_arg: ?[]const u8,
    block_production_identity_arg: ?[]const u8,
    block_production_first_slot_arg: ?[]const u8,
    block_production_last_slot_arg: ?[]const u8,
    confirmation_blocks_arg: ?[]const u8,
    delinquent_slot_distance_arg: ?[]const u8,
    encoding_arg: ?[]const u8,
    epoch_arg: ?[]const u8,
    feature_key_arg: ?[]const u8,
    largest_filter_arg: ?[]const u8,
    max_supported_transaction_version_arg: ?[]const u8,
    min_context_slot_arg: ?[]const u8,
    program_data_size_arg: ?[]const u8,
    program_data_slice_length_arg: ?[]const u8,
    program_data_slice_offset_arg: ?[]const u8,
    program_memcmp_bytes_arg: ?[]const u8,
    program_memcmp_offset_arg: ?[]const u8,
    program_sort_results: bool,
    program_with_context: bool,
    output_json: bool,
    signatures_for_address_arg: ?[]const u8,
    signatures_for_address_before_arg: ?[]const u8,
    signatures_for_address_until_arg: ?[]const u8,
    signatures_for_address_limit_arg: ?[]const u8,
    rewards_arg: ?[]const u8,
    slot_arg: ?[]const u8,
    blocks_end_slot_arg: ?[]const u8,
    blocks_limit_arg: ?[]const u8,
    message_arg: ?[]const u8,
    instructions_spec_arg: ?[]const u8,
    program_invoke_program_id_arg: ?[]const u8,
    program_invoke_accounts_arg: ?[]const u8,
    program_invoke_data_arg: ?[]const u8,
    program_invoke_data_encoding_arg: ?[]const u8,
    program_invoke_data_schema_json_arg: ?[]const u8,
    program_invoke_args_json_arg: ?[]const u8,
    program_invoke_schema_encoding_arg: ?[]const u8,
    program_invoke_signer_keypair_paths_arg: ?[]const u8,
    program_invoke_additional_signer_secret_keys: std.ArrayListUnmanaged([]const u8),
    program_invoke_lookup_tables_arg: ?[]const u8,
    program_invoke_nonce_account_arg: ?[]const u8,
    program_invoke_nonce_authority_keypair_path_arg: ?[]const u8,
    idl_program_id_arg: ?[]const u8,
    idl_spec_arg: ?[]const u8,
    idl_instruction_arg: ?[]const u8,
    idl_args_json_arg: ?[]const u8,
    idl_accounts_json_arg: ?[]const u8,
    idl_remaining_accounts_json_arg: ?[]const u8,
    raw_rpc_method_arg: ?[]const u8,
    raw_rpc_params_arg: ?[]const u8,
    slot_leaders_limit_arg: ?[]const u8,
    performance_limit_arg: ?[]const u8,
    leader_schedule_slot_arg: ?[]const u8,
    leader_schedule_identity_arg: ?[]const u8,
    lamports_arg: ?[]const u8,
    default_sender_keypair_path: ?[]const u8,
    mint_arg: ?[]const u8,
    rent_bytes_arg: ?[]const u8,
    sender_keypair_path_arg: ?[]const u8,
    sender_secret_key_arg: ?[]const u8,
    invoke_mode_arg: ?[]const u8,
    no_mode_fallback: bool,
    signed_tx_arg: ?[]const u8,
    simulation_account_encoding_arg: ?[]const u8,
    simulation_min_context_slot_arg: ?[]const u8,
    supply_exclude_non_circulating_accounts_list: bool,
    token_program_id_arg: ?[]const u8,
    transfer_recent_blockhash_arg: ?[]const u8,
    transaction_details_arg: ?[]const u8,
    vote_pubkey_arg: ?[]const u8,
    signature_statuses: std.ArrayListUnmanaged([]const u8),
    multiple_accounts: std.ArrayListUnmanaged([]const u8),
    simulation_accounts: std.ArrayListUnmanaged([]const u8),
    idl_account_bindings: std.ArrayListUnmanaged([]const u8),
    idl_remaining_accounts: std.ArrayListUnmanaged([]const u8),
    commitment: ?Commitment,
    status_timeout_ms: u64,
    status_poll_ms: u64,
    timeout_ms_overridden: bool,
    poll_ms_overridden: bool,
    search_transaction_history: bool,
    send_skip_preflight: bool,
    simulate_inner_instructions: bool,
    simulate_replace_recent_blockhash: bool,
    simulate_sig_verify: bool,
    vote_keep_unstaked_delinquents: bool,
    send_max_retries: ?u32,
    send_preflight_commitment: ?Commitment,

    pub fn deinit(self: *ParsedArgs, allocator: Allocator) void {
        self.signature_statuses.deinit(allocator);
        self.multiple_accounts.deinit(allocator);
        self.simulation_accounts.deinit(allocator);
        self.idl_account_bindings.deinit(allocator);
        self.idl_remaining_accounts.deinit(allocator);
        self.program_invoke_additional_signer_secret_keys.deinit(allocator);
    }
};

fn requireZeroOrOne(values: anytype) !?std.meta.Child(@TypeOf(values)) {
    return switch (values.len) {
        0 => null,
        1 => values[0],
        else => error.InvalidCli,
    };
}

fn appendStringArgs(allocator: Allocator, dest: *std.ArrayListUnmanaged([]const u8), values: []const []const u8) !void {
    for (values) |value| {
        dest.append(allocator, value) catch return error.InvalidCli;
    }
}

fn parsePositionalsWithClap(
    comptime params: []const clap.Param(clap.Help),
    allocator: Allocator,
    args: []const []const u8,
) !clap.ResultEx(clap.Help, params, positional_only_parsers) {
    comptime {
        @setEvalBranchQuota(8_000);
    }

    var iter = clap.args.SliceIterator{ .args = args };
    return clap.parseEx(clap.Help, params, positional_only_parsers, &iter, .{
        .allocator = allocator,
    }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidCli,
    };
}

fn commandFromArg(arg: []const u8) ?Command {
    inline for (command_usage_entries) |entry| {
        if (commandNameEql(arg, entry.command)) return entry.command;
    }

    return null;
}

fn parseTopLevelCommand(arg: []const u8) !ParsedTopLevelCommand {
    if (std.mem.eql(u8, arg, "help")) return .help;
    return .{ .command = commandFromArg(arg) orelse return error.InvalidCli };
}

fn parseCommandPositionalsFromMetadata(allocator: Allocator, parsed: *ParsedArgs, positionals: []const []const u8) !bool {
    const parse_style = commandUsageEntry(parsed.command).parse_style orelse return false;

    switch (parse_style) {
        .instruction => {
            var command_result = try parsePositionalsWithClap(&instruction_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.instructions_spec_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .idl_invoke_legacy => {
            var command_result = try parsePositionalsWithClap(&idl_invoke_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.idl_spec_arg = command_result.positionals[0];
            parsed.idl_instruction_arg = command_result.positionals[1];
            parsed.program_invoke_signer_keypair_paths_arg = command_result.positionals[2];
            if (command_result.positionals[3] != null or command_result.positionals[4].len != 0) return error.InvalidCli;
        },
        .idl_invoke_versioned => {
            var command_result = try parsePositionalsWithClap(&idl_invoke_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.idl_spec_arg = command_result.positionals[0];
            parsed.idl_instruction_arg = command_result.positionals[1];
            parsed.program_invoke_signer_keypair_paths_arg = command_result.positionals[2];
            parsed.program_invoke_lookup_tables_arg = command_result.positionals[3];
            if (command_result.positionals[4].len != 0) return error.InvalidCli;
        },
        .program_invoke_legacy => {
            var command_result = try parsePositionalsWithClap(&program_invoke_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.program_invoke_program_id_arg = command_result.positionals[0];
            parsed.program_invoke_accounts_arg = command_result.positionals[1];
            parsed.program_invoke_data_arg = command_result.positionals[2];
            parsed.program_invoke_data_encoding_arg = command_result.positionals[3];
            parsed.program_invoke_signer_keypair_paths_arg = command_result.positionals[4];
            if (command_result.positionals[5] != null or command_result.positionals[6].len != 0) return error.InvalidCli;
        },
        .program_invoke_versioned => {
            var command_result = try parsePositionalsWithClap(&program_invoke_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.program_invoke_program_id_arg = command_result.positionals[0];
            parsed.program_invoke_accounts_arg = command_result.positionals[1];
            parsed.program_invoke_data_arg = command_result.positionals[2];
            parsed.program_invoke_data_encoding_arg = command_result.positionals[3];
            parsed.program_invoke_signer_keypair_paths_arg = command_result.positionals[4];
            parsed.program_invoke_lookup_tables_arg = command_result.positionals[5];
            if (command_result.positionals[6].len != 0) return error.InvalidCli;
        },
        .transfer => {
            if (parsed.sender_keypair_path_arg == null and parsed.sender_secret_key_arg == null) {
                var command_result = try parsePositionalsWithClap(&transfer_with_default_sender_command_positionals_params, allocator, positionals);
                defer command_result.deinit();

                parsed.sender_secret_key_arg = command_result.positionals[0];
                parsed.account = command_result.positionals[1];
                parsed.lamports_arg = command_result.positionals[2];
                if (command_result.positionals[3].len != 0) return error.InvalidCli;
            } else {
                var command_result = try parsePositionalsWithClap(&transfer_with_explicit_sender_command_positionals_params, allocator, positionals);
                defer command_result.deinit();

                parsed.account = command_result.positionals[0];
                parsed.lamports_arg = command_result.positionals[1];
                if (command_result.positionals[2].len != 0) return error.InvalidCli;
            }
        },
        .signature => {
            var command_result = try parsePositionalsWithClap(&signature_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.signature = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .signature_list => {
            var command_result = try parsePositionalsWithClap(&signature_list_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            try appendStringArgs(allocator, &parsed.signature_statuses, command_result.positionals[0]);
        },
        .signatures_for_address => {
            var command_result = try parsePositionalsWithClap(&signatures_for_address_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.signatures_for_address_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .poll_for_signature_confirmation => {
            var command_result = try parsePositionalsWithClap(&poll_for_signature_confirmation_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.signature = command_result.positionals[0];
            parsed.confirmation_blocks_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .signed_transaction => {
            var command_result = try parsePositionalsWithClap(&signed_transaction_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.signed_tx_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .raw_rpc => {
            var command_result = try parsePositionalsWithClap(&raw_rpc_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.raw_rpc_method_arg = command_result.positionals[0];
            parsed.raw_rpc_params_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .account => {
            var command_result = try parsePositionalsWithClap(&account_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.account = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .account_expected_balance => {
            var command_result = try parsePositionalsWithClap(&account_expected_balance_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.account = command_result.positionals[0];
            parsed.expected_balance_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .account_lamports => {
            var command_result = try parsePositionalsWithClap(&account_lamports_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.account = command_result.positionals[0];
            parsed.lamports_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .address_list => {
            var command_result = try parsePositionalsWithClap(&address_list_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            try appendStringArgs(allocator, &parsed.multiple_accounts, command_result.positionals[0]);
        },
        .bytes => {
            var command_result = try parsePositionalsWithClap(&bytes_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.rent_bytes_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .blockhash => {
            var command_result = try parsePositionalsWithClap(&blockhash_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.blockhash_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .feature_pubkey => {
            var command_result = try parsePositionalsWithClap(&feature_pubkey_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.feature_key_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .slot => {
            var command_result = try parsePositionalsWithClap(&slot_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.slot_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .message => {
            var command_result = try parsePositionalsWithClap(&message_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.message_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .recent_performance_samples => {
            var command_result = try parsePositionalsWithClap(&recent_performance_samples_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.performance_limit_arg = command_result.positionals[0];
            if (command_result.positionals[1].len != 0) return error.InvalidCli;
        },
        .blocks => {
            var command_result = try parsePositionalsWithClap(&blocks_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.slot_arg = command_result.positionals[0];
            parsed.blocks_end_slot_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .start_slot_limit => {
            var command_result = try parsePositionalsWithClap(&slot_limit_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.slot_arg = command_result.positionals[0];
            switch (parsed.command) {
                .blocks_with_limit => parsed.blocks_limit_arg = command_result.positionals[1],
                .slot_leaders => parsed.slot_leaders_limit_arg = command_result.positionals[1],
                else => unreachable,
            }
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
        .leader_schedule => {
            var command_result = try parsePositionalsWithClap(&leader_schedule_command_positionals_params, allocator, positionals);
            defer command_result.deinit();

            parsed.leader_schedule_slot_arg = command_result.positionals[0];
            parsed.leader_schedule_identity_arg = command_result.positionals[1];
            if (command_result.positionals[2].len != 0) return error.InvalidCli;
        },
    }

    return true;
}

fn parseCommandPositionals(allocator: Allocator, parsed: *ParsedArgs, positionals: []const []const u8) !void {
    if (try parseCommandPositionalsFromMetadata(allocator, parsed, positionals)) return;
    if (positionals.len != 0) return error.InvalidCli;
}

pub fn parseCliArgs(allocator: Allocator, args: []const []const u8) !ParsedArgs {
    comptime {
        @setEvalBranchQuota(20_000);
    }

    var parsed = ParsedArgs{
        .command = .latest_blockhash,
        .help_command = null,
        .has_command = false,
        .show_usage = false,
        .rpc_url = default_solana_rpc_url,
        .rpc_url_overridden = false,
        .signature = null,
        .account = null,
        .expected_balance_arg = null,
        .airdrop_recent_blockhash_arg = null,
        .recent_blockhash_arg = null,
        .account_data_slice_length_arg = null,
        .account_data_slice_offset_arg = null,
        .account_encoding_arg = null,
        .blockhash_arg = null,
        .block_production_identity_arg = null,
        .block_production_first_slot_arg = null,
        .block_production_last_slot_arg = null,
        .confirmation_blocks_arg = null,
        .delinquent_slot_distance_arg = null,
        .encoding_arg = null,
        .epoch_arg = null,
        .feature_key_arg = null,
        .largest_filter_arg = null,
        .max_supported_transaction_version_arg = null,
        .min_context_slot_arg = null,
        .program_data_size_arg = null,
        .program_data_slice_length_arg = null,
        .program_data_slice_offset_arg = null,
        .program_memcmp_bytes_arg = null,
        .program_memcmp_offset_arg = null,
        .program_sort_results = false,
        .program_with_context = false,
        .output_json = false,
        .signatures_for_address_arg = null,
        .signatures_for_address_before_arg = null,
        .signatures_for_address_until_arg = null,
        .signatures_for_address_limit_arg = null,
        .rewards_arg = null,
        .slot_arg = null,
        .blocks_end_slot_arg = null,
        .blocks_limit_arg = null,
        .message_arg = null,
        .instructions_spec_arg = null,
        .program_invoke_program_id_arg = null,
        .program_invoke_accounts_arg = null,
        .program_invoke_data_arg = null,
        .program_invoke_data_encoding_arg = null,
        .program_invoke_data_schema_json_arg = null,
        .program_invoke_args_json_arg = null,
        .program_invoke_schema_encoding_arg = null,
        .program_invoke_signer_keypair_paths_arg = null,
        .program_invoke_additional_signer_secret_keys = .{},
        .program_invoke_lookup_tables_arg = null,
        .program_invoke_nonce_account_arg = null,
        .program_invoke_nonce_authority_keypair_path_arg = null,
        .idl_program_id_arg = null,
        .idl_spec_arg = null,
        .idl_instruction_arg = null,
        .idl_args_json_arg = null,
        .idl_accounts_json_arg = null,
        .idl_remaining_accounts_json_arg = null,
        .raw_rpc_method_arg = null,
        .raw_rpc_params_arg = null,
        .slot_leaders_limit_arg = null,
        .performance_limit_arg = null,
        .leader_schedule_slot_arg = null,
        .leader_schedule_identity_arg = null,
        .lamports_arg = null,
        .default_sender_keypair_path = null,
        .mint_arg = null,
        .rent_bytes_arg = null,
        .sender_keypair_path_arg = null,
        .sender_secret_key_arg = null,
        .invoke_mode_arg = null,
        .no_mode_fallback = false,
        .signed_tx_arg = null,
        .simulation_account_encoding_arg = null,
        .simulation_min_context_slot_arg = null,
        .supply_exclude_non_circulating_accounts_list = false,
        .token_program_id_arg = null,
        .transfer_recent_blockhash_arg = null,
        .transaction_details_arg = null,
        .vote_pubkey_arg = null,
        .signature_statuses = .{},
        .multiple_accounts = .{},
        .simulation_accounts = .{},
        .idl_account_bindings = .{},
        .idl_remaining_accounts = .{},
        .commitment = null,
        .status_timeout_ms = 30_000,
        .status_poll_ms = 500,
        .timeout_ms_overridden = false,
        .poll_ms_overridden = false,
        .search_transaction_history = false,
        .send_skip_preflight = false,
        .simulate_inner_instructions = false,
        .simulate_replace_recent_blockhash = false,
        .simulate_sig_verify = false,
        .vote_keep_unstaked_delinquents = false,
        .send_max_retries = null,
        .send_preflight_commitment = null,
    };

    var iter = clap.args.SliceIterator{ .args = args };
    var result = clap.parseEx(clap.Help, &cli_params, cli_parsers, &iter, .{
        .allocator = allocator,
    }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidCli,
    };
    defer result.deinit();

    parsed.show_usage = @field(result.args, "help") != 0;
    parsed.send_skip_preflight = @field(result.args, "skip-preflight") != 0;
    parsed.search_transaction_history = @field(result.args, "search-transaction-history") != 0;
    parsed.simulate_sig_verify = @field(result.args, "sig-verify") != 0;
    parsed.simulate_replace_recent_blockhash = @field(result.args, "replace-recent-blockhash") != 0;
    parsed.simulate_inner_instructions = @field(result.args, "inner-instructions") != 0;
    parsed.vote_keep_unstaked_delinquents = @field(result.args, "keep-unstaked-delinquents") != 0;
    parsed.supply_exclude_non_circulating_accounts_list = @field(result.args, "exclude-non-circulating-accounts-list") != 0;
    parsed.program_with_context = @field(result.args, "with-context") != 0;
    parsed.program_sort_results = @field(result.args, "sort-results") != 0;

    if (try requireZeroOrOne(@field(result.args, "rpc"))) |value| {
        parsed.rpc_url = value;
        parsed.rpc_url_overridden = true;
    }
    if (try requireZeroOrOne(@field(result.args, "commitment"))) |value| parsed.commitment = value;
    if (try requireZeroOrOne(@field(result.args, "timeout-ms"))) |value| {
        parsed.status_timeout_ms = value;
        parsed.timeout_ms_overridden = true;
    }
    if (try requireZeroOrOne(@field(result.args, "poll-ms"))) |value| {
        parsed.status_poll_ms = value;
        parsed.poll_ms_overridden = true;
    }
    if (try requireZeroOrOne(@field(result.args, "max-retries"))) |value| parsed.send_max_retries = value;
    if (try requireZeroOrOne(@field(result.args, "min-context-slot"))) |value| parsed.min_context_slot_arg = value;
    if (try requireZeroOrOne(@field(result.args, "epoch"))) |value| parsed.epoch_arg = value;
    if (try requireZeroOrOne(@field(result.args, "encoding"))) |value| parsed.encoding_arg = value;
    if (try requireZeroOrOne(@field(result.args, "max-supported-transaction-version"))) |value| parsed.max_supported_transaction_version_arg = value;
    if (try requireZeroOrOne(@field(result.args, "transaction-details"))) |value| parsed.transaction_details_arg = value;
    if (try requireZeroOrOne(@field(result.args, "rewards"))) |value| parsed.rewards_arg = value;
    if (try requireZeroOrOne(@field(result.args, "vote-pubkey"))) |value| parsed.vote_pubkey_arg = value;
    if (try requireZeroOrOne(@field(result.args, "delinquent-slot-distance"))) |value| parsed.delinquent_slot_distance_arg = value;
    if (try requireZeroOrOne(@field(result.args, "largest-filter"))) |value| parsed.largest_filter_arg = value;
    if (try requireZeroOrOne(@field(result.args, "block-production-identity"))) |value| parsed.block_production_identity_arg = value;
    if (try requireZeroOrOne(@field(result.args, "range-first-slot"))) |value| parsed.block_production_first_slot_arg = value;
    if (try requireZeroOrOne(@field(result.args, "range-last-slot"))) |value| parsed.block_production_last_slot_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-data-size"))) |value| parsed.program_data_size_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-memcmp-offset"))) |value| parsed.program_memcmp_offset_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-memcmp-bytes"))) |value| parsed.program_memcmp_bytes_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-data-slice-offset"))) |value| parsed.program_data_slice_offset_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-data-slice-length"))) |value| parsed.program_data_slice_length_arg = value;
    if (try requireZeroOrOne(@field(result.args, "account-encoding"))) |value| parsed.account_encoding_arg = value;
    if (try requireZeroOrOne(@field(result.args, "account-data-slice-offset"))) |value| parsed.account_data_slice_offset_arg = value;
    if (try requireZeroOrOne(@field(result.args, "account-data-slice-length"))) |value| parsed.account_data_slice_length_arg = value;
    if (try requireZeroOrOne(@field(result.args, "simulation-account-encoding"))) |value| parsed.simulation_account_encoding_arg = value;
    if (try requireZeroOrOne(@field(result.args, "simulation-min-context-slot"))) |value| parsed.simulation_min_context_slot_arg = value;
    if (try requireZeroOrOne(@field(result.args, "preflight-commitment"))) |value| parsed.send_preflight_commitment = value;
    if (try requireZeroOrOne(@field(result.args, "airdrop-recent-blockhash"))) |value| parsed.airdrop_recent_blockhash_arg = value;
    if (try requireZeroOrOne(@field(result.args, "recent-blockhash"))) |value| parsed.recent_blockhash_arg = value;
    if (try requireZeroOrOne(@field(result.args, "sender-keypair"))) |value| parsed.sender_keypair_path_arg = value;
    if (try requireZeroOrOne(@field(result.args, "sender-secret-key"))) |value| parsed.sender_secret_key_arg = value;
    if (try requireZeroOrOne(@field(result.args, "invoke-mode"))) |value| parsed.invoke_mode_arg = value;
    if (try requireZeroOrOne(@field(result.args, "program-id"))) |value| parsed.idl_program_id_arg = value;
    if (try requireZeroOrOne(@field(result.args, "data-schema-json"))) |value| parsed.program_invoke_data_schema_json_arg = value;
    if (try requireZeroOrOne(@field(result.args, "args-json"))) |value| parsed.program_invoke_args_json_arg = value;
    if (try requireZeroOrOne(@field(result.args, "schema-encoding"))) |value| parsed.program_invoke_schema_encoding_arg = value;
    if (try requireZeroOrOne(@field(result.args, "idl-args-json"))) |value| parsed.idl_args_json_arg = value;
    if (try requireZeroOrOne(@field(result.args, "accounts-json"))) |value| parsed.idl_accounts_json_arg = value;
    if (try requireZeroOrOne(@field(result.args, "remaining-accounts-json"))) |value| parsed.idl_remaining_accounts_json_arg = value;
    if (try requireZeroOrOne(@field(result.args, "nonce-account"))) |value| parsed.program_invoke_nonce_account_arg = value;
    if (try requireZeroOrOne(@field(result.args, "nonce-authority-keypair"))) |value| parsed.program_invoke_nonce_authority_keypair_path_arg = value;
    if (try requireZeroOrOne(@field(result.args, "transfer-recent-blockhash"))) |value| parsed.transfer_recent_blockhash_arg = value;
    if (try requireZeroOrOne(@field(result.args, "before"))) |value| parsed.signatures_for_address_before_arg = value;
    if (try requireZeroOrOne(@field(result.args, "until"))) |value| parsed.signatures_for_address_until_arg = value;
    if (try requireZeroOrOne(@field(result.args, "limit"))) |value| parsed.signatures_for_address_limit_arg = value;
    if (try requireZeroOrOne(@field(result.args, "mint"))) |value| parsed.mint_arg = value;
    if (try requireZeroOrOne(@field(result.args, "token-program-id"))) |value| parsed.token_program_id_arg = value;

    parsed.output_json = @field(result.args, "json") != 0;
    parsed.no_mode_fallback = @field(result.args, "no-mode-fallback") != 0;

    if (parsed.sender_keypair_path_arg != null and parsed.sender_secret_key_arg != null) {
        return error.InvalidCli;
    }

    try appendStringArgs(allocator, &parsed.simulation_accounts, @field(result.args, "simulation-account"));
    try appendStringArgs(allocator, &parsed.program_invoke_additional_signer_secret_keys, @field(result.args, "additional-signer-secret-key"));
    try appendStringArgs(allocator, &parsed.idl_account_bindings, @field(result.args, "account"));
    try appendStringArgs(allocator, &parsed.idl_remaining_accounts, @field(result.args, "remaining-account"));

    const top_level_command = result.positionals[0];
    if (top_level_command) |value| {
        switch (value) {
            .help => {
                parsed.show_usage = true;
                parsed.has_command = true;
                switch (result.positionals[1].len) {
                    0 => {},
                    1 => parsed.help_command = commandFromArg(result.positionals[1][0]) orelse return error.InvalidCli,
                    else => return error.InvalidCli,
                }
            },
            .command => |command| {
                parsed.command = command;
                parsed.has_command = true;
                if (parsed.show_usage) parsed.help_command = command;
                try parseCommandPositionals(allocator, &parsed, result.positionals[1]);
            },
        }
    }

    if (parsed.command == .transfer and
        parsed.sender_keypair_path_arg == null and
        parsed.sender_secret_key_arg != null and
        parsed.account != null and
        parsed.lamports_arg == null)
    {
        parsed.lamports_arg = parsed.account;
        parsed.account = parsed.sender_secret_key_arg;
        parsed.sender_secret_key_arg = null;
    }

    return parsed;
}

pub const Command = enum {
    latest_blockhash,
    new_latest_blockhash,
    account_info,
    account_data,
    ui_account,
    multiple_accounts,
    multiple_ui_accounts,
    program_accounts,
    program_ui_accounts,
    signatures_for_address,
    status,
    confirm_transaction,
    signature_status,
    signature_statuses,
    send_transaction,
    send_transaction_and_confirm,
    send_instructions,
    send_instructions_and_confirm,
    send_versioned_instructions,
    send_versioned_instructions_and_confirm,
    invoke_instructions,
    invoke_instructions_and_confirm,
    invoke_instructions_simulate,
    preview_instructions,
    explain_instructions,
    validate_instructions,
    prepare_instructions,
    estimate_instructions_fee,
    spec_instructions,
    invoke_spec,
    invoke_spec_and_confirm,
    invoke_spec_simulate,
    preview_spec,
    explain_spec,
    validate_spec,
    prepare_spec,
    estimate_spec_fee,
    send_program_invoke,
    send_program_invoke_and_confirm,
    send_versioned_program_invoke,
    send_versioned_program_invoke_and_confirm,
    invoke_program_invoke,
    invoke_program_invoke_and_confirm,
    invoke_program_invoke_simulate,
    preview_program_invoke,
    explain_program_invoke,
    validate_program_invoke,
    prepare_program_invoke,
    estimate_program_invoke_fee,
    spec_program_invoke,
    send_idl_invoke,
    send_idl_invoke_and_confirm,
    send_versioned_idl_invoke,
    send_versioned_idl_invoke_and_confirm,
    invoke_idl_invoke,
    invoke_idl_invoke_and_confirm,
    invoke_idl_invoke_simulate,
    preview_idl_invoke,
    explain_idl_invoke,
    validate_idl_invoke,
    prepare_idl_invoke,
    estimate_idl_invoke_fee,
    spec_idl_invoke,
    transfer,
    simulate_transaction,
    simulate_instructions,
    simulate_versioned_instructions,
    simulate_program_invoke,
    simulate_versioned_program_invoke,
    simulate_idl_invoke,
    simulate_versioned_idl_invoke,
    raw_rpc,
    slot,
    block_height,
    transaction_count,
    transaction,
    balance,
    poll_balance,
    wait_for_balance,
    request_airdrop,
    minimum_rent_exemption,
    feature_activation_slot,
    blockhash_valid,
    version,
    stake_minimum_delegation,
    largest_accounts,
    token_account_balance,
    token_account,
    token_supply,
    token_largest_accounts,
    token_accounts_by_owner,
    token_accounts_by_delegate,
    epoch_info,
    health,
    genesis_hash,
    inflation_reward,
    supply,
    epoch_schedule,
    inflation_rate,
    block_commitment,
    block,
    block_time,
    blocks,
    blocks_with_limit,
    poll_for_signature_confirmation,
    blocks_since_signature_confirmation,
    slot_leader,
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

comptime {
    @setEvalBranchQuota(20_000);

    if (command_usage_entries.len != std.meta.fields(Command).len) {
        @compileError("command_usage_entries must contain exactly one entry for every Command");
    }

    for (std.meta.fields(Command)) |field| {
        const command = @field(Command, field.name);
        var found = false;

        for (command_usage_entries) |entry| {
            if (entry.command != command) continue;
            if (found) {
                @compileError("duplicate command_usage_entries entry for Command." ++ field.name);
            }
            found = true;
        }

        if (!found) {
            @compileError("missing command_usage_entries entry for Command." ++ field.name);
        }
    }
}

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
    try std.testing.expect(std.mem.indexOf(u8, usage, "new-latest-blockhash <blockhash>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-status <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-statuses <signature-1> [signature-2 ...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "confirm-transaction <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "cluster-nodes") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "leader-schedule [slot] [identity]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "blocks-with-limit <start-slot> <limit>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "vote-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-production") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signature-status") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "feature-activation-slot <feature-pubkey>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "signatures-for-address <address>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-commitment <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "poll-for-signature-confirmation <signature> <min-confirmed-blocks>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "blocks-since-signature-confirmation <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "slot-leader") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "stake-minimum-delegation") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "account-info <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "account-data <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "ui-account <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "multiple-accounts <account-1> [account-2 ...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "multiple-ui-accounts <account-1> [account-2 ...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "program-accounts <program-id>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "program-ui-accounts <program-id>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "largest-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-account-balance <token-account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-account <token-account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-supply <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-largest-accounts <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "inflation-reward <address-1> [address-2 ...] [--epoch <epoch>]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "transaction <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-instructions-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-instructions-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "preview-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "explain-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "validate-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "prepare-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "spec-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "invoke-spec <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "invoke-spec-and-confirm <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "invoke-spec-simulate <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "preview-spec <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "explain-spec <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "validate-spec <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "prepare-spec <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "estimate-spec-fee <invocation-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-program-invoke-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-program-invoke-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "invoke-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "invoke-program-invoke-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "preview-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "explain-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "validate-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "prepare-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "spec-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-versioned-instructions [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] <instruction-spec-json|@path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-versioned-program-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--data-schema-json <json|@path>] [--args-json <json|@path>] [--schema-encoding <encoding>] <program-id> <accounts-json|@path> [data|@path] [data-encoding] [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-versioned-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-idl-invoke-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-versioned-idl-invoke-and-confirm [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "preview-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "explain-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "validate-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "prepare-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "spec-idl-invoke [--sender-keypair <path>] [--sender-secret-key <sender-secret-key>] [--recent-blockhash <base58>] [--program-id <pubkey>] [--nonce-account <pubkey>] [--nonce-authority-keypair <path>] [--idl-args-json <json|@path>] [--accounts-json <json|@path>] [--account <name=pubkey>...] [--remaining-account <pubkey[,is_signer,is_writable]>...] [--remaining-accounts-json <json|@path>] <idl-json|@path> <instruction-name> [additional-signer-keypair-paths-json|@path] [address-lookup-tables-json|@path]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "raw-rpc <method> [params-json]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "transfer [--sender-keypair <path> | <sender-secret-key>] <destination> <lamports>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "poll-balance <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "wait-for-balance <account> <expected-lamports>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-accounts-by-owner <owner>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-accounts-by-delegate <delegate>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction-and-confirm <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--skip-preflight") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--sig-verify") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--replace-recent-blockhash") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--inner-instructions") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--simulation-account <pubkey>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--simulation-account-encoding <mode>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--simulation-min-context-slot <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--min-context-slot <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--search-transaction-history") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--max-retries <count>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--preflight-commitment") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--airdrop-recent-blockhash <blockhash>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--rpc <url>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "RPC endpoint to use (default: Solana CLI config json_rpc_url or mainnet-beta)") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--commitment <level>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "processed|confirmed|finalized (default: Solana CLI config commitment when present)") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--sender-keypair <path>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "payer keypair JSON file (default: Solana CLI config keypair_path or ~/.config/solana/id.json)") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--sender-secret-key <sender-secret-key>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "payer secret key (base58)") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--transfer-recent-blockhash <blockhash>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--epoch <epoch>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--encoding <mode>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--max-supported-transaction-version <n>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--transaction-details <mode>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--rewards <true|false>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--vote-pubkey <pubkey>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--keep-unstaked-delinquents") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--delinquent-slot-distance <n>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--largest-filter <mode>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--block-production-identity <pubkey>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--range-first-slot <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--range-last-slot <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--exclude-non-circulating-accounts-list") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--program-data-size <bytes>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--program-memcmp-offset <offset>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--program-memcmp-bytes <bytes>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--program-data-slice-offset <offset>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--program-data-slice-length <length>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--with-context") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--sort-results") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--account-encoding <mode>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "base58|base64|jsonParsed for account-info and multiple-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--account-data-slice-offset <offset>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--account-data-slice-length <length>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--mint <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--token-program-id <program-id>") != null);
}

fn writeTextFile(path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |parent_path| {
        try std.fs.cwd().makePath(parent_path);
    }
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
}

test "cli.loadDefaultSolanaCliConfig parses standard Solana config file" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/home", .{tmp.sub_path});
    defer allocator.free(home_path);

    const config_path = try std.fs.path.join(allocator, &.{ home_path, default_solana_cli_config_path });
    defer allocator.free(config_path);

    try writeTextFile(config_path,
        \\json_rpc_url: "https://api.devnet.solana.com"
        \\websocket_url: wss://api.devnet.solana.com/
        \\keypair_path: ~/keys/devnet.json
        \\commitment: finalized
        \\address_labels:
        \\  test: Example11111111111111111111111111111111111
        \\
    );

    var config = try loadDefaultSolanaCliConfig(allocator, .{ .home_dir = home_path });
    defer config.deinit(allocator);

    try std.testing.expectEqualStrings(config_path, config.path orelse "");
    try std.testing.expectEqualStrings("https://api.devnet.solana.com", config.json_rpc_url orelse "");
    try std.testing.expectEqualStrings("wss://api.devnet.solana.com/", config.websocket_url orelse "");
    try std.testing.expectEqualStrings("~/keys/devnet.json", config.keypair_path orelse "");
    try std.testing.expectEqual(Commitment.finalized, config.commitment orelse .processed);
}

test "cli.loadDefaultSolanaCliConfig resolves custom override path" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const override_path = try std.fmt.allocPrint(
        allocator,
        ".zig-cache/tmp/{s}/custom_config.yml",
        .{tmp.sub_path},
    );
    defer allocator.free(override_path);

    try writeTextFile(override_path,
        \\json_rpc_url: https://api.testnet.solana.com
        \\commitment: confirmed
    );

    var config = try loadDefaultSolanaCliConfig(allocator, .{
        .config_path_override = override_path,
    });
    defer config.deinit(allocator);

    try std.testing.expectEqualStrings(override_path, config.path orelse "");
    try std.testing.expectEqualStrings("https://api.testnet.solana.com", config.json_rpc_url orelse "");
    try std.testing.expect(config.websocket_url == null);
    try std.testing.expectEqual(Commitment.confirmed, config.commitment orelse .processed);
}

test "cli.loadDefaultSolanaCliConfig expands home in override path" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const home_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer allocator.free(home_path);

    const override_path = "~/.solana_config_override.yml";
    const expanded_path = try expandUserPathForHome(
        allocator,
        override_path,
        home_path,
    );
    defer allocator.free(expanded_path);

    const parent_path = try std.fmt.allocPrint(
        allocator,
        "{s}/.solana",
        .{home_path},
    );
    defer allocator.free(parent_path);
    try std.fs.cwd().makePath(parent_path);

    try writeTextFile(expanded_path,
        \\json_rpc_url: "https://api.expand.solana.com"
        \\commitment: processed
    );

    var config = try loadDefaultSolanaCliConfig(allocator, .{
        .home_dir = home_path,
        .config_path_override = override_path,
    });
    defer config.deinit(allocator);

    try std.testing.expectEqualStrings(expanded_path, config.path orelse "");
    try std.testing.expectEqualStrings("https://api.expand.solana.com", config.json_rpc_url orelse "");
    try std.testing.expectEqual(Commitment.processed, config.commitment orelse .finalized);
}

test "cli.applySolanaCliConfigDefaults applies config defaults without overriding explicit rpc" {
    const allocator = std.testing.allocator;

    var config = SolanaCliConfig{
        .json_rpc_url = try allocator.dupe(u8, "https://api.devnet.solana.com"),
        .keypair_path = try allocator.dupe(u8, "/tmp/devnet-id.json"),
        .commitment = .confirmed,
    };
    defer config.deinit(allocator);

    var parsed = try parseCliArgs(allocator, &.{
        "--rpc",
        "https://override.solana.invalid",
        "transfer",
        "Destination111111111111111111111111111111",
        "12345",
    });
    defer parsed.deinit(allocator);

    applySolanaCliConfigDefaults(&parsed, &config);

    try std.testing.expectEqualStrings("https://override.solana.invalid", parsed.rpc_url);
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
    try std.testing.expectEqualStrings("/tmp/devnet-id.json", parsed.default_sender_keypair_path orelse "");
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
    try std.testing.expect(parsed.help_command == null);
}

test "cli.parseCliArgs captures help subcommand target" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{ "help", "transfer" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.show_usage);
    try std.testing.expect(parsed.has_command);
    try std.testing.expectEqual(Command.transfer, parsed.help_command.?);
}

test "cli.parseCliArgs captures command help target from help flag" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{ "transfer", "--help" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.show_usage);
    try std.testing.expect(parsed.has_command);
    try std.testing.expectEqual(Command.transfer, parsed.help_command.?);
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
        "--min-context-slot",
        "123",
        "--preflight-commitment",
        "confirmed",
        "signed-raw-transaction",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_transaction, parsed.command);
    try std.testing.expectEqualStrings("signed-raw-transaction", parsed.signed_tx_arg orelse "");
    try std.testing.expectEqual(true, parsed.send_skip_preflight);
    try std.testing.expectEqual(@as(u32, 3), parsed.send_max_retries orelse 0);
    try std.testing.expectEqualStrings("123", parsed.min_context_slot_arg orelse "");
    try std.testing.expectEqual(Commitment.confirmed, parsed.send_preflight_commitment orelse .processed);
}

test "cli.parseCliArgs parses raw-rpc with params json" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "raw-rpc",
        "getAccountInfo",
        "[\"Address11111111111111111111111111111111\"]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.raw_rpc, parsed.command);
    try std.testing.expectEqualStrings("getAccountInfo", parsed.raw_rpc_method_arg orelse "");
    try std.testing.expectEqualStrings("[\"Address11111111111111111111111111111111\"]", parsed.raw_rpc_params_arg orelse "");
}

test "cli.parseCliArgs parses raw-rpc without params json" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "raw-rpc",
        "getHealth",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.raw_rpc, parsed.command);
    try std.testing.expectEqualStrings("getHealth", parsed.raw_rpc_method_arg orelse "");
    try std.testing.expect(parsed.raw_rpc_params_arg == null);
}

test "cli.parseCliArgs parses simulate-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses send-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses preview-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "preview-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.preview_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses explain-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "explain-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.explain_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses validate-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "validate-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.validate_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses prepare-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "prepare-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.prepare_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses spec-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "spec-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.spec_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses preview-spec spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "preview-spec",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.preview_spec, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses invoke-spec args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-spec",
        "--json",
        "--invoke-mode",
        "versioned",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_spec, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses prepare-spec spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "prepare-spec",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.prepare_spec, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses invoke-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-instructions",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretInvokeInstructions1111111111111111111111111",
        "--recent-blockhash",
        "RecentInvokeInstructions1111111111111111111111111111",
        "{\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_instructions, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings(
        "{\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses invoke-instructions-and-confirm spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-instructions-and-confirm",
        "--json",
        "--invoke-mode",
        "legacy",
        "--sender-secret-key",
        "SecretInvokeInstructionsConfirm1111111111111111111",
        "--recent-blockhash",
        "RecentInvokeInstructionsConfirm111111111111111111",
        "{\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_instructions_and_confirm, parsed.command);
    try std.testing.expectEqualStrings("legacy", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings(
        "{\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses invoke-instructions-simulate spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-instructions-simulate",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretInvokeInstructionsSim11111111111111111111111",
        "--recent-blockhash",
        "RecentInvokeInstructionsSim111111111111111111111",
        "{\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_instructions_simulate, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings(
        "{\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses estimate-instructions-fee spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "estimate-instructions-fee",
        "--json",
        "--invoke-mode",
        "legacy",
        "--sender-secret-key",
        "SecretEstimateInstructions11111111111111111111111",
        "--recent-blockhash",
        "RecentEstimateInstructions111111111111111111111",
        "{\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.estimate_instructions_fee, parsed.command);
    try std.testing.expectEqualStrings("legacy", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings(
        "{\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses simulate-versioned-instructions spec" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-versioned-instructions",
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_versioned_instructions, parsed.command);
    try std.testing.expectEqualStrings(
        "{\"payer_secret_key\":\"abc\",\"instructions\":[]}",
        parsed.instructions_spec_arg orelse "",
    );
}

test "cli.parseCliArgs parses simulate-idl-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-idl-invoke",
        "--sender-secret-key",
        "Secret11111111111111111111111111111111",
        "{\"address\":\"Ev2cTB1BH9fNNdVbNg55CKu51tP7UTf8MGghRFmYvGvt\",\"instructions\":[{\"name\":\"initialize\",\"discriminator\":[1,2,3,4,5,6,7,8],\"accounts\":[],\"args\":[]}]}",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_idl_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
}

test "cli.parseCliArgs parses simulate-versioned-idl-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-versioned-idl-invoke",
        "--sender-secret-key",
        "Secret22222222222222222222222222222222",
        "{\"address\":\"Ev2cTB1BH9fNNdVbNg55CKu51tP7UTf8MGghRFmYvGvt\",\"instructions\":[{\"name\":\"initialize\",\"discriminator\":[1,2,3,4,5,6,7,8],\"accounts\":[],\"args\":[]}]}",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_versioned_idl_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret22222222222222222222222222222222", parsed.sender_secret_key_arg orelse "");
}

test "cli.parseCliArgs parses simulate-program-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-program-invoke",
        "--sender-secret-key",
        "Secret11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]",
        "ping",
        "utf8",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_program_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
}

test "cli.parseCliArgs parses simulate-versioned-program-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-versioned-program-invoke",
        "--sender-secret-key",
        "Secret33333333333333333333333333333333",
        "11111111111111111111111111111111",
        "[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]",
        "ping",
        "utf8",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_versioned_program_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret33333333333333333333333333333333", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
}

test "cli.parseCliArgs parses simulate-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-idl-invoke",
        "--sender-keypair",
        "/tmp/test-idl-invoke.json",
        "--recent-blockhash",
        "Recent111111111111111111111111111111111111111111",
        "--program-id",
        "Prog111111111111111111111111111111111111111111",
        "--nonce-account",
        "Nonce111111111111111111111111111111111111111111",
        "--nonce-authority-keypair",
        "/tmp/test-idl-nonce-authority.json",
        "--idl-args-json",
        "{\"enabled\":true}",
        "--accounts-json",
        "{\"state\":\"StateJson1111111111111111111111111111111111111\"}",
        "--account",
        "state=State111111111111111111111111111111111111111",
        "--remaining-account",
        "Remain111111111111111111111111111111111111111,true,false",
        "--remaining-accounts-json",
        "[{\"pubkey\":\"JsonRemain1111111111111111111111111111111111111\",\"is_signer\":false,\"is_writable\":true}]",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/extra.json\"]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-idl-invoke.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Recent111111111111111111111111111111111111111111", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("Prog111111111111111111111111111111111111111111", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("Nonce111111111111111111111111111111111111111111", parsed.program_invoke_nonce_account_arg orelse "");
    try std.testing.expectEqualStrings("/tmp/test-idl-nonce-authority.json", parsed.program_invoke_nonce_authority_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"state\":\"StateJson1111111111111111111111111111111111111\"}", parsed.idl_accounts_json_arg orelse "");
    try std.testing.expectEqual(@as(usize, 1), parsed.idl_account_bindings.items.len);
    try std.testing.expectEqualStrings("state=State111111111111111111111111111111111111111", parsed.idl_account_bindings.items[0]);
    try std.testing.expectEqual(@as(usize, 1), parsed.idl_remaining_accounts.items.len);
    try std.testing.expectEqualStrings("Remain111111111111111111111111111111111111111,true,false", parsed.idl_remaining_accounts.items[0]);
    try std.testing.expectEqualStrings("[{\"pubkey\":\"JsonRemain1111111111111111111111111111111111111\",\"is_signer\":false,\"is_writable\":true}]", parsed.idl_remaining_accounts_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
    try std.testing.expectEqualStrings("[\"/tmp/extra.json\"]", parsed.program_invoke_signer_keypair_paths_arg orelse "");
}

test "cli.parseCliArgs parses send-idl-invoke-and-confirm args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-idl-invoke-and-confirm",
        "--sender-keypair",
        "/tmp/test-idl-send.json",
        "--recent-blockhash",
        "Recent111111111111111111111111111111111111111111",
        "--program-id",
        "Prog222222222222222222222222222222222222222222",
        "--nonce-account",
        "Nonce222222222222222222222222222222222222222222",
        "@target/idl/hello_world.json",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_idl_invoke_and_confirm, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-idl-send.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Recent111111111111111111111111111111111111111111", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("Prog222222222222222222222222222222222222222222", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("Nonce222222222222222222222222222222222222222222", parsed.program_invoke_nonce_account_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses send-versioned-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-versioned-idl-invoke",
        "--sender-keypair",
        "/tmp/test-versioned-idl-send.json",
        "--recent-blockhash",
        "Recent333333333333333333333333333333333333333333",
        "--program-id",
        "Prog333333333333333333333333333333333333333333",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/versioned-extra.json\"]",
        "[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_versioned_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-versioned-idl-send.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Recent333333333333333333333333333333333333333333", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("Prog333333333333333333333333333333333333333333", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
    try std.testing.expectEqualStrings("[\"/tmp/versioned-extra.json\"]", parsed.program_invoke_signer_keypair_paths_arg orelse "");
    try std.testing.expectEqualStrings("[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]", parsed.program_invoke_lookup_tables_arg orelse "");
}

test "cli.parseCliArgs parses preview-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "preview-idl-invoke",
        "--sender-keypair",
        "/tmp/test-preview-idl.json",
        "--recent-blockhash",
        "Recent444444444444444444444444444444444444444444",
        "--program-id",
        "Prog444444444444444444444444444444444444444444",
        "--idl-args-json",
        "{\"enabled\":true}",
        "--accounts-json",
        "{\"authority\":\"Auth4444444444444444444444444444444444444444\"}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/preview-extra.json\"]",
        "[{\"account_key\":\"Lookup444444444444444444444444444444444\",\"addresses\":[\"Addr4444444444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.preview_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-preview-idl.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Recent444444444444444444444444444444444444444444", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("Prog444444444444444444444444444444444444444444", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"authority\":\"Auth4444444444444444444444444444444444444444\"}", parsed.idl_accounts_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
    try std.testing.expectEqualStrings("[\"/tmp/preview-extra.json\"]", parsed.program_invoke_signer_keypair_paths_arg orelse "");
    try std.testing.expectEqualStrings("[{\"account_key\":\"Lookup444444444444444444444444444444444\",\"addresses\":[\"Addr4444444444444444444444444444444444444\"]}]", parsed.program_invoke_lookup_tables_arg orelse "");
}

test "cli.parseCliArgs parses explain-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "explain-idl-invoke",
        "--sender-keypair",
        "/tmp/test-explain-idl.json",
        "--program-id",
        "ProgExplain44444444444444444444444444444444444444",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/explain-extra.json\"]",
        "[{\"account_key\":\"LookupExplain444444444444444444444444444444\",\"addresses\":[\"AddrExplain4444444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.explain_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-explain-idl.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("ProgExplain44444444444444444444444444444444444444", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses validate-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "validate-idl-invoke",
        "--sender-keypair",
        "/tmp/test-validate-idl.json",
        "--program-id",
        "ProgValidate4444444444444444444444444444444444444",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/validate-extra.json\"]",
        "[{\"account_key\":\"LookupValidate4444444444444444444444444444\",\"addresses\":[\"AddrValidate44444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.validate_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-validate-idl.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("ProgValidate4444444444444444444444444444444444444", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses prepare-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "prepare-idl-invoke",
        "--sender-keypair",
        "/tmp/test-prepare-idl.json",
        "--program-id",
        "ProgPrepare44444444444444444444444444444444444444",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/prepare-extra.json\"]",
        "[{\"account_key\":\"LookupPrepare44444444444444444444444444444\",\"addresses\":[\"AddrPrepare4444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.prepare_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-prepare-idl.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("ProgPrepare44444444444444444444444444444444444444", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses spec-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "spec-idl-invoke",
        "--sender-keypair",
        "/tmp/test-spec-idl.json",
        "--program-id",
        "ProgSpec4444444444444444444444444444444444444444",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/spec-extra.json\"]",
        "[{\"account_key\":\"LookupSpec444444444444444444444444444444444\",\"addresses\":[\"AddrSpec4444444444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.spec_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-spec-idl.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("ProgSpec4444444444444444444444444444444444444444", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses invoke-idl-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-idl-invoke",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretInvokeIdl111111111111111111111111111111111",
        "--program-id",
        "ProgInvokeIdl11111111111111111111111111111111111",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
        "[\"/tmp/invoke-idl-extra.json\"]",
        "[{\"account_key\":\"LookupInvoke44444444444444444444444444444\",\"addresses\":[\"AddrInvoke4444444444444444444444444444444\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_idl_invoke, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings("ProgInvokeIdl11111111111111111111111111111111111", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
}

test "cli.parseCliArgs parses invoke-idl-invoke-and-confirm args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-idl-invoke-and-confirm",
        "--json",
        "--invoke-mode",
        "legacy",
        "--sender-secret-key",
        "SecretInvokeIdlConfirm11111111111111111111111111111",
        "@target/idl/hello_world.json",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_idl_invoke_and_confirm, parsed.command);
    try std.testing.expectEqualStrings("legacy", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings("@target/idl/hello_world.json", parsed.idl_spec_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses invoke-idl-invoke-simulate args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-idl-invoke-simulate",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretInvokeIdlSim1111111111111111111111111111111",
        "--program-id",
        "ProgInvokeIdlSim111111111111111111111111111111111",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_idl_invoke_simulate, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings("ProgInvokeIdlSim111111111111111111111111111111111", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.idl_args_json_arg orelse "");
}

test "cli.parseCliArgs parses estimate-idl-invoke-fee args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "estimate-idl-invoke-fee",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretEstimateIdl111111111111111111111111111111111",
        "--program-id",
        "ProgEstimateIdl1111111111111111111111111111111111",
        "--idl-args-json",
        "{\"enabled\":true}",
        "@target/idl/hello_world.json",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.estimate_idl_invoke_fee, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings("ProgEstimateIdl1111111111111111111111111111111111", parsed.idl_program_id_arg orelse "");
}

test "cli.parseCliArgs parses send-program-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-program-invoke",
        "--sender-keypair",
        "/tmp/test-program-invoke.json",
        "Program1111111111111111111111111111111111",
        "[{\"pubkey\":\"Acct1111111111111111111111111111111111111\",\"is_signer\":true}]",
        "@data.bin",
        "hex",
        "[\"/tmp/extra.json\"]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-program-invoke.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"Acct1111111111111111111111111111111111111\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
    try std.testing.expectEqualStrings("@data.bin", parsed.program_invoke_data_arg orelse "");
    try std.testing.expectEqualStrings("hex", parsed.program_invoke_data_encoding_arg orelse "");
    try std.testing.expectEqualStrings("[\"/tmp/extra.json\"]", parsed.program_invoke_signer_keypair_paths_arg orelse "");
}

test "cli.parseCliArgs parses send-program-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-program-invoke",
        "--sender-secret-key",
        "Secret11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]",
        "ping",
        "utf8",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_program_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
}

test "cli.parseCliArgs parses send-program-invoke with additional-signer-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-program-invoke",
        "--sender-secret-key",
        "Secret11111111111111111111111111111111",
        "--additional-signer-secret-key",
        "ExtraSigner11111111111111111111111111111111",
        "--additional-signer-secret-key",
        "ExtraSigner22222222222222222222222222222222",
        "11111111111111111111111111111111",
        "[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]",
        "ping",
        "utf8",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_program_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqual(@as(usize, 2), parsed.program_invoke_additional_signer_secret_keys.items.len);
    try std.testing.expectEqualStrings(
        "ExtraSigner11111111111111111111111111111111",
        parsed.program_invoke_additional_signer_secret_keys.items[0],
    );
    try std.testing.expectEqualStrings(
        "ExtraSigner22222222222222222222222222222222",
        parsed.program_invoke_additional_signer_secret_keys.items[1],
    );
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"22222222222222222222222222222222\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
}

test "cli.parseCliArgs parses send-program-invoke with schema args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-program-invoke",
        "--sender-keypair",
        "/tmp/test-program-schema.json",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"amount\",\"type\":\"u64\"}]}",
        "--args-json",
        "{\"amount\":\"42\"}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-program-schema.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"amount\",\"type\":\"u64\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"amount\":\"42\"}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[]", parsed.program_invoke_accounts_arg orelse "");
    try std.testing.expect(parsed.program_invoke_data_arg == null);
    try std.testing.expect(parsed.program_invoke_data_encoding_arg == null);
}

test "cli.parseCliArgs parses preview-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "preview-program-invoke",
        "--sender-secret-key",
        "SecretPreview111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[\"/tmp/preview-extra.json\"]",
        "[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.preview_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretPreview111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses invoke-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-program-invoke",
        "--sender-secret-key",
        "SecretInvoke11111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[]",
        "[{\"account_key\":\"LookupInvoke1111111111111111111111111111111\",\"addresses\":[\"AddrInvoke11111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretInvoke11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses invoke-program-invoke-and-confirm with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-program-invoke-and-confirm",
        "--sender-secret-key",
        "SecretInvokeConfirm1111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[]",
        "[{\"account_key\":\"LookupInvokeConfirm11111111111111111111111111\",\"addresses\":[\"AddrInvokeConfirm1111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_program_invoke_and_confirm, parsed.command);
    try std.testing.expectEqualStrings("SecretInvokeConfirm1111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses invoke-program-invoke-simulate with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "invoke-program-invoke-simulate",
        "--sender-secret-key",
        "SecretInvokeSim1111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[]",
        "[{\"account_key\":\"LookupInvokeSim111111111111111111111111111\",\"addresses\":[\"AddrInvokeSim1111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.invoke_program_invoke_simulate, parsed.command);
    try std.testing.expectEqualStrings("SecretInvokeSim1111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses estimate-program-invoke-fee with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "estimate-program-invoke-fee",
        "--json",
        "--invoke-mode",
        "versioned",
        "--sender-secret-key",
        "SecretEstimateProgram1111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[]",
        "[{\"account_key\":\"LookupEstimate1111111111111111111111111111\",\"addresses\":[\"AddrEstimate11111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.estimate_program_invoke_fee, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
}

test "cli.parseCliArgs parses explain-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "explain-program-invoke",
        "--sender-secret-key",
        "SecretExplain1111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[\"/tmp/explain-extra.json\"]",
        "[{\"account_key\":\"LookupExplain11111111111111111111111111111\",\"addresses\":[\"AddrExplain1111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.explain_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretExplain1111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses validate-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "validate-program-invoke",
        "--sender-secret-key",
        "SecretValidate1111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[\"/tmp/validate-extra.json\"]",
        "[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.validate_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretValidate1111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses prepare-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "prepare-program-invoke",
        "--sender-secret-key",
        "SecretPrepare1111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[\"/tmp/prepare-extra.json\"]",
        "[{\"account_key\":\"LookupPrepare11111111111111111111111111111\",\"addresses\":[\"AddrPrepare1111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.prepare_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretPrepare1111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses spec-program-invoke with schema args and lookup tables" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "spec-program-invoke",
        "--sender-secret-key",
        "SecretSpec11111111111111111111111111111111111",
        "--data-schema-json",
        "{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}",
        "--args-json",
        "{\"enabled\":true}",
        "--schema-encoding",
        "borsh",
        "11111111111111111111111111111111",
        "[]",
        "[\"/tmp/spec-extra.json\"]",
        "[{\"account_key\":\"LookupSpec111111111111111111111111111111\",\"addresses\":[\"AddrSpec111111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.spec_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("SecretSpec11111111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("{\"type\":\"struct\",\"fields\":[{\"name\":\"enabled\",\"type\":\"bool\"}]}", parsed.program_invoke_data_schema_json_arg orelse "");
    try std.testing.expectEqualStrings("{\"enabled\":true}", parsed.program_invoke_args_json_arg orelse "");
    try std.testing.expectEqualStrings("borsh", parsed.program_invoke_schema_encoding_arg orelse "");
}

test "cli.parseCliArgs parses prepare-program-invoke invoke mode options" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "prepare-program-invoke",
        "--invoke-mode",
        "versioned",
        "--no-mode-fallback",
        "11111111111111111111111111111111",
        "[]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.prepare_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("versioned", parsed.invoke_mode_arg orelse "");
    try std.testing.expect(parsed.no_mode_fallback);
}

test "cli.parseCliArgs parses send-idl-invoke with sender-secret-key" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-idl-invoke",
        "--sender-secret-key",
        "Secret22222222222222222222222222222222",
        "--recent-blockhash",
        "Recent222222222222222222222222222222222222222222",
        "--program-id",
        "Prog22222222222222222222222222222222222222",
        "{\\\"address\\\":\\\"Ev2cTB1BH9fNNdVbNg55CKu51tP7UTf8MGghRFmYvGvt\\\",\\\"instructions\\\":[{\\\"name\\\":\\\"initialize\\\",\\\"discriminator\\\":[1,2,3,4,5,6,7,8],\\\"accounts\\\":[],\\\"args\\\":[]}]}",
        "initialize",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_idl_invoke, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expectEqualStrings("Secret22222222222222222222222222222222", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("Recent222222222222222222222222222222222222222222", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("Prog22222222222222222222222222222222222222", parsed.idl_program_id_arg orelse "");
    try std.testing.expectEqualStrings("initialize", parsed.idl_instruction_arg orelse "");
}

test "cli.parseCliArgs parses send-versioned-program-invoke args" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-versioned-program-invoke",
        "--sender-keypair",
        "/tmp/test-versioned-program-invoke.json",
        "Program1111111111111111111111111111111111",
        "[{\"pubkey\":\"Acct1111111111111111111111111111111111111\",\"is_signer\":true}]",
        "@data.bin",
        "base64",
        "[\"/tmp/extra.json\"]",
        "[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_versioned_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-versioned-program-invoke.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[{\"pubkey\":\"Acct1111111111111111111111111111111111111\",\"is_signer\":true}]", parsed.program_invoke_accounts_arg orelse "");
    try std.testing.expectEqualStrings("@data.bin", parsed.program_invoke_data_arg orelse "");
    try std.testing.expectEqualStrings("base64", parsed.program_invoke_data_encoding_arg orelse "");
    try std.testing.expectEqualStrings("[\"/tmp/extra.json\"]", parsed.program_invoke_signer_keypair_paths_arg orelse "");
    try std.testing.expectEqualStrings("[{\"account_key\":\"Lookup111111111111111111111111111111111\",\"addresses\":[\"Addr1111111111111111111111111111111111111\"]}]", parsed.program_invoke_lookup_tables_arg orelse "");
}

test "cli.parseCliArgs parses new-latest-blockhash" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "new-latest-blockhash",
        "Blockhash11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.new_latest_blockhash, parsed.command);
    try std.testing.expectEqualStrings("Blockhash11111111111111111111111111111111", parsed.blockhash_arg orelse "");
}

test "cli.parseCliArgs parses transfer with recent blockhash" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "transfer",
        "--transfer-recent-blockhash",
        "Blockhash11111111111111111111111111111111",
        "--skip-preflight",
        "--preflight-commitment",
        "confirmed",
        "--min-context-slot",
        "55",
        "SecretKey11111111111111111111111111111111",
        "Destination111111111111111111111111111111",
        "12345",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.transfer, parsed.command);
    try std.testing.expectEqualStrings("SecretKey11111111111111111111111111111111", parsed.sender_secret_key_arg orelse "");
    try std.testing.expectEqualStrings("Destination111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("12345", parsed.lamports_arg orelse "");
    try std.testing.expectEqualStrings("Blockhash11111111111111111111111111111111", parsed.transfer_recent_blockhash_arg orelse "");
    try std.testing.expect(parsed.send_skip_preflight);
    try std.testing.expectEqual(Commitment.confirmed, parsed.send_preflight_commitment orelse .processed);
    try std.testing.expectEqualStrings("55", parsed.min_context_slot_arg orelse "");
}

test "cli.parseCliArgs parses program invoke with recent blockhash" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "send-versioned-program-invoke",
        "--recent-blockhash",
        "Blockhash11111111111111111111111111111111",
        "--sender-keypair",
        "/tmp/test-program-invoke-keypair.json",
        "11111111111111111111111111111111",
        "[]",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.send_versioned_program_invoke, parsed.command);
    try std.testing.expectEqualStrings("Blockhash11111111111111111111111111111111", parsed.recent_blockhash_arg orelse "");
    try std.testing.expectEqualStrings("/tmp/test-program-invoke-keypair.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expectEqualStrings("11111111111111111111111111111111", parsed.program_invoke_program_id_arg orelse "");
    try std.testing.expectEqualStrings("[]", parsed.program_invoke_accounts_arg orelse "");
}

test "cli.parseCliArgs parses transfer with sender keypair path" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "transfer",
        "--sender-keypair",
        "/tmp/test-transfer-keypair.json",
        "Destination111111111111111111111111111111",
        "12345",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.transfer, parsed.command);
    try std.testing.expectEqualStrings("/tmp/test-transfer-keypair.json", parsed.sender_keypair_path_arg orelse "");
    try std.testing.expect(parsed.sender_secret_key_arg == null);
    try std.testing.expectEqualStrings("Destination111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("12345", parsed.lamports_arg orelse "");
}

test "cli.parseCliArgs parses transfer with default sender keypair" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "transfer",
        "Destination111111111111111111111111111111",
        "12345",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.transfer, parsed.command);
    try std.testing.expect(parsed.sender_keypair_path_arg == null);
    try std.testing.expect(parsed.sender_secret_key_arg == null);
    try std.testing.expectEqualStrings("Destination111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("12345", parsed.lamports_arg orelse "");
}

test "cli.parseCliArgs parses request-airdrop with recent blockhash" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "request-airdrop",
        "--airdrop-recent-blockhash",
        "RecentBlockhash1111111111111111111111111111",
        "Address11111111111111111111111111111111",
        "1000",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.request_airdrop, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("1000", parsed.lamports_arg orelse "");
    try std.testing.expectEqualStrings("RecentBlockhash1111111111111111111111111111", parsed.airdrop_recent_blockhash_arg orelse "");
}

test "cli.parseCliArgs parses simulate-transaction with simulation options" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-transaction",
        "--sig-verify",
        "--replace-recent-blockhash",
        "--inner-instructions",
        "--simulation-account",
        "Account11111111111111111111111111111111",
        "--simulation-account",
        "Account22222222222222222222222222222222",
        "--simulation-account-encoding",
        "base64",
        "--simulation-min-context-slot",
        "123",
        "--commitment",
        "processed",
        "signed-raw-transaction",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_transaction, parsed.command);
    try std.testing.expectEqualStrings("signed-raw-transaction", parsed.signed_tx_arg orelse "");
    try std.testing.expect(parsed.simulate_sig_verify);
    try std.testing.expect(parsed.simulate_replace_recent_blockhash);
    try std.testing.expect(parsed.simulate_inner_instructions);
    try std.testing.expectEqualStrings("base64", parsed.simulation_account_encoding_arg orelse "");
    try std.testing.expectEqualStrings("123", parsed.simulation_min_context_slot_arg orelse "");
    try std.testing.expectEqual(@as(usize, 2), parsed.simulation_accounts.items.len);
    try std.testing.expectEqualStrings("Account11111111111111111111111111111111", parsed.simulation_accounts.items[0]);
    try std.testing.expectEqualStrings("Account22222222222222222222222222222222", parsed.simulation_accounts.items[1]);
    try std.testing.expectEqual(Commitment.processed, parsed.commitment orelse .confirmed);
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

test "cli.parseCliArgs parses poll-balance" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "poll-balance",
        "Account11111111111111111111111111111111",
        "--timeout-ms",
        "2000",
        "--poll-ms",
        "50",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.poll_balance, parsed.command);
    try std.testing.expectEqualStrings("Account11111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqual(@as(u64, 2000), parsed.status_timeout_ms);
    try std.testing.expectEqual(@as(u64, 50), parsed.status_poll_ms);
    try std.testing.expect(parsed.timeout_ms_overridden);
    try std.testing.expect(parsed.poll_ms_overridden);
}

test "cli.parseCliArgs parses wait-for-balance" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "wait-for-balance",
        "Account11111111111111111111111111111111",
        "5000",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.wait_for_balance, parsed.command);
    try std.testing.expectEqualStrings("Account11111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("5000", parsed.expected_balance_arg orelse "");
}

test "cli.parseCliArgs parses confirm-transaction" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "confirm-transaction",
        "--search-transaction-history",
        "signature-value",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.confirm_transaction, parsed.command);
    try std.testing.expectEqualStrings("signature-value", parsed.signature orelse "");
    try std.testing.expect(parsed.search_transaction_history);
}

test "cli.parseCliArgs parses poll-for-signature-confirmation" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "poll-for-signature-confirmation",
        "signature-value",
        "8",
        "--timeout-ms",
        "10000",
        "--poll-ms",
        "250",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.poll_for_signature_confirmation, parsed.command);
    try std.testing.expectEqualStrings("signature-value", parsed.signature orelse "");
    try std.testing.expectEqualStrings("8", parsed.confirmation_blocks_arg orelse "");
    try std.testing.expectEqual(@as(u64, 10000), parsed.status_timeout_ms);
    try std.testing.expectEqual(@as(u64, 250), parsed.status_poll_ms);
}

test "cli.parseCliArgs parses blocks-since-signature-confirmation" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "blocks-since-signature-confirmation",
        "signature-value",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.blocks_since_signature_confirmation, parsed.command);
    try std.testing.expectEqualStrings("signature-value", parsed.signature orelse "");
}

test "cli.parseCliArgs parses signature-status with history search" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "signature-status",
        "--search-transaction-history",
        "signature-value",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.signature_status, parsed.command);
    try std.testing.expectEqualStrings("signature-value", parsed.signature orelse "");
    try std.testing.expect(parsed.search_transaction_history);
}

test "cli.parseCliArgs parses transaction with config flags" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "transaction",
        "--encoding",
        "jsonParsed",
        "--max-supported-transaction-version",
        "0",
        "--commitment",
        "finalized",
        "5h6xSignature111111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.transaction, parsed.command);
    try std.testing.expectEqualStrings("5h6xSignature111111111111111111111111111111111111", parsed.signature orelse "");
    try std.testing.expectEqualStrings("jsonParsed", parsed.encoding_arg orelse "");
    try std.testing.expectEqualStrings("0", parsed.max_supported_transaction_version_arg orelse "");
    try std.testing.expectEqual(Commitment.finalized, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses inflation reward with epoch" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "inflation-reward",
        "--epoch",
        "42",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.inflation_reward, parsed.command);
    try std.testing.expectEqualStrings("42", parsed.epoch_arg orelse "");
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
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

test "cli.parseCliArgs parses recent prioritization fees with accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "recent-prioritization-fees",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.recent_prioritization_fees, parsed.command);
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
}

test "cli.parseCliArgs parses vote accounts with filters" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "vote-accounts",
        "--vote-pubkey",
        "Vote111111111111111111111111111111111111111",
        "--keep-unstaked-delinquents",
        "--delinquent-slot-distance",
        "64",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.vote_accounts, parsed.command);
    try std.testing.expectEqualStrings("Vote111111111111111111111111111111111111111", parsed.vote_pubkey_arg orelse "");
    try std.testing.expect(parsed.vote_keep_unstaked_delinquents);
    try std.testing.expectEqualStrings("64", parsed.delinquent_slot_distance_arg orelse "");
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses block production with filters" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "block-production",
        "--block-production-identity",
        "Identity1111111111111111111111111111111111",
        "--range-first-slot",
        "100",
        "--range-last-slot",
        "200",
        "--commitment",
        "processed",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block_production, parsed.command);
    try std.testing.expectEqualStrings("Identity1111111111111111111111111111111111", parsed.block_production_identity_arg orelse "");
    try std.testing.expectEqualStrings("100", parsed.block_production_first_slot_arg orelse "");
    try std.testing.expectEqualStrings("200", parsed.block_production_last_slot_arg orelse "");
    try std.testing.expectEqual(Commitment.processed, parsed.commitment orelse .confirmed);
}

test "cli.parseCliArgs parses slot leader with commitment" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "slot-leader",
        "--commitment",
        "confirmed",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.slot_leader, parsed.command);
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
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

test "cli.parseCliArgs parses block commitment" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "block-commitment",
        "456",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block_commitment, parsed.command);
    try std.testing.expectEqualStrings("456", parsed.slot_arg orelse "");
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

test "cli.parseCliArgs parses block with config flags" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "block",
        "--encoding",
        "json",
        "--transaction-details",
        "accounts",
        "--rewards",
        "false",
        "--max-supported-transaction-version",
        "0",
        "123",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.block, parsed.command);
    try std.testing.expectEqualStrings("123", parsed.slot_arg orelse "");
    try std.testing.expectEqualStrings("json", parsed.encoding_arg orelse "");
    try std.testing.expectEqualStrings("accounts", parsed.transaction_details_arg orelse "");
    try std.testing.expectEqualStrings("false", parsed.rewards_arg orelse "");
    try std.testing.expectEqualStrings("0", parsed.max_supported_transaction_version_arg orelse "");
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

test "cli.parseCliArgs parses account data" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "account-data",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.account_data, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses ui account" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "ui-account",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.ui_account, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses account info with config" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "account-info",
        "--with-context",
        "--account-encoding",
        "base64",
        "--account-data-slice-offset",
        "0",
        "--account-data-slice-length",
        "32",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.account_info, parsed.command);
    try std.testing.expect(parsed.program_with_context);
    try std.testing.expectEqualStrings("base64", parsed.account_encoding_arg orelse "");
    try std.testing.expectEqualStrings("0", parsed.account_data_slice_offset_arg orelse "");
    try std.testing.expectEqualStrings("32", parsed.account_data_slice_length_arg orelse "");
}

test "cli.parseCliArgs parses account info with jsonParsed encoding" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "account-info",
        "--account-encoding",
        "jsonParsed",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.account_info, parsed.command);
    try std.testing.expectEqualStrings("jsonParsed", parsed.account_encoding_arg orelse "");
}

test "cli.parseCliArgs parses multiple accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "multiple-accounts",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.multiple_accounts, parsed.command);
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.multiple_accounts.items[0]);
    try std.testing.expectEqualStrings("Address22222222222222222222222222222222", parsed.multiple_accounts.items[1]);
}

test "cli.parseCliArgs parses multiple ui accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "multiple-ui-accounts",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.multiple_ui_accounts, parsed.command);
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.multiple_accounts.items[0]);
    try std.testing.expectEqualStrings("Address22222222222222222222222222222222", parsed.multiple_accounts.items[1]);
}

test "cli.parseCliArgs parses multiple ui accounts with context" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "multiple-ui-accounts",
        "--with-context",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.multiple_ui_accounts, parsed.command);
    try std.testing.expect(parsed.program_with_context);
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
}

test "cli.parseCliArgs parses multiple accounts with config" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "multiple-accounts",
        "--account-encoding",
        "base58",
        "--account-data-slice-offset",
        "4",
        "--account-data-slice-length",
        "16",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.multiple_accounts, parsed.command);
    try std.testing.expectEqualStrings("base58", parsed.account_encoding_arg orelse "");
    try std.testing.expectEqualStrings("4", parsed.account_data_slice_offset_arg orelse "");
    try std.testing.expectEqualStrings("16", parsed.account_data_slice_length_arg orelse "");
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
}

test "cli.parseCliArgs parses multiple accounts with jsonParsed encoding" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "multiple-accounts",
        "--account-encoding",
        "jsonParsed",
        "Address11111111111111111111111111111111",
        "Address22222222222222222222222222222222",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.multiple_accounts, parsed.command);
    try std.testing.expectEqualStrings("jsonParsed", parsed.account_encoding_arg orelse "");
    try std.testing.expectEqual(@as(usize, 2), parsed.multiple_accounts.items.len);
}

test "cli.parseCliArgs parses program accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.program_accounts, parsed.command);
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses program ui accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "program-ui-accounts",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.program_ui_accounts, parsed.command);
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses program ui accounts with filters" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "program-ui-accounts",
        "--program-data-size",
        "165",
        "--program-memcmp-offset",
        "32",
        "--program-memcmp-bytes",
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
        "--program-data-slice-offset",
        "0",
        "--program-data-slice-length",
        "32",
        "--with-context",
        "--sort-results",
        "--commitment",
        "finalized",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.program_ui_accounts, parsed.command);
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("165", parsed.program_data_size_arg orelse "");
    try std.testing.expectEqualStrings("32", parsed.program_memcmp_offset_arg orelse "");
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", parsed.program_memcmp_bytes_arg orelse "");
    try std.testing.expectEqualStrings("0", parsed.program_data_slice_offset_arg orelse "");
    try std.testing.expectEqualStrings("32", parsed.program_data_slice_length_arg orelse "");
    try std.testing.expect(parsed.program_with_context);
    try std.testing.expect(parsed.program_sort_results);
    try std.testing.expectEqual(Commitment.finalized, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses program accounts with filters" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "program-accounts",
        "--program-data-size",
        "165",
        "--program-memcmp-offset",
        "32",
        "--program-memcmp-bytes",
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
        "--program-data-slice-offset",
        "0",
        "--program-data-slice-length",
        "32",
        "--with-context",
        "--sort-results",
        "--commitment",
        "confirmed",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.program_accounts, parsed.command);
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("165", parsed.program_data_size_arg orelse "");
    try std.testing.expectEqualStrings("32", parsed.program_memcmp_offset_arg orelse "");
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", parsed.program_memcmp_bytes_arg orelse "");
    try std.testing.expectEqualStrings("0", parsed.program_data_slice_offset_arg orelse "");
    try std.testing.expectEqualStrings("32", parsed.program_data_slice_length_arg orelse "");
    try std.testing.expect(parsed.program_with_context);
    try std.testing.expect(parsed.program_sort_results);
    try std.testing.expectEqual(Commitment.confirmed, parsed.commitment orelse .processed);
}

test "cli.parseCliArgs parses largest accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "largest-accounts",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.largest_accounts, parsed.command);
}

test "cli.parseCliArgs parses largest accounts with filter" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "largest-accounts",
        "--largest-filter",
        "non-circulating",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.largest_accounts, parsed.command);
    try std.testing.expectEqualStrings("non-circulating", parsed.largest_filter_arg orelse "");
}

test "cli.parseCliArgs parses supply exclude list flag" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "supply",
        "--exclude-non-circulating-accounts-list",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.supply, parsed.command);
    try std.testing.expect(parsed.supply_exclude_non_circulating_accounts_list);
}

test "cli.parseCliArgs parses token account balance" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-account-balance",
        "TokenAcct1111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_account_balance, parsed.command);
    try std.testing.expectEqualStrings("TokenAcct1111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses token account" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-account",
        "TokenAcct1111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_account, parsed.command);
    try std.testing.expectEqualStrings("TokenAcct1111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses token supply" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-supply",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_supply, parsed.command);
    try std.testing.expectEqualStrings("Mint111111111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses token largest accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-largest-accounts",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_largest_accounts, parsed.command);
    try std.testing.expectEqualStrings("Mint111111111111111111111111111111111111", parsed.account orelse "");
}

test "cli.parseCliArgs parses token accounts by owner with mint filter" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-accounts-by-owner",
        "Owner1111111111111111111111111111111111111",
        "--mint",
        "Mint111111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_accounts_by_owner, parsed.command);
    try std.testing.expectEqualStrings("Owner1111111111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("Mint111111111111111111111111111111111111", parsed.mint_arg orelse "");
}

test "cli.parseCliArgs parses token accounts by delegate with program filter" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "token-accounts-by-delegate",
        "--token-program-id",
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
        "Delegate11111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.token_accounts_by_delegate, parsed.command);
    try std.testing.expectEqualStrings("Delegate11111111111111111111111111111111111", parsed.account orelse "");
    try std.testing.expectEqualStrings("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", parsed.token_program_id_arg orelse "");
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
        "--min-context-slot",
        "456",
        "Address11111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.signatures_for_address, parsed.command);
    try std.testing.expectEqualStrings("Address11111111111111111111111111111111", parsed.signatures_for_address_arg orelse "");
    try std.testing.expectEqualStrings("BeforeSig", parsed.signatures_for_address_before_arg orelse "");
    try std.testing.expectEqualStrings("UntilSig", parsed.signatures_for_address_until_arg orelse "");
    try std.testing.expectEqualStrings("50", parsed.signatures_for_address_limit_arg orelse "");
    try std.testing.expectEqualStrings("456", parsed.min_context_slot_arg orelse "");
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
