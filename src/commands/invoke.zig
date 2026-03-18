const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("../cli.zig");

const Allocator = std.mem.Allocator;

pub const InvokeFamily = client.invoke.InvokeFamily;

pub const CliInvokeContextArgs = struct {
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_secret_key_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,
    additional_signer_secret_keys_arg: []const []const u8,
};

pub const CliInvokePayloadArgs = struct {
    instructions_spec_arg: ?[]const u8,
    instruction_json_args: []const []const u8,
    program_id_arg: ?[]const u8,
    program_accounts_arg: ?[]const u8,
    program_data_arg: ?[]const u8,
    program_data_encoding_arg: ?[]const u8,
    program_data_schema_json_arg: ?[]const u8,
    program_args_json_arg: ?[]const u8,
    program_schema_encoding_arg: ?[]const u8,
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

pub const CliInvokeBuilderCallbacks = struct {
    buildInstructions: *const fn (Allocator, cli.Command, ?[]const u8, []const []const u8, ?[]const u8, ?[]const u8, []const []const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8) anyerror![]u8,
    buildProgram: *const fn (Allocator, cli.Command, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8) anyerror![]u8,
    buildProgramPayload: ?*const fn (Allocator, cli.Command, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8) anyerror![]u8 = null,
    buildAnchorIdl: *const fn (Allocator, cli.Command, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8, []const []const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8) anyerror![]u8,
    buildAnchorIdlPayload: ?*const fn (Allocator, cli.Command, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8, []const []const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, ?[]const u8, []const []const u8) anyerror![]u8 = null,
};

pub const CliInvokeRuntimeCallbacks = struct {
    builders: CliInvokeBuilderCallbacks,
    buildSimulationOptions: *const fn (CliInvokeExecutionArgs) anyerror!?client.SimulateTransactionOptions,
    freeSimulation: *const fn (Allocator, client.SimulatedTransaction) void,
    printSimulationResult: *const fn (client.SimulatedTransaction) void,
};

pub const CliInvokeCommandBehavior = struct {
    payload_family: InvokeFamily,
    execution_family: InvokeFamily = .instructions,
    versioned: bool,
    simulate: bool,
    confirm: bool,

    fn executionFamily(self: @This()) InvokeFamily {
        return self.execution_family;
    }

    fn buildPayloadSource(
        self: @This(),
        command: cli.Command,
        payload_args: CliInvokePayloadArgs,
        context_args: CliInvokeContextArgs,
    ) CliInvokePayloadSource {
        return buildCliInvokePayloadSource(self.payload_family, .{
            .command = command,
            .payload_args = payload_args,
            .context_args = context_args,
            .versioned = self.versioned,
        });
    }
};

pub const CliInvokeCommandSpec = struct {
    command: cli.Command,
    label: []const u8,
    behavior: CliInvokeCommandBehavior,

    fn executionFamily(self: @This()) InvokeFamily {
        return self.behavior.executionFamily();
    }

    fn buildPayloadSource(
        self: @This(),
        payload_args: CliInvokePayloadArgs,
        context_args: CliInvokeContextArgs,
    ) CliInvokePayloadSource {
        return self.behavior.buildPayloadSource(self.command, payload_args, context_args);
    }

    fn buildInvocationSpecJson(
        self: @This(),
        allocator: Allocator,
        payload_args: CliInvokePayloadArgs,
        context_args: CliInvokeContextArgs,
        builders: anytype,
    ) ![]u8 {
        return self.buildPayloadSource(payload_args, context_args).buildInvocationSpecJson(allocator, builders);
    }
};

pub const CliInvokeCanonicalSpecCommand = struct {
    command: cli.Command,
    label: []const u8,
    payload_family: InvokeFamily,
    invalid_error_message: []const u8,
};

const CliInvokePayloadBuilderInputs = struct {
    command: cli.Command,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    versioned: bool,
};

const CliInvokeInstructionsPayloadBuilderInputs = struct {
    command: cli.Command,
    instructions_spec_arg: ?[]const u8,
    instruction_json_args: []const []const u8,
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    additional_signer_secret_keys_arg: []const []const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_secret_key_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,

    fn buildInvocationSpecJson(self: @This(), allocator: Allocator, builders: anytype) ![]u8 {
        return builders.buildInstructions(
            allocator,
            self.command,
            self.instructions_spec_arg,
            self.instruction_json_args,
            self.payer_keypair_path_arg,
            self.payer_secret_key_arg,
            self.additional_signer_secret_keys_arg,
            self.signer_keypair_paths_arg,
            self.lookup_tables_arg,
            self.recent_blockhash_arg,
            self.nonce_account_arg,
            self.nonce_authority_secret_key_arg,
            self.nonce_authority_keypair_path_arg,
        );
    }
};

const CliInvokeSingleInstructionBuilderContext = struct {
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_secret_key_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,
    additional_signer_secret_keys_arg: []const []const u8,
};

const CliInvokeProgramPayloadBuilderArgs = struct {
    program_id_arg: ?[]const u8,
    program_accounts_arg: ?[]const u8,
    program_data_arg: ?[]const u8,
    program_data_encoding_arg: ?[]const u8,
    program_data_schema_json_arg: ?[]const u8,
    program_args_json_arg: ?[]const u8,
    program_schema_encoding_arg: ?[]const u8,
};

const CliInvokeAnchorIdlPayloadBuilderArgs = struct {
    idl_arg: ?[]const u8,
    idl_instruction_arg: ?[]const u8,
    idl_program_id_arg: ?[]const u8,
    idl_args_json_arg: ?[]const u8,
    idl_accounts_json_arg: ?[]const u8,
    idl_account_bindings: []const []const u8,
    idl_remaining_accounts: []const []const u8,
    idl_remaining_accounts_json_arg: ?[]const u8,
};

const CliInvokeSingleInstructionPayloadSource = union(enum) {
    program: CliInvokeProgramPayloadBuilderArgs,
    anchor_idl: CliInvokeAnchorIdlPayloadBuilderArgs,
};

const CliInvokeSingleInstructionBuilderInputs = struct {
    command: cli.Command,
    payload_source: CliInvokeSingleInstructionPayloadSource,
    context: CliInvokeSingleInstructionBuilderContext,

    fn buildInvocationSpecJson(self: @This(), allocator: Allocator, builders: anytype) ![]u8 {
        return switch (self.payload_source) {
            .program => |program_args| builders.buildProgram(
                allocator,
                self.command,
                program_args.program_id_arg,
                program_args.program_accounts_arg,
                program_args.program_data_arg,
                program_args.program_data_encoding_arg,
                program_args.program_data_schema_json_arg,
                program_args.program_args_json_arg,
                program_args.program_schema_encoding_arg,
                self.context.payer_keypair_path_arg,
                self.context.payer_secret_key_arg,
                self.context.signer_keypair_paths_arg,
                self.context.lookup_tables_arg,
                self.context.recent_blockhash_arg,
                self.context.nonce_account_arg,
                self.context.nonce_authority_secret_key_arg,
                self.context.nonce_authority_keypair_path_arg,
                self.context.additional_signer_secret_keys_arg,
            ),
            .anchor_idl => |idl_args| builders.buildAnchorIdl(
                allocator,
                self.command,
                idl_args.idl_arg,
                idl_args.idl_instruction_arg,
                idl_args.idl_program_id_arg,
                idl_args.idl_args_json_arg,
                idl_args.idl_accounts_json_arg,
                idl_args.idl_account_bindings,
                idl_args.idl_remaining_accounts,
                idl_args.idl_remaining_accounts_json_arg,
                self.context.payer_keypair_path_arg,
                self.context.payer_secret_key_arg,
                self.context.signer_keypair_paths_arg,
                self.context.lookup_tables_arg,
                self.context.recent_blockhash_arg,
                self.context.nonce_account_arg,
                self.context.nonce_authority_secret_key_arg,
                self.context.nonce_authority_keypair_path_arg,
                self.context.additional_signer_secret_keys_arg,
            ),
        };
    }
};

const CliInvokePayloadSource = union(enum) {
    instructions: CliInvokeInstructionsPayloadBuilderInputs,
    single_instruction: CliInvokeSingleInstructionBuilderInputs,

    fn buildInvocationSpecJson(self: @This(), allocator: Allocator, builders: anytype) ![]u8 {
        return switch (self) {
            .instructions => |instruction_inputs| instruction_inputs.buildInvocationSpecJson(allocator, builders),
            .single_instruction => |single_instruction_inputs| single_instruction_inputs.buildInvocationSpecJson(allocator, builders),
        };
    }
};

fn buildCliInvokeCommandBehavior(
    payload_family: InvokeFamily,
    versioned: bool,
    simulate: bool,
    confirm: bool,
) CliInvokeCommandBehavior {
    return .{
        .payload_family = payload_family,
        .versioned = versioned,
        .simulate = simulate,
        .confirm = confirm,
    };
}

fn buildCliInvokeCommandSpec(
    command: cli.Command,
    label: []const u8,
    payload_family: InvokeFamily,
    versioned: bool,
    simulate: bool,
    confirm: bool,
) CliInvokeCommandSpec {
    return .{
        .command = command,
        .label = label,
        .behavior = buildCliInvokeCommandBehavior(payload_family, versioned, simulate, confirm),
    };
}

pub fn buildCliInvokeContextArgs(
    payer_keypair_path_arg: ?[]const u8,
    payer_secret_key_arg: ?[]const u8,
    signer_keypair_paths_arg: ?[]const u8,
    lookup_tables_arg: ?[]const u8,
    recent_blockhash_arg: ?[]const u8,
    nonce_account_arg: ?[]const u8,
    nonce_authority_secret_key_arg: ?[]const u8,
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
        .nonce_authority_secret_key_arg = nonce_authority_secret_key_arg,
        .nonce_authority_keypair_path_arg = nonce_authority_keypair_path_arg,
        .additional_signer_secret_keys_arg = additional_signer_secret_keys_arg,
    };
}

pub fn buildCliInvokePayloadArgs(
    instructions_spec_arg: ?[]const u8,
    instruction_json_args: []const []const u8,
    program_id_arg: ?[]const u8,
    program_accounts_arg: ?[]const u8,
    program_data_arg: ?[]const u8,
    program_data_encoding_arg: ?[]const u8,
    program_data_schema_json_arg: ?[]const u8,
    program_args_json_arg: ?[]const u8,
    program_schema_encoding_arg: ?[]const u8,
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
        .instruction_json_args = instruction_json_args,
        .program_id_arg = program_id_arg,
        .program_accounts_arg = program_accounts_arg,
        .program_data_arg = program_data_arg,
        .program_data_encoding_arg = program_data_encoding_arg,
        .program_data_schema_json_arg = program_data_schema_json_arg,
        .program_args_json_arg = program_args_json_arg,
        .program_schema_encoding_arg = program_schema_encoding_arg,
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
    buildCliInvokeCommandSpec(.send_instructions, "send-instructions", .instructions, false, false, false),
    buildCliInvokeCommandSpec(.send_instructions_and_confirm, "send-instructions-and-confirm", .instructions, false, false, true),
    buildCliInvokeCommandSpec(.send_versioned_instructions, "send-versioned-instructions", .instructions, true, false, false),
    buildCliInvokeCommandSpec(.send_versioned_instructions_and_confirm, "send-versioned-instructions-and-confirm", .instructions, true, false, true),
    buildCliInvokeCommandSpec(.simulate_instructions, "simulate-instructions", .instructions, false, true, false),
    buildCliInvokeCommandSpec(.simulate_versioned_instructions, "simulate-versioned-instructions", .instructions, true, true, false),

    buildCliInvokeCommandSpec(.send_program_invoke, "send-program-invoke", .program, false, false, false),
    buildCliInvokeCommandSpec(.send_program_invoke_and_confirm, "send-program-invoke-and-confirm", .program, false, false, true),
    buildCliInvokeCommandSpec(.send_versioned_program_invoke, "send-versioned-program-invoke", .program, true, false, false),
    buildCliInvokeCommandSpec(.send_versioned_program_invoke_and_confirm, "send-versioned-program-invoke-and-confirm", .program, true, false, true),
    buildCliInvokeCommandSpec(.simulate_program_invoke, "simulate-program-invoke", .program, false, true, false),
    buildCliInvokeCommandSpec(.simulate_versioned_program_invoke, "simulate-versioned-program-invoke", .program, true, true, false),

    buildCliInvokeCommandSpec(.send_idl_invoke, "send-idl-invoke", .anchor_idl, false, false, false),
    buildCliInvokeCommandSpec(.send_idl_invoke_and_confirm, "send-idl-invoke-and-confirm", .anchor_idl, false, false, true),
    buildCliInvokeCommandSpec(.send_versioned_idl_invoke, "send-versioned-idl-invoke", .anchor_idl, true, false, false),
    buildCliInvokeCommandSpec(.send_versioned_idl_invoke_and_confirm, "send-versioned-idl-invoke-and-confirm", .anchor_idl, true, false, true),
    buildCliInvokeCommandSpec(.simulate_idl_invoke, "simulate-idl-invoke", .anchor_idl, false, true, false),
    buildCliInvokeCommandSpec(.simulate_versioned_idl_invoke, "simulate-versioned-idl-invoke", .anchor_idl, true, true, false),
};

pub const cli_invoke_canonical_spec_commands = [_]CliInvokeCanonicalSpecCommand{
    .{
        .command = .spec_instructions,
        .label = "spec-instructions",
        .payload_family = .instructions,
        .invalid_error_message = "error: spec-instructions spec is invalid\n",
    },
    .{
        .command = .spec_program_invoke,
        .label = "spec-program-invoke",
        .payload_family = .program,
        .invalid_error_message = "error: spec-program-invoke arguments are invalid\n",
    },
    .{
        .command = .spec_idl_invoke,
        .label = "spec-idl-invoke",
        .payload_family = .anchor_idl,
        .invalid_error_message = "error: spec-idl-invoke arguments are invalid\n",
    },
};

pub fn lookupInvokeCommandSpec(command: cli.Command) ?CliInvokeCommandSpec {
    inline for (cli_invoke_command_specs) |spec| {
        if (spec.command == command) return spec;
    }
    return null;
}

pub fn lookupCanonicalSpecCommand(command: cli.Command) ?CliInvokeCanonicalSpecCommand {
    inline for (cli_invoke_canonical_spec_commands) |spec| {
        if (spec.command == command) return spec;
    }
    return null;
}

pub fn lookupInvokeCommandLabel(command: cli.Command) ?[]const u8 {
    if (lookupInvokeCommandSpec(command)) |spec| return spec.label;

    return switch (command) {
        .invoke_instructions => "invoke-instructions",
        .invoke_instructions_and_confirm => "invoke-instructions-and-confirm",
        .invoke_instructions_simulate => "invoke-instructions-simulate",
        .invoke_spec => "invoke-spec",
        .invoke_spec_and_confirm => "invoke-spec-and-confirm",
        .invoke_spec_simulate => "invoke-spec-simulate",
        .preview_spec => "preview-spec",
        .explain_spec => "explain-spec",
        .validate_spec => "validate-spec",
        .inspect_spec => "inspect-spec",
        .prepare_spec => "prepare-spec",
        .estimate_spec_fee => "estimate-spec-fee",
        .preview_instructions => "preview-instructions",
        .explain_instructions => "explain-instructions",
        .validate_instructions => "validate-instructions",
        .inspect_instructions => "inspect-instructions",
        .prepare_instructions => "prepare-instructions",
        .estimate_instructions_fee => "estimate-instructions-fee",
        .spec_instructions => "spec-instructions",
        .invoke_program_invoke => "invoke-program-invoke",
        .invoke_program_invoke_and_confirm => "invoke-program-invoke-and-confirm",
        .invoke_program_invoke_simulate => "invoke-program-invoke-simulate",
        .preview_program_invoke => "preview-program-invoke",
        .explain_program_invoke => "explain-program-invoke",
        .validate_program_invoke => "validate-program-invoke",
        .inspect_program_invoke => "inspect-program-invoke",
        .prepare_program_invoke => "prepare-program-invoke",
        .estimate_program_invoke_fee => "estimate-program-invoke-fee",
        .spec_program_invoke => "spec-program-invoke",
        .invoke_idl_invoke => "invoke-idl-invoke",
        .invoke_idl_invoke_and_confirm => "invoke-idl-invoke-and-confirm",
        .invoke_idl_invoke_simulate => "invoke-idl-invoke-simulate",
        .preview_idl_invoke => "preview-idl-invoke",
        .explain_idl_invoke => "explain-idl-invoke",
        .validate_idl_invoke => "validate-idl-invoke",
        .inspect_idl_invoke => "inspect-idl-invoke",
        .prepare_idl_invoke => "prepare-idl-invoke",
        .estimate_idl_invoke_fee => "estimate-idl-invoke-fee",
        .spec_idl_invoke => "spec-idl-invoke",
        else => null,
    };
}

pub fn isGenericInvocationCommand(command: cli.Command) bool {
    return lookupInvokeCommandSpec(command) != null;
}

pub fn isProgramInvokeCommand(command: cli.Command) bool {
    return switch (command) {
        .send_program_invoke,
        .send_program_invoke_and_confirm,
        .send_versioned_program_invoke,
        .send_versioned_program_invoke_and_confirm,
        .simulate_program_invoke,
        .simulate_versioned_program_invoke,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .invoke_program_invoke_simulate,
        .preview_program_invoke,
        .explain_program_invoke,
        .validate_program_invoke,
        .inspect_program_invoke,
        .prepare_program_invoke,
        .estimate_program_invoke_fee,
        .spec_program_invoke,
        => true,
        else => false,
    };
}

pub fn isIdlInvokeCommand(command: cli.Command) bool {
    return switch (command) {
        .send_idl_invoke,
        .send_idl_invoke_and_confirm,
        .send_versioned_idl_invoke,
        .send_versioned_idl_invoke_and_confirm,
        .simulate_idl_invoke,
        .simulate_versioned_idl_invoke,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        .invoke_idl_invoke_simulate,
        .preview_idl_invoke,
        .explain_idl_invoke,
        .validate_idl_invoke,
        .inspect_idl_invoke,
        .prepare_idl_invoke,
        .estimate_idl_invoke_fee,
        .spec_idl_invoke,
        => true,
        else => false,
    };
}

pub fn isInvocationSendCommand(command: cli.Command) bool {
    if (isGenericInvocationCommand(command)) return true;

    return switch (command) {
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_instructions_simulate,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .invoke_spec_simulate,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .invoke_program_invoke_simulate,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        .invoke_idl_invoke_simulate,
        => true,
        else => false,
    };
}

pub fn supportsRecentBlockhash(command: cli.Command) bool {
    if (isGenericInvocationCommand(command)) return true;

    return switch (command) {
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_instructions_simulate,
        .preview_instructions,
        .explain_instructions,
        .validate_instructions,
        .inspect_instructions,
        .prepare_instructions,
        .estimate_instructions_fee,
        .spec_instructions,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .invoke_spec_simulate,
        .preview_spec,
        .explain_spec,
        .validate_spec,
        .inspect_spec,
        .prepare_spec,
        .estimate_spec_fee,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .invoke_program_invoke_simulate,
        .preview_program_invoke,
        .explain_program_invoke,
        .validate_program_invoke,
        .inspect_program_invoke,
        .prepare_program_invoke,
        .estimate_program_invoke_fee,
        .spec_program_invoke,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        .invoke_idl_invoke_simulate,
        .preview_idl_invoke,
        .explain_idl_invoke,
        .validate_idl_invoke,
        .inspect_idl_invoke,
        .prepare_idl_invoke,
        .estimate_idl_invoke_fee,
        .spec_idl_invoke,
        => true,
        else => false,
    };
}

pub fn supportsJsonOutput(command: cli.Command) bool {
    return switch (command) {
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_instructions_simulate,
        .preview_instructions,
        .explain_instructions,
        .validate_instructions,
        .inspect_instructions,
        .prepare_instructions,
        .estimate_instructions_fee,
        .spec_instructions,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .invoke_spec_simulate,
        .preview_spec,
        .explain_spec,
        .validate_spec,
        .inspect_spec,
        .prepare_spec,
        .estimate_spec_fee,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .invoke_program_invoke_simulate,
        .preview_program_invoke,
        .explain_program_invoke,
        .validate_program_invoke,
        .inspect_program_invoke,
        .prepare_program_invoke,
        .estimate_program_invoke_fee,
        .spec_program_invoke,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        .invoke_idl_invoke_simulate,
        .preview_idl_invoke,
        .explain_idl_invoke,
        .validate_idl_invoke,
        .inspect_idl_invoke,
        .prepare_idl_invoke,
        .estimate_idl_invoke_fee,
        .spec_idl_invoke,
        => true,
        else => false,
    };
}

pub fn supportsWaitOptions(command: cli.Command) bool {
    return switch (command) {
        .status,
        .poll_balance,
        .wait_for_balance,
        .send_transaction_and_confirm,
        .poll_for_signature_confirmation,
        .transfer,
        .send_instructions_and_confirm,
        .send_versioned_instructions_and_confirm,
        .send_program_invoke_and_confirm,
        .send_versioned_program_invoke_and_confirm,
        .send_idl_invoke_and_confirm,
        .send_versioned_idl_invoke_and_confirm,
        .invoke_instructions_and_confirm,
        .invoke_spec_and_confirm,
        .invoke_program_invoke_and_confirm,
        .invoke_idl_invoke_and_confirm,
        => true,
        else => false,
    };
}

pub fn supportsSendOptions(command: cli.Command) bool {
    return switch (command) {
        .send_transaction,
        .send_transaction_and_confirm,
        .transfer,
        .send_instructions,
        .send_instructions_and_confirm,
        .send_versioned_instructions,
        .send_versioned_instructions_and_confirm,
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .send_program_invoke,
        .send_program_invoke_and_confirm,
        .send_versioned_program_invoke,
        .send_versioned_program_invoke_and_confirm,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .send_idl_invoke,
        .send_idl_invoke_and_confirm,
        .send_versioned_idl_invoke,
        .send_versioned_idl_invoke_and_confirm,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        => true,
        else => false,
    };
}

pub fn supportsPreferredInvocationMode(command: cli.Command) bool {
    return switch (command) {
        .send_instructions,
        .send_instructions_and_confirm,
        .send_versioned_instructions,
        .send_versioned_instructions_and_confirm,
        .simulate_instructions,
        .simulate_versioned_instructions,
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_instructions_simulate,
        .preview_instructions,
        .explain_instructions,
        .validate_instructions,
        .inspect_instructions,
        .prepare_instructions,
        .estimate_instructions_fee,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .invoke_spec_simulate,
        .preview_spec,
        .explain_spec,
        .validate_spec,
        .inspect_spec,
        .prepare_spec,
        .estimate_spec_fee,
        .invoke_program_invoke,
        .invoke_program_invoke_and_confirm,
        .invoke_program_invoke_simulate,
        .preview_program_invoke,
        .explain_program_invoke,
        .validate_program_invoke,
        .inspect_program_invoke,
        .prepare_program_invoke,
        .estimate_program_invoke_fee,
        .invoke_idl_invoke,
        .invoke_idl_invoke_and_confirm,
        .invoke_idl_invoke_simulate,
        .preview_idl_invoke,
        .explain_idl_invoke,
        .validate_idl_invoke,
        .inspect_idl_invoke,
        .prepare_idl_invoke,
        .estimate_idl_invoke_fee,
        => true,
        else => false,
    };
}

pub fn supportsSearchTransactionHistory(command: cli.Command) bool {
    return switch (command) {
        .status,
        .confirm_transaction,
        .signature_status,
        .signature_statuses,
        .blocks_since_signature_confirmation,
        .poll_for_signature_confirmation,
        .send_transaction_and_confirm,
        .transfer,
        .send_instructions_and_confirm,
        .send_versioned_instructions_and_confirm,
        .send_program_invoke_and_confirm,
        .send_versioned_program_invoke_and_confirm,
        .send_idl_invoke_and_confirm,
        .send_versioned_idl_invoke_and_confirm,
        .invoke_instructions_and_confirm,
        .invoke_spec_and_confirm,
        .invoke_program_invoke_and_confirm,
        .invoke_idl_invoke_and_confirm,
        => true,
        else => false,
    };
}

pub fn supportsInspectSection(command: cli.Command) bool {
    return switch (command) {
        .inspect_instructions,
        .inspect_spec,
        .inspect_program_invoke,
        .inspect_idl_invoke,
        => true,
        else => false,
    };
}

pub fn supportsInvocationContextOverrides(command: cli.Command) bool {
    return supportsRecentBlockhash(command);
}

pub fn supportsSenderCredentials(command: cli.Command) bool {
    return command == .transfer or supportsInvocationContextOverrides(command);
}

pub fn supportsInstructionJson(command: cli.Command) bool {
    return switch (command) {
        .send_instructions,
        .send_instructions_and_confirm,
        .send_versioned_instructions,
        .send_versioned_instructions_and_confirm,
        .invoke_instructions,
        .invoke_instructions_and_confirm,
        .invoke_instructions_simulate,
        .preview_instructions,
        .explain_instructions,
        .validate_instructions,
        .inspect_instructions,
        .prepare_instructions,
        .estimate_instructions_fee,
        .spec_instructions,
        .invoke_spec,
        .invoke_spec_and_confirm,
        .invoke_spec_simulate,
        .preview_spec,
        .explain_spec,
        .validate_spec,
        .inspect_spec,
        .prepare_spec,
        .estimate_spec_fee,
        .simulate_instructions,
        .simulate_versioned_instructions,
        => true,
        else => false,
    };
}

pub fn hasInstructionJsonPositionalConflict(instruction_json_count: usize, instructions_spec_arg: ?[]const u8) bool {
    return instruction_json_count > 0 and instructions_spec_arg != null;
}

pub fn supportsSimulationQueryOptions(command: cli.Command) bool {
    return switch (command) {
        .simulate_transaction,
        .simulate_instructions,
        .simulate_versioned_instructions,
        .invoke_instructions_simulate,
        .invoke_spec_simulate,
        .simulate_program_invoke,
        .simulate_versioned_program_invoke,
        .invoke_program_invoke_simulate,
        .simulate_idl_invoke,
        .simulate_versioned_idl_invoke,
        .invoke_idl_invoke_simulate,
        => true,
        else => false,
    };
}

pub fn supportsNonceAccount(command: cli.Command) bool {
    return supportsInvocationContextOverrides(command);
}

pub fn supportsAdditionalSigners(command: cli.Command) bool {
    return supportsInvocationContextOverrides(command);
}

pub fn supportsAddressLookupTables(command: cli.Command) bool {
    return supportsInvocationContextOverrides(command);
}

pub fn supportsNonceAuthority(command: cli.Command) bool {
    return supportsNonceAccount(command);
}

pub fn hasMissingNonceAccountForNonceAuthority(
    nonce_account_arg: ?[]const u8,
    nonce_authority_secret_key_arg: ?[]const u8,
    nonce_authority_keypair_path_arg: ?[]const u8,
) bool {
    return (nonce_authority_secret_key_arg != null or nonce_authority_keypair_path_arg != null) and nonce_account_arg == null;
}

pub fn buildInvocationSpecJsonForPayloadFamily(
    allocator: Allocator,
    payload_family: InvokeFamily,
    inputs: CliInvokePayloadBuilderInputs,
    builders: anytype,
) ![]u8 {
    return buildInvocationSpecJsonFromPayloadSource(
        allocator,
        buildCliInvokePayloadSource(payload_family, inputs),
        builders,
    );
}

fn buildCliInvokeInstructionsPayloadBuilderInputs(
    inputs: CliInvokePayloadBuilderInputs,
) CliInvokeInstructionsPayloadBuilderInputs {
    return .{
        .command = inputs.command,
        .instructions_spec_arg = inputs.payload_args.instructions_spec_arg,
        .instruction_json_args = inputs.payload_args.instruction_json_args,
        .payer_keypair_path_arg = inputs.context_args.payer_keypair_path_arg,
        .payer_secret_key_arg = inputs.context_args.payer_secret_key_arg,
        .additional_signer_secret_keys_arg = inputs.context_args.additional_signer_secret_keys_arg,
        .signer_keypair_paths_arg = inputs.context_args.signer_keypair_paths_arg,
        .lookup_tables_arg = effectiveLookupTablesArg(inputs.versioned, inputs.context_args.lookup_tables_arg),
        .recent_blockhash_arg = inputs.context_args.recent_blockhash_arg,
        .nonce_account_arg = inputs.context_args.nonce_account_arg,
        .nonce_authority_secret_key_arg = inputs.context_args.nonce_authority_secret_key_arg,
        .nonce_authority_keypair_path_arg = inputs.context_args.nonce_authority_keypair_path_arg,
    };
}

fn buildCliInvokePayloadSource(
    payload_family: InvokeFamily,
    inputs: CliInvokePayloadBuilderInputs,
) CliInvokePayloadSource {
    return switch (payload_family) {
        .instructions => .{ .instructions = buildCliInvokeInstructionsPayloadBuilderInputs(inputs) },
        .program, .anchor_idl => .{ .single_instruction = buildCliInvokeSingleInstructionBuilderInputs(payload_family, inputs) },
    };
}

fn buildInstructionsInvocationSpecJson(
    allocator: Allocator,
    inputs: CliInvokeInstructionsPayloadBuilderInputs,
    builders: anytype,
) ![]u8 {
    return inputs.buildInvocationSpecJson(allocator, builders);
}

fn buildInvocationSpecJsonFromPayloadSource(
    allocator: Allocator,
    payload_source: CliInvokePayloadSource,
    builders: anytype,
) ![]u8 {
    return payload_source.buildInvocationSpecJson(allocator, builders);
}

fn buildCliInvokeSingleInstructionBuilderContext(
    inputs: CliInvokePayloadBuilderInputs,
) CliInvokeSingleInstructionBuilderContext {
    return .{
        .payer_keypair_path_arg = inputs.context_args.payer_keypair_path_arg,
        .payer_secret_key_arg = inputs.context_args.payer_secret_key_arg,
        .signer_keypair_paths_arg = inputs.context_args.signer_keypair_paths_arg,
        .lookup_tables_arg = effectiveLookupTablesArg(inputs.versioned, inputs.context_args.lookup_tables_arg),
        .recent_blockhash_arg = inputs.context_args.recent_blockhash_arg,
        .nonce_account_arg = inputs.context_args.nonce_account_arg,
        .nonce_authority_secret_key_arg = inputs.context_args.nonce_authority_secret_key_arg,
        .nonce_authority_keypair_path_arg = inputs.context_args.nonce_authority_keypair_path_arg,
        .additional_signer_secret_keys_arg = inputs.context_args.additional_signer_secret_keys_arg,
    };
}

fn effectiveLookupTablesArg(versioned: bool, lookup_tables_arg: ?[]const u8) ?[]const u8 {
    return if (versioned) lookup_tables_arg else null;
}

fn buildCliInvokeSingleInstructionPayloadSource(
    payload_family: InvokeFamily,
    payload_args: CliInvokePayloadArgs,
) CliInvokeSingleInstructionPayloadSource {
    return switch (payload_family) {
        .program => .{ .program = .{
            .program_id_arg = payload_args.program_id_arg,
            .program_accounts_arg = payload_args.program_accounts_arg,
            .program_data_arg = payload_args.program_data_arg,
            .program_data_encoding_arg = payload_args.program_data_encoding_arg,
            .program_data_schema_json_arg = payload_args.program_data_schema_json_arg,
            .program_args_json_arg = payload_args.program_args_json_arg,
            .program_schema_encoding_arg = payload_args.program_schema_encoding_arg,
        } },
        .anchor_idl => .{ .anchor_idl = .{
            .idl_arg = payload_args.idl_arg,
            .idl_instruction_arg = payload_args.idl_instruction_arg,
            .idl_program_id_arg = payload_args.idl_program_id_arg,
            .idl_args_json_arg = payload_args.idl_args_json_arg,
            .idl_accounts_json_arg = payload_args.idl_accounts_json_arg,
            .idl_account_bindings = payload_args.idl_account_bindings,
            .idl_remaining_accounts = payload_args.idl_remaining_accounts,
            .idl_remaining_accounts_json_arg = payload_args.idl_remaining_accounts_json_arg,
        } },
        .instructions => unreachable,
    };
}

fn buildCliInvokeSingleInstructionBuilderInputs(
    payload_family: InvokeFamily,
    inputs: CliInvokePayloadBuilderInputs,
) CliInvokeSingleInstructionBuilderInputs {
    return .{
        .command = inputs.command,
        .payload_source = buildCliInvokeSingleInstructionPayloadSource(payload_family, inputs.payload_args),
        .context = buildCliInvokeSingleInstructionBuilderContext(inputs),
    };
}

fn buildSingleInstructionInvocationSpecJson(
    allocator: Allocator,
    inputs: CliInvokeSingleInstructionBuilderInputs,
    builders: anytype,
) ![]u8 {
    return inputs.buildInvocationSpecJson(allocator, builders);
}

pub fn canonicalizeInvocationSpecJson(
    allocator: Allocator,
    invocation_spec_json: []const u8,
) ![]u8 {
    return canonicalizeInvocationSpecJsonForPayloadFamily(
        allocator,
        .instructions,
        invocation_spec_json,
    );
}

pub fn canonicalizeInvocationSpecJsonForPayloadFamily(
    allocator: Allocator,
    payload_family: InvokeFamily,
    invocation_spec_json: []const u8,
) ![]u8 {
    var owned_spec = client.invoke.buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        payload_family,
        invocation_spec_json,
    ) catch return error.InvalidCli;
    defer owned_spec.deinit(allocator);

    return client.invoke.buildInvocationSpecJsonFromOwnedInvocationSpec(
        allocator,
        &owned_spec,
    ) catch return error.InvalidCli;
}

pub fn buildCanonicalInvocationSpecJsonForPayloadFamily(
    allocator: Allocator,
    payload_family: InvokeFamily,
    command: cli.Command,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    builders: anytype,
) ![]u8 {
    const invocation_spec_json = try buildPayloadInvocationSpecJsonForPayloadFamily(
        allocator,
        payload_family,
        command,
        payload_args,
        context_args,
        builders,
    );
    defer allocator.free(invocation_spec_json);

    return canonicalizeInvocationSpecJsonForPayloadFamily(
        allocator,
        payload_family,
        invocation_spec_json,
    );
}

pub fn buildPayloadInvocationSpecJsonForPayloadFamily(
    allocator: Allocator,
    payload_family: InvokeFamily,
    command: cli.Command,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    builders: anytype,
) ![]u8 {
    return switch (payload_family) {
        .instructions => try builders.buildInstructions(
            allocator,
            command,
            payload_args.instructions_spec_arg,
            payload_args.instruction_json_args,
            context_args.payer_keypair_path_arg,
            context_args.payer_secret_key_arg,
            context_args.additional_signer_secret_keys_arg,
            context_args.signer_keypair_paths_arg,
            context_args.lookup_tables_arg,
            context_args.recent_blockhash_arg,
            context_args.nonce_account_arg,
            context_args.nonce_authority_secret_key_arg,
            context_args.nonce_authority_keypair_path_arg,
        ),
        .program => blk: {
            if (@hasField(@TypeOf(builders), "buildProgramPayload")) {
                if (@typeInfo(@TypeOf(builders.buildProgramPayload)) == .optional) {
                    if (builders.buildProgramPayload) |builder| {
                        break :blk try builder(
                            allocator,
                            command,
                            payload_args.program_id_arg,
                            payload_args.program_accounts_arg,
                            payload_args.program_data_arg,
                            payload_args.program_data_encoding_arg,
                            payload_args.program_data_schema_json_arg,
                            payload_args.program_args_json_arg,
                            payload_args.program_schema_encoding_arg,
                            context_args.payer_keypair_path_arg,
                            context_args.payer_secret_key_arg,
                            context_args.signer_keypair_paths_arg,
                            context_args.lookup_tables_arg,
                            context_args.recent_blockhash_arg,
                            context_args.nonce_account_arg,
                            context_args.nonce_authority_secret_key_arg,
                            context_args.nonce_authority_keypair_path_arg,
                            context_args.additional_signer_secret_keys_arg,
                        );
                    }
                } else {
                    break :blk try builders.buildProgramPayload(
                        allocator,
                        command,
                        payload_args.program_id_arg,
                        payload_args.program_accounts_arg,
                        payload_args.program_data_arg,
                        payload_args.program_data_encoding_arg,
                        payload_args.program_data_schema_json_arg,
                        payload_args.program_args_json_arg,
                        payload_args.program_schema_encoding_arg,
                        context_args.payer_keypair_path_arg,
                        context_args.payer_secret_key_arg,
                        context_args.signer_keypair_paths_arg,
                        context_args.lookup_tables_arg,
                        context_args.recent_blockhash_arg,
                        context_args.nonce_account_arg,
                        context_args.nonce_authority_secret_key_arg,
                        context_args.nonce_authority_keypair_path_arg,
                        context_args.additional_signer_secret_keys_arg,
                    );
                }
            }
            break :blk try builders.buildProgram(
                allocator,
                command,
                payload_args.program_id_arg,
                payload_args.program_accounts_arg,
                payload_args.program_data_arg,
                payload_args.program_data_encoding_arg,
                payload_args.program_data_schema_json_arg,
                payload_args.program_args_json_arg,
                payload_args.program_schema_encoding_arg,
                context_args.payer_keypair_path_arg,
                context_args.payer_secret_key_arg,
                context_args.signer_keypair_paths_arg,
                context_args.lookup_tables_arg,
                context_args.recent_blockhash_arg,
                context_args.nonce_account_arg,
                context_args.nonce_authority_secret_key_arg,
                context_args.nonce_authority_keypair_path_arg,
                context_args.additional_signer_secret_keys_arg,
            );
        },
        .anchor_idl => blk: {
            if (@hasField(@TypeOf(builders), "buildAnchorIdlPayload")) {
                if (@typeInfo(@TypeOf(builders.buildAnchorIdlPayload)) == .optional) {
                    if (builders.buildAnchorIdlPayload) |builder| {
                        break :blk try builder(
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
                            context_args.lookup_tables_arg,
                            context_args.recent_blockhash_arg,
                            context_args.nonce_account_arg,
                            context_args.nonce_authority_secret_key_arg,
                            context_args.nonce_authority_keypair_path_arg,
                            context_args.additional_signer_secret_keys_arg,
                        );
                    }
                } else {
                    break :blk try builders.buildAnchorIdlPayload(
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
                        context_args.lookup_tables_arg,
                        context_args.recent_blockhash_arg,
                        context_args.nonce_account_arg,
                        context_args.nonce_authority_secret_key_arg,
                        context_args.nonce_authority_keypair_path_arg,
                        context_args.additional_signer_secret_keys_arg,
                    );
                }
            }
            break :blk try builders.buildAnchorIdl(
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
                context_args.lookup_tables_arg,
                context_args.recent_blockhash_arg,
                context_args.nonce_account_arg,
                context_args.nonce_authority_secret_key_arg,
                context_args.nonce_authority_keypair_path_arg,
                context_args.additional_signer_secret_keys_arg,
            );
        },
    };
}

pub fn runGenericInvocationCommand(
    allocator: Allocator,
    rpc: *client.RpcClient,
    command: cli.Command,
    payload_args: CliInvokePayloadArgs,
    context_args: CliInvokeContextArgs,
    execution_args: CliInvokeExecutionArgs,
    preferred_invocation_mode_options: ?client.invoke.PreferredInvocationModeOptions,
    callbacks: CliInvokeRuntimeCallbacks,
) !void {
    const spec = lookupInvokeCommandSpec(command) orelse unreachable;
    const behavior = spec.behavior;
    const execution_family = spec.executionFamily();
    const invocation_spec_json = try spec.buildInvocationSpecJson(allocator, payload_args, context_args, callbacks.builders);
    defer allocator.free(invocation_spec_json);

    const reportNoBuildableMode = struct {
        fn emit(
            report_allocator: Allocator,
            report_rpc: *client.RpcClient,
            report_execution_family: InvokeFamily,
            report_invocation_spec_json: []const u8,
            report_preferred_mode_options: client.invoke.PreferredInvocationModeOptions,
        ) !void {
            var buf: [4096]u8 = undefined;
            var stderr_writer = std.fs.File.stderr().writer(&buf);

            try stderr_writer.interface.print(
                "error: no executable invocation mode was found for the requested preferences\n",
                .{},
            );

            try client.invoke.writePreferredInvocationModeResolutionTextFromInvocationSpecJson(
                &stderr_writer.interface,
                report_allocator,
                report_rpc,
                report_execution_family,
                report_invocation_spec_json,
                .{},
                report_preferred_mode_options,
            );

            const hint = if (report_preferred_mode_options.allow_fallback)
                "try adjusting --invoke-mode or invocation data"
            else
                "retry without --no-mode-fallback or adjust --invoke-mode";

            try stderr_writer.interface.print("hint: {s}\n", .{hint});
            try stderr_writer.interface.flush();
        }
    }.emit;

    if (behavior.simulate) {
        const options = try callbacks.buildSimulationOptions(execution_args);
        if (preferred_invocation_mode_options) |mode_options| {
            var simulation_result = (client.invoke.simulatePreferredTransactionExecutionResultFromInvocationSpecJson(
                allocator,
                rpc,
                execution_family,
                invocation_spec_json,
                .{
                    .mode = mode_options,
                    .simulate = .{
                        .blockhash_commitment = execution_args.commitment,
                        .simulate_options = options,
                    },
                },
            ) catch |err| {
                if (err == error.NoBuildableInvocationMode) {
                    try reportNoBuildableMode(
                        allocator,
                        rpc,
                        execution_family,
                        invocation_spec_json,
                        mode_options,
                    );
                }
                return err;
            });
            defer simulation_result.deinit(allocator);

            callbacks.printSimulationResult(simulation_result.simulation);
            return;
        }

        const simulation = try client.invoke.simulateTransactionFromInvocationSpecJson(
            allocator,
            rpc,
            execution_family,
            behavior.versioned,
            invocation_spec_json,
            .{
                .blockhash_commitment = execution_args.commitment,
                .simulate_options = options,
            },
        );
        defer callbacks.freeSimulation(allocator, simulation);
        callbacks.printSimulationResult(simulation);

        return;
    }

    if (behavior.confirm) {
        if (preferred_invocation_mode_options) |mode_options| {
            var result = (client.invoke.sendAndConfirmPreferredTransactionExecutionResultFromInvocationSpecJson(
                allocator,
                rpc,
                execution_family,
                invocation_spec_json,
                .{
                    .mode = mode_options,
                    .send_and_confirm = .{
                        .blockhash_commitment = execution_args.commitment orelse execution_args.send_preflight_commitment,
                        .send_transaction_options = execution_args.send_transaction_options,
                        .commitment = execution_args.commitment,
                        .search_transaction_history = execution_args.search_transaction_history,
                        .timeout_ms = execution_args.status_timeout_ms,
                        .poll_interval_ms = execution_args.status_poll_ms,
                    },
                },
            ) catch |err| {
                if (err == error.NoBuildableInvocationMode) {
                    try reportNoBuildableMode(
                        allocator,
                        rpc,
                        execution_family,
                        invocation_spec_json,
                        mode_options,
                    );
                }
                return err;
            });
            defer result.deinit(allocator);
            std.debug.print("confirmed signature: {s}\n", .{result.signature});
        } else {
            const tx_signature = try client.invoke.sendAndConfirmInvocationSpecJson(
                allocator,
                rpc,
                execution_family,
                behavior.versioned,
                invocation_spec_json,
                .{
                    .blockhash_commitment = execution_args.commitment orelse execution_args.send_preflight_commitment,
                    .send_transaction_options = execution_args.send_transaction_options,
                    .commitment = execution_args.commitment,
                    .search_transaction_history = execution_args.search_transaction_history,
                    .timeout_ms = execution_args.status_timeout_ms,
                    .poll_interval_ms = execution_args.status_poll_ms,
                },
            );
            defer allocator.free(tx_signature);
            std.debug.print("confirmed signature: {s}\n", .{tx_signature});
        }
        return;
    }

    if (preferred_invocation_mode_options) |mode_options| {
        var result = (client.invoke.sendPreferredTransactionExecutionResultFromInvocationSpecJson(
            allocator,
            rpc,
            execution_family,
            invocation_spec_json,
            .{
                .mode = mode_options,
                .send = .{
                    .blockhash_commitment = execution_args.commitment orelse execution_args.send_preflight_commitment,
                    .send_transaction_options = execution_args.send_transaction_options,
                },
            },
        ) catch |err| {
            if (err == error.NoBuildableInvocationMode) {
                try reportNoBuildableMode(
                    allocator,
                    rpc,
                    execution_family,
                    invocation_spec_json,
                    mode_options,
                );
            }
            return err;
        });
        defer result.deinit(allocator);
        std.debug.print("signature: {s}\n", .{result.signature});
        return;
    }

    const tx_signature = try client.invoke.sendTransactionFromInvocationSpecJson(
        allocator,
        rpc,
        execution_family,
        behavior.versioned,
        invocation_spec_json,
        .{
            .blockhash_commitment = execution_args.commitment orelse execution_args.send_preflight_commitment,
            .send_transaction_options = execution_args.send_transaction_options,
        },
    );
    defer allocator.free(tx_signature);
    std.debug.print("signature: {s}\n", .{tx_signature});
}

test "commands.invoke CliInvokeCommandBehavior executionFamily defaults to instructions" {
    try std.testing.expectEqual(
        InvokeFamily.instructions,
        (CliInvokeCommandBehavior{
            .payload_family = .instructions,
            .versioned = false,
            .simulate = false,
            .confirm = false,
        }).executionFamily(),
    );
    try std.testing.expectEqual(
        InvokeFamily.instructions,
        (CliInvokeCommandBehavior{
            .payload_family = .program,
            .versioned = true,
            .simulate = false,
            .confirm = true,
        }).executionFamily(),
    );
    try std.testing.expectEqual(
        InvokeFamily.instructions,
        (CliInvokeCommandBehavior{
            .payload_family = .anchor_idl,
            .versioned = false,
            .simulate = true,
            .confirm = false,
        }).executionFamily(),
    );
    try std.testing.expectEqual(
        InvokeFamily.program,
        (CliInvokeCommandBehavior{
            .payload_family = .program,
            .execution_family = .program,
            .versioned = false,
            .simulate = false,
            .confirm = false,
        }).executionFamily(),
    );
}

test "commands.invoke canonicalizeInvocationSpecJson rejects invalid invocation specs" {
    const allocator = std.testing.allocator;
    const invocation_spec_json = "{\"instructions\":[{\"program_id\":\"11111111111111111111111111111111\",\"accounts\":[],\"data\":\"AQ==\",\"data_encoding\":\"base64\"}]}";

    try std.testing.expectError(
        error.InvalidCli,
        canonicalizeInvocationSpecJson(allocator, invocation_spec_json),
    );
}

test "commands.invoke buildCanonicalInvocationSpecJsonForPayloadFamily forwards payload inputs before canonicalization" {
    const allocator = std.testing.allocator;

    const FakeBuilders = struct {
        fn buildInstructions(
            _: Allocator,
            _: cli.Command,
            _: ?[]const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
        ) ![]u8 {
            return error.Unexpected;
        }

        fn buildProgram(
            alloc: Allocator,
            command: cli.Command,
            program_id_arg: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
        ) ![]u8 {
            try std.testing.expectEqual(cli.Command.spec_program_invoke, command);
            try std.testing.expectEqualStrings("11111111111111111111111111111111", program_id_arg.?);
            try std.testing.expectEqualStrings(
                "[{\"account_key\":\"Lookup1111111111111111111111111111111111\",\"addresses\":[]}]",
                lookup_tables_arg.?,
            );
            return try alloc.dupe(
                u8,
                "{\"instructions\":[{\"program_id\":\"11111111111111111111111111111111\",\"accounts\":[],\"data_bytes\":[1]}]}",
            );
        }

        fn buildAnchorIdl(
            _: Allocator,
            _: cli.Command,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
        ) ![]u8 {
            return error.Unexpected;
        }
    };

    try std.testing.expectError(
        error.InvalidCli,
        buildCanonicalInvocationSpecJsonForPayloadFamily(
            allocator,
            .program,
            .spec_program_invoke,
            .{
                .instructions_spec_arg = null,
                .instruction_json_args = &.{},
                .program_id_arg = "11111111111111111111111111111111",
                .program_accounts_arg = "[]",
                .program_data_arg = null,
                .program_data_encoding_arg = null,
                .program_data_schema_json_arg = null,
                .program_args_json_arg = null,
                .program_schema_encoding_arg = null,
                .idl_arg = null,
                .idl_instruction_arg = null,
                .idl_program_id_arg = null,
                .idl_args_json_arg = null,
                .idl_accounts_json_arg = null,
                .idl_account_bindings = &.{},
                .idl_remaining_accounts = &.{},
                .idl_remaining_accounts_json_arg = null,
            },
            .{
                .payer_keypair_path_arg = null,
                .payer_secret_key_arg = null,
                .signer_keypair_paths_arg = null,
                .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\",\"addresses\":[]}]",
                .recent_blockhash_arg = null,
                .nonce_account_arg = null,
                .nonce_authority_secret_key_arg = null,
                .nonce_authority_keypair_path_arg = null,
                .additional_signer_secret_keys_arg = &.{},
            },
            .{
                .buildInstructions = FakeBuilders.buildInstructions,
                .buildProgram = FakeBuilders.buildProgram,
                .buildAnchorIdl = FakeBuilders.buildAnchorIdl,
            },
        ),
    );
}

test "commands.invoke buildCanonicalInvocationSpecJsonForPayloadFamily canonicalizes raw program payload json" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic(.{23} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);

    const FakeBuilders = struct {
        fn buildInstructions(
            _: Allocator,
            _: cli.Command,
            _: ?[]const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
        ) ![]u8 {
            return error.Unexpected;
        }

        fn buildProgram(
            _: Allocator,
            _: cli.Command,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
        ) ![]u8 {
            return error.Unexpected;
        }

        fn buildProgramPayload(
            alloc: Allocator,
            command: cli.Command,
            program_id_arg: ?[]const u8,
            accounts_arg: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
        ) ![]u8 {
            try std.testing.expectEqual(cli.Command.spec_program_invoke, command);
            try std.testing.expectEqualStrings("11111111111111111111111111111111", program_id_arg.?);
            try std.testing.expectEqualStrings(
                "[{\"pubkey\":\"11111111111111111111111111111111\",\"is_signer\":false,\"is_writable\":false}]",
                accounts_arg.?,
            );
            try std.testing.expect(payer_secret_key_arg != null);
            return try std.fmt.allocPrint(
                alloc,
                "{{\"payer_secret_key\":\"{s}\",\"program_id\":\"11111111111111111111111111111111\",\"accounts\":[{{\"pubkey\":\"11111111111111111111111111111111\",\"is_signer\":false,\"is_writable\":false}}],\"data_bytes\":[1,2,3]}}",
                .{payer_secret_key_arg.?},
            );
        }

        fn buildAnchorIdl(
            _: Allocator,
            _: cli.Command,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
            _: []const []const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: ?[]const u8,
            _: []const []const u8,
        ) ![]u8 {
            return error.Unexpected;
        }
    };

    const invocation_spec_json = try buildCanonicalInvocationSpecJsonForPayloadFamily(
        allocator,
        .program,
        .spec_program_invoke,
        .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = "11111111111111111111111111111111",
            .program_accounts_arg = "[{\"pubkey\":\"11111111111111111111111111111111\",\"is_signer\":false,\"is_writable\":false}]",
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .{
            .payer_keypair_path_arg = null,
            .payer_secret_key_arg = payer_secret_key_base58,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = null,
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .{
            .buildInstructions = FakeBuilders.buildInstructions,
            .buildProgram = FakeBuilders.buildProgram,
            .buildProgramPayload = FakeBuilders.buildProgramPayload,
            .buildAnchorIdl = FakeBuilders.buildAnchorIdl,
        },
    );
    defer allocator.free(invocation_spec_json);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, invocation_spec_json, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try std.testing.expect(parsed.value == .object);
    try std.testing.expect(parsed.value.object.get("instructions") != null);
    try std.testing.expect(parsed.value.object.get("program_id") == null);
}

test "commands.invoke isInvocationSendCommand covers direct and generic invocation sends" {
    try std.testing.expect(isInvocationSendCommand(.send_instructions));
    try std.testing.expect(isInvocationSendCommand(.send_versioned_program_invoke));
    try std.testing.expect(isInvocationSendCommand(.invoke_spec_and_confirm));
    try std.testing.expect(isInvocationSendCommand(.invoke_idl_invoke_simulate));
    try std.testing.expect(!isInvocationSendCommand(.preview_spec));
}

test "commands.invoke isProgramInvokeCommand and isIdlInvokeCommand cover invoke families" {
    try std.testing.expect(isProgramInvokeCommand(.send_versioned_program_invoke));
    try std.testing.expect(isProgramInvokeCommand(.spec_program_invoke));
    try std.testing.expect(!isProgramInvokeCommand(.send_instructions));

    try std.testing.expect(isIdlInvokeCommand(.simulate_versioned_idl_invoke));
    try std.testing.expect(isIdlInvokeCommand(.preview_idl_invoke));
    try std.testing.expect(!isIdlInvokeCommand(.preview_program_invoke));
}

test "commands.invoke supportsRecentBlockhash covers invocation command families" {
    try std.testing.expect(supportsRecentBlockhash(.send_versioned_idl_invoke));
    try std.testing.expect(supportsRecentBlockhash(.simulate_program_invoke));
    try std.testing.expect(supportsRecentBlockhash(.preview_spec));
    try std.testing.expect(supportsRecentBlockhash(.spec_program_invoke));
    try std.testing.expect(!supportsRecentBlockhash(.transfer));
}

test "commands.invoke supportsJsonOutput covers invoke analysis commands only" {
    try std.testing.expect(supportsJsonOutput(.invoke_spec_simulate));
    try std.testing.expect(supportsJsonOutput(.preview_program_invoke));
    try std.testing.expect(supportsJsonOutput(.spec_idl_invoke));
    try std.testing.expect(!supportsJsonOutput(.send_versioned_program_invoke));
    try std.testing.expect(!supportsJsonOutput(.transfer));
}

test "commands.invoke supportsWaitOptions covers confirmation and polling commands" {
    try std.testing.expect(supportsWaitOptions(.send_versioned_idl_invoke_and_confirm));
    try std.testing.expect(supportsWaitOptions(.invoke_program_invoke_and_confirm));
    try std.testing.expect(supportsWaitOptions(.poll_for_signature_confirmation));
    try std.testing.expect(!supportsWaitOptions(.send_program_invoke));
    try std.testing.expect(!supportsWaitOptions(.preview_spec));
}

test "commands.invoke supportsSendOptions covers direct, generic, and versioned send commands" {
    try std.testing.expect(supportsSendOptions(.send_transaction));
    try std.testing.expect(supportsSendOptions(.transfer));
    try std.testing.expect(supportsSendOptions(.invoke_spec));
    try std.testing.expect(supportsSendOptions(.send_versioned_program_invoke));
    try std.testing.expect(supportsSendOptions(.send_versioned_idl_invoke_and_confirm));
    try std.testing.expect(!supportsSendOptions(.preview_program_invoke));
    try std.testing.expect(!supportsSendOptions(.simulate_versioned_idl_invoke));
}

test "commands.invoke supportsPreferredInvocationMode covers preferred execution analysis commands" {
    try std.testing.expect(supportsPreferredInvocationMode(.invoke_spec_simulate));
    try std.testing.expect(supportsPreferredInvocationMode(.preview_program_invoke));
    try std.testing.expect(supportsPreferredInvocationMode(.estimate_idl_invoke_fee));
    try std.testing.expect(supportsPreferredInvocationMode(.send_instructions));
    try std.testing.expect(supportsPreferredInvocationMode(.send_versioned_instructions_and_confirm));
    try std.testing.expect(supportsPreferredInvocationMode(.simulate_versioned_instructions));
    try std.testing.expect(!supportsPreferredInvocationMode(.spec_program_invoke));
    try std.testing.expect(!supportsPreferredInvocationMode(.send_program_invoke));
}

test "commands.invoke supportsSearchTransactionHistory covers confirmation-oriented commands" {
    try std.testing.expect(supportsSearchTransactionHistory(.status));
    try std.testing.expect(supportsSearchTransactionHistory(.send_versioned_program_invoke_and_confirm));
    try std.testing.expect(supportsSearchTransactionHistory(.invoke_idl_invoke_and_confirm));
    try std.testing.expect(!supportsSearchTransactionHistory(.poll_balance));
    try std.testing.expect(!supportsSearchTransactionHistory(.preview_spec));
}

test "commands.invoke lookupInvokeCommandLabel covers direct spec invoke commands" {
    try std.testing.expectEqualStrings("invoke-spec", lookupInvokeCommandLabel(.invoke_spec).?);
    try std.testing.expectEqualStrings("invoke-spec-and-confirm", lookupInvokeCommandLabel(.invoke_spec_and_confirm).?);
    try std.testing.expectEqualStrings("invoke-spec-simulate", lookupInvokeCommandLabel(.invoke_spec_simulate).?);
}

test "commands.invoke supportsInspectSection covers inspect commands only" {
    try std.testing.expect(supportsInspectSection(.inspect_instructions));
    try std.testing.expect(supportsInspectSection(.inspect_idl_invoke));
    try std.testing.expect(!supportsInspectSection(.preview_spec));
    try std.testing.expect(!supportsInspectSection(.send_program_invoke));
}

test "commands.invoke supportsInvocationContextOverrides covers generic invocation context commands" {
    try std.testing.expect(supportsInvocationContextOverrides(.send_versioned_program_invoke));
    try std.testing.expect(supportsInvocationContextOverrides(.preview_spec));
    try std.testing.expect(supportsInvocationContextOverrides(.simulate_versioned_idl_invoke));
    try std.testing.expect(!supportsInvocationContextOverrides(.transfer));
    try std.testing.expect(!supportsInvocationContextOverrides(.request_airdrop));
}

test "commands.invoke supportsSenderCredentials covers transfer and generic invocation commands" {
    try std.testing.expect(supportsSenderCredentials(.transfer));
    try std.testing.expect(supportsSenderCredentials(.send_versioned_program_invoke));
    try std.testing.expect(supportsSenderCredentials(.preview_spec));
    try std.testing.expect(supportsSenderCredentials(.simulate_versioned_idl_invoke));
    try std.testing.expect(!supportsSenderCredentials(.request_airdrop));
}

test "commands.invoke supportsInstructionJson covers instructions and spec families only" {
    try std.testing.expect(supportsInstructionJson(.send_instructions));
    try std.testing.expect(supportsInstructionJson(.invoke_spec_simulate));
    try std.testing.expect(supportsInstructionJson(.simulate_versioned_instructions));
    try std.testing.expect(!supportsInstructionJson(.send_program_invoke));
    try std.testing.expect(!supportsInstructionJson(.spec_program_invoke));
}

test "commands.invoke hasInstructionJsonPositionalConflict requires both instruction-json and positional spec" {
    try std.testing.expect(hasInstructionJsonPositionalConflict(1, "{}"));
    try std.testing.expect(!hasInstructionJsonPositionalConflict(0, "{}"));
    try std.testing.expect(!hasInstructionJsonPositionalConflict(2, null));
}

test "commands.invoke supportsSimulationQueryOptions covers simulate command families only" {
    try std.testing.expect(supportsSimulationQueryOptions(.simulate_transaction));
    try std.testing.expect(supportsSimulationQueryOptions(.invoke_spec_simulate));
    try std.testing.expect(supportsSimulationQueryOptions(.simulate_versioned_idl_invoke));
    try std.testing.expect(!supportsSimulationQueryOptions(.send_instructions));
    try std.testing.expect(!supportsSimulationQueryOptions(.preview_program_invoke));
}

test "commands.invoke supportsNonceAccount and supportsNonceAuthority follow generic invocation recent-blockhash support" {
    try std.testing.expect(supportsNonceAccount(.send_versioned_program_invoke));
    try std.testing.expect(supportsNonceAccount(.estimate_idl_invoke_fee));
    try std.testing.expect(supportsNonceAuthority(.simulate_instructions));
    try std.testing.expect(supportsNonceAuthority(.spec_program_invoke));
    try std.testing.expect(!supportsNonceAccount(.transfer));
    try std.testing.expect(!supportsNonceAuthority(.request_airdrop));
}

test "commands.invoke supportsAdditionalSigners and supportsAddressLookupTables follow generic invocation recent-blockhash support" {
    try std.testing.expect(supportsAdditionalSigners(.send_versioned_program_invoke));
    try std.testing.expect(supportsAdditionalSigners(.preview_spec));
    try std.testing.expect(supportsAddressLookupTables(.simulate_versioned_idl_invoke));
    try std.testing.expect(supportsAddressLookupTables(.spec_program_invoke));
    try std.testing.expect(!supportsAdditionalSigners(.transfer));
    try std.testing.expect(!supportsAddressLookupTables(.request_airdrop));
}

test "commands.invoke hasMissingNonceAccountForNonceAuthority requires authority credentials without nonce account" {
    try std.testing.expect(hasMissingNonceAccountForNonceAuthority(null, "[1,2,3]", null));
    try std.testing.expect(hasMissingNonceAccountForNonceAuthority(null, null, "/tmp/nonce-authority.json"));
    try std.testing.expect(!hasMissingNonceAccountForNonceAuthority("Nonce1111111111111111111111111111111111111", "[1,2,3]", null));
    try std.testing.expect(!hasMissingNonceAccountForNonceAuthority(null, null, null));
}

test "commands.invoke command specs default non-instructions payloads to instructions execution" {
    const program_spec = lookupInvokeCommandSpec(.send_program_invoke).?;
    try std.testing.expectEqual(InvokeFamily.program, program_spec.behavior.payload_family);
    try std.testing.expectEqual(InvokeFamily.instructions, program_spec.behavior.execution_family);

    const idl_spec = lookupInvokeCommandSpec(.send_idl_invoke).?;
    try std.testing.expectEqual(InvokeFamily.anchor_idl, idl_spec.behavior.payload_family);
    try std.testing.expectEqual(InvokeFamily.instructions, idl_spec.behavior.execution_family);

    const instructions_spec = lookupInvokeCommandSpec(.send_instructions).?;
    try std.testing.expectEqual(InvokeFamily.instructions, instructions_spec.behavior.payload_family);
    try std.testing.expectEqual(InvokeFamily.instructions, instructions_spec.behavior.execution_family);
}

test "commands.invoke cli_invoke_command_specs has unique commands" {
    for (cli_invoke_command_specs, 0..) |lhs, i| {
        for (cli_invoke_command_specs[(i + 1)..]) |rhs| {
            try std.testing.expect(lhs.command != rhs.command);
        }
    }
}

test "commands.invoke lookupCanonicalSpecCommand maps spec families to payload families" {
    try std.testing.expectEqual(InvokeFamily.instructions, lookupCanonicalSpecCommand(.spec_instructions).?.payload_family);
    try std.testing.expectEqual(InvokeFamily.program, lookupCanonicalSpecCommand(.spec_program_invoke).?.payload_family);
    try std.testing.expectEqual(InvokeFamily.anchor_idl, lookupCanonicalSpecCommand(.spec_idl_invoke).?.payload_family);
    try std.testing.expect(lookupCanonicalSpecCommand(.send_program_invoke) == null);
}

test "commands.invoke buildInvocationSpecJsonForPayloadFamily dispatches by payload family" {
    const allocator = std.testing.allocator;
    const builders = struct {
        fn buildInstructions(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            instructions_spec_arg: ?[]const u8,
            instruction_json_args: []const []const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
        ) ![]u8 {
            _ = command;
            _ = instructions_spec_arg;
            _ = instruction_json_args;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = additional_signer_secret_keys_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            return alloc.dupe(u8, "instructions");
        }

        fn buildProgram(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            program_id_arg: ?[]const u8,
            program_accounts_arg: ?[]const u8,
            program_data_arg: ?[]const u8,
            program_data_encoding_arg: ?[]const u8,
            program_data_schema_json_arg: ?[]const u8,
            program_args_json_arg: ?[]const u8,
            program_schema_encoding_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            _ = command;
            _ = program_id_arg;
            _ = program_accounts_arg;
            _ = program_data_arg;
            _ = program_data_encoding_arg;
            _ = program_data_schema_json_arg;
            _ = program_args_json_arg;
            _ = program_schema_encoding_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "program");
        }

        fn buildAnchorIdl(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            idl_arg: ?[]const u8,
            idl_instruction_arg: ?[]const u8,
            idl_program_id_arg: ?[]const u8,
            idl_args_json_arg: ?[]const u8,
            idl_accounts_json_arg: ?[]const u8,
            idl_account_bindings: []const []const u8,
            idl_remaining_accounts: []const []const u8,
            idl_remaining_accounts_json_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            _ = command;
            _ = idl_arg;
            _ = idl_instruction_arg;
            _ = idl_program_id_arg;
            _ = idl_args_json_arg;
            _ = idl_accounts_json_arg;
            _ = idl_account_bindings;
            _ = idl_remaining_accounts;
            _ = idl_remaining_accounts_json_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "anchor-idl");
        }
    }{};

    const inputs = CliInvokePayloadBuilderInputs{
        .command = .send_instructions,
        .payload_args = .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = null,
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = null,
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = false,
    };

    const instructions_json = try buildInvocationSpecJsonForPayloadFamily(allocator, .instructions, inputs, builders);
    defer allocator.free(instructions_json);
    try std.testing.expectEqualStrings("instructions", instructions_json);

    const program_json = try buildInvocationSpecJsonForPayloadFamily(allocator, .program, inputs, builders);
    defer allocator.free(program_json);
    try std.testing.expectEqualStrings("program", program_json);

    const anchor_idl_json = try buildInvocationSpecJsonForPayloadFamily(allocator, .anchor_idl, inputs, builders);
    defer allocator.free(anchor_idl_json);
    try std.testing.expectEqualStrings("anchor-idl", anchor_idl_json);
}

test "commands.invoke buildCliInvokeSingleInstructionBuilderContext only enables lookup tables for versioned payloads" {
    const versioned_context = buildCliInvokeSingleInstructionBuilderContext(.{
        .command = .send_versioned_program_invoke,
        .payload_args = .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = "payer.json",
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = "[]",
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = "RecentBlockhash111111111111111111111111111111",
            .nonce_account_arg = "Nonce1111111111111111111111111111111111111",
            .nonce_authority_secret_key_arg = "[1,2,3]",
            .nonce_authority_keypair_path_arg = "nonce.json",
            .additional_signer_secret_keys_arg = &.{"[4,5,6]"},
        },
        .versioned = true,
    });
    try std.testing.expectEqualStrings(
        "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
        versioned_context.lookup_tables_arg.?,
    );
    try std.testing.expectEqualStrings("payer.json", versioned_context.payer_keypair_path_arg.?);
    try std.testing.expectEqualStrings("nonce.json", versioned_context.nonce_authority_keypair_path_arg.?);
    try std.testing.expectEqual(@as(usize, 1), versioned_context.additional_signer_secret_keys_arg.len);

    const legacy_context = buildCliInvokeSingleInstructionBuilderContext(.{
        .command = .send_program_invoke,
        .payload_args = .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = null,
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = false,
    });
    try std.testing.expect(legacy_context.lookup_tables_arg == null);
}

test "commands.invoke buildCliInvokeInstructionsPayloadBuilderInputs only enables lookup tables for versioned payloads" {
    const versioned_inputs = buildCliInvokeInstructionsPayloadBuilderInputs(.{
        .command = .send_versioned_instructions,
        .payload_args = .{
            .instructions_spec_arg = "{\"instructions\":[]}",
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = "payer.json",
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = true,
    });
    try std.testing.expectEqualStrings(
        "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
        versioned_inputs.lookup_tables_arg.?,
    );

    const legacy_inputs = buildCliInvokeInstructionsPayloadBuilderInputs(.{
        .command = .send_instructions,
        .payload_args = .{
            .instructions_spec_arg = "{\"instructions\":[]}",
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = "payer.json",
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = false,
    });
    try std.testing.expect(legacy_inputs.lookup_tables_arg == null);
}

test "commands.invoke buildCliInvokeSingleInstructionPayloadSource maps program and anchor payload args" {
    const payload_args = CliInvokePayloadArgs{
        .instructions_spec_arg = null,
        .instruction_json_args = &.{},
        .program_id_arg = "Program1111111111111111111111111111111111111",
        .program_accounts_arg = "[{\"pubkey\":\"Account111111111111111111111111111111111111\"}]",
        .program_data_arg = "AQID",
        .program_data_encoding_arg = "base64",
        .program_data_schema_json_arg = "{\"kind\":\"u8\"}",
        .program_args_json_arg = "[1]",
        .program_schema_encoding_arg = "borsh",
        .idl_arg = "{\"address\":\"Idl111111111111111111111111111111111111111\"}",
        .idl_instruction_arg = "mint",
        .idl_program_id_arg = "Anchor1111111111111111111111111111111111111",
        .idl_args_json_arg = "[{\"amount\":1}]",
        .idl_accounts_json_arg = "{\"payer\":\"Payer1111111111111111111111111111111111111\"}",
        .idl_account_bindings = &.{"payer=Binding11111111111111111111111111111111111"},
        .idl_remaining_accounts = &.{"Remaining11111111111111111111111111111111111"},
        .idl_remaining_accounts_json_arg = "[{\"pubkey\":\"RemainingJson1111111111111111111111111111111\"}]",
    };

    const program_source = buildCliInvokeSingleInstructionPayloadSource(.program, payload_args);
    switch (program_source) {
        .program => |program_args| {
            try std.testing.expectEqualStrings("AQID", program_args.program_data_arg.?);
            try std.testing.expectEqualStrings("borsh", program_args.program_schema_encoding_arg.?);
            try std.testing.expectEqualStrings(
                "[{\"pubkey\":\"Account111111111111111111111111111111111111\"}]",
                program_args.program_accounts_arg.?,
            );
        },
        else => return error.UnexpectedPayloadSource,
    }

    const anchor_source = buildCliInvokeSingleInstructionPayloadSource(.anchor_idl, payload_args);
    switch (anchor_source) {
        .anchor_idl => |idl_args| {
            try std.testing.expectEqualStrings("mint", idl_args.idl_instruction_arg.?);
            try std.testing.expectEqual(@as(usize, 1), idl_args.idl_account_bindings.len);
            try std.testing.expectEqual(@as(usize, 1), idl_args.idl_remaining_accounts.len);
            try std.testing.expectEqualStrings(
                "[{\"pubkey\":\"RemainingJson1111111111111111111111111111111\"}]",
                idl_args.idl_remaining_accounts_json_arg.?,
            );
        },
        else => return error.UnexpectedPayloadSource,
    }
}

test "commands.invoke buildCliInvokeSingleInstructionBuilderInputs combines command payload source and versioned context" {
    const single_instruction_inputs = buildCliInvokeSingleInstructionBuilderInputs(.program, .{
        .command = .send_versioned_program_invoke,
        .payload_args = .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = "Program1111111111111111111111111111111111111",
            .program_accounts_arg = null,
            .program_data_arg = "AQID",
            .program_data_encoding_arg = "base64",
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = "payer.json",
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = "[]",
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = "RecentBlockhash111111111111111111111111111111",
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = true,
    });

    try std.testing.expectEqual(cli.Command.send_versioned_program_invoke, single_instruction_inputs.command);
    try std.testing.expectEqualStrings(
        "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
        single_instruction_inputs.context.lookup_tables_arg.?,
    );
    switch (single_instruction_inputs.payload_source) {
        .program => |program_args| {
            try std.testing.expectEqualStrings("Program1111111111111111111111111111111111111", program_args.program_id_arg.?);
            try std.testing.expectEqualStrings("AQID", program_args.program_data_arg.?);
        },
        else => return error.UnexpectedPayloadSource,
    }
}

test "commands.invoke buildCliInvokePayloadSource maps instructions and single-instruction payload families" {
    const instructions_source = buildCliInvokePayloadSource(.instructions, .{
        .command = .send_instructions,
        .payload_args = .{
            .instructions_spec_arg = "{\"instructions\":[]}",
            .instruction_json_args = &.{"{\"program_id\":\"Program1111111111111111111111111111111111111\"}"},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = null,
            .idl_instruction_arg = null,
            .idl_program_id_arg = null,
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = "payer.json",
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = false,
    });
    switch (instructions_source) {
        .instructions => |instruction_inputs| {
            try std.testing.expectEqual(cli.Command.send_instructions, instruction_inputs.command);
            try std.testing.expectEqualStrings("{\"instructions\":[]}", instruction_inputs.instructions_spec_arg.?);
            try std.testing.expectEqual(@as(usize, 1), instruction_inputs.instruction_json_args.len);
        },
        else => return error.UnexpectedPayloadSource,
    }

    const single_instruction_source = buildCliInvokePayloadSource(.anchor_idl, .{
        .command = .send_versioned_idl_invoke,
        .payload_args = .{
            .instructions_spec_arg = null,
            .instruction_json_args = &.{},
            .program_id_arg = null,
            .program_accounts_arg = null,
            .program_data_arg = null,
            .program_data_encoding_arg = null,
            .program_data_schema_json_arg = null,
            .program_args_json_arg = null,
            .program_schema_encoding_arg = null,
            .idl_arg = "{\"address\":\"Idl111111111111111111111111111111111111111\"}",
            .idl_instruction_arg = "mint",
            .idl_program_id_arg = "Anchor1111111111111111111111111111111111111",
            .idl_args_json_arg = null,
            .idl_accounts_json_arg = null,
            .idl_account_bindings = &.{},
            .idl_remaining_accounts = &.{},
            .idl_remaining_accounts_json_arg = null,
        },
        .context_args = .{
            .payer_keypair_path_arg = null,
            .payer_secret_key_arg = null,
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
            .additional_signer_secret_keys_arg = &.{},
        },
        .versioned = true,
    });
    switch (single_instruction_source) {
        .single_instruction => |single_instruction_inputs| {
            try std.testing.expectEqual(cli.Command.send_versioned_idl_invoke, single_instruction_inputs.command);
            try std.testing.expectEqualStrings(
                "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
                single_instruction_inputs.context.lookup_tables_arg.?,
            );
            switch (single_instruction_inputs.payload_source) {
                .anchor_idl => |idl_args| try std.testing.expectEqualStrings("mint", idl_args.idl_instruction_arg.?),
                else => return error.UnexpectedPayloadSource,
            }
        },
        else => return error.UnexpectedPayloadSource,
    }
}

test "commands.invoke buildInstructionsInvocationSpecJson forwards typed instruction inputs" {
    const allocator = std.testing.allocator;
    const builders = struct {
        fn buildInstructions(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            instructions_spec_arg: ?[]const u8,
            instruction_json_args: []const []const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
        ) ![]u8 {
            try std.testing.expectEqual(cli.Command.send_versioned_instructions, command);
            try std.testing.expectEqualStrings("{\"instructions\":[]}", instructions_spec_arg.?);
            try std.testing.expectEqual(@as(usize, 1), instruction_json_args.len);
            try std.testing.expectEqualStrings("payer.json", payer_keypair_path_arg.?);
            try std.testing.expectEqualStrings("[1,2,3]", payer_secret_key_arg.?);
            try std.testing.expectEqual(@as(usize, 1), additional_signer_secret_keys_arg.len);
            try std.testing.expectEqualStrings("[]", signer_keypair_paths_arg.?);
            try std.testing.expectEqualStrings(
                "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
                lookup_tables_arg.?,
            );
            try std.testing.expectEqualStrings("RecentBlockhash111111111111111111111111111111", recent_blockhash_arg.?);
            try std.testing.expectEqualStrings("Nonce1111111111111111111111111111111111111", nonce_account_arg.?);
            try std.testing.expectEqualStrings("[4,5,6]", nonce_authority_secret_key_arg.?);
            try std.testing.expectEqualStrings("nonce.json", nonce_authority_keypair_path_arg.?);
            return alloc.dupe(u8, "instructions");
        }
    }{};

    const invocation_spec_json = try buildInstructionsInvocationSpecJson(allocator, .{
        .command = .send_versioned_instructions,
        .instructions_spec_arg = "{\"instructions\":[]}",
        .instruction_json_args = &.{"{\"program_id\":\"Program1111111111111111111111111111111111111\"}"},
        .payer_keypair_path_arg = "payer.json",
        .payer_secret_key_arg = "[1,2,3]",
        .additional_signer_secret_keys_arg = &.{"[7,8,9]"},
        .signer_keypair_paths_arg = "[]",
        .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
        .recent_blockhash_arg = "RecentBlockhash111111111111111111111111111111",
        .nonce_account_arg = "Nonce1111111111111111111111111111111111111",
        .nonce_authority_secret_key_arg = "[4,5,6]",
        .nonce_authority_keypair_path_arg = "nonce.json",
    }, builders);
    defer allocator.free(invocation_spec_json);

    try std.testing.expectEqualStrings("instructions", invocation_spec_json);
}

test "commands.invoke CliInvokePayloadSource buildInvocationSpecJson dispatches through typed adapters" {
    const allocator = std.testing.allocator;
    const builders = struct {
        fn buildInstructions(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            instructions_spec_arg: ?[]const u8,
            instruction_json_args: []const []const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
        ) ![]u8 {
            _ = command;
            _ = instructions_spec_arg;
            _ = instruction_json_args;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = additional_signer_secret_keys_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            return alloc.dupe(u8, "instructions");
        }

        fn buildProgram(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            program_id_arg: ?[]const u8,
            program_accounts_arg: ?[]const u8,
            program_data_arg: ?[]const u8,
            program_data_encoding_arg: ?[]const u8,
            program_data_schema_json_arg: ?[]const u8,
            program_args_json_arg: ?[]const u8,
            program_schema_encoding_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            _ = command;
            _ = program_id_arg;
            _ = program_accounts_arg;
            _ = program_data_arg;
            _ = program_data_encoding_arg;
            _ = program_data_schema_json_arg;
            _ = program_args_json_arg;
            _ = program_schema_encoding_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "program");
        }

        fn buildAnchorIdl(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            idl_arg: ?[]const u8,
            idl_instruction_arg: ?[]const u8,
            idl_program_id_arg: ?[]const u8,
            idl_args_json_arg: ?[]const u8,
            idl_accounts_json_arg: ?[]const u8,
            idl_account_bindings: []const []const u8,
            idl_remaining_accounts: []const []const u8,
            idl_remaining_accounts_json_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            _ = command;
            _ = idl_arg;
            _ = idl_instruction_arg;
            _ = idl_program_id_arg;
            _ = idl_args_json_arg;
            _ = idl_accounts_json_arg;
            _ = idl_account_bindings;
            _ = idl_remaining_accounts;
            _ = idl_remaining_accounts_json_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "anchor-idl");
        }
    }{};

    const instructions_json = try (CliInvokePayloadSource{
        .instructions = .{
            .command = .send_instructions,
            .instructions_spec_arg = "{\"instructions\":[]}",
            .instruction_json_args = &.{},
            .payer_keypair_path_arg = null,
            .payer_secret_key_arg = null,
            .additional_signer_secret_keys_arg = &.{},
            .signer_keypair_paths_arg = null,
            .lookup_tables_arg = null,
            .recent_blockhash_arg = null,
            .nonce_account_arg = null,
            .nonce_authority_secret_key_arg = null,
            .nonce_authority_keypair_path_arg = null,
        },
    }).buildInvocationSpecJson(allocator, builders);
    defer allocator.free(instructions_json);
    try std.testing.expectEqualStrings("instructions", instructions_json);

    const single_instruction_json = try (CliInvokePayloadSource{
        .single_instruction = .{
            .command = .send_idl_invoke,
            .payload_source = .{ .anchor_idl = .{
                .idl_arg = "{}",
                .idl_instruction_arg = "mint",
                .idl_program_id_arg = "Anchor1111111111111111111111111111111111111",
                .idl_args_json_arg = null,
                .idl_accounts_json_arg = null,
                .idl_account_bindings = &.{},
                .idl_remaining_accounts = &.{},
                .idl_remaining_accounts_json_arg = null,
            } },
            .context = .{
                .payer_keypair_path_arg = null,
                .payer_secret_key_arg = null,
                .signer_keypair_paths_arg = null,
                .lookup_tables_arg = null,
                .recent_blockhash_arg = null,
                .nonce_account_arg = null,
                .nonce_authority_secret_key_arg = null,
                .nonce_authority_keypair_path_arg = null,
                .additional_signer_secret_keys_arg = &.{},
            },
        },
    }).buildInvocationSpecJson(allocator, builders);
    defer allocator.free(single_instruction_json);
    try std.testing.expectEqualStrings("anchor-idl", single_instruction_json);
}

test "commands.invoke CliInvokeCommandSpec buildInvocationSpecJson uses behavior-derived payload source" {
    const allocator = std.testing.allocator;
    const spec = CliInvokeCommandSpec{
        .command = .send_versioned_idl_invoke,
        .label = "send-versioned-idl-invoke",
        .behavior = .{
            .payload_family = .anchor_idl,
            .versioned = true,
            .simulate = false,
            .confirm = false,
        },
    };
    const builders = struct {
        fn buildInstructions(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            instructions_spec_arg: ?[]const u8,
            instruction_json_args: []const []const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
        ) ![]u8 {
            _ = command;
            _ = instructions_spec_arg;
            _ = instruction_json_args;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = additional_signer_secret_keys_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            return alloc.dupe(u8, "instructions");
        }

        fn buildProgram(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            program_id_arg: ?[]const u8,
            program_accounts_arg: ?[]const u8,
            program_data_arg: ?[]const u8,
            program_data_encoding_arg: ?[]const u8,
            program_data_schema_json_arg: ?[]const u8,
            program_args_json_arg: ?[]const u8,
            program_schema_encoding_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            _ = command;
            _ = program_id_arg;
            _ = program_accounts_arg;
            _ = program_data_arg;
            _ = program_data_encoding_arg;
            _ = program_data_schema_json_arg;
            _ = program_args_json_arg;
            _ = program_schema_encoding_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = lookup_tables_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "program");
        }

        fn buildAnchorIdl(
            _: @This(),
            alloc: Allocator,
            command: cli.Command,
            idl_arg: ?[]const u8,
            idl_instruction_arg: ?[]const u8,
            idl_program_id_arg: ?[]const u8,
            idl_args_json_arg: ?[]const u8,
            idl_accounts_json_arg: ?[]const u8,
            idl_account_bindings: []const []const u8,
            idl_remaining_accounts: []const []const u8,
            idl_remaining_accounts_json_arg: ?[]const u8,
            payer_keypair_path_arg: ?[]const u8,
            payer_secret_key_arg: ?[]const u8,
            signer_keypair_paths_arg: ?[]const u8,
            lookup_tables_arg: ?[]const u8,
            recent_blockhash_arg: ?[]const u8,
            nonce_account_arg: ?[]const u8,
            nonce_authority_secret_key_arg: ?[]const u8,
            nonce_authority_keypair_path_arg: ?[]const u8,
            additional_signer_secret_keys_arg: []const []const u8,
        ) ![]u8 {
            try std.testing.expectEqual(cli.Command.send_versioned_idl_invoke, command);
            try std.testing.expectEqualStrings("mint", idl_instruction_arg.?);
            try std.testing.expectEqualStrings(
                "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
                lookup_tables_arg.?,
            );
            _ = idl_arg;
            _ = idl_program_id_arg;
            _ = idl_args_json_arg;
            _ = idl_accounts_json_arg;
            _ = idl_account_bindings;
            _ = idl_remaining_accounts;
            _ = idl_remaining_accounts_json_arg;
            _ = payer_keypair_path_arg;
            _ = payer_secret_key_arg;
            _ = signer_keypair_paths_arg;
            _ = recent_blockhash_arg;
            _ = nonce_account_arg;
            _ = nonce_authority_secret_key_arg;
            _ = nonce_authority_keypair_path_arg;
            _ = additional_signer_secret_keys_arg;
            return alloc.dupe(u8, "anchor-idl");
        }
    }{};

    const invocation_spec_json = try spec.buildInvocationSpecJson(allocator, .{
        .instructions_spec_arg = null,
        .instruction_json_args = &.{},
        .program_id_arg = null,
        .program_accounts_arg = null,
        .program_data_arg = null,
        .program_data_encoding_arg = null,
        .program_data_schema_json_arg = null,
        .program_args_json_arg = null,
        .program_schema_encoding_arg = null,
        .idl_arg = "{}",
        .idl_instruction_arg = "mint",
        .idl_program_id_arg = "Anchor1111111111111111111111111111111111111",
        .idl_args_json_arg = null,
        .idl_accounts_json_arg = null,
        .idl_account_bindings = &.{},
        .idl_remaining_accounts = &.{},
        .idl_remaining_accounts_json_arg = null,
    }, .{
        .payer_keypair_path_arg = null,
        .payer_secret_key_arg = null,
        .signer_keypair_paths_arg = null,
        .lookup_tables_arg = "[{\"account_key\":\"Lookup1111111111111111111111111111111111\"}]",
        .recent_blockhash_arg = null,
        .nonce_account_arg = null,
        .nonce_authority_secret_key_arg = null,
        .nonce_authority_keypair_path_arg = null,
        .additional_signer_secret_keys_arg = &.{},
    }, builders);
    defer allocator.free(invocation_spec_json);

    try std.testing.expectEqualStrings("anchor-idl", invocation_spec_json);
    try std.testing.expectEqual(InvokeFamily.instructions, spec.executionFamily());
}
