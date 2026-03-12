const std = @import("std");
const client = @import("solana_client_zig");

pub const std_options = struct {
    pub const log_level = std.log.Level.err;
};

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
