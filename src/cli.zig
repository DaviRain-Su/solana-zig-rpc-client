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
    "  solana_client_zig [--rpc <url>] simulate-transaction <signed-tx-base64>\n" ++
    "  solana_client_zig [--rpc <url>] slot\n" ++
    "  solana_client_zig [--rpc <url>] block-height\n" ++
    "  solana_client_zig [--rpc <url>] transaction-count\n" ++
    "  solana_client_zig [--rpc <url>] transaction <signature>\n" ++
    "  solana_client_zig [--rpc <url>] balance <account>\n" ++
    "  solana_client_zig [--rpc <url>] account-info <account>\n" ++
    "  solana_client_zig [--rpc <url>] multiple-accounts <account-1> [account-2 ...]\n" ++
    "  solana_client_zig [--rpc <url>] program-accounts <program-id>\n" ++
    "  solana_client_zig [--rpc <url>] request-airdrop <account> <lamports>\n" ++
    "  solana_client_zig [--rpc <url>] minimum-rent-exemption <bytes>\n" ++
    "  solana_client_zig [--rpc <url>] version\n" ++
    "  solana_client_zig [--rpc <url>] epoch-info\n" ++
    "  solana_client_zig [--rpc <url>] health\n" ++
    "  solana_client_zig [--rpc <url>] genesis-hash\n" ++
    "  solana_client_zig [--rpc <url>] inflation-reward <address-1> [address-2 ...] [--epoch <epoch>]\n" ++
    "  solana_client_zig [--rpc <url>] supply\n" ++
    "  solana_client_zig [--rpc <url>] epoch-schedule\n" ++
    "  solana_client_zig [--rpc <url>] inflation-rate\n" ++
    "  solana_client_zig [--rpc <url>] block-time <slot>\n" ++
    "  solana_client_zig [--rpc <url>] block-commitment <slot>\n" ++
    "  solana_client_zig [--rpc <url>] block <slot>\n" ++
    "  solana_client_zig [--rpc <url>] blocks-with-limit <start-slot> <limit>\n" ++
    "  solana_client_zig [--rpc <url>] signatures-for-address <address> [--before <signature>] [--until <signature>] [--limit <count>]\n" ++
    "  solana_client_zig [--rpc <url>] feature-activation-slot <feature-pubkey>\n" ++
    "  solana_client_zig [--rpc <url>] stake-minimum-delegation\n" ++
    "  solana_client_zig [--rpc <url>] largest-accounts\n" ++
    "  solana_client_zig [--rpc <url>] token-account-balance <token-account>\n" ++
    "  solana_client_zig [--rpc <url>] token-supply <mint>\n" ++
    "  solana_client_zig [--rpc <url>] token-largest-accounts <mint>\n" ++
    "  solana_client_zig [--rpc <url>] token-accounts-by-owner <owner> (--mint <mint> | --token-program-id <program-id>)\n" ++
    "  solana_client_zig [--rpc <url>] token-accounts-by-delegate <delegate> (--mint <mint> | --token-program-id <program-id>)\n" ++
    "  solana_client_zig [--rpc <url>] fee-for-message <base64-message>\n" ++
    "  solana_client_zig [--rpc <url>] recent-performance-samples [limit]\n" ++
    "  solana_client_zig [--rpc <url>] highest-snapshot-slot\n" ++
    "  solana_client_zig [--rpc <url>] blocks <start-slot> [end-slot]\n" ++
    "  solana_client_zig [--rpc <url>] slot-leader\n" ++
    "  solana_client_zig [--rpc <url>] slot-leaders <start-slot> <limit>\n" ++
    "  solana_client_zig [--rpc <url>] recent-prioritization-fees [account-1 ...]\n" ++
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
    "  --sig-verify             Verify signatures during simulation (simulate-transaction)\n" ++
    "  --replace-recent-blockhash  Replace recent blockhash during simulation\n" ++
    "  --max-retries <count>    Max tx retries before giving up\n" ++
    "  --preflight-commitment <level>  Commitment for tx preflight checks\n" ++
    "  --epoch <epoch>          Epoch override for inflation-reward\n" ++
    "  --encoding <mode>        json|jsonParsed|base58|base64 (block and transaction)\n" ++
    "  --max-supported-transaction-version <n>  Max supported tx version (block and transaction)\n" ++
    "  --transaction-details <mode>  full|accounts|signatures|none (block)\n" ++
    "  --rewards <true|false>   Include rewards in block response\n" ++
    "  --vote-pubkey <pubkey>   Filter vote-accounts by vote pubkey\n" ++
    "  --keep-unstaked-delinquents  Keep unstaked delinquents in vote-accounts\n" ++
    "  --delinquent-slot-distance <n> Delinquent slot distance for vote-accounts\n" ++
    "  --largest-filter <mode>  circulating|non-circulating (largest-accounts)\n" ++
    "  --block-production-identity <pubkey> Filter block-production by identity\n" ++
    "  --range-first-slot <slot> First slot for block-production range\n" ++
    "  --range-last-slot <slot>  Last slot for block-production range\n" ++
    "  --exclude-non-circulating-accounts-list Exclude non-circulating account list from supply\n" ++
    "  --program-data-size <bytes> Filter program-accounts by account data size\n" ++
    "  --program-memcmp-offset <offset> Memcmp offset for program-accounts filter\n" ++
    "  --program-memcmp-bytes <bytes>  Memcmp bytes for program-accounts filter\n" ++
    "  --program-data-slice-offset <offset> Data slice offset for program-accounts\n" ++
    "  --program-data-slice-length <length> Data slice length for program-accounts\n" ++
    "  --mint <mint>            Token account filter by mint (token-accounts-by-*)\n" ++
    "  --token-program-id <program-id> Token account filter by token program (token-accounts-by-*)\n";

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
    block_production_identity_arg: ?[]const u8,
    block_production_first_slot_arg: ?[]const u8,
    block_production_last_slot_arg: ?[]const u8,
    delinquent_slot_distance_arg: ?[]const u8,
    encoding_arg: ?[]const u8,
    epoch_arg: ?[]const u8,
    feature_key_arg: ?[]const u8,
    largest_filter_arg: ?[]const u8,
    max_supported_transaction_version_arg: ?[]const u8,
    program_data_size_arg: ?[]const u8,
    program_data_slice_length_arg: ?[]const u8,
    program_data_slice_offset_arg: ?[]const u8,
    program_memcmp_bytes_arg: ?[]const u8,
    program_memcmp_offset_arg: ?[]const u8,
    signatures_for_address_arg: ?[]const u8,
    signatures_for_address_before_arg: ?[]const u8,
    signatures_for_address_until_arg: ?[]const u8,
    signatures_for_address_limit_arg: ?[]const u8,
    rewards_arg: ?[]const u8,
    slot_arg: ?[]const u8,
    blocks_end_slot_arg: ?[]const u8,
    blocks_limit_arg: ?[]const u8,
    message_arg: ?[]const u8,
    slot_leaders_limit_arg: ?[]const u8,
    performance_limit_arg: ?[]const u8,
    leader_schedule_slot_arg: ?[]const u8,
    leader_schedule_identity_arg: ?[]const u8,
    lamports_arg: ?[]const u8,
    mint_arg: ?[]const u8,
    rent_bytes_arg: ?[]const u8,
    signed_tx_arg: ?[]const u8,
    supply_exclude_non_circulating_accounts_list: bool,
    token_program_id_arg: ?[]const u8,
    transaction_details_arg: ?[]const u8,
    vote_pubkey_arg: ?[]const u8,
    signature_statuses: std.ArrayListUnmanaged([]const u8),
    multiple_accounts: std.ArrayListUnmanaged([]const u8),
    commitment: ?Commitment,
    status_timeout_ms: u64,
    status_poll_ms: u64,
    send_skip_preflight: bool,
    simulate_replace_recent_blockhash: bool,
    simulate_sig_verify: bool,
    vote_keep_unstaked_delinquents: bool,
    send_max_retries: ?u32,
    send_preflight_commitment: ?Commitment,

    pub fn deinit(self: *ParsedArgs, allocator: Allocator) void {
        self.signature_statuses.deinit(allocator);
        self.multiple_accounts.deinit(allocator);
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
        .block_production_identity_arg = null,
        .block_production_first_slot_arg = null,
        .block_production_last_slot_arg = null,
        .delinquent_slot_distance_arg = null,
        .encoding_arg = null,
        .epoch_arg = null,
        .feature_key_arg = null,
        .largest_filter_arg = null,
        .max_supported_transaction_version_arg = null,
        .program_data_size_arg = null,
        .program_data_slice_length_arg = null,
        .program_data_slice_offset_arg = null,
        .program_memcmp_bytes_arg = null,
        .program_memcmp_offset_arg = null,
        .signatures_for_address_arg = null,
        .signatures_for_address_before_arg = null,
        .signatures_for_address_until_arg = null,
        .signatures_for_address_limit_arg = null,
        .rewards_arg = null,
        .slot_arg = null,
        .blocks_end_slot_arg = null,
        .blocks_limit_arg = null,
        .message_arg = null,
        .slot_leaders_limit_arg = null,
        .performance_limit_arg = null,
        .leader_schedule_slot_arg = null,
        .leader_schedule_identity_arg = null,
        .lamports_arg = null,
        .mint_arg = null,
        .rent_bytes_arg = null,
        .signed_tx_arg = null,
        .supply_exclude_non_circulating_accounts_list = false,
        .token_program_id_arg = null,
        .transaction_details_arg = null,
        .vote_pubkey_arg = null,
        .signature_statuses = .{},
        .multiple_accounts = .{},
        .commitment = null,
        .status_timeout_ms = 30_000,
        .status_poll_ms = 500,
        .send_skip_preflight = false,
        .simulate_replace_recent_blockhash = false,
        .simulate_sig_verify = false,
        .vote_keep_unstaked_delinquents = false,
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

        if (std.mem.eql(u8, arg, "--sig-verify")) {
            parsed.simulate_sig_verify = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--replace-recent-blockhash")) {
            parsed.simulate_replace_recent_blockhash = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--keep-unstaked-delinquents")) {
            parsed.vote_keep_unstaked_delinquents = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--exclude-non-circulating-accounts-list")) {
            parsed.supply_exclude_non_circulating_accounts_list = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--max-retries")) {
            if (index >= args.len) return error.InvalidCli;
            parsed.send_max_retries = std.fmt.parseInt(u32, args[index], 10) catch return error.InvalidCli;
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--epoch")) {
            if (index >= args.len or parsed.epoch_arg != null) return error.InvalidCli;
            parsed.epoch_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--encoding")) {
            if (index >= args.len or parsed.encoding_arg != null) return error.InvalidCli;
            parsed.encoding_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--max-supported-transaction-version")) {
            if (index >= args.len or parsed.max_supported_transaction_version_arg != null) return error.InvalidCli;
            parsed.max_supported_transaction_version_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--transaction-details")) {
            if (index >= args.len or parsed.transaction_details_arg != null) return error.InvalidCli;
            parsed.transaction_details_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--rewards")) {
            if (index >= args.len or parsed.rewards_arg != null) return error.InvalidCli;
            parsed.rewards_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--vote-pubkey")) {
            if (index >= args.len or parsed.vote_pubkey_arg != null) return error.InvalidCli;
            parsed.vote_pubkey_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--delinquent-slot-distance")) {
            if (index >= args.len or parsed.delinquent_slot_distance_arg != null) return error.InvalidCli;
            parsed.delinquent_slot_distance_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--largest-filter")) {
            if (index >= args.len or parsed.largest_filter_arg != null) return error.InvalidCli;
            parsed.largest_filter_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--block-production-identity")) {
            if (index >= args.len or parsed.block_production_identity_arg != null) return error.InvalidCli;
            parsed.block_production_identity_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--range-first-slot")) {
            if (index >= args.len or parsed.block_production_first_slot_arg != null) return error.InvalidCli;
            parsed.block_production_first_slot_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--range-last-slot")) {
            if (index >= args.len or parsed.block_production_last_slot_arg != null) return error.InvalidCli;
            parsed.block_production_last_slot_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--program-data-size")) {
            if (index >= args.len or parsed.program_data_size_arg != null) return error.InvalidCli;
            parsed.program_data_size_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--program-memcmp-offset")) {
            if (index >= args.len or parsed.program_memcmp_offset_arg != null) return error.InvalidCli;
            parsed.program_memcmp_offset_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--program-memcmp-bytes")) {
            if (index >= args.len or parsed.program_memcmp_bytes_arg != null) return error.InvalidCli;
            parsed.program_memcmp_bytes_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--program-data-slice-offset")) {
            if (index >= args.len or parsed.program_data_slice_offset_arg != null) return error.InvalidCli;
            parsed.program_data_slice_offset_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--program-data-slice-length")) {
            if (index >= args.len or parsed.program_data_slice_length_arg != null) return error.InvalidCli;
            parsed.program_data_slice_length_arg = args[index];
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

        if (std.mem.eql(u8, arg, "--mint")) {
            if (index >= args.len or parsed.mint_arg != null) return error.InvalidCli;
            parsed.mint_arg = args[index];
            index += 1;
            continue;
        }

        if (std.mem.eql(u8, arg, "--token-program-id")) {
            if (index >= args.len or parsed.token_program_id_arg != null) return error.InvalidCli;
            parsed.token_program_id_arg = args[index];
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

            if (std.mem.eql(u8, arg, "simulate-transaction")) {
                parsed.command = .simulate_transaction;
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

            if (std.mem.eql(u8, arg, "transaction")) {
                parsed.command = .transaction;
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

            if (std.mem.eql(u8, arg, "multiple-accounts")) {
                parsed.command = .multiple_accounts;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "program-accounts")) {
                parsed.command = .program_accounts;
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

            if (std.mem.eql(u8, arg, "inflation-reward")) {
                parsed.command = .inflation_reward;
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

            if (std.mem.eql(u8, arg, "block-commitment")) {
                parsed.command = .block_commitment;
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

            if (std.mem.eql(u8, arg, "slot-leader")) {
                parsed.command = .slot_leader;
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

            if (std.mem.eql(u8, arg, "largest-accounts")) {
                parsed.command = .largest_accounts;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "token-account-balance")) {
                parsed.command = .token_account_balance;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "token-supply")) {
                parsed.command = .token_supply;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "token-largest-accounts")) {
                parsed.command = .token_largest_accounts;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "token-accounts-by-owner")) {
                parsed.command = .token_accounts_by_owner;
                parsed.has_command = true;
                continue;
            }

            if (std.mem.eql(u8, arg, "token-accounts-by-delegate")) {
                parsed.command = .token_accounts_by_delegate;
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
            .latest_blockhash, .slot, .block_height, .transaction_count, .version, .epoch_info, .health, .genesis_hash, .supply, .epoch_schedule, .inflation_rate, .highest_snapshot_slot, .first_available_block, .identity, .cluster_nodes, .vote_accounts, .block_production, .inflation_governor, .minimum_ledger_slot, .max_retransmit_slot, .max_shred_insert_slot, .largest_accounts, .slot_leader => return error.InvalidCli,

            .stake_minimum_delegation => return error.InvalidCli,

            .signatures_for_address => if (parsed.signatures_for_address_arg == null) {
                parsed.signatures_for_address_arg = arg;
            } else {
                return error.InvalidCli;
            },

            .status, .signature_status, .transaction => if (parsed.signature == null) {
                parsed.signature = arg;
            } else {
                return error.InvalidCli;
            },

            .signature_statuses => {
                parsed.signature_statuses.append(allocator, arg) catch return error.InvalidCli;
            },

            .send_transaction, .send_transaction_and_confirm, .simulate_transaction => if (parsed.signed_tx_arg == null) {
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

            .multiple_accounts, .inflation_reward, .recent_prioritization_fees => {
                parsed.multiple_accounts.append(allocator, arg) catch return error.InvalidCli;
            },

            .program_accounts, .token_account_balance, .token_supply, .token_largest_accounts, .token_accounts_by_owner, .token_accounts_by_delegate => if (parsed.account == null) {
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

            .block_commitment => if (parsed.slot_arg == null) {
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
    multiple_accounts,
    program_accounts,
    signatures_for_address,
    status,
    signature_status,
    signature_statuses,
    send_transaction,
    send_transaction_and_confirm,
    simulate_transaction,
    slot,
    block_height,
    transaction_count,
    transaction,
    balance,
    request_airdrop,
    minimum_rent_exemption,
    feature_activation_slot,
    blockhash_valid,
    version,
    stake_minimum_delegation,
    largest_accounts,
    token_account_balance,
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
    try std.testing.expect(std.mem.indexOf(u8, usage, "block-commitment <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "block <slot>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "slot-leader") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "stake-minimum-delegation") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "account-info <account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "multiple-accounts <account-1> [account-2 ...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "program-accounts <program-id>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "largest-accounts") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-account-balance <token-account>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-supply <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-largest-accounts <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "inflation-reward <address-1> [address-2 ...] [--epoch <epoch>]") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "transaction <signature>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "simulate-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-accounts-by-owner <owner>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "token-accounts-by-delegate <delegate>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "send-transaction-and-confirm <signed-tx-base64>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--skip-preflight") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--sig-verify") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--replace-recent-blockhash") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--max-retries <count>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--preflight-commitment") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, usage, "--mint <mint>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "--token-program-id <program-id>") != null);
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

test "cli.parseCliArgs parses simulate-transaction with simulation options" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "simulate-transaction",
        "--sig-verify",
        "--replace-recent-blockhash",
        "--commitment",
        "processed",
        "signed-raw-transaction",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.simulate_transaction, parsed.command);
    try std.testing.expectEqualStrings("signed-raw-transaction", parsed.signed_tx_arg orelse "");
    try std.testing.expect(parsed.simulate_sig_verify);
    try std.testing.expect(parsed.simulate_replace_recent_blockhash);
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

test "cli.parseCliArgs parses program accounts" {
    var parsed = try parseCliArgs(std.testing.allocator, &.{
        "program-accounts",
        "Program1111111111111111111111111111111111",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(Command.program_accounts, parsed.command);
    try std.testing.expectEqualStrings("Program1111111111111111111111111111111111", parsed.account orelse "");
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
