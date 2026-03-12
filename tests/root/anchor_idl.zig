const std = @import("std");
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

fn createProgramAddress(seeds: []const []const u8, program_id: client.Pubkey) !client.Pubkey {
    for (seeds) |seed| {
        if (seed.len > 32) return error.InvalidSeed;
    }

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (seeds) |seed| hasher.update(seed);
    hasher.update(&program_id.bytes);
    hasher.update("ProgramDerivedAddress");

    var hash: [32]u8 = undefined;
    hasher.final(&hash);
    if (std.crypto.ecc.Edwards25519.fromBytes(hash)) |_| {
        return error.InvalidSeed;
    } else |_| {}
    return client.Pubkey.fromBytes(hash);
}

fn findProgramAddress(allocator: std.mem.Allocator, seeds: []const []const u8, program_id: client.Pubkey) !client.Pubkey {
    const search_seeds = try allocator.alloc([]const u8, seeds.len + 1);
    defer allocator.free(search_seeds);
    @memcpy(search_seeds[0..seeds.len], seeds);

    var bump_seed: [1]u8 = undefined;
    search_seeds[seeds.len] = bump_seed[0..];

    var bump: i16 = 255;
    while (bump >= 0) : (bump -= 1) {
        bump_seed[0] = @intCast(bump);
        const candidate = createProgramAddress(search_seeds, program_id) catch continue;
        return candidate;
    }
    return error.InvalidSeed;
}

test "root.anchor_idl.parseJson ignores unknown fields and resolves metadata program id" {
    const allocator = std.testing.allocator;
    const parsed = try client.anchor_idl.parseJson(allocator,
        \\{"metadata":{"program_id":"11111111111111111111111111111111"},"instructions":[{"name":"initialize_config","discriminator":[1,2,3,4,5,6,7,8],"accounts":[],"args":[]}],"extra":{"ignored":true}}
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings(
        "11111111111111111111111111111111",
        client.anchor_idl.programAddress(&parsed.value).?,
    );
    try std.testing.expect(client.anchor_idl.findInstruction(&parsed.value, "initializeConfig") != null);
}

test "root.anchor_idl_encode.encodeInstructionDataNamed matches instruction aliases" {
    const allocator = std.testing.allocator;
    const parsed = try client.anchor_idl.parseJson(allocator,
        \\{"instructions":[{"name":"setValues","discriminator":[9,9,9,9,9,9,9,9],"args":[{"name":"count","type":"u16"}]}]}
    );
    defer parsed.deinit();

    const encoded = try client.anchor_idl_encode.encodeInstructionDataNamed(
        allocator,
        &parsed.value,
        "set_values",
        "{\"count\":513}",
    );
    defer allocator.free(encoded);

    const expected = [_]u8{ 9, 9, 9, 9, 9, 9, 9, 9, 0x01, 0x02 };
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "root.anchor_idl_encode.encodeInstructionDataFromJson parses and encodes in one step" {
    const allocator = std.testing.allocator;
    const authority = client.Pubkey.fromBytes(.{7} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const args_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":\"{s}\"}}",
        .{authority_base58},
    );
    defer allocator.free(args_json);

    const encoded = try client.anchor_idl_encode.encodeInstructionDataFromJson(
        allocator,
        \\{"instructions":[{"name":"setAuthority","discriminator":[5,4,3,2,1,0,9,8],"args":[{"name":"authority","type":"publicKey"}]}],"unexpected":"ignored"}
    ,
        "set_authority",
        args_json,
    );
    defer allocator.free(encoded);

    var expected = std.ArrayListUnmanaged(u8){};
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, &.{ 5, 4, 3, 2, 1, 0, 9, 8 });
    try expected.appendSlice(allocator, &authority.bytes);

    try std.testing.expectEqualSlices(u8, expected.items, encoded);
}

test "root.anchor_idl_encode.encodeInstructionDataNamed returns missing instruction error" {
    const allocator = std.testing.allocator;
    const parsed = try client.anchor_idl.parseJson(allocator,
        \\{"instructions":[{"name":"setAuthority","discriminator":[1,1,1,1,1,1,1,1],"args":[]}]}
    );
    defer parsed.deinit();

    try std.testing.expectError(
        client.anchor_idl_encode.EncodeError.MissingAnchorIdlInstruction,
        client.anchor_idl_encode.encodeInstructionDataNamed(
            allocator,
            &parsed.value,
            "close_authority",
            null,
        ),
    );
}

test "root.anchor_idl_encode.encodeInstructionDataNamed computes missing discriminator" {
    const allocator = std.testing.allocator;
    const parsed = try client.anchor_idl.parseJson(allocator,
        \\{"instructions":[{"name":"initializeConfig","args":[{"name":"count","type":"u8"}]}]}
    );
    defer parsed.deinit();

    const encoded = try client.anchor_idl_encode.encodeInstructionDataNamed(
        allocator,
        &parsed.value,
        "initialize_config",
        "{\"count\":7}",
    );
    defer allocator.free(encoded);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("global:initializeConfig", &digest, .{});

    try std.testing.expectEqualSlices(u8, digest[0..8], encoded[0..8]);
    try std.testing.expectEqual(@as(u8, 7), encoded[8]);
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves bindings default signer and builtins" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{41} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const state = client.Pubkey.fromBytes(.{42} ** 32);
    const signer = client.Pubkey.fromBytes(.{43} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"setFlag","discriminator":[1,2,3,4,5,6,7,8],"accounts":[{{"name":"state","writable":true}},{{"name":"authority","signer":true}},{{"name":"systemProgram"}}],"args":[{{"name":"enabled","type":"bool"}}]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const parsed = try client.anchor_idl.parseJson(allocator, idl_json);
    defer parsed.deinit();

    var owned = try client.anchor_idl_invoke.buildOwnedInstruction(
        allocator,
        &parsed.value,
        "set_flag",
        .{
            .args_json = "{\"enabled\":true}",
            .account_bindings = &.{
                .{ .path = "state", .pubkey = state },
            },
            .default_signer = signer,
        },
    );
    defer owned.deinit(allocator);

    const system_program = try client.Pubkey.fromBase58(allocator, "11111111111111111111111111111111");

    try std.testing.expect(owned.instruction.program_id.eql(program_id));
    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(state));
    try std.testing.expect(!owned.instruction.accounts[0].is_signer);
    try std.testing.expect(owned.instruction.accounts[0].is_writable);
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(signer));
    try std.testing.expect(owned.instruction.accounts[1].is_signer);
    try std.testing.expect(!owned.instruction.accounts[1].is_writable);
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(system_program));
    try std.testing.expect(!owned.instruction.accounts[2].is_signer);
    try std.testing.expect(!owned.instruction.accounts[2].is_writable);

    const expected = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 1 };
    try std.testing.expectEqualSlices(u8, &expected, owned.instruction.data);
}

test "root.anchor_idl_invoke.buildOwnedInstruction fills missing optional accounts with program id" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{44} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const payer = client.Pubkey.fromBytes(.{45} ** 32);
    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"configure","discriminator":[8,7,6,5,4,3,2,1],"accounts":[{{"name":"payer","signer":true,"writable":true}},{{"name":"delegate","optional":true,"signer":true,"writable":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "configure",
        .{
            .default_signer = payer,
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(payer));
    try std.testing.expect(owned.instruction.accounts[0].is_signer);
    try std.testing.expect(owned.instruction.accounts[0].is_writable);
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
    try std.testing.expect(!owned.instruction.accounts[1].is_signer);
    try std.testing.expect(!owned.instruction.accounts[1].is_writable);
}

test "root.anchor_idl_invoke.buildOwnedInstruction derives const seed pda" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{46} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = client.Pubkey.fromBytes(.{47} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[9,9,9,9,9,9,9,9],"accounts":[{{"name":"vault","pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}}]}},"writable":true}},{{"name":"payer","signer":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{
            .default_signer = payer,
        },
    );
    defer owned.deinit(allocator);

    const expected_vault = try findProgramAddress(allocator, &.{"vault"}, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_vault));
    try std.testing.expect(owned.instruction.accounts[0].is_writable);
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(payer));
}

test "root.anchor_idl_invoke.buildOwnedInstruction derives arg seed pda" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{48} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[7,7,7,7,7,7,7,7],"accounts":[{{"name":"vault","pda":{{"seeds":[{{"kind":"const","value":"vault"}},{{"kind":"arg","path":"label"}}]}}}}],"args":[{{"name":"label","type":"string"}}]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{
            .args_json = "{\"label\":\"main\"}",
        },
    );
    defer owned.deinit(allocator);

    const expected_vault = try findProgramAddress(allocator, &.{ "vault", "main" }, program_id);
    try std.testing.expectEqual(@as(usize, 1), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_vault));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves relation binding path" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{49} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const vault = client.Pubkey.fromBytes(.{50} ** 32);
    const authority = client.Pubkey.fromBytes(.{51} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"update","discriminator":[6,6,6,6,6,6,6,6],"accounts":[{{"name":"vault","writable":true}},{{"name":"authority","signer":true,"relations":["vault"]}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "update",
        .{
            .account_bindings = &.{
                .{ .path = "vault", .pubkey = vault },
                .{ .path = "vault.authority", .pubkey = authority },
            },
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(vault));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(authority));
}

test "root.anchor_idl_invoke.buildOwnedInstruction returns unsupported account feature for scalar account seed pda" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{52} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const config = client.Pubkey.fromBytes(.{53} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[9,9,9,9,9,9,9,9],"accounts":[{{"name":"config"}},{{"name":"vault","pda":{{"seeds":[{{"kind":"account","path":"config.counter","type":"u64"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const parsed = try client.anchor_idl.parseJson(allocator, idl_json);
    defer parsed.deinit();

    try std.testing.expectError(
        client.anchor_idl_invoke.BuildError.UnsupportedAnchorIdlAccountFeature,
        client.anchor_idl_invoke.buildOwnedInstruction(
            allocator,
            &parsed.value,
            "initialize",
            .{
                .account_bindings = &.{
                    .{ .path = "config", .pubkey = config },
                },
            },
        ),
    );
}

test "root.anchor_idl_invoke.buildOwnedLegacyMessageFromJson builds typed legacy message" {
    const allocator = std.testing.allocator;
    const program_id = try client.sdk.Pubkey.fromBase58(allocator, "11111111111111111111111111111111");
    const payer = try client.sdk.Pubkey.fromBase58(allocator, "ComputeBudget111111111111111111111111111111");
    const authority = try client.sdk.Pubkey.fromBase58(allocator, "Stake11111111111111111111111111111111111111");
    const target = try client.sdk.Pubkey.fromBase58(allocator, "Vote111111111111111111111111111111111111111");
    const args_json = "{\"value\":42}";

    var owned = try client.anchor_idl_invoke.buildOwnedLegacyMessageFromJson(
        allocator,
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
    ,
        "setValue",
        .{
            .payer = payer,
            .recent_blockhash = client.sdk.Hash.fromBytes([_]u8{9} ** 32),
            .instruction_options = .{
                .args_json = args_json,
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = authority },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expect(owned.message.payer.eql(payer));
    try std.testing.expectEqual(client.sdk.Hash.fromBytes([_]u8{9} ** 32), owned.message.recent_blockhash);
    try std.testing.expectEqual(@as(usize, 1), owned.message.instructions.len);

    const instruction = owned.message.instructions[0];
    try std.testing.expect(instruction.program_id.eql(program_id));
    try std.testing.expectEqual(@as(usize, 2), instruction.accounts.len);
    try std.testing.expect(instruction.accounts[0].pubkey.eql(authority));
    try std.testing.expect(instruction.accounts[0].is_signer);
    try std.testing.expect(instruction.accounts[0].is_writable);
    try std.testing.expect(instruction.accounts[1].pubkey.eql(target));
    try std.testing.expect(!instruction.accounts[1].is_signer);
    try std.testing.expect(instruction.accounts[1].is_writable);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6, 7, 8 }, instruction.data[0..8]);
    try std.testing.expectEqual(@as(usize, 16), instruction.data.len);
    try std.testing.expectEqual(@as(u64, 42), std.mem.readInt(u64, instruction.data[8..16], .little));
}

test "root.anchor_idl_invoke.buildSignedLegacyTransactionFromJson signs and encodes transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{7} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{8} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x11} ** 32);
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

    var signed = try client.anchor_idl_invoke.buildSignedLegacyTransactionFromJson(
        allocator,
        idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const direct_base64 = try signed.toBase64(allocator);
    defer allocator.free(direct_base64);

    const helper_base64 = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer allocator.free(helper_base64);

    try std.testing.expect(signed.firstSignature() != null);
    try std.testing.expect(direct_base64.len > 0);
    try std.testing.expectEqualSlices(u8, direct_base64, helper_base64);
}

test "root.anchor_idl_invoke.buildOwnedVersionedMessageFromJson compiles and signs versioned transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{9} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{10} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x22} ** 32);
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

    var owned = try client.anchor_idl_invoke.buildOwnedVersionedMessageFromJson(
        allocator,
        idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer owned.deinit(allocator);

    var direct_signed = try owned.sign(allocator, &.{signer});
    defer direct_signed.deinit(allocator);

    const direct_base64 = try direct_signed.toBase64(allocator);
    defer allocator.free(direct_base64);

    var signed = try client.anchor_idl_invoke.buildSignedVersionedTransactionFromJson(
        allocator,
        idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer signed.deinit(allocator);

    const signed_base64 = try signed.toBase64(allocator);
    defer allocator.free(signed_base64);

    const helper_base64 = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer allocator.free(helper_base64);

    try std.testing.expect(direct_signed.firstSignature() != null);
    try std.testing.expect(signed.firstSignature() != null);
    try std.testing.expectEqualSlices(u8, direct_base64, signed_base64);
    try std.testing.expectEqualSlices(u8, direct_base64, helper_base64);
}

const rpc_test_idl_json =
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

test "root.anchor_idl_invoke.sendLegacyTransactionFromJson sends signed legacy transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{11} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{12} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x33} ** 32);

    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigAnchorLegacy11111111111111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try client.anchor_idl_invoke.sendLegacyTransactionFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
        .{
            .transaction_options = .{
                .skip_preflight = true,
                .preflight_commitment = .confirmed,
            },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorLegacy11111111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.simulateVersionedTransactionFromJson simulates signed versioned transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{13} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{14} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x44} ** 32);

    const expected_encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}" },
    });
    defer rpc.deinit();

    const result = try client.anchor_idl_invoke.simulateVersionedTransactionFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
        .{
            .transaction_options = .{
                .sig_verify = true,
                .replace_recent_blockhash = true,
            },
        },
    );

    try std.testing.expectEqual(@as(u64, 120), result.fee.?);
    try std.testing.expectEqual(@as(u64, 42), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"replaceRecentBlockhash\":true") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromJson submits and confirms signed versioned transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{15} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{16} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x55} ** 32);

    const expected_encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigAnchorVersionedConfirm11111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 10, .status = .{
                .slot = 10,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 11, .status = .{
                .slot = 11,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
        .{
            .transaction_options = .{ .skip_preflight = true },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 2_000,
            .poll_interval_ms = 20,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorVersionedConfirm11111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}
