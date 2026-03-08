const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

const RpcClient = client.RpcClient;
const Keypair = client.Keypair;
const Pubkey = client.Pubkey;
const Hash = client.Hash;
const Instruction = client.Instruction;
const LegacyTransaction = client.LegacyTransaction;
const SystemProgram = client.SystemProgram;
const CompiledInstruction = client.CompiledInstruction;
const MessageAddressTableLookup = client.MessageAddressTableLookup;
const VersionedTransaction = client.VersionedTransaction;
const VersionedMessageV0 = client.VersionedMessageV0;
const max_lockout_history = client.max_lockout_history;
const confirmationSatisfiesCommitment = client.confirmationSatisfiesCommitment;
const encodeBase58 = client.encodeBase58;

test "root.send delegates to sendTransaction" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"Sig111111111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.send("SignedTransactionBase64==");
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, "SignedTransactionBase64==") != null);
}

test "root.sendTransactionTyped serializes signed legacy transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigTyped111111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendTransactionTyped(
        signed,
        .{
            .skip_preflight = true,
            .preflight_commitment = .confirmed,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigTyped111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.sendLegacyTransaction signs and serializes legacy transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    const encoded = try transaction.toBase64(allocator, &.{keypair});
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigLegacy11111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendLegacyTransaction(transaction, &.{keypair}, .{ .skip_preflight = true });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigLegacy11111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
}

test "root.sendAndConfirmTransaction aliases wait on signature status" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockSignatureResult("Sig111111111111111111111111111111111111111111111111111111111111111111");
    try rpc.pushMockSingleSignatureStatusResult(10, .{
        .slot = 10,
        .confirmations = 1,
        .confirmation_status = "processed",
        .has_error = false,
    });

    const signature = try rpc.sendAndConfirmTransaction("SignedTransactionBase64==");
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
}

test "root.mock latest blockhash send and status flow helper covers common send path" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockLatestBlockhashSendAndSingleSignatureStatusFlow(
        30,
        "BH11111111111111111111111111111111111111111111",
        88,
        "SigFlow1111111111111111111111111111111111111111111111111111111111111",
        31,
        .{
            .slot = 31,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        },
    );

    const latest = try rpc.getLatestBlockhashResponse(.confirmed);
    defer allocator.free(latest.value.blockhash);
    try std.testing.expectEqual(@as(u64, 30), latest.context_slot);
    try std.testing.expectEqualStrings(
        "BH11111111111111111111111111111111111111111111",
        latest.value.blockhash,
    );
    try std.testing.expectEqual(@as(u64, 88), latest.value.last_valid_block_height);

    const signature = try rpc.sendTransaction("SignedTransactionBase64==", null);
    defer allocator.free(signature);
    try std.testing.expectEqualStrings(
        "SigFlow1111111111111111111111111111111111111111111111111111111111111",
        signature,
    );

    const statuses = try rpc.getSignatureStatusesWithOptions(&.{signature}, .{
        .search_transaction_history = true,
        .commitment = .confirmed,
    });
    defer {
        for (statuses) |maybe_status| {
            if (maybe_status) |status| {
                if (status.confirmation_status) |value| allocator.free(value);
            }
        }
        allocator.free(statuses);
    }

    try std.testing.expectEqual(@as(usize, 1), statuses.len);
    try std.testing.expect(statuses[0] != null);
    try std.testing.expectEqual(@as(?u64, 31), statuses[0].?.slot);
    try std.testing.expectEqualStrings("confirmed", statuses[0].?.confirmation_status.?);
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
}

test "root.mock send and status poll flow helper covers repeated confirmation polling" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigPollFlow111111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 40, .status = null },
            .{ .context_slot = 41, .status = .{
                .slot = 41,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 42, .status = .{
                .slot = 42,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendTransactionAndConfirm(
        "SignedTransactionBase64==",
        null,
        .confirmed,
        false,
        200,
        0,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigPollFlow111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[3].method);
}

test "root.mock signature status helpers cover not-found and errored results" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    try rpc.pushMockSignatureStatusesResult(21, &.{
        null,
        .{
            .slot = 22,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = true,
        },
    });

    const statuses = try rpc.getSignatureStatusesWithOptions(
        &.{
            "SigA111111111111111111111111111111111111",
            "SigB111111111111111111111111111111111111",
        },
        null,
    );
    defer {
        for (statuses) |maybe_status| {
            if (maybe_status) |status| {
                if (status.confirmation_status) |value| allocator.free(value);
            }
        }
        allocator.free(statuses);
    }

    try std.testing.expectEqual(@as(usize, 2), statuses.len);
    try std.testing.expect(statuses[0] == null);
    try std.testing.expect(statuses[1] != null);
    try std.testing.expectEqual(@as(?u64, 22), statuses[1].?.slot);
    try std.testing.expectEqual(@as(?u64, 2), statuses[1].?.confirmations);
    try std.testing.expectEqualStrings("confirmed", statuses[1].?.confirmation_status.?);
    try std.testing.expect(statuses[1].?.has_error);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[0].method);
}

test "root.sendTransactionAndConfirmTyped submits and confirms signed legacy transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigTypedConfirm11111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 10, .status = .{
                .slot = 10,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendTransactionAndConfirmTyped(
        signed,
        .{ .skip_preflight = true },
        null,
        true,
        2_000,
        20,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigTypedConfirm11111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":true") != null);
}

test "root.sendTransactionAndConfirm uses initial transaction-not-found timeout from constructor" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMockWithTimeoutsAndCommitment(
        allocator,
        &.{},
        40,
        80,
        null,
    );
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigInitialTimeout111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 10, .status = null },
            .{ .context_slot = 11, .status = null },
            .{ .context_slot = 12, .status = .{
                .slot = 12,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendTransactionAndConfirm(
        "SignedTransactionBase64==",
        null,
        null,
        false,
        40,
        20,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigInitialTimeout111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[3].method);
}

test "root.sendAndConfirmTransactionWithSpinner prints progress and honors config" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMockWithTimeoutsAndCommitment(
        allocator,
        &.{},
        200,
        80,
        null,
    );
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigSpinner11111111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 10, .status = null },
            .{ .context_slot = 11, .status = .{
                .slot = 11,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 12, .status = .{
                .slot = 12,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.sendAndConfirmTransactionWithSpinnerAndCommitmentAndConfig(
        "SignedTransactionBase64==",
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigSpinner11111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[3].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigSpinner11111111111111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigSpinner11111111111111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigSpinner11111111111111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigSpinner11111111111111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.confirmTransactionWithSpinner waits for observation then commitment" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMockWithTimeoutsAndCommitment(
        allocator,
        &.{},
        200,
        80,
        null,
    );
    defer rpc.deinit();
    try rpc.pushMockConfirmTransactionSpinnerFlow(
        &.{
            .{
                .context_slot = 10,
                .status = null,
                .blockhash_still_valid = true,
            },
            .{
                .context_slot = 12,
                .status = .{
                    .slot = 12,
                    .confirmations = 1,
                    .confirmation_status = "processed",
                    .has_error = false,
                },
            },
        },
        &.{
            .{
                .context_slot = 13,
                .status = .{
                    .slot = 13,
                    .confirmations = 2,
                    .confirmation_status = "confirmed",
                    .has_error = false,
                },
            },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    try rpc.confirmTransactionWithSpinnerAndTimeouts(
        "SigConfirmSpinner11111111111111111111111111111111111111111111111111111111",
        "BlockhashConfirmSpinner1111111111111111111111111111111111111",
        .confirmed,
        200,
        20,
    );

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
    try std.testing.expectEqualStrings("isBlockhashValid", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[3].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings(
        \\confirming transaction: SigConfirmSpinner11111111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigConfirmSpinner11111111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigConfirmSpinner11111111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigConfirmSpinner11111111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.confirmTransactionWithSpinner returns blockhash expired when not observed" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMockWithTimeoutsAndCommitment(
        allocator,
        &.{},
        200,
        0,
        null,
    );
    defer rpc.deinit();
    try rpc.pushMockConfirmTransactionSpinnerFlow(
        &.{
            .{
                .context_slot = 10,
                .status = null,
                .blockhash_still_valid = false,
            },
        },
        &.{},
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    try std.testing.expectError(
        error.BlockhashExpired,
        rpc.confirmTransactionWithSpinnerAndTimeouts(
            "SigExpiredSpinner111111111111111111111111111111111111111111111111111111",
            "BlockhashExpiredSpinner11111111111111111111111111111111111111",
            .confirmed,
            200,
            20,
        ),
    );

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 1024);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        \\confirming transaction: SigExpiredSpinner111111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigExpiredSpinner111111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.sendAndConfirmTransactionWithConfig supports send options" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "Sig222222222222222222222222222222222222222222222222222222222222222222",
        &.{
            .{ .context_slot = 11, .status = .{
                .slot = 11,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendAndConfirmTransactionWithConfig(
        "SignedTransactionBase64==",
        .{ .skip_preflight = true },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig222222222222222222222222222222222222222222222222222222222222222222",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
}

test "root.sendAndConfirmTransactionWithCommitmentAndConfig supports both commitment and send options" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "Sig333333333333333333333333333333333333333333333333333333333333333333",
        &.{
            .{ .context_slot = 12, .status = .{
                .slot = 12,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendAndConfirmTransactionWithCommitmentAndConfig(
        "SignedTransactionBase64==",
        .confirmed,
        .{ .skip_preflight = true },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig333333333333333333333333333333333333333333333333333333333333333333",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.sendAndConfirmTransactionWithCommitment requires commitment-aware confirmation" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "Sig333333333333333333333333333333333333333333333333333333333333333333",
        &.{
            .{ .context_slot = 12, .status = .{
                .slot = 12,
                .confirmations = 1,
                .confirmation_status = "finalized",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendAndConfirmTransactionWithCommitment(
        "SignedTransactionBase64==",
        .confirmed,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig333333333333333333333333333333333333333333333333333333333333333333",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.pollGetBalanceWithCommitmentAndTimeouts retries until success" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockRpcError(.{
        .code = -32000,
        .message = "node behind",
    });
    try rpc.pushMockBalanceResponse(44, 77);

    const balance = try rpc.pollGetBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        .confirmed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 77), balance);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getBalance", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getBalance", rpc.capturedMockRequests()[1].method);
}

test "root.waitForBalanceWithCommitmentAndTimeouts waits for expected value" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockBalancePollResults(&.{
        .{ .context_slot = 45, .value = 1 },
        .{ .context_slot = 46, .value = 5 },
    });

    const balance = try rpc.waitForBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        5,
        .processed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 5), balance);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
}

test "root.confirmTransaction checks transaction confirmed status" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSignatureStatusPollResults(&.{
        .{ .context_slot = 10, .status = .{
            .slot = 10,
            .confirmations = 1,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
    });

    const confirmed = try rpc.confirmTransaction("Sig111111111111111111111111111111111111", .confirmed, false);
    try std.testing.expect(confirmed);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.confirmTransaction returns false for missing signature" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSignatureStatusNotFound(1);

    const confirmed = try rpc.confirmTransaction("Sig111111111111111111111111111111111111", .processed, false);
    try std.testing.expect(!confirmed);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.pollForSignatureConfirmationWithTimeouts waits for configured lockout" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSignatureStatusPollResults(&.{
        .{ .context_slot = 21, .status = .{
            .slot = 21,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
        .{ .context_slot = 22, .status = .{
            .slot = 22,
            .confirmations = 3,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
        .{ .context_slot = 23, .status = .{
            .slot = 23,
            .confirmations = 10,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
    });

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        false,
        500,
        10,
    );
    try std.testing.expectEqual(@as(u64, 10), confirmed_blocks);
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
}

test "root.pollForSignatureConfirmationWithCommitmentAndTimeouts waits for commitment level" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSignatureStatusPollResults(&.{
        .{ .context_slot = 31, .status = .{
            .slot = 31,
            .confirmations = 1,
            .confirmation_status = "confirmed",
            .has_error = false,
        } },
        .{ .context_slot = 32, .status = .{
            .slot = 32,
            .confirmations = 10,
            .confirmation_status = "finalized",
            .has_error = false,
        } },
    });

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithCommitmentAndTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        .finalized,
        false,
        500,
        10,
    );
    try std.testing.expectEqual(@as(u64, 10), confirmed_blocks);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
}

test "root.pollForSignature returns on failed signature" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSignatureStatusPollResults(&.{
        .{ .context_slot = 41, .status = .{
            .slot = 41,
            .confirmations = 1,
            .confirmation_status = "processed",
            .has_error = true,
        } },
    });

    try rpc.pollForSignature(
        "Sig111111111111111111111111111111111111",
        null,
        false,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.pollForSignatureConfirmation returns partial confirmations on timeout" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    for (0..20) |_| {
        try rpc.pushMockSingleSignatureStatusResult(41, .{
            .slot = 41,
            .confirmations = 3,
            .confirmation_status = "processed",
            .has_error = false,
        });
    }

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        false,
        100,
        10,
    );
    try std.testing.expectEqual(@as(u64, 3), confirmed_blocks);
    try std.testing.expect(rpc.mockRequestCount() >= 1);
}

test "root.getNumBlocksSinceSignatureConfirmation returns lockout fallback when confirmations missing" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSingleSignatureStatusResult(31, .{
        .slot = 31,
        .confirmation_status = "confirmed",
        .has_error = false,
    });

    const confirmed_blocks = try rpc.getNumBlocksSinceSignatureConfirmation("Sig111111111111111111111111111111111111", false);
    try std.testing.expectEqual(@as(u64, max_lockout_history + 1), confirmed_blocks);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.getNumBlocksSinceSignatureConfirmationWithCommitment passes commitment into signature status query" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSingleSignatureStatusResult(31, .{
        .slot = 31,
        .confirmation_status = "confirmed",
        .has_error = false,
    });

    const confirmed_blocks = try rpc.getNumBlocksSinceSignatureConfirmationWithCommitment(
        "Sig111111111111111111111111111111111111",
        .confirmed,
        false,
    );
    try std.testing.expectEqual(@as(u64, max_lockout_history + 1), confirmed_blocks);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getTransactionWithConfig returns decoded transaction json" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"transaction\":\"abc\",\"meta\":{\"err\":null}}},\"id\":1}" },
    });
    defer rpc.deinit();

    const tx_json = try rpc.getTransactionWithConfig(
        "Sig111111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(tx_json.?);

    try std.testing.expect(std.mem.indexOf(u8, tx_json.?, "abc") != null);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
}

test "root.simulateTransactionWithConfig delegates to simulateTransaction" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}" },
    });
    defer rpc.deinit();

    const result = try rpc.simulateTransactionWithConfig("signed-transaction-base64", null);
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
}

test "root.simulateTransactionTyped serializes signed legacy transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}" },
    });
    defer rpc.deinit();

    const result = try rpc.simulateTransactionTyped(
        signed,
        .{ .sig_verify = true, .replace_recent_blockhash = true },
    );
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"replaceRecentBlockhash\":true") != null);
}

test "root.simulateLegacyTransaction signs and serializes legacy transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    const encoded = try transaction.toBase64(allocator, &.{keypair});
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}" },
    });
    defer rpc.deinit();

    const result = try rpc.simulateLegacyTransaction(transaction, &.{keypair}, .{ .sig_verify = true });
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"sigVerify\":true") != null);
}

test "root.buildTransferTransactionWithOptions fetches latest blockhash" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":9}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":55}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const encoded_transaction = try rpc.buildTransferTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(encoded_transaction);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);

    const tx_bytes_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded_transaction);
    var tx_bytes = try allocator.alloc(u8, tx_bytes_len);
    defer allocator.free(tx_bytes);
    try std.base64.standard.Decoder.decode(tx_bytes, encoded_transaction);

    const message = tx_bytes[1 + Ed25519.Signature.encoded_length ..];
    try std.testing.expect(std.mem.eql(u8, message[100..132], &recent_blockhash));
}

test "root.buildTransferSignedTransactionWithOptions fetches latest blockhash" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":9}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":55}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildTransferSignedTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const tx_bytes = try signed.serialize(allocator);
    defer allocator.free(tx_bytes);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);

    const message = tx_bytes[1 + Ed25519.Signature.encoded_length ..];
    try std.testing.expect(std.mem.eql(u8, message[100..132], &recent_blockhash));
}

test "root.buildTransferSignedTransactionWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_key_pair.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_account_key_pair.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x52} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildTransferSignedTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferTransactionWithNonce(
        allocator,
        &sender_secret_key,
        &nonce_account_pubkey,
        &destination_public_key,
        &nonce_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expect(std.mem.eql(u8, expected, encoded));
}

test "root.buildVersionedTransferSignedTransactionWithOptions fetches latest blockhash" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildVersionedTransferSignedTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const tx_bytes = try signed.serialize(allocator);
    defer allocator.free(tx_bytes);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);

    const message = tx_bytes[1 + Ed25519.Signature.encoded_length ..];
    try std.testing.expectEqual(@as(u8, 0x80), message[0]);
    const recent_blockhash_offset = 1 + 3 + 1 + (3 * Ed25519.PublicKey.encoded_length);
    try std.testing.expect(std.mem.eql(u8, message[recent_blockhash_offset .. recent_blockhash_offset + 32], &recent_blockhash));
}

test "root.buildVersionedTransferSignedTransactionWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x44} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildVersionedTransferSignedTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected = try client.buildVersionedNonceTransferTransactionBase64(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
        &.{sender},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.buildVersionedTransferMessageBase64WithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x46} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const encoded = try rpc.buildVersionedTransferMessageBase64WithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
    );
    defer allocator.free(encoded);

    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_bytes = try client.buildVersionedTransferMessageBytesWithNonce(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.buildOwnedVersionedTransferMessageWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x48} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var owned = try rpc.buildOwnedVersionedTransferMessageWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedTransferMessageBase64WithNonce(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.buildVersionedNonceTransferMessageBase64 returns nonce-aware versioned message" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x54} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const encoded = try rpc.buildVersionedNonceTransferMessageBase64(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
        &.{},
    );
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const expected_bytes = try client.buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedNonceTransferMessageBase64WithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x55} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const encoded = try rpc.buildVersionedNonceTransferMessageBase64WithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        &.{},
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const expected_bytes = try client.buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(nonce_blockhash),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.buildOwnedVersionedNonceTransferMessageWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x5a} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var owned = try rpc.buildOwnedVersionedNonceTransferMessageWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        &.{},
        .{ .blockhash_commitment = .confirmed },
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.buildVersionedNonceTransferMessageBase64 builds distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const recent_blockhash = [_]u8{0x56} ** 32;

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_raw.secret_key.toBytes());
    const sender = try Keypair.fromSecretKeyBytes(sender_raw.secret_key.toBytes());
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const encoded = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination,
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(sender.public_key, destination, 1_000);
    const instructions = [_]Instruction{transfer.instruction()};
    const expected_bytes = try client.buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        fee_payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedNonceTransferTransactionBase64WithSender builds distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const recent_blockhash = [_]u8{0x57} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const nonce_account = Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const encoded = try client.buildVersionedNonceTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination,
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(sender.public_key, destination, 1_000);
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        fee_payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildVersionedTransferTransaction with fixed blockhash returns versioned payload" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x22} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const encoded = try rpc.buildVersionedTransferTransaction(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
        &.{},
    );
    defer allocator.free(encoded);

    const tx_bytes_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
    var tx_bytes = try allocator.alloc(u8, tx_bytes_len);
    defer allocator.free(tx_bytes);
    try std.base64.standard.Decoder.decode(tx_bytes, encoded);

    const message = tx_bytes[1 + Ed25519.Signature.encoded_length ..];
    const recent_blockhash_offset = 1 + 3 + 1 + (3 * Ed25519.PublicKey.encoded_length);
    const decoded_recent_blockhash = message[recent_blockhash_offset .. recent_blockhash_offset + 32];
    try std.testing.expect(std.mem.eql(u8, decoded_recent_blockhash, &recent_blockhash));
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.buildVersionedMessageBase64 with fixed blockhash returns compiled v0 message" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const payer = Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const recent_blockhash = [_]u8{0x24} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const transfer = SystemProgram.transfer(
        payer,
        destination,
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};

    const encoded = try rpc.buildVersionedMessageBase64(
        payer,
        instructions[0..],
        &.{},
        recent_blockhash_base58,
    );
    defer allocator.free(encoded);

    const expected = try client.buildVersionedMessageV0Base64(
        allocator,
        payer,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.buildVersionedTransactionV0Base64WithNonceInstructions prepends nonce advance" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_raw.public_key.toBytes());
    const recent_blockhash = Hash.fromBytes(.{0x26} ** 32);

    const transfer = SystemProgram.transfer(
        payer.public_key,
        destination,
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};

    const encoded = try client.buildVersionedTransactionV0Base64WithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        payer.public_key,
        recent_blockhash,
        instructions[0..],
        &.{},
        &.{payer},
    );
    defer allocator.free(encoded);

    var owned_instructions = try client.prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        payer.public_key,
        instructions[0..],
    );
    defer owned_instructions.deinit(allocator);

    var expected = try client.buildSignedVersionedTransactionV0(
        allocator,
        payer.public_key,
        recent_blockhash,
        owned_instructions.instructions,
        &.{},
        &.{payer},
    );
    defer expected.deinit(allocator);

    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildVersionedNonceTransferTransactionBase64 builds nonce-aware transfer transaction" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_raw.public_key.toBytes());
    const recent_blockhash = Hash.fromBytes(.{0x28} ** 32);

    const encoded = try client.buildVersionedNonceTransferTransactionBase64(
        allocator,
        payer.public_key,
        nonce_account,
        payer.public_key,
        destination,
        recent_blockhash,
        2_000,
        &.{},
        &.{payer},
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        payer.public_key,
        destination,
        2_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var owned_instructions = try client.prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        payer.public_key,
        instructions[0..],
    );
    defer owned_instructions.deinit(allocator);

    var expected = try client.buildSignedVersionedTransactionV0(
        allocator,
        payer.public_key,
        recent_blockhash,
        owned_instructions.instructions,
        &.{},
        &.{payer},
    );
    defer expected.deinit(allocator);

    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildVersionedTransferMessageBase64WithNonce prepends nonce advance" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const payer = Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_raw.public_key.toBytes());
    const recent_blockhash = Hash.fromBytes(.{0x2a} ** 32);

    const encoded = try client.buildVersionedTransferMessageBase64WithNonce(
        allocator,
        payer,
        nonce_account,
        payer,
        destination,
        recent_blockhash,
        3_000,
        &.{},
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        payer,
        destination,
        3_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var owned_instructions = try client.prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        payer,
        instructions[0..],
    );
    defer owned_instructions.deinit(allocator);

    const expected = try client.buildVersionedMessageV0Base64(
        allocator,
        payer,
        recent_blockhash,
        owned_instructions.instructions,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildOwnedVersionedTransferMessageWithNonce prepends nonce advance" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const payer = Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_raw.public_key.toBytes());
    const recent_blockhash = Hash.fromBytes(.{0x45} ** 32);

    var owned = try client.buildOwnedVersionedTransferMessageWithNonce(
        allocator,
        payer,
        nonce_account,
        payer,
        destination,
        recent_blockhash,
        1_000,
        &.{},
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedTransferMessageBase64WithNonce(
        allocator,
        payer,
        nonce_account,
        payer,
        destination,
        recent_blockhash,
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.sendVersionedTransferWithOptions resolves latest blockhash and sends" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = latest_blockhash_json },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigVersioned111111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendVersionedTransferWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{
                .skip_preflight = true,
                .preflight_commitment = .confirmed,
            },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersioned111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.versionedTransferWithOptions resolves blockhash and confirms" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x22} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        11,
        recent_blockhash_base58,
        42,
        "SigVersionedConfirm111111111111111111111111111111111111111111111111111111111",
        &.{
            .{
                .context_slot = 10,
                .status = .{
                    .slot = 10,
                    .confirmations = 1,
                    .confirmation_status = "finalized",
                    .has_error = false,
                },
            },
        },
    );

    const signature = try rpc.versionedTransferWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{
                .skip_preflight = true,
            },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 2_000,
            .poll_interval_ms = 20,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedConfirm111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
}

test "root.buildSignedVersionedTransactionWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_keypair = try Keypair.fromSecretKeyBytes(payer_secret_key);
    const destination_pubkey = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &payer_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_blockhash = [_]u8{0x52} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const transfer_instruction = SystemProgram.transfer(
        payer_keypair.public_key,
        destination_pubkey,
        1_000,
    );
    const instructions = [_]Instruction{transfer_instruction.instruction()};

    var signed = try rpc.buildSignedVersionedTransactionWithOptions(
        payer_keypair.public_key,
        instructions[0..],
        &.{},
        &.{payer_keypair},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
            .nonce_authority = payer_keypair.public_key,
        },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var owned_instructions = try client.prependNonceAdvanceInstruction(
        allocator,
        Pubkey.fromBytes(nonce_account_pubkey),
        payer_keypair.public_key,
        instructions[0..],
    );
    defer owned_instructions.deinit(allocator);

    var expected = try client.buildSignedVersionedTransactionV0(
        allocator,
        payer_keypair.public_key,
        Hash.fromBytes(nonce_blockhash),
        owned_instructions.instructions,
        &.{},
        &.{payer_keypair},
    );
    defer expected.deinit(allocator);

    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.sendVersionedInstructionsWithOptions resolves latest blockhash and sends" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_keypair = try Keypair.fromSecretKeyBytes(payer_secret_key);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_pubkey = Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = latest_blockhash_json },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigVersionedInstructions11111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const transfer_instruction = SystemProgram.transfer(
        payer_keypair.public_key,
        destination_pubkey,
        1_000,
    );
    const instructions = [_]Instruction{transfer_instruction.instruction()};

    const signature = try rpc.sendVersionedInstructionsWithOptions(
        payer_keypair.public_key,
        instructions[0..],
        &.{},
        &.{payer_keypair},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{
                .skip_preflight = true,
                .preflight_commitment = .confirmed,
            },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedInstructions11111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.getFeeForVersionedInstructionsWithOptions compiles message and requests fee" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const payer_pubkey = Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const destination_pubkey = Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const recent_blockhash = [_]u8{0x12} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const transfer_instruction = SystemProgram.transfer(
        payer_pubkey,
        destination_pubkey,
        1_000,
    );
    const instructions = [_]Instruction{transfer_instruction.instruction()};

    const expected_message = try client.buildVersionedMessageV0Base64(
        allocator,
        payer_pubkey,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":5000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForVersionedInstructionsWithOptions(
        payer_pubkey,
        instructions[0..],
        &.{},
        .{ .recent_blockhash = recent_blockhash_base58 },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForVersionedTransferMessageWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x47} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    const expected_message = try client.buildVersionedTransferMessageBase64WithNonce(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":44},\"value\":9000},\"id\":1}",
    );

    const fee = try rpc.getFeeForVersionedTransferMessageWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 9000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.buildNonceTransferSignedTransactionWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x52} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const expected = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(expected);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualSlices(u8, expected, encoded);
}

test "root.buildLegacyNonceTransferMessageBase64 builds distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const encoded = try client.buildLegacyNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x56} ** 32),
        1_000,
    );
    defer allocator.free(encoded);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x56} ** 32),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyTransferMessageBase64WithNonce reuses same-role nonce helper" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const encoded = try client.buildLegacyTransferMessageBase64WithNonce(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x57} ** 32),
        1_000,
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x57} ** 32),
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildOwnedLegacyTransferMessage builds same-role payer sender message" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    var owned = try client.buildOwnedLegacyTransferMessage(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5a} ** 32),
        1_000,
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5a} ** 32),
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyTransferTransactionBase64 builds same-role payer sender transaction" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    const encoded = try client.buildLegacyTransferTransactionBase64(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5b} ** 32),
        1_000,
        &.{sender},
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        sender.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5b} ** 32),
        1_000,
        &.{sender},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyMessageBase64WithNonceInstructions prepends nonce advance" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const transfer = SystemProgram.transfer(
        Pubkey.fromBytes(payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};

    const encoded = try client.buildLegacyMessageBase64WithNonceInstructions(
        allocator,
        Pubkey.fromBytes(payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5e} ** 32),
        instructions[0..],
    );
    defer allocator.free(encoded);

    var expected_owned = try client.buildOwnedLegacyMessageWithNonceInstructions(
        allocator,
        Pubkey.fromBytes(payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5e} ** 32),
        instructions[0..],
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyTransactionBase64WithNonceInstructions signs prepended nonce advance" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const payer = try Keypair.fromSecretKeyBytes(payer_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);

    const transfer = SystemProgram.transfer(
        payer.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};

    const encoded = try client.buildLegacyTransactionBase64WithNonceInstructions(
        allocator,
        payer.public_key,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        nonce_authority.public_key,
        Hash.fromBytes(.{0x5f} ** 32),
        instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer allocator.free(encoded);

    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer.public_key,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        nonce_authority.public_key,
        Hash.fromBytes(.{0x5f} ** 32),
        instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer expected_signed.deinit(allocator);
    const expected = try expected_signed.toBase64(allocator);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildOwnedLegacyTransferMessageWithNonce reuses same-role nonce helper" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    var owned = try client.buildOwnedLegacyTransferMessageWithNonce(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x58} ** 32),
        1_000,
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildLegacyNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x58} ** 32),
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyTransferTransactionBase64WithNonce reuses same-role nonce helper" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    const encoded = try client.buildLegacyTransferTransactionBase64WithNonce(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x59} ** 32),
        1_000,
        &.{sender},
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        sender.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x59} ** 32),
        1_000,
        &.{sender},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildNonceTransferMessageBase64WithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x54} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const encoded = try rpc.buildNonceTransferMessageBase64WithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.buildOwnedLegacyTransferMessageWithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = Hash.fromBytes(.{0x45} ** 32);

    var owned = try client.buildOwnedLegacyTransferMessageWithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        recent_blockhash,
        1_000,
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const expected = try client.buildLegacyMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        recent_blockhash,
        instructions[0..],
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildTransferMessageBase64 builds fixed blockhash message" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x70} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const encoded = try rpc.buildTransferMessageBase64(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.buildOwnedTransferMessageWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x71} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var owned = try rpc.buildOwnedTransferMessageWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
        },
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
}

test "root.buildLegacyTransferMessageBase64WithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = Hash.fromBytes(.{0x46} ** 32);

    const encoded = try client.buildLegacyTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        recent_blockhash,
        1_000,
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const expected = try client.buildLegacyMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        recent_blockhash,
        instructions[0..],
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildLegacyTransferTransactionBase64WithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = Hash.fromBytes(.{0x47} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    const encoded = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        recent_blockhash,
        1_000,
        &.{ fee_payer, sender },
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedLegacyTransaction(
        allocator,
        fee_payer.public_key,
        recent_blockhash,
        instructions[0..],
        &.{ fee_payer, sender },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildVersionedNonceTransferSignedTransactionWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x53} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildVersionedNonceTransferSignedTransactionWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        1_000,
        &.{},
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(nonce_blockhash),
        instructions[0..],
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildOwnedVersionedNonceTransferMessage builds distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    var owned = try client.buildOwnedVersionedNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x46} ** 32),
        1_000,
        &.{},
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x46} ** 32),
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedTransferMessageBase64WithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = Hash.fromBytes(.{0x47} ** 32);

    const encoded = try client.buildVersionedTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        recent_blockhash,
        1_000,
        &.{},
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    const expected = try client.buildVersionedMessageV0Base64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        recent_blockhash,
        instructions[0..],
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedTransferTransactionBase64WithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = Hash.fromBytes(.{0x48} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    const encoded = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        recent_blockhash,
        1_000,
        &.{},
        &.{ fee_payer, sender },
    );
    defer allocator.free(encoded);

    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0(
        allocator,
        fee_payer.public_key,
        recent_blockhash,
        instructions[0..],
        &.{},
        &.{ fee_payer, sender },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildSignedVersionedTransferTransaction builds same-role payer sender transaction" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    var signed = try client.buildSignedVersionedTransferTransaction(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5c} ** 32),
        1_000,
        &.{},
        &.{sender},
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        sender.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5c} ** 32),
        1_000,
        &.{},
        &.{sender},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedTransferTransactionBase64 builds same-role payer sender transaction" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);

    const encoded = try client.buildVersionedTransferTransactionBase64(
        allocator,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5d} ** 32),
        1_000,
        &.{},
        &.{sender},
    );
    defer allocator.free(encoded);

    const expected = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        sender.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_raw.public_key.toBytes()),
        Hash.fromBytes(.{0x5d} ** 32),
        1_000,
        &.{},
        &.{sender},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.buildVersionedTransferSignedTransactionWithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x5b} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildVersionedTransferSignedTransactionWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    var expected = try client.buildSignedVersionedNonceTransferTransactionWithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
        &.{ fee_payer, sender },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.buildTransferSignedTransactionWithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x60} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var signed = try rpc.buildTransferSignedTransactionWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.buildTransferMessageBase64WithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x63} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    const encoded = try rpc.buildTransferMessageBase64WithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
        },
    );
    defer allocator.free(encoded);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.buildTransferMessageBase64WithSender builds distinct payer and sender" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x64} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const encoded = try rpc.buildTransferMessageBase64WithSender(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
}

test "root.sendTransferWithSenderAndOptions resolves latest blockhash and sends" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x61} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = latest_blockhash_json },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigLegacyWithSender1111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendTransferWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigLegacyWithSender1111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
}

test "root.transferWithSenderAndOptions fetches latest blockhash and confirms" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x62} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_json);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigLegacyWithSenderConfirm1111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.transferWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigLegacyWithSenderConfirm1111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.sendVersionedTransferWithSenderAndOptions resolves latest blockhash and sends" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x5c} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);
    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = latest_blockhash_json },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigVersionedWithSender11111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendVersionedTransferWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedWithSender11111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
}

test "root.versionedTransferWithSenderAndOptions fetches latest blockhash and confirms" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x5d} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_json = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":11}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":42}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_json);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_json);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedWithSenderConfirm11111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.versionedTransferWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedWithSenderConfirm11111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getFeeForVersionedNonceTransferMessageWithOptions supports fixed blockhash with distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x53} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_message = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        5_000,
        &.{},
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":7000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForVersionedNonceTransferMessageWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        &.{},
        .{ .recent_blockhash = recent_blockhash_base58 },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 7000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForNonceTransferMessageWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x55} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        5_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected_message = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":7000},\"id\":1}",
    );

    const fee = try rpc.getFeeForNonceTransferMessageWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        .{ .blockhash_commitment = .confirmed },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 7000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.transferWithOptions fetches latest blockhash and confirms" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x34} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashSendAndSingleSignatureStatusFlow(
        12,
        recent_blockhash_base58,
        77,
        "Sig555555555555555555555555555555555555555555555555555555555555555555",
        13,
        .{
            .slot = 13,
            .confirmations = 2,
            .confirmation_status = "confirmed",
            .has_error = false,
        },
    );

    const signature = try rpc.transferWithOptions(
        sender_secret_key_base58,
        destination_base58,
        5_000,
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig555555555555555555555555555555555555555555555555555555555555555555",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.transferWithOptions supports nonce blockhash query and confirms" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_key_pair.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_account_key_pair.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x34} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const expected_encoded = try client.buildLegacyTransferTransactionWithNonce(
        allocator,
        &sender_secret_key,
        &nonce_account_pubkey,
        &destination_public_key,
        &nonce_blockhash,
        5_000,
    );
    defer allocator.free(expected_encoded);

    const nonce_account_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(nonce_account_response);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(nonce_account_response);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "Sig999999999999999999999999999999999999999999999999999999999999999999",
        &.{
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.transferWithOptions(
        sender_secret_key_base58,
        destination_base58,
        5_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig999999999999999999999999999999999999999999999999999999999999999999",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.nonceTransferWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x34} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const expected_encoded = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        5_000,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(expected_encoded);

    const nonce_account_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(nonce_account_response);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(nonce_account_response);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "Sig777777777777777777777777777777777777777777777777777777777777777777",
        &.{
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.nonceTransferWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig777777777777777777777777777777777777777777777777777777777777777777",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.sendVersionedNonceTransferWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x35} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        5_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(nonce_blockhash),
        instructions[0..],
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const nonce_account_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(nonce_account_response);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(nonce_account_response);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":\"SigVersionedNonce111111111111111111111111111111111111111111111111111111111\",\"id\":1}",
    );

    const signature = try rpc.sendVersionedNonceTransferWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedNonce111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
}

test "root.versionedNonceTransferWithOptions supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_authority_public_key_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_public_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_blockhash = [_]u8{0x36} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        5_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(nonce_blockhash),
        instructions[0..],
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const nonce_account_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ nonce_authority_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(nonce_account_response);
    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(nonce_account_response);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedNonceConfirm11111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.versionedNonceTransferWithOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        &.{},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 10,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedNonceConfirm11111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.buildVersionedTransferMessageBase64WithSender returns distinct payer and sender versioned message" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x60} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const encoded = try rpc.buildVersionedTransferMessageBase64WithSender(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
        &.{},
    );
    defer allocator.free(encoded);

    const expected = try client.buildVersionedTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.buildOwnedVersionedTransferMessageWithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x61} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);

    var owned = try rpc.buildOwnedVersionedTransferMessageWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .confirmed,
                },
            },
        },
    );
    defer owned.deinit(allocator);

    const encoded_bytes = try owned.serialize(allocator);
    defer allocator.free(encoded_bytes);
    const encoded = try client.encodeBase64(allocator, encoded_bytes);
    defer allocator.free(encoded);

    const expected = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
}

test "root.getFeeForTransferMessageWithOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x65} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected_message = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":44},\"value\":8000},\"id\":1}",
    );

    const fee = try rpc.getFeeForTransferMessageWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 8000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForTransferMessageWithSender uses distinct payer and sender message" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x66} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_message = try client.buildLegacyTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":6000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForTransferMessageWithSender(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 6000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForTransferMessageWithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x67} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    var expected_owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
    );
    defer expected_owned.deinit(allocator);
    const expected_bytes = try expected_owned.serialize(allocator);
    defer allocator.free(expected_bytes);
    const expected_message = try client.encodeBase64(allocator, expected_bytes);
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":44},\"value\":9000},\"id\":1}",
    );

    const fee = try rpc.getFeeForTransferMessageWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 9000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForVersionedTransferMessageWithSender uses distinct payer and sender message" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x62} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_message = try client.buildVersionedTransferMessageBase64WithSender(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":6000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForVersionedTransferMessageWithSender(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        recent_blockhash_base58,
        &.{},
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 6000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.getFeeForVersionedTransferMessageWithSenderAndOptions supports nonce blockhash query" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const nonce_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const sender_public_key_base58 = try encodeBase58(allocator, &sender_raw.public_key.toBytes());
    defer allocator.free(sender_public_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const nonce_account_pubkey = nonce_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const nonce_blockhash = [_]u8{0x63} ** 32;
    const nonce_blockhash_base58 = try encodeBase58(allocator, &nonce_blockhash);
    defer allocator.free(nonce_blockhash_base58);

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":43}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    const expected_message = try client.buildVersionedNonceTransferMessageBase64(
        allocator,
        Pubkey.fromBytes(fee_payer_raw.public_key.toBytes()),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_account_pubkey),
        Pubkey.fromBytes(sender_raw.public_key.toBytes()),
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(nonce_blockhash),
        1_000,
        &.{},
    );
    defer allocator.free(expected_message);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(response_body);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":44},\"value\":9000},\"id\":1}",
    );

    const fee = try rpc.getFeeForVersionedTransferMessageWithSenderAndOptions(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        1_000,
        &.{},
        .{
            .blockhash_query = .{
                .nonce_account = .{
                    .pubkey = nonce_account_base58,
                    .commitment = .finalized,
                },
            },
        },
        .processed,
    );

    try std.testing.expectEqual(@as(?u64, 9000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.versionedTransferWithSpinner supports fixed blockhashes" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x59} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        5_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0(
        allocator,
        sender.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
        &.{sender},
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 310, .status = null },
            .{ .context_slot = 311, .status = .{
                .slot = 311,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 312, .status = .{
                .slot = 312,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.versionedTransferWithSpinner(
        sender_secret_key_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        &.{},
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigVersionedTransferSpinner11111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.versionedTransferWithSenderAndSpinner supports fixed blockhashes" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x5e} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildVersionedTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        5_000,
        &.{},
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 410, .status = null },
            .{ .context_slot = 411, .status = .{
                .slot = 411,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 412, .status = .{
                .slot = 412,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.versionedTransferWithSenderAndSpinner(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        &.{},
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigVersionedWithSenderSpinner1111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.transferWithSenderAndSpinner supports fixed blockhashes" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x68} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        5_000,
        &.{ fee_payer, sender },
    );
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 420, .status = null },
            .{ .context_slot = 421, .status = .{
                .slot = 421,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 422, .status = .{
                .slot = 422,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.transferWithSenderAndSpinner(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigLegacyWithSenderSpinner111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.transferWithSpinner supports fixed blockhashes" {
    const allocator = std.testing.allocator;

    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);

    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x72} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const expected_encoded = try client.buildLegacyTransferTransactionBase64WithSender(
        allocator,
        sender.public_key,
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        5_000,
        &.{sender},
    );
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 440, .status = null },
            .{ .context_slot = 441, .status = .{
                .slot = 441,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 442, .status = .{
                .slot = 442,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.transferWithSpinner(
        sender_secret_key_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigLegacyTransferSpinner111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.nonceTransferWithSpinner supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x69} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const expected_encoded = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        5_000,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 430, .status = null },
            .{ .context_slot = 431, .status = .{
                .slot = 431,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 432, .status = .{
                .slot = 432,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.nonceTransferWithSpinner(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigLegacyNonceSpinner111111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.versionedNonceTransferWithSpinner supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const sender_secret_key = sender_raw.secret_key.toBytes();
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const sender_secret_key_base58 = try encodeBase58(allocator, &sender_secret_key);
    defer allocator.free(sender_secret_key_base58);
    const nonce_authority_secret_key_base58 = try encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);

    const nonce_account_pubkey = nonce_account_raw.public_key.toBytes();
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_pubkey);
    defer allocator.free(nonce_account_base58);

    const destination_public_key = destination_raw.public_key.toBytes();
    const destination_base58 = try encodeBase58(allocator, &destination_public_key);
    defer allocator.free(destination_base58);

    const recent_blockhash = [_]u8{0x58} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const sender = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_secret_key);
    const transfer = SystemProgram.transfer(
        sender.public_key,
        Pubkey.fromBytes(destination_public_key),
        5_000,
    );
    const instructions = [_]Instruction{transfer.instruction()};
    var expected = try client.buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        fee_payer.public_key,
        Pubkey.fromBytes(nonce_account_pubkey),
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{},
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected.deinit(allocator);
    const expected_encoded = try expected.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 210, .status = null },
            .{ .context_slot = 211, .status = .{
                .slot = 211,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 212, .status = .{
                .slot = 212,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const pipe_fds = try std.posix.pipe();
    defer std.posix.close(pipe_fds[0]);
    const saved_stderr = try std.posix.dup(std.posix.STDERR_FILENO);
    defer std.posix.close(saved_stderr);
    try std.posix.dup2(pipe_fds[1], std.posix.STDERR_FILENO);
    std.posix.close(pipe_fds[1]);
    defer std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO) catch {};

    const signature = try rpc.versionedNonceTransferWithSpinner(
        fee_payer_secret_key_base58,
        sender_secret_key_base58,
        nonce_authority_secret_key_base58,
        nonce_account_base58,
        destination_base58,
        5_000,
        recent_blockhash_base58,
        &.{},
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":false") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigVersionedNonceSpinner1111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.sendTransaction params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params_json = try rpc.serializeSendTransactionParams(
        "signed-transaction-base64",
        .{
            .skip_preflight = true,
            .preflight_commitment = .confirmed,
            .max_retries = 3,
            .min_context_slot = 456,
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"signed-transaction-base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"preflightCommitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"maxRetries\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":456") != null);
}

test "root.simulateTransaction params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const params_json = try rpc.serializeSimulateTransactionParams(
        "signed-transaction-base64",
        .{
            .sig_verify = true,
            .replace_recent_blockhash = true,
            .commitment = .finalized,
            .min_context_slot = 123,
            .inner_instructions = true,
            .accounts = .{
                .addresses = &.{
                    "Account11111111111111111111111111111111",
                    "Account22222222222222222222222222222222",
                },
                .encoding = .base64,
            },
        },
    );
    defer allocator.free(params_json);

    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"signed-transaction-base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"encoding\":\"base64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"replaceRecentBlockhash\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"minContextSlot\":123") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"innerInstructions\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, params_json, "\"addresses\":[\"Account11111111111111111111111111111111\",\"Account22222222222222222222222222222222\"]") != null);
}

test "root.getSignatureStatus params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const signatures = [_][]const u8{"signature"};

    const default_json = try rpc.serializeSignatureStatusesParams(signatures[0..], null);
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "searchTransactionHistory") == null);

    const with_history_json = try rpc.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true },
    );
    defer allocator.free(with_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"signature\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "searchTransactionHistory") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "true") != null);

    const with_commitment_json = try rpc.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "commitment") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"confirmed\"") != null);

    const with_commitment_history_json = try rpc.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true, .commitment = .finalized },
    );
    defer allocator.free(with_commitment_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "searchTransactionHistory") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "true") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_history_json, "\"finalized\"") != null);
}

test "root.getSignatureStatuses params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const signatures = [_][]const u8{ "sig-1", "sig-2" };

    const default_json = try rpc.serializeSignatureStatusesParams(signatures[0..], null);
    defer allocator.free(default_json);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"sig-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "\"sig-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, default_json, "searchTransactionHistory") == null);

    const with_history_json = try rpc.serializeSignatureStatusesParams(
        signatures[0..],
        .{ .search_transaction_history = true },
    );
    defer allocator.free(with_history_json);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"sig-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "\"sig-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_history_json, "searchTransactionHistory") != null);
}

test "root.confirmationSatisfiesCommitment" {
    try std.testing.expect(confirmationSatisfiesCommitment("processed", null));
    try std.testing.expect(confirmationSatisfiesCommitment("confirmed", .processed));
    try std.testing.expect(confirmationSatisfiesCommitment("finalized", .confirmed));
    try std.testing.expect(!confirmationSatisfiesCommitment("processed", .confirmed));
    try std.testing.expect(!confirmationSatisfiesCommitment(null, .processed));
}

test "root.getSignaturesForAddress params serialization" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const without_commitment_json = try rpc.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        null,
    );
    defer allocator.free(without_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, without_commitment_json, "\"Address11111111111111111111111111111111\"") != null);

    const with_commitment_json = try rpc.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(with_commitment_json);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"Address11111111111111111111111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_commitment_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getSignaturesForAddress params serialization with filters" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const with_filters_json = try rpc.serializeSignaturesForAddressParams(
        "Address11111111111111111111111111111111",
        .{
            .before = "BeforeSig",
            .until = "UntilSig",
            .limit = @as(u64, 50),
            .commitment = .finalized,
            .min_context_slot = 789,
        },
    );
    defer allocator.free(with_filters_json);

    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"before\":\"BeforeSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"until\":\"UntilSig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"limit\":50") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_filters_json, "\"minContextSlot\":789") != null);
}

test "root.rpc error detail is captured" {
    const allocator = std.testing.allocator;
    var rpc = try RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32600,\"message\":\"invalid request\"}}";

    const response = rpc.parseResponse(body, u64);
    try std.testing.expectError(error.RpcError, response);

    const last_error = rpc.getLastError() orelse return error.TestExpectedError;
    try std.testing.expect(last_error.code == -32600);
    try std.testing.expect(std.mem.eql(u8, last_error.message, "invalid request"));
}

test "root.sendVersionedTransactionTyped serializes signed versioned transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer_instruction = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const address_table_lookups = [_]MessageAddressTableLookup{};
    const account_keys = [_]Pubkey{
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        SystemProgram.id(),
    };
    const transaction = VersionedTransaction{
        .message = .{
            .header = .{
                .num_required_signatures = 1,
                .num_readonly_signed_accounts = 0,
                .num_readonly_unsigned_accounts = 1,
            },
            .account_keys = account_keys[0..],
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
            .address_table_lookups = address_table_lookups[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigVersioned1111111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try rpc.sendVersionedTransactionTyped(
        signed,
        .{
            .skip_preflight = true,
            .preflight_commitment = .confirmed,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersioned1111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.simulateVersionedTransactionTyped serializes signed versioned transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer_instruction = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const address_table_lookups = [_]MessageAddressTableLookup{};
    const account_keys = [_]Pubkey{
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        SystemProgram.id(),
    };
    const transaction = VersionedTransaction{
        .message = .{
            .header = .{
                .num_required_signatures = 1,
                .num_readonly_signed_accounts = 0,
                .num_readonly_unsigned_accounts = 1,
            },
            .account_keys = account_keys[0..],
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
            .address_table_lookups = address_table_lookups[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}" },
    });
    defer rpc.deinit();

    const result = try rpc.simulateVersionedTransactionTyped(
        signed,
        .{ .sig_verify = true, .replace_recent_blockhash = true },
    );
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"replaceRecentBlockhash\":true") != null);
}

test "root.sendAndConfirmVersionedTransactionTyped submits and confirms signed versioned transaction" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer_instruction = SystemProgram.transfer(
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const address_table_lookups = [_]MessageAddressTableLookup{};
    const account_keys = [_]Pubkey{
        keypair.public_key,
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        SystemProgram.id(),
    };
    const transaction = VersionedTransaction{
        .message = .{
            .header = .{
                .num_required_signatures = 1,
                .num_readonly_signed_accounts = 0,
                .num_readonly_unsigned_accounts = 1,
            },
            .account_keys = account_keys[0..],
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
            .address_table_lookups = address_table_lookups[0..],
        },
    };
    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    var rpc = try RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigVersionedConfirm111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 10, .status = .{
                .slot = 10,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
        },
    );

    const signature = try rpc.sendAndConfirmVersionedTransactionTyped(
        signed,
        .{ .skip_preflight = true },
        null,
        true,
        2_000,
        20,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigVersionedConfirm111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded) != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":true") != null);
}

test "root.getFeeForVersionedMessageTyped serializes typed v0 message" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const transfer_instruction = SystemProgram.transfer(
        Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const address_table_lookups = [_]MessageAddressTableLookup{};
    const account_keys = [_]Pubkey{
        Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        SystemProgram.id(),
    };
    const message = VersionedMessageV0{
        .header = .{
            .num_required_signatures = 1,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 1,
        },
        .account_keys = account_keys[0..],
        .recent_blockhash = Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
        .address_table_lookups = address_table_lookups[0..],
    };
    const encoded_message = try message.toBase64(allocator);
    defer allocator.free(encoded_message);

    var rpc = try RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":123},\"value\":5000},\"id\":1}" },
    });
    defer rpc.deinit();

    const fee = try rpc.getFeeForVersionedMessageTyped(message, .processed);
    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, encoded_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}
