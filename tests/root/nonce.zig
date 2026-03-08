const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

const Hash = client.Hash;
const Keypair = client.Keypair;
const LegacyTransaction = client.LegacyTransaction;
const Pubkey = client.Pubkey;
const SystemProgram = client.SystemProgram;
const encodeBase58 = client.encodeBase58;

test "root.getNonceAccountResponse parses nonce account from jsonParsed account data" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":55},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth111111111111111111111111111111111111\",\"blockhash\":\"NonceBlockhash1111111111111111111111111111\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}},\"id\":1}" },
    });
    defer rpc.deinit();

    const response = try rpc.getNonceAccountResponse("Nonce11111111111111111111111111111111111", .confirmed);
    try std.testing.expectEqual(@as(u64, 55), response.context_slot);
    try std.testing.expect(response.account != null);

    const nonce_account = response.account.?;
    defer rpc.freeOwnedNonceAccount(nonce_account);

    try std.testing.expectEqualStrings("Auth111111111111111111111111111111111111", nonce_account.authority);
    try std.testing.expectEqualStrings("NonceBlockhash1111111111111111111111111111", nonce_account.blockhash);
    try std.testing.expectEqual(@as(?u64, 5000), nonce_account.lamports_per_signature);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.getNonceBlockhash returns owned blockhash copy" {
    const allocator = std.testing.allocator;
    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":56},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth111111111111111111111111111111111111\",\"blockhash\":\"NonceBlockhash2222222222222222222222222222\",\"feeCalculator\":{\"lamportsPerSignature\":5001}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}},\"id\":1}" },
    });
    defer rpc.deinit();

    const blockhash = try rpc.getNonceBlockhash("Nonce11111111111111111111111111111111111", .finalized);
    defer allocator.free(blockhash);

    try std.testing.expectEqualStrings("NonceBlockhash2222222222222222222222222222", blockhash);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.resolveBlockhashQuery resolves cluster, fixed, and nonce account sources" {
    const allocator = std.testing.allocator;

    var fixed_rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer fixed_rpc.deinit();

    const fixed = try fixed_rpc.resolveBlockhashQuery(.{ .fixed = "FixedBlockhash11111111111111111111111111111" });
    defer fixed_rpc.freeOwnedResolvedBlockhash(fixed);
    try std.testing.expectEqual(client.BlockhashQuerySource.fixed, fixed.source);
    try std.testing.expectEqualStrings("FixedBlockhash11111111111111111111111111111", fixed.blockhash);
    try std.testing.expect(fixed.context_slot == null);
    try std.testing.expect(fixed.last_valid_block_height == null);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":77},\"value\":{\"blockhash\":\"LatestBlockhash1111111111111111111111111111\",\"lastValidBlockHeight\":999}},\"id\":1}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":88},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth111111111111111111111111111111111111\",\"blockhash\":\"NonceResolvedBlockhash11111111111111111111\",\"feeCalculator\":{\"lamportsPerSignature\":5002}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}},\"id\":2}" },
    });
    defer rpc.deinit();

    const cluster = try rpc.resolveBlockhashQuery(.{ .cluster = .{ .commitment = .confirmed } });
    defer rpc.freeOwnedResolvedBlockhash(cluster);
    try std.testing.expectEqual(client.BlockhashQuerySource.cluster, cluster.source);
    try std.testing.expectEqualStrings("LatestBlockhash1111111111111111111111111111", cluster.blockhash);
    try std.testing.expectEqual(@as(?u64, 77), cluster.context_slot);
    try std.testing.expectEqual(@as(?u64, 999), cluster.last_valid_block_height);

    const nonce = try rpc.resolveBlockhashQuery(.{
        .nonce_account = .{
            .pubkey = "Nonce11111111111111111111111111111111111",
            .commitment = .finalized,
        },
    });
    defer rpc.freeOwnedResolvedBlockhash(nonce);
    try std.testing.expectEqual(client.BlockhashQuerySource.nonce_account, nonce.source);
    try std.testing.expectEqualStrings("NonceResolvedBlockhash11111111111111111111", nonce.blockhash);
    try std.testing.expectEqual(@as(?u64, 88), nonce.context_slot);
    try std.testing.expect(nonce.last_valid_block_height == null);

    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.buildOwnedLegacyMessageWithBlockhashQuery resolves cluster blockhash for arbitrary instructions" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const recent_blockhash = [_]u8{0x33} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":66}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":1234}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 42);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var owned = try rpc.buildOwnedLegacyMessageWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        .{ .cluster = .{ .commitment = .confirmed } },
        null,
    );
    defer owned.deinit(allocator);

    var expected = try client.buildOwnedLegacyMessage(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer expected.deinit(allocator);

    const encoded = try owned.serialize(allocator);
    defer allocator.free(encoded);
    const expected_encoded = try expected.serialize(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.buildSignedLegacyTransactionWithBlockhashQuery supports nonce account queries for arbitrary instructions" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{6} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":88},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth111111111111111111111111111111111111\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);
    try rpc.pushMockResultJson(nonce_account_result_json);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 77);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var signed = try rpc.buildSignedLegacyTransactionWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        &.{ payer, nonce_authority },
        .{ .nonce_account = .{
            .pubkey = nonce_account_base58,
            .commitment = .finalized,
        } },
        nonce_authority.public_key,
    );
    defer signed.deinit(allocator);

    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer expected_signed.deinit(allocator);

    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, signed.message_bytes);
    try std.testing.expectEqual(@as(usize, expected_signed.signatures.len), signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[0].bytes[0..], signed.signatures[0].bytes[0..]);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[1].bytes[0..], signed.signatures[1].bytes[0..]);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.buildLegacyInstructionsSignedTransactionWithOptions resolves cluster blockhash" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{29} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{30} ** 32);
    const recent_blockhash = [_]u8{0x51} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":109}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":901}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 222);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var signed = try rpc.buildLegacyInstructionsSignedTransactionWithOptions(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, expected_signed.signatures.len), signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, signed.message_bytes);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[0].bytes[0..], signed.signatures[0].bytes[0..]);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.buildLegacyInstructionsSignedTransactionWithConfig supports fixed blockhash" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{31} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{32} ** 32);
    const recent_blockhash = [_]u8{0x52} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 333);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var signed = try rpc.buildLegacyInstructionsSignedTransactionWithConfig(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .recent_blockhash = recent_blockhash_base58 },
    );
    defer signed.deinit(allocator);

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, expected_signed.signatures.len), signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, signed.message_bytes);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[0].bytes[0..], signed.signatures[0].bytes[0..]);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.buildLegacyInstructionsTransactionWithOptions resolves cluster blockhash" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{33} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{34} ** 32);
    const recent_blockhash = [_]u8{0x53} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":121}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":901}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 444);
    const instructions = [_]client.Instruction{transfer.instruction()};

    const encoded = try rpc.buildLegacyInstructionsTransactionWithOptions(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(encoded);

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.buildLegacyTransactionBase64WithBlockhashQuery supports fixed blockhashes without RPC" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const recent_blockhash = [_]u8{0x45} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 99);
    const instructions = [_]client.Instruction{transfer.instruction()};

    const encoded = try rpc.buildLegacyTransactionBase64WithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .fixed = recent_blockhash_base58 },
        null,
    );
    defer allocator.free(encoded);

    const expected_encoded = try client.buildLegacyTransactionBase64(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
}

test "root.buildLegacyMessageBytesAndBase64WithBlockhashQuery support fixed blockhashes without RPC" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{10} ** 32);
    const recent_blockhash = [_]u8{0x46} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.init(allocator, "https://example.com");
    defer rpc.deinit();

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 101);
    const instructions = [_]client.Instruction{transfer.instruction()};

    const message_bytes = try rpc.buildLegacyMessageBytesWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        .{ .fixed = recent_blockhash_base58 },
        null,
    );
    defer allocator.free(message_bytes);

    const message_base64 = try rpc.buildLegacyMessageBase64WithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        .{ .fixed = recent_blockhash_base58 },
        null,
    );
    defer allocator.free(message_base64);

    const expected_bytes = try client.buildLegacyMessageBytes(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(expected_bytes);

    const expected_base64 = try client.buildLegacyMessageBase64(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(expected_base64);

    try std.testing.expectEqualSlices(u8, expected_bytes, message_bytes);
    try std.testing.expectEqualStrings(expected_base64, message_base64);
}

test "root.sendLegacyInstructionsWithBlockhashQuery resolves cluster blockhash and sends arbitrary instructions" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{11} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{12} ** 32);
    const recent_blockhash = [_]u8{0x47} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashResponse(91, recent_blockhash_base58, 4567);
    try rpc.pushMockSignatureResult("SigGenericSend11111111111111111111111111111111111111111111111111111111111");

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 123);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const signature = try rpc.sendLegacyInstructionsWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .cluster = .{ .commitment = .confirmed } },
        null,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigGenericSend11111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
}

test "root.getFeeForLegacyInstructionsWithBlockhashQuery resolves cluster blockhash and serializes arbitrary instructions" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{19} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{20} ** 32);
    const recent_blockhash = [_]u8{0x4A} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashResponse(94, recent_blockhash_base58, 6789);
    try rpc.pushMockResultJson("{\"context\":{\"slot\":95},\"value\":5000}");

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 654);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_message = try client.buildOwnedLegacyMessage(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer expected_message.deinit(allocator);
    const expected_base64 = try expected_message.toBase64(allocator);
    defer allocator.free(expected_base64);

    const fee = try rpc.getFeeForLegacyInstructionsWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        .{ .cluster = .{ .commitment = .confirmed } },
        null,
        .confirmed,
    );

    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_base64) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.simulateLegacyInstructionsWithBlockhashQuery supports fixed blockhashes without RPC blockhash lookup" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{21} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{22} ** 32);
    const recent_blockhash = [_]u8{0x4B} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 777);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson("{\"context\":{\"slot\":96},\"value\":{\"err\":null,\"unitsConsumed\":42}}");

    const result = try rpc.simulateLegacyInstructionsWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .fixed = recent_blockhash_base58 },
        null,
        .{ .sig_verify = true },
    );

    try std.testing.expectEqual(@as(u64, 96), result.context_slot);
    try std.testing.expectEqual(@as(?u64, 42), result.units_consumed);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"sigVerify\":true") != null);
}

test "root.buildLegacyMessageBase64WithOptions uses explicit recent blockhash without blockhash RPC" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{23} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{24} ** 32);
    const recent_blockhash = [_]u8{0x4C} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 888);
    const instructions = [_]client.Instruction{transfer.instruction()};

    const encoded = try rpc.buildLegacyMessageBase64WithOptions(
        payer.public_key,
        instructions[0..],
        .{ .recent_blockhash = recent_blockhash_base58 },
    );
    defer allocator.free(encoded);

    const expected = try client.buildLegacyMessageBase64(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.sendAndConfirmLegacyInstructions uses explicit recent blockhash without blockhash lookup" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{27} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{28} ** 32);
    const recent_blockhash = [_]u8{0x4E} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigLegacyPlain1111111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 101, .status = .{
                .slot = 101,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 102, .status = .{
                .slot = 102,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 1111);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const signature = try rpc.sendAndConfirmLegacyInstructions(
        payer.public_key,
        instructions[0..],
        &.{payer},
        recent_blockhash_base58,
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 5 },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigLegacyPlain1111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":5") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
}

test "root.sendAndConfirmLegacyInstructionsWithBlockhashQuery supports nonce account queries for arbitrary instructions" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{13} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{14} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{15} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{16} ** 32);
    const recent_blockhash = [_]u8{0x48} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":92},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"Auth111111111111111111111111111111111111\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);
    try rpc.pushMockResultJson(nonce_account_result_json);
    try rpc.pushMockSignatureResult("SigGenericNonce111111111111111111111111111111111111111111111111111111111");
    try rpc.pushMockSingleSignatureStatusResult(93, .{
        .slot = 93,
        .confirmations = 1,
        .confirmation_status = "confirmed",
        .has_error = false,
    });

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const nonce_account = Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 321);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const signature = try rpc.sendAndConfirmLegacyInstructionsWithBlockhashQuery(
        payer.public_key,
        instructions[0..],
        &.{ payer, nonce_authority },
        .{ .nonce_account = .{
            .pubkey = nonce_account_base58,
            .commitment = .finalized,
        } },
        nonce_authority.public_key,
        .{ .skip_preflight = true, .max_retries = 3 },
        .confirmed,
        false,
        200,
        0,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigGenericNonce111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":3") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.sendAndConfirmLegacyInstructionsWithOptions resolves cluster blockhash and honors send/confirm options" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{25} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{26} ** 32);
    const recent_blockhash = [_]u8{0x4D} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashResponse(97, recent_blockhash_base58, 7001);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigGenericOptions11111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 98, .status = null },
            .{ .context_slot = 99, .status = .{
                .slot = 99,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 100, .status = .{
                .slot = 100,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 999);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const signature = try rpc.sendAndConfirmLegacyInstructionsWithOptions(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 4 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 0,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigGenericOptions11111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 5), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":4") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[3].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[4].method);
}

test "root.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner supports fixed blockhashes" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{17} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{18} ** 32);
    const recent_blockhash = [_]u8{0x49} ** 32;
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer = SystemProgram.transfer(payer.public_key, destination, 456);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var expected_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{payer},
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigGenericSpinner11111111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 100, .status = null },
            .{ .context_slot = 101, .status = .{
                .slot = 101,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 102, .status = .{
                .slot = 102,
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

    const signature = try rpc.sendAndConfirmLegacyInstructionsWithBlockhashQueryWithSpinner(
        payer.public_key,
        instructions[0..],
        &.{payer},
        .{ .fixed = recent_blockhash_base58 },
        null,
        .{ .skip_preflight = true, .max_retries = 1 },
        .confirmed,
        true,
        200,
        0,
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigGenericSpinner11111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":1") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expectEqualStrings(
        \\sending transaction...
        \\submitted transaction: SigGenericSpinner11111111111111111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigGenericSpinner11111111111111111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigGenericSpinner11111111111111111111111111111111111111111111111111111111
        \\transaction confirmed: SigGenericSpinner11111111111111111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.buildInitializeNonceAccountSignedTransactionWithOptions fetches latest blockhash" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const recent_blockhash = [_]u8{0x55} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":77}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":999}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);

    var signed = try rpc.buildInitializeNonceAccountSignedTransactionWithOptions(
        fee_payer_secret_key_base58,
        nonce_account_base58,
        nonce_authority_base58,
        .{ .blockhash_commitment = .confirmed },
    );
    defer signed.deinit(allocator);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const initialize = try SystemProgram.initializeNonceAccount(
        allocator,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
    );
    const instructions = [_]client.Instruction{initialize.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    var expected_signed = try expected_transaction.sign(allocator, &.{fee_payer});
    defer expected_signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, signed.message_bytes);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[0].bytes[0..], signed.signatures[0].bytes[0..]);
}

test "root.sendInitializeNonceAccountWithOptions fetches latest blockhash and sends transaction" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const recent_blockhash = [_]u8{0x57} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const initialize = try SystemProgram.initializeNonceAccount(
        allocator,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
    );
    const instructions = [_]client.Instruction{initialize.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    const expected_encoded = try expected_transaction.toBase64(allocator, &.{fee_payer});
    defer allocator.free(expected_encoded);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":77}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":999}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":\"SigInit1111111111111111111111111111111111111111111111111111111111111111\",\"id\":2}");

    const signature = try rpc.sendInitializeNonceAccountWithOptions(
        fee_payer_secret_key_base58,
        nonce_account_base58,
        nonce_authority_base58,
        .{
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigInit1111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
}

test "root.initializeNonceAccount uses explicit recent blockhash and commitment" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{6} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const recent_blockhash = [_]u8{0x58} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try encodeBase58(allocator, &nonce_authority_raw.public_key.toBytes());
    defer allocator.free(nonce_authority_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const initialize = try SystemProgram.initializeNonceAccount(
        allocator,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(nonce_authority_raw.public_key.toBytes()),
    );
    const instructions = [_]client.Instruction{initialize.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    const expected_encoded = try expected_transaction.toBase64(allocator, &.{fee_payer});
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigInit2222222222222222222222222222222222222222222222222222222222222222\",\"id\":1}" },
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":78},\"value\":[{\"slot\":78,\"confirmations\":2,\"confirmationStatus\":\"confirmed\",\"err\":null}]},\"id\":2}" },
    });
    defer rpc.deinit();

    const signature = try rpc.initializeNonceAccount(
        fee_payer_secret_key_base58,
        nonce_account_base58,
        nonce_authority_base58,
        recent_blockhash_base58,
        .confirmed,
        .{ .skip_preflight = true, .max_retries = 2 },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigInit2222222222222222222222222222222222222222222222222222222222222222",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.advanceNonceAccountWithOptions supports distinct fee payer and authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const current_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{6} ** 32);
    const recent_blockhash = [_]u8{0x59} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const current_authority_secret_key = current_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const current_authority_secret_key_base58 = try encodeBase58(allocator, &current_authority_secret_key);
    defer allocator.free(current_authority_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const current_authority = try Keypair.fromSecretKeyBytes(current_authority_secret_key);
    const advance = try SystemProgram.advanceNonceAccount(
        allocator,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        current_authority.public_key,
    );
    const instructions = [_]client.Instruction{advance.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    const expected_encoded = try expected_transaction.toBase64(
        allocator,
        &.{ fee_payer, current_authority },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":77}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":999}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":\"SigAdv1111111111111111111111111111111111111111111111111111111111111111\",\"id\":2}");
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":78},\"value\":[{\"slot\":78,\"confirmations\":2,\"confirmationStatus\":\"confirmed\",\"err\":null}]},\"id\":3}");

    const signature = try rpc.advanceNonceAccountWithOptions(
        fee_payer_secret_key_base58,
        current_authority_secret_key_base58,
        nonce_account_base58,
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
        "SigAdv1111111111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.authorizeNonceAccountWithOptions supports distinct fee payer and authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const current_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const new_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const recent_blockhash = [_]u8{0x61} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const current_authority_secret_key = current_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const current_authority_secret_key_base58 = try encodeBase58(allocator, &current_authority_secret_key);
    defer allocator.free(current_authority_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const new_authority_base58 = try encodeBase58(allocator, &new_authority_raw.public_key.toBytes());
    defer allocator.free(new_authority_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const current_authority = try Keypair.fromSecretKeyBytes(current_authority_secret_key);
    const authorize = SystemProgram.authorizeNonceAccount(
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        current_authority.public_key,
        Pubkey.fromBytes(new_authority_raw.public_key.toBytes()),
    );
    const instructions = [_]client.Instruction{authorize.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    const expected_encoded = try expected_transaction.toBase64(
        allocator,
        &.{ fee_payer, current_authority },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":77}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":999}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":\"Sig121212121212121212121212121212121212121212121212121212121212121212\",\"id\":2}");
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":78},\"value\":[{\"slot\":78,\"confirmations\":2,\"confirmationStatus\":\"confirmed\",\"err\":null}]},\"id\":3}");

    const signature = try rpc.authorizeNonceAccountWithOptions(
        fee_payer_secret_key_base58,
        current_authority_secret_key_base58,
        nonce_account_base58,
        new_authority_base58,
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
        "Sig121212121212121212121212121212121212121212121212121212121212121212",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.withdrawNonceAccountWithOptions supports distinct fee payer and authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const current_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const recipient_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x62} ** 32;

    const fee_payer_secret_key = fee_payer_raw.secret_key.toBytes();
    const current_authority_secret_key = current_authority_raw.secret_key.toBytes();
    const fee_payer_secret_key_base58 = try encodeBase58(allocator, &fee_payer_secret_key);
    defer allocator.free(fee_payer_secret_key_base58);
    const current_authority_secret_key_base58 = try encodeBase58(allocator, &current_authority_secret_key);
    defer allocator.free(current_authority_secret_key_base58);
    const nonce_account_base58 = try encodeBase58(allocator, &nonce_account_raw.public_key.toBytes());
    defer allocator.free(nonce_account_base58);
    const recipient_base58 = try encodeBase58(allocator, &recipient_raw.public_key.toBytes());
    defer allocator.free(recipient_base58);
    const recent_blockhash_base58 = try encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const fee_payer = try Keypair.fromSecretKeyBytes(fee_payer_secret_key);
    const current_authority = try Keypair.fromSecretKeyBytes(current_authority_secret_key);
    const withdraw = try SystemProgram.withdrawNonceAccount(
        allocator,
        Pubkey.fromBytes(nonce_account_raw.public_key.toBytes()),
        Pubkey.fromBytes(recipient_raw.public_key.toBytes()),
        current_authority.public_key,
        42_000,
    );
    const instructions = [_]client.Instruction{withdraw.instruction()};
    const expected_transaction = LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };
    const expected_encoded = try expected_transaction.toBase64(
        allocator,
        &.{ fee_payer, current_authority },
    );
    defer allocator.free(expected_encoded);

    const latest_blockhash_response = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":77}},\"value\":{{\"blockhash\":\"{s}\",\"lastValidBlockHeight\":999}}}},\"id\":1}}",
        .{recent_blockhash_base58},
    );
    defer allocator.free(latest_blockhash_response);
    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(latest_blockhash_response);
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":\"Sig343434343434343434343434343434343434343434343434343434343434343434\",\"id\":2}");
    try rpc.pushMockJsonResponse("{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":78},\"value\":[{\"slot\":78,\"confirmations\":2,\"confirmationStatus\":\"confirmed\",\"err\":null}]},\"id\":3}");

    const signature = try rpc.withdrawNonceAccountWithOptions(
        fee_payer_secret_key_base58,
        current_authority_secret_key_base58,
        nonce_account_base58,
        recipient_base58,
        42_000,
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
        "Sig343434343434343434343434343434343434343434343434343434343434343434",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"maxRetries\":2") != null);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}
