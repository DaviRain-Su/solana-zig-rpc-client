const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("../cli.zig");

const Allocator = std.mem.Allocator;

pub const InvokeFamily = enum {
    instructions,
    program,
    anchor_idl,
};

pub const CliInvokeContextArgs = struct {
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,
    additional_signer_secret_keys_arg: []const []const u8,
};

pub const CliInvokePayloadArgs = struct {
    instructions_spec_arg: ?[]const u8,
    program_id_arg: ?[]const u8,
    program_accounts_arg: ?[]const u8,
    program_data_arg: ?[]const u8,
    program_data_encoding_arg: ?[]const u8,
    idl_arg: ?[]const u8,
    idl_instruction_arg: ?[]const u8,
    idl_program_id_arg: ?[]const u8,
    idl_args_json_arg: ?[]const u8,
    idl_accounts_json_arg: ?[]const u8,
    idl_account_bindings: []const []const u8,
    idl_remaining_accounts: []const []const u8,
    idl_remaining_accounts_json_arg: ?[]const u8,
};

pub const CliInvokeExecutionArgs = struct {
    commitment: ?client.Commitment,
    send_preflight_commitment: ?client.Commitment,
    send_transaction_options: ?client.SendTransactionOptions,
    search_transaction_history: bool,
    status_timeout_ms: u64,
    status_poll_ms: u64,
    simulation_account_encoding_arg: ?[]const u8,
    simulation_min_context_slot_arg: ?[]const u8,
    simulation_accounts: []const []const u8,
    simulate_sig_verify: bool,
    simulate_replace_recent_blockhash: bool,
    simulate_inner_instructions: bool,
};

pub const CliInvokeCommandBehavior = struct {
    family: InvokeFamily,
    versioned: bool,
    simulate: bool,
    confirm: bool,
};

pub const CliInvokeCommandSpec = struct {
    command: cli.Command,
    label: []const u8,
    behavior: CliInvokeCommandBehavior,
};

pub fn buildCliInvokeContextArgs(
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,
    additional_signer_secret_keys_arg: []const []const u8,
) CliInvokeContextArgs {
    return .{
        .payer_keypair_path_arg = payer_keypair_path_arg,
        .payer_secret_key_arg = payer_secret_key_arg,
        .signer_keypair_paths_arg = signer_keypair_paths_arg,
        .lookup_tables_arg = lookup_tables_arg,
        .recent_blockhash_arg = recent_blockhash_arg,
        .nonce_account_arg = nonce_account_arg,
        .nonce_authority_keypair_path_arg = nonce_authority_keypair_path_arg,
        .additional_signer_secret_keys_arg = additional_signer_secret_keys_arg,
    };
}

pub fn buildCliInvokePayloadArgs(
    instructions_spec_arg: ?[]const u8,
    program_id_arg: ?[]const u8,
    program_accounts_arg: ?[]const u8,
    program_data_arg: ?[]const u8,
    program_data_encoding_arg: ?[]const u8,
    idl_arg: ?[]const u8,
    idl_instruction_arg: ?[]const u8,
    idl_program_id_arg: ?[]const u8,
    idl_args_json_arg: ?[]const u8,
    idl_accounts_json_arg: ?[]const u8,
    idl_account_bindings: []const []const u8,
    idl_remaining_accounts: []const []const u8,
    idl_remaining_accounts_json_arg: ?[]const u8,
) CliInvokePayloadArgs {
    return .{
        .instructions_spec_arg = instructions_spec_arg,
        .program_id_arg = program_id_arg,
        .program_accounts_arg = program_accounts_arg,
        .program_data_arg = program_data_arg,
        .program_data_encoding_arg = program_data_encoding_arg,
        .idl_arg = idl_arg,
        .idl_instruction_arg = idl_instruction_arg,
        .idl_program_id_arg = idl_program_id_arg,
        .idl_args_json_arg = idl_args_json_arg,
        .idl_accounts_json_arg = idl_accounts_json_arg,
        .idl_account_bindings = idl_account_bindings,
        .idl_remaining_accounts = idl_remaining_accounts,
        .idl_remaining_accounts_json_arg = idl_remaining_accounts_json_arg,
    };
}

pub fn buildCliInvokeExecutionArgs(
    commitment: ?client.Commitment,
    send_preflight_commitment: ?client.Commitment,
    send_transaction_options: ?client.SendTransactionOptions,
    search_transaction_history: bool,
    status_timeout_ms: u64,
    status_poll_ms: u64,
    simulation_account_encoding_arg: ?[]const u8,
    simulation_min_context_slot_arg: ?[]const u8,
    simulation_accounts: []const []const u8,
    simulate_sig_verify: bool,
    simulate_replace_recent_blockhash: bool,
    simulate_inner_instructions: bool,
) CliInvokeExecutionArgs {
    return .{
        .commitment = commitment,
        .send_preflight_commitment = send_preflight_commitment,
        .send_transaction_options = send_transaction_options,
        .search_transaction_history = search_transaction_history,
        .status_timeout_ms = status_timeout_ms,
        .status_poll_ms = status_poll_ms,
        .simulation_account_encoding_arg = simulation_account_encoding_arg,
        .simulation_min_context_slot_arg = simulation_min_context_slot_arg,
        .simulation_accounts = simulation_accounts,
        .simulate_sig_verify = simulate_sig_verify,
        .simulate_replace_recent_blockhash = simulate_replace_recent_blockhash,
        .simulate_inner_instructions = simulate_inner_instructions,
    };
}

pub const cli_invoke_command_specs = [_]CliInvokeCommandSpec{
    .{ .command = .send_instructions, .label = "send-instructions", .behavior = .{ .family = .instructions, .versioned = false, .simulate = false, .confirm = false } },
    .{ .command = .send_instructions_and_confirm, .label = "send-instructions-and-confirm", .behavior = .{ .family = .instructions, .versioned = false, .simulate = false, .confirm = true } },
    .{ .command = .send_versioned_instructions, .label = "send-versioned-instructions", .behavior = .{ .family = .instructions, .versioned = true, .simulate = false, .confirm = false } },
    .{ .command = .send_versioned_instructions_and_confirm, .label = "send-versioned-instructions-and-confirm", .behavior = .{ .family = .instructions, .versioned = true, .simulate = false, .confirm = true } },
    .{ .command = .simulate_instructions, .label = "simulate-instructions", .behavior = .{ .family = .instructions, .versioned = false, .simulate = true, .confirm = false } },
    .{ .command = .simulate_versioned_instructions, .label = "simulate-versioned-instructions", .behavior = .{ .family = .instructions, .versioned = true, .simulate = true, .confirm = false } },

    .{ .command = .send_program_invoke, .label = "send-program-invoke", .behavior = .{ .family = .program, .versioned = false, .simulate = false, .confirm = false } },
    .{ .command = .send_program_invoke_and_confirm, .label = "send-program-invoke-and-confirm", .behavior = .{ .family = .program, .versioned = false, .simulate = false, .confirm = true } },
    .{ .command = .send_versioned_program_invoke, .label = "send-versioned-program-invoke", .behavior = .{ .family = .program, .versioned = true, .simulate = false, .confirm = false } },
    .{ .command = .send_versioned_program_invoke_and_confirm, .label = "send-versioned-program-invoke-and-confirm", .behavior = .{ .family = .program, .versioned = true, .simulate = false, .confirm = true } },
    .{ .command = .simulate_program_invoke, .label = "simulate-program-invoke", .behavior = .{ .family = .program, .versioned = false, .simulate = true, .confirm = false } },
    .{ .command = .simulate_versioned_program_invoke, .label = "simulate-versioned-program-invoke", .behavior = .{ .family = .program, .versioned = true, .simulate = true, .confirm = false } },

    .{ .command = .send_idl_invoke, .label = "send-idl-invoke", .behavior = .{ .family = .anchor_idl, .versioned = false, .simulate = false, .confirm = false } },
    .{ .command = .send_idl_invoke_and_confirm, .label = "send-idl-invoke-and-confirm", .behavior = .{ .family = .anchor_idl, .versioned = false, .simulate = false, .confirm = true } },
    .{ .command = .send_versioned_idl_invoke, .label = "send-versioned-idl-invoke", .behavior = .{ .family = .anchor_idl, .versioned = true, .simulate = false, .confirm = false } },
    .{ .command = .send_versioned_idl_invoke_and_confirm, .label = "send-versioned-idl-invoke-and-confirm", .behavior = .{ .family = .anchor_idl, .versioned = true, .simulate = false, .confirm = true } },
    .{ .command = .simulate_idl_invoke, .label = "simulate-idl-invoke", .behavior = .{ .family = .anchor_idl, .versioned = false, .simulate = true, .confirm = false } },
    .{ .command = .simulate_versioned_idl_invoke, .label = "simulate-versioned-idl-invoke", .behavior = .{ .family = .anchor_idl, .versioned = true, .simulate = true, .confirm = false } },
};

pub fn lookupInvokeCommandSpec(command: cli.Command) ?CliInvokeCommandSpec {
    inline for (cli_invoke_command_specs) |spec| {
        if (spec.command == command) return spec;
    }
    return null;
}

pub fn sendInvocationSpecJson(
    allocator: Allocator,
    rpc: *client.RpcClient,
    family: InvokeFamily,
    versioned: bool,
    confirm: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    send_transaction_options: anytype,
    confirm_commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            if (confirm)
                client.instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .instruction_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .instruction_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
        .program => if (versioned)
            if (confirm)
                client.program_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .program_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.program_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .program_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.program_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.program_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
        .anchor_idl => if (versioned)
            if (confirm)
                client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                    .anchor_idl_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.anchor_idl_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                    .anchor_idl_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
    };
}

pub fn simulateInvocationSpecJson(
    allocator: Allocator,
    rpc: *client.RpcClient,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    simulate_options: ?client.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
        .program => if (versioned)
            client.program_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.program_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
    };
}

pub fn buildInvocationSpecJsonForCommand(
    allocator: Allocator,
    command: cli.Command,
    behavior: CliInvokeCommandBehavior,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    builders: anytype,
) ![]u8 {
    return switch (behavior.family) {
        .instructions => builders.buildInstructions(
            allocator,
            command,
            payload_args.instructions_spec_arg,
            context_args.payer_keypair_path_arg,
            context_args.payer_secret_key_arg,
            context_args.additional_signer_secret_keys_arg,
            context_args.recent_blockhash_arg,
        ),
        .program => builders.buildProgram(
            allocator,
            command,
            payload_args.program_id_arg,
            payload_args.program_accounts_arg,
            payload_args.program_data_arg,
            payload_args.program_data_encoding_arg,
            context_args.payer_keypair_path_arg,
            context_args.payer_secret_key_arg,
            context_args.signer_keypair_paths_arg,
            if (behavior.versioned) context_args.lookup_tables_arg else null,
            context_args.recent_blockhash_arg,
            context_args.nonce_account_arg,
            context_args.nonce_authority_keypair_path_arg,
            context_args.additional_signer_secret_keys_arg,
        ),
        .anchor_idl => builders.buildAnchorIdl(
            allocator,
            command,
            payload_args.idl_arg,
            payload_args.idl_instruction_arg,
            payload_args.idl_program_id_arg,
            payload_args.idl_args_json_arg,
            payload_args.idl_accounts_json_arg,
            payload_args.idl_account_bindings,
            payload_args.idl_remaining_accounts,
            payload_args.idl_remaining_accounts_json_arg,
            context_args.payer_keypair_path_arg,
            context_args.payer_secret_key_arg,
            context_args.signer_keypair_paths_arg,
            if (behavior.versioned) context_args.lookup_tables_arg else null,
            context_args.recent_blockhash_arg,
            context_args.nonce_account_arg,
            context_args.nonce_authority_keypair_path_arg,
            context_args.additional_signer_secret_keys_arg,
        ),
    };
}

pub fn runGenericInvocationCommand(
    allocator: Allocator,
    rpc: *client.RpcClient,
    command: cli.Command,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    execution_args: CliInvokeExecutionArgs,
    callbacks: anytype,
) !void {
    const spec = lookupInvokeCommandSpec(command) orelse unreachable;
    const behavior = spec.behavior;
    const invocation_spec_json = try buildInvocationSpecJsonForCommand(
        allocator,
        command,
        behavior,
        payload_args,
        context_args,
        callbacks.builders,
    );
    defer allocator.free(invocation_spec_json);

    if (behavior.simulate) {
        const options = try callbacks.buildSimulationOptions(execution_args);
        const simulation = try simulateInvocationSpecJson(
            allocator,
            rpc,
            behavior.family,
            behavior.versioned,
            invocation_spec_json,
            execution_args.commitment,
            options,
        );
        defer callbacks.freeSimulation(allocator, simulation);

        callbacks.printSimulationResult(simulation);
        return;
    }

    const tx_signature = try sendInvocationSpecJson(
        allocator,
        rpc,
        behavior.family,
        behavior.versioned,
        behavior.confirm,
        invocation_spec_json,
        execution_args.commitment orelse execution_args.send_preflight_commitment,
        execution_args.send_transaction_options,
        execution_args.commitment,
        execution_args.search_transaction_history,
        execution_args.status_timeout_ms,
        execution_args.status_poll_ms,
    );
    defer allocator.free(tx_signature);

    if (behavior.confirm) {
        std.debug.print("confirmed signature: {s}\n", .{tx_signature});
    } else {
        std.debug.print("signature: {s}\n", .{tx_signature});
    }
}
