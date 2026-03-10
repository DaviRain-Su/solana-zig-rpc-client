const std = @import("std");
const json = std.json;
const sdk = @import("../sdk.zig");
const rpc_types = @import("../rpc_types.zig");

const LegacyTransaction = sdk.LegacyTransaction;
const SignedLegacyTransaction = sdk.SignedLegacyTransaction;
const VersionedTransaction = sdk.VersionedTransaction;
const SignedVersionedTransaction = sdk.SignedVersionedTransaction;
const max_lockout_history = sdk.max_lockout_history;
const poll_for_signature_timeout_ms = sdk.poll_for_signature_timeout_ms;
const poll_for_signature_confirmation_timeout_ms = sdk.poll_for_signature_confirmation_timeout_ms;
const signature_poll_interval_ms = sdk.signature_poll_interval_ms;
const default_balance_poll_timeout_ms = sdk.default_balance_poll_timeout_ms;
const default_balance_poll_interval_ms = sdk.default_balance_poll_interval_ms;
const wait_for_balance_error_retries = sdk.wait_for_balance_error_retries;

const Commitment = rpc_types.Commitment;
const LatestBlockhash = rpc_types.LatestBlockhash;
const RpcErrorDetail = rpc_types.RpcErrorDetail;
const RpcSimulatedTransactionResult = rpc_types.RpcSimulatedTransactionResult;
const SendTransactionOptions = rpc_types.SendTransactionOptions;
const SignatureForAddress = rpc_types.SignatureForAddress;
const SignatureStatus = rpc_types.SignatureStatus;
const SignaturesForAddressOptions = rpc_types.SignaturesForAddressOptions;
const SignatureStatusesQueryOptions = rpc_types.SignatureStatusesQueryOptions;
const SimulateTransactionOptions = rpc_types.SimulateTransactionOptions;
const SimulatedTransaction = rpc_types.SimulatedTransaction;
const SimulationReturnData = rpc_types.SimulationReturnData;
const accountEncodingToString = rpc_types.accountEncodingToString;
const commitmentToString = rpc_types.commitmentToString;
const confirmationSatisfiesCommitment = rpc_types.confirmationSatisfiesCommitment;

const SpinnerPhase = enum {
    waiting_for_observation,
    waiting_for_commitment,
    confirmed,
};

const SpinnerReporter = struct {
    signature: []const u8,
    commitment: ?Commitment,
    last_phase: ?SpinnerPhase = null,

    fn initSend(signature: []const u8, commitment: ?Commitment) SpinnerReporter {
        std.debug.print("sending transaction...\n", .{});
        std.debug.print("submitted transaction: {s}\n", .{signature});
        return .{
            .signature = signature,
            .commitment = commitment,
        };
    }

    fn initConfirm(signature: []const u8, commitment: ?Commitment) SpinnerReporter {
        std.debug.print("confirming transaction: {s}\n", .{signature});
        return .{
            .signature = signature,
            .commitment = commitment,
        };
    }

    fn transition(self: *SpinnerReporter, phase: SpinnerPhase) void {
        if (self.last_phase == phase) return;
        self.last_phase = phase;

        switch (phase) {
            .waiting_for_observation => std.debug.print(
                "waiting for transaction to be observed: {s}\n",
                .{self.signature},
            ),
            .waiting_for_commitment => std.debug.print(
                "waiting for {s} confirmation: {s}\n",
                .{ commitmentToString(self.commitment orelse .processed), self.signature },
            ),
            .confirmed => std.debug.print(
                "transaction confirmed: {s}\n",
                .{self.signature},
            ),
        }
    }
};

pub fn serializeSimulateTransactionParams(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SimulateTransactionOptions,
) ![]u8 {
    const SimulationAccountsConfig = struct {
        addresses: []const []const u8 = &.{},
        encoding: ?[]const u8 = null,
    };

    const SimulateOptions = struct {
        commitment: ?[]const u8 = null,
        encoding: []const u8 = "base64",
        replaceRecentBlockhash: bool = false,
        sigVerify: bool = false,
        minContextSlot: ?u64 = null,
        innerInstructions: bool = false,
        accounts: ?SimulationAccountsConfig = null,
    };

    const params = .{
        signed_tx_base64,
        SimulateOptions{
            .commitment = self.resolveCommitmentString(if (options) |opts| opts.commitment else null),
            .replaceRecentBlockhash = if (options) |opts| opts.replace_recent_blockhash else false,
            .sigVerify = if (options) |opts| opts.sig_verify else false,
            .minContextSlot = if (options) |opts| opts.min_context_slot else null,
            .innerInstructions = if (options) |opts| opts.inner_instructions else false,
            .accounts = if (options) |opts|
                if (opts.accounts) |accounts|
                    SimulationAccountsConfig{
                        .addresses = accounts.addresses,
                        .encoding = if (accounts.encoding) |value| accountEncodingToString(value) else null,
                    }
                else
                    null
            else
                null,
        },
    };

    return try self.serializeParams(params);
}

pub fn serializeSendTransactionParams(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
) ![]u8 {
    const SendOptions = struct {
        encoding: []const u8 = "base64",
        skipPreflight: bool,
        maxRetries: ?u32 = null,
        preflightCommitment: ?[]const u8 = null,
        minContextSlot: ?u64 = null,
    };

    const params = .{
        signed_tx_base64,
        SendOptions{
            .skipPreflight = if (options) |opts| opts.skip_preflight else false,
            .maxRetries = if (options) |opts| opts.max_retries else null,
            .preflightCommitment = self.resolveCommitmentString(if (options) |opts| opts.preflight_commitment else null),
            .minContextSlot = if (options) |opts| opts.min_context_slot else null,
        },
    };

    return try self.serializeParams(params);
}

pub fn serializeSignaturesForAddressParams(
    self: anytype,
    address: []const u8,
    options: ?SignaturesForAddressOptions,
) ![]u8 {
    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const before = if (options) |value| value.before else null;
    const until = if (options) |value| value.until else null;
    const limit = if (options) |value| value.limit else null;
    const min_context_slot = if (options) |value| value.min_context_slot else null;

    if (before == null and until == null and limit == null and resolved_commitment == null and min_context_slot == null) {
        return try self.serializeParams(.{address});
    }

    const params = .{
        address,
        .{
            .before = before,
            .until = until,
            .limit = limit,
            .commitment = resolved_commitment,
            .minContextSlot = min_context_slot,
        },
    };
    return try self.serializeParams(params);
}

pub fn serializeSignatureStatusesParams(
    self: anytype,
    signatures: []const []const u8,
    options: ?SignatureStatusesQueryOptions,
) ![]u8 {
    if (options) |value| {
        const resolved_commitment = self.resolveCommitmentString(value.commitment);

        if (resolved_commitment != null) {
            return try self.serializeParams(.{
                signatures,
                .{
                    .searchTransactionHistory = value.search_transaction_history,
                    .commitment = resolved_commitment,
                },
            });
        }

        if (value.search_transaction_history) {
            return try self.serializeParams(.{
                signatures,
                .{ .searchTransactionHistory = true },
            });
        }
    }

    return try self.serializeParams(.{signatures});
}
pub fn send(self: anytype, signed_tx_base64: []const u8) ![]const u8 {
    return try self.sendTransaction(signed_tx_base64, null);
}

pub fn sendTransactionWithConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendTransaction(signed_tx_base64, options);
}

pub fn sendAndConfirmTransaction(self: anytype, signed_tx_base64: []const u8) ![]const u8 {
    return try self.sendTransactionAndConfirm(
        signed_tx_base64,
        null,
        null,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithCommitment(
    self: anytype,
    signed_tx_base64: []const u8,
    commitment: Commitment,
) ![]const u8 {
    return try self.sendTransactionAndConfirm(
        signed_tx_base64,
        null,
        commitment,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendTransactionAndConfirm(
        signed_tx_base64,
        options,
        null,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithCommitmentAndConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    commitment: Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try self.sendTransactionAndConfirm(
        signed_tx_base64,
        options,
        commitment,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendTransaction(self: anytype, signed_tx_base64: []const u8, options: ?SendTransactionOptions) ![]const u8 {
    const params_json = try self.serializeSendTransactionParams(signed_tx_base64, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("sendTransaction", params_json);
    defer self.allocator.free(response);

    const signature = try self.parseResponse(response, []const u8);

    return try self.allocator.dupe(u8, signature);
}

pub fn sendTransactionTyped(
    self: anytype,
    transaction: SignedLegacyTransaction,
    options: ?SendTransactionOptions,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.sendTransaction(encoded, options);
}

pub fn sendVersionedTransactionTyped(
    self: anytype,
    transaction: SignedVersionedTransaction,
    options: ?SendTransactionOptions,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.sendTransaction(encoded, options);
}

pub fn sendLegacyTransaction(
    self: anytype,
    transaction: LegacyTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendTransactionTyped(signed, options);
}

pub fn sendVersionedTransaction(
    self: anytype,
    transaction: VersionedTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendVersionedTransactionTyped(signed, options);
}

pub fn simulateTransaction(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    const params_json = try self.serializeSimulateTransactionParams(signed_tx_base64, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("simulateTransaction", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?struct {
            context: struct {
                slot: u64 = 0,
            } = .{ .slot = 0 },
            value: RpcSimulatedTransactionResult = .{},
        } = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = parsed.value.result orelse return error.InvalidResponse;
    var simulation = SimulatedTransaction{};
    errdefer {
        if (simulation.accounts) |accounts| {
            for (accounts) |maybe_info| {
                if (maybe_info) |info| {
                    self.allocator.free(info.owner);
                    if (info.data) |value| self.allocator.free(value);
                    if (info.data_encoding) |value| self.allocator.free(value);
                }
            }
            self.allocator.free(accounts);
        }
        if (simulation.err_json) |value| self.allocator.free(value);
        if (simulation.inner_instructions_json) |value| self.allocator.free(value);
        if (simulation.logs) |logs| {
            for (logs) |entry| self.allocator.free(entry);
            self.allocator.free(logs);
        }
        if (simulation.replacement_blockhash) |value| self.allocator.free(value.blockhash);
        if (simulation.return_data) |value| {
            self.allocator.free(value.program_id);
            if (value.data) |entry| self.allocator.free(entry);
            if (value.data_encoding) |entry| self.allocator.free(entry);
        }
    }

    simulation.context_slot = result.context.slot;

    if (result.value.accounts) |accounts| {
        simulation.accounts = try self.cloneOptionalAccountInfos(accounts);
    }

    if (result.value.err) |value| {
        simulation.err_json = switch (value) {
            .null => null,
            .string => |text| try self.allocator.dupe(u8, text),
            else => try json.Stringify.valueAlloc(self.allocator, value, .{}),
        };
    }

    simulation.fee = result.value.fee;

    if (result.value.innerInstructions) |value| {
        simulation.inner_instructions_json = try json.Stringify.valueAlloc(self.allocator, value, .{});
    }

    if (result.value.logs) |logs| {
        simulation.logs = try self.cloneStringList(logs);
    }

    simulation.loaded_accounts_data_size = result.value.loadedAccountsDataSize;
    simulation.units_consumed = result.value.unitsConsumed;
    simulation.replacement_blockhash = if (result.value.replacementBlockhash) |value|
        LatestBlockhash{
            .blockhash = try self.allocator.dupe(u8, value.blockhash),
            .last_valid_block_height = value.lastValidBlockHeight,
        }
    else
        null;

    simulation.return_data = if (result.value.returnData) |value|
        SimulationReturnData{
            .program_id = try self.allocator.dupe(u8, value.programId),
            .data = if (value.data) |entry|
                if (entry.len >= 1) try self.allocator.dupe(u8, entry[0]) else null
            else
                null,
            .data_encoding = if (value.data) |entry|
                if (entry.len >= 2) try self.allocator.dupe(u8, entry[1]) else null
            else
                null,
        }
    else
        null;

    return simulation;
}

pub fn simulateTransactionWithConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    return try self.simulateTransaction(signed_tx_base64, options);
}

pub fn simulateTransactionTyped(
    self: anytype,
    transaction: SignedLegacyTransaction,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.simulateTransaction(encoded, options);
}

pub fn simulateVersionedTransactionTyped(
    self: anytype,
    transaction: SignedVersionedTransaction,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.simulateTransaction(encoded, options);
}

pub fn simulateLegacyTransaction(
    self: anytype,
    transaction: LegacyTransaction,
    signers: []const sdk.Keypair,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.simulateTransactionTyped(signed, options);
}

pub fn simulateVersionedTransaction(
    self: anytype,
    transaction: VersionedTransaction,
    signers: []const sdk.Keypair,
    options: ?SimulateTransactionOptions,
) !SimulatedTransaction {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.simulateVersionedTransactionTyped(signed, options);
}

const SignatureStatusEntry = struct {
    confirmationStatus: ?[]const u8 = null,
    err: ?json.Value = null,
    slot: ?u64 = null,
    confirmations: ?u64 = null,
};

const SignatureStatusesResult = struct {
    context: struct {
        slot: u64 = 0,
    } = .{ .slot = 0 },
    value: []?SignatureStatusEntry = &.{},
};

pub fn getSignatureStatusWithOptions(
    self: anytype,
    signature: []const u8,
    options: ?SignatureStatusesQueryOptions,
) !SignatureStatus {
    const signatures = [_][]const u8{signature};
    const params_json = try self.serializeSignatureStatusesParams(signatures[0..], options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getSignatureStatuses", params_json);
    defer self.allocator.free(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?SignatureStatusesResult = null,
        @"error": ?RpcErrorDetail = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.@"error" != null) {
        const err = parsed.value.@"error".?;
        self.last_error = RpcErrorDetail{
            .code = err.code,
            .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
        };
        return error.RpcError;
    }

    const result = parsed.value.result orelse return error.InvalidResponse;
    if (result.value.len == 0) return error.TransactionNotFound;

    const first = result.value[0] orelse return error.TransactionNotFound;

    return SignatureStatus{
        .confirmation_status = if (first.confirmationStatus) |value| try self.allocator.dupe(u8, value) else null,
        .has_error = first.err != null,
        .slot = first.slot,
        .confirmations = first.confirmations,
    };
}

pub fn getSignatureStatusWithConfig(
    self: anytype,
    signature: []const u8,
    options: ?SignatureStatusesQueryOptions,
) !SignatureStatus {
    return try self.getSignatureStatusWithOptions(signature, options);
}

pub fn getSignatureStatus(self: anytype, signature: []const u8, commitment: ?Commitment) !SignatureStatus {
    return try self.getSignatureStatusWithOptions(
        signature,
        if (commitment) |value| .{ .commitment = value } else null,
    );
}

pub fn getSignatureStatusWithHistory(self: anytype, signature: []const u8) !SignatureStatus {
    return try self.getSignatureStatusWithOptions(signature, .{ .search_transaction_history = true });
}

pub fn getSignatureStatusWithCommitmentAndHistory(
    self: anytype,
    signature: []const u8,
    commitment: ?Commitment,
) !SignatureStatus {
    return try self.getSignatureStatusWithOptions(
        signature,
        .{
            .search_transaction_history = true,
            .commitment = commitment,
        },
    );
}

pub fn getSignatureStatusesWithOptions(
    self: anytype,
    signatures: []const []const u8,
    options: ?SignatureStatusesQueryOptions,
) ![]?SignatureStatus {
    const params_json = try self.serializeSignatureStatusesParams(signatures, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getSignatureStatuses", params_json);
    defer self.allocator.free(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?SignatureStatusesResult = null,
        @"error": ?RpcErrorDetail = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.@"error" != null) {
        const err = parsed.value.@"error".?;
        self.last_error = RpcErrorDetail{
            .code = err.code,
            .message = self.allocator.dupe(u8, err.message) catch return error.InvalidResponse,
        };
        return error.RpcError;
    }

    const result = parsed.value.result orelse return error.InvalidResponse;
    if (result.value.len == 0) return self.allocator.alloc(?SignatureStatus, 0);

    const copied = try self.allocator.alloc(?SignatureStatus, result.value.len);

    for (result.value, 0..) |entry, index| {
        if (entry) |status| {
            copied[index] = SignatureStatus{
                .confirmation_status = if (status.confirmationStatus) |value| try self.allocator.dupe(u8, value) else null,
                .has_error = status.err != null,
                .slot = status.slot,
                .confirmations = status.confirmations,
            };
        } else {
            copied[index] = null;
        }
    }

    return copied;
}

pub fn getSignatureStatusesWithConfig(
    self: anytype,
    signatures: []const []const u8,
    options: ?SignatureStatusesQueryOptions,
) ![]?SignatureStatus {
    return try self.getSignatureStatusesWithOptions(signatures, options);
}

pub fn getSignatureStatuses(self: anytype, signatures: []const []const u8, commitment: ?Commitment) ![]?SignatureStatus {
    return try self.getSignatureStatusesWithOptions(
        signatures,
        if (commitment) |value| .{ .commitment = value } else null,
    );
}

pub fn getSignatureStatusesWithHistory(self: anytype, signatures: []const []const u8) ![]?SignatureStatus {
    return try self.getSignatureStatusesWithOptions(signatures, .{ .search_transaction_history = true });
}

pub fn getSignatureStatusesWithCommitmentAndHistory(
    self: anytype,
    signatures: []const []const u8,
    commitment: ?Commitment,
) ![]?SignatureStatus {
    return try self.getSignatureStatusesWithOptions(
        signatures,
        .{
            .search_transaction_history = true,
            .commitment = commitment,
        },
    );
}

pub fn confirmTransaction(
    self: anytype,
    signature: []const u8,
    commitment: ?Commitment,
    search_transaction_history: bool,
) !bool {
    const resolved_commitment = self.resolveCommitment(commitment);
    const signature_status_options = if (search_transaction_history or resolved_commitment != null)
        SignatureStatusesQueryOptions{
            .search_transaction_history = search_transaction_history,
            .commitment = resolved_commitment,
        }
    else
        null;

    const status = self.getSignatureStatusWithOptions(
        signature,
        signature_status_options,
    ) catch |err| switch (err) {
        error.TransactionNotFound => return false,
        else => return err,
    };
    defer if (status.confirmation_status) |value| self.allocator.free(value);

    if (status.has_error) return false;
    return confirmationSatisfiesCommitment(status.confirmation_status, resolved_commitment);
}

pub fn getNumBlocksSinceSignatureConfirmation(
    self: anytype,
    signature: []const u8,
    search_transaction_history: bool,
) !u64 {
    return try self.getNumBlocksSinceSignatureConfirmationWithCommitment(
        signature,
        null,
        search_transaction_history,
    );
}

pub fn getNumBlocksSinceSignatureConfirmationWithCommitment(
    self: anytype,
    signature: []const u8,
    commitment: ?Commitment,
    search_transaction_history: bool,
) !u64 {
    const resolved_commitment = self.resolveCommitment(commitment);
    const status = try self.getSignatureStatusWithOptions(
        signature,
        if (search_transaction_history or resolved_commitment != null)
            SignatureStatusesQueryOptions{
                .search_transaction_history = search_transaction_history,
                .commitment = resolved_commitment,
            }
        else
            null,
    );
    defer if (status.confirmation_status) |value| self.allocator.free(value);

    return status.confirmations orelse max_lockout_history + 1;
}

const SignatureForAddressResult = struct {
    signature: []const u8 = "",
    slot: u64 = 0,
    err: ?json.Value = null,
    memo: ?[]const u8 = null,
    confirmationStatus: ?[]const u8 = null,
    blockTime: ?i64 = null,
};

pub fn getSignaturesForAddress(
    self: anytype,
    address: []const u8,
    before: ?[]const u8,
    until: ?[]const u8,
    limit: ?u64,
    commitment: ?Commitment,
) ![]SignatureForAddress {
    return try self.getSignaturesForAddressWithOptions(
        address,
        .{
            .before = before,
            .until = until,
            .limit = limit,
            .commitment = commitment,
        },
    );
}

pub fn getSignaturesForAddressWithConfig(
    self: anytype,
    address: []const u8,
    options: ?rpc_types.SignaturesForAddressOptions,
) ![]SignatureForAddress {
    return try self.getSignaturesForAddressWithOptions(address, options);
}

pub fn getSignaturesForAddressWithOptions(
    self: anytype,
    address: []const u8,
    options: ?rpc_types.SignaturesForAddressOptions,
) ![]SignatureForAddress {
    const params = try self.serializeSignaturesForAddressParams(address, options);
    defer self.allocator.free(params);

    const response = try self.sendRequest("getSignaturesForAddress", params);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?[]SignatureForAddressResult = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const source = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.allocator.alloc(SignatureForAddress, source.len);

    for (source, 0..) |entry, idx| {
        copied[idx] = SignatureForAddress{
            .signature = try self.allocator.dupe(u8, entry.signature),
            .slot = entry.slot,
            .block_time = entry.blockTime,
            .confirmation_status = if (entry.confirmationStatus) |status| try self.allocator.dupe(u8, status) else null,
            .memo = if (entry.memo) |memo| try self.allocator.dupe(u8, memo) else null,
            .has_error = entry.err != null,
        };
    }

    return copied;
}

pub fn pollGetBalanceWithCommitmentAndTimeouts(
    self: anytype,
    account: []const u8,
    commitment: ?Commitment,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !u64 {
    const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
    var last_error: ?anyerror = null;

    while (std.time.milliTimestamp() < deadline) {
        const balance_result = self.getBalance(account, commitment);
        if (balance_result) |balance| {
            return balance;
        } else |err| {
            last_error = err;
        }

        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    if (last_error) |err| return err;
    return error.Timeout;
}

pub fn pollGetBalanceWithCommitment(self: anytype, account: []const u8, commitment: ?Commitment) !u64 {
    return try self.pollGetBalanceWithCommitmentAndTimeouts(
        account,
        commitment,
        default_balance_poll_timeout_ms,
        default_balance_poll_interval_ms,
    );
}

pub fn waitForBalanceWithCommitmentAndTimeouts(
    self: anytype,
    account: []const u8,
    expected_balance: ?u64,
    commitment: ?Commitment,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !u64 {
    const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
    var last_error: ?anyerror = null;

    while (std.time.milliTimestamp() < deadline) {
        const balance_result = self.getBalance(account, commitment);
        if (balance_result) |balance| {
            last_error = null;
            if (expected_balance == null or balance == expected_balance.?) {
                return balance;
            }
        } else |err| {
            last_error = err;
        }

        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    if (last_error) |err| return err;
    return error.Timeout;
}

pub fn waitForBalanceWithCommitment(
    self: anytype,
    account: []const u8,
    expected_balance: ?u64,
    commitment: ?Commitment,
) !u64 {
    var run: usize = 0;

    while (true) {
        const balance_result = self.pollGetBalanceWithCommitment(account, commitment);
        if (expected_balance == null) return balance_result;

        if (balance_result) |balance| {
            if (balance == expected_balance.?) return balance;
        } else |err| {
            if (run == wait_for_balance_error_retries) return err;
        }

        run += 1;
    }
}

pub fn waitForSignatureStatus(
    self: anytype,
    signature: []const u8,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
    strict: bool,
) !void {
    return try waitForSignatureStatusWithInitialTimeout(
        self,
        signature,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
        strict,
        null,
        null,
    );
}

fn waitForSignatureStatusWithInitialTimeout(
    self: anytype,
    signature: []const u8,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
    strict: bool,
    initial_transaction_not_found_timeout_ms: ?u64,
    spinner: ?*SpinnerReporter,
) !void {
    const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
    const resolved_commitment = self.resolveCommitment(commitment);
    const initial_deadline = if (initial_transaction_not_found_timeout_ms) |value|
        std.time.milliTimestamp() + @as(i64, @intCast(value))
    else
        deadline;
    var confirmation_deadline: ?i64 = if (initial_transaction_not_found_timeout_ms == null) deadline else null;

    while (true) {
        if (confirmation_deadline) |value| {
            if (std.time.milliTimestamp() >= value) return error.TransactionNotConfirmed;
        }

        const status_options = if (search_transaction_history or resolved_commitment != null)
            SignatureStatusesQueryOptions{
                .search_transaction_history = search_transaction_history,
                .commitment = resolved_commitment,
            }
        else
            null;

        const status = self.getSignatureStatusWithOptions(signature, status_options) catch |err| {
            switch (err) {
                error.TransactionNotFound => {
                    const effective_deadline = confirmation_deadline orelse initial_deadline;
                    if (std.time.milliTimestamp() >= effective_deadline) {
                        return error.TransactionNotConfirmed;
                    }
                    if (spinner) |value| value.transition(.waiting_for_observation);
                    std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
                    continue;
                },
                else => return err,
            }
        };

        if (confirmation_deadline == null) {
            confirmation_deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
        }

        defer {
            if (status.confirmation_status) |value| {
                self.allocator.free(value);
            }
        }

        if (strict and status.has_error) return error.TransactionFailed;
        if (confirmationSatisfiesCommitment(status.confirmation_status, resolved_commitment)) {
            if (spinner) |value| value.transition(.confirmed);
            return;
        }
        if (!strict and status.has_error and resolved_commitment == null) {
            if (spinner) |value| value.transition(.confirmed);
            return;
        }

        if (spinner) |value| value.transition(.waiting_for_commitment);

        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    return error.TransactionNotConfirmed;
}

pub fn pollForSignature(self: anytype, signature: []const u8, commitment: ?Commitment, search_transaction_history: bool) !void {
    try self.waitForSignatureStatus(
        signature,
        commitment,
        search_transaction_history,
        poll_for_signature_timeout_ms,
        signature_poll_interval_ms,
        false,
    );
}

pub fn pollForSignatureConfirmationWithTimeouts(
    self: anytype,
    signature: []const u8,
    min_confirmed_blocks: u64,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !u64 {
    return try self.pollForSignatureConfirmationWithCommitmentAndTimeouts(
        signature,
        min_confirmed_blocks,
        null,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn pollForSignatureConfirmationWithCommitmentAndTimeouts(
    self: anytype,
    signature: []const u8,
    min_confirmed_blocks: u64,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !u64 {
    const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
    var confirmed_blocks: ?u64 = null;
    const resolved_commitment = self.resolveCommitment(commitment);

    while (std.time.milliTimestamp() < deadline) {
        const status = self.getSignatureStatusWithOptions(
            signature,
            if (search_transaction_history or resolved_commitment != null)
                SignatureStatusesQueryOptions{
                    .search_transaction_history = search_transaction_history,
                    .commitment = resolved_commitment,
                }
            else
                null,
        ) catch |err| switch (err) {
            error.TransactionNotFound => {
                std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
                continue;
            },
            else => return err,
        };
        defer if (status.confirmation_status) |value| self.allocator.free(value);

        if (resolved_commitment != null and !confirmationSatisfiesCommitment(status.confirmation_status, resolved_commitment)) {
            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
            continue;
        }

        const current_confirmed_blocks = status.confirmations orelse max_lockout_history + 1;
        confirmed_blocks = current_confirmed_blocks;
        if (current_confirmed_blocks >= min_confirmed_blocks) return current_confirmed_blocks;

        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    if (confirmed_blocks) |value| {
        return value;
    }
    return error.TransactionNotConfirmed;
}

pub fn pollForSignatureConfirmation(
    self: anytype,
    signature: []const u8,
    min_confirmed_blocks: u64,
    search_transaction_history: bool,
) !u64 {
    return try self.pollForSignatureConfirmationWithTimeouts(
        signature,
        min_confirmed_blocks,
        search_transaction_history,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendTransactionAndConfirm(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const signature = try self.sendTransaction(signed_tx_base64, options);
    errdefer self.allocator.free(signature);

    try waitForSignatureStatusWithInitialTimeout(
        self,
        signature,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
        true,
        self.getConfirmTransactionInitialTimeoutMs(),
        null,
    );

    return signature;
}

fn sendTransactionAndConfirmWithSpinnerInternal(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const signature = try self.sendTransaction(signed_tx_base64, options);
    errdefer self.allocator.free(signature);

    var spinner = SpinnerReporter.initSend(signature, self.resolveCommitment(commitment));
    try waitForSignatureStatusWithInitialTimeout(
        self,
        signature,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
        true,
        self.getConfirmTransactionInitialTimeoutMs(),
        &spinner,
    );

    return signature;
}

pub fn sendAndConfirmTransactionWithSpinner(self: anytype, signed_tx_base64: []const u8) ![]const u8 {
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        signed_tx_base64,
        null,
        null,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithSpinnerAndCommitment(
    self: anytype,
    signed_tx_base64: []const u8,
    commitment: Commitment,
) ![]const u8 {
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        signed_tx_base64,
        null,
        commitment,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithSpinnerAndConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        signed_tx_base64,
        options,
        null,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn sendAndConfirmTransactionWithSpinnerAndCommitmentAndConfig(
    self: anytype,
    signed_tx_base64: []const u8,
    commitment: Commitment,
    options: ?SendTransactionOptions,
) ![]const u8 {
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        signed_tx_base64,
        options,
        commitment,
        false,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn confirmTransactionWithSpinner(
    self: anytype,
    signature: []const u8,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
) !void {
    return try self.confirmTransactionWithSpinnerAndTimeouts(
        signature,
        recent_blockhash,
        commitment,
        poll_for_signature_confirmation_timeout_ms,
        signature_poll_interval_ms,
    );
}

pub fn confirmTransactionWithSpinnerAndTimeouts(
    self: anytype,
    signature: []const u8,
    recent_blockhash: []const u8,
    commitment: ?Commitment,
    timeout_ms: u64,
    poll_interval_ms: u64,
) !void {
    const initial_timeout_ms = self.getConfirmTransactionInitialTimeoutMs() orelse 0;
    const initial_deadline = std.time.milliTimestamp() + @as(i64, @intCast(initial_timeout_ms));
    const resolved_commitment = self.resolveCommitment(commitment);
    var spinner = SpinnerReporter.initConfirm(signature, resolved_commitment);

    while (true) {
        const observed_status = self.getSignatureStatusWithOptions(
            signature,
            .{ .commitment = .processed },
        ) catch |err| switch (err) {
            error.TransactionNotFound => null,
            else => return err,
        };

        if (observed_status) |status| {
            defer if (status.confirmation_status) |value| self.allocator.free(value);

            if (status.has_error) return error.TransactionFailed;
            if (confirmationSatisfiesCommitment(status.confirmation_status, resolved_commitment)) {
                spinner.transition(.confirmed);
                return;
            }
            spinner.transition(.waiting_for_commitment);
            break;
        }

        spinner.transition(.waiting_for_observation);

        const blockhash_still_valid = try self.isBlockhashValid(recent_blockhash, .processed);
        if (!blockhash_still_valid and std.time.milliTimestamp() >= initial_deadline) {
            return error.BlockhashExpired;
        }

        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    const confirmation_deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));
    while (std.time.milliTimestamp() < confirmation_deadline) {
        const status = self.getSignatureStatusWithOptions(
            signature,
            if (resolved_commitment != null)
                SignatureStatusesQueryOptions{ .commitment = resolved_commitment }
            else
                null,
        ) catch |err| switch (err) {
            error.TransactionNotFound => {
                std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
                continue;
            },
            else => return err,
        };
        defer if (status.confirmation_status) |value| self.allocator.free(value);

        if (status.has_error) return error.TransactionFailed;
        if (confirmationSatisfiesCommitment(status.confirmation_status, resolved_commitment)) {
            spinner.transition(.confirmed);
            return;
        }

        spinner.transition(.waiting_for_commitment);
        std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
    }

    return error.TransactionNotConfirmed;
}

pub fn sendTransactionAndConfirmTyped(
    self: anytype,
    transaction: SignedLegacyTransaction,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.sendTransactionAndConfirm(
        encoded,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendTransactionAndConfirmTypedWithSpinner(
    self: anytype,
    transaction: SignedLegacyTransaction,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        encoded,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionTyped(
    self: anytype,
    transaction: SignedVersionedTransaction,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try self.sendTransactionAndConfirm(
        encoded,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionTypedWithSpinner(
    self: anytype,
    transaction: SignedVersionedTransaction,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    const encoded = try transaction.toBase64(self.allocator);
    defer self.allocator.free(encoded);
    return try sendTransactionAndConfirmWithSpinnerInternal(
        self,
        encoded,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransaction(
    self: anytype,
    transaction: LegacyTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendTransactionAndConfirmTyped(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmLegacyTransactionWithSpinner(
    self: anytype,
    transaction: LegacyTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendTransactionAndConfirmTypedWithSpinner(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransaction(
    self: anytype,
    transaction: VersionedTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendAndConfirmVersionedTransactionTyped(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}

pub fn sendAndConfirmVersionedTransactionWithSpinner(
    self: anytype,
    transaction: VersionedTransaction,
    signers: []const sdk.Keypair,
    options: ?SendTransactionOptions,
    commitment: ?Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    var signed = try transaction.sign(self.allocator, signers);
    defer signed.deinit(self.allocator);
    return try self.sendAndConfirmVersionedTransactionTypedWithSpinner(
        signed,
        options,
        commitment,
        search_transaction_history,
        timeout_ms,
        poll_interval_ms,
    );
}
