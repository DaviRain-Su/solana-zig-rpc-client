const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const client = @import("solana_client_zig");

test "root.writeCompactVecLen uses shortvec little-endian 7-bit chunks" {
    const allocator = std.testing.allocator;
    var bytes = std.ArrayList(u8).empty;
    defer bytes.deinit(allocator);

    try client.writeCompactVecLen(&bytes, allocator, 0);
    try client.writeCompactVecLen(&bytes, allocator, 1);
    try client.writeCompactVecLen(&bytes, allocator, 127);
    try client.writeCompactVecLen(&bytes, allocator, 128);
    try client.writeCompactVecLen(&bytes, allocator, 255);

    const expected = [_]u8{ 0, 1, 127, 128, 1, 255, 1 };
    try std.testing.expect(std.mem.eql(u8, bytes.items, &expected));
}

test "root.decodeBase58 validates characters and lengths" {
    const allocator = std.testing.allocator;

    const zeros = try client.decodeBase58(allocator, "11111111111111111111111111111111");
    defer allocator.free(zeros);
    var expected = [_]u8{0} ** 32;
    try std.testing.expectEqual(@as(usize, 32), zeros.len);
    try std.testing.expect(std.mem.eql(u8, zeros, expected[0..]));

    try std.testing.expectError(
        client.SdkError.InvalidBase58Character,
        client.decodeBase58(allocator, "0"),
    );

    try std.testing.expectError(
        client.SdkError.InvalidBase58Length,
        client.decodeBase58WithLength(allocator, "11111111111111111111111111111111", 31),
    );
}

test "root.encodeBase58 roundtrips decodeBase58" {
    const allocator = std.testing.allocator;

    const source = [_]u8{ 0, 0, 1, 2, 3, 250, 251, 252, 253, 254, 255 };
    const encoded = try client.encodeBase58(allocator, &source);
    defer allocator.free(encoded);

    const decoded = try client.decodeBase58(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expect(std.mem.eql(u8, &source, decoded));
}

test "root.LegacyMessage serializes system transfer" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const transfer = client.SystemProgram.transfer(
        client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]client.Instruction{transfer.instruction()};
    const message = client.LegacyMessage{
        .payer = client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
    };

    const serialized = try message.serialize(allocator);
    defer allocator.free(serialized);

    const expected = try client.buildLegacyTransferMessage(
        allocator,
        sender_key_pair.public_key.toBytes(),
        destination_key_pair.public_key.toBytes(),
        recent_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u8, expected, serialized));
}

test "root.LegacyTransaction signs system transfer" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const recent_blockhash = [_]u8{0x12} ** 32;
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = client.SystemProgram.transfer(
        keypair.public_key,
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]client.Instruction{transfer.instruction()};
    const transaction = client.LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferTransaction(
        allocator,
        &sender_secret_key,
        &destination_key_pair.public_key.toBytes(),
        &recent_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqual(@as(usize, 1), signed.signatures.len);
    try std.testing.expect(std.mem.eql(u8, expected, encoded));
}

test "root.LegacyTransaction toBase64 matches signed transfer payload" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const recent_blockhash = [_]u8{0x12} ** 32;
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer = client.SystemProgram.transfer(
        keypair.public_key,
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const instructions = [_]client.Instruction{transfer.instruction()};
    const transaction = client.LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    const encoded = try transaction.toBase64(allocator, &.{keypair});
    defer allocator.free(encoded);

    const expected = try client.buildLegacyTransferTransaction(
        allocator,
        &sender_secret_key,
        &destination_key_pair.public_key.toBytes(),
        &recent_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u8, expected, encoded));
}

test "root.buildLegacyTransferTransaction builds valid signed transfer payload" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const destination_public_key = destination_key_pair.public_key.toBytes();
    const recent_blockhash = [_]u8{0x12} ** 32;

    const encoded_transaction = try client.buildLegacyTransferTransaction(
        allocator,
        &sender_secret_key,
        &destination_public_key,
        &recent_blockhash,
        1_000,
    );
    defer allocator.free(encoded_transaction);

    const tx_bytes_len = try std.base64.standard.Decoder.calcSizeForSlice(encoded_transaction);
    var tx_bytes = try allocator.alloc(u8, tx_bytes_len);
    defer allocator.free(tx_bytes);
    try std.base64.standard.Decoder.decode(tx_bytes, encoded_transaction);

    try std.testing.expectEqual(@as(u8, 1), tx_bytes[0]);
    try std.testing.expectEqual(@as(usize, 1 + Ed25519.Signature.encoded_length + 147), tx_bytes_len);

    const signature_offset = 1;
    const signature_end = signature_offset + Ed25519.Signature.encoded_length;
    const signature_bytes = tx_bytes[signature_offset..signature_end];
    const message = tx_bytes[signature_end..];

    const signature_array: [Ed25519.Signature.encoded_length]u8 = signature_bytes.*;
    const signature = Ed25519.Signature.fromBytes(signature_array);
    try Ed25519.Signature.verify(signature, message, sender_key_pair.public_key);

    const expected_header = [_]u8{ 1, 0, 1 };
    try std.testing.expect(std.mem.eql(u8, message[0..3], &expected_header));

    try std.testing.expectEqual(@as(u8, 3), message[3]);

    const sender_pubkey_offset = 4;
    const destination_pubkey_offset = sender_pubkey_offset + 32;
    const system_pubkey_offset = destination_pubkey_offset + 32;
    const blockhash_offset = system_pubkey_offset + 32;
    const instructions_offset = blockhash_offset + 32;
    try std.testing.expect(std.mem.eql(u8, message[sender_pubkey_offset..destination_pubkey_offset], &sender_key_pair.public_key.toBytes()));
    try std.testing.expect(std.mem.eql(u8, message[destination_pubkey_offset..system_pubkey_offset], &destination_public_key));
    try std.testing.expect(std.mem.eql(u8, message[system_pubkey_offset..blockhash_offset], &([_]u8{0} ** 32)));
    try std.testing.expect(std.mem.eql(u8, message[blockhash_offset..instructions_offset], &recent_blockhash));

    try std.testing.expectEqual(@as(u8, 1), message[instructions_offset]);
    const first_instruction_offset = instructions_offset + 1;
    try std.testing.expectEqual(@as(u8, 2), message[first_instruction_offset]);
    const first_instruction_account_count_offset = first_instruction_offset + 1;
    try std.testing.expectEqual(@as(u8, 2), message[first_instruction_account_count_offset]);
    try std.testing.expectEqual(@as(u8, 0), message[first_instruction_account_count_offset + 1]);
    try std.testing.expectEqual(@as(u8, 1), message[first_instruction_account_count_offset + 2]);
    const instruction_data_len_offset = first_instruction_account_count_offset + 3;
    try std.testing.expectEqual(@as(u8, 9), message[instruction_data_len_offset]);
    try std.testing.expectEqual(@as(u8, 2), message[instruction_data_len_offset + 1]);
    try std.testing.expectEqual(@as(u8, 232), message[instruction_data_len_offset + 2]);
    try std.testing.expectEqual(@as(u8, 3), message[instruction_data_len_offset + 3]);
    try std.testing.expectEqual(@as(u8, 0), message[instruction_data_len_offset + 4]);
    try std.testing.expectEqual(@as(u8, 0), message[instruction_data_len_offset + 5]);
    try std.testing.expectEqual(@as(u8, 0), message[instruction_data_len_offset + 6]);
    try std.testing.expectEqual(@as(u8, 0), message[instruction_data_len_offset + 7]);
    try std.testing.expectEqual(@as(u8, 0), message[instruction_data_len_offset + 8]);
}

test "root.buildLegacyMessageBytes and base64 match manual legacy message construction" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const extra_signer_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const writable_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const program_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const recent_blockhash = [_]u8{0x19} ** 32;

    const payer = client.Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const extra_signer = client.Pubkey.fromBytes(extra_signer_raw.public_key.toBytes());
    const writable = client.Pubkey.fromBytes(writable_raw.public_key.toBytes());
    const program_id = client.Pubkey.fromBytes(program_raw.public_key.toBytes());
    const instruction_accounts = [_]client.AccountMeta{
        client.AccountMeta.init(payer, true, true),
        client.AccountMeta.init(extra_signer, true, false),
        client.AccountMeta.init(writable, false, true),
    };
    const instruction_data = [_]u8{ 0xaa, 0xbb, 0xcc };
    const instructions = [_]client.Instruction{
        .{
            .program_id = program_id,
            .accounts = instruction_accounts[0..],
            .data = instruction_data[0..],
        },
    };
    const message = client.LegacyMessage{
        .payer = payer,
        .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
    };

    const expected_bytes = try message.serialize(allocator);
    defer allocator.free(expected_bytes);
    const actual_bytes = try client.buildLegacyMessageBytes(
        allocator,
        payer,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(actual_bytes);
    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);

    const expected_base64 = try message.toBase64(allocator);
    defer allocator.free(expected_base64);
    const actual_base64 = try client.buildLegacyMessageBase64(
        allocator,
        payer,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(actual_base64);
    try std.testing.expectEqualSlices(u8, expected_base64, actual_base64);
}

test "root.buildOwnedLegacyMessage clones instructions and signs multi-signer messages" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const extra_signer_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const writable_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const readonly_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const program_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const recent_blockhash = [_]u8{0x23} ** 32;

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const extra_signer = try client.Keypair.fromSecretKeyBytes(extra_signer_raw.secret_key.toBytes());
    const writable = client.Pubkey.fromBytes(writable_raw.public_key.toBytes());
    const readonly = client.Pubkey.fromBytes(readonly_raw.public_key.toBytes());
    const program_id = client.Pubkey.fromBytes(program_raw.public_key.toBytes());
    const instruction_accounts = [_]client.AccountMeta{
        client.AccountMeta.init(payer.public_key, true, true),
        client.AccountMeta.init(extra_signer.public_key, true, false),
        client.AccountMeta.init(writable, false, true),
        client.AccountMeta.init(readonly, false, false),
    };
    const instruction_data = [_]u8{ 0x10, 0x20, 0x30 };
    const instructions = [_]client.Instruction{
        .{
            .program_id = program_id,
            .accounts = instruction_accounts[0..],
            .data = instruction_data[0..],
        },
    };
    const transaction = client.LegacyTransaction{
        .message = .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    var owned = try client.buildOwnedLegacyMessage(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer owned.deinit(allocator);

    try std.testing.expect(owned.message.instructions.ptr != instructions[0..].ptr);
    try std.testing.expect(owned.message.instructions[0].accounts.ptr != instructions[0].accounts.ptr);
    try std.testing.expect(owned.message.instructions[0].data.ptr != instructions[0].data.ptr);

    const expected_bytes = try transaction.message.serialize(allocator);
    defer allocator.free(expected_bytes);
    const actual_bytes = try owned.serialize(allocator);
    defer allocator.free(actual_bytes);
    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);

    var expected_signed = try transaction.sign(allocator, &.{ payer, extra_signer });
    defer expected_signed.deinit(allocator);
    var actual_signed = try owned.sign(allocator, &.{ payer, extra_signer });
    defer actual_signed.deinit(allocator);

    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, actual_signed.message_bytes);
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[0].bytes[0..],
        actual_signed.signatures[0].bytes[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[1].bytes[0..],
        actual_signed.signatures[1].bytes[0..],
    );
}

test "root.SystemProgram.advanceNonceAccount builds durable nonce instruction" {
    const allocator = std.testing.allocator;

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);

    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const authority = client.Pubkey.fromBytes(authority_key_pair.public_key.toBytes());
    const recent_blockhashes_sysvar = try client.Sysvar.recentBlockhashes(allocator);

    const advance = try client.SystemProgram.advanceNonceAccount(
        allocator,
        nonce_account,
        authority,
    );
    const instruction = advance.instruction();

    try std.testing.expect(instruction.program_id.eql(client.SystemProgram.id()));
    try std.testing.expectEqualSlices(u8, &.{4}, instruction.data);
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expect(instruction.accounts[0].pubkey.eql(nonce_account));
    try std.testing.expect(!instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(instruction.accounts[1].pubkey.eql(recent_blockhashes_sysvar));
    try std.testing.expect(!instruction.accounts[1].is_signer);
    try std.testing.expect(!instruction.accounts[1].is_writable);
    try std.testing.expect(instruction.accounts[2].pubkey.eql(authority));
    try std.testing.expect(instruction.accounts[2].is_signer);
    try std.testing.expect(!instruction.accounts[2].is_writable);
}

test "root.SystemProgram.initializeNonceAccount builds durable nonce initialization instruction" {
    const allocator = std.testing.allocator;

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);

    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const authority = client.Pubkey.fromBytes(authority_key_pair.public_key.toBytes());
    const recent_blockhashes_sysvar = try client.Sysvar.recentBlockhashes(allocator);
    const rent_sysvar = try client.Sysvar.rent(allocator);

    const initialize = try client.SystemProgram.initializeNonceAccount(
        allocator,
        nonce_account,
        authority,
    );
    const instruction = initialize.instruction();

    try std.testing.expect(instruction.program_id.eql(client.SystemProgram.id()));
    try std.testing.expectEqual(@as(usize, 33), instruction.data.len);
    try std.testing.expectEqual(@as(u8, 6), instruction.data[0]);
    try std.testing.expectEqualSlices(u8, authority.bytes[0..], instruction.data[1..33]);
    try std.testing.expectEqual(@as(usize, 3), instruction.accounts.len);
    try std.testing.expect(instruction.accounts[0].pubkey.eql(nonce_account));
    try std.testing.expect(!instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(instruction.accounts[1].pubkey.eql(recent_blockhashes_sysvar));
    try std.testing.expect(!instruction.accounts[1].is_signer);
    try std.testing.expect(!instruction.accounts[1].is_writable);
    try std.testing.expect(instruction.accounts[2].pubkey.eql(rent_sysvar));
    try std.testing.expect(!instruction.accounts[2].is_signer);
    try std.testing.expect(!instruction.accounts[2].is_writable);
}

test "root.SystemProgram.authorizeNonceAccount builds durable nonce authorization instruction" {
    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const new_authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);

    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const authority = client.Pubkey.fromBytes(authority_key_pair.public_key.toBytes());
    const new_authority = client.Pubkey.fromBytes(new_authority_key_pair.public_key.toBytes());

    const authorize = client.SystemProgram.authorizeNonceAccount(
        nonce_account,
        authority,
        new_authority,
    );
    const instruction = authorize.instruction();

    try std.testing.expect(instruction.program_id.eql(client.SystemProgram.id()));
    try std.testing.expectEqual(@as(usize, 33), instruction.data.len);
    try std.testing.expectEqual(@as(u8, 7), instruction.data[0]);
    try std.testing.expectEqualSlices(u8, new_authority.bytes[0..], instruction.data[1..33]);
    try std.testing.expectEqual(@as(usize, 2), instruction.accounts.len);
    try std.testing.expect(instruction.accounts[0].pubkey.eql(nonce_account));
    try std.testing.expect(!instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(instruction.accounts[1].pubkey.eql(authority));
    try std.testing.expect(instruction.accounts[1].is_signer);
    try std.testing.expect(!instruction.accounts[1].is_writable);
}

test "root.SystemProgram.withdrawNonceAccount builds durable nonce withdrawal instruction" {
    const allocator = std.testing.allocator;

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const recipient_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const authority = client.Pubkey.fromBytes(authority_key_pair.public_key.toBytes());
    const recipient = client.Pubkey.fromBytes(recipient_key_pair.public_key.toBytes());
    const recent_blockhashes_sysvar = try client.Sysvar.recentBlockhashes(allocator);
    const rent_sysvar = try client.Sysvar.rent(allocator);

    const withdraw = try client.SystemProgram.withdrawNonceAccount(
        allocator,
        nonce_account,
        recipient,
        authority,
        42_000,
    );
    const instruction = withdraw.instruction();

    try std.testing.expect(instruction.program_id.eql(client.SystemProgram.id()));
    try std.testing.expectEqual(@as(usize, 9), instruction.data.len);
    try std.testing.expectEqual(@as(u8, 5), instruction.data[0]);
    try std.testing.expectEqual(@as(u64, 42_000), std.mem.readInt(u64, instruction.data[1..9], .little));
    try std.testing.expectEqual(@as(usize, 5), instruction.accounts.len);
    try std.testing.expect(instruction.accounts[0].pubkey.eql(nonce_account));
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(instruction.accounts[1].pubkey.eql(recipient));
    try std.testing.expect(instruction.accounts[1].is_writable);
    try std.testing.expect(instruction.accounts[2].pubkey.eql(recent_blockhashes_sysvar));
    try std.testing.expect(!instruction.accounts[2].is_signer);
    try std.testing.expect(!instruction.accounts[2].is_writable);
    try std.testing.expect(instruction.accounts[3].pubkey.eql(rent_sysvar));
    try std.testing.expect(!instruction.accounts[3].is_signer);
    try std.testing.expect(!instruction.accounts[3].is_writable);
    try std.testing.expect(instruction.accounts[4].pubkey.eql(authority));
    try std.testing.expect(instruction.accounts[4].is_signer);
    try std.testing.expect(!instruction.accounts[4].is_writable);
}

test "root.prependNonceAdvanceInstruction prepends durable nonce and clones instruction payloads" {
    const allocator = std.testing.allocator;

    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const authority_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);

    const authority = client.Pubkey.fromBytes(authority_key_pair.public_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const transfer = client.SystemProgram.transfer(authority, destination, 1_000);
    const original_instructions = [_]client.Instruction{transfer.instruction()};

    var owned = try client.prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        authority,
        original_instructions[0..],
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instructions.len);
    try std.testing.expect(owned.instructions[0].program_id.eql(client.SystemProgram.id()));
    try std.testing.expectEqualSlices(u8, &.{4}, owned.instructions[0].data);
    try std.testing.expect(owned.instructions[0].accounts[0].pubkey.eql(nonce_account));
    try std.testing.expect(owned.instructions[0].accounts[2].pubkey.eql(authority));
    try std.testing.expect(owned.instructions[1].program_id.eql(original_instructions[0].program_id));
    try std.testing.expectEqualSlices(u8, original_instructions[0].data, owned.instructions[1].data);
    try std.testing.expectEqual(@as(usize, original_instructions[0].accounts.len), owned.instructions[1].accounts.len);
    try std.testing.expect(owned.instructions[1].accounts.ptr != original_instructions[0].accounts.ptr);
    try std.testing.expect(owned.instructions[1].data.ptr != original_instructions[0].data.ptr);
}

test "root.buildLegacyTransferTransactionWithNonce matches typed durable nonce transfer" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const advance = try client.SystemProgram.advanceNonceAccount(
        allocator,
        nonce_account,
        keypair.public_key,
    );
    const transfer = client.SystemProgram.transfer(keypair.public_key, destination, 1_000);
    const instructions = [_]client.Instruction{
        advance.instruction(),
        transfer.instruction(),
    };
    const transaction = client.LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    const expected = try transaction.toBase64(allocator, &.{keypair});
    defer allocator.free(expected);

    const actual = try client.buildLegacyTransferTransactionWithNonce(
        allocator,
        &sender_secret_key,
        &nonce_account_key_pair.public_key.toBytes(),
        &destination_key_pair.public_key.toBytes(),
        &recent_blockhash,
        1_000,
    );
    defer allocator.free(actual);

    try std.testing.expect(std.mem.eql(u8, expected, actual));
}

test "root.buildLegacyMessageWithNonceInstructions matches transfer-specific durable nonce helper" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;

    const sender = client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const transfer = client.SystemProgram.transfer(sender, destination, 1_000);
    const instructions = [_]client.Instruction{transfer.instruction()};

    const expected = try client.buildLegacyTransferMessageWithNonce(
        allocator,
        sender_key_pair.public_key.toBytes(),
        nonce_account_key_pair.public_key.toBytes(),
        destination_key_pair.public_key.toBytes(),
        recent_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    const actual = try client.buildLegacyMessageWithNonceInstructions(
        allocator,
        sender,
        nonce_account,
        sender,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "root.buildSignedLegacyTransactionWithNonceInstructions matches transfer-specific durable nonce helper" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const transfer = client.SystemProgram.transfer(keypair.public_key, destination, 1_000);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        keypair.public_key,
        nonce_account,
        keypair.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{keypair},
    );
    defer signed.deinit(allocator);

    const actual = try signed.toBase64(allocator);
    defer allocator.free(actual);

    const expected = try client.buildLegacyTransferTransactionWithNonce(
        allocator,
        &sender_secret_key,
        &nonce_account_key_pair.public_key.toBytes(),
        &destination_key_pair.public_key.toBytes(),
        &recent_blockhash,
        1_000,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "root.buildOwnedLegacyMessageWithNonceInstructions signs like generic durable nonce helper" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const nonce_account_key_pair = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const nonce_account = client.Pubkey.fromBytes(nonce_account_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const transfer = client.SystemProgram.transfer(keypair.public_key, destination, 1_000);
    const instructions = [_]client.Instruction{transfer.instruction()};

    var owned = try client.buildOwnedLegacyMessageWithNonceInstructions(
        allocator,
        keypair.public_key,
        nonce_account,
        keypair.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.message.instructions.len);
    try std.testing.expectEqualSlices(u8, &.{4}, owned.message.instructions[0].data);

    var actual_signed = try owned.sign(allocator, &.{keypair});
    defer actual_signed.deinit(allocator);

    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        keypair.public_key,
        nonce_account,
        keypair.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{keypair},
    );
    defer expected_signed.deinit(allocator);

    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, actual_signed.message_bytes);
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[0].bytes[0..],
        actual_signed.signatures[0].bytes[0..],
    );
}

test "root.buildSignedLegacyNonceTransferTransaction supports distinct payer sender and nonce authority" {
    const allocator = std.testing.allocator;

    const fee_payer_raw = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const sender_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const nonce_authority_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const nonce_account_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x44} ** 32;

    const fee_payer = try client.Keypair.fromSecretKeyBytes(fee_payer_raw.secret_key.toBytes());
    const sender = try client.Keypair.fromSecretKeyBytes(sender_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_raw.public_key.toBytes());

    const advance = try client.SystemProgram.advanceNonceAccount(
        allocator,
        nonce_account,
        nonce_authority.public_key,
    );
    const transfer = client.SystemProgram.transfer(sender.public_key, destination, 1_000);
    const instructions = [_]client.Instruction{
        advance.instruction(),
        transfer.instruction(),
    };
    const expected_transaction = client.LegacyTransaction{
        .message = .{
            .payer = fee_payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    var expected_signed = try expected_transaction.sign(
        allocator,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer expected_signed.deinit(allocator);

    var actual_signed = try client.buildSignedLegacyNonceTransferTransaction(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination,
        client.Hash.fromBytes(recent_blockhash),
        1_000,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer actual_signed.deinit(allocator);

    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, actual_signed.message_bytes);
    try std.testing.expectEqual(@as(usize, 3), actual_signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[0].bytes[0..], actual_signed.signatures[0].bytes[0..]);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[1].bytes[0..], actual_signed.signatures[1].bytes[0..]);
    try std.testing.expectEqualSlices(u8, expected_signed.signatures[2].bytes[0..], actual_signed.signatures[2].bytes[0..]);

    var owned = try client.buildOwnedLegacyNonceTransferMessage(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination,
        client.Hash.fromBytes(recent_blockhash),
        1_000,
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.message.instructions.len);
    try std.testing.expect(owned.message.instructions[0].accounts[2].pubkey.eql(nonce_authority.public_key));
    try std.testing.expect(owned.message.instructions[1].accounts[0].pubkey.eql(sender.public_key));

    const expected_base64 = try expected_transaction.toBase64(
        allocator,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(expected_base64);

    const actual_base64 = try client.buildLegacyNonceTransferTransactionBase64(
        allocator,
        fee_payer.public_key,
        sender.public_key,
        nonce_account,
        nonce_authority.public_key,
        destination,
        client.Hash.fromBytes(recent_blockhash),
        1_000,
        &.{ fee_payer, sender, nonce_authority },
    );
    defer allocator.free(actual_base64);

    try std.testing.expectEqualSlices(u8, expected_base64, actual_base64);
}

test "root.buildSignedLegacyTransaction and base64 match manual multi-signer legacy flow" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const extra_signer_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const writable_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const readonly_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const program_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const recent_blockhash = [_]u8{0x23} ** 32;

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const extra_signer = try client.Keypair.fromSecretKeyBytes(extra_signer_raw.secret_key.toBytes());
    const writable = client.Pubkey.fromBytes(writable_raw.public_key.toBytes());
    const readonly = client.Pubkey.fromBytes(readonly_raw.public_key.toBytes());
    const program_id = client.Pubkey.fromBytes(program_raw.public_key.toBytes());
    const instruction_accounts = [_]client.AccountMeta{
        client.AccountMeta.init(payer.public_key, true, true),
        client.AccountMeta.init(extra_signer.public_key, true, false),
        client.AccountMeta.init(writable, false, true),
        client.AccountMeta.init(readonly, false, false),
    };
    const instruction_data = [_]u8{ 0x10, 0x20, 0x30 };
    const instructions = [_]client.Instruction{
        .{
            .program_id = program_id,
            .accounts = instruction_accounts[0..],
            .data = instruction_data[0..],
        },
    };
    const transaction = client.LegacyTransaction{
        .message = .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
        },
    };

    var expected_signed = try transaction.sign(allocator, &.{ payer, extra_signer });
    defer expected_signed.deinit(allocator);
    var actual_signed = try client.buildSignedLegacyTransaction(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{ payer, extra_signer },
    );
    defer actual_signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, expected_signed.signatures.len), actual_signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, actual_signed.message_bytes);
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[0].bytes[0..],
        actual_signed.signatures[0].bytes[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[1].bytes[0..],
        actual_signed.signatures[1].bytes[0..],
    );

    const expected_base64 = try transaction.toBase64(allocator, &.{ payer, extra_signer });
    defer allocator.free(expected_base64);
    const actual_base64 = try client.buildLegacyTransactionBase64(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        &.{ payer, extra_signer },
    );
    defer allocator.free(actual_base64);
    try std.testing.expectEqualSlices(u8, expected_base64, actual_base64);
}

test "root.VersionedMessageV0 serializes system transfer with lookup table references" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const lookup_table_key_pair = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const transfer_instruction = client.SystemProgram.transfer(
        client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]client.CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const writable_indexes = [_]u8{ 0, 2 };
    const readonly_indexes = [_]u8{1};
    const lookups = [_]client.MessageAddressTableLookup{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_key_pair.public_key.toBytes()),
            .writable_indexes = writable_indexes[0..],
            .readonly_indexes = readonly_indexes[0..],
        },
    };
    const account_keys = [_]client.Pubkey{
        client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes()),
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        client.SystemProgram.id(),
    };
    const message = client.VersionedMessageV0{
        .header = .{
            .num_required_signatures = 1,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 1,
        },
        .account_keys = account_keys[0..],
        .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
        .address_table_lookups = lookups[0..],
    };

    const serialized = try message.serialize(allocator);
    defer allocator.free(serialized);

    const expected = try client.buildVersionedTransferMessageBytes(
        allocator,
        sender_key_pair.public_key.toBytes(),
        destination_key_pair.public_key.toBytes(),
        recent_blockhash,
        1_000,
        lookups[0..],
    );
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u8, expected, serialized));
}

test "root.compileVersionedMessageV0 compiles transfer accounts through lookup tables" {
    const allocator = std.testing.allocator;

    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const lookup_table_key_pair = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const unused_lookup_table_key_pair = try Ed25519.KeyPair.generateDeterministic(.{6} ** 32);
    const unused_lookup_address_key_pair = try Ed25519.KeyPair.generateDeterministic(.{2} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const sender = client.Pubkey.fromBytes(sender_key_pair.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes());
    const transfer_instruction = client.SystemProgram.transfer(sender, destination, 1_000);
    const instructions = [_]client.Instruction{transfer_instruction.instruction()};
    const lookup_addresses = [_]client.Pubkey{destination};
    const unused_lookup_addresses = [_]client.Pubkey{
        client.Pubkey.fromBytes(unused_lookup_address_key_pair.public_key.toBytes()),
    };
    const lookup_tables = [_]client.AddressLookupTableAccount{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_key_pair.public_key.toBytes()),
            .addresses = lookup_addresses[0..],
        },
        .{
            .account_key = client.Pubkey.fromBytes(unused_lookup_table_key_pair.public_key.toBytes()),
            .addresses = unused_lookup_addresses[0..],
        },
    };

    var compiled = try client.compileVersionedMessageV0(
        allocator,
        sender,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer compiled.deinit(allocator);

    try std.testing.expectEqual(@as(u8, 1), compiled.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 0), compiled.message.header.num_readonly_signed_accounts);
    try std.testing.expectEqual(@as(u8, 1), compiled.message.header.num_readonly_unsigned_accounts);
    try std.testing.expectEqual(@as(usize, 2), compiled.message.account_keys.len);
    try std.testing.expect(compiled.message.account_keys[0].eql(sender));
    try std.testing.expect(compiled.message.account_keys[1].eql(client.SystemProgram.id()));
    try std.testing.expectEqual(@as(usize, 1), compiled.message.address_table_lookups.len);
    try std.testing.expectEqualSlices(u8, &.{0}, compiled.message.address_table_lookups[0].writable_indexes);
    try std.testing.expectEqual(@as(usize, 0), compiled.message.address_table_lookups[0].readonly_indexes.len);
    try std.testing.expectEqual(@as(usize, 1), compiled.message.instructions.len);
    try std.testing.expectEqual(@as(u8, 1), compiled.message.instructions[0].program_id_index);
    try std.testing.expectEqualSlices(u8, &.{ 0, 2 }, compiled.message.instructions[0].account_indexes);

    const account_indexes = [_]u8{ 0, 2 };
    const expected_instructions = [_]client.CompiledInstruction{
        .{
            .program_id_index = 1,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const writable_indexes = [_]u8{0};
    const expected_lookups = [_]client.MessageAddressTableLookup{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_key_pair.public_key.toBytes()),
            .writable_indexes = writable_indexes[0..],
            .readonly_indexes = &.{},
        },
    };
    const expected_account_keys = [_]client.Pubkey{
        sender,
        client.SystemProgram.id(),
    };
    const expected_message = client.VersionedMessageV0{
        .header = .{
            .num_required_signatures = 1,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 1,
        },
        .account_keys = expected_account_keys[0..],
        .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
        .instructions = expected_instructions[0..],
        .address_table_lookups = expected_lookups[0..],
    };

    const expected = try expected_message.serialize(allocator);
    defer allocator.free(expected);

    const actual = try compiled.serialize(allocator);
    defer allocator.free(actual);

    try std.testing.expect(std.mem.eql(u8, expected, actual));
}

test "root.compileVersionedMessageV0 keeps signers static and signs compiled messages" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const signer_raw = try Ed25519.KeyPair.generateDeterministic(.{5} ** 32);
    const writable_loaded_raw = try Ed25519.KeyPair.generateDeterministic(.{3} ** 32);
    const readonly_loaded_raw = try Ed25519.KeyPair.generateDeterministic(.{4} ** 32);
    const program_raw = try Ed25519.KeyPair.generateDeterministic(.{8} ** 32);
    const lookup_table_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const recent_blockhash = [_]u8{0x34} ** 32;

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const extra_signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const writable_loaded = client.Pubkey.fromBytes(writable_loaded_raw.public_key.toBytes());
    const readonly_loaded = client.Pubkey.fromBytes(readonly_loaded_raw.public_key.toBytes());
    const program_id = client.Pubkey.fromBytes(program_raw.public_key.toBytes());

    const instruction_accounts = [_]client.AccountMeta{
        client.AccountMeta.init(payer.public_key, true, true),
        client.AccountMeta.init(extra_signer.public_key, true, false),
        client.AccountMeta.init(writable_loaded, false, true),
        client.AccountMeta.init(readonly_loaded, false, false),
    };
    const instruction_data = [_]u8{ 0xaa, 0xbb, 0xcc };
    const instructions = [_]client.Instruction{
        .{
            .program_id = program_id,
            .accounts = instruction_accounts[0..],
            .data = instruction_data[0..],
        },
    };
    const lookup_addresses = [_]client.Pubkey{
        writable_loaded,
        readonly_loaded,
    };
    const lookup_tables = [_]client.AddressLookupTableAccount{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_raw.public_key.toBytes()),
            .addresses = lookup_addresses[0..],
        },
    };

    var compiled = try client.VersionedMessageV0.compile(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer compiled.deinit(allocator);

    try std.testing.expectEqual(@as(u8, 2), compiled.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 1), compiled.message.header.num_readonly_signed_accounts);
    try std.testing.expectEqual(@as(u8, 1), compiled.message.header.num_readonly_unsigned_accounts);
    try std.testing.expectEqual(@as(usize, 3), compiled.message.account_keys.len);
    try std.testing.expect(compiled.message.account_keys[0].eql(payer.public_key));
    try std.testing.expect(compiled.message.account_keys[1].eql(extra_signer.public_key));
    try std.testing.expect(compiled.message.account_keys[2].eql(program_id));
    try std.testing.expectEqualSlices(u8, &.{0}, compiled.message.address_table_lookups[0].writable_indexes);
    try std.testing.expectEqualSlices(u8, &.{1}, compiled.message.address_table_lookups[0].readonly_indexes);
    try std.testing.expectEqual(@as(u8, 2), compiled.message.instructions[0].program_id_index);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 3, 4 }, compiled.message.instructions[0].account_indexes);

    var signed = try compiled.sign(allocator, &.{ payer, extra_signer });
    defer signed.deinit(allocator);

    const expected_payer_signature = try payer.signMessage(signed.message_bytes);
    const expected_extra_signature = try extra_signer.signMessage(signed.message_bytes);
    try std.testing.expectEqual(@as(usize, 2), signed.signatures.len);
    try std.testing.expect(std.mem.eql(u8, expected_payer_signature.bytes[0..], signed.signatures[0].bytes[0..]));
    try std.testing.expect(std.mem.eql(u8, expected_extra_signature.bytes[0..], signed.signatures[1].bytes[0..]));
}

test "root.buildSignedVersionedTransactionV0 matches compile-and-sign flow" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const lookup_table_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const recent_blockhash = [_]u8{0x34} ** 32;

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer_instruction = client.SystemProgram.transfer(
        payer.public_key,
        destination,
        1_000,
    );
    const instructions = [_]client.Instruction{transfer_instruction.instruction()};
    const lookup_tables = [_]client.AddressLookupTableAccount{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_raw.public_key.toBytes()),
            .addresses = &.{destination},
        },
    };

    var expected_compiled = try client.compileVersionedMessageV0(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer expected_compiled.deinit(allocator);

    var expected_signed = try expected_compiled.sign(allocator, &.{payer});
    defer expected_signed.deinit(allocator);

    var actual_signed = try client.buildSignedVersionedTransactionV0(
        allocator,
        payer.public_key,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
        &.{payer},
    );
    defer actual_signed.deinit(allocator);

    try std.testing.expectEqual(@as(usize, expected_signed.signatures.len), actual_signed.signatures.len);
    try std.testing.expectEqualSlices(u8, expected_signed.message_bytes, actual_signed.message_bytes);
    try std.testing.expectEqualSlices(
        u8,
        expected_signed.signatures[0].bytes[0..],
        actual_signed.signatures[0].bytes[0..],
    );
}

test "root.buildVersionedMessageV0Bytes and base64 match compile flow" {
    const allocator = std.testing.allocator;

    const payer_raw = try Ed25519.KeyPair.generateDeterministic(.{7} ** 32);
    const destination_raw = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const lookup_table_raw = try Ed25519.KeyPair.generateDeterministic(.{9} ** 32);
    const recent_blockhash = [_]u8{0x34} ** 32;

    const payer = client.Pubkey.fromBytes(payer_raw.public_key.toBytes());
    const destination = client.Pubkey.fromBytes(destination_raw.public_key.toBytes());
    const transfer_instruction = client.SystemProgram.transfer(payer, destination, 1_000);
    const instructions = [_]client.Instruction{transfer_instruction.instruction()};
    const lookup_tables = [_]client.AddressLookupTableAccount{
        .{
            .account_key = client.Pubkey.fromBytes(lookup_table_raw.public_key.toBytes()),
            .addresses = &.{destination},
        },
    };

    var compiled = try client.compileVersionedMessageV0(
        allocator,
        payer,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer compiled.deinit(allocator);

    const expected_bytes = try compiled.serialize(allocator);
    defer allocator.free(expected_bytes);
    const actual_bytes = try client.buildVersionedMessageV0Bytes(
        allocator,
        payer,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer allocator.free(actual_bytes);
    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);

    const expected_base64 = try compiled.toBase64(allocator);
    defer allocator.free(expected_base64);
    const actual_base64 = try client.buildVersionedMessageV0Base64(
        allocator,
        payer,
        client.Hash.fromBytes(recent_blockhash),
        instructions[0..],
        lookup_tables[0..],
    );
    defer allocator.free(actual_base64);
    try std.testing.expectEqualSlices(u8, expected_base64, actual_base64);
}

test "root.VersionedTransaction signs system transfer" {
    const allocator = std.testing.allocator;

    const sender_seed = [_]u8{7} ** 32;
    const sender_key_pair = try Ed25519.KeyPair.generateDeterministic(sender_seed);
    const sender_secret_key = sender_key_pair.secret_key.toBytes();
    const destination_key_pair = try Ed25519.KeyPair.generateDeterministic(.{1} ** 32);
    const recent_blockhash = [_]u8{0x12} ** 32;

    const keypair = try client.Keypair.fromSecretKeyBytes(sender_secret_key);
    const transfer_instruction = client.SystemProgram.transfer(
        keypair.public_key,
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        1_000,
    );
    const account_indexes = [_]u8{ 0, 1 };
    const instructions = [_]client.CompiledInstruction{
        .{
            .program_id_index = 2,
            .account_indexes = account_indexes[0..],
            .data = transfer_instruction.data[0..],
        },
    };
    const address_table_lookups = [_]client.MessageAddressTableLookup{};
    const account_keys = [_]client.Pubkey{
        keypair.public_key,
        client.Pubkey.fromBytes(destination_key_pair.public_key.toBytes()),
        client.SystemProgram.id(),
    };
    const transaction = client.VersionedTransaction{
        .message = .{
            .header = .{
                .num_required_signatures = 1,
                .num_readonly_signed_accounts = 0,
                .num_readonly_unsigned_accounts = 1,
            },
            .account_keys = account_keys[0..],
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instructions = instructions[0..],
            .address_table_lookups = address_table_lookups[0..],
        },
    };

    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    const expected_signature = try keypair.signMessage(signed.message_bytes);
    try std.testing.expectEqual(@as(usize, 1), signed.signatures.len);
    try std.testing.expect(std.mem.eql(u8, expected_signature.bytes[0..], signed.signatures[0].bytes[0..]));

    const serialized = try signed.serialize(allocator);
    defer allocator.free(serialized);

    try std.testing.expectEqual(@as(usize, 1 + Ed25519.Signature.encoded_length + signed.message_bytes.len), serialized.len);
    try std.testing.expectEqual(@as(u8, 1), serialized[0]);
    try std.testing.expect(std.mem.eql(u8, expected_signature.bytes[0..], serialized[1 .. 1 + Ed25519.Signature.encoded_length]));
    try std.testing.expect(std.mem.eql(u8, signed.message_bytes, serialized[1 + Ed25519.Signature.encoded_length ..]));
}
