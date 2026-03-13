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

test "root.anchor_idl_invoke.buildOwnedInstruction resolves extended sysvar aliases" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{62} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[16,16,16,16,16,16,16,16],"accounts":[{{"name":"recentBlockhashes"}},{{"name":"slot_hashes"}},{{"name":"epochScheduleSysvar"}},{{"name":"epoch_rewards"}},{{"name":"stakeHistory"}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_recent_blockhashes = try client.Sysvar.recentBlockhashes(allocator);
    const expected_slot_hashes = try client.Pubkey.fromBase58(allocator, "SysvarS1otHashes111111111111111111111111111");
    const expected_epoch_schedule = try client.Pubkey.fromBase58(allocator, "SysvarEpochSchedu1e111111111111111111111111");
    const expected_epoch_rewards = try client.Pubkey.fromBase58(allocator, "SysvarEpochRewards1111111111111111111111111");
    const expected_stake_history = try client.Pubkey.fromBase58(allocator, "SysvarStakeHistory1111111111111111111111111");

    try std.testing.expectEqual(@as(usize, 5), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_recent_blockhashes));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_slot_hashes));
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(expected_epoch_schedule));
    try std.testing.expect(owned.instruction.accounts[3].pubkey.eql(expected_epoch_rewards));
    try std.testing.expect(owned.instruction.accounts[4].pubkey.eql(expected_stake_history));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves sysvar prefix and builtin id suffix aliases" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{63} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[17,17,17,17,17,17,17,17],"accounts":[{{"name":"sysvar_recent_blockhashes"}},{{"name":"sysvar_slot_hashes"}},{{"name":"sysvar_epoch_schedule_id"}},{{"name":"epochRewardsSysvarId"}},{{"name":"sysvar_stake_history_id"}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_recent_blockhashes = try client.Sysvar.recentBlockhashes(allocator);
    const expected_slot_hashes = try client.Pubkey.fromBase58(allocator, "SysvarS1otHashes111111111111111111111111111");
    const expected_epoch_schedule = try client.Pubkey.fromBase58(allocator, "SysvarEpochSchedu1e111111111111111111111111");
    const expected_epoch_rewards = try client.Pubkey.fromBase58(allocator, "SysvarEpochRewards1111111111111111111111111");
    const expected_stake_history = try client.Pubkey.fromBase58(allocator, "SysvarStakeHistory1111111111111111111111111");

    try std.testing.expectEqual(@as(usize, 5), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_recent_blockhashes));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_slot_hashes));
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(expected_epoch_schedule));
    try std.testing.expect(owned.instruction.accounts[3].pubkey.eql(expected_epoch_rewards));
    try std.testing.expect(owned.instruction.accounts[4].pubkey.eql(expected_stake_history));
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

test "root.anchor_idl_invoke.buildOwnedInstruction derives bytes arg seed pda from base64 string" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{64} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[18,18,18,18,18,18,18,18],"accounts":[{{"name":"vault","pda":{{"seeds":[{{"kind":"const","value":"vault"}},{{"kind":"arg","path":"digest"}}]}}}}],"args":[{{"name":"digest","type":"bytes"}}]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{
            .args_json = "{\"digest\":\"base64:AQID\"}",
        },
    );
    defer owned.deinit(allocator);

    const expected_vault = try findProgramAddress(allocator, &.{ "vault", &.{ 1, 2, 3 } }, program_id);
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

test "root.anchor_idl_invoke.buildOwnedInstruction resolves event cpi accounts automatically" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{54} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"emit","discriminator":[10,10,10,10,10,10,10,10],"accounts":[{{"name":"eventAuthority"}},{{"name":"program"}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "emit",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_event_authority = try findProgramAddress(allocator, &.{"__event_authority"}, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_event_authority));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves nested event cpi accounts automatically" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{55} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"emit","discriminator":[11,11,11,11,11,11,11,11],"accounts":[{{"name":"event","accounts":[{{"name":"eventAuthority"}},{{"name":"program"}}]}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "emit",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_event_authority = try findProgramAddress(allocator, &.{"__event_authority"}, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_event_authority));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves snake_case event cpi accounts automatically" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{56} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"emit","discriminator":[12,12,12,12,12,12,12,12],"accounts":[{{"name":"event_authority"}},{{"name":"program"}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "emit",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_event_authority = try findProgramAddress(allocator, &.{"__event_authority"}, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_event_authority));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
}

test "root.anchor_idl_invoke.buildOwnedInstruction reuses auto-resolved accounts in later pda resolution" {
    const allocator = std.testing.allocator;
    const payer = client.Pubkey.fromBytes(.{57} ** 32);
    const program_id = client.Pubkey.fromBytes(.{58} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[13,13,13,13,13,13,13,13],"accounts":[{{"name":"authority","signer":true}},{{"name":"vault","pda":{{"seeds":[{{"kind":"account","path":"authority"}}]}}}}],"args":[]}}]}}
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

    const expected_vault = try findProgramAddress(allocator, &.{payer.bytes[0..]}, program_id);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(payer));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_vault));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves forward relation through nested auto-resolved signer" {
    const allocator = std.testing.allocator;
    const payer = client.Pubkey.fromBytes(.{59} ** 32);
    const program_id = client.Pubkey.fromBytes(.{60} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[14,14,14,14,14,14,14,14],"accounts":[{{"name":"vault","pda":{{"seeds":[{{"kind":"account","path":"authority"}}]}}}},{{"name":"state","accounts":[{{"name":"authority","signer":true}}]}},{{"name":"authority","relations":["state"]}}],"args":[]}}]}}
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

    const expected_vault = try findProgramAddress(allocator, &.{payer.bytes[0..]}, program_id);

    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_vault));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(payer));
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(payer));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves forward nested event cpi accounts in pda program" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{61} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"emit","discriminator":[15,15,15,15,15,15,15,15],"accounts":[{{"name":"vault","pda":{{"program":{{"kind":"account","path":"event.program"}},"seeds":[{{"kind":"const","value":[118,97,117,108,116]}}]}}}},{{"name":"event","accounts":[{{"name":"eventAuthority"}},{{"name":"program"}}]}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "emit",
        .{},
    );
    defer owned.deinit(allocator);

    const expected_vault = try findProgramAddress(allocator, &.{"vault"}, program_id);
    const expected_event_authority = try findProgramAddress(allocator, &.{"__event_authority"}, program_id);

    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(expected_vault));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_event_authority));
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(program_id));
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

test "root.anchor_idl_invoke.sendLegacyTransactionWithLatestBlockhashFromJson fetches latest blockhash before sending" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{17} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{18} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

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

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashResponse(91, latest_blockhash_base58, 4567);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":\"SigAnchorLatestLegacy1111111111111111111111111111111111111111111111111111111\",\"id\":1}",
    );

    const signature = try client.anchor_idl_invoke.sendLegacyTransactionWithLatestBlockhashFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_commitment = .confirmed,
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
        "SigAnchorLatestLegacy1111111111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
}

test "root.anchor_idl_invoke.simulateVersionedTransactionWithLatestBlockhashFromJson fetches latest blockhash before simulating" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{19} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{20} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

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
    try rpc.pushMockLatestBlockhashResponse(92, latest_blockhash_base58, 4568);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}",
    );

    const result = try client.anchor_idl_invoke.simulateVersionedTransactionWithLatestBlockhashFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_commitment = .processed,
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
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"replaceRecentBlockhash\":true") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithLatestBlockhashFromJson fetches latest blockhash before confirming" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{21} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{22} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

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
    try rpc.pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        93,
        latest_blockhash_base58,
        4569,
        "SigAnchorLatestVersionedConfirm1111111111111111111111111111111111111111111111",
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

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithLatestBlockhashFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_commitment = .confirmed,
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
        "SigAnchorLatestVersionedConfirm1111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromJson submits and confirms signed legacy transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{23} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{24} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x66} ** 32);

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

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigAnchorLegacySpinner11111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 12, .status = .{
                .slot = 12,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 13, .status = .{
                .slot = 13,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromJson(
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
        "SigAnchorLegacySpinner11111111111111111111111111111111111111111111111111111",
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

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromJson submits and confirms signed versioned transaction" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{25} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{26} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = client.Hash.fromBytes([_]u8{0x77} ** 32);

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
        "SigAnchorVersionedSpinner111111111111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 14, .status = .{
                .slot = 14,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 15, .status = .{
                .slot = 15,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromJson(
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
        "SigAnchorVersionedSpinner111111111111111111111111111111111111111111111111111",
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

test "root.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinnerFromJson fetches latest blockhash before confirming" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{27} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{28} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

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

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        94,
        latest_blockhash_base58,
        4570,
        "SigAnchorLatestLegacySpinner111111111111111111111111111111111111111111111111",
        &.{
            .{
                .context_slot = 16,
                .status = .{
                    .slot = 16,
                    .confirmations = 1,
                    .confirmation_status = "finalized",
                    .has_error = false,
                },
            },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithLatestBlockhashAndSpinnerFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_commitment = .confirmed,
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
        "SigAnchorLatestLegacySpinner111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinnerFromJson fetches latest blockhash before confirming" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{29} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{30} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

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
    try rpc.pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        95,
        latest_blockhash_base58,
        4571,
        "SigAnchorLatestVersionedSpinner1111111111111111111111111111111111111111111111",
        &.{
            .{
                .context_slot = 17,
                .status = .{
                    .slot = 17,
                    .confirmations = 1,
                    .confirmation_status = "finalized",
                    .has_error = false,
                },
            },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithLatestBlockhashAndSpinnerFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_commitment = .processed,
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
        "SigAnchorLatestVersionedSpinner1111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.sendLegacyTransactionWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{31} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{32} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x88} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
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
    try rpc.pushMockSignatureResult("SigAnchorBlockhashLegacy1111111111111111111111111111111111111111111111111");

    const signature = try client.anchor_idl_invoke.sendLegacyTransactionWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
        .{
            .transaction_options = .{ .skip_preflight = true, .max_retries = 2 },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorBlockhashLegacy1111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"maxRetries\":2") != null);
}

test "root.anchor_idl_invoke.simulateVersionedTransactionWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{33} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{34} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x99} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
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
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":10},\"value\":{\"accounts\":[],\"err\":null,\"fee\":120,\"unitsConsumed\":42}},\"id\":1}",
    );

    const result = try client.anchor_idl_invoke.simulateVersionedTransactionWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
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

test "root.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{35} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{36} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{37} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{38} ** 32);
    const recent_blockhash = [_]u8{0xA1} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":140},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);
    try rpc.pushMockSignatureResult("SigAnchorNonceLegacy11111111111111111111111111111111111111111111111111");
    try rpc.pushMockSingleSignatureStatusResult(141, .{
        .slot = 141,
        .confirmations = 1,
        .confirmation_status = "confirmed",
        .has_error = false,
    });

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const signature = try client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .signers = &.{ payer, nonce_authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
        .{
            .transaction_options = .{ .skip_preflight = true, .max_retries = 3 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 0,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorNonceLegacy11111111111111111111111111111111111111111111111111",
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
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{39} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{40} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0xB2} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
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
        "SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 150, .status = null },
            .{ .context_slot = 151, .status = .{
                .slot = 151,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 152, .status = .{
                .slot = 152,
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

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithBlockhashQueryAndSpinnerFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
        .{
            .transaction_options = .{ .skip_preflight = true, .max_retries = 1 },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 200,
            .poll_interval_ms = 0,
        },
    );
    defer allocator.free(signature);

    try std.posix.dup2(saved_stderr, std.posix.STDERR_FILENO);
    const captured = try (std.fs.File{ .handle = pipe_fds[0] }).readToEndAlloc(allocator, 2048);
    defer allocator.free(captured);

    try std.testing.expectEqualStrings(
        "SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111",
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
        \\submitted transaction: SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111
        \\waiting for transaction to be observed: SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111
        \\waiting for confirmed confirmation: SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111
        \\transaction confirmed: SigAnchorBlockhashVersionedSpinner1111111111111111111111111111111111111111111
        \\
    , captured);
}

test "root.anchor_idl_invoke.buildSignedLegacyTransactionWithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{41} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{42} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{43} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{44} ** 32);
    const recent_blockhash = [_]u8{0xC3} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":160},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    var expected_signed = try client.buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
        &.{ payer, nonce_authority },
    );
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var signed = try client.anchor_idl_invoke.buildSignedLegacyTransactionWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .signers = &.{ payer, nonce_authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer signed.deinit(allocator);
    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.anchor_idl_invoke.buildLegacyTransactionBase64WithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{45} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{46} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0xD4} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
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

    const encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64WithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.anchor_idl_invoke.buildSignedVersionedTransactionWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const signer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{47} ** 32);
    const signer = try client.Keypair.fromSecretKeyBytes(signer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{48} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0xE5} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var expected_signed = try client.anchor_idl_invoke.buildSignedVersionedTransactionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
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
    defer expected_signed.deinit(allocator);
    const expected_encoded = try expected_signed.toBase64(allocator);
    defer allocator.free(expected_encoded);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    var signed = try client.anchor_idl_invoke.buildSignedVersionedTransactionWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = signer.public_key,
            .signers = &.{signer},
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = signer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
    );
    defer signed.deinit(allocator);
    const encoded = try signed.toBase64(allocator);
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.anchor_idl_invoke.buildVersionedTransactionBase64WithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{49} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{50} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{51} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{52} ** 32);
    const recent_blockhash = [_]u8{0xF6} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":170},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    const expected_encoded = try client.buildVersionedTransactionBase64WithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
        &.{},
        &.{ payer, nonce_authority },
    );
    defer allocator.free(expected_encoded);

    const encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64WithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .signers = &.{ payer, nonce_authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.anchor_idl_invoke.buildOwnedLegacyMessageWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{53} ** 32);
    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{54} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x17} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var expected = try client.anchor_idl_invoke.buildOwnedLegacyMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer expected.deinit(allocator);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    var owned = try client.anchor_idl_invoke.buildOwnedLegacyMessageWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
    );
    defer owned.deinit(allocator);

    const encoded = try owned.serialize(allocator);
    defer allocator.free(encoded);
    const expected_encoded = try expected.serialize(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.anchor_idl_invoke.buildLegacyMessageBase64WithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{55} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{56} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{57} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{58} ** 32);
    const recent_blockhash = [_]u8{0x18} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":180},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    const expected_encoded = try client.buildLegacyMessageBase64WithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
    );
    defer allocator.free(expected_encoded);

    const encoded = try client.anchor_idl_invoke.buildLegacyMessageBase64WithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.anchor_idl_invoke.buildOwnedVersionedMessageWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{59} ** 32);
    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{60} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x19} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var expected = try client.anchor_idl_invoke.buildOwnedVersionedMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer expected.deinit(allocator);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    var owned = try client.anchor_idl_invoke.buildOwnedVersionedMessageWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
    );
    defer owned.deinit(allocator);

    const encoded = try owned.serialize(allocator);
    defer allocator.free(encoded);
    const expected_encoded = try expected.serialize(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.anchor_idl_invoke.buildVersionedMessageBase64WithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{61} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{62} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{63} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{64} ** 32);
    const recent_blockhash = [_]u8{0x1A} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":181},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    var expected_owned = try client.buildOwnedVersionedMessageWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
        &.{},
    );
    defer expected_owned.deinit(allocator);
    const expected_encoded = try expected_owned.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const encoded = try client.anchor_idl_invoke.buildVersionedMessageBase64WithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings(expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.anchor_idl_invoke.buildLegacyMessageBytesWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{65} ** 32);
    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{66} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x1B} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var expected = try client.anchor_idl_invoke.buildOwnedLegacyMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer expected.deinit(allocator);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();

    const encoded = try client.anchor_idl_invoke.buildLegacyMessageBytesWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
    );
    defer allocator.free(encoded);

    const expected_encoded = try expected.serialize(allocator);
    defer allocator.free(expected_encoded);

    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 0), rpc.mockRequestCount());
}

test "root.anchor_idl_invoke.buildVersionedMessageBytesWithBlockhashQueryFromJson supports nonce account queries" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{67} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{68} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{69} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{70} ** 32);
    const recent_blockhash = [_]u8{0x1C} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);

    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":182},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);

    var owned_instruction = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .args_json = "{\"value\":42}",
            .account_bindings = &.{
                .{ .path = "authority", .pubkey = payer.public_key },
                .{ .path = "target", .pubkey = target },
            },
        },
    );
    defer owned_instruction.deinit(allocator);

    const expected_instructions = [_]client.Instruction{owned_instruction.instruction};
    var expected_owned = try client.buildOwnedVersionedMessageWithNonceInstructions(
        allocator,
        payer.public_key,
        nonce_account,
        nonce_authority.public_key,
        client.Hash.fromBytes(recent_blockhash),
        expected_instructions[0..],
        &.{},
    );
    defer expected_owned.deinit(allocator);
    const expected_encoded = try expected_owned.serialize(allocator);
    defer allocator.free(expected_encoded);

    const encoded = try client.anchor_idl_invoke.buildVersionedMessageBytesWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"encoding\":\"jsonParsed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"finalized\"") != null);
}

test "root.anchor_idl_invoke.getFeeForLegacyMessageWithBlockhashQueryFromJson resolves cluster blockhash and encodes message" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{71} ** 32);
    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{72} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x1D} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashResponse(190, recent_blockhash_base58, 6789);
    try rpc.pushMockResultJson("{\"context\":{\"slot\":191},\"value\":5000}");

    var expected_message = try client.anchor_idl_invoke.buildOwnedLegacyMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer expected_message.deinit(allocator);
    const expected_base64 = try expected_message.toBase64(allocator);
    defer allocator.free(expected_base64);

    const fee = try client.anchor_idl_invoke.getFeeForLegacyMessageWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .cluster = .{ .commitment = .confirmed } },
        },
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqual(@as(?u64, 5000), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_base64) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.getFeeForVersionedMessageWithBlockhashQueryFromJson supports fixed blockhashes" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{73} ** 32);
    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{74} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const recent_blockhash = [_]u8{0x1E} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    var expected_message = try client.anchor_idl_invoke.buildOwnedVersionedMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = client.Hash.fromBytes(recent_blockhash),
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
        },
    );
    defer expected_message.deinit(allocator);
    const expected_base64 = try expected_message.toBase64(allocator);
    defer allocator.free(expected_base64);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson("{\"context\":{\"slot\":192},\"value\":6000}");

    const fee = try client.anchor_idl_invoke.getFeeForVersionedMessageWithBlockhashQueryFromJson(
        &rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings = &.{
                    .{ .path = "authority", .pubkey = payer.public_key },
                    .{ .path = "target", .pubkey = target },
                },
            },
            .blockhash_query = .{ .fixed = recent_blockhash_base58 },
        },
        .{ .commitment = .processed },
    );

    try std.testing.expectEqual(@as(?u64, 6000), fee.value);
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_base64) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"processed\"") != null);
}

test "root.anchor_idl_invoke.buildOwnedInstruction accepts account_bindings_json alias objects and explicit null optional accounts" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{75} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = client.Pubkey.fromBytes(.{76} ** 32);
    const payer_base58 = try payer.toBase58(allocator);
    defer allocator.free(payer_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"configure","discriminator":[8,7,6,5,4,3,2,1],"accounts":[{{"name":"payer","signer":true,"writable":true}},{{"name":"delegate","optional":true,"signer":true,"writable":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"payer\":{{\"publicKey\":\"{s}\"}},\"delegate\":null}}",
        .{payer_base58},
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "configure",
        .{
            .account_bindings_json = account_bindings_json,
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

test "root.anchor_idl_invoke.buildOwnedInstruction accepts nested account_bindings_json groups" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{77} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const authority = client.Pubkey.fromBytes(.{78} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const target = client.Pubkey.fromBytes(.{79} ** 32);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"configureNested","discriminator":[1,1,1,1,1,1,1,1],"accounts":[{{"name":"authority","signer":true}},{{"name":"group","accounts":[{{"name":"target","writable":true}},{{"name":"systemProgram"}}]}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":\"{s}\",\"group\":{{\"target\":{{\"address\":\"{s}\"}}}}}}",
        .{ authority_base58, target_base58 },
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "configureNested",
        .{
            .account_bindings_json = account_bindings_json,
        },
    );
    defer owned.deinit(allocator);

    const system_program = try client.Pubkey.fromBase58(allocator, "11111111111111111111111111111111");

    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(authority));
    try std.testing.expect(owned.instruction.accounts[0].is_signer);
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(target));
    try std.testing.expect(owned.instruction.accounts[1].is_writable);
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(system_program));
}

test "root.anchor_idl_invoke.buildOwnedInstruction resolves related account from nested binding object with parent pubkey" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{65} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const state = client.Pubkey.fromBytes(.{66} ** 32);
    const authority = client.Pubkey.fromBytes(.{67} ** 32);
    const state_base58 = try state.toBase58(allocator);
    defer allocator.free(state_base58);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"update","discriminator":[19,19,19,19,19,19,19,19],"accounts":[{{"name":"state","writable":true}},{{"name":"authority","signer":true,"relations":["state"]}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"state\":{{\"publicKey\":\"{s}\",\"authority\":\"{s}\"}}}}",
        .{ state_base58, authority_base58 },
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "update",
        .{
            .account_bindings_json = account_bindings_json,
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(state));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(authority));
}

test "root.anchor_idl_invoke.buildOwnedInstruction derives pda seed from nested binding object with parent pubkey" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{68} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const state = client.Pubkey.fromBytes(.{69} ** 32);
    const authority = client.Pubkey.fromBytes(.{70} ** 32);
    const state_base58 = try state.toBase58(allocator);
    defer allocator.free(state_base58);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"initialize","discriminator":[20,20,20,20,20,20,20,20],"accounts":[{{"name":"state","writable":true}},{{"name":"vault","pda":{{"seeds":[{{"kind":"account","path":"state.authority","type":"publicKey"}}]}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"state\":{{\"address\":\"{s}\",\"authority\":\"{s}\"}}}}",
        .{ state_base58, authority_base58 },
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "initialize",
        .{
            .account_bindings_json = account_bindings_json,
        },
    );
    defer owned.deinit(allocator);

    const expected_vault = try findProgramAddress(allocator, &.{authority.bytes[0..]}, program_id);
    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(state));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_vault));
}

test "root.anchor_idl_invoke.buildOwnedInstruction derives pda with pda program account field from nested binding object" {
    const allocator = std.testing.allocator;
    const authority = client.Pubkey.fromBytes(.{71} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const pda_program = client.Pubkey.fromBytes(.{72} ** 32);
    const pda_program_base58 = try pda_program.toBase58(allocator);
    defer allocator.free(pda_program_base58);
    const program_id = client.Pubkey.fromBytes(.{73} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"init","discriminator":[21,21,21,21,21,21,21,21],"accounts":[{{"name":"authority"}},{{"name":"vault","writable":true,"pda":{{"seeds":[{{"kind":"const","value":[118,97,117,108,116]}}],"program":{{"kind":"account","path":"authority.programId","type":"publicKey"}}}}}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"authority\":{{\"address\":\"{s}\",\"programId\":\"{s}\"}}}}",
        .{ authority_base58, pda_program_base58 },
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "init",
        .{
            .account_bindings_json = account_bindings_json,
        },
    );
    defer owned.deinit(allocator);

    const expected_pda = try findProgramAddress(allocator, &.{"vault"}, pda_program);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(authority));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(expected_pda));
}

test "root.anchor_idl_invoke.buildOwnedInstruction treats publicKey object null optional account as missing" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{74} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = client.Pubkey.fromBytes(.{75} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"configure","discriminator":[22,22,22,22,22,22,22,22],"accounts":[{{"name":"payer","signer":true,"writable":true}},{{"name":"delegate","optional":true,"signer":true,"writable":true}}],"args":[]}}]}}
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
            .account_bindings_json = "{\"delegate\":{\"publicKey\":null}}",
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(payer));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
}

test "root.anchor_idl_invoke.buildOwnedInstruction treats address object null optional account as missing" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{76} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const payer = client.Pubkey.fromBytes(.{77} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"configure","discriminator":[23,23,23,23,23,23,23,23],"accounts":[{{"name":"payer","signer":true,"writable":true}},{{"name":"delegate","optional":true,"signer":true,"writable":true}}],"args":[]}}]}}
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
            .account_bindings_json = "{\"delegate\":{\"address\":null}}",
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(payer));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(program_id));
}

test "root.anchor_idl_invoke.buildOwnedInstruction prefers explicit account_bindings over account_bindings_json" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{80} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const wrong_state = client.Pubkey.fromBytes(.{81} ** 32);
    const wrong_state_base58 = try wrong_state.toBase58(allocator);
    defer allocator.free(wrong_state_base58);
    const correct_state = client.Pubkey.fromBytes(.{82} ** 32);
    const signer = client.Pubkey.fromBytes(.{83} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"setFlag","discriminator":[1,2,3,4,5,6,7,8],"accounts":[{{"name":"state","writable":true}},{{"name":"authority","signer":true}}],"args":[{{"name":"enabled","type":"bool"}}]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"state\":\"{s}\"}}",
        .{wrong_state_base58},
    );
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "setFlag",
        .{
            .args_json = "{\"enabled\":true}",
            .account_bindings = &.{
                .{ .path = "state", .pubkey = correct_state },
            },
            .account_bindings_json = account_bindings_json,
            .default_signer = signer,
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(correct_state));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(signer));
}

test "root.anchor_idl_invoke.buildOwnedInstruction accepts remaining_accounts_json entries" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{84} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const authority = client.Pubkey.fromBytes(.{85} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const extra_readonly = client.Pubkey.fromBytes(.{86} ** 32);
    const extra_readonly_base58 = try extra_readonly.toBase58(allocator);
    defer allocator.free(extra_readonly_base58);
    const extra_writable = client.Pubkey.fromBytes(.{87} ** 32);
    const extra_writable_base58 = try extra_writable.toBase58(allocator);
    defer allocator.free(extra_writable_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"setAuthority","discriminator":[5,4,3,2,1,0,9,8],"accounts":[{{"name":"authority","signer":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const remaining_accounts_json = try std.fmt.allocPrint(
        allocator,
        "[\"{s}\",{{\"pubkey\":\"{s}\",\"isWritable\":true,\"isSigner\":true}}]",
        .{ extra_readonly_base58, extra_writable_base58 },
    );
    defer allocator.free(remaining_accounts_json);
    const account_bindings_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{authority_base58});
    defer allocator.free(account_bindings_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "setAuthority",
        .{
            .account_bindings_json = account_bindings_json,
            .remaining_accounts_json = remaining_accounts_json,
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[0].pubkey.eql(authority));
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(extra_readonly));
    try std.testing.expect(!owned.instruction.accounts[1].is_signer);
    try std.testing.expect(!owned.instruction.accounts[1].is_writable);
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(extra_writable));
    try std.testing.expect(owned.instruction.accounts[2].is_signer);
    try std.testing.expect(owned.instruction.accounts[2].is_writable);
}

test "root.anchor_idl_invoke.buildOwnedInstruction concatenates remaining_accounts_json before typed remaining_accounts" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{88} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const authority = client.Pubkey.fromBytes(.{89} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);
    const json_extra = client.Pubkey.fromBytes(.{90} ** 32);
    const json_extra_base58 = try json_extra.toBase58(allocator);
    defer allocator.free(json_extra_base58);
    const typed_extra = client.Pubkey.fromBytes(.{91} ** 32);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"setAuthority","discriminator":[5,4,3,2,1,0,9,8],"accounts":[{{"name":"authority","signer":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{authority_base58});
    defer allocator.free(account_bindings_json);
    const remaining_accounts_json = try std.fmt.allocPrint(allocator, "[\"{s}\"]", .{json_extra_base58});
    defer allocator.free(remaining_accounts_json);

    var owned = try client.anchor_idl_invoke.buildOwnedInstructionFromJson(
        allocator,
        idl_json,
        "setAuthority",
        .{
            .account_bindings_json = account_bindings_json,
            .remaining_accounts_json = remaining_accounts_json,
            .remaining_accounts = &.{
                .{ .pubkey = typed_extra, .is_signer = true, .is_writable = false },
            },
        },
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), owned.instruction.accounts.len);
    try std.testing.expect(owned.instruction.accounts[1].pubkey.eql(json_extra));
    try std.testing.expect(owned.instruction.accounts[2].pubkey.eql(typed_extra));
    try std.testing.expect(owned.instruction.accounts[2].is_signer);
}

test "root.anchor_idl_invoke.buildOwnedInstruction rejects invalid remaining_accounts_json fields" {
    const allocator = std.testing.allocator;
    const program_id = client.Pubkey.fromBytes(.{92} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const authority = client.Pubkey.fromBytes(.{93} ** 32);
    const authority_base58 = try authority.toBase58(allocator);
    defer allocator.free(authority_base58);

    const idl_json = try std.fmt.allocPrint(
        allocator,
        \\{{"address":"{s}","instructions":[{{"name":"setAuthority","discriminator":[5,4,3,2,1,0,9,8],"accounts":[{{"name":"authority","signer":true}}],"args":[]}}]}}
    ,
        .{program_id_base58},
    );
    defer allocator.free(idl_json);

    const account_bindings_json = try std.fmt.allocPrint(allocator, "{{\"authority\":\"{s}\"}}", .{authority_base58});
    defer allocator.free(account_bindings_json);

    try std.testing.expectError(
        client.anchor_idl_invoke.BuildError.InvalidAnchorIdlAccountSpec,
        client.anchor_idl_invoke.buildOwnedInstructionFromJson(
            allocator,
            idl_json,
            "setAuthority",
            .{
                .account_bindings_json = account_bindings_json,
                .remaining_accounts_json = "[{\"pubkey\":123}]",
            },
        ),
    );
}

test "root.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson uses explicit default signer for account resolution and signing" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{90} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{91} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{92} ** 32);
    const recent_blockhash = [_]u8{0xC1} ** 32;
    const recent_blockhash_hash = client.Hash.fromBytes(recent_blockhash);
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
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);

    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = recent_blockhash_hash,
            .signers = &.{ payer, authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = authority.public_key,
            },
        },
    );
    defer allocator.free(expected_encoded);

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
            rpc_test_idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{
        .{ .json = "{\"jsonrpc\":\"2.0\",\"result\":\"SigAnchorInvocationLegacy1111111111111111111111111111111111111111111111111\",\"id\":1}" },
    });
    defer rpc.deinit();

    const signature = try client.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson(
        &rpc,
        allocator,
        .{
            .anchor_idl_invocation_spec_json = spec_json,
            .send_transaction_options = .{
                .skip_preflight = true,
                .preflight_commitment = .confirmed,
            },
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorInvocationLegacy1111111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 1), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"preflightCommitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson resolves nonce account specs" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{93} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{94} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{95} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{96} ** 32);
    const recent_blockhash = [_]u8{0xC2} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key_base58 = try client.encodeBase58(allocator, &nonce_authority.secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);
    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":210},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var expected_rpc = try client.RpcClient.newMock(allocator, &.{});
    defer expected_rpc.deinit();
    try expected_rpc.pushMockResultJson(nonce_account_result_json);
    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64WithBlockhashQueryFromJson(
        &expected_rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .signers = &.{ payer, nonce_authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = payer.public_key,
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(expected_encoded);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            rpc_test_idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":11},\"value\":{\"accounts\":[],\"err\":null,\"fee\":99,\"unitsConsumed\":15}},\"id\":1}",
    );

    const result = try client.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson(
        &rpc,
        allocator,
        .{
            .anchor_idl_invocation_spec_json = spec_json,
            .simulate_options = .{
                .sig_verify = true,
                .replace_recent_blockhash = true,
            },
        },
    );

    try std.testing.expectEqual(@as(u64, 99), result.fee.?);
    try std.testing.expectEqual(@as(u64, 15), result.units_consumed.?);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("simulateTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"sigVerify\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"replaceRecentBlockhash\":true") != null);
}

test "root.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson uses latest blockhash and lookup tables" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{97} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{98} ** 32);
    const lookup_table_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{99} ** 32);
    const lookup_address_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{100} ** 32);
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const lookup_table = client.Pubkey.fromBytes(lookup_table_raw.public_key.toBytes());
    const lookup_address = client.Pubkey.fromBytes(lookup_address_raw.public_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);

    const expected_encoded = try client.anchor_idl_invoke.buildVersionedTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = recent_blockhash,
            .signers = &.{payer},
            .address_lookup_tables = &.{
                .{
                    .account_key = lookup_table,
                    .addresses = &.{lookup_address},
                },
            },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = payer.public_key,
            },
        },
    );
    defer allocator.free(expected_encoded);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}},
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            rpc_test_idl_json,
            target_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
    defer allocator.free(spec_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockLatestBlockhashSendAndSignatureStatusPollFlow(
        230,
        latest_blockhash_base58,
        9999,
        "SigAnchorInvocationVersioned1111111111111111111111111111111111111111111111",
        &.{
            .{
                .context_slot = 12,
                .status = .{
                    .slot = 12,
                    .confirmations = 1,
                    .confirmation_status = "confirmed",
                    .has_error = false,
                },
            },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(
        &rpc,
        allocator,
        .{
            .anchor_idl_invocation_spec_json = spec_json,
            .blockhash_commitment = .confirmed,
            .send_transaction_options = .{ .skip_preflight = true },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 2_000,
            .poll_interval_ms = 20,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorInvocationVersioned1111111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 3), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
}

test "root.anchor_idl_invoke.buildLegacyTransactionBase64FromInvocationSpecJson builds recent blockhash payloads without rpc" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{101} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{102} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{103} ** 32);
    const recent_blockhash = [_]u8{0xC3} ** 32;
    const recent_blockhash_hash = client.Hash.fromBytes(recent_blockhash);
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
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);

    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = recent_blockhash_hash,
            .signers = &.{ payer, authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = authority.public_key,
            },
        },
    );
    defer allocator.free(expected_encoded);

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
            rpc_test_idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var dummy = try client.RpcClient.newMock(allocator, &.{});
    defer dummy.deinit();
    const actual_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(
        &dummy,
        allocator,
        .{ .anchor_idl_invocation_spec_json = spec_json },
    );
    defer allocator.free(actual_encoded);

    try std.testing.expectEqualStrings(expected_encoded, actual_encoded);
    try std.testing.expectEqual(@as(usize, 0), dummy.mockRequestCount());
}

test "root.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson resolves nonce account specs" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{104} ** 32);
    const nonce_authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{105} ** 32);
    const nonce_account_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{106} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{107} ** 32);
    const recent_blockhash = [_]u8{0xC4} ** 32;
    const recent_blockhash_base58 = try client.encodeBase58(allocator, &recent_blockhash);
    defer allocator.free(recent_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const nonce_authority = try client.Keypair.fromSecretKeyBytes(nonce_authority_raw.secret_key.toBytes());
    const nonce_account = client.Pubkey.fromBytes(nonce_account_raw.public_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key_base58 = try client.encodeBase58(allocator, &nonce_authority.secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);
    const nonce_authority_base58 = try nonce_authority.public_key.toBase58(allocator);
    defer allocator.free(nonce_authority_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);
    const nonce_account_result_json = try std.mem.concat(allocator, u8, &.{
        "{\"context\":{\"slot\":240},\"value\":{\"data\":{\"program\":\"system\",\"parsed\":{\"type\":\"initialized\",\"info\":{\"authority\":\"",
        nonce_authority_base58,
        "\",\"blockhash\":\"",
        recent_blockhash_base58,
        "\",\"feeCalculator\":{\"lamportsPerSignature\":5000}}},\"space\":80},\"executable\":false,\"lamports\":123456,\"owner\":\"11111111111111111111111111111111\",\"rentEpoch\":0,\"space\":80}}",
    });
    defer allocator.free(nonce_account_result_json);

    var expected_rpc = try client.RpcClient.newMock(allocator, &.{});
    defer expected_rpc.deinit();
    try expected_rpc.pushMockResultJson(nonce_account_result_json);
    const expected_encoded = try client.anchor_idl_invoke.buildLegacyTransactionBase64WithBlockhashQueryFromJson(
        &expected_rpc,
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .signers = &.{ payer, nonce_authority },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = payer.public_key,
            },
            .blockhash_query = .{ .nonce_account = .{
                .pubkey = nonce_account_base58,
                .commitment = .finalized,
            } },
            .nonce_authority = nonce_authority.public_key,
        },
    );
    defer allocator.free(expected_encoded);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            rpc_test_idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockResultJson(nonce_account_result_json);
    try rpc.pushMockSendAndSignatureStatusPollFlow(
        "SigAnchorInvocationLegacySpinner11111111111111111111111111111111111111111111",
        &.{
            .{ .context_slot = 14, .status = .{
                .slot = 14,
                .confirmations = 1,
                .confirmation_status = "processed",
                .has_error = false,
            } },
            .{ .context_slot = 15, .status = .{
                .slot = 15,
                .confirmations = 2,
                .confirmation_status = "confirmed",
                .has_error = false,
            } },
        },
    );

    const signature = try client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(
        &rpc,
        allocator,
        .{
            .anchor_idl_invocation_spec_json = spec_json,
            .blockhash_commitment = .finalized,
            .send_transaction_options = .{ .skip_preflight = true },
            .commitment = .confirmed,
            .search_transaction_history = true,
            .timeout_ms = 2_000,
            .poll_interval_ms = 20,
        },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings(
        "SigAnchorInvocationLegacySpinner11111111111111111111111111111111111111111111",
        signature,
    );
    try std.testing.expectEqual(@as(usize, 4), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getAccountInfo", rpc.capturedMockRequests()[0].method);
    try std.testing.expectEqualStrings("sendTransaction", rpc.capturedMockRequests()[1].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[2].method);
    try std.testing.expectEqualStrings("getSignatureStatuses", rpc.capturedMockRequests()[3].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, nonce_account_base58) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"skipPreflight\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[2].params_json, "\"searchTransactionHistory\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[3].params_json, "\"commitment\":\"confirmed\"") != null);
}

test "root.anchor_idl_invoke.getFeeForVersionedMessageFromInvocationSpecJson uses latest blockhash and lookup tables" {
    const allocator = std.testing.allocator;
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{108} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{109} ** 32);
    const lookup_table_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{110} ** 32);
    const lookup_address_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{111} ** 32);
    const latest_blockhash_base58 = "11111111111111111111111111111111";
    const recent_blockhash = try client.Hash.fromBase58(allocator, latest_blockhash_base58);

    const payer = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const lookup_table = client.Pubkey.fromBytes(lookup_table_raw.public_key.toBytes());
    const lookup_address = client.Pubkey.fromBytes(lookup_address_raw.public_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);
    const lookup_table_base58 = try lookup_table.toBase58(allocator);
    defer allocator.free(lookup_table_base58);
    const lookup_address_base58 = try lookup_address.toBase58(allocator);
    defer allocator.free(lookup_address_base58);
    const account_bindings_json = try std.fmt.allocPrint(
        allocator,
        "{{\"target\":\"{s}\"}}",
        .{target_base58},
    );
    defer allocator.free(account_bindings_json);

    var expected_message = try client.anchor_idl_invoke.buildOwnedVersionedMessageFromJson(
        allocator,
        rpc_test_idl_json,
        "setValue",
        .{
            .payer = payer.public_key,
            .recent_blockhash = recent_blockhash,
            .address_lookup_tables = &.{
                .{
                    .account_key = lookup_table,
                    .addresses = &.{lookup_address},
                },
            },
            .instruction_options = .{
                .args_json = "{\"value\":42}",
                .account_bindings_json = account_bindings_json,
                .default_signer = payer.public_key,
            },
        },
    );
    defer expected_message.deinit(allocator);
    const expected_encoded = try expected_message.toBase64(allocator);
    defer allocator.free(expected_encoded);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}},
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            rpc_test_idl_json,
            target_base58,
            lookup_table_base58,
            lookup_address_base58,
        },
    );
    defer allocator.free(spec_json);

    var rpc = try client.RpcClient.newMock(allocator, &.{});
    defer rpc.deinit();
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":250},\"value\":{\"blockhash\":\"11111111111111111111111111111111\",\"lastValidBlockHeight\":9999}},\"id\":1}",
    );
    try rpc.pushMockJsonResponse(
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":251},\"value\":7777},\"id\":1}",
    );

    const fee = try client.anchor_idl_invoke.getFeeForVersionedMessageFromInvocationSpecJson(
        &rpc,
        allocator,
        .{
            .anchor_idl_invocation_spec_json = spec_json,
            .blockhash_commitment = .confirmed,
        },
        .{ .commitment = .processed },
    );

    try std.testing.expectEqual(@as(?u64, 7777), fee.value);
    try std.testing.expectEqual(@as(usize, 2), rpc.mockRequestCount());
    try std.testing.expectEqualStrings("getLatestBlockhash", rpc.capturedMockRequests()[0].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[0].params_json, "\"commitment\":\"confirmed\"") != null);
    try std.testing.expectEqualStrings("getFeeForMessage", rpc.capturedMockRequests()[1].method);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].request_body, expected_encoded) != null);
    try std.testing.expect(std.mem.indexOf(u8, rpc.capturedMockRequests()[1].params_json, "\"commitment\":\"processed\"") != null);
}
