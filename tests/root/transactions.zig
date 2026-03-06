const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const client = @import("solana_client_zig");
const root_test_support = @import("root_test_support");

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
const runMockRootServer = root_test_support.runMockRootServer;
const runMockRootServerSequence = root_test_support.runMockRootServerSequence;
const runMockRootServerCaptureSequence = root_test_support.runMockRootServerCaptureSequence;

test "root.send delegates to sendTransaction" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":"Sig111111111111111111111111111111111111111111111111111111111111111111","id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const signature = try rpc.send("SignedTransactionBase64==");
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigTyped111111111111111111111111111111111111111111111111111111111111111","id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
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
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"preflightCommitment\":\"confirmed\"") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigLegacy11111111111111111111111111111111111111111111111111111111111111","id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const signature = try rpc.sendLegacyTransaction(transaction, &.{keypair}, .{ .skip_preflight = true });
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigLegacy11111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"skipPreflight\":true") != null);
}

test "root.sendAndConfirmTransaction aliases wait on signature status" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"Sig111111111111111111111111111111111111111111111111111111111111111111","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[{"slot":10,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const signature = try rpc.sendAndConfirmTransaction("SignedTransactionBase64==");
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig111111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigTypedConfirm11111111111111111111111111111111111111111111111111111111111","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[{"slot":10,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 2), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"searchTransactionHistory\":true") != null);
}

test "root.sendTransactionAndConfirm uses initial transaction-not-found timeout from constructor" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigInitialTimeout111111111111111111111111111111111111111111111111111111111","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[null]},"id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":[null]},"id":3}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":[{"slot":12,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":4}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.newWithTimeoutsAndCommitment(allocator, rpc_url, 40, 80, null);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 4), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[3], "\"method\":\"getSignatureStatuses\"") != null);
}

test "root.sendAndConfirmTransactionWithSpinner prints progress and honors config" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigSpinner11111111111111111111111111111111111111111111111111111111111111","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[null]},"id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":[{"slot":11,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":3}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":[{"slot":12,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":4}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.newWithTimeoutsAndCommitment(allocator, rpc_url, 200, 80, null);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 4), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"maxRetries\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[3], "\"commitment\":\"confirmed\"") != null);
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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[null]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":true,"id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":[{"slot":12,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":3}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":13},"value":[{"slot":13,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":4}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.newWithTimeoutsAndCommitment(allocator, rpc_url, 200, 80, null);
    defer rpc.deinit();

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

    try std.testing.expectEqual(@as(usize, 4), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"isBlockhashValid\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[3], "\"commitment\":\"confirmed\"") != null);
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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[null]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":false,"id":2}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.newWithTimeoutsAndCommitment(allocator, rpc_url, 200, 0, null);
    defer rpc.deinit();

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
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"Sig222222222222222222222222222222222222222222222222222222222222222222","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":[{"slot":11,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const signature = try rpc.sendAndConfirmTransactionWithConfig(
        "SignedTransactionBase64==",
        .{ .skip_preflight = true },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig222222222222222222222222222222222222222222222222222222222222222222",
        signature,
    );
}

test "root.sendAndConfirmTransactionWithCommitmentAndConfig supports both commitment and send options" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"Sig333333333333333333333333333333333333333333333333333333333333333333","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":[{"slot":12,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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
}

test "root.sendAndConfirmTransactionWithCommitment requires commitment-aware confirmation" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"Sig333333333333333333333333333333333333333333333333333333333333333333","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":[{"slot":12,"confirmations":1,"confirmationStatus":"finalized","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const signature = try rpc.sendAndConfirmTransactionWithCommitment(
        "SignedTransactionBase64==",
        .confirmed,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "Sig333333333333333333333333333333333333333333333333333333333333333333",
        signature,
    );
}

test "root.pollGetBalanceWithCommitmentAndTimeouts retries until success" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"node behind"}}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":44},"value":77},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const balance = try rpc.pollGetBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        .confirmed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 77), balance);
}

test "root.waitForBalanceWithCommitmentAndTimeouts waits for expected value" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":45},"value":1},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":46},"value":5},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const balance = try rpc.waitForBalanceWithCommitmentAndTimeouts(
        "Address11111111111111111111111111111111",
        5,
        .processed,
        200,
        10,
    );
    try std.testing.expectEqual(@as(u64, 5), balance);
}

test "root.confirmTransaction checks transaction confirmed status" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[{"slot":10,"confirmations":1,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":[{"slot":11,"confirmations":2,"confirmationStatus":"finalized","err":null}]},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed = try rpc.confirmTransaction("Sig111111111111111111111111111111111111", .confirmed, false);
    try std.testing.expect(confirmed);
}

test "root.confirmTransaction returns false for missing signature" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":1},"value":[null]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed = try rpc.confirmTransaction("Sig111111111111111111111111111111111111", .processed, false);
    try std.testing.expect(!confirmed);
}

test "root.pollForSignatureConfirmationWithTimeouts waits for configured lockout" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":21},"value":[{"slot":21,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":22},"value":[{"slot":22,"confirmations":3,"confirmationStatus":"confirmed","err":null}]},"id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":23},"value":[{"slot":23,"confirmations":10,"confirmationStatus":"confirmed","err":null}]},"id":3}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        false,
        500,
        10,
    );
    try std.testing.expectEqual(@as(u64, 10), confirmed_blocks);
}

test "root.pollForSignatureConfirmationWithCommitmentAndTimeouts waits for commitment level" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":31},"value":[{"slot":31,"confirmations":1,"confirmationStatus":"confirmed","err":null}]},"id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":32},"value":[{"slot":32,"confirmations":10,"confirmationStatus":"finalized","err":null}]},"id":2}
        ,
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithCommitmentAndTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        .finalized,
        false,
        500,
        10,
    );
    try std.testing.expectEqual(@as(u64, 10), confirmed_blocks);
}

test "root.pollForSignature returns on failed signature" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":41},"value":[{"slot":41,"confirmations":1,"confirmationStatus":"processed","err":{"InstructionError":"GenericError"}}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    try rpc.pollForSignature(
        "Sig111111111111111111111111111111111111",
        null,
        false,
    );
}

test "root.pollForSignatureConfirmation returns partial confirmations on timeout" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":41},"value":[{"slot":41,"confirmations":3,"confirmationStatus":"processed","err":null}]},"id":1}
    ;
    const response_bodies: [20][]const u8 = .{response_body} ** 20;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerSequence, .{ &listener, allocator, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed_blocks = try rpc.pollForSignatureConfirmationWithTimeouts(
        "Sig111111111111111111111111111111111111",
        10,
        false,
        100,
        10,
    );
    try std.testing.expectEqual(@as(u64, 3), confirmed_blocks);
}

test "root.getNumBlocksSinceSignatureConfirmation returns lockout fallback when confirmations missing" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":31},"value":[{"slot":31,"confirmationStatus":"confirmed","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed_blocks = try rpc.getNumBlocksSinceSignatureConfirmation("Sig111111111111111111111111111111111111", false);
    try std.testing.expectEqual(@as(u64, max_lockout_history + 1), confirmed_blocks);
}

test "root.getNumBlocksSinceSignatureConfirmationWithCommitment passes commitment into signature status query" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":31},"value":[{"slot":31,"confirmationStatus":"confirmed","err":null}]},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const confirmed_blocks = try rpc.getNumBlocksSinceSignatureConfirmationWithCommitment(
        "Sig111111111111111111111111111111111111",
        .confirmed,
        false,
    );
    try std.testing.expectEqual(@as(u64, max_lockout_history + 1), confirmed_blocks);
}

test "root.getTransactionWithConfig returns decoded transaction json" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":{"transaction":"abc","meta":{"err":null}}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const tx_json = try rpc.getTransactionWithConfig(
        "Sig111111111111111111111111111111111111",
        .{ .commitment = .confirmed },
    );
    defer allocator.free(tx_json.?);

    try std.testing.expect(std.mem.indexOf(u8, tx_json.?, "abc") != null);
}

test "root.simulateTransactionWithConfig delegates to simulateTransaction" {
    const allocator = std.testing.allocator;
    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    const response_body =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":{"accounts":[],"err":null,"fee":120,"unitsConsumed":42}},"id":1}
    ;
    const server_thread = try std.Thread.spawn(.{}, runMockRootServer, .{ &listener, allocator, response_body });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const result = try rpc.simulateTransactionWithConfig("signed-transaction-base64", null);
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":{"accounts":[],"err":null,"fee":120,"unitsConsumed":42}},"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const result = try rpc.simulateTransactionTyped(
        signed,
        .{ .sig_verify = true, .replace_recent_blockhash = true },
    );
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"simulateTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"replaceRecentBlockhash\":true") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":{"accounts":[],"err":null,"fee":120,"unitsConsumed":42}},"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const result = try rpc.simulateLegacyTransaction(transaction, &.{keypair}, .{ .sig_verify = true });
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"sigVerify\":true") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":9}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":55}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(response_body);

    const response_bodies = [_][]const u8{response_body};
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const encoded_transaction = try rpc.buildTransferTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(encoded_transaction);

    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getLatestBlockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"confirmed\"") != null);

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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":9}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":55}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(response_body);

    const response_bodies = [_][]const u8{response_body};
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    var signed = try rpc.buildTransferSignedTransactionWithOptions(
        sender_secret_key_base58,
        destination_base58,
        1_000,
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const tx_bytes = try signed.serialize(allocator);
    defer allocator.free(tx_bytes);

    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getLatestBlockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"confirmed\"") != null);

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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_body = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":42}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(response_body);

    const response_bodies = [_][]const u8{response_body};
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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

    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getAccountInfo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"finalized\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], nonce_account_base58) != null);
    try std.testing.expect(std.mem.eql(u8, expected, encoded));
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":77}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);

    const response_bodies = [_][]const u8{
        latest_blockhash_response,
        \\{"jsonrpc":"2.0","result":"Sig555555555555555555555555555555555555555555555555555555555555555555","id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":13},"value":[{"slot":13,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":3}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 3), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getLatestBlockhash\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"maxRetries\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"commitment\":\"confirmed\"") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const nonce_account_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"data\":{{\"program\":\"system\",\"parsed\":{{\"type\":\"initialized\",\"info\":{{\"authority\":\"{s}\",\"blockhash\":\"{s}\",\"feeCalculator\":{{\"lamportsPerSignature\":5000}}}}}},\"space\":80}},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}}},\"id\":1}}",
        .{ sender_public_key_base58, nonce_blockhash_base58 },
    );
    defer allocator.free(nonce_account_response);

    const response_bodies = [_][]const u8{
        nonce_account_response,
        \\{"jsonrpc":"2.0","result":"Sig999999999999999999999999999999999999999999999999999999999999999999","id":2}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":13},"value":[{"slot":13,"confirmations":2,"confirmationStatus":"confirmed","err":null}]},"id":3}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 3), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getAccountInfo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"maxRetries\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[2], "\"commitment\":\"confirmed\"") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigVersioned1111111111111111111111111111111111111111111111111111111111111","id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
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
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"preflightCommitment\":\"confirmed\"") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":{"accounts":[],"err":null,"fee":120,"unitsConsumed":42}},"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const result = try rpc.simulateVersionedTransactionTyped(
        signed,
        .{ .sig_verify = true, .replace_recent_blockhash = true },
    );
    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"simulateTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"replaceRecentBlockhash\":true") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":"SigVersionedConfirm111111111111111111111111111111111111111111111111111111111","id":1}
        ,
        \\{"jsonrpc":"2.0","result":{"context":{"slot":10},"value":[{"slot":10,"confirmations":1,"confirmationStatus":"processed","err":null}]},"id":2}
    };

    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

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
    try std.testing.expectEqual(@as(usize, 2), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"sendTransaction\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"method\":\"getSignatureStatuses\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[1], "\"searchTransactionHistory\":true") != null);
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

    var listener = try (try std.net.Address.parseIp("127.0.0.1", 0)).listen(.{});
    defer listener.deinit();
    const port = listener.listen_address.getPort();

    var request_captures = std.ArrayList([]u8).empty;
    defer {
        for (request_captures.items) |request| allocator.free(request);
        request_captures.deinit(allocator);
    }

    const response_bodies = [_][]const u8{
        \\{"jsonrpc":"2.0","result":{"context":{"slot":123},"value":5000},"id":1}
    };
    const server_thread = try std.Thread.spawn(.{}, runMockRootServerCaptureSequence, .{ &listener, allocator, &request_captures, &response_bodies });
    defer server_thread.join();

    const rpc_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
    defer allocator.free(rpc_url);

    var rpc = try RpcClient.init(allocator, rpc_url);
    defer rpc.deinit();

    const fee = try rpc.getFeeForVersionedMessageTyped(message, .processed);
    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), request_captures.items.len);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"method\":\"getFeeForMessage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], encoded_message) != null);
    try std.testing.expect(std.mem.indexOf(u8, request_captures.items[0], "\"commitment\":\"processed\"") != null);
}
