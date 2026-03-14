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

    pub fn serialize(self: OwnedInvocationMessage, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |owned| try owned.serialize(allocator),
            .versioned => |owned| try owned.serialize(allocator),
        };
    }

    pub fn toBase64(self: OwnedInvocationMessage, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |owned| try owned.toBase64(allocator),
            .versioned => |owned| try owned.toBase64(allocator),
        };
    }
};

pub const SignedInvocationTransaction = union(enum) {
    legacy: sdk.SignedLegacyTransaction,
    versioned: sdk.SignedVersionedTransaction,

    pub fn deinit(self: *SignedInvocationTransaction, allocator: Allocator) void {
        switch (self.*) {
            .legacy => |*signed| signed.deinit(allocator),
            .versioned => |*signed| signed.deinit(allocator),
        }
        self.* = undefined;
    }

    pub fn serialize(self: SignedInvocationTransaction, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |signed| try signed.serialize(allocator),
            .versioned => |signed| try signed.serialize(allocator),
        };
    }

    pub fn toBase64(self: SignedInvocationTransaction, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |signed| try signed.toBase64(allocator),
            .versioned => |signed| try signed.toBase64(allocator),
        };
    }

    pub fn serializeMessage(self: SignedInvocationTransaction, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |signed| try allocator.dupe(u8, signed.message_bytes),
            .versioned => |signed| try allocator.dupe(u8, signed.message_bytes),
        };
    }

    pub fn messageToBase64(self: SignedInvocationTransaction, allocator: Allocator) ![]u8 {
        return switch (self) {
            .legacy => |signed| try sdk.encodeBase64(allocator, signed.message_bytes),
            .versioned => |signed| try sdk.encodeBase64(allocator, signed.message_bytes),
        };
    }

    pub fn firstSignature(self: SignedInvocationTransaction) ?sdk.Signature {
        return switch (self) {
            .legacy => |signed| signed.firstSignature(),
            .versioned => |signed| signed.firstSignature(),
        };
    }
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

pub const OwnedResolvedInvocationParts = struct {
    payer: sdk.Pubkey,
    signer_pubkeys: []sdk.Pubkey,
    owned_instructions: sdk.OwnedInstructions,
    address_lookup_tables: []sdk.AddressLookupTableAccount = &.{},
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BorrowedResolvedInvocationParts = struct {
    payer: sdk.Pubkey,
    signer_pubkeys: []const sdk.Pubkey,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,
};

pub fn buildOwnedResolvedInvocationFromOwnedParts(
    parts: OwnedResolvedInvocationParts,
) !OwnedResolvedInvocation {
    if (parts.recent_blockhash != null and parts.nonce_account != null) {
        return error.ConflictingRecentBlockhashAndNonce;
    }

    return .{
        .payer = parts.payer,
        .signer_pubkeys = parts.signer_pubkeys,
        .owned_instructions = parts.owned_instructions,
        .address_lookup_tables = parts.address_lookup_tables,
        .recent_blockhash = parts.recent_blockhash,
        .nonce_account = parts.nonce_account,
        .nonce_authority = parts.nonce_authority,
    };
}

pub fn buildOwnedResolvedInvocationFromBorrowedParts(
    allocator: Allocator,
    parts: BorrowedResolvedInvocationParts,
) !OwnedResolvedInvocation {
    const signer_pubkeys = try allocator.dupe(sdk.Pubkey, parts.signer_pubkeys);
    errdefer allocator.free(signer_pubkeys);

    var owned_instructions = try sdk.cloneInstructions(
        allocator,
        parts.instructions,
    );
    errdefer owned_instructions.deinit(allocator);

    const address_lookup_tables = try allocator.alloc(
        sdk.AddressLookupTableAccount,
        parts.address_lookup_tables.len,
    );
    errdefer allocator.free(address_lookup_tables);
    var initialized_tables_len: usize = 0;
    errdefer {
        for (address_lookup_tables[0..initialized_tables_len]) |table| {
            allocator.free(table.addresses);
        }
        allocator.free(address_lookup_tables);
    }
    for (parts.address_lookup_tables, 0..) |table, index| {
        address_lookup_tables[index] = .{
            .account_key = table.account_key,
            .addresses = try allocator.dupe(sdk.Pubkey, table.addresses),
        };
        initialized_tables_len += 1;
    }

    return buildOwnedResolvedInvocationFromOwnedParts(.{
        .payer = parts.payer,
        .signer_pubkeys = signer_pubkeys,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = address_lookup_tables,
        .recent_blockhash = parts.recent_blockhash,
        .nonce_account = parts.nonce_account,
        .nonce_authority = parts.nonce_authority,
    });
}

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

    pub fn find(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) ?InvocationAccountInfo {
        for (self.accounts) |info| {
            if (std.meta.eql(info.pubkey, pubkey)) return info;
        }
        return null;
    }

    pub fn contains(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return self.find(pubkey) != null;
    }

    pub fn isSigner(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return if (self.find(pubkey)) |info| info.is_signer else false;
    }

    pub fn isWritable(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return if (self.find(pubkey)) |info| info.is_writable else false;
    }

    pub fn isPayer(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return if (self.find(pubkey)) |info| info.is_payer else false;
    }

    pub fn isProgram(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return if (self.find(pubkey)) |info| info.is_program else false;
    }

    pub fn isNonceAccount(self: OwnedInvocationAccounts, pubkey: sdk.Pubkey) bool {
        return if (self.find(pubkey)) |info| info.is_nonce_account else false;
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

    pub fn providesSigner(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.provided_signer_pubkeys, pubkey);
    }

    pub fn requiresSigner(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.required_signer_pubkeys, pubkey);
    }

    pub fn hasExtraSigner(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.extra_signer_pubkeys, pubkey);
    }

    pub fn isWritable(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.writable_pubkeys, pubkey);
    }

    pub fn isReadonly(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.readonly_pubkeys, pubkey);
    }

    pub fn containsLookupTable(self: OwnedInvocationPreflight, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.lookup_table_pubkeys, pubkey);
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

    pub fn providesSigner(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.provided_signer_pubkeys, pubkey);
    }

    pub fn requiresSigner(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.required_signer_pubkeys, pubkey);
    }

    pub fn isMissingRequiredSigner(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.missing_required_signer_pubkeys, pubkey);
    }

    pub fn isExtraSigner(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.extra_signer_pubkeys, pubkey);
    }

    pub fn hasDuplicateProvidedSigner(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.duplicate_provided_signer_pubkeys, pubkey);
    }

    pub fn containsLookupTable(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.lookup_table_pubkeys, pubkey);
    }

    pub fn hasDuplicateLookupTable(self: OwnedInvocationValidation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.duplicate_lookup_table_pubkeys, pubkey);
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

    pub fn containsLookupTable(self: OwnedInvocationLookupCoverage, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.lookup_table_pubkeys, pubkey);
    }

    pub fn isCandidate(self: OwnedInvocationLookupCoverage, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.candidate_pubkeys, pubkey);
    }

    pub fn coversPubkey(self: OwnedInvocationLookupCoverage, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.covered_pubkeys, pubkey);
    }

    pub fn isUncoveredPubkey(self: OwnedInvocationLookupCoverage, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.uncovered_pubkeys, pubkey);
    }
};

pub const OwnedInvocationReport = struct {
    summary: OwnedInvocationSummary,
    plan: OwnedInvocationPlan,
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
        self.plan.deinit(allocator);
        self.preflight.deinit(allocator);
        self.validation.deinit(allocator);
        self.lookup_coverage.deinit(allocator);
        self.* = undefined;
    }

    pub fn usesLookupTables(self: OwnedInvocationReport) bool {
        return self.plan.address_lookup_table_count != 0;
    }

    pub fn hasMissingRequiredSigner(self: OwnedInvocationReport, pubkey: sdk.Pubkey) bool {
        return self.validation.isMissingRequiredSigner(pubkey);
    }

    pub fn hasExtraSigner(self: OwnedInvocationReport, pubkey: sdk.Pubkey) bool {
        return self.validation.isExtraSigner(pubkey);
    }

    pub fn hasDuplicateSigner(self: OwnedInvocationReport, pubkey: sdk.Pubkey) bool {
        return self.validation.hasDuplicateProvidedSigner(pubkey);
    }

    pub fn hasDuplicateLookupTable(self: OwnedInvocationReport, pubkey: sdk.Pubkey) bool {
        return self.validation.hasDuplicateLookupTable(pubkey);
    }

    pub fn lookupCoverageIncludes(self: OwnedInvocationReport, pubkey: sdk.Pubkey) bool {
        return self.lookup_coverage.coversPubkey(pubkey);
    }
};

pub const InvocationDiagnosticSeverity = enum {
    info,
    warning,
    err,
};

pub const InvocationDiagnosticCode = enum {
    no_buildable_mode,
    mode_fallback,
    missing_required_signers,
    extra_signers,
    duplicate_signers,
    duplicate_lookup_tables,
    incomplete_lookup_coverage,
    durable_nonce,
};

pub const InvocationDiagnostic = struct {
    severity: InvocationDiagnosticSeverity,
    code: InvocationDiagnosticCode,
};

pub const OwnedInvocationDiagnostics = struct {
    items: []InvocationDiagnostic,

    pub fn deinit(self: *OwnedInvocationDiagnostics, allocator: Allocator) void {
        allocator.free(self.items);
        self.* = undefined;
    }

    pub fn errorCount(self: OwnedInvocationDiagnostics) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.severity == .err) count += 1;
        }
        return count;
    }

    pub fn warningCount(self: OwnedInvocationDiagnostics) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.severity == .warning) count += 1;
        }
        return count;
    }

    pub fn infoCount(self: OwnedInvocationDiagnostics) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.severity == .info) count += 1;
        }
        return count;
    }

    pub fn hasCode(self: OwnedInvocationDiagnostics, code: InvocationDiagnosticCode) bool {
        for (self.items) |item| {
            if (item.code == code) return true;
        }
        return false;
    }
};

pub fn invocationDiagnosticSeverityLabel(severity: InvocationDiagnosticSeverity) []const u8 {
    return switch (severity) {
        .info => "info",
        .warning => "warning",
        .err => "error",
    };
}

pub fn invocationDiagnosticCodeLabel(code: InvocationDiagnosticCode) []const u8 {
    return @tagName(code);
}

pub fn invocationDiagnosticMessage(code: InvocationDiagnosticCode) []const u8 {
    return switch (code) {
        .no_buildable_mode => "No invocation mode can be built with the current inputs.",
        .mode_fallback => "Requested invocation mode was not used and the runtime fell back to another mode.",
        .missing_required_signers => "Required signer pubkeys are missing from the provided signer set.",
        .extra_signers => "Extra signer pubkeys were provided but are not required by the invocation.",
        .duplicate_signers => "Duplicate signer pubkeys were provided.",
        .duplicate_lookup_tables => "Duplicate address lookup tables were provided.",
        .incomplete_lookup_coverage => "Not all lookup candidate pubkeys are covered by the provided address lookup tables.",
        .durable_nonce => "Invocation uses a durable nonce account instead of a recent blockhash.",
    };
}

pub fn invocationDiagnosticSuggestion(code: InvocationDiagnosticCode) ?[]const u8 {
    return switch (code) {
        .no_buildable_mode => "Add the missing signers or switch invocation mode inputs so at least one mode becomes buildable.",
        .mode_fallback => "If the fallback is undesirable, rerun with --no-mode-fallback or change --invoke-mode.",
        .missing_required_signers => "Add the missing signer keypairs or remove signer requirements from the invocation inputs.",
        .extra_signers => "Remove the unnecessary signer keypairs to keep the signer set minimal.",
        .duplicate_signers => "Deduplicate signer inputs before sending the invocation.",
        .duplicate_lookup_tables => "Deduplicate address lookup table inputs before building the transaction.",
        .incomplete_lookup_coverage => "Provide additional address lookup tables or drop unnecessary lookup-table-only accounts.",
        .durable_nonce => "Ensure the nonce account and nonce authority are valid for the target cluster before sending.",
    };
}

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

pub const GetFeeForPreferredInvocationSpecOptions = struct {
    mode: PreferredInvocationModeOptions = .{},
    fee: GetFeeForInvocationSpecOptions = .{},
};

pub const PreferredOwnedMessageResult = struct {
    mode: InvocationMode,
    message: OwnedInvocationMessage,

    pub fn deinit(self: *PreferredOwnedMessageResult, allocator: Allocator) void {
        self.message.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredSignedTransactionResult = struct {
    mode: InvocationMode,
    transaction: SignedInvocationTransaction,

    pub fn deinit(self: *PreferredSignedTransactionResult, allocator: Allocator) void {
        self.transaction.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredBytesResult = struct {
    mode: InvocationMode,
    bytes: []u8,

    pub fn deinit(self: *PreferredBytesResult, allocator: Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const PreferredSignatureResult = struct {
    mode: InvocationMode,
    signature: []const u8,

    pub fn deinit(self: *PreferredSignatureResult, allocator: Allocator) void {
        allocator.free(self.signature);
        self.* = undefined;
    }
};

pub const PreferredSimulationResult = struct {
    mode: InvocationMode,
    simulation: client.SimulatedTransaction,
};

pub const PreferredFeeResult = struct {
    mode: InvocationMode,
    fee: client.FeeForMessage,
};

pub const OwnedPreferredInvocationReport = struct {
    mode_report: InvocationModeReport,
    report: OwnedInvocationReport,

    pub fn deinit(self: *OwnedPreferredInvocationReport, allocator: Allocator) void {
        self.report.deinit(allocator);
        self.* = undefined;
    }

    pub fn preferredMode(self: OwnedPreferredInvocationReport) ?InvocationMode {
        return self.mode_report.preferred_mode;
    }

    pub fn prefersVersioned(self: OwnedPreferredInvocationReport) bool {
        return self.mode_report.preferred_mode == .versioned;
    }
};

pub const PreferredInvocationExecutionReport = struct {
    mode_report: InvocationModeReport,
    report: OwnedInvocationReport,
    requested_mode: ?InvocationMode,
    selected_mode: ?InvocationMode,
    requested_mode_buildable: bool,
    used_fallback: bool,
    can_execute_selected_mode: bool,

    pub fn deinit(self: *PreferredInvocationExecutionReport, allocator: Allocator) void {
        self.report.deinit(allocator);
        self.* = undefined;
    }

    pub fn usedRequestedMode(self: PreferredInvocationExecutionReport) bool {
        return self.requested_mode != null and self.requested_mode == self.selected_mode;
    }

    pub fn selectedUsesVersioned(self: PreferredInvocationExecutionReport) bool {
        return self.selected_mode == .versioned;
    }
};

pub const PreferredOwnedMessageExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    message: OwnedInvocationMessage,

    pub fn deinit(self: *PreferredOwnedMessageExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.message.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredBytesExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    bytes: []u8,

    pub fn deinit(self: *PreferredBytesExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const PreferredSignedTransactionExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    transaction: SignedInvocationTransaction,

    pub fn deinit(self: *PreferredSignedTransactionExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.transaction.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredResolvedInvocationExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    resolved_invocation: OwnedResolvedInvocation,

    pub fn deinit(self: *PreferredResolvedInvocationExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.resolved_invocation.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredInvocationAnalysis = struct {
    execution_report: PreferredInvocationExecutionReport,
    resolved_invocation: OwnedResolvedInvocation,
    accounts: OwnedInvocationAccounts,

    pub fn deinit(self: *PreferredInvocationAnalysis, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.resolved_invocation.deinit(allocator);
        self.accounts.deinit(allocator);
        self.* = undefined;
    }
};

fn invocationModeJsonLabel(mode: ?InvocationMode) []const u8 {
    return if (mode) |value| switch (value) {
        .legacy => "legacy",
        .versioned => "versioned",
    } else "none";
}

fn invocationBlockhashModeJsonLabel(mode: InvocationBlockhashMode) []const u8 {
    return switch (mode) {
        .latest_blockhash => "latest-blockhash",
        .explicit_recent_blockhash => "explicit-recent-blockhash",
        .durable_nonce => "durable-nonce",
    };
}

fn writeJsonStringField(writer: *std.Io.Writer, first: *bool, name: []const u8, value: ?[]const u8) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":");
    try std.json.Stringify.value(value, .{}, writer);
}

fn writeJsonBoolField(writer: *std.Io.Writer, first: *bool, name: []const u8, value: bool) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":");
    try std.json.Stringify.value(value, .{}, writer);
}

fn writeJsonUsizeField(writer: *std.Io.Writer, first: *bool, name: []const u8, value: usize) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":");
    try std.json.Stringify.value(value, .{}, writer);
}

fn writeJsonU64Field(writer: *std.Io.Writer, first: *bool, name: []const u8, value: u64) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":");
    try std.json.Stringify.value(value, .{}, writer);
}

fn writeJsonOptionalU64Field(writer: *std.Io.Writer, first: *bool, name: []const u8, value: ?u64) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":");
    try std.json.Stringify.value(value, .{}, writer);
}

fn writeJsonPubkeyArrayField(writer: *std.Io.Writer, first: *bool, name: []const u8, allocator: Allocator, pubkeys: anytype) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value(name, .{}, writer);
    try writer.writeAll(":[");
    for (pubkeys, 0..) |pubkey, index| {
        if (index != 0) try writer.writeAll(",");
        const base58 = try pubkey.toBase58(allocator);
        defer allocator.free(base58);
        try std.json.Stringify.value(base58, .{}, writer);
    }
    try writer.writeAll("]");
}

fn writeJsonAccountsField(writer: *std.Io.Writer, first: *bool, allocator: Allocator, accounts: OwnedInvocationAccounts) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value("accounts", .{}, writer);
    try writer.writeAll(":[");
    for (accounts.accounts, 0..) |account, index| {
        if (index != 0) try writer.writeAll(",");
        const base58 = try account.pubkey.toBase58(allocator);
        defer allocator.free(base58);
        try writer.writeAll("{");
        var account_first = true;
        try writeJsonStringField(writer, &account_first, "pubkey", base58);
        try writeJsonBoolField(writer, &account_first, "is_payer", account.is_payer);
        try writeJsonBoolField(writer, &account_first, "is_program", account.is_program);
        try writeJsonBoolField(writer, &account_first, "is_nonce_account", account.is_nonce_account);
        try writeJsonBoolField(writer, &account_first, "is_signer", account.is_signer);
        try writeJsonBoolField(writer, &account_first, "is_writable", account.is_writable);
        try writer.writeAll("}");
    }
    try writer.writeAll("]");
}

fn writeJsonDiagnosticsField(
    writer: *std.Io.Writer,
    first: *bool,
    diagnostics: OwnedInvocationDiagnostics,
) !void {
    if (!first.*) try writer.writeAll(",");
    first.* = false;
    try std.json.Stringify.value("diagnostics", .{}, writer);
    try writer.writeAll(":[");
    for (diagnostics.items, 0..) |item, index| {
        if (index != 0) try writer.writeAll(",");
        try writer.writeAll("{");
        var item_first = true;
        try writeJsonStringField(writer, &item_first, "severity", invocationDiagnosticSeverityLabel(item.severity));
        try writeJsonStringField(writer, &item_first, "code", invocationDiagnosticCodeLabel(item.code));
        try writeJsonStringField(writer, &item_first, "message", invocationDiagnosticMessage(item.code));
        try writeJsonStringField(writer, &item_first, "suggestion", invocationDiagnosticSuggestion(item.code));
        try writer.writeAll("}");
    }
    try writer.writeAll("]");
}

pub fn writePreferredInvocationAnalysisJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    analysis: *const PreferredInvocationAnalysis,
) !void {
    var first = true;
    var diagnostics = try buildInvocationDiagnosticsFromPreferredExecutionReport(
        allocator,
        &analysis.execution_report,
    );
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "preferred_mode", invocationModeJsonLabel(analysis.execution_report.mode_report.preferred_mode));
    try writeJsonStringField(writer, &first, "requested_mode", invocationModeJsonLabel(analysis.execution_report.requested_mode));
    try writeJsonStringField(writer, &first, "selected_mode", invocationModeJsonLabel(analysis.execution_report.selected_mode));
    try writeJsonBoolField(writer, &first, "used_fallback", analysis.execution_report.used_fallback);
    try writeJsonBoolField(writer, &first, "legacy_buildable", analysis.execution_report.mode_report.legacy_buildable);
    try writeJsonBoolField(writer, &first, "versioned_buildable", analysis.execution_report.mode_report.versioned_buildable);
    try writeJsonBoolField(writer, &first, "validation_passed", analysis.execution_report.mode_report.validation_passed);
    try writeJsonBoolField(writer, &first, "can_execute_selected_mode", analysis.execution_report.can_execute_selected_mode);
    try writeJsonBoolField(writer, &first, "can_execute", analysis.execution_report.report.can_execute);
    try writeJsonBoolField(writer, &first, "uses_durable_nonce", analysis.execution_report.report.uses_durable_nonce);
    try writeJsonBoolField(writer, &first, "full_lookup_coverage", analysis.execution_report.report.has_full_lookup_coverage);

    const payer_base58 = try analysis.execution_report.report.summary.payer.toBase58(allocator);
    defer allocator.free(payer_base58);
    try writeJsonStringField(writer, &first, "payer", payer_base58);
    try writeJsonStringField(writer, &first, "blockhash_mode", invocationBlockhashModeJsonLabel(analysis.execution_report.report.plan.blockhash_mode));

    try writeJsonUsizeField(writer, &first, "instruction_count", analysis.execution_report.report.summary.instruction_count);
    try writeJsonUsizeField(writer, &first, "account_count", analysis.execution_report.report.summary.account_count);
    try writeJsonUsizeField(writer, &first, "signer_count", analysis.execution_report.report.summary.signer_count);
    try writeJsonUsizeField(writer, &first, "writable_account_count", analysis.execution_report.report.summary.writable_account_count);
    try writeJsonUsizeField(writer, &first, "readonly_account_count", analysis.execution_report.report.summary.readonly_account_count);
    try writeJsonUsizeField(writer, &first, "lookup_table_count", analysis.execution_report.report.summary.address_lookup_table_count);
    try writeJsonUsizeField(writer, &first, "missing_required_signer_count", analysis.execution_report.report.validation.missing_required_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "extra_signer_count", analysis.execution_report.report.validation.extra_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_signer_count", analysis.execution_report.report.validation.duplicate_provided_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_lookup_table_count", analysis.execution_report.report.validation.duplicate_lookup_table_pubkeys.len);

    try writeJsonPubkeyArrayField(writer, &first, "program_ids", allocator, analysis.execution_report.report.summary.program_ids);
    try writeJsonPubkeyArrayField(writer, &first, "provided_signer_pubkeys", allocator, analysis.execution_report.report.preflight.provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "required_signer_pubkeys", allocator, analysis.execution_report.report.preflight.required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "writable_pubkeys", allocator, analysis.execution_report.report.preflight.writable_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "readonly_pubkeys", allocator, analysis.execution_report.report.preflight.readonly_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_table_pubkeys", allocator, analysis.execution_report.report.plan.lookup_table_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_covered_pubkeys", allocator, analysis.execution_report.report.lookup_coverage.covered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_uncovered_pubkeys", allocator, analysis.execution_report.report.lookup_coverage.uncovered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "missing_required_signer_pubkeys", allocator, analysis.execution_report.report.validation.missing_required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "extra_signer_pubkeys", allocator, analysis.execution_report.report.validation.extra_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_signer_pubkeys", allocator, analysis.execution_report.report.validation.duplicate_provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_lookup_table_pubkeys", allocator, analysis.execution_report.report.validation.duplicate_lookup_table_pubkeys);
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writeJsonAccountsField(writer, &first, allocator, analysis.accounts);
    try writer.writeAll("}");
}

pub fn allocPreferredInvocationAnalysisJson(
    allocator: Allocator,
    analysis: *const PreferredInvocationAnalysis,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreferredInvocationAnalysisJson(&aw.writer, allocator, analysis);
    return try aw.toOwnedSlice();
}

pub fn writePreferredSignatureExecutionResultJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    result: *const PreferredSignatureExecutionResult,
) !void {
    var first = true;
    var diagnostics = try buildInvocationDiagnosticsFromPreferredExecutionReport(
        allocator,
        &result.execution_report,
    );
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "requested_mode", invocationModeJsonLabel(result.execution_report.requested_mode));
    try writeJsonStringField(writer, &first, "selected_mode", invocationModeJsonLabel(result.execution_report.selected_mode));
    try writeJsonBoolField(writer, &first, "requested_mode_buildable", result.execution_report.requested_mode_buildable);
    try writeJsonBoolField(writer, &first, "used_fallback", result.execution_report.used_fallback);
    try writeJsonBoolField(writer, &first, "can_execute_selected_mode", result.execution_report.can_execute_selected_mode);
    try writeJsonStringField(writer, &first, "signature", result.signature);
    try writeJsonUsizeField(writer, &first, "diagnostic_error_count", diagnostics.errorCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_warning_count", diagnostics.warningCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_info_count", diagnostics.infoCount());
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writer.writeAll("}");
}

pub fn allocPreferredSignatureExecutionResultJson(
    allocator: Allocator,
    result: *const PreferredSignatureExecutionResult,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreferredSignatureExecutionResultJson(&aw.writer, allocator, result);
    return try aw.toOwnedSlice();
}

pub fn writePreferredSimulationExecutionResultJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    result: *const PreferredSimulationExecutionResult,
) !void {
    var first = true;
    var diagnostics = try buildInvocationDiagnosticsFromPreferredExecutionReport(
        allocator,
        &result.execution_report,
    );
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "requested_mode", invocationModeJsonLabel(result.execution_report.requested_mode));
    try writeJsonStringField(writer, &first, "selected_mode", invocationModeJsonLabel(result.execution_report.selected_mode));
    try writeJsonBoolField(writer, &first, "requested_mode_buildable", result.execution_report.requested_mode_buildable);
    try writeJsonBoolField(writer, &first, "used_fallback", result.execution_report.used_fallback);
    try writeJsonBoolField(writer, &first, "can_execute_selected_mode", result.execution_report.can_execute_selected_mode);
    try writeJsonU64Field(writer, &first, "context_slot", result.simulation.context_slot);
    try writeJsonOptionalU64Field(writer, &first, "fee", result.simulation.fee);
    try writeJsonOptionalU64Field(writer, &first, "units_consumed", result.simulation.units_consumed);
    try writeJsonOptionalU64Field(
        writer,
        &first,
        "loaded_accounts_data_size",
        if (result.simulation.loaded_accounts_data_size) |value| @as(u64, value) else null,
    );
    try writeJsonBoolField(writer, &first, "has_logs", result.simulation.logs != null);
    try writeJsonUsizeField(writer, &first, "logs_count", if (result.simulation.logs) |logs| logs.len else @as(usize, 0));
    try writeJsonUsizeField(writer, &first, "accounts_count", if (result.simulation.accounts) |accounts| accounts.len else @as(usize, 0));
    try writeJsonUsizeField(writer, &first, "diagnostic_error_count", diagnostics.errorCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_warning_count", diagnostics.warningCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_info_count", diagnostics.infoCount());
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writer.writeAll("}");
}

pub fn allocPreferredSimulationExecutionResultJson(
    allocator: Allocator,
    result: *const PreferredSimulationExecutionResult,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreferredSimulationExecutionResultJson(&aw.writer, allocator, result);
    return try aw.toOwnedSlice();
}

pub fn writePreferredFeeExecutionResultJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    result: *const PreferredFeeExecutionResult,
) !void {
    var first = true;
    var diagnostics = try buildInvocationDiagnosticsFromPreferredExecutionReport(
        allocator,
        &result.execution_report,
    );
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "requested_mode", invocationModeJsonLabel(result.execution_report.requested_mode));
    try writeJsonStringField(writer, &first, "selected_mode", invocationModeJsonLabel(result.execution_report.selected_mode));
    try writeJsonBoolField(writer, &first, "requested_mode_buildable", result.execution_report.requested_mode_buildable);
    try writeJsonBoolField(writer, &first, "used_fallback", result.execution_report.used_fallback);
    try writeJsonBoolField(writer, &first, "can_execute_selected_mode", result.execution_report.can_execute_selected_mode);
    try writeJsonOptionalU64Field(writer, &first, "fee", result.fee.value);
    try writeJsonUsizeField(writer, &first, "diagnostic_error_count", diagnostics.errorCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_warning_count", diagnostics.warningCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_info_count", diagnostics.infoCount());
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writer.writeAll("}");
}

pub fn allocPreferredFeeExecutionResultJson(
    allocator: Allocator,
    result: *const PreferredFeeExecutionResult,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreferredFeeExecutionResultJson(&aw.writer, allocator, result);
    return try aw.toOwnedSlice();
}

fn requestedModeText(mode: ?InvocationMode) []const u8 {
    return if (mode) |value| @tagName(value) else "auto";
}

fn selectedModeText(mode: ?InvocationMode) []const u8 {
    return if (mode) |value| @tagName(value) else "none";
}

pub fn writeInvocationDiagnosticsText(
    writer: *std.Io.Writer,
    diagnostics: OwnedInvocationDiagnostics,
) !void {
    try writer.print(
        "diagnostics: {d} error(s), {d} warning(s), {d} info item(s)\n",
        .{ diagnostics.errorCount(), diagnostics.warningCount(), diagnostics.infoCount() },
    );
    for (diagnostics.items) |item| {
        try writer.print(
            "  [{s}] {s}: {s}\n",
            .{
                invocationDiagnosticSeverityLabel(item.severity),
                invocationDiagnosticCodeLabel(item.code),
                invocationDiagnosticMessage(item.code),
            },
        );
        if (invocationDiagnosticSuggestion(item.code)) |suggestion| {
            try writer.print("    suggestion: {s}\n", .{suggestion});
        }
    }
}

pub fn writePreferredSignatureExecutionResultText(
    writer: *std.Io.Writer,
    result: *const PreferredSignatureExecutionResult,
    confirmed: bool,
) !void {
    try writer.print("requested mode: {s}\n", .{requestedModeText(result.execution_report.requested_mode)});
    try writer.print("selected mode: {s}\n", .{selectedModeText(result.execution_report.selected_mode)});
    try writer.print("used fallback: {}\n", .{result.execution_report.used_fallback});
    try writer.print("{s}: {s}\n", .{ if (confirmed) "confirmed signature" else "signature", result.signature });
}

pub fn writePreferredSimulationExecutionSummaryText(
    writer: *std.Io.Writer,
    result: *const PreferredSimulationExecutionResult,
) !void {
    try writer.print("requested mode: {s}\n", .{requestedModeText(result.execution_report.requested_mode)});
    try writer.print("selected mode: {s}\n", .{selectedModeText(result.execution_report.selected_mode)});
    try writer.print("used fallback: {}\n", .{result.execution_report.used_fallback});
}

pub fn writePreferredFeeExecutionResultText(
    writer: *std.Io.Writer,
    result: *const PreferredFeeExecutionResult,
) !void {
    try writer.print("requested mode: {s}\n", .{requestedModeText(result.execution_report.requested_mode)});
    try writer.print("selected mode: {s}\n", .{selectedModeText(result.execution_report.selected_mode)});
    try writer.print("used fallback: {}\n", .{result.execution_report.used_fallback});
    if (result.fee.value) |value| {
        try writer.print("fee: {}\n", .{value});
    } else {
        try writer.writeAll("fee: unavailable\n");
    }
}

pub fn writeInvocationPubkeysText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    label: []const u8,
    pubkeys: anytype,
) !void {
    try writer.print("{s} ({d}):\n", .{ label, pubkeys.len });
    for (pubkeys) |pubkey| {
        const base58 = try pubkey.toBase58(allocator);
        defer allocator.free(base58);
        try writer.print("  {s}\n", .{base58});
    }
}

pub fn writeInvocationAccountsText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    accounts: OwnedInvocationAccounts,
) !void {
    if (accounts.accounts.len == 0) return;

    try writer.print("accounts ({d}):\n", .{accounts.accounts.len});
    for (accounts.accounts) |account| {
        const base58 = try account.pubkey.toBase58(allocator);
        defer allocator.free(base58);

        try writer.print(
            "  {s} [{s}{s}{s}{s}{s}, {s}]\n",
            .{
                base58,
                if (account.is_payer) "payer " else "",
                if (account.is_program) "program " else "",
                if (account.is_nonce_account) "nonce " else "",
                if (account.is_signer) "signer " else "",
                if (!account.is_payer and !account.is_program and !account.is_nonce_account and !account.is_signer) "account" else "",
                if (account.is_writable) "writable" else "readonly",
            },
        );
    }
}

pub fn writePreferredInvocationExecutionReportText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    report: *const PreferredInvocationExecutionReport,
) !void {
    const payer_base58 = try report.report.summary.payer.toBase58(allocator);
    defer allocator.free(payer_base58);

    try writer.print("preferred mode: {s}\n", .{selectedModeText(report.mode_report.preferred_mode)});
    try writer.print("requested mode: {s}\n", .{requestedModeText(report.requested_mode)});
    try writer.print("selected mode: {s}\n", .{selectedModeText(report.selected_mode)});
    try writer.print("used fallback: {}\n", .{report.used_fallback});
    try writer.print("legacy buildable: {}\n", .{report.mode_report.legacy_buildable});
    try writer.print("versioned buildable: {}\n", .{report.mode_report.versioned_buildable});
    try writer.print("validation passed: {}\n", .{report.mode_report.validation_passed});
    try writer.print("can execute selected mode: {}\n", .{report.can_execute_selected_mode});
    try writer.print("payer: {s}\n", .{payer_base58});
    try writer.print("blockhash mode: {s}\n", .{invocationBlockhashModeJsonLabel(report.report.plan.blockhash_mode)});
    try writer.print("instruction count: {d}\n", .{report.report.summary.instruction_count});
    try writer.print("account count: {d}\n", .{report.report.summary.account_count});
    try writer.print("signer count: {d}\n", .{report.report.summary.signer_count});
    try writer.print("writable accounts: {d}\n", .{report.report.summary.writable_account_count});
    try writer.print("readonly accounts: {d}\n", .{report.report.summary.readonly_account_count});
    try writer.print("lookup tables: {d}\n", .{report.report.summary.address_lookup_table_count});
    try writer.print("full lookup coverage: {}\n", .{report.report.has_full_lookup_coverage});
    try writer.print("missing required signers: {d}\n", .{report.report.validation.missing_required_signer_pubkeys.len});
    try writer.print("extra signers: {d}\n", .{report.report.validation.extra_signer_pubkeys.len});
    try writer.print("duplicate signers: {d}\n", .{report.report.validation.duplicate_provided_signer_pubkeys.len});
    try writer.print("duplicate lookup tables: {d}\n", .{report.report.validation.duplicate_lookup_table_pubkeys.len});

    try writeInvocationPubkeysText(writer, allocator, "program ids", report.report.summary.program_ids);
    if (report.report.preflight.provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "provided signer pubkeys", report.report.preflight.provided_signer_pubkeys);
    }
    if (report.report.preflight.required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "required signer pubkeys", report.report.preflight.required_signer_pubkeys);
    }
    if (report.report.preflight.writable_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "writable pubkeys", report.report.preflight.writable_pubkeys);
    }
    if (report.report.preflight.readonly_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "readonly pubkeys", report.report.preflight.readonly_pubkeys);
    }
    if (report.report.plan.lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup table pubkeys", report.report.plan.lookup_table_pubkeys);
    }
    if (report.report.lookup_coverage.covered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup covered pubkeys", report.report.lookup_coverage.covered_pubkeys);
    }
    if (report.report.lookup_coverage.uncovered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup uncovered pubkeys", report.report.lookup_coverage.uncovered_pubkeys);
    }
    if (report.report.validation.missing_required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "missing required signer pubkeys", report.report.validation.missing_required_signer_pubkeys);
    }
    if (report.report.validation.extra_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "extra signer pubkeys", report.report.validation.extra_signer_pubkeys);
    }
    if (report.report.validation.duplicate_provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate signer pubkeys", report.report.validation.duplicate_provided_signer_pubkeys);
    }
    if (report.report.validation.duplicate_lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate lookup table pubkeys", report.report.validation.duplicate_lookup_table_pubkeys);
    }
}

pub fn writePreferredInvocationAnalysisText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    analysis: *const PreferredInvocationAnalysis,
) !void {
    try writePreferredInvocationExecutionReportText(writer, allocator, &analysis.execution_report);
    try writeInvocationAccountsText(writer, allocator, analysis.accounts);
}

pub fn writePreferredPreparedInvocationText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    prepared: *const PreferredPreparedInvocation,
) !void {
    const payer_base58 = try prepared.payer().toBase58(allocator);
    defer allocator.free(payer_base58);

    const transaction_base64 = try prepared.toBase64(allocator);
    defer allocator.free(transaction_base64);

    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);

    const first_signature_base58 = if (prepared.firstSignature()) |signature|
        try signature.toBase58(allocator)
    else
        null;
    defer if (first_signature_base58) |value| allocator.free(value);

    var diagnostics = try buildInvocationDiagnosticsFromReport(
        allocator,
        &prepared.prepared.report,
    );
    defer diagnostics.deinit(allocator);

    try writer.print("preferred mode: {s}\n", .{selectedModeText(prepared.mode_report.preferred_mode)});
    try writer.print("requested mode: {s}\n", .{requestedModeText(prepared.requested_mode)});
    try writer.print("selected mode: {s}\n", .{@tagName(prepared.selected_mode)});
    try writer.print("used fallback: {}\n", .{prepared.used_fallback});
    try writer.print("requested mode buildable: {}\n", .{prepared.requested_mode_buildable});
    try writer.print("can execute selected mode: {}\n", .{prepared.can_execute_selected_mode});
    try writer.print("validation passed: {}\n", .{prepared.prepared.report.validation.is_valid});
    try writer.print("payer: {s}\n", .{payer_base58});
    try writer.print("blockhash mode: {s}\n", .{invocationBlockhashModeJsonLabel(prepared.prepared.report.plan.blockhash_mode)});
    if (prepared.prepared.report.plan.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(allocator);
        defer allocator.free(recent_blockhash_base58);
        try writer.print("recent blockhash: {s}\n", .{recent_blockhash_base58});
    }
    if (prepared.prepared.report.plan.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(allocator);
        defer allocator.free(nonce_account_base58);
        try writer.print("nonce account: {s}\n", .{nonce_account_base58});
    }
    if (prepared.prepared.report.plan.nonce_authority) |value| {
        const nonce_authority_base58 = try value.toBase58(allocator);
        defer allocator.free(nonce_authority_base58);
        try writer.print("nonce authority: {s}\n", .{nonce_authority_base58});
    }
    try writer.print("instruction count: {}\n", .{prepared.prepared.report.summary.instruction_count});
    try writer.print("account count: {}\n", .{prepared.prepared.report.summary.account_count});
    try writer.print("signer count: {}\n", .{prepared.prepared.report.summary.signer_count});
    try writer.print("lookup table count: {}\n", .{prepared.prepared.report.summary.address_lookup_table_count});
    if (first_signature_base58) |value| {
        try writer.print("first signature: {s}\n", .{value});
    }
    try writer.print("transaction base64: {s}\n", .{transaction_base64});
    try writer.print("message base64: {s}\n", .{message_base64});
    if (prepared.prepared.report.summary.program_ids.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "program ids", prepared.prepared.report.summary.program_ids);
    }
    if (prepared.prepared.report.preflight.provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "provided signer pubkeys", prepared.prepared.report.preflight.provided_signer_pubkeys);
    }
    if (prepared.prepared.report.preflight.required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "required signer pubkeys", prepared.prepared.report.preflight.required_signer_pubkeys);
    }
    if (prepared.prepared.report.preflight.writable_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "writable pubkeys", prepared.prepared.report.preflight.writable_pubkeys);
    }
    if (prepared.prepared.report.preflight.readonly_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "readonly pubkeys", prepared.prepared.report.preflight.readonly_pubkeys);
    }
    if (prepared.prepared.report.plan.lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup table pubkeys", prepared.prepared.report.plan.lookup_table_pubkeys);
    }
    if (prepared.prepared.report.lookup_coverage.lookup_table_address_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup table address pubkeys", prepared.prepared.report.lookup_coverage.lookup_table_address_pubkeys);
    }
    if (prepared.prepared.report.lookup_coverage.candidate_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup candidate pubkeys", prepared.prepared.report.lookup_coverage.candidate_pubkeys);
    }
    if (prepared.prepared.report.lookup_coverage.covered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup covered pubkeys", prepared.prepared.report.lookup_coverage.covered_pubkeys);
    }
    if (prepared.prepared.report.lookup_coverage.uncovered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup uncovered pubkeys", prepared.prepared.report.lookup_coverage.uncovered_pubkeys);
    }
    if (prepared.prepared.report.validation.missing_required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "missing required signer pubkeys", prepared.prepared.report.validation.missing_required_signer_pubkeys);
    }
    if (prepared.prepared.report.validation.extra_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "extra signer pubkeys", prepared.prepared.report.validation.extra_signer_pubkeys);
    }
    if (prepared.prepared.report.validation.duplicate_provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate signer pubkeys", prepared.prepared.report.validation.duplicate_provided_signer_pubkeys);
    }
    if (prepared.prepared.report.validation.duplicate_lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate lookup table pubkeys", prepared.prepared.report.validation.duplicate_lookup_table_pubkeys);
    }
    try writeInvocationDiagnosticsText(writer, diagnostics);
    try writeInvocationAccountsText(writer, allocator, prepared.prepared.accounts);
}

pub fn writePreferredPreparedInvocationJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    prepared: *const PreferredPreparedInvocation,
) !void {
    var first = true;
    const report = &prepared.prepared.report;
    var diagnostics = try buildInvocationDiagnosticsFromReport(allocator, report);
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "preferred_mode", invocationModeJsonLabel(prepared.mode_report.preferred_mode));
    try writeJsonStringField(writer, &first, "requested_mode", invocationModeJsonLabel(prepared.requested_mode));
    try writeJsonStringField(writer, &first, "selected_mode", @tagName(prepared.selected_mode));
    try writeJsonBoolField(writer, &first, "used_fallback", prepared.used_fallback);
    try writeJsonBoolField(writer, &first, "requested_mode_buildable", prepared.requested_mode_buildable);
    try writeJsonBoolField(writer, &first, "legacy_buildable", prepared.mode_report.legacy_buildable);
    try writeJsonBoolField(writer, &first, "versioned_buildable", prepared.mode_report.versioned_buildable);
    try writeJsonBoolField(writer, &first, "validation_passed", report.validation.is_valid);
    try writeJsonBoolField(writer, &first, "can_execute_selected_mode", prepared.can_execute_selected_mode);
    try writeJsonBoolField(writer, &first, "can_execute", report.can_execute);

    const payer_base58 = try report.summary.payer.toBase58(allocator);
    defer allocator.free(payer_base58);
    try writeJsonStringField(writer, &first, "payer", payer_base58);
    try writeJsonStringField(writer, &first, "blockhash_mode", invocationBlockhashModeJsonLabel(report.plan.blockhash_mode));
    const recent_blockhash_base58 = if (report.plan.recent_blockhash) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (recent_blockhash_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "recent_blockhash", recent_blockhash_base58);
    const nonce_account_base58 = if (report.plan.nonce_account) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_account_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "nonce_account", nonce_account_base58);
    const nonce_authority_base58 = if (report.plan.nonce_authority) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_authority_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "nonce_authority", nonce_authority_base58);

    try writeJsonUsizeField(writer, &first, "instruction_count", report.summary.instruction_count);
    try writeJsonUsizeField(writer, &first, "account_count", report.summary.account_count);
    try writeJsonUsizeField(writer, &first, "signer_count", report.summary.signer_count);
    try writeJsonUsizeField(writer, &first, "writable_account_count", report.summary.writable_account_count);
    try writeJsonUsizeField(writer, &first, "readonly_account_count", report.summary.readonly_account_count);
    try writeJsonUsizeField(writer, &first, "lookup_table_count", report.summary.address_lookup_table_count);
    try writeJsonUsizeField(writer, &first, "missing_required_signer_count", report.validation.missing_required_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "extra_signer_count", report.validation.extra_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_signer_count", report.validation.duplicate_provided_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_lookup_table_count", report.validation.duplicate_lookup_table_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "diagnostic_error_count", diagnostics.errorCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_warning_count", diagnostics.warningCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_info_count", diagnostics.infoCount());

    const transaction_base64 = try prepared.toBase64(allocator);
    defer allocator.free(transaction_base64);
    try writeJsonStringField(writer, &first, "transaction_base64", transaction_base64);

    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);
    try writeJsonStringField(writer, &first, "message_base64", message_base64);

    const first_signature_base58 = if (prepared.firstSignature()) |signature|
        try signature.toBase58(allocator)
    else
        null;
    defer if (first_signature_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "first_signature", first_signature_base58);

    try writeJsonPubkeyArrayField(writer, &first, "program_ids", allocator, report.summary.program_ids);
    try writeJsonPubkeyArrayField(writer, &first, "provided_signer_pubkeys", allocator, report.preflight.provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "required_signer_pubkeys", allocator, report.preflight.required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "writable_pubkeys", allocator, report.preflight.writable_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "readonly_pubkeys", allocator, report.preflight.readonly_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_table_pubkeys", allocator, report.plan.lookup_table_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_table_address_pubkeys", allocator, report.lookup_coverage.lookup_table_address_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_candidate_pubkeys", allocator, report.lookup_coverage.candidate_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_covered_pubkeys", allocator, report.lookup_coverage.covered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_uncovered_pubkeys", allocator, report.lookup_coverage.uncovered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "missing_required_signer_pubkeys", allocator, report.validation.missing_required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "extra_signer_pubkeys", allocator, report.validation.extra_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_signer_pubkeys", allocator, report.validation.duplicate_provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_lookup_table_pubkeys", allocator, report.validation.duplicate_lookup_table_pubkeys);
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writeJsonAccountsField(writer, &first, allocator, prepared.prepared.accounts);
    try writer.writeAll("}");
}

pub fn allocPreferredPreparedInvocationJson(
    allocator: Allocator,
    prepared: *const PreferredPreparedInvocation,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreferredPreparedInvocationJson(&aw.writer, allocator, prepared);
    return try aw.toOwnedSlice();
}

pub fn writePreparedInvocationText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    prepared: *const PreparedInvocation,
) !void {
    const payer_base58 = try prepared.payer().toBase58(allocator);
    defer allocator.free(payer_base58);

    const transaction_base64 = try prepared.toBase64(allocator);
    defer allocator.free(transaction_base64);

    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);

    const first_signature_base58 = if (prepared.firstSignature()) |signature|
        try signature.toBase58(allocator)
    else
        null;
    defer if (first_signature_base58) |value| allocator.free(value);

    var diagnostics = try buildInvocationDiagnosticsFromReport(
        allocator,
        &prepared.report,
    );
    defer diagnostics.deinit(allocator);

    try writer.print("mode: {s}\n", .{@tagName(prepared.mode)});
    try writer.print("validation passed: {}\n", .{prepared.report.validation.is_valid});
    try writer.print("can execute: {}\n", .{prepared.report.can_execute});
    try writer.print("payer: {s}\n", .{payer_base58});
    try writer.print("blockhash mode: {s}\n", .{invocationBlockhashModeJsonLabel(prepared.report.plan.blockhash_mode)});
    if (prepared.report.plan.recent_blockhash) |value| {
        const recent_blockhash_base58 = try value.toBase58(allocator);
        defer allocator.free(recent_blockhash_base58);
        try writer.print("recent blockhash: {s}\n", .{recent_blockhash_base58});
    }
    if (prepared.report.plan.nonce_account) |value| {
        const nonce_account_base58 = try value.toBase58(allocator);
        defer allocator.free(nonce_account_base58);
        try writer.print("nonce account: {s}\n", .{nonce_account_base58});
    }
    if (prepared.report.plan.nonce_authority) |value| {
        const nonce_authority_base58 = try value.toBase58(allocator);
        defer allocator.free(nonce_authority_base58);
        try writer.print("nonce authority: {s}\n", .{nonce_authority_base58});
    }
    try writer.print("instruction count: {}\n", .{prepared.report.summary.instruction_count});
    try writer.print("account count: {}\n", .{prepared.report.summary.account_count});
    try writer.print("signer count: {}\n", .{prepared.report.summary.signer_count});
    try writer.print("writable account count: {}\n", .{prepared.report.summary.writable_account_count});
    try writer.print("readonly account count: {}\n", .{prepared.report.summary.readonly_account_count});
    try writer.print("lookup table count: {}\n", .{prepared.report.summary.address_lookup_table_count});
    if (first_signature_base58) |value| {
        try writer.print("first signature: {s}\n", .{value});
    }
    try writer.print("transaction base64: {s}\n", .{transaction_base64});
    try writer.print("message base64: {s}\n", .{message_base64});
    try writeInvocationPubkeysText(writer, allocator, "program ids", prepared.report.summary.program_ids);
    if (prepared.report.preflight.provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "provided signer pubkeys", prepared.report.preflight.provided_signer_pubkeys);
    }
    if (prepared.report.preflight.required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "required signer pubkeys", prepared.report.preflight.required_signer_pubkeys);
    }
    if (prepared.report.preflight.writable_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "writable pubkeys", prepared.report.preflight.writable_pubkeys);
    }
    if (prepared.report.preflight.readonly_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "readonly pubkeys", prepared.report.preflight.readonly_pubkeys);
    }
    if (prepared.report.plan.lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup table pubkeys", prepared.report.plan.lookup_table_pubkeys);
    }
    if (prepared.report.lookup_coverage.lookup_table_address_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup table address pubkeys", prepared.report.lookup_coverage.lookup_table_address_pubkeys);
    }
    if (prepared.report.lookup_coverage.candidate_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup candidate pubkeys", prepared.report.lookup_coverage.candidate_pubkeys);
    }
    if (prepared.report.lookup_coverage.covered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup covered pubkeys", prepared.report.lookup_coverage.covered_pubkeys);
    }
    if (prepared.report.lookup_coverage.uncovered_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "lookup uncovered pubkeys", prepared.report.lookup_coverage.uncovered_pubkeys);
    }
    if (prepared.report.validation.missing_required_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "missing required signer pubkeys", prepared.report.validation.missing_required_signer_pubkeys);
    }
    if (prepared.report.validation.extra_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "extra signer pubkeys", prepared.report.validation.extra_signer_pubkeys);
    }
    if (prepared.report.validation.duplicate_provided_signer_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate signer pubkeys", prepared.report.validation.duplicate_provided_signer_pubkeys);
    }
    if (prepared.report.validation.duplicate_lookup_table_pubkeys.len != 0) {
        try writeInvocationPubkeysText(writer, allocator, "duplicate lookup table pubkeys", prepared.report.validation.duplicate_lookup_table_pubkeys);
    }
    try writeInvocationDiagnosticsText(writer, diagnostics);
    try writeInvocationAccountsText(writer, allocator, prepared.accounts);
}

pub fn writePreparedInvocationJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    prepared: *const PreparedInvocation,
) !void {
    var first = true;
    var diagnostics = try buildInvocationDiagnosticsFromReport(
        allocator,
        &prepared.report,
    );
    defer diagnostics.deinit(allocator);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "mode", @tagName(prepared.mode));
    try writeJsonBoolField(writer, &first, "validation_passed", prepared.report.validation.is_valid);
    try writeJsonBoolField(writer, &first, "can_execute", prepared.report.can_execute);

    const payer_base58 = try prepared.report.summary.payer.toBase58(allocator);
    defer allocator.free(payer_base58);
    try writeJsonStringField(writer, &first, "payer", payer_base58);
    try writeJsonStringField(writer, &first, "blockhash_mode", invocationBlockhashModeJsonLabel(prepared.report.plan.blockhash_mode));

    const recent_blockhash_base58 = if (prepared.report.plan.recent_blockhash) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (recent_blockhash_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "recent_blockhash", recent_blockhash_base58);

    const nonce_account_base58 = if (prepared.report.plan.nonce_account) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_account_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "nonce_account", nonce_account_base58);

    const nonce_authority_base58 = if (prepared.report.plan.nonce_authority) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_authority_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "nonce_authority", nonce_authority_base58);

    try writeJsonUsizeField(writer, &first, "instruction_count", prepared.report.summary.instruction_count);
    try writeJsonUsizeField(writer, &first, "account_count", prepared.report.summary.account_count);
    try writeJsonUsizeField(writer, &first, "signer_count", prepared.report.summary.signer_count);
    try writeJsonUsizeField(writer, &first, "writable_account_count", prepared.report.summary.writable_account_count);
    try writeJsonUsizeField(writer, &first, "readonly_account_count", prepared.report.summary.readonly_account_count);
    try writeJsonUsizeField(writer, &first, "lookup_table_count", prepared.report.summary.address_lookup_table_count);
    try writeJsonUsizeField(writer, &first, "missing_required_signer_count", prepared.report.validation.missing_required_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "extra_signer_count", prepared.report.validation.extra_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_signer_count", prepared.report.validation.duplicate_provided_signer_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "duplicate_lookup_table_count", prepared.report.validation.duplicate_lookup_table_pubkeys.len);
    try writeJsonUsizeField(writer, &first, "diagnostic_error_count", diagnostics.errorCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_warning_count", diagnostics.warningCount());
    try writeJsonUsizeField(writer, &first, "diagnostic_info_count", diagnostics.infoCount());

    const transaction_base64 = try prepared.toBase64(allocator);
    defer allocator.free(transaction_base64);
    try writeJsonStringField(writer, &first, "transaction_base64", transaction_base64);

    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);
    try writeJsonStringField(writer, &first, "message_base64", message_base64);

    const first_signature_base58 = if (prepared.firstSignature()) |signature|
        try signature.toBase58(allocator)
    else
        null;
    defer if (first_signature_base58) |value| allocator.free(value);
    try writeJsonStringField(writer, &first, "first_signature", first_signature_base58);

    try writeJsonPubkeyArrayField(writer, &first, "program_ids", allocator, prepared.report.summary.program_ids);
    try writeJsonPubkeyArrayField(writer, &first, "provided_signer_pubkeys", allocator, prepared.report.preflight.provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "required_signer_pubkeys", allocator, prepared.report.preflight.required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "writable_pubkeys", allocator, prepared.report.preflight.writable_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "readonly_pubkeys", allocator, prepared.report.preflight.readonly_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_table_pubkeys", allocator, prepared.report.plan.lookup_table_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_table_address_pubkeys", allocator, prepared.report.lookup_coverage.lookup_table_address_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_candidate_pubkeys", allocator, prepared.report.lookup_coverage.candidate_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_covered_pubkeys", allocator, prepared.report.lookup_coverage.covered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "lookup_uncovered_pubkeys", allocator, prepared.report.lookup_coverage.uncovered_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "missing_required_signer_pubkeys", allocator, prepared.report.validation.missing_required_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "extra_signer_pubkeys", allocator, prepared.report.validation.extra_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_signer_pubkeys", allocator, prepared.report.validation.duplicate_provided_signer_pubkeys);
    try writeJsonPubkeyArrayField(writer, &first, "duplicate_lookup_table_pubkeys", allocator, prepared.report.validation.duplicate_lookup_table_pubkeys);
    try writeJsonDiagnosticsField(writer, &first, diagnostics);
    try writeJsonAccountsField(writer, &first, allocator, prepared.accounts);
    try writer.writeAll("}");
}

pub fn allocPreparedInvocationJson(
    allocator: Allocator,
    prepared: *const PreparedInvocation,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreparedInvocationJson(&aw.writer, allocator, prepared);
    return try aw.toOwnedSlice();
}

pub fn writeSentPreparedInvocationText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    sent: *const SentPreparedInvocation,
    confirmed: bool,
) !void {
    try writePreparedInvocationText(writer, allocator, &sent.prepared);
    try writer.print("{s}: {s}\n", .{ if (confirmed) "confirmed signature" else "signature", sent.signature });
}

pub fn writeSentPreparedInvocationJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    sent: *const SentPreparedInvocation,
) !void {
    const prepared_json = try allocPreparedInvocationJson(allocator, &sent.prepared);
    defer allocator.free(prepared_json);

    try writer.writeAll(prepared_json[0 .. prepared_json.len - 1]);
    try writer.writeAll(",\"signature\":");
    try std.json.Stringify.value(sent.signature, .{}, writer);
    try writer.writeAll("}");
}

pub fn allocSentPreparedInvocationJson(
    allocator: Allocator,
    sent: *const SentPreparedInvocation,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writeSentPreparedInvocationJson(&aw.writer, allocator, sent);
    return try aw.toOwnedSlice();
}

pub fn writeSimulatedPreparedInvocationText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    simulated: *const SimulatedPreparedInvocation,
) !void {
    try writePreparedInvocationText(writer, allocator, &simulated.prepared);
    try writer.print("context slot: {}\n", .{simulated.simulation.context_slot});
    if (simulated.simulation.fee) |value| try writer.print("fee: {}\n", .{value});
    if (simulated.simulation.units_consumed) |value| try writer.print("units consumed: {}\n", .{value});
}

pub fn writeSimulatedPreparedInvocationJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    simulated: *const SimulatedPreparedInvocation,
) !void {
    const prepared_json = try allocPreparedInvocationJson(allocator, &simulated.prepared);
    defer allocator.free(prepared_json);

    try writer.writeAll(prepared_json[0 .. prepared_json.len - 1]);
    try writer.writeAll(",\"context_slot\":");
    try std.json.Stringify.value(simulated.simulation.context_slot, .{}, writer);
    try writer.writeAll(",\"fee\":");
    try std.json.Stringify.value(simulated.simulation.fee, .{}, writer);
    try writer.writeAll(",\"units_consumed\":");
    try std.json.Stringify.value(simulated.simulation.units_consumed, .{}, writer);
    try writer.writeAll("}");
}

pub fn allocSimulatedPreparedInvocationJson(
    allocator: Allocator,
    simulated: *const SimulatedPreparedInvocation,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writeSimulatedPreparedInvocationJson(&aw.writer, allocator, simulated);
    return try aw.toOwnedSlice();
}

pub fn writePreparedInvocationFeeText(
    writer: *std.Io.Writer,
    allocator: Allocator,
    fee_result: *const PreparedInvocationFee,
) !void {
    try writePreparedInvocationText(writer, allocator, &fee_result.prepared);
    try writer.print("fee: {}\n", .{fee_result.fee});
}

pub fn writePreparedInvocationFeeJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    fee_result: *const PreparedInvocationFee,
) !void {
    const prepared_json = try allocPreparedInvocationJson(allocator, &fee_result.prepared);
    defer allocator.free(prepared_json);

    try writer.writeAll(prepared_json[0 .. prepared_json.len - 1]);
    try writer.writeAll(",\"fee\":");
    try std.json.Stringify.value(fee_result.fee, .{}, writer);
    try writer.writeAll("}");
}

pub fn allocPreparedInvocationFeeJson(
    allocator: Allocator,
    fee_result: *const PreparedInvocationFee,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writePreparedInvocationFeeJson(&aw.writer, allocator, fee_result);
    return try aw.toOwnedSlice();
}

pub const PreparedInvocation = struct {
    mode: InvocationMode,
    report: OwnedInvocationReport,
    resolved_invocation: OwnedResolvedInvocation,
    accounts: OwnedInvocationAccounts,
    transaction: SignedInvocationTransaction,

    pub fn deinit(self: *PreparedInvocation, allocator: Allocator) void {
        self.report.deinit(allocator);
        self.resolved_invocation.deinit(allocator);
        self.accounts.deinit(allocator);
        self.transaction.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: PreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.transaction.serialize(allocator);
    }

    pub fn toBase64(self: PreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.transaction.toBase64(allocator);
    }

    pub fn serializeMessage(self: PreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.transaction.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: PreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.transaction.messageToBase64(allocator);
    }

    pub fn firstSignature(self: PreparedInvocation) ?sdk.Signature {
        return self.transaction.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const PreparedInvocation, allocator: Allocator) ![]u8 {
        return try allocOwnedResolvedInvocationJson(allocator, &self.resolved_invocation);
    }

    pub fn allocInstructionsJson(self: *const PreparedInvocation, allocator: Allocator) ![]u8 {
        return try buildInstructionsJsonFromOwnedResolvedInvocation(allocator, &self.resolved_invocation);
    }

    pub fn send(
        self: *const PreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) ![]const u8 {
        return try sendPreparedInvocation(rpc, self, options);
    }

    pub fn simulate(
        self: *const PreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !client.SimulatedTransaction {
        return try simulatePreparedInvocation(rpc, self, options);
    }

    pub fn sendAndConfirm(
        self: *const PreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try sendAndConfirmPreparedInvocation(
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmWithSpinner(
        self: *const PreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try sendAndConfirmPreparedInvocationWithSpinner(
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFee(
        self: *const PreparedInvocation,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !rpc_types.FeeForMessage {
        return try getFeeForPreparedInvocation(rpc, self, commitment);
    }

    pub fn payer(self: PreparedInvocation) sdk.Pubkey {
        return self.resolved_invocation.payer;
    }

    pub fn containsSigner(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.resolved_invocation.signer_pubkeys, pubkey);
    }

    pub fn containsProgram(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return pubkeySliceContains(self.report.summary.program_ids, pubkey);
    }

    pub fn containsLookupTable(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.report.lookup_coverage.containsLookupTable(pubkey);
    }

    pub fn isWritableAccount(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.accounts.isWritable(pubkey);
    }

    pub fn isProgramAccount(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.accounts.isProgram(pubkey);
    }

    pub fn usesDurableNonce(self: PreparedInvocation) bool {
        return self.report.uses_durable_nonce;
    }

    pub fn blockhashMode(self: PreparedInvocation) InvocationBlockhashMode {
        return self.report.plan.blockhash_mode;
    }

    pub fn canExecute(self: PreparedInvocation) bool {
        return self.report.can_execute;
    }

    pub fn hasMissingRequiredSigner(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.report.hasMissingRequiredSigner(pubkey);
    }

    pub fn hasExtraSigner(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.report.hasExtraSigner(pubkey);
    }

    pub fn hasDuplicateSigner(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.report.hasDuplicateSigner(pubkey);
    }

    pub fn hasDuplicateLookupTable(self: PreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.report.hasDuplicateLookupTable(pubkey);
    }

    pub fn sendOwned(
        self: PreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) !SentPreparedInvocation {
        return try sendOwnedPreparedInvocation(allocator, rpc, self, options);
    }

    pub fn simulateOwned(
        self: PreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !SimulatedPreparedInvocation {
        return try simulateOwnedPreparedInvocation(allocator, rpc, self, options);
    }

    pub fn sendAndConfirmOwned(
        self: PreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreparedInvocation {
        return try sendAndConfirmOwnedPreparedInvocation(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmOwnedWithSpinner(
        self: PreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreparedInvocation {
        return try sendAndConfirmOwnedPreparedInvocationWithSpinner(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFeeOwned(
        self: PreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !PreparedInvocationFee {
        return try getFeeForOwnedPreparedInvocation(allocator, rpc, self, commitment);
    }
};

pub const PreferredPreparedInvocation = struct {
    mode_report: InvocationModeReport,
    requested_mode: ?InvocationMode,
    selected_mode: InvocationMode,
    requested_mode_buildable: bool,
    used_fallback: bool,
    can_execute_selected_mode: bool,
    prepared: PreparedInvocation,

    pub fn deinit(self: *PreferredPreparedInvocation, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: PreferredPreparedInvocation) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const PreferredPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }

    pub fn send(
        self: *const PreferredPreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) ![]const u8 {
        return try self.prepared.send(rpc, options);
    }

    pub fn simulate(
        self: *const PreferredPreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !client.SimulatedTransaction {
        return try self.prepared.simulate(rpc, options);
    }

    pub fn sendAndConfirm(
        self: *const PreferredPreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try self.prepared.sendAndConfirm(
            rpc,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmWithSpinner(
        self: *const PreferredPreparedInvocation,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try self.prepared.sendAndConfirmWithSpinner(
            rpc,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFee(
        self: *const PreferredPreparedInvocation,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !rpc_types.FeeForMessage {
        return try self.prepared.getFee(rpc, commitment);
    }

    pub fn payer(self: PreferredPreparedInvocation) sdk.Pubkey {
        return self.prepared.payer();
    }

    pub fn containsSigner(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.containsSigner(pubkey);
    }

    pub fn containsProgram(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.containsProgram(pubkey);
    }

    pub fn containsLookupTable(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.containsLookupTable(pubkey);
    }

    pub fn isWritableAccount(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.isWritableAccount(pubkey);
    }

    pub fn isProgramAccount(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.isProgramAccount(pubkey);
    }

    pub fn usesDurableNonce(self: PreferredPreparedInvocation) bool {
        return self.prepared.usesDurableNonce();
    }

    pub fn blockhashMode(self: PreferredPreparedInvocation) InvocationBlockhashMode {
        return self.prepared.blockhashMode();
    }

    pub fn canExecute(self: PreferredPreparedInvocation) bool {
        return self.can_execute_selected_mode;
    }

    pub fn hasMissingRequiredSigner(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.hasMissingRequiredSigner(pubkey);
    }

    pub fn hasExtraSigner(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.hasExtraSigner(pubkey);
    }

    pub fn hasDuplicateSigner(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.hasDuplicateSigner(pubkey);
    }

    pub fn hasDuplicateLookupTable(self: PreferredPreparedInvocation, pubkey: sdk.Pubkey) bool {
        return self.prepared.hasDuplicateLookupTable(pubkey);
    }

    pub fn sendOwned(
        self: PreferredPreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) !SentPreferredPreparedExecution {
        return try sendOwnedPreferredPreparedExecution(allocator, rpc, self, options);
    }

    pub fn simulateOwned(
        self: PreferredPreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !SimulatedPreferredPreparedExecution {
        return try simulateOwnedPreferredPreparedExecution(allocator, rpc, self, options);
    }

    pub fn sendAndConfirmOwned(
        self: PreferredPreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreferredPreparedExecution {
        return try sendAndConfirmOwnedPreferredPreparedExecution(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmOwnedWithSpinner(
        self: PreferredPreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreferredPreparedExecution {
        return try sendAndConfirmOwnedPreferredPreparedExecutionWithSpinner(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFeeOwned(
        self: PreferredPreparedInvocation,
        allocator: Allocator,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !PreferredPreparedExecutionFee {
        return try getFeeForOwnedPreferredPreparedExecution(allocator, rpc, self, commitment);
    }
};

pub const SentPreparedInvocation = struct {
    prepared: PreparedInvocation,
    signature: []const u8,

    pub fn deinit(self: *SentPreparedInvocation, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        allocator.free(self.signature);
        self.* = undefined;
    }

    pub fn serialize(self: SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: SentPreparedInvocation) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const SentPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const SimulatedPreparedInvocation = struct {
    prepared: PreparedInvocation,
    simulation: client.SimulatedTransaction,

    pub fn deinit(self: *SimulatedPreparedInvocation, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: SimulatedPreparedInvocation) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const SimulatedPreparedInvocation, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const PreparedInvocationFee = struct {
    prepared: PreparedInvocation,
    fee: rpc_types.FeeForMessage,

    pub fn deinit(self: *PreparedInvocationFee, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: PreparedInvocationFee) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const PreparedInvocationFee, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const SentPreferredPreparedExecution = struct {
    prepared: PreferredPreparedInvocation,
    signature: []const u8,

    pub fn deinit(self: *SentPreferredPreparedExecution, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        allocator.free(self.signature);
        self.* = undefined;
    }

    pub fn serialize(self: SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: SentPreferredPreparedExecution) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const SentPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const SimulatedPreferredPreparedExecution = struct {
    prepared: PreferredPreparedInvocation,
    simulation: client.SimulatedTransaction,

    pub fn deinit(self: *SimulatedPreferredPreparedExecution, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: SimulatedPreferredPreparedExecution) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const SimulatedPreferredPreparedExecution, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const PreferredPreparedExecutionFee = struct {
    prepared: PreferredPreparedInvocation,
    fee: rpc_types.FeeForMessage,

    pub fn deinit(self: *PreferredPreparedExecutionFee, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.serialize(allocator);
    }

    pub fn toBase64(self: PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.toBase64(allocator);
    }

    pub fn serializeMessage(self: PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.messageToBase64(allocator);
    }

    pub fn firstSignature(self: PreferredPreparedExecutionFee) ?sdk.Signature {
        return self.prepared.firstSignature();
    }

    pub fn allocResolvedInvocationJson(self: *const PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.allocResolvedInvocationJson(allocator);
    }

    pub fn allocInstructionsJson(self: *const PreferredPreparedExecutionFee, allocator: Allocator) ![]u8 {
        return try self.prepared.allocInstructionsJson(allocator);
    }
};

pub const PreferredPreparedSignedTransaction = struct {
    execution_report: PreferredInvocationExecutionReport,
    resolved_invocation: OwnedResolvedInvocation,
    accounts: OwnedInvocationAccounts,
    transaction: SignedInvocationTransaction,

    pub fn deinit(self: *PreferredPreparedSignedTransaction, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.resolved_invocation.deinit(allocator);
        self.accounts.deinit(allocator);
        self.transaction.deinit(allocator);
        self.* = undefined;
    }

    pub fn serialize(self: PreferredPreparedSignedTransaction, allocator: Allocator) ![]u8 {
        return try self.transaction.serialize(allocator);
    }

    pub fn toBase64(self: PreferredPreparedSignedTransaction, allocator: Allocator) ![]u8 {
        return try self.transaction.toBase64(allocator);
    }

    pub fn serializeMessage(self: PreferredPreparedSignedTransaction, allocator: Allocator) ![]u8 {
        return try self.transaction.serializeMessage(allocator);
    }

    pub fn messageToBase64(self: PreferredPreparedSignedTransaction, allocator: Allocator) ![]u8 {
        return try self.transaction.messageToBase64(allocator);
    }

    pub fn firstSignature(self: PreferredPreparedSignedTransaction) ?sdk.Signature {
        return self.transaction.firstSignature();
    }

    pub fn send(
        self: *const PreferredPreparedSignedTransaction,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) ![]const u8 {
        return try sendPreferredPreparedInvocation(rpc, self, options);
    }

    pub fn simulate(
        self: *const PreferredPreparedSignedTransaction,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !client.SimulatedTransaction {
        return try simulatePreferredPreparedInvocation(rpc, self, options);
    }

    pub fn sendAndConfirm(
        self: *const PreferredPreparedSignedTransaction,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try sendAndConfirmPreferredPreparedInvocation(
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmWithSpinner(
        self: *const PreferredPreparedSignedTransaction,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) ![]const u8 {
        return try sendAndConfirmPreferredPreparedInvocationWithSpinner(
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFee(
        self: *const PreferredPreparedSignedTransaction,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !rpc_types.FeeForMessage {
        return try getFeeForPreferredPreparedInvocation(rpc, self, commitment);
    }

    pub fn sendOwned(
        self: PreferredPreparedSignedTransaction,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
    ) !SentPreferredPreparedInvocation {
        return try sendOwnedPreferredPreparedInvocation(allocator, rpc, self, options);
    }

    pub fn simulateOwned(
        self: PreferredPreparedSignedTransaction,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SimulateTransactionOptions,
    ) !SimulatedPreferredPreparedInvocation {
        return try simulateOwnedPreferredPreparedInvocation(allocator, rpc, self, options);
    }

    pub fn sendAndConfirmOwned(
        self: PreferredPreparedSignedTransaction,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreferredPreparedInvocation {
        return try sendAndConfirmOwnedPreferredPreparedInvocation(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn sendAndConfirmOwnedWithSpinner(
        self: PreferredPreparedSignedTransaction,
        allocator: Allocator,
        rpc: anytype,
        options: ?rpc_types.SendTransactionOptions,
        commitment: ?client.Commitment,
        search_transaction_history: bool,
        timeout_ms: u64,
        poll_interval_ms: u64,
    ) !SentPreferredPreparedInvocation {
        return try sendAndConfirmOwnedPreferredPreparedInvocationWithSpinner(
            allocator,
            rpc,
            self,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        );
    }

    pub fn getFeeOwned(
        self: PreferredPreparedSignedTransaction,
        allocator: Allocator,
        rpc: anytype,
        commitment: ?client.Commitment,
    ) !PreferredPreparedInvocationFee {
        return try getFeeForOwnedPreferredPreparedInvocation(allocator, rpc, self, commitment);
    }
};

pub const SentPreferredPreparedInvocation = struct {
    prepared: PreferredPreparedSignedTransaction,
    signature: []const u8,

    pub fn deinit(self: *SentPreferredPreparedInvocation, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        allocator.free(self.signature);
        self.* = undefined;
    }
};

pub const SimulatedPreferredPreparedInvocation = struct {
    prepared: PreferredPreparedSignedTransaction,
    simulation: client.SimulatedTransaction,

    pub fn deinit(self: *SimulatedPreferredPreparedInvocation, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredPreparedInvocationFee = struct {
    prepared: PreferredPreparedSignedTransaction,
    fee: rpc_types.FeeForMessage,

    pub fn deinit(self: *PreferredPreparedInvocationFee, allocator: Allocator) void {
        self.prepared.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredSignatureExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    signature: []const u8,

    pub fn deinit(self: *PreferredSignatureExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        allocator.free(self.signature);
        self.* = undefined;
    }
};

pub const PreferredSimulationExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    simulation: client.SimulatedTransaction,

    pub fn deinit(self: *PreferredSimulationExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.* = undefined;
    }
};

pub const PreferredFeeExecutionResult = struct {
    execution_report: PreferredInvocationExecutionReport,
    fee: client.FeeForMessage,

    pub fn deinit(self: *PreferredFeeExecutionResult, allocator: Allocator) void {
        self.execution_report.deinit(allocator);
        self.* = undefined;
    }
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

pub const OwnedInvocationSpecParts = struct {
    payer: sdk.Pubkey,
    signers: []sdk.Keypair,
    owned_instructions: sdk.OwnedInstructions,
    address_lookup_tables: []sdk.AddressLookupTableAccount = &.{},
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,
};

pub const BorrowedInvocationSpecParts = struct {
    payer: sdk.Pubkey,
    signers: []const sdk.Keypair,
    instructions: []const sdk.Instruction,
    address_lookup_tables: []const sdk.AddressLookupTableAccount = &.{},
    recent_blockhash: ?sdk.Hash = null,
    nonce_account: ?sdk.Pubkey = null,
    nonce_authority: ?sdk.Pubkey = null,
};

pub fn buildOwnedInvocationSpecFromOwnedParts(
    parts: OwnedInvocationSpecParts,
) !OwnedInvocationSpec {
    if (parts.recent_blockhash != null and parts.nonce_account != null) {
        return error.ConflictingRecentBlockhashAndNonce;
    }

    return .{
        .payer = parts.payer,
        .signers = parts.signers,
        .owned_instructions = parts.owned_instructions,
        .address_lookup_tables = parts.address_lookup_tables,
        .recent_blockhash = parts.recent_blockhash,
        .nonce_account = parts.nonce_account,
        .nonce_authority = parts.nonce_authority,
    };
}

pub fn buildOwnedInvocationSpecFromBorrowedParts(
    allocator: Allocator,
    parts: BorrowedInvocationSpecParts,
) !OwnedInvocationSpec {
    const signers = try allocator.dupe(sdk.Keypair, parts.signers);
    errdefer allocator.free(signers);

    var owned_instructions = try sdk.cloneInstructions(
        allocator,
        parts.instructions,
    );
    errdefer owned_instructions.deinit(allocator);

    const address_lookup_tables = try allocator.alloc(
        sdk.AddressLookupTableAccount,
        parts.address_lookup_tables.len,
    );
    errdefer allocator.free(address_lookup_tables);
    var initialized_tables_len: usize = 0;
    errdefer {
        for (address_lookup_tables[0..initialized_tables_len]) |table| {
            allocator.free(table.addresses);
        }
        allocator.free(address_lookup_tables);
    }
    for (parts.address_lookup_tables, 0..) |table, index| {
        address_lookup_tables[index] = .{
            .account_key = table.account_key,
            .addresses = try allocator.dupe(sdk.Pubkey, table.addresses),
        };
        initialized_tables_len += 1;
    }

    return buildOwnedInvocationSpecFromOwnedParts(.{
        .payer = parts.payer,
        .signers = signers,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = address_lookup_tables,
        .recent_blockhash = parts.recent_blockhash,
        .nonce_account = parts.nonce_account,
        .nonce_authority = parts.nonce_authority,
    });
}

pub const BuildInvocationSpecJsonFromOwnedInvocationSpecError =
    client.invocation_spec_json.BuildError ||
    Allocator.Error ||
    error{
        MissingPayerSigner,
        MissingNonceAuthoritySigner,
    };

fn findOwnedInvocationSignerSecretKeyBase58(
    allocator: Allocator,
    signers: []const sdk.Keypair,
    pubkey: sdk.Pubkey,
) !?[]u8 {
    for (signers) |signer| {
        if (std.meta.eql(signer.public_key, pubkey)) {
            return try client.encodeBase58(allocator, &signer.secret_key);
        }
    }
    return null;
}

fn buildAdditionalSignerSecretKeysJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !?[]u8 {
    const explicit_nonce_authority = if (owned_spec.nonce_account != null and owned_spec.nonce_authority != null and
        !std.meta.eql(owned_spec.nonce_authority.?, owned_spec.payer))
        owned_spec.nonce_authority.?
    else
        null;

    var json_buffer: std.Io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    var signer_count: usize = 0;
    try json_buffer.writer.writeByte('[');
    for (owned_spec.signers) |signer| {
        if (std.meta.eql(signer.public_key, owned_spec.payer)) continue;
        if (explicit_nonce_authority) |nonce_authority| {
            if (std.meta.eql(signer.public_key, nonce_authority)) continue;
        }

        if (signer_count != 0) try json_buffer.writer.writeByte(',');
        const secret_key_base58 = try client.encodeBase58(allocator, &signer.secret_key);
        defer allocator.free(secret_key_base58);
        try std.json.Stringify.value(secret_key_base58, .{}, &json_buffer.writer);
        signer_count += 1;
    }
    try json_buffer.writer.writeByte(']');

    if (signer_count == 0) return null;
    return try allocator.dupe(u8, json_buffer.written());
}

fn buildAddressLookupTablesJsonFromLookupTableSlice(
    allocator: Allocator,
    address_lookup_tables: []const sdk.AddressLookupTableAccount,
) !?[]u8 {
    if (address_lookup_tables.len == 0) return null;

    var json_buffer: std.Io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('[');
    for (address_lookup_tables, 0..) |table, table_index| {
        if (table_index != 0) try json_buffer.writer.writeByte(',');
        const account_key_base58 = try table.account_key.toBase58(allocator);
        defer allocator.free(account_key_base58);

        try json_buffer.writer.writeAll("{\"account_key\":");
        try std.json.Stringify.value(account_key_base58, .{}, &json_buffer.writer);
        try json_buffer.writer.writeAll(",\"addresses\":[");
        for (table.addresses, 0..) |address, address_index| {
            if (address_index != 0) try json_buffer.writer.writeByte(',');
            const address_base58 = try address.toBase58(allocator);
            defer allocator.free(address_base58);
            try std.json.Stringify.value(address_base58, .{}, &json_buffer.writer);
        }
        try json_buffer.writer.writeAll("]}");
    }
    try json_buffer.writer.writeByte(']');

    return try allocator.dupe(u8, json_buffer.written());
}

fn buildAddressLookupTablesJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !?[]u8 {
    return try buildAddressLookupTablesJsonFromLookupTableSlice(
        allocator,
        owned_spec.address_lookup_tables,
    );
}

pub fn buildAddressLookupTablesJsonFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: *const OwnedResolvedInvocation,
) !?[]u8 {
    return try buildAddressLookupTablesJsonFromLookupTableSlice(
        allocator,
        resolved.address_lookup_tables,
    );
}

fn buildInstructionsJsonFromInstructionSlice(
    allocator: Allocator,
    instructions: []const sdk.Instruction,
) (Allocator.Error || error{WriteFailed})![]u8 {
    var json_buffer: std.Io.Writer.Allocating = .init(allocator);
    defer json_buffer.deinit();

    try json_buffer.writer.writeByte('[');
    for (instructions, 0..) |instruction, instruction_index| {
        if (instruction_index != 0) try json_buffer.writer.writeByte(',');
        const program_id_base58 = try instruction.program_id.toBase58(allocator);
        defer allocator.free(program_id_base58);

        try json_buffer.writer.writeAll("{\"program_id\":");
        try std.json.Stringify.value(program_id_base58, .{}, &json_buffer.writer);

        if (instruction.accounts.len != 0) {
            try json_buffer.writer.writeAll(",\"accounts\":[");
            for (instruction.accounts, 0..) |account, account_index| {
                if (account_index != 0) try json_buffer.writer.writeByte(',');
                const account_base58 = try account.pubkey.toBase58(allocator);
                defer allocator.free(account_base58);
                try json_buffer.writer.writeAll("{\"pubkey\":");
                try std.json.Stringify.value(account_base58, .{}, &json_buffer.writer);
                try json_buffer.writer.writeAll(",\"is_signer\":");
                try std.json.Stringify.value(account.is_signer, .{}, &json_buffer.writer);
                try json_buffer.writer.writeAll(",\"is_writable\":");
                try std.json.Stringify.value(account.is_writable, .{}, &json_buffer.writer);
                try json_buffer.writer.writeByte('}');
            }
            try json_buffer.writer.writeByte(']');
        }

        try json_buffer.writer.writeAll(",\"data_bytes\":[");
        for (instruction.data, 0..) |byte, byte_index| {
            if (byte_index != 0) try json_buffer.writer.writeByte(',');
            try std.json.Stringify.value(byte, .{}, &json_buffer.writer);
        }
        try json_buffer.writer.writeAll("]}");
    }
    try json_buffer.writer.writeByte(']');

    return try allocator.dupe(u8, json_buffer.written());
}

pub fn buildInstructionsJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) ![]u8 {
    return try buildInstructionsJsonFromInstructionSlice(
        allocator,
        owned_spec.owned_instructions.instructions,
    );
}

pub fn buildInstructionsJsonFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: *const OwnedResolvedInvocation,
) ![]u8 {
    return try buildInstructionsJsonFromInstructionSlice(
        allocator,
        resolved.owned_instructions.instructions,
    );
}

pub fn writeOwnedResolvedInvocationJson(
    writer: *std.Io.Writer,
    allocator: Allocator,
    resolved: *const OwnedResolvedInvocation,
) !void {
    var first = true;
    const payer_base58 = try resolved.payer.toBase58(allocator);
    defer allocator.free(payer_base58);

    const instructions_json = try buildInstructionsJsonFromOwnedResolvedInvocation(
        allocator,
        resolved,
    );
    defer allocator.free(instructions_json);

    const address_lookup_tables_json = try buildAddressLookupTablesJsonFromOwnedResolvedInvocation(
        allocator,
        resolved,
    );
    defer if (address_lookup_tables_json) |value| allocator.free(value);

    const recent_blockhash_base58 = if (resolved.recent_blockhash) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (recent_blockhash_base58) |value| allocator.free(value);

    const nonce_account_base58 = if (resolved.nonce_account) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_account_base58) |value| allocator.free(value);

    const nonce_authority_base58 = if (resolved.nonce_authority) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_authority_base58) |value| allocator.free(value);

    try writer.writeAll("{");
    try writeJsonStringField(writer, &first, "payer", payer_base58);
    try writeJsonPubkeyArrayField(writer, &first, "signer_pubkeys", allocator, resolved.signer_pubkeys);
    try writeJsonStringField(writer, &first, "recent_blockhash", recent_blockhash_base58);
    try writeJsonStringField(writer, &first, "nonce_account", nonce_account_base58);
    try writeJsonStringField(writer, &first, "nonce_authority", nonce_authority_base58);
    if (address_lookup_tables_json) |value| {
        if (!first) try writer.writeAll(",");
        first = false;
        try std.json.Stringify.value("address_lookup_tables", .{}, writer);
        try writer.writeAll(":");
        try writer.writeAll(value);
    }
    if (!first) try writer.writeAll(",");
    first = false;
    try std.json.Stringify.value("instructions", .{}, writer);
    try writer.writeAll(":");
    try writer.writeAll(instructions_json);
    try writer.writeAll("}");
}

pub fn allocOwnedResolvedInvocationJson(
    allocator: Allocator,
    resolved: *const OwnedResolvedInvocation,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try writeOwnedResolvedInvocationJson(&aw.writer, allocator, resolved);
    return try aw.toOwnedSlice();
}

pub fn buildResolvedInvocationJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) ![]u8 {
    var resolved = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(allocator, owned_spec);
    defer resolved.deinit(allocator);
    return try allocOwnedResolvedInvocationJson(allocator, &resolved);
}

pub fn buildInvocationSpecJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) BuildInvocationSpecJsonFromOwnedInvocationSpecError![]u8 {
    const payer_secret_key = try findOwnedInvocationSignerSecretKeyBase58(
        allocator,
        owned_spec.signers,
        owned_spec.payer,
    ) orelse return error.MissingPayerSigner;
    defer allocator.free(payer_secret_key);

    const additional_signer_secret_keys_json = try buildAdditionalSignerSecretKeysJsonFromOwnedInvocationSpec(
        allocator,
        owned_spec,
    );
    defer if (additional_signer_secret_keys_json) |value| allocator.free(value);

    const address_lookup_tables_json = try buildAddressLookupTablesJsonFromOwnedInvocationSpec(
        allocator,
        owned_spec,
    );
    defer if (address_lookup_tables_json) |value| allocator.free(value);

    const instructions_json = try buildInstructionsJsonFromInstructionSlice(
        allocator,
        owned_spec.owned_instructions.instructions,
    );
    defer allocator.free(instructions_json);

    const recent_blockhash_base58 = if (owned_spec.recent_blockhash) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (recent_blockhash_base58) |value| allocator.free(value);

    const nonce_account_base58 = if (owned_spec.nonce_account) |value|
        try value.toBase58(allocator)
    else
        null;
    defer if (nonce_account_base58) |value| allocator.free(value);

    const nonce_authority_secret_key = if (owned_spec.nonce_account != null and owned_spec.nonce_authority != null and
        !std.meta.eql(owned_spec.nonce_authority.?, owned_spec.payer))
        try findOwnedInvocationSignerSecretKeyBase58(
            allocator,
            owned_spec.signers,
            owned_spec.nonce_authority.?,
        ) orelse return error.MissingNonceAuthoritySigner
    else
        null;
    defer if (nonce_authority_secret_key) |value| allocator.free(value);

    return try client.invocation_spec_json.buildInvocationSpecJson(allocator, .{
        .payer_secret_key = payer_secret_key,
        .additional_signer_secret_keys_json = additional_signer_secret_keys_json,
        .address_lookup_tables_json = address_lookup_tables_json,
        .recent_blockhash = recent_blockhash_base58,
        .nonce_account = nonce_account_base58,
        .nonce_authority_secret_key = nonce_authority_secret_key,
        .instructions_json = instructions_json,
    });
}

fn buildOwnedResolvedInvocationFromOwnedSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedResolvedInvocation {
    var mutable = owned_spec;

    const signer_pubkeys = try allocator.alloc(sdk.Pubkey, mutable.signers.len);
    errdefer allocator.free(signer_pubkeys);
    for (mutable.signers, 0..) |signer, index| {
        signer_pubkeys[index] = signer.public_key;
    }

    const owned_instructions = mutable.owned_instructions;
    mutable.owned_instructions.instructions = &.{};
    const address_lookup_tables = mutable.address_lookup_tables;
    mutable.address_lookup_tables = &.{};
    allocator.free(mutable.signers);
    mutable.signers = &.{};

    return buildOwnedResolvedInvocationFromOwnedParts(.{
        .payer = mutable.payer,
        .signer_pubkeys = signer_pubkeys,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = address_lookup_tables,
        .recent_blockhash = mutable.recent_blockhash,
        .nonce_account = mutable.nonce_account,
        .nonce_authority = mutable.nonce_authority,
    });
}

pub fn cloneOwnedInvocationSpec(
    allocator: Allocator,
    source: *const OwnedInvocationSpec,
) !OwnedInvocationSpec {
    return buildOwnedInvocationSpecFromBorrowedParts(allocator, .{
        .payer = source.payer,
        .signers = source.signers,
        .instructions = source.owned_instructions.instructions,
        .address_lookup_tables = source.address_lookup_tables,
        .recent_blockhash = source.recent_blockhash,
        .nonce_account = source.nonce_account,
        .nonce_authority = source.nonce_authority,
    });
}

pub fn buildInvocationSignerPubkeysFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) ![]sdk.Pubkey {
    const signer_pubkeys = try allocator.alloc(sdk.Pubkey, owned_spec.signers.len);
    errdefer allocator.free(signer_pubkeys);
    for (owned_spec.signers, 0..) |signer, index| {
        signer_pubkeys[index] = signer.public_key;
    }
    return signer_pubkeys;
}

pub fn buildOwnedInstructionsFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !sdk.OwnedInstructions {
    return try buildOwnedInstructionsFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn cloneOwnedResolvedInvocation(
    allocator: Allocator,
    source: *const OwnedResolvedInvocation,
) !OwnedResolvedInvocation {
    return buildOwnedResolvedInvocationFromBorrowedParts(allocator, .{
        .payer = source.payer,
        .signer_pubkeys = source.signer_pubkeys,
        .instructions = source.owned_instructions.instructions,
        .address_lookup_tables = source.address_lookup_tables,
        .recent_blockhash = source.recent_blockhash,
        .nonce_account = source.nonce_account,
        .nonce_authority = source.nonce_authority,
    });
}

pub fn buildOwnedResolvedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedResolvedInvocation {
    const signer_pubkeys = try buildInvocationSignerPubkeysFromOwnedInvocationSpecRef(
        allocator,
        owned_spec,
    );
    errdefer allocator.free(signer_pubkeys);

    var owned_instructions = try sdk.cloneInstructions(
        allocator,
        owned_spec.owned_instructions.instructions,
    );
    errdefer owned_instructions.deinit(allocator);

    const address_lookup_tables = try allocator.alloc(
        sdk.AddressLookupTableAccount,
        owned_spec.address_lookup_tables.len,
    );
    errdefer allocator.free(address_lookup_tables);
    var initialized_tables_len: usize = 0;
    errdefer {
        for (address_lookup_tables[0..initialized_tables_len]) |table| {
            allocator.free(table.addresses);
        }
        allocator.free(address_lookup_tables);
    }
    for (owned_spec.address_lookup_tables, 0..) |table, index| {
        address_lookup_tables[index] = .{
            .account_key = table.account_key,
            .addresses = try allocator.dupe(sdk.Pubkey, table.addresses),
        };
        initialized_tables_len += 1;
    }

    return buildOwnedResolvedInvocationFromOwnedParts(.{
        .payer = owned_spec.payer,
        .signer_pubkeys = signer_pubkeys,
        .owned_instructions = owned_instructions,
        .address_lookup_tables = address_lookup_tables,
        .recent_blockhash = owned_spec.recent_blockhash,
        .nonce_account = owned_spec.nonce_account,
        .nonce_authority = owned_spec.nonce_authority,
    });
}

pub fn buildInvocationAccountsFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationAccounts {
    return try buildInvocationAccountsFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationSummaryFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationSummary {
    return try buildInvocationSummaryFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationPlanFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationPlan {
    return try buildInvocationPlanFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationPreflightFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationPreflight {
    return try buildInvocationPreflightFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationValidationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationValidation {
    return try buildInvocationValidationFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationLookupCoverageFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationLookupCoverage {
    return try buildInvocationLookupCoverageFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationReportFromOwnedInvocationSpecRef(
    allocator: Allocator,
    owned_spec: *const OwnedInvocationSpec,
) !OwnedInvocationReport {
    return try buildInvocationReportFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
}

fn buildOwnedMessageFromOwnedSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !OwnedInvocationMessage {
    var resolved_invocation = try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec);
    defer resolved_invocation.deinit(allocator);

    if (versioned) {
        if (resolved_invocation.recent_blockhash) |recent_blockhash| {
            return .{ .versioned = try client.instructions_invoke.buildOwnedVersionedMessage(allocator, .{
                .payer = resolved_invocation.payer,
                .recent_blockhash = recent_blockhash,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .address_lookup_tables = resolved_invocation.address_lookup_tables,
            }) };
        }

        if (resolved_invocation.nonce_account) |nonce_account| {
            const nonce_account_base58 = try nonce_account.toBase58(allocator);
            defer allocator.free(nonce_account_base58);

            return .{ .versioned = try client.instructions_invoke.buildOwnedVersionedMessageWithBlockhashQuery(rpc, .{
                .payer = resolved_invocation.payer,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .address_lookup_tables = resolved_invocation.address_lookup_tables,
                .blockhash_query = .{ .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = options.blockhash_commitment,
                } },
                .nonce_authority = resolved_invocation.nonce_authority,
            }) };
        }

        return .{ .versioned = try client.instructions_invoke.buildOwnedVersionedMessageWithLatestBlockhash(rpc, .{
            .payer = resolved_invocation.payer,
            .instructions = resolved_invocation.owned_instructions.instructions,
            .address_lookup_tables = resolved_invocation.address_lookup_tables,
            .blockhash_commitment = options.blockhash_commitment,
        }) };
    }

    if (resolved_invocation.recent_blockhash) |recent_blockhash| {
        return .{ .legacy = try client.instructions_invoke.buildOwnedLegacyMessage(allocator, .{
            .payer = resolved_invocation.payer,
            .recent_blockhash = recent_blockhash,
            .instructions = resolved_invocation.owned_instructions.instructions,
        }) };
    }

    if (resolved_invocation.nonce_account) |nonce_account| {
        const nonce_account_base58 = try nonce_account.toBase58(allocator);
        defer allocator.free(nonce_account_base58);

        return .{ .legacy = try client.instructions_invoke.buildOwnedLegacyMessageWithBlockhashQuery(rpc, .{
            .payer = resolved_invocation.payer,
            .instructions = resolved_invocation.owned_instructions.instructions,
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = options.blockhash_commitment,
            } },
            .nonce_authority = resolved_invocation.nonce_authority,
        }) };
    }

    return .{ .legacy = try client.instructions_invoke.buildOwnedLegacyMessageWithLatestBlockhash(rpc, .{
        .payer = resolved_invocation.payer,
        .instructions = resolved_invocation.owned_instructions.instructions,
        .blockhash_commitment = options.blockhash_commitment,
    }) };
}

fn buildSignedTransactionFromOwnedSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !SignedInvocationTransaction {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    const transaction = prepared.transaction;
    prepared.report.deinit(allocator);
    prepared.resolved_invocation.deinit(allocator);
    prepared.accounts.deinit(allocator);
    return transaction;
}

pub fn buildOwnedResolvedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedResolvedInvocation {
    return try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec);
}

pub fn buildOwnedResolvedInvocationFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedResolvedInvocation {
    return try buildOwnedResolvedInvocationFromOwnedSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

pub fn buildOwnedInstructionsFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !sdk.OwnedInstructions {
    var resolved = try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec);
    const owned_instructions = resolved.owned_instructions;
    resolved.owned_instructions.instructions = &.{};
    resolved.deinit(allocator);
    return owned_instructions;
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

pub fn buildInvocationSignerPubkeysFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) ![]sdk.Pubkey {
    var resolved = try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec);
    const signer_pubkeys = resolved.signer_pubkeys;
    resolved.signer_pubkeys = &.{};
    resolved.deinit(allocator);
    return signer_pubkeys;
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

pub fn buildInvocationAccountsFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationAccounts {
    var resolved = try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec);
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

fn buildInvocationSummaryFromResolved(
    allocator: Allocator,
    resolved_input: OwnedResolvedInvocation,
) !OwnedInvocationSummary {
    var resolved = resolved_input;
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
    defer resolved.deinit(allocator);

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

pub fn buildInvocationSummaryFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationSummary {
    return try buildInvocationSummaryFromResolved(allocator, resolved);
}

pub fn buildInvocationSummaryFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationSummary {
    return try buildInvocationSummaryFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationSummaryFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationSummary {
    return try buildInvocationSummaryFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
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

fn buildInvocationPlanFromResolved(
    allocator: Allocator,
    resolved_input: OwnedResolvedInvocation,
) !OwnedInvocationPlan {
    var resolved = resolved_input;
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
    defer resolved.deinit(allocator);

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

pub fn buildInvocationPlanFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationPlan {
    return try buildInvocationPlanFromResolved(allocator, resolved);
}

pub fn buildInvocationPlanFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationPlan {
    return try buildInvocationPlanFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationPlanFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationPlan {
    return try buildInvocationPlanFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

fn buildInvocationPreflightFromResolved(
    allocator: Allocator,
    resolved_input: OwnedResolvedInvocation,
) !OwnedInvocationPreflight {
    var resolved = resolved_input;
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
    defer resolved.deinit(allocator);

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

pub fn buildInvocationPreflightFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationPreflight {
    return try buildInvocationPreflightFromResolved(allocator, resolved);
}

pub fn buildInvocationPreflightFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationPreflight {
    return try buildInvocationPreflightFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationPreflightFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationPreflight {
    return try buildInvocationPreflightFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

fn buildInvocationValidationFromResolved(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationValidation {
    var preflight = try buildInvocationPreflightFromResolved(allocator, resolved);
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

pub fn buildInvocationValidationFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationValidation {
    return try buildInvocationValidationFromResolved(allocator, resolved);
}

pub fn buildInvocationValidationFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationValidation {
    return try buildInvocationValidationFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationValidationFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationValidation {
    return try buildInvocationValidationFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

fn buildInvocationLookupCoverageFromResolved(
    allocator: Allocator,
    resolved_input: OwnedResolvedInvocation,
) !OwnedInvocationLookupCoverage {
    var resolved = resolved_input;
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

    defer resolved.deinit(allocator);
    return .{
        .lookup_table_pubkeys = lookup_table_pubkeys,
        .lookup_table_address_pubkeys = try lookup_table_address_pubkeys.toOwnedSlice(allocator),
        .candidate_pubkeys = try candidate_pubkeys.toOwnedSlice(allocator),
        .covered_pubkeys = try covered_pubkeys.toOwnedSlice(allocator),
        .uncovered_pubkeys = try uncovered_pubkeys.toOwnedSlice(allocator),
        .fully_covered = covered_pubkeys.items.len == candidate_pubkeys.items.len,
    };
}

pub fn buildInvocationLookupCoverageFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationLookupCoverage {
    return try buildInvocationLookupCoverageFromResolved(allocator, resolved);
}

pub fn buildInvocationLookupCoverageFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationLookupCoverage {
    return try buildInvocationLookupCoverageFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationLookupCoverageFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationLookupCoverage {
    return try buildInvocationLookupCoverageFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

fn buildInvocationReportFromResolved(
    allocator: Allocator,
    resolved_input: OwnedResolvedInvocation,
) !OwnedInvocationReport {
    var resolved = resolved_input;
    defer resolved.deinit(allocator);

    var summary = try buildInvocationSummaryFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved),
    );
    errdefer summary.deinit(allocator);

    var plan = try buildInvocationPlanFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved),
    );
    errdefer plan.deinit(allocator);

    var preflight = try buildInvocationPreflightFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved),
    );
    errdefer preflight.deinit(allocator);

    var validation = try buildInvocationValidationFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved),
    );
    errdefer validation.deinit(allocator);

    var lookup_coverage = try buildInvocationLookupCoverageFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved),
    );
    errdefer lookup_coverage.deinit(allocator);

    return .{
        .summary = summary,
        .plan = plan,
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

pub fn buildInvocationReportFromOwnedResolvedInvocation(
    allocator: Allocator,
    resolved: OwnedResolvedInvocation,
) !OwnedInvocationReport {
    return try buildInvocationReportFromResolved(allocator, resolved);
}

pub fn buildInvocationReportFromOwnedInvocationSpec(
    allocator: Allocator,
    owned_spec: OwnedInvocationSpec,
) !OwnedInvocationReport {
    return try buildInvocationReportFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedSpec(allocator, owned_spec),
    );
}

pub fn buildInvocationReportFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationReport {
    return try buildInvocationReportFromResolved(
        allocator,
        try buildOwnedResolvedInvocationFromInvocationSpecJson(
            allocator,
            family,
            invocation_spec_json,
        ),
    );
}

pub fn buildInvocationDiagnosticsFromReport(
    allocator: Allocator,
    report: *const OwnedInvocationReport,
) !OwnedInvocationDiagnostics {
    var diagnostics: std.ArrayList(InvocationDiagnostic) = .empty;
    errdefer diagnostics.deinit(allocator);

    if (report.has_missing_required_signers) {
        try diagnostics.append(allocator, .{
            .severity = .err,
            .code = .missing_required_signers,
        });
    }
    if (report.has_extra_signers) {
        try diagnostics.append(allocator, .{
            .severity = .warning,
            .code = .extra_signers,
        });
    }
    if (report.has_duplicate_signers) {
        try diagnostics.append(allocator, .{
            .severity = .err,
            .code = .duplicate_signers,
        });
    }
    if (report.has_duplicate_lookup_tables) {
        try diagnostics.append(allocator, .{
            .severity = .err,
            .code = .duplicate_lookup_tables,
        });
    }
    if (report.usesLookupTables() and !report.has_full_lookup_coverage) {
        try diagnostics.append(allocator, .{
            .severity = .warning,
            .code = .incomplete_lookup_coverage,
        });
    }
    if (report.uses_durable_nonce) {
        try diagnostics.append(allocator, .{
            .severity = .info,
            .code = .durable_nonce,
        });
    }

    return .{
        .items = try diagnostics.toOwnedSlice(allocator),
    };
}

pub fn buildInvocationDiagnosticsFromPreferredExecutionReport(
    allocator: Allocator,
    report: *const PreferredInvocationExecutionReport,
) !OwnedInvocationDiagnostics {
    var diagnostics = try buildInvocationDiagnosticsFromReport(allocator, &report.report);
    defer diagnostics.deinit(allocator);

    var items: std.ArrayList(InvocationDiagnostic) = .empty;
    errdefer items.deinit(allocator);
    try items.appendSlice(allocator, diagnostics.items);
    if (report.selected_mode == null) {
        try items.append(allocator, .{
            .severity = .err,
            .code = .no_buildable_mode,
        });
    } else if (report.used_fallback) {
        try items.append(allocator, .{
            .severity = .warning,
            .code = .mode_fallback,
        });
    }

    return .{
        .items = try items.toOwnedSlice(allocator),
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

pub fn buildPreferredOwnedMessageExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredOwnedMessageExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredOwnedMessageExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredMessageBytesExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredMessageBytesExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredMessageBase64ExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredMessageBase64ExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredSignedTransactionExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredSignedTransactionExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredSignedTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredTransactionBase64ExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredTransactionBase64ExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredResolvedInvocationExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredResolvedInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredInvocationAnalysisFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredInvocationAnalysis {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredInvocationAnalysisFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredPreparedSignedTransaction {
    return buildPreferredPreparedSignedTransactionFromOwnedInvocationSpec(
        allocator,
        rpc,
        try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json),
        options,
    );
}

pub fn buildPreferredPreparedInvocationFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredPreparedInvocation {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);

    return buildPreferredPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn buildPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !PreparedInvocation {
    return try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildPreparedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !PreparedInvocation {
    return try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !PreparedInvocation {
    return try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
}

pub fn buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !PreparedInvocation {
    var mutable = owned_spec;
    const signers = mutable.signers;
    mutable.signers = &.{};
    errdefer allocator.free(signers);
    const nonce_authority = mutable.nonce_authority;

    var resolved_invocation = try buildOwnedResolvedInvocationFromOwnedSpec(allocator, mutable);
    errdefer resolved_invocation.deinit(allocator);

    var report = try buildInvocationReportFromResolved(
        allocator,
        try cloneOwnedResolvedInvocation(allocator, &resolved_invocation),
    );
    errdefer report.deinit(allocator);

    var accounts = try buildOwnedInvocationAccountsFromResolved(allocator, &resolved_invocation);
    errdefer accounts.deinit(allocator);

    const transaction: SignedInvocationTransaction = if (versioned) blk: {
        if (resolved_invocation.recent_blockhash) |recent_blockhash| {
            break :blk .{ .versioned = try client.instructions_invoke.buildSignedVersionedTransaction(allocator, .{
                .payer = resolved_invocation.payer,
                .recent_blockhash = recent_blockhash,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .address_lookup_tables = resolved_invocation.address_lookup_tables,
                .signers = signers,
            }) };
        }

        if (resolved_invocation.nonce_account) |nonce_account| {
            const nonce_account_base58 = try nonce_account.toBase58(allocator);
            defer allocator.free(nonce_account_base58);

            break :blk .{ .versioned = try client.instructions_invoke.buildSignedVersionedTransactionWithBlockhashQuery(rpc, .{
                .payer = resolved_invocation.payer,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .address_lookup_tables = resolved_invocation.address_lookup_tables,
                .signers = signers,
                .blockhash_query = .{ .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = options.blockhash_commitment,
                } },
                .nonce_authority = nonce_authority,
            }) };
        }

        break :blk .{ .versioned = try client.instructions_invoke.buildSignedVersionedTransactionWithLatestBlockhash(rpc, .{
            .payer = resolved_invocation.payer,
            .instructions = resolved_invocation.owned_instructions.instructions,
            .address_lookup_tables = resolved_invocation.address_lookup_tables,
            .signers = signers,
            .blockhash_commitment = options.blockhash_commitment,
        }) };
    } else blk: {
        if (resolved_invocation.recent_blockhash) |recent_blockhash| {
            break :blk .{ .legacy = try client.instructions_invoke.buildSignedLegacyTransaction(allocator, .{
                .payer = resolved_invocation.payer,
                .recent_blockhash = recent_blockhash,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .signers = signers,
            }) };
        }

        if (resolved_invocation.nonce_account) |nonce_account| {
            const nonce_account_base58 = try nonce_account.toBase58(allocator);
            defer allocator.free(nonce_account_base58);

            break :blk .{ .legacy = try client.instructions_invoke.buildSignedLegacyTransactionWithBlockhashQuery(rpc, .{
                .payer = resolved_invocation.payer,
                .instructions = resolved_invocation.owned_instructions.instructions,
                .signers = signers,
                .blockhash_query = .{ .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = options.blockhash_commitment,
                } },
                .nonce_authority = nonce_authority,
            }) };
        }

        break :blk .{ .legacy = try client.instructions_invoke.buildSignedLegacyTransactionWithLatestBlockhash(rpc, .{
            .payer = resolved_invocation.payer,
            .instructions = resolved_invocation.owned_instructions.instructions,
            .signers = signers,
            .blockhash_commitment = options.blockhash_commitment,
        }) };
    };

    allocator.free(signers);

    return .{
        .mode = if (versioned) .versioned else .legacy,
        .report = report,
        .resolved_invocation = resolved_invocation,
        .accounts = accounts,
        .transaction = transaction,
    };
}

pub fn buildInvocationModeReportFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !InvocationModeReport {
    var report = try buildInvocationReportFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    defer report.deinit(allocator);

    const legacy_buildable = blk: {
        const encoded = buildLegacyTransactionBase64FromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            owned_spec,
            options,
        ) catch break :blk false;
        allocator.free(encoded);
        break :blk true;
    };

    const versioned_buildable = blk: {
        const encoded = buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            owned_spec,
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

pub fn buildPreferredInvocationReportFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !OwnedPreferredInvocationReport {
    return .{
        .mode_report = try buildInvocationModeReportFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            options,
        ),
        .report = try buildInvocationReportFromOwnedInvocationSpec(
            allocator,
            try cloneOwnedInvocationSpec(allocator, owned_spec),
        ),
    };
}

pub fn buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredInvocationExecutionReport {
    const mode_report = try buildInvocationModeReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options.build,
    );

    var report = try buildInvocationReportFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    errdefer report.deinit(allocator);

    const requested_mode_buildable = if (options.mode.preferred_mode) |requested_mode|
        switch (requested_mode) {
            .legacy => mode_report.legacy_buildable,
            .versioned => mode_report.versioned_buildable,
        }
    else
        false;

    const selected_mode = blk: {
        if (options.mode.preferred_mode) |requested_mode| {
            if (requested_mode_buildable) break :blk requested_mode;
            if (!options.mode.allow_fallback) break :blk null;
        }
        break :blk mode_report.preferred_mode;
    };

    return .{
        .mode_report = mode_report,
        .report = report,
        .requested_mode = options.mode.preferred_mode,
        .selected_mode = selected_mode,
        .requested_mode_buildable = requested_mode_buildable,
        .used_fallback = if (options.mode.preferred_mode) |requested_mode|
            selected_mode != null and selected_mode.? != requested_mode
        else
            false,
        .can_execute_selected_mode = selected_mode != null and report.can_execute,
    };
}

pub fn buildPreferredInvocationAnalysisFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredInvocationAnalysis {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    var resolved_invocation = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    errdefer resolved_invocation.deinit(allocator);

    var accounts = try buildInvocationAccountsFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    errdefer accounts.deinit(allocator);

    return .{
        .execution_report = execution_report,
        .resolved_invocation = resolved_invocation,
        .accounts = accounts,
    };
}

pub fn buildPreferredPreparedSignedTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredPreparedSignedTransaction {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    var resolved_invocation = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    errdefer resolved_invocation.deinit(allocator);

    var accounts = try buildInvocationAccountsFromOwnedInvocationSpec(
        allocator,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
    );
    errdefer accounts.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;

    return .{
        .execution_report = execution_report,
        .resolved_invocation = resolved_invocation,
        .accounts = accounts,
        .transaction = try buildSignedTransactionFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredPreparedInvocation {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const selected_mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;

    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        selected_mode == .versioned,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options.build,
    );
    errdefer prepared.deinit(allocator);
    prepared.report.deinit(allocator);
    prepared.report = execution_report.report;

    return .{
        .mode_report = execution_report.mode_report,
        .requested_mode = execution_report.requested_mode,
        .selected_mode = selected_mode,
        .requested_mode_buildable = execution_report.requested_mode_buildable,
        .used_fallback = execution_report.used_fallback,
        .can_execute_selected_mode = execution_report.can_execute_selected_mode,
        .prepared = prepared,
    };
}

pub fn writePreferredInvocationAnalysisTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !void {
    var analysis = try buildPreferredInvocationAnalysisFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer analysis.deinit(allocator);
    try writePreferredInvocationAnalysisText(writer, allocator, &analysis);
}

pub fn allocPreferredInvocationAnalysisJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var analysis = try buildPreferredInvocationAnalysisFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer analysis.deinit(allocator);
    return try allocPreferredInvocationAnalysisJson(allocator, &analysis);
}

pub fn writePreferredPreparedInvocationTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !void {
    var prepared = try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    try writePreferredPreparedInvocationText(writer, allocator, &prepared);
}

pub fn allocPreferredPreparedInvocationJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var prepared = try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    return try allocPreferredPreparedInvocationJson(allocator, &prepared);
}

pub fn writePreparedInvocationTextFromOwnedInvocationSpecRef(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !void {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    try writePreparedInvocationText(writer, allocator, &prepared);
}

pub fn allocPreparedInvocationJsonFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    return try allocPreparedInvocationJson(allocator, &prepared);
}

pub fn writePreparedInvocationTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !void {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    try writePreparedInvocationText(writer, allocator, &prepared);
}

pub fn allocPreparedInvocationJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer prepared.deinit(allocator);
    return try allocPreparedInvocationJson(allocator, &prepared);
}

pub fn writeSentPreparedInvocationTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SendInvocationSpecOptions,
    confirmed: bool,
) !void {
    var sent = try sendOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer sent.deinit(allocator);
    try writeSentPreparedInvocationText(writer, allocator, &sent, confirmed);
}

pub fn allocSentPreparedInvocationJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SendInvocationSpecOptions,
) ![]u8 {
    var sent = try sendOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer sent.deinit(allocator);
    return try allocSentPreparedInvocationJson(allocator, &sent);
}

pub fn writeSimulatedPreparedInvocationTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SimulateInvocationSpecOptions,
) !void {
    var simulated = try simulateOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer simulated.deinit(allocator);
    try writeSimulatedPreparedInvocationText(writer, allocator, &simulated);
}

pub fn allocSimulatedPreparedInvocationJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SimulateInvocationSpecOptions,
) ![]u8 {
    var simulated = try simulateOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer simulated.deinit(allocator);
    return try allocSimulatedPreparedInvocationJson(allocator, &simulated);
}

pub fn writePreparedInvocationFeeTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: GetFeeForInvocationSpecOptions,
) !void {
    var fee_result = try getFeeForOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer fee_result.deinit(allocator);
    try writePreparedInvocationFeeText(writer, allocator, &fee_result);
}

pub fn allocPreparedInvocationFeeJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: GetFeeForInvocationSpecOptions,
) ![]u8 {
    var fee_result = try getFeeForOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        versioned,
        owned_spec,
        options,
    );
    defer fee_result.deinit(allocator);
    return try allocPreparedInvocationFeeJson(allocator, &fee_result);
}

pub fn buildOwnedLegacyMessageFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedLegacyMessage {
    const message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        false,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    return message.legacy;
}

pub fn buildOwnedLegacyMessageFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedLegacyMessage {
    return buildOwnedLegacyMessageFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        false,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    defer message.deinit(allocator);
    return try message.serialize(allocator);
}

pub fn buildLegacyMessageBytesFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        false,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    defer message.deinit(allocator);
    return try message.toBase64(allocator);
}

pub fn buildLegacyMessageBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedLegacyTransactionFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !sdk.SignedLegacyTransaction {
    const transaction = try buildSignedTransactionFromOwnedSpecWithOptions(
        allocator,
        rpc,
        false,
        owned_spec,
        options,
    );
    return transaction.legacy;
}

pub fn buildSignedLegacyTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedLegacyTransaction {
    return buildSignedLegacyTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyTransactionBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var transaction = try buildSignedTransactionFromOwnedSpecWithOptions(
        allocator,
        rpc,
        false,
        owned_spec,
        options,
    );
    defer transaction.deinit(allocator);
    return try transaction.toBase64(allocator);
}

pub fn buildLegacyTransactionBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyTransactionBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedVersionedMessageFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedVersionedMessageV0 {
    const message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        true,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    return message.versioned;
}

pub fn buildOwnedVersionedMessageFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedVersionedMessageV0 {
    return buildOwnedVersionedMessageFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBytesFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        true,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    defer message.deinit(allocator);
    return try message.serialize(allocator);
}

pub fn buildVersionedMessageBytesFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBytesFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var message = try buildOwnedMessageFromOwnedSpecWithOptions(
        allocator,
        rpc,
        true,
        try cloneOwnedInvocationSpec(allocator, owned_spec),
        options,
    );
    defer message.deinit(allocator);
    return try message.toBase64(allocator);
}

pub fn buildVersionedMessageBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedVersionedTransactionFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !sdk.SignedVersionedTransaction {
    const transaction = try buildSignedTransactionFromOwnedSpecWithOptions(
        allocator,
        rpc,
        true,
        owned_spec,
        options,
    );
    return transaction.versioned;
}

pub fn buildSignedVersionedTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedVersionedTransaction {
    return buildSignedVersionedTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    var transaction = try buildSignedTransactionFromOwnedSpecWithOptions(
        allocator,
        rpc,
        true,
        owned_spec,
        options,
    );
    defer transaction.deinit(allocator);
    return try transaction.toBase64(allocator);
}

pub fn buildVersionedTransactionBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedMessageFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !OwnedInvocationMessage {
    return if (versioned)
        .{ .versioned = try buildOwnedVersionedMessageFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options) }
    else
        .{ .legacy = try buildOwnedLegacyMessageFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options) };
}

pub fn buildOwnedMessageFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !OwnedInvocationMessage {
    return buildOwnedMessageFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBytesFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBytesFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options)
    else
        try buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options);
}

pub fn buildMessageBytesFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBytesFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBase64FromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options)
    else
        try buildLegacyMessageBase64FromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options);
}

pub fn buildMessageBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedTransactionFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) !SignedInvocationTransaction {
    return if (versioned)
        .{ .versioned = try buildSignedVersionedTransactionFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options) }
    else
        .{ .legacy = try buildSignedLegacyTransactionFromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options) };
}

pub fn buildSignedTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !SignedInvocationTransaction {
    return buildSignedTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildTransactionBase64FromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options)
    else
        try buildLegacyTransactionBase64FromOwnedInvocationSpecWithOptions(allocator, rpc, owned_spec, options);
}

pub fn buildTransactionBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildTransactionBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn sendTransactionFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendInvocationSpecOptions,
) ![]const u8 {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = options.blockhash_commitment },
    );
    defer prepared.deinit(allocator);

    return try sendPreparedInvocation(
        rpc,
        &prepared,
        options.send_transaction_options,
    );
}

pub fn sendTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) ![]const u8 {
    return sendTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn simulateTransactionFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulateInvocationSpecOptions,
) !client.SimulatedTransaction {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = options.blockhash_commitment },
    );
    defer prepared.deinit(allocator);

    return try simulatePreparedInvocation(
        rpc,
        &prepared,
        options.simulate_options,
    );
}

pub fn simulateTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !client.SimulatedTransaction {
    return simulateTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn sendAndConfirmInvocationFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = options.blockhash_commitment },
    );
    defer prepared.deinit(allocator);

    return try sendAndConfirmPreparedInvocation(
        rpc,
        &prepared,
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
    timeout_ms: ?u64,
    poll_ms: ?u64,
    search_transaction_history: bool,
) ![]const u8 {
    return sendAndConfirmInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{
            .blockhash_commitment = blockhash_commitment,
            .timeout_ms = timeout_ms,
            .poll_ms = poll_ms,
            .search_transaction_history = search_transaction_history,
        },
    );
}

pub fn sendAndConfirmInvocationFromOwnedInvocationSpecWithSpinnerOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = options.blockhash_commitment },
    );
    defer prepared.deinit(allocator);

    return try sendAndConfirmPreparedInvocationWithSpinner(
        allocator,
        rpc,
        &prepared,
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms orelse sdk.poll_for_signature_confirmation_timeout_ms,
        options.poll_ms orelse sdk.signature_poll_interval_ms,
    );
}

pub fn getFeeForInvocationSpecFromOwnedInvocationSpecWithOptions(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForInvocationSpecOptions,
) !client.FeeForMessage {
    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = options.blockhash_commitment },
    );
    defer prepared.deinit(allocator);

    return try getFeeForPreparedInvocation(
        rpc,
        &prepared,
        options.commitment,
    );
}

pub fn getFeeForInvocationSpecFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    blockhash_commitment: ?client.Commitment,
) !client.FeeForMessage {
    return getFeeForInvocationSpecFromOwnedInvocationSpecWithOptions(
        allocator,
        rpc,
        versioned,
        owned_spec,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn writePreferredSignatureExecutionResultTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
    confirmed: bool,
) !void {
    var result = try sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    try writePreferredSignatureExecutionResultText(writer, &result, confirmed);
}

pub fn allocPreferredSignatureExecutionResultJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
) ![]u8 {
    var result = try sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    return try allocPreferredSignatureExecutionResultJson(allocator, &result);
}

pub fn writePreferredSimulationExecutionResultTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) !void {
    var result = try simulatePreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    try writePreferredSimulationExecutionSummaryText(writer, &result);
}

pub fn allocPreferredSimulationExecutionResultJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) ![]u8 {
    var result = try simulatePreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    return try allocPreferredSimulationExecutionResultJson(allocator, &result);
}

pub fn writePreferredFeeExecutionResultTextFromOwnedInvocationSpec(
    writer: *std.Io.Writer,
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) !void {
    var result = try getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    try writePreferredFeeExecutionResultText(writer, &result);
}

pub fn allocPreferredFeeExecutionResultJsonFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) ![]u8 {
    var result = try getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    defer result.deinit(allocator);
    return try allocPreferredFeeExecutionResultJson(allocator, &result);
}

pub fn buildPreferredOwnedMessageExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredOwnedMessageExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .message = try buildOwnedMessageFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredMessageBytesExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .bytes = try buildMessageBytesFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredMessageBase64ExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .bytes = try buildMessageBase64FromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredSignedTransactionExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredSignedTransactionExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .transaction = try buildSignedTransactionFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredTransactionBase64ExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .bytes = try buildTransactionBase64FromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.build,
        ),
    };
}

pub fn buildPreferredResolvedInvocationExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredResolvedInvocationExecutionResult {
    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    errdefer execution_report.deinit(allocator);

    return .{
        .execution_report = execution_report,
        .resolved_invocation = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
            allocator,
            try cloneOwnedInvocationSpec(allocator, owned_spec),
        ),
    };
}

pub fn buildPreferredOwnedMessageFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredOwnedMessageResult {
    var result = try buildPreferredOwnedMessageExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .message = result.message };
}

pub fn buildPreferredMessageBytesFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var result = try buildPreferredMessageBytesExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .bytes = result.bytes };
}

pub fn buildPreferredMessageBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var result = try buildPreferredMessageBase64ExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .bytes = result.bytes };
}

pub fn buildPreferredSignedTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredSignedTransactionResult {
    var result = try buildPreferredSignedTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .transaction = result.transaction };
}

pub fn buildPreferredTransactionBase64FromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var result = try buildPreferredTransactionBase64ExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .bytes = result.bytes };
}

pub fn sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var report_spec = try cloneOwnedInvocationSpec(allocator, owned_spec);
    defer report_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        &report_spec,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.send.blockhash_commitment },
        },
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .signature = try sendTransactionFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.send,
        ),
    };
}

pub fn simulatePreferredTransactionExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) !PreferredSimulationExecutionResult {
    var report_spec = try cloneOwnedInvocationSpec(allocator, owned_spec);
    defer report_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        &report_spec,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.simulate.blockhash_commitment },
        },
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .simulation = try simulateTransactionFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.simulate,
        ),
    };
}

pub fn sendAndConfirmPreferredTransactionExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var report_spec = try cloneOwnedInvocationSpec(allocator, owned_spec);
    defer report_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        &report_spec,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
        },
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .signature = try sendAndConfirmInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.send_and_confirm,
        ),
    };
}

pub fn sendAndConfirmPreferredTransactionExecutionResultWithSpinnerFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var report_spec = try cloneOwnedInvocationSpec(allocator, owned_spec);
    defer report_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        &report_spec,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
        },
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .signature = try sendAndConfirmInvocationFromOwnedInvocationSpecWithSpinnerOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.send_and_confirm,
        ),
    };
}

pub fn getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredFeeExecutionResult {
    var report_spec = try cloneOwnedInvocationSpec(allocator, owned_spec);
    defer report_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        &report_spec,
        .{
            .mode = options.mode,
            .build = .{ .blockhash_commitment = options.fee.blockhash_commitment },
        },
    );
    errdefer execution_report.deinit(allocator);

    const mode = execution_report.selected_mode orelse return error.NoBuildableInvocationMode;
    return .{
        .execution_report = execution_report,
        .fee = try getFeeForInvocationSpecFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            mode == .versioned,
            owned_spec,
            options.fee,
        ),
    };
}

pub fn sendPreferredTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var result = try sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .signature = result.signature };
}

pub fn simulatePreferredTransactionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) !PreferredSimulationResult {
    var result = try simulatePreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .simulation = result.simulation };
}

pub fn sendAndConfirmPreferredInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var result = try sendAndConfirmPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .signature = result.signature };
}

pub fn sendAndConfirmPreferredInvocationWithSpinnerFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var result = try sendAndConfirmPreferredTransactionExecutionResultWithSpinnerFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .signature = result.signature };
}

pub fn getFeeForPreferredInvocationSpecFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredFeeResult {
    var result = try getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        owned_spec,
        options,
    );
    const mode = result.execution_report.selected_mode orelse {
        result.deinit(allocator);
        return error.NoBuildableInvocationMode;
    };
    result.execution_report.deinit(allocator);
    return .{ .mode = mode, .fee = result.fee };
}

pub fn sendOwnedPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SendInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
    );
}

pub fn sendPreparedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
    );
}

pub fn simulateOwnedPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SimulateInvocationSpecOptions,
) !SimulatedPreparedInvocation {
    return try simulateOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.simulate_options,
    );
}

pub fn simulatePreparedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulateInvocationSpecOptions,
) !SimulatedPreparedInvocation {
    return try simulateOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.simulate_options,
    );
}

pub fn sendAndConfirmOwnedPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendAndConfirmOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmPreparedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendAndConfirmOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmOwnedPreparedInvocationWithSpinnerFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendAndConfirmOwnedPreparedInvocationWithSpinner(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn sendAndConfirmPreparedInvocationWithSpinnerFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmInvocationSpecOptions,
) !SentPreparedInvocation {
    return try sendAndConfirmOwnedPreparedInvocationWithSpinner(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.send_transaction_options,
        options.commitment,
        options.search_transaction_history,
        options.timeout_ms,
        options.poll_interval_ms,
    );
}

pub fn getFeeForOwnedPreparedInvocationFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: OwnedInvocationSpec,
    options: GetFeeForInvocationSpecOptions,
) !PreparedInvocationFee {
    return try getFeeForOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.commitment,
    );
}

pub fn getFeeForPreparedInvocationFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    versioned: bool,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForInvocationSpecOptions,
) !PreparedInvocationFee {
    return try getFeeForOwnedPreparedInvocation(
        allocator,
        rpc,
        try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
            allocator,
            rpc,
            versioned,
            owned_spec,
            .{ .blockhash_commitment = options.blockhash_commitment },
        ),
        options.commitment,
    );
}

pub fn sendOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send.blockhash_commitment },
            },
        ),
        options.send.send_transaction_options,
    );
}

pub fn simulateOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) !SimulatedPreferredPreparedExecution {
    return try simulateOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.simulate.blockhash_commitment },
            },
        ),
        options.simulate.simulate_options,
    );
}

pub fn sendAndConfirmOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendAndConfirmOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
            },
        ),
        options.send_and_confirm.send_transaction_options,
        options.send_and_confirm.commitment,
        options.send_and_confirm.search_transaction_history,
        options.send_and_confirm.timeout_ms,
        options.send_and_confirm.poll_interval_ms,
    );
}

pub fn sendAndConfirmOwnedPreferredPreparedExecutionWithSpinnerFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendAndConfirmOwnedPreferredPreparedExecutionWithSpinner(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
            },
        ),
        options.send_and_confirm.send_transaction_options,
        options.send_and_confirm.commitment,
        options.send_and_confirm.search_transaction_history,
        options.send_and_confirm.timeout_ms,
        options.send_and_confirm.poll_interval_ms,
    );
}

pub fn getFeeForOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredPreparedExecutionFee {
    return try getFeeForOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.fee.commitment },
            },
        ),
        options.fee.commitment,
    );
}

pub fn sendPreferredPreparedExecutionFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send.blockhash_commitment },
            },
        ),
        options.send.send_transaction_options,
    );
}

pub fn simulatePreferredPreparedExecutionFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SimulatePreferredInvocationSpecOptions,
) !SimulatedPreferredPreparedExecution {
    return try simulateOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.simulate.blockhash_commitment },
            },
        ),
        options.simulate.simulate_options,
    );
}

pub fn sendAndConfirmPreferredPreparedExecutionFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendAndConfirmOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
            },
        ),
        options.send_and_confirm.send_transaction_options,
        options.send_and_confirm.commitment,
        options.send_and_confirm.search_transaction_history,
        options.send_and_confirm.timeout_ms,
        options.send_and_confirm.poll_interval_ms,
    );
}

pub fn sendAndConfirmPreferredPreparedExecutionWithSpinnerFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !SentPreferredPreparedExecution {
    return try sendAndConfirmOwnedPreferredPreparedExecutionWithSpinner(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.send_and_confirm.blockhash_commitment },
            },
        ),
        options.send_and_confirm.send_transaction_options,
        options.send_and_confirm.commitment,
        options.send_and_confirm.search_transaction_history,
        options.send_and_confirm.timeout_ms,
        options.send_and_confirm.poll_interval_ms,
    );
}

pub fn getFeeForPreferredPreparedExecutionFromOwnedInvocationSpecRef(
    allocator: Allocator,
    rpc: anytype,
    owned_spec: *const OwnedInvocationSpec,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredPreparedExecutionFee {
    return try getFeeForOwnedPreferredPreparedExecution(
        allocator,
        rpc,
        try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
            allocator,
            rpc,
            owned_spec,
            .{
                .mode = options.mode,
                .build = .{ .blockhash_commitment = options.fee.commitment },
            },
        ),
        options.fee.commitment,
    );
}

pub fn buildPreparedInvocationFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !PreparedInvocation {
    var report = try buildInvocationReportFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer report.deinit(allocator);

    var resolved_invocation = try buildOwnedResolvedInvocationFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer resolved_invocation.deinit(allocator);

    var accounts = try buildInvocationAccountsFromInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    errdefer accounts.deinit(allocator);

    return .{
        .mode = if (versioned) .versioned else .legacy,
        .report = report,
        .resolved_invocation = resolved_invocation,
        .accounts = accounts,
        .transaction = try buildSignedTransactionFromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            versioned,
            invocation_spec_json,
            options,
        ),
    };
}

pub fn sendPreparedInvocation(
    rpc: anytype,
    prepared: *const PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionTyped(signed, options),
        .versioned => |signed| try rpc.sendVersionedTransactionTyped(signed, options),
    };
}

pub fn simulatePreparedInvocation(
    rpc: anytype,
    prepared: *const PreparedInvocation,
    options: ?rpc_types.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.simulateTransactionTyped(signed, options),
        .versioned => |signed| try rpc.simulateVersionedTransactionTyped(signed, options),
    };
}

pub fn sendAndConfirmPreparedInvocation(
    rpc: anytype,
    prepared: *const PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionAndConfirmTyped(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
        .versioned => |signed| try rpc.sendAndConfirmVersionedTransactionTyped(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendAndConfirmPreparedInvocationWithSpinner(
    rpc: anytype,
    prepared: *const PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionAndConfirmTypedWithSpinner(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
        .versioned => |signed| try rpc.sendAndConfirmVersionedTransactionTypedWithSpinner(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendOwnedPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
) !SentPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendPreparedInvocation(rpc, &owned, options),
    };
}

pub fn simulateOwnedPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreparedInvocation,
    options: ?rpc_types.SimulateTransactionOptions,
) !SimulatedPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .simulation = try simulatePreparedInvocation(rpc, &owned, options),
    };
}

pub fn sendAndConfirmOwnedPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendAndConfirmPreparedInvocation(
            rpc,
            &owned,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendAndConfirmOwnedPreparedInvocationWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendAndConfirmPreparedInvocationWithSpinner(
            rpc,
            &owned,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn getFeeForPreparedInvocation(
    rpc: anytype,
    prepared: *const PreparedInvocation,
    commitment: ?client.Commitment,
) !rpc_types.FeeForMessage {
    return switch (prepared.transaction) {
        .legacy => |signed| blk: {
            const encoded_message = try sdk.encodeBase64(rpc.allocator, signed.message_bytes);
            defer rpc.allocator.free(encoded_message);
            break :blk try rpc.getFeeForMessage(encoded_message, commitment);
        },
        .versioned => |signed| blk: {
            const encoded_message = try sdk.encodeBase64(rpc.allocator, signed.message_bytes);
            defer rpc.allocator.free(encoded_message);
            break :blk try rpc.getFeeForMessage(encoded_message, commitment);
        },
    };
}

pub fn getFeeForOwnedPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreparedInvocation,
    commitment: ?client.Commitment,
) !PreparedInvocationFee {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .fee = try getFeeForPreparedInvocation(rpc, &owned, commitment),
    };
}

pub fn sendOwnedPreferredPreparedExecution(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
) !SentPreferredPreparedExecution {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try owned.send(rpc, options),
    };
}

pub fn simulateOwnedPreferredPreparedExecution(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedInvocation,
    options: ?rpc_types.SimulateTransactionOptions,
) !SimulatedPreferredPreparedExecution {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .simulation = try owned.simulate(rpc, options),
    };
}

pub fn sendAndConfirmOwnedPreferredPreparedExecution(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreferredPreparedExecution {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try owned.sendAndConfirm(
            rpc,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendAndConfirmOwnedPreferredPreparedExecutionWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedInvocation,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreferredPreparedExecution {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try owned.sendAndConfirmWithSpinner(
            rpc,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn getFeeForOwnedPreferredPreparedExecution(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedInvocation,
    commitment: ?client.Commitment,
) !PreferredPreparedExecutionFee {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .fee = try owned.getFee(rpc, commitment),
    };
}

pub fn sendPreferredPreparedInvocation(
    rpc: anytype,
    prepared: *const PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionTyped(signed, options),
        .versioned => |signed| try rpc.sendVersionedTransactionTyped(signed, options),
    };
}

pub fn simulatePreferredPreparedInvocation(
    rpc: anytype,
    prepared: *const PreferredPreparedSignedTransaction,
    options: ?rpc_types.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.simulateTransactionTyped(signed, options),
        .versioned => |signed| try rpc.simulateVersionedTransactionTyped(signed, options),
    };
}

pub fn sendAndConfirmPreferredPreparedInvocation(
    rpc: anytype,
    prepared: *const PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionAndConfirmTyped(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
        .versioned => |signed| try rpc.sendAndConfirmVersionedTransactionTyped(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendAndConfirmPreferredPreparedInvocationWithSpinner(
    rpc: anytype,
    prepared: *const PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return switch (prepared.transaction) {
        .legacy => |signed| try rpc.sendTransactionAndConfirmTypedWithSpinner(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
        .versioned => |signed| try rpc.sendAndConfirmVersionedTransactionTypedWithSpinner(
            signed,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendOwnedPreferredPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
) !SentPreferredPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendPreferredPreparedInvocation(rpc, &owned, options),
    };
}

pub fn simulateOwnedPreferredPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedSignedTransaction,
    options: ?rpc_types.SimulateTransactionOptions,
) !SimulatedPreferredPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .simulation = try simulatePreferredPreparedInvocation(rpc, &owned, options),
    };
}

pub fn sendAndConfirmOwnedPreferredPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreferredPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendAndConfirmPreferredPreparedInvocation(
            rpc,
            &owned,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn sendAndConfirmOwnedPreferredPreparedInvocationWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedSignedTransaction,
    options: ?rpc_types.SendTransactionOptions,
    commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !SentPreferredPreparedInvocation {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .signature = try sendAndConfirmPreferredPreparedInvocationWithSpinner(
            rpc,
            &owned,
            options,
            commitment,
            search_transaction_history,
            timeout_ms,
            poll_interval_ms,
        ),
    };
}

pub fn getFeeForPreferredPreparedInvocation(
    rpc: anytype,
    prepared: *const PreferredPreparedSignedTransaction,
    commitment: ?client.Commitment,
) !rpc_types.FeeForMessage {
    return switch (prepared.transaction) {
        .legacy => |signed| blk: {
            const encoded_message = try sdk.encodeBase64(rpc.allocator, signed.message_bytes);
            defer rpc.allocator.free(encoded_message);
            break :blk try rpc.getFeeForMessage(encoded_message, commitment);
        },
        .versioned => |signed| blk: {
            const encoded_message = try sdk.encodeBase64(rpc.allocator, signed.message_bytes);
            defer rpc.allocator.free(encoded_message);
            break :blk try rpc.getFeeForMessage(encoded_message, commitment);
        },
    };
}

pub fn getFeeForOwnedPreferredPreparedInvocation(
    allocator: Allocator,
    rpc: anytype,
    prepared: PreferredPreparedSignedTransaction,
    commitment: ?client.Commitment,
) !PreferredPreparedInvocationFee {
    var owned = prepared;
    errdefer owned.deinit(allocator);
    return .{
        .prepared = owned,
        .fee = try getFeeForPreferredPreparedInvocation(rpc, &owned, commitment),
    };
}

pub fn buildPreferredMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try buildPreferredMessageBase64FromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.bytes;
}

pub fn buildPreferredOwnedMessageResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredOwnedMessageResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return buildPreferredOwnedMessageFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredOwnedMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !OwnedInvocationMessage {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try buildPreferredOwnedMessageFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.message;
}

pub fn buildPreferredMessageBytesResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return buildPreferredMessageBytesFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try buildPreferredMessageBytesFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.bytes;
}

pub fn buildPreferredMessageBase64ResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return buildPreferredMessageBase64FromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) ![]u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try buildPreferredTransactionBase64FromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.bytes;
}

pub fn buildPreferredSignedTransactionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredSignedTransactionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return buildPreferredSignedTransactionFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredTransactionBase64ResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredBytesResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return buildPreferredTransactionBase64FromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredSignedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !SignedInvocationTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try buildPreferredSignedTransactionFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.transaction;
}

pub fn sendPreferredTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendPreferredInvocationSpecOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try sendPreferredTransactionFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.signature;
}

pub fn sendPreferredTransactionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendPreferredTransactionFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn simulatePreferredTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SimulatePreferredInvocationSpecOptions,
) !client.SimulatedTransaction {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try simulatePreferredTransactionFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.simulation;
}

pub fn simulatePreferredTransactionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SimulatePreferredInvocationSpecOptions,
) !PreferredSimulationResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return simulatePreferredTransactionFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn sendAndConfirmPreferredInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try sendAndConfirmPreferredInvocationFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.signature;
}

pub fn sendAndConfirmPreferredTransactionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendAndConfirmPreferredInvocationFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn sendAndConfirmPreferredInvocationSpecJsonWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) ![]const u8 {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try sendAndConfirmPreferredInvocationWithSpinnerFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.signature;
}

pub fn sendAndConfirmPreferredTransactionResultWithSpinnerFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendAndConfirmPreferredInvocationWithSpinnerFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn getFeeForPreferredInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: GetFeeForPreferredInvocationSpecOptions,
) !client.FeeForMessage {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    const result = try getFeeForPreferredInvocationSpecFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
    return result.fee;
}

pub fn getFeeForPreferredInvocationSpecResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredFeeResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return getFeeForPreferredInvocationSpecFromOwnedInvocationSpec(allocator, rpc, &owned_spec, options);
}

pub fn buildPreferredInvocationReportFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedPreferredInvocationReport {
    return buildPreferredInvocationReportFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json),
    );
}

pub fn buildPreferredInvocationExecutionReportFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildPreferredInvocationSpecOptions,
) !PreferredInvocationExecutionReport {
    return buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        rpc,
        try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json),
        options,
    );
}

pub fn sendPreferredTransactionExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn simulatePreferredTransactionExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SimulatePreferredInvocationSpecOptions,
) !PreferredSimulationExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return simulatePreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn sendAndConfirmPreferredTransactionExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendAndConfirmPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn sendAndConfirmPreferredTransactionExecutionResultWithSpinnerFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: SendAndConfirmPreferredInvocationSpecOptions,
) !PreferredSignatureExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return sendAndConfirmPreferredTransactionExecutionResultWithSpinnerFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
    );
}

pub fn getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: GetFeeForPreferredInvocationSpecOptions,
) !PreferredFeeExecutionResult {
    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(allocator, family, invocation_spec_json);
    defer owned_spec.deinit(allocator);
    return getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        rpc,
        &owned_spec,
        options,
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

test "invoke.buildOwnedResolvedInvocationFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 436, 437, 438, 439, 440);
    defer allocator.free(spec_json);

    var resolved = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer resolved.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), resolved.signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.owned_instructions.instructions.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.address_lookup_tables.len);
    try std.testing.expect(resolved.recent_blockhash != null);
}

test "invoke.buildInvocationSpecJsonFromOwnedInvocationSpec round-trips rich signer and nonce context" {
    const allocator = std.testing.allocator;

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 160, 161, 162, 163, 164, 165);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const exported_json = try buildInvocationSpecJsonFromOwnedInvocationSpec(allocator, &owned_spec);
    defer allocator.free(exported_json);

    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"payer_secret_key\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"additional_signer_secret_keys\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"nonce_account\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"nonce_authority_secret_key\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"data_bytes\":[4,5,6]") != null);

    var roundtrip = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        exported_json,
    );
    defer roundtrip.deinit(allocator);

    try std.testing.expectEqualDeep(owned_spec.payer, roundtrip.payer);
    try std.testing.expectEqualDeep(owned_spec.recent_blockhash, roundtrip.recent_blockhash);
    try std.testing.expectEqualDeep(owned_spec.nonce_account, roundtrip.nonce_account);
    try std.testing.expectEqualDeep(owned_spec.nonce_authority, roundtrip.nonce_authority);
    try std.testing.expectEqual(@as(usize, owned_spec.signers.len), roundtrip.signers.len);
    try std.testing.expectEqualSlices(
        u8,
        owned_spec.owned_instructions.instructions[0].data,
        roundtrip.owned_instructions.instructions[0].data,
    );
}

test "invoke.buildInvocationSpecJsonFromOwnedInvocationSpec round-trips canonical lookup tables" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 166, 167, 168, 169, 170);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const exported_json = try buildInvocationSpecJsonFromOwnedInvocationSpec(allocator, &owned_spec);
    defer allocator.free(exported_json);

    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"address_lookup_tables\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, exported_json, "\"instructions\":[") != null);

    var roundtrip = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        exported_json,
    );
    defer roundtrip.deinit(allocator);

    try std.testing.expectEqualDeep(owned_spec.payer, roundtrip.payer);
    try std.testing.expectEqualDeep(owned_spec.recent_blockhash, roundtrip.recent_blockhash);
    try std.testing.expectEqual(@as(usize, 1), roundtrip.address_lookup_tables.len);
    try std.testing.expectEqualDeep(
        owned_spec.address_lookup_tables[0].account_key,
        roundtrip.address_lookup_tables[0].account_key,
    );
    try std.testing.expectEqualDeep(
        owned_spec.address_lookup_tables[0].addresses[0],
        roundtrip.address_lookup_tables[0].addresses[0],
    );
}

test "invoke.buildInstructionsJsonFromOwnedInvocationSpec exports canonical instruction array" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 171, 172, 173, 174, 175);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const instructions_json = try buildInstructionsJsonFromOwnedInvocationSpec(allocator, &owned_spec);
    defer allocator.free(instructions_json);

    var roundtrip = try client.instructions_invoke.buildOwnedInstructionsFromJson(
        allocator,
        instructions_json,
    );
    defer roundtrip.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"program_id\":\"") != null);
    try std.testing.expectEqual(@as(usize, 1), roundtrip.instructions.len);
    try std.testing.expectEqualDeep(
        owned_spec.owned_instructions.instructions[0].program_id,
        roundtrip.instructions[0].program_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        owned_spec.owned_instructions.instructions[0].data,
        roundtrip.instructions[0].data,
    );
    try std.testing.expectEqualDeep(
        owned_spec.owned_instructions.instructions[0].accounts[0],
        roundtrip.instructions[0].accounts[0],
    );
}

test "invoke.buildInstructionsJsonFromOwnedResolvedInvocation exports canonical instruction array" {
    const allocator = std.testing.allocator;

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 176, 177, 178, 179, 180, 181);
    defer allocator.free(spec_json);

    var resolved = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
    );
    defer resolved.deinit(allocator);

    const instructions_json = try buildInstructionsJsonFromOwnedResolvedInvocation(allocator, &resolved);
    defer allocator.free(instructions_json);

    var roundtrip = try client.instructions_invoke.buildOwnedInstructionsFromJson(
        allocator,
        instructions_json,
    );
    defer roundtrip.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"accounts\":[") != null);
    try std.testing.expectEqual(@as(usize, 1), roundtrip.instructions.len);
    try std.testing.expectEqualDeep(
        resolved.owned_instructions.instructions[0].program_id,
        roundtrip.instructions[0].program_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        resolved.owned_instructions.instructions[0].data,
        roundtrip.instructions[0].data,
    );
    try std.testing.expectEqualDeep(
        resolved.owned_instructions.instructions[0].accounts[0],
        roundtrip.instructions[0].accounts[0],
    );
}

test "invoke.allocResolvedInvocationJson emits canonical resolved fields" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 182, 183, 184, 185, 186);
    defer allocator.free(spec_json);

    var resolved = try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer resolved.deinit(allocator);

    const json = try allocOwnedResolvedInvocationJson(allocator, &resolved);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"payer\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"signer_pubkeys\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"address_lookup_tables\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"instructions\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"recent_blockhash\":\"") != null);
}

test "invoke.buildOwnedInstructionsFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 441, 442, 443);
    defer allocator.free(spec_json);

    var owned_instructions = try buildOwnedInstructionsFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
    );
    defer owned_instructions.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned_instructions.instructions.len);
}

test "invoke.buildInvocationAccountsFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;
    const program_id = sdk.Pubkey.fromBytes([_]u8{446} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 445, 446, 447, 448, 449);
    defer allocator.free(spec_json);

    var accounts = try buildInvocationAccountsFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer accounts.deinit(allocator);

    try std.testing.expect(accounts.isProgram(program_id));
    try std.testing.expect(accounts.contains(program_id));
    try std.testing.expectEqual(@as(usize, 3), accounts.accounts.len);
}

test "invoke.buildInvocationSummaryFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 450, 451, 452, 453, 454);
    defer allocator.free(spec_json);

    var summary = try buildInvocationSummaryFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), summary.program_ids.len);
    try std.testing.expectEqual(@as(usize, 1), summary.address_lookup_table_count);
    try std.testing.expect(summary.recent_blockhash != null);
}

test "invoke.buildInvocationValidationFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{456} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{459} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(allocator, 455, 456, 457, 458, 459, 460);
    defer allocator.free(spec_json);

    var validation = try buildInvocationValidationFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer validation.deinit(allocator);

    try std.testing.expect(!validation.is_valid);
    try std.testing.expect(validation.hasDuplicateProvidedSigner(duplicate_signer_raw.public_key));
    try std.testing.expect(validation.hasDuplicateLookupTable(lookup_table));
}

test "invoke.buildInvocationLookupCoverageFromOwnedResolvedInvocation reuses typed normalized spec" {
    const allocator = std.testing.allocator;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{464} ** 32);
    const covered_pubkey = sdk.Pubkey.fromBytes([_]u8{465} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 461, 462, 463, 464, 465);
    defer allocator.free(spec_json);

    var coverage = try buildInvocationLookupCoverageFromOwnedResolvedInvocation(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
            allocator,
            try buildOwnedInvocationSpecFromInvocationSpecJson(
                allocator,
                .program,
                spec_json,
            ),
        ),
    );
    defer coverage.deinit(allocator);

    try std.testing.expect(coverage.containsLookupTable(lookup_table));
    try std.testing.expect(coverage.coversPubkey(covered_pubkey));
}

test "invoke.buildInvocationReportFromOwnedInvocationSpec reuses typed normalized spec" {
    const allocator = std.testing.allocator;
    const duplicate_signer = try sdk.Keypair.fromSecretKeyBytes([_]u8{467} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{470} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(allocator, 466, 467, 468, 469, 470, 471);
    defer allocator.free(spec_json);

    var report = try buildInvocationReportFromOwnedInvocationSpec(
        allocator,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.can_execute);
    try std.testing.expect(report.hasDuplicateSigner(duplicate_signer.public_key));
    try std.testing.expect(report.hasDuplicateLookupTable(lookup_table));
}

test "invoke.buildInvocationReportFromOwnedResolvedInvocation reuses typed normalized spec" {
    const allocator = std.testing.allocator;

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 472, 473, 474, 475, 476, 477);
    defer allocator.free(spec_json);

    var report = try buildInvocationReportFromOwnedResolvedInvocation(
        allocator,
        try buildOwnedResolvedInvocationFromOwnedInvocationSpec(
            allocator,
            try buildOwnedInvocationSpecFromInvocationSpecJson(
                allocator,
                .instructions,
                spec_json,
            ),
        ),
    );
    defer report.deinit(allocator);

    try std.testing.expect(report.can_execute);
    try std.testing.expect(report.uses_durable_nonce);
    try std.testing.expectEqual(InvocationBlockhashMode.durable_nonce, report.plan.blockhash_mode);
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

test "invoke.OwnedInvocationPreflight query helpers expose signer and lookup roles" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{197} ** 32);
    const extra_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{198} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{200} ** 32);
    const missing_pubkey = sdk.Pubkey.fromBytes([_]u8{201} ** 32);

    const spec_json = try allocInstructionsInvocationSpecJsonWithUnusedSigner(allocator, 197, 198, 199, 200);
    defer allocator.free(spec_json);

    var preflight = try buildInvocationPreflightFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer preflight.deinit(allocator);

    try std.testing.expect(preflight.providesSigner(payer_raw.public_key));
    try std.testing.expect(preflight.requiresSigner(payer_raw.public_key));
    try std.testing.expect(preflight.providesSigner(extra_signer_raw.public_key));
    try std.testing.expect(preflight.hasExtraSigner(extra_signer_raw.public_key));
    try std.testing.expect(preflight.containsLookupTable(lookup_table));
    try std.testing.expect(!preflight.providesSigner(missing_pubkey));
    try std.testing.expect(!preflight.requiresSigner(missing_pubkey));
    try std.testing.expect(!preflight.hasExtraSigner(missing_pubkey));
    try std.testing.expect(!preflight.containsLookupTable(missing_pubkey));
}

test "invoke.OwnedInvocationValidation query helpers expose signer and duplicate roles" {
    const allocator = std.testing.allocator;
    const extra_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{202} ** 32);
    const missing_signer = sdk.Pubkey.fromBytes([_]u8{203} ** 32);
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{205} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{208} ** 32);
    const missing_pubkey = sdk.Pubkey.fromBytes([_]u8{209} ** 32);

    const missing_spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(allocator, 202, 203, 204, 205, 206);
    defer allocator.free(missing_spec_json);

    var missing_validation = try buildInvocationValidationFromInvocationSpecJson(
        allocator,
        .instructions,
        missing_spec_json,
    );
    defer missing_validation.deinit(allocator);

    try std.testing.expect(missing_validation.providesSigner(extra_signer_raw.public_key));
    try std.testing.expect(missing_validation.isExtraSigner(extra_signer_raw.public_key));
    try std.testing.expect(missing_validation.isMissingRequiredSigner(missing_signer));
    try std.testing.expect(!missing_validation.hasDuplicateProvidedSigner(extra_signer_raw.public_key));
    try std.testing.expect(!missing_validation.hasDuplicateLookupTable(missing_pubkey));

    const duplicate_spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(allocator, 204, 205, 206, 207, 208, 209);
    defer allocator.free(duplicate_spec_json);

    var duplicate_validation = try buildInvocationValidationFromInvocationSpecJson(
        allocator,
        .program,
        duplicate_spec_json,
    );
    defer duplicate_validation.deinit(allocator);

    try std.testing.expect(duplicate_validation.providesSigner(duplicate_signer_raw.public_key));
    try std.testing.expect(duplicate_validation.hasDuplicateProvidedSigner(duplicate_signer_raw.public_key));
    try std.testing.expect(duplicate_validation.containsLookupTable(lookup_table));
    try std.testing.expect(duplicate_validation.hasDuplicateLookupTable(lookup_table));
    try std.testing.expect(!duplicate_validation.isMissingRequiredSigner(missing_pubkey));
    try std.testing.expect(!duplicate_validation.isExtraSigner(missing_pubkey));
}

test "invoke.OwnedInvocationLookupCoverage query helpers expose lookup and coverage state" {
    const allocator = std.testing.allocator;
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{210} ** 32);
    const covered_pubkey = sdk.Pubkey.fromBytes([_]u8{211} ** 32);
    const missing_pubkey = sdk.Pubkey.fromBytes([_]u8{212} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 209, 208, 207, 210, 211);
    defer allocator.free(spec_json);

    var coverage = try buildInvocationLookupCoverageFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer coverage.deinit(allocator);

    try std.testing.expect(coverage.containsLookupTable(lookup_table));
    try std.testing.expect(coverage.isCandidate(covered_pubkey));
    try std.testing.expect(coverage.coversPubkey(covered_pubkey));
    try std.testing.expect(!coverage.isUncoveredPubkey(covered_pubkey));
    try std.testing.expect(!coverage.containsLookupTable(missing_pubkey));
    try std.testing.expect(!coverage.isCandidate(missing_pubkey));
    try std.testing.expect(!coverage.coversPubkey(missing_pubkey));
    try std.testing.expect(!coverage.isUncoveredPubkey(missing_pubkey));
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

test "invoke.buildPreferredOwnedMessageResultFromInvocationSpecJson returns selected mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 266, 267, 268);
    defer allocator.free(spec_json);

    var result = try buildPreferredOwnedMessageResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.legacy, result.mode);
    switch (result.message) {
        .legacy => |owned| try std.testing.expectEqual(@as(usize, 1), owned.owned_instructions.len),
        .versioned => try std.testing.expect(false),
    }
}

test "invoke.buildPreferredOwnedMessageFromInvocationSpecJson defaults to legacy union" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 266, 267, 268);
    defer allocator.free(spec_json);

    var actual = try buildPreferredOwnedMessageFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer actual.deinit(allocator);

    switch (actual) {
        .legacy => |owned| {
            try std.testing.expectEqual(@as(usize, 1), owned.owned_instructions.len);
        },
        .versioned => try std.testing.expect(false),
    }
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

test "invoke.buildPreferredMessageBytesResultFromInvocationSpecJson returns selected versioned mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 286, 287, 288, 289, 290);
    defer allocator.free(spec_json);

    var result = try buildPreferredMessageBytesResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.versioned, result.mode);
}

test "invoke.buildPreferredMessageBytesFromInvocationSpecJson prefers versioned mode with lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 286, 287, 288, 289, 290);
    defer allocator.free(spec_json);

    const expected = try buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    const actual = try buildPreferredMessageBytesFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildPreferredTransactionBase64ResultFromInvocationSpecJson returns selected mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 296, 297, 298, 299, 210);
    defer allocator.free(spec_json);

    var result = try buildPreferredTransactionBase64ResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.versioned, result.mode);
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

test "invoke.buildPreferredInvocationReportFromInvocationSpecJson surfaces versioned preference" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        311,
        312,
        313,
        314,
        315,
    );
    defer allocator.free(spec_json);

    var preferred_report = try buildPreferredInvocationReportFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer preferred_report.deinit(allocator);

    try std.testing.expect(preferred_report.report.can_execute);
    try std.testing.expect(preferred_report.report.has_full_lookup_coverage);
    try std.testing.expectEqual(@as(usize, 1), preferred_report.report.plan.address_lookup_table_count);
    try std.testing.expectEqual(InvocationBlockhashMode.latest_blockhash, preferred_report.report.plan.blockhash_mode);
    try std.testing.expect(preferred_report.mode_report.versioned_buildable);
    try std.testing.expectEqual(
        @as(?InvocationMode, .versioned),
        preferred_report.mode_report.preferred_mode,
    );
}

test "invoke.buildPreferredInvocationReportFromInvocationSpecJson surfaces invalid preferred mode state" {
    const allocator = std.testing.allocator;

    const spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(
        allocator,
        321,
        322,
        323,
        324,
        325,
    );
    defer allocator.free(spec_json);

    var preferred_report = try buildPreferredInvocationReportFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer preferred_report.deinit(allocator);

    try std.testing.expect(!preferred_report.report.can_execute);
    try std.testing.expect(preferred_report.report.has_missing_required_signers);
    try std.testing.expectEqual(@as(usize, 0), preferred_report.report.plan.address_lookup_table_count);
    try std.testing.expectEqual(InvocationBlockhashMode.latest_blockhash, preferred_report.report.plan.blockhash_mode);
    try std.testing.expect(!preferred_report.mode_report.legacy_buildable);
    try std.testing.expect(!preferred_report.mode_report.versioned_buildable);
    try std.testing.expectEqual(
        @as(?InvocationMode, null),
        preferred_report.mode_report.preferred_mode,
    );
}

test "invoke.buildPreferredInvocationExecutionReportFromInvocationSpecJson tracks fallback selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        331,
        332,
        333,
        334,
        335,
    );
    defer allocator.free(spec_json);

    var execution_report = try buildPreferredInvocationExecutionReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer execution_report.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), execution_report.requested_mode);
    try std.testing.expect(!execution_report.requested_mode_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), execution_report.selected_mode);
    try std.testing.expect(execution_report.used_fallback);
    try std.testing.expect(execution_report.can_execute_selected_mode);
}

test "invoke.buildPreferredInvocationExecutionReportFromInvocationSpecJson tracks unbuildable requested mode without fallback" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocInstructionsInvocationSpecJsonWithMissingSignerAndExtraSigner(
        allocator,
        341,
        342,
        343,
        344,
        345,
    );
    defer allocator.free(spec_json);

    var execution_report = try buildPreferredInvocationExecutionReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = false,
            },
        },
    );
    defer execution_report.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), execution_report.requested_mode);
    try std.testing.expect(!execution_report.requested_mode_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, null), execution_report.selected_mode);
    try std.testing.expect(!execution_report.used_fallback);
    try std.testing.expect(!execution_report.can_execute_selected_mode);
}

test "invoke preferred report and execution query helpers expose mode state" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{214} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{217} ** 32);

    const preferred_spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        213,
        214,
        215,
        216,
        217,
    );
    defer allocator.free(preferred_spec_json);

    var preferred_report = try buildPreferredInvocationReportFromInvocationSpecJson(
        allocator,
        .program,
        preferred_spec_json,
    );
    defer preferred_report.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .versioned), preferred_report.preferredMode());
    try std.testing.expect(preferred_report.prefersVersioned());
    try std.testing.expect(preferred_report.report.usesLookupTables());

    const duplicate_spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(
        allocator,
        213,
        214,
        215,
        216,
        217,
        218,
    );
    defer allocator.free(duplicate_spec_json);

    var execution_report = try buildPreferredInvocationExecutionReportFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        duplicate_spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer execution_report.deinit(allocator);

    try std.testing.expect(execution_report.selectedUsesVersioned());
    try std.testing.expect(!execution_report.usedRequestedMode());
    try std.testing.expect(execution_report.report.hasDuplicateSigner(duplicate_signer_raw.public_key));
    try std.testing.expect(execution_report.report.hasDuplicateLookupTable(lookup_table));
}

test "invoke.buildPreferredOwnedMessageExecutionResultFromInvocationSpecJson preserves execution report" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 346, 347, 348);
    defer allocator.free(spec_json);

    var result = try buildPreferredOwnedMessageExecutionResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, null), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.can_execute_selected_mode);
}

test "invoke.buildPreferredTransactionBase64ExecutionResultFromInvocationSpecJson preserves fallback selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        351,
        352,
        353,
        354,
        355,
    );
    defer allocator.free(spec_json);

    var result = try buildPreferredTransactionBase64ExecutionResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expect(result.bytes.len != 0);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
}

test "invoke.buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson preserves default legacy selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 356, 357, 358);
    defer allocator.free(spec_json);

    var result = try buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.can_execute_selected_mode);
    try std.testing.expectEqual(@as(usize, 1), result.resolved_invocation.signer_pubkeys.len);
    try std.testing.expectEqual(@as(usize, 1), result.resolved_invocation.owned_instructions.instructions.len);
}

test "invoke.buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        361,
        362,
        363,
        364,
        365,
    );
    defer allocator.free(spec_json);

    var result = try buildPreferredResolvedInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
    try std.testing.expectEqual(@as(usize, 1), result.resolved_invocation.address_lookup_tables.len);
}

test "invoke.buildPreferredInvocationAnalysisFromInvocationSpecJson combines execution and account introspection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 66, 67, 68, 69, 70, 71);
    defer allocator.free(spec_json);

    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{66} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{70} ** 32);

    var analysis = try buildPreferredInvocationAnalysisFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer analysis.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), analysis.execution_report.selected_mode);
    try std.testing.expect(analysis.execution_report.can_execute_selected_mode);
    try std.testing.expectEqual(@as(usize, 1), analysis.resolved_invocation.owned_instructions.instructions.len);

    const payer_info = findInvocationAccountInfo(analysis.accounts.accounts, payer_raw.public_key).?;
    try std.testing.expect(payer_info.is_payer);
    const nonce_account_info = findInvocationAccountInfo(analysis.accounts.accounts, nonce_account).?;
    try std.testing.expect(nonce_account_info.is_nonce_account);
}

test "invoke.buildPreferredInvocationAnalysisFromInvocationSpecJson preserves fallback and lookup analysis" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};
    const program_id = sdk.Pubkey.fromBytes([_]u8{72} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 71, 72, 73, 74, 75);
    defer allocator.free(spec_json);

    var analysis = try buildPreferredInvocationAnalysisFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer analysis.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .versioned), analysis.execution_report.selected_mode);
    try std.testing.expect(analysis.execution_report.used_fallback);
    try std.testing.expectEqual(@as(usize, 1), analysis.resolved_invocation.address_lookup_tables.len);

    const program_info = findInvocationAccountInfo(analysis.accounts.accounts, program_id).?;
    try std.testing.expect(program_info.is_program);
}

test "invoke.allocPreferredInvocationAnalysisJson emits reusable analysis fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 71, 72, 73, 74, 75);
    defer allocator.free(spec_json);

    var analysis = try buildPreferredInvocationAnalysisFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer analysis.deinit(allocator);

    const json = try allocPreferredInvocationAnalysisJson(allocator, &analysis);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"selected_mode\":\"versioned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"used_fallback\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"lookup_table_count\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"program_ids\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"accounts\":[") != null);
}

test "invoke.allocPreferredInvocationAnalysisJsonFromOwnedInvocationSpec emits reusable analysis fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 198, 199, 200);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const json = try allocPreferredInvocationAnalysisJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"selected_mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"accounts\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"provided_signer_pubkeys\":[") != null);
}

test "invoke.writePreferredInvocationAnalysisTextFromOwnedInvocationSpec emits preferred analysis text" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 201, 202, 203);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    try writePreferredInvocationAnalysisTextFromOwnedInvocationSpec(
        &aw.writer,
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );

    const text = try aw.toOwnedSlice();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "selected mode: legacy") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "accounts (") != null);
}

test "invoke.allocPreferredPreparedInvocationJsonFromOwnedInvocationSpec preserves fallback fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 204, 205, 206, 207, 208);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const json = try allocPreferredPreparedInvocationJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"requested_mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"selected_mode\":\"versioned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"used_fallback\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"transaction_base64\":") != null);
}

test "invoke.allocPreferredSignatureExecutionResultJsonFromOwnedInvocationSpec emits signature fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-writer-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 209, 210, 211);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const json = try allocPreferredSignatureExecutionResultJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"selected_mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"signature\":\"typed-writer-send\"") != null);
}

test "invoke.allocPreferredSimulationExecutionResultJsonFromOwnedInvocationSpec emits simulation fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 902,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 654,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 212, 213, 214, 215, 216);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const json = try allocPreferredSimulationExecutionResultJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"selected_mode\":\"versioned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"used_fallback\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"context_slot\":902") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"units_consumed\":654") != null);
}

test "invoke.writePreferredFeeExecutionResultTextFromOwnedInvocationSpec emits fee text" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 777 };
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 217, 218, 219);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    try writePreferredFeeExecutionResultTextFromOwnedInvocationSpec(
        &aw.writer,
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );

    const text = try aw.toOwnedSlice();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "selected mode: legacy") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "fee: 777") != null);
}

test "invoke.allocSentPreparedInvocationJsonFromOwnedInvocationSpec emits signature fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-explicit-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 234, 235, 236);
    defer allocator.free(spec_json);

    const json = try allocSentPreparedInvocationJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"signature\":\"typed-explicit-send\"") != null);
}

test "invoke.allocSimulatedPreparedInvocationJsonFromOwnedInvocationSpec emits simulation fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 904,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 321,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 237, 238, 239, 240, 241);
    defer allocator.free(spec_json);

    const json = try allocSimulatedPreparedInvocationJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        true,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"versioned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"context_slot\":904") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"units_consumed\":321") != null);
}

test "invoke.writePreparedInvocationFeeTextFromOwnedInvocationSpec emits fee text" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 889 };
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 242, 243, 244);
    defer allocator.free(spec_json);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    try writePreparedInvocationFeeTextFromOwnedInvocationSpec(
        &aw.writer,
        allocator,
        DummyRpc{},
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{},
    );

    const text = try aw.toOwnedSlice();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "mode: legacy") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "fee: 889") != null);
}

test "invoke.buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions matches explicit json builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 245, 246, 247);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const actual = try buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer allocator.free(actual);

    const expected = try buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildLegacyMessageBytesFromOwnedInvocationSpec wraps WithOptions" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 10, 11, 12);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const actual = try buildLegacyMessageBytesFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .confirmed,
    );
    defer allocator.free(actual);

    const expected = try buildLegacyMessageBytesFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(expected);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions matches explicit json builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 248, 249, 250, 251, 252);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const actual = try buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer allocator.free(actual);

    const expected = try buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildVersionedTransactionBase64FromOwnedInvocationSpec wraps WithOptions" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 13, 14, 15, 16, 17);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const actual = try buildVersionedTransactionBase64FromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .processed,
    );
    defer allocator.free(actual);

    const expected = try buildVersionedTransactionBase64FromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{ .blockhash_commitment = .processed },
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildOwnedMessageFromOwnedInvocationSpecWithOptions returns typed versioned message" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 253, 254, 7, 8, 9);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var message = try buildOwnedMessageFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        true,
        &owned_spec,
        .{},
    );
    defer message.deinit(allocator);

    switch (message) {
        .versioned => |value| try std.testing.expect(value.instructions.len > 0),
        .legacy => return error.UnexpectedLegacyMode,
    }
}

test "invoke.buildOwnedMessageFromOwnedInvocationSpec wraps WithOptions" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 18, 19, 20);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var message = try buildOwnedMessageFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .finalized,
    );
    defer message.deinit(allocator);

    switch (message) {
        .legacy => |value| try std.testing.expect(value.instructions.len > 0),
        .versioned => return error.UnexpectedVersionedMode,
    }
}

test "invoke.sendTransactionFromOwnedInvocationSpecWithOptions executes explicit legacy send" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-explicit-runtime-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 21, 22, 23);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const signature = try sendTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{},
    );

    try std.testing.expectEqualStrings("typed-explicit-runtime-send", signature);
}

test "invoke.simulateTransactionFromOwnedInvocationSpecWithOptions executes explicit versioned simulate" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 905,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 432,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 24, 25, 26, 27, 28);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const simulation = try simulateTransactionFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        true,
        &owned_spec,
        .{},
    );

    try std.testing.expectEqual(@as(u64, 905), simulation.context_slot);
    try std.testing.expectEqual(@as(?u64, 432), simulation.units_consumed);
}

test "invoke.getFeeForInvocationSpecFromOwnedInvocationSpecWithOptions executes explicit fee path" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 990 };
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 29, 30, 31);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const fee = try getFeeForInvocationSpecFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 990), fee);
}

test "invoke.sendAndConfirmInvocationFromOwnedInvocationSpecWithOptions executes explicit confirm path" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-explicit-confirm";
        }

        pub fn getSignatureStatuses(
            self: *@This(),
            signatures: []const []const u8,
            config: ?rpc_types.GetSignatureStatusesConfig,
        ) !rpc_types.GetSignatureStatusesResult {
            _ = self;
            _ = signatures;
            _ = config;
            return .{
                .context = .{ .slot = 777 },
                .value = &.{.{
                    .slot = 777,
                    .confirmations = null,
                    .err = null,
                    .confirmation_status = .confirmed,
                    .status = .{ .Ok = std.json.Value{ .null = {} } },
                }},
            };
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 32, 33, 34);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const signature = try sendAndConfirmInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{
            .commitment = .confirmed,
            .timeout_ms = 10,
            .poll_ms = 1,
        },
    );

    try std.testing.expectEqualStrings("typed-explicit-confirm", signature);
}

test "invoke.allocPreparedInvocationJsonFromOwnedInvocationSpec emits generic prepared fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 220, 221, 222);
    defer allocator.free(spec_json);

    const json = try allocPreparedInvocationJsonFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"transaction_base64\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"diagnostic_error_count\":0") != null);
}

test "invoke.sendOwnedPreparedInvocationFromOwnedInvocationSpec preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-prepared-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 223, 224, 225);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        &rpc,
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{},
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("typed-prepared-send", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.mode);
}

test "invoke.simulateOwnedPreparedInvocationFromOwnedInvocationSpec preserves versioned mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 903,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 987,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 226, 227, 228, 229, 230);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var simulated = try simulateOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        &rpc,
        true,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
        .{},
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 903), simulated.simulation.context_slot);
    try std.testing.expectEqual(InvocationMode.versioned, simulated.prepared.mode);
}

test "invoke.getFeeForOwnedPreparedInvocationFromOwnedInvocationSpec preserves explicit mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 888 };
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 231, 232, 233);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        &rpc,
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{ .commitment = .confirmed },
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 888), fee_result.fee);
    try std.testing.expectEqual(InvocationMode.legacy, fee_result.prepared.mode);
}

test "invoke.sendPreparedInvocationFromOwnedInvocationSpecRef preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-borrowed-prepared-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 38, 39, 40);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var sent = try sendPreparedInvocationFromOwnedInvocationSpecRef(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{},
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("typed-borrowed-prepared-send", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.mode);
}

test "invoke.simulatePreparedInvocationFromOwnedInvocationSpecRef preserves versioned mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 906,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 543,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 41, 42, 43, 44, 45);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var simulated = try simulatePreparedInvocationFromOwnedInvocationSpecRef(
        allocator,
        DummyRpc{},
        true,
        &owned_spec,
        .{},
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 906), simulated.simulation.context_slot);
    try std.testing.expectEqual(InvocationMode.versioned, simulated.prepared.mode);
}

test "invoke.getFeeForPreparedInvocationFromOwnedInvocationSpecRef preserves explicit mode" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 991 };
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 46, 47, 48);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var fee_result = try getFeeForPreparedInvocationFromOwnedInvocationSpecRef(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{ .commitment = .confirmed },
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 991), fee_result.fee);
    try std.testing.expectEqual(InvocationMode.legacy, fee_result.prepared.mode);
}

test "invoke.buildPreferredPreparedSignedTransactionFromInvocationSpecJson prepares legacy transaction with analysis" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 76, 77, 78);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), prepared.execution_report.selected_mode);
    try std.testing.expect(prepared.execution_report.can_execute_selected_mode);
    try std.testing.expectEqual(@as(usize, 1), prepared.resolved_invocation.owned_instructions.instructions.len);
    try std.testing.expect(prepared.accounts.accounts.len >= 2);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .legacy), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreferredPreparedSignedTransactionFromInvocationSpecJson preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 81, 82, 83, 84, 85);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), prepared.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), prepared.execution_report.selected_mode);
    try std.testing.expect(prepared.execution_report.used_fallback);
    try std.testing.expectEqual(@as(usize, 1), prepared.resolved_invocation.address_lookup_tables.len);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .versioned), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreparedInvocationFromInvocationSpecJsonWithOptions prepares explicit legacy invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 86, 87, 88);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.legacy, prepared.mode);
    try std.testing.expect(prepared.report.can_execute);
    try std.testing.expectEqual(@as(usize, 1), prepared.resolved_invocation.owned_instructions.instructions.len);
    try std.testing.expect(prepared.accounts.accounts.len >= 2);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .legacy), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreparedInvocationFromInvocationSpecJsonWithOptions prepares explicit versioned invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 91, 92, 93, 94, 95);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        true,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.versioned, prepared.mode);
    try std.testing.expect(prepared.report.can_execute);
    try std.testing.expectEqual(@as(usize, 1), prepared.report.plan.address_lookup_table_count);
    try std.testing.expectEqual(@as(usize, 1), prepared.resolved_invocation.address_lookup_tables.len);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .versioned), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreparedInvocationFromOwnedInvocationSpecWithOptions prepares explicit legacy invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 119, 120, 121);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        false,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .instructions,
            spec_json,
        ),
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.legacy, prepared.mode);
    try std.testing.expect(prepared.report.can_execute);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .legacy), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions prepares explicit legacy invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 32, 33, 34);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecRefWithOptions(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.legacy, prepared.mode);
    try std.testing.expect(prepared.report.can_execute);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .legacy), std.meta.activeTag(prepared.transaction));
}

test "invoke.buildPreparedInvocationFromOwnedInvocationSpecWithOptions prepares explicit versioned invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 122, 123, 124, 125, 126);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromOwnedInvocationSpecWithOptions(
        allocator,
        DummyRpc{},
        true,
        try buildOwnedInvocationSpecFromInvocationSpecJson(
            allocator,
            .program,
            spec_json,
        ),
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.versioned, prepared.mode);
    try std.testing.expectEqual(@as(usize, 1), prepared.report.plan.address_lookup_table_count);
    try std.testing.expectEqual(@as(usize, 1), prepared.resolved_invocation.address_lookup_tables.len);
    try std.testing.expectEqual(@as(std.meta.Tag(SignedInvocationTransaction), .versioned), std.meta.activeTag(prepared.transaction));
}

test "invoke.allocPreparedInvocationJsonFromOwnedInvocationSpecRef emits generic prepared fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 35, 36, 37);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const json = try allocPreparedInvocationJsonFromOwnedInvocationSpecRef(
        allocator,
        DummyRpc{},
        false,
        &owned_spec,
        .{},
    );
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"transaction_base64\":\"") != null);
}

test "invoke.buildInvocationModeReportFromOwnedInvocationSpec prefers versioned with lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 127, 128, 129, 130, 131);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    const mode_report = try buildInvocationModeReportFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );

    try std.testing.expect(!mode_report.legacy_buildable);
    try std.testing.expect(mode_report.versioned_buildable);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), mode_report.preferred_mode);
}

test "invoke.buildPreferredInvocationExecutionReportFromOwnedInvocationSpec tracks fallback selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 132, 133, 134, 135, 136);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var execution_report = try buildPreferredInvocationExecutionReportFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer execution_report.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), execution_report.selected_mode);
    try std.testing.expect(execution_report.used_fallback);
    try std.testing.expect(execution_report.can_execute_selected_mode);
}

test "invoke.buildPreferredInvocationAnalysisFromOwnedInvocationSpec combines execution and account introspection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 137, 138, 139);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var analysis = try buildPreferredInvocationAnalysisFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer analysis.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), analysis.execution_report.selected_mode);
    try std.testing.expectEqual(owned_spec.payer, analysis.resolved_invocation.payer);
    try std.testing.expect(analysis.accounts.contains(owned_spec.payer));
    try std.testing.expect(analysis.accounts.isPayer(owned_spec.payer));
}

test "invoke.buildPreferredPreparedInvocationFromOwnedInvocationSpec preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 140, 141, 142, 143, 144);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var prepared = try buildPreferredPreparedInvocationFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, prepared.selected_mode);
    try std.testing.expect(prepared.used_fallback);
    try std.testing.expectEqual(InvocationMode.versioned, prepared.prepared.mode);
}

test "invoke.sendPreferredTransactionExecutionResultFromOwnedInvocationSpec preserves legacy selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-preferred-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 145, 146, 147);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var result = try sendPreferredTransactionExecutionResultFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("typed-preferred-send", result.signature);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.can_execute_selected_mode);
}

test "invoke.getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 742);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 148, 149, 150, 151, 152);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var result = try getFeeForPreferredInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
            .fee = .{ .commitment = .confirmed },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 742), result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
}

test "invoke.sendPreferredTransactionFromOwnedInvocationSpec returns preferred signature result" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-preferred-signature";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 153, 154, 155);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var result = try sendPreferredTransactionFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("typed-preferred-signature", result.signature);
    try std.testing.expectEqual(InvocationMode.legacy, result.mode);
}

test "invoke.getFeeForPreferredInvocationSpecFromOwnedInvocationSpec returns preferred fee result" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 843);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 156, 157, 158, 159, 160);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    const result = try getFeeForPreferredInvocationSpecFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
            .fee = .{ .commitment = .confirmed },
        },
    );

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 843), result.fee);
    try std.testing.expectEqual(InvocationMode.versioned, result.mode);
}

test "invoke.buildPreferredOwnedMessageExecutionResultFromOwnedInvocationSpec preserves legacy selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 174, 175, 176);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var result = try buildPreferredOwnedMessageExecutionResultFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.can_execute_selected_mode);
    try std.testing.expectEqual(@as(std.meta.Tag(OwnedInvocationMessage), .legacy), std.meta.activeTag(result.message));
}

test "invoke.buildPreferredTransactionBase64ExecutionResultFromOwnedInvocationSpec preserves versioned fallback selection" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 177, 178, 179, 180, 181);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var result = try buildPreferredTransactionBase64ExecutionResultFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expect(result.bytes.len != 0);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
}

test "invoke.buildPreferredResolvedInvocationExecutionResultFromOwnedInvocationSpec preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 182, 183, 184, 185, 186);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var result = try buildPreferredResolvedInvocationExecutionResultFromOwnedInvocationSpec(
        allocator,
        DummyRpc{},
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
    try std.testing.expectEqual(@as(usize, 1), result.resolved_invocation.address_lookup_tables.len);
}

test "invoke.sendOwnedPreferredPreparedExecutionFromOwnedInvocationSpec preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-owned-prepared-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 161, 162, 163);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{},
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("typed-owned-prepared-send", sent.signature);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), sent.prepared.selected_mode);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.prepared.mode);
}

test "invoke.simulateOwnedPreferredPreparedExecutionFromOwnedInvocationSpec preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 864,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 321,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 164, 165, 166, 167, 168);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var simulated = try simulateOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 864), simulated.simulation.context_slot);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), simulated.prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, simulated.prepared.selected_mode);
    try std.testing.expect(simulated.prepared.used_fallback);
}

test "invoke.getFeeForOwnedPreferredPreparedExecutionFromOwnedInvocationSpec preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 944);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 169, 170, 171, 172, 173);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreferredPreparedExecutionFromOwnedInvocationSpec(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
            .fee = .{ .commitment = .confirmed },
        },
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 944), fee_result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), fee_result.prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, fee_result.prepared.selected_mode);
    try std.testing.expect(fee_result.prepared.used_fallback);
}

test "invoke.sendPreferredPreparedExecutionFromOwnedInvocationSpecRef preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "typed-borrowed-preferred-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 62, 63, 64);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var sent = try sendPreferredPreparedExecutionFromOwnedInvocationSpecRef(
        allocator,
        &rpc,
        &owned_spec,
        .{},
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("typed-borrowed-preferred-send", sent.signature);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), sent.prepared.selected_mode);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.prepared.mode);
}

test "invoke.simulatePreferredPreparedExecutionFromOwnedInvocationSpecRef preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !client.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 908,
                .value = .{
                    .err = null,
                    .logs = null,
                    .accounts = null,
                    .units_consumed = 765,
                    .return_data = null,
                    .inner_instructions = null,
                },
            };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 65, 66, 67, 68, 69);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var simulated = try simulatePreferredPreparedExecutionFromOwnedInvocationSpecRef(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 908), simulated.simulation.context_slot);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), simulated.prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, simulated.prepared.selected_mode);
    try std.testing.expect(simulated.prepared.used_fallback);
}

test "invoke.getFeeForPreferredPreparedExecutionFromOwnedInvocationSpecRef preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 956);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 70, 71, 72, 73, 74);
    defer allocator.free(spec_json);

    var owned_spec = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer owned_spec.deinit(allocator);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForPreferredPreparedExecutionFromOwnedInvocationSpecRef(
        allocator,
        &rpc,
        &owned_spec,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
            .fee = .{ .commitment = .confirmed },
        },
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 956), fee_result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), fee_result.prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, fee_result.prepared.selected_mode);
    try std.testing.expect(fee_result.prepared.used_fallback);
}

test "invoke.allocPreparedInvocationJson emits generic prepared fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 241, 242, 243);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    const json = try allocPreparedInvocationJson(allocator, &prepared);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"legacy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"transaction_base64\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"message_base64\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"diagnostic_error_count\":0") != null);
}

test "invoke.PreparedInvocation allocResolvedInvocationJson emits canonical resolved fields" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 251, 252, 253, 254, 255, 0);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    const json = try prepared.allocResolvedInvocationJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"nonce_account\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"nonce_authority\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"instructions\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"signer_pubkeys\":[") != null);
}

test "invoke.PreparedInvocation allocInstructionsJson emits canonical instruction array" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 256, 257, 258);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    const instructions_json = try prepared.allocInstructionsJson(allocator);
    defer allocator.free(instructions_json);

    var roundtrip = try client.instructions_invoke.buildOwnedInstructionsFromJson(
        allocator,
        instructions_json,
    );
    defer roundtrip.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"program_id\":\"") != null);
    try std.testing.expectEqual(@as(usize, 1), roundtrip.instructions.len);
    try std.testing.expectEqualSlices(
        u8,
        prepared.resolved_invocation.owned_instructions.instructions[0].data,
        roundtrip.instructions[0].data,
    );
}

test "invoke.SentPreparedInvocation exports canonical resolved and instruction json" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "owned-prepared-export";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocRichInstructionsInvocationSpecJson(allocator, 264, 265, 266, 267, 268, 269);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreparedInvocation(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .instructions,
            false,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    const resolved_json = try sent.allocResolvedInvocationJson(allocator);
    defer allocator.free(resolved_json);
    const instructions_json = try sent.allocInstructionsJson(allocator);
    defer allocator.free(instructions_json);

    try std.testing.expect(std.mem.indexOf(u8, resolved_json, "\"nonce_account\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"program_id\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"data_bytes\":[4,5,6]") != null);
}

test "invoke.writePreparedInvocationText emits generic prepared summary" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 244, 245, 246, 247, 248);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        true,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try writePreparedInvocationText(&aw.writer, allocator, &prepared);
    const text = try aw.toOwnedSlice();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "mode: versioned") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "transaction base64:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "lookup table count: 1") != null);
}

test "invoke.sendPreparedInvocation dispatches prepared legacy transaction" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        captured_skip_preflight: bool = false,

        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = transaction;
            self.captured_skip_preflight = options.?.skip_preflight;
            return "prepared-legacy-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 96, 97, 98);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    const signature = try sendPreparedInvocation(
        &rpc,
        &prepared,
        .{ .skip_preflight = true },
    );

    try std.testing.expectEqualStrings("prepared-legacy-send", signature);
    try std.testing.expect(rpc.captured_skip_preflight);
}

test "invoke.simulatePreparedInvocation dispatches prepared versioned transaction" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        captured_sig_verify: bool = false,

        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = transaction;
            self.captured_sig_verify = options.?.sig_verify;
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

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 101, 102, 103, 104, 105);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        true,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    _ = try simulatePreparedInvocation(
        &rpc,
        &prepared,
        .{ .sig_verify = true },
    );

    try std.testing.expect(rpc.captured_sig_verify);
}

test "invoke.sendAndConfirmPreparedInvocationWithSpinner dispatches prepared versioned transaction" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        captured_timeout_ms: u64 = 0,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn sendTransactionAndConfirmTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return error.UnexpectedLegacyCall;
        }

        pub fn sendAndConfirmVersionedTransactionTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = transaction;
            _ = options;
            _ = search_transaction_history;
            _ = poll_interval_ms;
            self.captured_timeout_ms = timeout_ms;
            self.captured_commitment = commitment;
            return "prepared-versioned-spinner";
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 111, 112, 113, 114, 115);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .program,
        true,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    const signature = try sendAndConfirmPreparedInvocationWithSpinner(
        &rpc,
        &prepared,
        null,
        .confirmed,
        false,
        777,
        10,
    );

    try std.testing.expectEqualStrings("prepared-versioned-spinner", signature);
    try std.testing.expectEqual(@as(u64, 777), rpc.captured_timeout_ms);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, rpc.captured_commitment.?);
}

test "invoke.sendOwnedPreparedInvocation preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "owned-prepared-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 126, 127, 128);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreparedInvocation(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .instructions,
            false,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("owned-prepared-send", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.mode);
    try std.testing.expect(sent.prepared.report.can_execute);
}

test "invoke.simulateOwnedPreparedInvocation preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 9,
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

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 131, 132, 133, 134, 135);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var simulated = try simulateOwnedPreparedInvocation(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .program,
            true,
            spec_json,
            .{},
        ),
        null,
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 9), simulated.simulation.context_slot);
    try std.testing.expectEqual(InvocationMode.versioned, simulated.prepared.mode);
    try std.testing.expectEqual(@as(usize, 1), simulated.prepared.resolved_invocation.address_lookup_tables.len);
}

test "invoke.sendAndConfirmOwnedPreparedInvocationWithSpinner preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionAndConfirmTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return "owned-prepared-spinner";
        }

        pub fn sendAndConfirmVersionedTransactionTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 136, 137, 138);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendAndConfirmOwnedPreparedInvocationWithSpinner(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .instructions,
            false,
            spec_json,
            .{},
        ),
        null,
        .confirmed,
        false,
        777,
        10,
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("owned-prepared-spinner", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.mode);
    try std.testing.expect(sent.prepared.firstSignature() != null);
}

test "invoke.getFeeForPreparedInvocation dispatches prepared legacy transaction" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 321);
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 364, 365, 366);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    const fee = try getFeeForPreparedInvocation(&rpc, &prepared, .confirmed);
    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 321), fee);
}

test "invoke.getFeeForOwnedPreparedInvocation preserves prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 654);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 367, 368, 369, 370, 371);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreparedInvocation(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .program,
            true,
            spec_json,
            .{},
        ),
        .processed,
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 654), fee_result.fee);
    try std.testing.expectEqual(InvocationMode.versioned, fee_result.prepared.mode);
    try std.testing.expectEqual(@as(usize, 1), fee_result.prepared.resolved_invocation.address_lookup_tables.len);
}

test "invoke.getFeeForOwnedPreferredPreparedInvocation preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 987);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 372, 373, 374, 375, 376);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreferredPreparedInvocation(
        allocator,
        &rpc,
        try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{
                .mode = .{
                    .preferred_mode = .legacy,
                    .allow_fallback = true,
                },
            },
        ),
        .confirmed,
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 987), fee_result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), fee_result.prepared.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), fee_result.prepared.execution_report.selected_mode);
    try std.testing.expect(fee_result.prepared.execution_report.used_fallback);
}

test "invoke.PreparedInvocation methods delegate execution helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "prepared-method-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }

        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 444);
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 377, 378, 379);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    const signature = try prepared.send(&rpc, null);
    const fee = try prepared.getFee(&rpc, .confirmed);

    try std.testing.expectEqualStrings("prepared-method-send", signature);
    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 444), fee);
}

test "invoke.PreparedInvocation owned methods delegate execution helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "prepared-owned-method-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 401, 402, 403);
    defer allocator.free(spec_json);

    const prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );

    var rpc = DummyRpc{};
    var sent = try prepared.sendOwned(allocator, &rpc, null);
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("prepared-owned-method-send", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.mode);
}

test "invoke.PreferredPreparedSignedTransaction methods delegate execution helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 12,
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

        pub fn sendTransactionAndConfirmTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return error.UnexpectedLegacyCall;
        }

        pub fn sendAndConfirmVersionedTransactionTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return "preferred-method-spinner";
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 380, 381, 382, 383, 384);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    var rpc = DummyRpc{};
    const simulation = try prepared.simulate(&rpc, null);
    const signature = try prepared.sendAndConfirmWithSpinner(
        &rpc,
        null,
        .confirmed,
        false,
        888,
        11,
    );

    try std.testing.expectEqual(@as(u64, 12), simulation.context_slot);
    try std.testing.expectEqualStrings("preferred-method-spinner", signature);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), prepared.execution_report.selected_mode);
}

test "invoke.PreferredPreparedSignedTransaction owned methods delegate execution helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 852);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 404, 405, 406, 407, 408);
    defer allocator.free(spec_json);

    const prepared = try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );

    var rpc = DummyRpc{};
    var fee_result = try prepared.getFeeOwned(allocator, &rpc, .confirmed);
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 852), fee_result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), fee_result.prepared.execution_report.selected_mode);
    try std.testing.expect(fee_result.prepared.execution_report.used_fallback);
}

test "invoke.buildPreferredPreparedInvocationFromInvocationSpecJson prepares legacy invocation" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 385, 386, 387);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedInvocationFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(InvocationMode.legacy, prepared.selected_mode);
    try std.testing.expectEqual(InvocationMode.legacy, prepared.prepared.mode);
    try std.testing.expect(prepared.can_execute_selected_mode);
}

test "invoke.buildPreferredPreparedInvocationFromInvocationSpecJson preserves versioned fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 388, 389, 390, 391, 392);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedInvocationFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, prepared.selected_mode);
    try std.testing.expect(prepared.used_fallback);
    try std.testing.expectEqual(InvocationMode.versioned, prepared.prepared.mode);
}

test "invoke.sendOwnedPreferredPreparedExecution preserves preferred prepared metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "preferred-prepared-execution-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 393, 394, 395);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreferredPreparedExecution(
        allocator,
        &rpc,
        try buildPreferredPreparedInvocationFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .instructions,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("preferred-prepared-execution-send", sent.signature);
    try std.testing.expectEqual(InvocationMode.legacy, sent.prepared.selected_mode);
    try std.testing.expect(sent.prepared.can_execute_selected_mode);
}

test "invoke.SentPreferredPreparedExecution exports canonical resolved and instruction json" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "preferred-prepared-export-send";
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 259, 260, 261, 262, 263);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreferredPreparedExecution(
        allocator,
        &rpc,
        try buildPreferredPreparedInvocationFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    const resolved_json = try sent.allocResolvedInvocationJson(allocator);
    defer allocator.free(resolved_json);
    const instructions_json = try sent.allocInstructionsJson(allocator);
    defer allocator.free(instructions_json);

    try std.testing.expect(std.mem.indexOf(u8, resolved_json, "\"address_lookup_tables\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"program_id\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"data_bytes\":[1]") != null);
}

test "invoke.PreferredPreparedExecutionFee exports canonical resolved and instruction json" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: anytype,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return .{ .value = 991 };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 270, 271, 272, 273, 274);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreferredPreparedExecution(
        allocator,
        &rpc,
        try buildPreferredPreparedInvocationFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{},
        ),
        null,
    );
    defer fee_result.deinit(allocator);

    const resolved_json = try fee_result.allocResolvedInvocationJson(allocator);
    defer allocator.free(resolved_json);
    const instructions_json = try fee_result.allocInstructionsJson(allocator);
    defer allocator.free(instructions_json);

    try std.testing.expect(std.mem.indexOf(u8, resolved_json, "\"address_lookup_tables\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"program_id\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instructions_json, "\"data_bytes\":[1]") != null);
}

test "invoke.getFeeForOwnedPreferredPreparedExecution preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 741);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 396, 397, 398, 399, 400);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreferredPreparedExecution(
        allocator,
        &rpc,
        try buildPreferredPreparedInvocationFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{
                .mode = .{
                    .preferred_mode = .legacy,
                    .allow_fallback = true,
                },
            },
        ),
        .confirmed,
    );
    defer fee_result.deinit(allocator);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 741), fee_result.fee);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), fee_result.prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, fee_result.prepared.selected_mode);
    try std.testing.expect(fee_result.prepared.used_fallback);
}

test "invoke.SentPreparedInvocation exposes transaction and message helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "sent-prepared-helper";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 409, 410, 411);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreparedInvocation(
        allocator,
        &rpc,
        try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
            allocator,
            DummyRpc{},
            .instructions,
            false,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    const tx_base64 = try sent.toBase64(allocator);
    defer allocator.free(tx_base64);
    const message_base64 = try sent.messageToBase64(allocator);
    defer allocator.free(message_base64);

    try std.testing.expectEqualStrings("sent-prepared-helper", sent.signature);
    try std.testing.expect(tx_base64.len != 0);
    try std.testing.expect(message_base64.len != 0);
    try std.testing.expect(sent.firstSignature() != null);
}

test "invoke.PreferredPreparedExecutionFee exposes transaction and message helpers" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn getFeeForMessageTyped(
            self: *@This(),
            message: sdk.LegacyMessage,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return error.UnexpectedLegacyCall;
        }

        pub fn getFeeForVersionedMessageTyped(
            self: *@This(),
            message: sdk.VersionedMessageV0,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = message;
            _ = commitment;
            return @as(rpc_types.FeeForMessage, 963);
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 412, 413, 414, 415, 416);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var fee_result = try getFeeForOwnedPreferredPreparedExecution(
        allocator,
        &rpc,
        try buildPreferredPreparedInvocationFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{
                .mode = .{
                    .preferred_mode = .legacy,
                    .allow_fallback = true,
                },
            },
        ),
        .confirmed,
    );
    defer fee_result.deinit(allocator);

    const tx_base64 = try fee_result.toBase64(allocator);
    defer allocator.free(tx_base64);
    const message_base64 = try fee_result.messageToBase64(allocator);
    defer allocator.free(message_base64);

    try std.testing.expectEqual(@as(rpc_types.FeeForMessage, 963), fee_result.fee);
    try std.testing.expect(tx_base64.len != 0);
    try std.testing.expect(message_base64.len != 0);
    try std.testing.expect(fee_result.firstSignature() != null);
}

test "invoke.PreparedInvocation query helpers expose signer and program state" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};
    const program_id = sdk.Pubkey.fromBytes([_]u8{425} ** 32);
    const missing_pubkey = sdk.Pubkey.fromBytes([_]u8{429} ** 32);

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 423, 424, 425);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    try std.testing.expect(std.meta.eql(prepared.payer(), prepared.report.summary.payer));
    try std.testing.expect(prepared.containsSigner(prepared.payer()));
    try std.testing.expect(prepared.containsProgram(program_id));
    try std.testing.expect(prepared.isProgramAccount(program_id));
    try std.testing.expect(prepared.canExecute());
    try std.testing.expectEqual(InvocationBlockhashMode.latest_blockhash, prepared.blockhashMode());
    try std.testing.expect(!prepared.usesDurableNonce());
    try std.testing.expect(!prepared.containsSigner(missing_pubkey));
    try std.testing.expect(!prepared.containsProgram(missing_pubkey));
    try std.testing.expect(!prepared.hasMissingRequiredSigner(missing_pubkey));
    try std.testing.expect(!prepared.hasExtraSigner(missing_pubkey));
    try std.testing.expect(!prepared.hasDuplicateSigner(missing_pubkey));
    try std.testing.expect(!prepared.hasDuplicateLookupTable(missing_pubkey));
}

test "invoke.PreferredPreparedInvocation query helpers expose fallback and lookup state" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};
    const duplicate_signer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{431} ** 32);
    const lookup_table = sdk.Pubkey.fromBytes([_]u8{434} ** 32);
    const missing_pubkey = sdk.Pubkey.fromBytes([_]u8{435} ** 32);

    const spec_json = try allocProgramInvocationSpecJsonWithDuplicateSignerAndLookupTable(
        allocator,
        430,
        431,
        432,
        433,
        434,
        435,
    );
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedInvocationFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    try std.testing.expectEqual(@as(?InvocationMode, .legacy), prepared.requested_mode);
    try std.testing.expectEqual(InvocationMode.versioned, prepared.selected_mode);
    try std.testing.expect(prepared.used_fallback);
    try std.testing.expect(prepared.canExecute());
    try std.testing.expect(prepared.containsLookupTable(lookup_table));
    try std.testing.expect(prepared.hasDuplicateSigner(duplicate_signer_raw.public_key));
    try std.testing.expect(prepared.hasDuplicateLookupTable(lookup_table));
    try std.testing.expect(!prepared.hasMissingRequiredSigner(missing_pubkey));
    try std.testing.expect(!prepared.hasExtraSigner(missing_pubkey));
}

test "invoke.OwnedInvocationAccounts query helpers expose payer and program roles" {
    const allocator = std.testing.allocator;

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 417, 418, 419);
    defer allocator.free(spec_json);

    var accounts = try buildInvocationAccountsFromInvocationSpecJson(
        allocator,
        .instructions,
        spec_json,
    );
    defer accounts.deinit(allocator);

    var payer_pubkey: ?sdk.Pubkey = null;
    var program_pubkey: ?sdk.Pubkey = null;
    for (accounts.accounts) |info| {
        if (info.is_payer) payer_pubkey = info.pubkey;
        if (info.is_program) program_pubkey = info.pubkey;
    }

    try std.testing.expect(payer_pubkey != null);
    try std.testing.expect(program_pubkey != null);
    try std.testing.expect(accounts.contains(payer_pubkey.?));
    try std.testing.expect(accounts.isPayer(payer_pubkey.?));
    try std.testing.expect(accounts.isSigner(payer_pubkey.?));
    try std.testing.expect(!accounts.isProgram(payer_pubkey.?));
    try std.testing.expect(accounts.contains(program_pubkey.?));
    try std.testing.expect(accounts.isProgram(program_pubkey.?));
    try std.testing.expect(!accounts.isPayer(program_pubkey.?));
}

test "invoke.OwnedInvocationAccounts query helpers expose writable and missing account lookups" {
    const allocator = std.testing.allocator;

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 420, 421, 422, 423, 424);
    defer allocator.free(spec_json);

    var accounts = try buildInvocationAccountsFromInvocationSpecJson(
        allocator,
        .program,
        spec_json,
    );
    defer accounts.deinit(allocator);

    var writable_pubkey: ?sdk.Pubkey = null;
    for (accounts.accounts) |info| {
        if (info.is_writable and !info.is_program) {
            writable_pubkey = info.pubkey;
            break;
        }
    }

    const missing_pubkey = sdk.Pubkey.fromBytes(.{255} ** 32);

    try std.testing.expect(writable_pubkey != null);
    try std.testing.expect(accounts.isWritable(writable_pubkey.?));
    try std.testing.expect(accounts.find(writable_pubkey.?) != null);
    try std.testing.expect(!accounts.contains(missing_pubkey));
    try std.testing.expect(accounts.find(missing_pubkey) == null);
    try std.testing.expect(!accounts.isSigner(missing_pubkey));
    try std.testing.expect(!accounts.isWritable(missing_pubkey));
    try std.testing.expect(!accounts.isProgram(missing_pubkey));
    try std.testing.expect(!accounts.isNonceAccount(missing_pubkey));
}

test "invoke.PreparedInvocation transaction helpers expose generic serialization" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 116, 117, 118);
    defer allocator.free(spec_json);

    var prepared = try buildPreparedInvocationFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{},
    );
    defer prepared.deinit(allocator);

    const serialized = try prepared.serialize(allocator);
    defer allocator.free(serialized);
    const encoded = try prepared.toBase64(allocator);
    defer allocator.free(encoded);
    const message_bytes = try prepared.serializeMessage(allocator);
    defer allocator.free(message_bytes);
    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);

    try std.testing.expect(serialized.len != 0);
    try std.testing.expect(encoded.len != 0);
    try std.testing.expect(message_bytes.len != 0);
    try std.testing.expect(message_base64.len != 0);
    try std.testing.expect(prepared.firstSignature() != null);
}

test "invoke.PreferredPreparedSignedTransaction transaction helpers expose generic serialization" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 121, 122, 123, 124, 125);
    defer allocator.free(spec_json);

    var prepared = try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
        allocator,
        DummyRpc{},
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
        },
    );
    defer prepared.deinit(allocator);

    const encoded = try prepared.toBase64(allocator);
    defer allocator.free(encoded);
    const message_bytes = try prepared.serializeMessage(allocator);
    defer allocator.free(message_bytes);
    const message_base64 = try prepared.messageToBase64(allocator);
    defer allocator.free(message_base64);

    try std.testing.expect(encoded.len != 0);
    try std.testing.expect(message_bytes.len != 0);
    try std.testing.expect(message_base64.len != 0);
    try std.testing.expect(prepared.firstSignature() != null);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), prepared.execution_report.selected_mode);
}

test "invoke.sendOwnedPreferredPreparedInvocation preserves preferred prepared context" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return "owned-preferred-prepared-send";
        }

        pub fn sendVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedVersionedCall;
        }
    };

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 351, 352, 353);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendOwnedPreferredPreparedInvocation(
        allocator,
        &rpc,
        try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .instructions,
            spec_json,
            .{},
        ),
        null,
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("owned-preferred-prepared-send", sent.signature);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), sent.prepared.execution_report.selected_mode);
    try std.testing.expect(sent.prepared.execution_report.can_execute_selected_mode);
}

test "invoke.simulateOwnedPreferredPreparedInvocation preserves preferred prepared lookup tables" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn simulateTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return error.UnexpectedLegacyCall;
        }

        pub fn simulateVersionedTransactionTyped(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SimulateTransactionOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = self;
            _ = transaction;
            _ = options;
            return .{
                .context_slot = 11,
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

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 354, 355, 356, 357, 358);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var simulated = try simulateOwnedPreferredPreparedInvocation(
        allocator,
        &rpc,
        try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{
                .mode = .{
                    .preferred_mode = .legacy,
                    .allow_fallback = true,
                },
            },
        ),
        null,
    );
    defer simulated.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 11), simulated.simulation.context_slot);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), simulated.prepared.execution_report.selected_mode);
    try std.testing.expectEqual(@as(usize, 1), simulated.prepared.resolved_invocation.address_lookup_tables.len);
}

test "invoke.sendAndConfirmOwnedPreferredPreparedInvocationWithSpinner preserves fallback metadata" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {
        pub fn sendTransactionAndConfirmTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedLegacyTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return error.UnexpectedLegacyCall;
        }

        pub fn sendAndConfirmVersionedTransactionTypedWithSpinner(
            self: *@This(),
            transaction: sdk.SignedVersionedTransaction,
            options: ?rpc_types.SendTransactionOptions,
            commitment: ?rpc_types.Commitment,
            search_transaction_history: bool,
            timeout_ms: u64,
            poll_interval_ms: u64,
        ) ![]const u8 {
            _ = self;
            _ = transaction;
            _ = options;
            _ = commitment;
            _ = search_transaction_history;
            _ = timeout_ms;
            _ = poll_interval_ms;
            return "owned-preferred-prepared-spinner";
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(allocator, 359, 360, 361, 362, 363);
    defer allocator.free(spec_json);

    var rpc = DummyRpc{};
    var sent = try sendAndConfirmOwnedPreferredPreparedInvocationWithSpinner(
        allocator,
        &rpc,
        try buildPreferredPreparedSignedTransactionFromInvocationSpecJson(
            allocator,
            DummyRpc{},
            .program,
            spec_json,
            .{
                .mode = .{
                    .preferred_mode = .legacy,
                    .allow_fallback = true,
                },
            },
        ),
        null,
        .confirmed,
        false,
        555,
        10,
    );
    defer sent.deinit(allocator);

    try std.testing.expectEqualStrings("owned-preferred-prepared-spinner", sent.signature);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), sent.prepared.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), sent.prepared.execution_report.selected_mode);
    try std.testing.expect(sent.prepared.execution_report.used_fallback);
}

test "invoke.sendPreferredTransactionExecutionResultFromInvocationSpecJson preserves execution report" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{346} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{347} ** 32);
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
        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = signers;
            _ = options;
            return "preferred-execution-send";
        }
    };

    var rpc = MockRpc{};
    var result = try sendPreferredTransactionExecutionResultFromInvocationSpecJson(
        allocator,
        &rpc,
        .program,
        spec_json,
        .{},
    );
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("preferred-execution-send", result.signature);
    try std.testing.expectEqual(@as(?InvocationMode, null), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.can_execute_selected_mode);
}

test "invoke.getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson preserves fallback report" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        pub fn getFeeForVersionedInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            lookup_tables: []const sdk.AddressLookupTableAccount,
            options: ?rpc_types.VersionedInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = self;
            _ = payer;
            _ = instructions;
            _ = lookup_tables;
            _ = options;
            _ = commitment;
            return .{ .value = 2468 };
        }
    };

    const spec_json = try allocProgramInvocationSpecJsonWithLookupTable(
        allocator,
        351,
        352,
        353,
        354,
        355,
    );
    defer allocator.free(spec_json);

    var rpc = MockLegacyInvocationFeeClient{};
    var result = try getFeeForPreferredInvocationExecutionResultFromInvocationSpecJson(
        allocator,
        &rpc,
        .program,
        spec_json,
        .{
            .mode = .{
                .preferred_mode = .legacy,
                .allow_fallback = true,
            },
            .fee = .{ .commitment = .processed },
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(?u64, 2468), result.fee.value);
    try std.testing.expectEqual(@as(?InvocationMode, .legacy), result.execution_report.requested_mode);
    try std.testing.expectEqual(@as(?InvocationMode, .versioned), result.execution_report.selected_mode);
    try std.testing.expect(result.execution_report.used_fallback);
}
