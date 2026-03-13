const std = @import("std");
const client = @import("../root.zig");

const Allocator = std.mem.Allocator;
const sdk = client.sdk;
const rpc_types = client.rpc_types;

pub const InvokeFamily = enum {
    instructions,
    program,
    anchor_idl,
};

pub const SendInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    send_transaction_options: ?client.SendTransactionOptions = null,
};

pub const SimulateInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    simulate_options: ?client.SimulateTransactionOptions = null,
};

pub const BuildInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
};

pub const GetFeeForInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    commitment: ?client.Commitment = null,
};

pub const SendAndConfirmInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    send_transaction_options: ?client.SendTransactionOptions = null,
    commitment: ?client.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = client.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = client.signature_poll_interval_ms,
};

pub const OwnedInvocationMessage = union(enum) {
    legacy: sdk.OwnedLegacyMessage,
    versioned: sdk.OwnedVersionedMessageV0,

    pub fn deinit(self: *OwnedInvocationMessage, allocator: Allocator) void {
        switch (self.*) {
            .legacy => |*owned| owned.deinit(allocator),
            .versioned => |*owned| owned.deinit(allocator),
        }
    }
};

pub const SignedInvocationTransaction = union(enum) {
    legacy: sdk.SignedLegacyTransaction,
    versioned: sdk.SignedVersionedTransaction,
};

pub const OwnedInvocationSpec = client.instructions_invoke.OwnedInvocationSpec;

pub const OwnedResolvedInvocation = struct {
    payer: sdk.Pubkey,
    signer_pubkeys: []sdk.Pubkey,
    owned_instructions: sdk.OwnedInstructions,
    address_lookup_tables: []sdk.AddressLookupTableAccount,
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,

    pub fn deinit(self: *OwnedResolvedInvocation, allocator: Allocator) void {
        allocator.free(self.signer_pubkeys);
        self.owned_instructions.deinit(allocator);
        for (self.address_lookup_tables) |table| allocator.free(table.addresses);
        allocator.free(self.address_lookup_tables);
        self.* = undefined;
    }
};

pub const InvocationAccountInfo = struct {
    pubkey: sdk.Pubkey,
    is_signer: bool = false,
    is_writable: bool = false,
    is_payer: bool = false,
    is_program: bool = false,
    is_nonce_account: bool = false,
};

pub const OwnedInvocationAccounts = struct {
    accounts: []InvocationAccountInfo,

    pub fn deinit(self: *OwnedInvocationAccounts, allocator: Allocator) void {
        allocator.free(self.accounts);
        self.* = undefined;
    }
};

pub const OwnedInvocationSummary = struct {
    payer: sdk.Pubkey,
    signer_pubkeys: []sdk.Pubkey,
    program_ids: []sdk.Pubkey,
    instruction_count: usize,
    account_count: usize,
    signer_count: usize,
    writable_account_count: usize,
    readonly_account_count: usize,
    address_lookup_table_count: usize,
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,

    pub fn deinit(self: *OwnedInvocationSummary, allocator: Allocator) void {
        allocator.free(self.signer_pubkeys);
        allocator.free(self.program_ids);
        self.* = undefined;
    }
};

pub const InvocationBlockhashMode = enum {
    latest_blockhash,
    explicit_recent_blockhash,
    durable_nonce,
};

pub const OwnedInvocationPlan = struct {
    payer: sdk.Pubkey,
    signer_pubkeys: []sdk.Pubkey,
    program_ids: []sdk.Pubkey,
    lookup_table_pubkeys: []sdk.Pubkey,
    instruction_count: usize,
    account_count: usize,
    signer_count: usize,
    writable_account_count: usize,
    readonly_account_count: usize,
    address_lookup_table_count: usize,
    blockhash_mode: InvocationBlockhashMode,
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,

    pub fn deinit(self: *OwnedInvocationPlan, allocator: Allocator) void {
        allocator.free(self.signer_pubkeys);
        allocator.free(self.program_ids);
        allocator.free(self.lookup_table_pubkeys);
        self.* = undefined;
    }
};

pub const OwnedInvocationPreflight = struct {
    payer: sdk.Pubkey,
    provided_signer_pubkeys: []sdk.Pubkey,
    required_signer_pubkeys: []sdk.Pubkey,
    extra_signer_pubkeys: []sdk.Pubkey,
    writable_pubkeys: []sdk.Pubkey,
    readonly_pubkeys: []sdk.Pubkey,
    program_ids: []sdk.Pubkey,
    lookup_table_pubkeys: []sdk.Pubkey,
    blockhash_mode: InvocationBlockhashMode,
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,

    pub fn deinit(self: *OwnedInvocationPreflight, allocator: Allocator) void {
        allocator.free(self.provided_signer_pubkeys);
        allocator.free(self.required_signer_pubkeys);
        allocator.free(self.extra_signer_pubkeys);
        allocator.free(self.writable_pubkeys);
        allocator.free(self.readonly_pubkeys);
        allocator.free(self.program_ids);
        allocator.free(self.lookup_table_pubkeys);
        self.* = undefined;
    }
};

pub const OwnedInvocationValidation = struct {
    provided_signer_pubkeys: []sdk.Pubkey,
    required_signer_pubkeys: []sdk.Pubkey,
    missing_required_signer_pubkeys: []sdk.Pubkey,
    extra_signer_pubkeys: []sdk.Pubkey,
    duplicate_provided_signer_pubkeys: []sdk.Pubkey,
    lookup_table_pubkeys: []sdk.Pubkey,
    duplicate_lookup_table_pubkeys: []sdk.Pubkey,
    is_valid: bool,

    pub fn deinit(self: *OwnedInvocationValidation, allocator: Allocator) void {
        allocator.free(self.provided_signer_pubkeys);
        allocator.free(self.required_signer_pubkeys);
        allocator.free(self.missing_required_signer_pubkeys);
        allocator.free(self.extra_signer_pubkeys);
        allocator.free(self.duplicate_provided_signer_pubkeys);
        allocator.free(self.lookup_table_pubkeys);
        allocator.free(self.duplicate_lookup_table_pubkeys);
        self.* = undefined;
    }
};

pub const OwnedInvocationLookupCoverage = struct {
    lookup_table_pubkeys: []sdk.Pubkey,
    lookup_table_address_pubkeys: []sdk.Pubkey,
    candidate_pubkeys: []sdk.Pubkey,
    covered_pubkeys: []sdk.Pubkey,
    uncovered_pubkeys: []sdk.Pubkey,
    fully_covered: bool,

    pub fn deinit(self: *OwnedInvocationLookupCoverage, allocator: Allocator) void {
        allocator.free(self.lookup_table_pubkeys);
        allocator.free(self.lookup_table_address_pubkeys);
        allocator.free(self.candidate_pubkeys);
        allocator.free(self.covered_pubkeys);
        allocator.free(self.uncovered_pubkeys);
        self.* = undefined;
    }
};

pub const OwnedInvocationReport = struct {
    summary: OwnedInvocationSummary,
    preflight: OwnedInvocationPreflight,
    validation: OwnedInvocationValidation,
    lookup_coverage: OwnedInvocationLookupCoverage,
    can_execute: bool,
    uses_durable_nonce: bool,
    has_full_lookup_coverage: bool,
    has_missing_required_signers: bool,
    has_extra_signers: bool,
    has_duplicate_signers: bool,
    has_duplicate_lookup_tables: bool,

    pub fn deinit(self: *OwnedInvocationReport, allocator: Allocator) void {
        self.summary.deinit(allocator);
        self.preflight.deinit(allocator);
        self.validation.deinit(allocator);
        self.lookup_coverage.deinit(allocator);
        self.* = undefined;
    }
};

pub const InvocationMode = enum {
    legacy,
    versioned,
};

pub const InvocationModeReport = struct {
    legacy_buildable: bool,
    versioned_buildable: bool,
    preferred_mode: ?InvocationMode,
    validation_passed: bool,
    uses_durable_nonce: bool,
    address_lookup_table_count: usize,
};

pub const PreferredInvocationModeOptions = struct {
    preferred_mode: ?InvocationMode = null,
    allow_fallback: bool = true,
};

pub const BuildPreferredInvocationSpecOptions = struct {
    mode: PreferredInvocationModeOptions = .{},
    build: BuildInvocationSpecOptions = .{},
};

pub const SendPreferredInvocationSpecOptions = struct {
    mode: PreferredInvocationModeOptions = .{},
    send: SendInvocationSpecOptions = .{},
};

pub const SimulatePreferredInvocationSpecOptions = struct {
    mode: PreferredInvocationModeOptions = .{},
    simulate: SimulateInvocationSpecOptions = .{},
};

pub const SendAndConfirmPreferredInvocationSpecOptions = struct {
    mode: PreferredInvocationModeOptions = .{},
    send_and_confirm: SendAndConfirmInvocationSpecOptions = .{},
};

pub fn buildInstructionInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) ![]u8 {
    return switch (family) {
        .instructions => try allocator.dupe(u8, invocation_spec_json),
        .program => try client.program_invoke.buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
            allocator,
            invocation_spec_json,
        ),
        .anchor_idl => try client.anchor_idl_invoke.buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
            allocator,
            invocation_spec_json,
        ),
    };
}

pub fn buildOwnedInvocationSpecFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationSpec {
    if (family == .instructions) {
        return try client.instructions_invoke.buildOwnedInvocationSpecFromJson(
            allocator,
            invocation_spec_json,
        );
    }

    const instruction_spec_json = try buildInstructionInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try client.instructions_invoke.buildOwnedInvocationSpecFromJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn buildOwnedResolvedInvocationFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedResolvedInvocation {
    const owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );

    const signer_pubkeys = try allocator.alloc(sdk.Pubkey, owned_spec.signers.len);
    errdefer allocator.free(signer_pubkeys);
    for (owned_spec.signers, 0..) |signer, index| {
        signer_pubkeys[index] = signer.public_key;
    }

    const owned_instructions = owned_spec.owned_instructions;
    const address_lookup_tables = owned_spec.address_lookup_tables;
    allocator.free(owned_spec.signers);

    return .{
        .payer = owned_spec.payer,
        .signer_pubkeys = signer_pubkeys,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = address_lookup_tables,
        .recent_blockhash = owned_spec.recent_blockhash,
        .nonce_account = owned_spec.nonce_account,
        .nonce_authority = owned_spec.nonce_authority,
    };
}

pub fn buildOwnedInstructionsFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !sdk.OwnedInstructions {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    const owned_instructions = resolved.owned_instructions;
    resolved.owned_instructions.instructions = &.{};
    resolved.deinit(allocator);
    return owned_instructions;
}

pub fn buildInvocationSignerPubkeysFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) ![]sdk.Pubkey {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    const signer_pubkeys = resolved.signer_pubkeys;
    resolved.signer_pubkeys = &.{};
    resolved.deinit(allocator);
    return signer_pubkeys;
}

fn mergeInvocationAccountInfo(
    existing: *InvocationAccountInfo,
    incoming: InvocationAccountInfo,
) void {
    existing.is_signer = existing.is_signer or incoming.is_signer;
    existing.is_writable = existing.is_writable or incoming.is_writable;
    existing.is_payer = existing.is_payer or incoming.is_payer;
    existing.is_program = existing.is_program or incoming.is_program;
    existing.is_nonce_account = existing.is_nonce_account or incoming.is_nonce_account;
}

fn appendOrMergeInvocationAccountInfo(
    allocator: Allocator,
    accounts: *std.ArrayList(InvocationAccountInfo),
    incoming: InvocationAccountInfo,
) !void {
    for (accounts.items) |*existing| {
        if (!std.meta.eql(existing.pubkey, incoming.pubkey)) continue;
        mergeInvocationAccountInfo(existing, incoming);
        return;
    }
    try accounts.append(allocator, incoming);
}

fn buildOwnedInvocationAccountsFromResolved(
    allocator: Allocator,
    resolved: *const OwnedResolvedInvocation,
) !OwnedInvocationAccounts {
    var accounts: std.ArrayList(InvocationAccountInfo) = .empty;
    errdefer accounts.deinit(allocator);

    try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
        .pubkey = resolved.payer,
        .is_signer = true,
        .is_writable = true,
        .is_payer = true,
    });

    for (resolved.signer_pubkeys) |pubkey| {
        try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
            .pubkey = pubkey,
            .is_signer = true,
        });
    }

    if (resolved.nonce_account) |pubkey| {
        try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
            .pubkey = pubkey,
            .is_writable = true,
            .is_nonce_account = true,
        });
    }

    if (resolved.nonce_authority) |pubkey| {
        try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
            .pubkey = pubkey,
            .is_signer = true,
        });
    }

    for (resolved.owned_instructions.instructions) |instruction| {
        try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
            .pubkey = instruction.program_id,
            .is_program = true,
        });
        for (instruction.accounts) |account| {
            try appendOrMergeInvocationAccountInfo(allocator, &accounts, .{
                .pubkey = account.pubkey,
                .is_signer = account.is_signer,
                .is_writable = account.is_writable,
            });
        }
    }

    return .{ .accounts = try accounts.toOwnedSlice(allocator) };
}

pub fn buildInvocationAccountsFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationAccounts {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    defer resolved.deinit(allocator);

    return try buildOwnedInvocationAccountsFromResolved(allocator, &resolved);
}

fn appendUniquePubkey(
    allocator: Allocator,
    pubkeys: *std.ArrayList(sdk.Pubkey),
    pubkey: sdk.Pubkey,
) !void {
    for (pubkeys.items) |existing| {
        if (std.meta.eql(existing, pubkey)) return;
    }
    try pubkeys.append(allocator, pubkey);
}

fn pubkeySliceContains(
    pubkeys: []const sdk.Pubkey,
    target: sdk.Pubkey,
) bool {
    for (pubkeys) |pubkey| {
        if (std.meta.eql(pubkey, target)) return true;
    }
    return false;
}

fn collectDuplicatePubkeys(
    allocator: Allocator,
    pubkeys: []const sdk.Pubkey,
) ![]sdk.Pubkey {
    var duplicates: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer duplicates.deinit(allocator);

    for (pubkeys, 0..) |pubkey, index| {
        for (pubkeys[index + 1 ..]) |other| {
            if (!std.meta.eql(pubkey, other)) continue;
            try appendUniquePubkey(allocator, &duplicates, pubkey);
            break;
        }
    }

    return try duplicates.toOwnedSlice(allocator);
}

pub fn buildInvocationSummaryFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationSummary {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer resolved.deinit(allocator);

    var accounts = try buildOwnedInvocationAccountsFromResolved(allocator, &resolved);
    defer accounts.deinit(allocator);

    var writable_account_count: usize = 0;
    for (accounts.accounts) |account| {
        if (account.is_writable) writable_account_count += 1;
    }

    var program_ids: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer program_ids.deinit(allocator);
    for (resolved.owned_instructions.instructions) |instruction| {
        try appendUniquePubkey(allocator, &program_ids, instruction.program_id);
    }

    const signer_pubkeys = resolved.signer_pubkeys;
    resolved.signer_pubkeys = &.{};

    return .{
        .payer = resolved.payer,
        .signer_pubkeys = signer_pubkeys,
        .program_ids = try program_ids.toOwnedSlice(allocator),
        .instruction_count = resolved.owned_instructions.instructions.len,
        .account_count = accounts.accounts.len,
        .signer_count = signer_pubkeys.len,
        .writable_account_count = writable_account_count,
        .readonly_account_count = accounts.accounts.len - writable_account_count,
        .address_lookup_table_count = resolved.address_lookup_tables.len,
        .recent_blockhash = resolved.recent_blockhash,
        .nonce_account = resolved.nonce_account,
        .nonce_authority = resolved.nonce_authority,
    };
}

pub fn buildInvocationLookupTablePubkeysFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) ![]sdk.Pubkey {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    defer resolved.deinit(allocator);

    const lookup_table_pubkeys = try allocator.alloc(sdk.Pubkey, resolved.address_lookup_tables.len);
    for (resolved.address_lookup_tables, 0..) |table, index| {
        lookup_table_pubkeys[index] = table.account_key;
    }
    return lookup_table_pubkeys;
}

pub fn buildInvocationPlanFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationPlan {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer resolved.deinit(allocator);

    var accounts = try buildOwnedInvocationAccountsFromResolved(allocator, &resolved);
    defer accounts.deinit(allocator);

    var writable_account_count: usize = 0;
    for (accounts.accounts) |account| {
        if (account.is_writable) writable_account_count += 1;
    }

    var program_ids: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer program_ids.deinit(allocator);
    for (resolved.owned_instructions.instructions) |instruction| {
        try appendUniquePubkey(allocator, &program_ids, instruction.program_id);
    }

    const lookup_table_pubkeys = try allocator.alloc(sdk.Pubkey, resolved.address_lookup_tables.len);
    errdefer allocator.free(lookup_table_pubkeys);
    for (resolved.address_lookup_tables, 0..) |table, index| {
        lookup_table_pubkeys[index] = table.account_key;
    }

    const signer_pubkeys = resolved.signer_pubkeys;
    resolved.signer_pubkeys = &.{};

    return .{
        .payer = resolved.payer,
        .signer_pubkeys = signer_pubkeys,
        .program_ids = try program_ids.toOwnedSlice(allocator),
        .lookup_table_pubkeys = lookup_table_pubkeys,
        .instruction_count = resolved.owned_instructions.instructions.len,
        .account_count = accounts.accounts.len,
        .signer_count = signer_pubkeys.len,
        .writable_account_count = writable_account_count,
        .readonly_account_count = accounts.accounts.len - writable_account_count,
        .address_lookup_table_count = resolved.address_lookup_tables.len,
        .blockhash_mode = if (resolved.nonce_account != null)
            .durable_nonce
        else if (resolved.recent_blockhash != null)
            .explicit_recent_blockhash
        else
            .latest_blockhash,
        .recent_blockhash = resolved.recent_blockhash,
        .nonce_account = resolved.nonce_account,
        .nonce_authority = resolved.nonce_authority,
    };
}

pub fn buildInvocationPreflightFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationPreflight {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer resolved.deinit(allocator);

    var accounts = try buildOwnedInvocationAccountsFromResolved(allocator, &resolved);
    defer accounts.deinit(allocator);

    var required_signers: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer required_signers.deinit(allocator);
    var writable_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer writable_pubkeys.deinit(allocator);
    var readonly_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer readonly_pubkeys.deinit(allocator);
    var program_ids: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer program_ids.deinit(allocator);

    for (accounts.accounts) |account| {
        if (account.is_signer or account.is_payer) {
            try appendUniquePubkey(allocator, &required_signers, account.pubkey);
        }
        if (account.is_writable) {
            try appendUniquePubkey(allocator, &writable_pubkeys, account.pubkey);
        } else {
            try appendUniquePubkey(allocator, &readonly_pubkeys, account.pubkey);
        }
        if (account.is_program) {
            try appendUniquePubkey(allocator, &program_ids, account.pubkey);
        }
    }

    const lookup_table_pubkeys = try allocator.alloc(sdk.Pubkey, resolved.address_lookup_tables.len);
    errdefer allocator.free(lookup_table_pubkeys);
    for (resolved.address_lookup_tables, 0..) |table, index| {
        lookup_table_pubkeys[index] = table.account_key;
    }

    var extra_signers: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer extra_signers.deinit(allocator);
    for (resolved.signer_pubkeys) |pubkey| {
        if (!pubkeySliceContains(required_signers.items, pubkey)) {
            try appendUniquePubkey(allocator, &extra_signers, pubkey);
        }
    }

    const provided_signer_pubkeys = resolved.signer_pubkeys;
    resolved.signer_pubkeys = &.{};

    return .{
        .payer = resolved.payer,
        .provided_signer_pubkeys = provided_signer_pubkeys,
        .required_signer_pubkeys = try required_signers.toOwnedSlice(allocator),
        .extra_signer_pubkeys = try extra_signers.toOwnedSlice(allocator),
        .writable_pubkeys = try writable_pubkeys.toOwnedSlice(allocator),
        .readonly_pubkeys = try readonly_pubkeys.toOwnedSlice(allocator),
        .program_ids = try program_ids.toOwnedSlice(allocator),
        .lookup_table_pubkeys = lookup_table_pubkeys,
        .blockhash_mode = if (resolved.nonce_account != null)
            .durable_nonce
        else if (resolved.recent_blockhash != null)
            .explicit_recent_blockhash
        else
            .latest_blockhash,
        .recent_blockhash = resolved.recent_blockhash,
        .nonce_account = resolved.nonce_account,
        .nonce_authority = resolved.nonce_authority,
    };
}

pub fn buildInvocationValidationFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationValidation {
    var preflight = try buildInvocationPreflightFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer preflight.deinit(allocator);

    var missing_required_signers: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer missing_required_signers.deinit(allocator);
    for (preflight.required_signer_pubkeys) |pubkey| {
        if (!pubkeySliceContains(preflight.provided_signer_pubkeys, pubkey)) {
            try appendUniquePubkey(allocator, &missing_required_signers, pubkey);
        }
    }

    const duplicate_provided_signers = try collectDuplicatePubkeys(
        allocator,
        preflight.provided_signer_pubkeys,
    );
    errdefer allocator.free(duplicate_provided_signers);
    const duplicate_lookup_table_pubkeys = try collectDuplicatePubkeys(
        allocator,
        preflight.lookup_table_pubkeys,
    );
    errdefer allocator.free(duplicate_lookup_table_pubkeys);

    const provided_signer_pubkeys = preflight.provided_signer_pubkeys;
    const required_signer_pubkeys = preflight.required_signer_pubkeys;
    const extra_signer_pubkeys = preflight.extra_signer_pubkeys;
    const lookup_table_pubkeys = preflight.lookup_table_pubkeys;
    preflight.provided_signer_pubkeys = &.{};
    preflight.required_signer_pubkeys = &.{};
    preflight.extra_signer_pubkeys = &.{};
    preflight.lookup_table_pubkeys = &.{};
    preflight.deinit(allocator);

    const missing_required_signer_pubkeys = try missing_required_signers.toOwnedSlice(allocator);

    return .{
        .provided_signer_pubkeys = provided_signer_pubkeys,
        .required_signer_pubkeys = required_signer_pubkeys,
        .missing_required_signer_pubkeys = missing_required_signer_pubkeys,
        .extra_signer_pubkeys = extra_signer_pubkeys,
        .duplicate_provided_signer_pubkeys = duplicate_provided_signers,
        .lookup_table_pubkeys = lookup_table_pubkeys,
        .duplicate_lookup_table_pubkeys = duplicate_lookup_table_pubkeys,
        .is_valid = missing_required_signer_pubkeys.len == 0 and extra_signer_pubkeys.len == 0 and duplicate_provided_signers.len == 0 and duplicate_lookup_table_pubkeys.len == 0,
    };
}

pub fn buildInvocationLookupCoverageFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationLookupCoverage {
    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer resolved.deinit(allocator);

    var accounts = try buildOwnedInvocationAccountsFromResolved(allocator, &resolved);
    defer accounts.deinit(allocator);

    var lookup_table_address_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer lookup_table_address_pubkeys.deinit(allocator);
    const lookup_table_pubkeys = try allocator.alloc(sdk.Pubkey, resolved.address_lookup_tables.len);
    errdefer allocator.free(lookup_table_pubkeys);
    for (resolved.address_lookup_tables, 0..) |table, index| {
        lookup_table_pubkeys[index] = table.account_key;
        for (table.addresses) |pubkey| {
            try appendUniquePubkey(allocator, &lookup_table_address_pubkeys, pubkey);
        }
    }

    var candidate_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer candidate_pubkeys.deinit(allocator);
    for (accounts.accounts) |account| {
        if (account.is_signer or account.is_payer or account.is_program) continue;
        try appendUniquePubkey(allocator, &candidate_pubkeys, account.pubkey);
    }

    var covered_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer covered_pubkeys.deinit(allocator);
    var uncovered_pubkeys: std.ArrayList(sdk.Pubkey) = .empty;
    errdefer uncovered_pubkeys.deinit(allocator);
    for (candidate_pubkeys.items) |pubkey| {
        if (pubkeySliceContains(lookup_table_address_pubkeys.items, pubkey)) {
            try appendUniquePubkey(allocator, &covered_pubkeys, pubkey);
        } else {
            try appendUniquePubkey(allocator, &uncovered_pubkeys, pubkey);
        }
    }

    return .{
        .lookup_table_pubkeys = lookup_table_pubkeys,
        .lookup_table_address_pubkeys = try lookup_table_address_pubkeys.toOwnedSlice(allocator),
        .candidate_pubkeys = try candidate_pubkeys.toOwnedSlice(allocator),
        .covered_pubkeys = try covered_pubkeys.toOwnedSlice(allocator),
        .uncovered_pubkeys = try uncovered_pubkeys.toOwnedSlice(allocator),
        .fully_covered = covered_pubkeys.items.len == candidate_pubkeys.items.len,
    };
}

pub fn buildInvocationReportFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationReport {
    var summary = try buildInvocationSummaryFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer summary.deinit(allocator);

    var preflight = try buildInvocationPreflightFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer preflight.deinit(allocator);

    var validation = try buildInvocationValidationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer validation.deinit(allocator);

    var lookup_coverage = try buildInvocationLookupCoverageFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer lookup_coverage.deinit(allocator);

    return .{
        .summary = summary,
        .preflight = preflight,
        .validation = validation,
        .lookup_coverage = lookup_coverage,
        .can_execute = validation.is_valid,
        .uses_durable_nonce = summary.nonce_account != null,
        .has_full_lookup_coverage = lookup_coverage.fully_covered,
        .has_missing_required_signers = validation.missing_required_signer_pubkeys.len != 0,
        .has_extra_signers = validation.extra_signer_pubkeys.len != 0,
        .has_duplicate_signers = validation.duplicate_provided_signer_pubkeys.len != 0,
        .has_duplicate_lookup_tables = validation.duplicate_lookup_table_pubkeys.len != 0,
    };
}

pub fn buildInvocationModeReportFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !InvocationModeReport {
    var report = try buildInvocationReportFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    defer report.deinit(allocator);

    const legacy_buildable = blk: {
        const encoded = buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        ) catch break :blk false;
        allocator.free(encoded);
        break :blk true;
    };

    const versioned_buildable = blk: {
        const encoded = buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        ) catch break :blk false;
        allocator.free(encoded);
        break :blk true;
    };

    return .{
        .legacy_buildable = legacy_buildable,
        .versioned_buildable = versioned_buildable,
        .preferred_mode = if (versioned_buildable and report.summary.address_lookup_table_count != 0)
            .versioned
        else if (legacy_buildable)
            .legacy
        else if (versioned_buildable)
            .versioned
        else
            null,
        .validation_passed = report.validation.is_valid,
        .uses_durable_nonce = report.uses_durable_nonce,
        .address_lookup_table_count = report.summary.address_lookup_table_count,
    };
}

fn resolvePreferredInvocationMode(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !InvocationMode {
    const mode_report = try buildInvocationModeReportFromInvocationSpecJson(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        options.build,
    );

    if (options.mode.preferred_mode) |preferred_mode| {
        if ((preferred_mode == .legacy and mode_report.legacy_buildable) or
            (preferred_mode == .versioned and mode_report.versioned_buildable))
        {
            return preferred_mode;
        }
        if (!options.mode.allow_fallback) return error.NoBuildableInvocationMode;
    }

    return mode_report.preferred_mode orelse error.NoBuildableInvocationMode;
}

pub fn buildPreferredMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        options,
    );
    return try buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.build,
    );
}

pub fn buildPreferredTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        options,
    );
    return try buildTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.build,
    );
}

pub fn buildPreferredSignedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !SignedInvocationTransaction {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        options,
    );
    return try buildSignedTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.build,
    );
}

pub fn sendPreferredTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendPreferredInvocationSpecOptions,
) ![]const u8 {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.send.blockhash_commitment },
        },
    );
    return try sendTransactionFromInvocationSpecJson(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.send,
    );
}

pub fn simulatePreferredTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SimulatePreferredInvocationSpecOptions,
) !client.SimulatedTransaction {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.simulate.blockhash_commitment },
        },
    );
    return try simulateTransactionFromInvocationSpecJson(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.simulate,
    );
}

pub fn sendAndConfirmPreferredInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) ![]const u8 {
    const mode = try resolvePreferredInvocationMode(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
        },
    );
    return try sendAndConfirmInvocationSpecJson(
        allocator,
        rpc,
        family,
        mode == .versioned,
        invocation_spec_json,
        options.send_and_confirm,
    );
}

pub fn sendInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
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
    if (confirm) {
        return sendAndConfirmInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
            .blockhash_commitment = blockhash_commitment,
            .send_transaction_options = send_transaction_options,
            .commitment = confirm_commitment,
            .search_transaction_history = search_transaction_history,
            .timeout_ms = timeout_ms,
            .poll_interval_ms = poll_interval_ms,
        });
    }
    return sendTransactionFromInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
        .blockhash_commitment = blockhash_commitment,
        .send_transaction_options = send_transaction_options,
    });
}

pub fn simulateInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    simulate_options: ?client.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return simulateTransactionFromInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
        .blockhash_commitment = blockhash_commitment,
        .simulate_options = simulate_options,
    });
}

pub fn sendTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
        .program => if (versioned)
            client.program_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.program_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
    };
}

pub fn sendAndConfirmInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .program => if (versioned)
            client.program_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.program_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
    };
}

pub fn simulateTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SimulateInvocationSpecOptions,
) !client.SimulatedTransaction {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
        .program => if (versioned)
            client.program_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.program_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
    };
}

pub fn sendAndConfirmInvocationSpecJsonWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    send_transaction_options: ?client.SendTransactionOptions,
    confirm_commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{
            .blockhash_commitment = blockhash_commitment,
            .send_transaction_options = send_transaction_options,
            .commitment = confirm_commitment,
            .search_transaction_history = search_transaction_history,
            .timeout_ms = timeout_ms,
            .poll_interval_ms = poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.instructions_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .program => if (versioned)
            client.program_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.program_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
    };
}

pub fn getFeeForMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    commitment: ?client.Commitment,
) !client.FeeForMessage {
    return getFeeForInvocationSpecJson(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{
            .blockhash_commitment = blockhash_commitment,
            .commitment = commitment,
        },
    );
}

pub fn getFeeForInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: GetFeeForInvocationSpecOptions,
) !client.FeeForMessage {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.instructions_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
        .program => if (versioned)
            client.program_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.program_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.anchor_idl_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
    };
}

pub fn buildTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedLegacyMessage {
    return buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedLegacyMessage {
    return switch (family) {
        .instructions => client.instructions_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildLegacyMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildLegacyMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildOwnedMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !OwnedInvocationMessage {
    return buildOwnedMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !OwnedInvocationMessage {
    return if (versioned)
        .{
            .versioned = try buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        }
    else
        .{
            .legacy = try buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        };
}

pub fn buildMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedLegacyTransaction {
    return buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.SignedLegacyTransaction {
    return switch (family) {
        .instructions => client.instructions_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildSignedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !SignedInvocationTransaction {
    return buildSignedTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !SignedInvocationTransaction {
    return if (versioned)
        .{
            .versioned = try buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        }
    else
        .{
            .legacy = try buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        };
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedVersionedMessageV0 {
    return buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedVersionedMessageV0 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedVersionedTransaction {
    return buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.SignedVersionedTransaction {
    return switch (family) {
        .instructions => client.instructions_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

fn allocMinimalInstructionsInvocationSpecJson(
    allocator: Allocator,
    payer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
}

fn allocMinimalProgramInvocationSpecJson(
    allocator: Allocator,
    payer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "program_id":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","isSigner":true,"isWritable":false}}],
        \\  "dataBytes":[9,8,7]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            program_id_base58,
        },
    );
}

fn allocRichInstructionsInvocationSpecJson(
    allocator: Allocator,
    payer_fill: u8,
    additional_signer_fill: u8,
    nonce_authority_fill: u8,
    program_fill: u8,
    nonce_fill: u8,
    account_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const additional_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{additional_signer_fill} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{nonce_authority_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{nonce_fill} ** 32);
    const writable_account = sdk.Pubkey.fromBytes([_]u8{account_fill} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const additional_signer_secret_key = additional_signer_raw.secret_key.toBytes();
    const additional_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &additional_signer_secret_key);
    defer allocator.free(additional_signer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const writable_account_base58 = try writable_account.toBase58(allocator);
    defer allocator.free(writable_account_base58);
    const additional_signer_pubkey_base58 = try additional_signer_raw.public_key.toBase58(allocator);
    defer allocator.free(additional_signer_pubkey_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[
        \\    {{
        \\      "program_id":"{s}",
        \\      "accounts":[
        \\        {{"pubkey":"{s}","isSigner":true,"isWritable":true}},
        \\        {{"pubkey":"{s}","isSigner":false,"isWritable":true}}
        \\      ],
        \\      "dataBytes":[4,5,6]
        \\    }}
        \\  ]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            additional_signer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
            additional_signer_pubkey_base58,
            writable_account_base58,
        },
    );
}

fn allocProgramInvocationSpecJsonWithLookupTable(
    allocator: Allocator,
    payer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
    lookup_table_fill: u8,
    lookup_address_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{lookup_table_fill} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes([_]u8{lookup_address_fill} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "program_id":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","isSigner":false,"isWritable":false}}],
        \\  "address_lookup_tables":[{{"accountKey":"{s}","addresses":["{s}"]}}],
        \\  "dataBytes":[1]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            lookup_address_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
}

fn allocInstructionsInvocationSpecJsonWithUnusedSigner(
    allocator: Allocator,
    payer_fill: u8,
    additional_signer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const additional_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{additional_signer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const additional_signer_secret_key = additional_signer_raw.secret_key.toBytes();
    const additional_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &additional_signer_secret_key);
    defer allocator.free(additional_signer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[2]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            additional_signer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
}

fn allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(
    allocator: Allocator,
    payer_fill: u8,
    extra_signer_fill: u8,
    missing_signer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const extra_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{extra_signer_fill} ** 32);
    const missing_signer = sdk.Pubkey.fromBytes([_]u8{missing_signer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const extra_signer_secret_key = extra_signer_raw.secret_key.toBytes();
    const extra_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &extra_signer_secret_key);
    defer allocator.free(extra_signer_secret_key_base58);
    const missing_signer_base58 = try missing_signer.toBase58(allocator);
    defer allocator.free(missing_signer_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}"],
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[
        \\    {{
        \\      "program_id":"{s}",
        \\      "accounts":[{{"pubkey":"{s}","isSigner":true,"isWritable":false}}],
        \\      "dataBytes":[3]
        \\    }}
        \\  ]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            extra_signer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            missing_signer_base58,
        },
    );
}

fn allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(
    allocator: Allocator,
    payer_fill: u8,
    duplicate_signer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
    lookup_table_fill: u8,
    lookup_address_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{duplicate_signer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{lookup_table_fill} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes([_]u8{lookup_address_fill} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const duplicate_signer_secret_key = duplicate_signer_raw.secret_key.toBytes();
    const duplicate_signer_secret_key_base58 = try sdk.encodeBase58(allocator, &duplicate_signer_secret_key);
    defer allocator.free(duplicate_signer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "additional_signer_secret_keys":["{s}","{s}"],
        \\  "recent_blockhash":"{s}",
        \\  "program_id":"{s}",
        \\  "address_lookup_tables":[
        \\    {{"accountKey":"{s}","addresses":["{s}"]}},
        \\    {{"accountKey":"{s}","addresses":["{s}"]}}
        \\  ],
        \\  "dataBytes":[5]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            duplicate_signer_secret_key_base58,
            duplicate_signer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            lookup_table_base58,
            lookup_address_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
}

fn findInvocationAccountInfo(
    accounts: []const InvocationAccountInfo,
    pubkey: sdk.Pubkey,
) ?InvocationAccountInfo {
    for (accounts) |account| {
        if (std.meta.eql(account.pubkey, pubkey)) return account;
    }
    return null;
}

test "invoke.buildInstructionInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 41, 42, 43);
    defer allocator.free(program_spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"instructions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"program_id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"payer_secret_key\"") != null);
}

test "invoke.buildOwnedInvocationSpecFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 51, 52, 53);
    defer allocator.free(program_spec_json);

    var owned = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned.instructions.len);
    try std.testing.expectEqual(@as(usize, 0), owned.additional_signers.len);
    try std.testing.expectEqual(@as(usize, 0), owned.address_lookup_tables.len);
    try std.testing.expectEqual(@as(usize, 1), owned.instructions[0].accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 9, 8, 7 }, owned.instructions[0].data);
}

test "invoke.buildOwnedResolvedInvocationFromInvocationSpecJson removes secret key material" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 61, 62, 63);
    defer allocator.free(program_spec_json);

    var resolved = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer resolved.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), resolved.signer_pubkeys.len);
    try std.testing.expectEqual(resolved.payer, resolved.signer_pubkeys[0]);
    try std.testing.expectEqual(@as(usize, 1), resolved.owned_instructions.instructions.len);
    try std.testing.expectEqual(@as(usize, 0), resolved.address_lookup_tables.len);
    try std.testing.expect(resolved.recent_blockhash != null);
    try std.testing.expectEqualSlices(u8, &.{ 9, 8, 7 }, resolved.owned_instructions.instructions[0].data);
}

test "invoke.buildInvocationSignerPubkeysFromInvocationSpecJson dispatches instructions family" {
    const allocator = std.testing.allocator;

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 71, 72, 73);
    defer allocator.free(spec_json);

    const signer_pubkeys = try buildInvocationSignerPubkeysFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer allocator.free(signer_pubkeys);

    try std.testing.expectEqual(@as(usize, 1), signer_pubkeys.len);
}

test "invoke.buildOwnedInstructionsFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 81, 82, 83);
    defer allocator.free(program_spec_json);

    var owned_instructions = try buildOwnedInstructionsFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer owned_instructions.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned_instructions.instructions.len);
    try std.testing.expectEqual(@as(usize, 1), owned_instructions.instructions[0].accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 9, 8, 7 }, owned_instructions.instructions[0].data);
}

test "invoke.buildInvocationAccountsFromInvocationSpecJson merges signer and nonce roles" {
    const allocator = std.testing.allocator;

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{91} ** 32);
    const additional_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{92} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{93} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{94} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{95} ** 32);
    const writable_account = sdk.Pubkey.fromBytes([_]u8{96} ** 32);

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 91, 92, 93, 94, 95, 96);
    defer allocator.free(spec_json);

    var accounts = try buildInvocationAccountsFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer accounts.deinit(allocator);

    const payer_info = findInvocationAccountInfo(accounts.accounts, payer_raw.public_key).?;
    try std.testing.expect(payer_info.is_payer);
    try std.testing.expect(payer_info.is_signer);
    try std.testing.expect(payer_info.is_writable);

    const additional_signer_info = findInvocationAccountInfo(accounts.accounts, additional_signer_raw.public_key).?;
    try std.testing.expect(additional_signer_info.is_signer);
    try std.testing.expect(additional_signer_info.is_writable);

    const nonce_authority_info = findInvocationAccountInfo(accounts.accounts, nonce_authority_raw.public_key).?;
    try std.testing.expect(nonce_authority_info.is_signer);
    try std.testing.expect(!nonce_authority_info.is_nonce_account);

    const nonce_account_info = findInvocationAccountInfo(accounts.accounts, nonce_account).?;
    try std.testing.expect(nonce_account_info.is_writable);
    try std.testing.expect(nonce_account_info.is_nonce_account);

    const program_info = findInvocationAccountInfo(accounts.accounts, program_id).?;
    try std.testing.expect(program_info.is_program);
    try std.testing.expect(!program_info.is_signer);

    const writable_account_info = findInvocationAccountInfo(accounts.accounts, writable_account).?;
    try std.testing.expect(writable_account_info.is_writable);
}

test "invoke.buildInvocationAccountsFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{102} ** 32);

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 101, 102, 103);
    defer allocator.free(program_spec_json);

    var accounts = try buildInvocationAccountsFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer accounts.deinit(allocator);

    try std.testing.expect(accounts.accounts.len >= 3);
    const program_info = findInvocationAccountInfo(accounts.accounts, program_id).?;
    try std.testing.expect(program_info.is_program);
}

test "invoke.buildInvocationSummaryFromInvocationSpecJson summarizes instructions family" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{114} ** 32);

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 111, 112, 113, 114, 115, 116);
    defer allocator.free(spec_json);

    var summary = try buildInvocationSummaryFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), summary.instruction_count);
    try std.testing.expectEqual(@as(usize, 6), summary.account_count);
    try std.testing.expectEqual(@as(usize, 3), summary.signer_count);
    try std.testing.expectEqual(@as(usize, 4), summary.writable_account_count);
    try std.testing.expectEqual(@as(usize, 2), summary.readonly_account_count);
    try std.testing.expectEqual(@as(usize, 1), summary.program_ids.len);
    try std.testing.expect(std.meta.eql(summary.program_ids[0], program_id));
    try std.testing.expect(summary.recent_blockhash == null);
    try std.testing.expect(summary.nonce_account != null);
    try std.testing.expect(summary.nonce_authority != null);
}

test "invoke.buildInvocationSummaryFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{122} ** 32);

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 121, 122, 123);
    defer allocator.free(program_spec_json);

    var summary = try buildInvocationSummaryFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), summary.instruction_count);
    try std.testing.expectEqual(@as(usize, 1), summary.signer_count);
    try std.testing.expectEqual(@as(usize, 1), summary.program_ids.len);
    try std.testing.expect(std.meta.eql(summary.program_ids[0], program_id));
    try std.testing.expect(summary.recent_blockhash != null);
}

test "invoke.buildInvocationLookupTablePubkeysFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{134} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 131, 132, 133, 134, 135);
    defer allocator.free(spec_json);

    const lookup_table_pubkeys = try buildInvocationLookupTablePubkeysFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer allocator.free(lookup_table_pubkeys);

    try std.testing.expectEqual(@as(usize, 1), lookup_table_pubkeys.len);
    try std.testing.expect(std.meta.eql(lookup_table_pubkeys[0], lookup_table));
}

test "invoke.buildInvocationPlanFromInvocationSpecJson summarizes durable nonce and lookup tables" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{144} ** 32);

    const instructions_spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 141, 142, 143, 144, 145, 146);
    defer allocator.free(instructions_spec_json);

    var nonce_plan = try buildInvocationPlanFromInvocationSpecJson(
        allocator,
        .instructions,
        instructions_spec_json,
    );
    defer nonce_plan.deinit(allocator);

    try std.testing.expectEqual(InvocationBlockhashMode.durable_nonce, nonce_plan.blockhash_mode);
    try std.testing.expectEqual(@as(usize, 0), nonce_plan.lookup_table_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 3), nonce_plan.signer_count);
    try std.testing.expectEqual(@as(usize, 1), nonce_plan.program_ids.len);
    try std.testing.expect(std.meta.eql(nonce_plan.program_ids[0], program_id));

    const program_spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 151, 152, 153, 154, 155);
    defer allocator.free(program_spec_json);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{154} ** 32);

    var recent_plan = try buildInvocationPlanFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer recent_plan.deinit(allocator);

    try std.testing.expectEqual(InvocationBlockhashMode.explicit_recent_blockhash, recent_plan.blockhash_mode);
    try std.testing.expectEqual(@as(usize, 1), recent_plan.lookup_table_pubkeys.len);
    try std.testing.expect(std.meta.eql(recent_plan.lookup_table_pubkeys[0], lookup_table));
    try std.testing.expectEqual(@as(usize, 1), recent_plan.address_lookup_table_count);
    try std.testing.expect(recent_plan.recent_blockhash != null);
}

test "invoke.buildInvocationPreflightFromInvocationSpecJson separates required and extra signers" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{161} ** 32);
    const additional_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{162} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{163} ** 32);

    const spec_json = try allocInstructionsInvocationSpecJsonWithUnusedSigner(allocator, 161, 162, 163, 164);
    defer allocator.free(spec_json);

    var preflight = try buildInvocationPreflightFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer preflight.deinit(allocator);

    try std.testing.expectEqual(InvocationBlockhashMode.explicit_recent_blockhash, preflight.blockhash_mode);
    try std.testing.expectEqual(@as(usize, 2), preflight.provided_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), preflight.required_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), preflight.extra_signer_pubkeys.len);
    try std.testing.expect(std.meta.eql(preflight.required_signer_pubkeys[0], payer_raw.public_key));
    try std.testing.expect(std.meta.eql(preflight.extra_signer_pubkeys[0], additional_signer_raw.public_key));
    try std.testing.expectEqual(@as(usize, 1), preflight.program_ids.len);
    try std.testing.expect(std.meta.eql(preflight.program_ids[0], program_id));
}

test "invoke.buildInvocationPreflightFromInvocationSpecJson dispatches program lookup tables" {
    const allocator = std.testing.allocator;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{174} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 171, 172, 173, 174, 175);
    defer allocator.free(spec_json);

    var preflight = try buildInvocationPreflightFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer preflight.deinit(allocator);

    try std.testing.expectEqual(InvocationBlockhashMode.explicit_recent_blockhash, preflight.blockhash_mode);
    try std.testing.expectEqual(@as(usize, 1), preflight.lookup_table_pubkeys.len);
    try std.testing.expect(std.meta.eql(preflight.lookup_table_pubkeys[0], lookup_table));
    try std.testing.expectEqual(@as(usize, 1), preflight.required_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 0), preflight.extra_signer_pubkeys.len);
}

test "invoke.buildInvocationValidationFromInvocationSpecJson detects missing and extra signers" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{181} ** 32);
    const extra_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{182} ** 32);
    const missing_signer = sdk.Pubkey.fromBytes([_]u8{183} ** 32);

    const spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(allocator, 181, 182, 183, 184, 185);
    defer allocator.free(spec_json);

    var validation = try buildInvocationValidationFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer validation.deinit(allocator);

    try std.testing.expect(!validation.is_valid);
    try std.testing.expectEqual(@as(usize, 2), validation.provided_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 2), validation.required_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), validation.missing_required_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), validation.extra_signer_pubkeys.len);
    try std.testing.expect(std.meta.eql(validation.required_signer_pubkeys[0], payer_raw.public_key) or std.meta.eql(validation.required_signer_pubkeys[1], payer_raw.public_key));
    try std.testing.expect(std.meta.eql(validation.missing_required_signer_pubkeys[0], missing_signer));
    try std.testing.expect(std.meta.eql(validation.extra_signer_pubkeys[0], extra_signer_raw.public_key));
}

test "invoke.buildInvocationValidationFromInvocationSpecJson detects duplicate signers and lookup tables" {
    const allocator = std.testing.allocator;
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{192} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{195} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(allocator, 191, 192, 193, 194, 195, 196);
    defer allocator.free(spec_json);

    var validation = try buildInvocationValidationFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer validation.deinit(allocator);

    try std.testing.expect(!validation.is_valid);
    try std.testing.expectEqual(@as(usize, 1), validation.duplicate_provided_signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), validation.duplicate_lookup_table_pubkeys.len);
    try std.testing.expect(std.meta.eql(validation.duplicate_provided_signer_pubkeys[0], duplicate_signer_raw.public_key));
    try std.testing.expect(std.meta.eql(validation.duplicate_lookup_table_pubkeys[0], lookup_table));
}

test "invoke.buildInvocationLookupCoverageFromInvocationSpecJson detects uncovered nonce path" {
    const allocator = std.testing.allocator;

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 201, 202, 203, 204, 205, 206);
    defer allocator.free(spec_json);

    var coverage = try buildInvocationLookupCoverageFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer coverage.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), coverage.lookup_table_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 2), coverage.candidate_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 0), coverage.covered_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 2), coverage.uncovered_pubkeys.len);
    try std.testing.expect(!coverage.fully_covered);
}

test "invoke.buildInvocationLookupCoverageFromInvocationSpecJson detects full program lookup coverage" {
    const allocator = std.testing.allocator;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{214} ** 32);
    const lookup_address = sdk.Pubkey.fromBytes([_]u8{215} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 211, 212, 213, 214, 215);
    defer allocator.free(spec_json);

    var coverage = try buildInvocationLookupCoverageFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer coverage.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), coverage.lookup_table_pubkeys.len);
    try std.testing.expect(std.meta.eql(coverage.lookup_table_pubkeys[0], lookup_table));
    try std.testing.expectEqual(@as(usize, 1), coverage.lookup_table_address_pubkeys.len);
    try std.testing.expect(std.meta.eql(coverage.lookup_table_address_pubkeys[0], lookup_address));
    try std.testing.expectEqual(@as(usize, 1), coverage.candidate_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), coverage.covered_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 0), coverage.uncovered_pubkeys.len);
    try std.testing.expect(coverage.fully_covered);
}

test "invoke.buildInvocationReportFromInvocationSpecJson summarizes valid durable nonce flow" {
    const allocator = std.testing.allocator;

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 221, 222, 223, 224, 225, 226);
    defer allocator.free(spec_json);

    var report = try buildInvocationReportFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer report.deinit(allocator);

    try std.testing.expect(report.can_execute);
    try std.testing.expect(report.uses_durable_nonce);
    try std.testing.expect(!report.has_missing_required_signers);
    try std.testing.expect(!report.has_extra_signers);
    try std.testing.expect(!report.has_duplicate_signers);
    try std.testing.expect(!report.has_duplicate_lookup_tables);
    try std.testing.expect(!report.has_full_lookup_coverage);
    try std.testing.expectEqual(InvocationBlockhashMode.durable_nonce, report.preflight.blockhash_mode);
    try std.testing.expectEqual(@as(usize, 1), report.summary.instruction_count);
}

test "invoke.buildInvocationReportFromInvocationSpecJson summarizes invalid program flow" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(allocator, 231, 232, 233, 234, 235, 236);
    defer allocator.free(spec_json);

    var report = try buildInvocationReportFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.can_execute);
    try std.testing.expect(!report.uses_durable_nonce);
    try std.testing.expect(report.has_duplicate_signers);
    try std.testing.expect(report.has_duplicate_lookup_tables);
    try std.testing.expect(!report.has_missing_required_signers);
    try std.testing.expect(!report.has_extra_signers);
    try std.testing.expect(report.has_full_lookup_coverage);
    try std.testing.expectEqual(InvocationBlockhashMode.explicit_recent_blockhash, report.preflight.blockhash_mode);
}

test "invoke.buildInvocationModeReportFromInvocationSpecJson prefers legacy without lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 241, 242, 243);
    defer allocator.free(spec_json);

    const mode_report = try buildInvocationModeReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );

    try std.testing.expect(mode_report.legacy_buildable);
    try std.testing.expect(mode_report.versioned_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), mode_report.preferred_mode);
    try std.testing.expect(mode_report.validation_passed);
    try std.testing.expectEqual(@as(usize, 0), mode_report.address_lookup_table_count);
}

test "invoke.buildInvocationModeReportFromInvocationSpecJson prefers versioned with lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 251, 252, 253, 254, 255);
    defer allocator.free(spec_json);

    const mode_report = try buildInvocationModeReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );

    try std.testing.expect(mode_report.versioned_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), mode_report.preferred_mode);
    try std.testing.expect(mode_report.validation_passed);
    try std.testing.expectEqual(@as(usize, 1), mode_report.address_lookup_table_count);
}

test "invoke.buildInvocationModeReportFromInvocationSpecJson reports missing signer as not buildable" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(allocator, 261, 262, 263, 264, 265);
    defer allocator.free(spec_json);

    const mode_report = try buildInvocationModeReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );

    try std.testing.expect(!mode_report.legacy_buildable);
    try std.testing.expect(!mode_report.versioned_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, null), mode_report.preferred_mode);
    try std.testing.expect(!mode_report.validation_passed);
}

test "invoke.buildPreferredTransactionBase64FromInvocationSpecJson defaults to legacy mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 271, 272, 273);
    defer allocator.free(spec_json);

    const expected = try buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    const actual = try buildPreferredTransactionBase64FromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildPreferredTransactionBase64FromInvocationSpecJson prefers versioned mode with lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 281, 282, 283, 284, 285);
    defer allocator.free(spec_json);

    const expected = try buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    const actual = try buildPreferredTransactionBase64FromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildPreferredTransactionBase64FromInvocationSpecJson honors explicit preferred mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 291, 292, 293);
    defer allocator.free(spec_json);

    const expected = try buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    const actual = try buildPreferredTransactionBase64FromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .versioned,
                .allow_fallback = false,
            },
        },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildPreferredTransactionBase64FromInvocationSpecJson returns no buildable mode for invalid spec" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(allocator, 301, 302, 303, 304, 305);
    defer allocator.free(spec_json);

    try std.testing.expectError(
        error.NoBuildableInvocationMode,
        buildPreferredTransactionBase64FromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .instructions,
            spec_json,
            .{},
        ),
    );
}

test "invoke.buildLegacyMessageBytesFromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 11, 12, 13);
    defer allocator.free(spec_json);

    const expected = try buildMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{ .blockhash_commitment = .processed },
    );
    defer allocator.free(expected);

    const actual = try buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .processed },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 21, 22, 23);
    defer allocator.free(spec_json);

    const expected = try buildTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(expected);

    const actual = try buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildVersionedMessageBase64FromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 31, 32, 33);
    defer allocator.free(spec_json);

    const expected = try buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        true,
        spec_json,
        .{ .blockhash_commitment = .finalized },
    );
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .finalized },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.sendAndConfirmInvocationSpecJsonWithSpinner dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{96} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{97} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{98} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{99} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[7]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,
        captured_timeout_ms: u64 = 0,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_signer_count = signers_arg.len;
            self.captured_query = options_arg.?.blockhash_query.?;
            self.captured_nonce_authority = options_arg.?.nonce_authority.?;
            self.captured_commitment = options_arg.?.commitment.?;
            self.captured_timeout_ms = options_arg.?.timeout_ms;
            return try self.allocator.dupe(u8, "sig-spec-legacy-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmInvocationSpecJsonWithSpinner(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .confirmed,
        null,
        .finalized,
        false,
        777,
        10,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spec-legacy-spinner", signature);
    try std.testing.expectEqual(@as(usize, 2), rpc.captured_signer_count);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .confirmed } },
        rpc.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, rpc.captured_nonce_authority.?);
    try std.testing.expectEqual(.finalized, rpc.captured_commitment.?);
    try std.testing.expectEqual(@as(u64, 777), rpc.captured_timeout_ms);
}

test "invoke.getFeeForMessageFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn getFeeForLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            options: ?rpc_types.LegacyInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer;
            _ = instructions;
            self.captured_query = options.?.blockhash_query.?;
            self.captured_nonce_authority = options.?.nonce_authority.?;
            self.captured_commitment = commitment;
            return .{ .value = 2468 };
        }
    };

    var mock = MockLegacyInvocationFeeClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{161} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes(.{162} ** 32);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{163} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account = sdk.Pubkey.fromBytes(.{164} ** 32);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7],
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
        },
    );
    defer allocator.free(spec_json);

    const fee = try getFeeForMessageFromInvocationSpecJson(
        allocator,
        &mock,
        .program,
        false,
        spec_json,
        .finalized,
        .confirmed,
    );

    try std.testing.expectEqual(@as(?u64, 2468), fee.value);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .finalized } },
        mock.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, mock.captured_nonce_authority.?);
    try std.testing.expectEqual(.confirmed, mock.captured_commitment.?);
}

test "invoke.buildTransactionBase64FromInvocationSpecJson dispatches instructions versioned family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{171} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{172} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{173} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildTransactionBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        true,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildLegacyMessageBase64FromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{181} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{182} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{183} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildLegacyMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildVersionedMessageBytesFromInvocationSpecJson dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{184} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{185} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{186} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{187} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{188} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[4,5,6]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBytesFromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildVersionedMessageBase64FromInvocationSpecJson dispatches anchor family" {
    const allocator = std.testing.allocator;
    const idl_json =
        \\{
        \\  "address": "11111111111111111111111111111111",
        \\  "instructions": [
        \\    {
        \\      "name": "setValue",
        \\      "discriminator": [1, 2, 3, 4, 5, 6, 7, 8],
        \\      "accounts": [
        \\        { "name": "authority", "writable": true, "signer": true },
        \\        { "name": "target", "writable": true }
        \\      ],
        \\      "args": [
        \\        { "name": "value", "type": "u64" }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{189} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{190} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{191} ** 32);
    const recent_blockhash = [_]u8{0xD4} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const authority = try client.Keypair.fromSecretKeyBytes(authority_raw.secret_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const authority_secret_key_base58 = try client.encodeBase58(allocator, &authority.secret_key);
    defer allocator.free(authority_secret_key_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "default_signer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            authority_secret_key_base58,
            recent_blockhash_base58,
            idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var dummy = try client.RpcClient.newMock(allocator, &.{});
    defer dummy.deinit();
    const expected = try client.anchor_idl_invoke.buildVersionedMessageBase64FromInvocationSpecJson(
        &dummy,
        allocator,
        .{ .anchor_idl_invocation_spec_json = spec_json },
    );
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .anchor_idl,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildMessageBase64FromInvocationSpecJson dispatches program family generically" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{192} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{193} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{194} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildMessageBytesFromInvocationSpecJson dispatches instructions family generically" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{195} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{196} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{197} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{198} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{199} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[4,5,6]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBytesFromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        true,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildOwnedMessageFromInvocationSpecJson returns typed union" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{200} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{201} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{202} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    var owned = try buildOwnedMessageFromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );
    defer owned.deinit(allocator);

    switch (owned) {
        .legacy => {},
        .versioned => return error.UnexpectedResult,
    }
}

test "invoke.buildSignedTransactionFromInvocationSpecJson returns typed union" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{203} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{204} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{205} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const signed = try buildSignedTransactionFromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );

    switch (signed) {
        .legacy => {},
        .versioned => return error.UnexpectedResult,
    }
}

test "invoke.sendTransactionFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{206} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{207} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_program_id: ?sdk.Pubkey = null,
        captured_skip_preflight: bool = false,

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = signers;
            self.captured_program_id = instructions[0].program_id;
            self.captured_skip_preflight = options.?.send_transaction_options.?.skip_preflight;
            return "invoke-program-send";
        }
    };

    var rpc = MockRpc{};
    const signature = try sendTransactionFromInvocationSpecJson(
        allocator,
        &rpc,
        .program,
        false,
        spec_json,
        .{ .send_transaction_options = .{ .skip_preflight = true } },
    );

    try std.testing.expectEqualStrings("invoke-program-send", signature);
    try std.testing.expect(rpc.captured_program_id.?.eql(program_id));
    try std.testing.expect(rpc.captured_skip_preflight);
}

test "invoke.sendAndConfirmInvocationSpecJson dispatches anchor family" {
    const allocator = std.testing.allocator;
    const idl_json =
        \\{
        \\  "address": "11111111111111111111111111111111",
        \\  "instructions": [
        \\    {
        \\      "name": "setValue",
        \\      "discriminator": [1, 2, 3, 4, 5, 6, 7, 8],
        \\      "accounts": [
        \\        { "name": "authority", "writable": true, "signer": true },
        \\        { "name": "target", "writable": true }
        \\      ],
        \\      "args": [
        \\        { "name": "value", "type": "u64" }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{208} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{209} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{210} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const payer_keypair = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const authority = try client.Keypair.fromSecretKeyBytes(authority_raw.secret_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_keypair.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const authority_secret_key_base58 = try client.encodeBase58(allocator, &authority.secret_key);
    defer allocator.free(authority_secret_key_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "default_signer_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            authority_secret_key_base58,
            idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_program_id: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn sendAndConfirmLegacyInstructionsWithOptions(
            self: *@This(),
            payer_pubkey: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_pubkey;
            _ = signers;
            self.captured_program_id = instructions[0].program_id;
            self.captured_commitment = options.?.commitment.?;
            return "invoke-anchor-confirm";
        }
    };

    var rpc = MockRpc{};
    const signature = try sendAndConfirmInvocationSpecJson(
        allocator,
        &rpc,
        .anchor_idl,
        false,
        spec_json,
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqualStrings("invoke-anchor-confirm", signature);
    try std.testing.expect(rpc.captured_program_id != null);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, rpc.captured_commitment.?);
}

test "invoke.simulateTransactionFromInvocationSpecJson dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{211} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{212} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_sig_verify: bool = false,

        pub fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsSimulationOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = payer;
            _ = instructions;
            _ = signers;
            self.captured_sig_verify = options.?.simulate_transaction_options.?.sig_verify;
            return .{
                .context_slot = 1,
                .logs = null,
                .accounts = null,
                .units_consumed = null,
                .return_data = null,
                .inner_instructions = null,
                .replacement_blockhash = null,
                .err_json = null,
                .fee = null,
                .loaded_accounts_data_size = null,
            };
        }
    };

    var rpc = MockRpc{};
    _ = try simulateTransactionFromInvocationSpecJson(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .{ .simulate_options = .{ .sig_verify = true } },
    );

    try std.testing.expect(rpc.captured_sig_verify);
}

test "invoke.sendAndConfirmInvocationSpecJsonWithSpinnerOptions dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{213} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{214} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{215} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{216} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[7]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_timeout_ms: u64 = 0,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            _ = signers_arg;
            self.captured_timeout_ms = options_arg.?.timeout_ms;
            return try self.allocator.dupe(u8, "sig-spinner-options");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .{ .timeout_ms = 321 },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spinner-options", signature);
    try std.testing.expectEqual(@as(u64, 321), rpc.captured_timeout_ms);
}

test "invoke.getFeeForInvocationSpecJson dispatches options form" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn getFeeForLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            options: ?rpc_types.LegacyInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer;
            _ = instructions;
            _ = options;
            self.captured_commitment = commitment;
            return .{ .value = 1357 };
        }
    };

    var mock = MockLegacyInvocationFeeClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{217} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{218} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const fee = try getFeeForInvocationSpecJson(
        allocator,
        &mock,
        .program,
        false,
        spec_json,
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqual(@as(?u64, 1357), fee.value);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_commitment.?);
}

test "invoke.buildMessageBase64FromInvocationSpecJsonWithOptions dispatches options form" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{219} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{220} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{221} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        .{},
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
