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
