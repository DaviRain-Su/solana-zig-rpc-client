const std = @import("std");
const sdk = @import("./sdk.zig");

const Allocator = std.mem.Allocator;

pub const InstructionDataEncoding = enum {
    base64,
    hex,
    utf8,
};

pub const BuildError = Allocator.Error || error{
    InvalidProgramInvokeSpec,
    InvalidHexData,
};

pub const BuildInstructionOptions = struct {
    accounts: []const sdk.AccountMeta = &.{},
    accounts_json: ?[]const u8 = null,
    data: ?[]const u8 = null,
    data_bytes: ?[]const u8 = null,
    data_encoding: InstructionDataEncoding = .base64,
};

pub const OwnedInstruction = struct {
    instruction: sdk.Instruction,

    pub fn deinit(self: *OwnedInstruction, allocator: Allocator) void {
        allocator.free(self.instruction.accounts);
        allocator.free(self.instruction.data);
        self.* = undefined;
    }
};

const JsonAccountMeta = struct {
    pubkey: []const u8,
    is_signer: bool = false,
    is_writable: bool = false,
};

const OwnedAccounts = struct {
    metas: []sdk.AccountMeta,

    fn deinit(self: *OwnedAccounts, allocator: Allocator) void {
        allocator.free(self.metas);
        self.* = undefined;
    }
};

fn parseAccountsJson(allocator: Allocator, json_source: []const u8) BuildError!OwnedAccounts {
    const parsed = std.json.parseFromSlice([]JsonAccountMeta, allocator, json_source, .{
        .ignore_unknown_fields = true,
    }) catch return error.InvalidProgramInvokeSpec;
    defer parsed.deinit();

    const metas = try allocator.alloc(sdk.AccountMeta, parsed.value.len);
    errdefer allocator.free(metas);

    for (parsed.value, 0..) |account, index| {
        metas[index] = sdk.AccountMeta.init(
            sdk.Pubkey.fromBase58(allocator, account.pubkey) catch return error.InvalidProgramInvokeSpec,
            account.is_signer,
            account.is_writable,
        );
    }

    return .{ .metas = metas };
}

fn decodeInstructionData(
    allocator: Allocator,
    encoded: ?[]const u8,
    encoding: InstructionDataEncoding,
) BuildError![]u8 {
    const value = encoded orelse return try allocator.alloc(u8, 0);

    return switch (encoding) {
        .utf8 => try allocator.dupe(u8, value),
        .base64 => blk: {
            const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(value) catch return error.InvalidProgramInvokeSpec;
            const decoded = try allocator.alloc(u8, decoded_len);
            errdefer allocator.free(decoded);
            std.base64.standard.Decoder.decode(decoded, value) catch return error.InvalidProgramInvokeSpec;
            break :blk decoded;
        },
        .hex => blk: {
            const hex_value = if (std.mem.startsWith(u8, value, "0x") or std.mem.startsWith(u8, value, "0X"))
                value[2..]
            else
                value;
            if (hex_value.len % 2 != 0) return error.InvalidHexData;
            const decoded = try allocator.alloc(u8, hex_value.len / 2);
            errdefer allocator.free(decoded);
            _ = std.fmt.hexToBytes(decoded, hex_value) catch return error.InvalidHexData;
            break :blk decoded;
        },
    };
}

pub fn buildOwnedInstruction(
    allocator: Allocator,
    program_id: sdk.Pubkey,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    if (options.data != null and options.data_bytes != null) return error.InvalidProgramInvokeSpec;

    var json_accounts = if (options.accounts_json) |value|
        try parseAccountsJson(allocator, value)
    else
        null;
    defer if (json_accounts) |*value| value.deinit(allocator);

    var merged_accounts: ?[]sdk.AccountMeta = null;
    defer if (merged_accounts) |value| allocator.free(value);
    const resolved_accounts = if (json_accounts) |value| blk: {
        if (options.accounts.len == 0) break :blk value.metas;
        if (value.metas.len == 0) break :blk options.accounts;

        const merged = try allocator.alloc(sdk.AccountMeta, options.accounts.len + value.metas.len);
        merged_accounts = merged;
        @memcpy(merged[0..options.accounts.len], options.accounts);
        @memcpy(merged[options.accounts.len..], value.metas);
        break :blk merged;
    } else options.accounts;

    const accounts = try allocator.dupe(sdk.AccountMeta, resolved_accounts);
    errdefer allocator.free(accounts);

    const data = if (options.data_bytes) |value|
        try allocator.dupe(u8, value)
    else
        try decodeInstructionData(allocator, options.data, options.data_encoding);
    errdefer allocator.free(data);

    return .{
        .instruction = .{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
        },
    };
}

pub fn buildOwnedInstructionFromJson(
    allocator: Allocator,
    program_id: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    const program_pubkey = sdk.Pubkey.fromBase58(allocator, program_id) catch return error.InvalidProgramInvokeSpec;
    return try buildOwnedInstruction(allocator, program_pubkey, options);
}

test "program_invoke.buildOwnedInstructionFromJson builds utf8 instruction from accounts json" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{81} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const signer = sdk.Pubkey.fromBytes(.{82} ** 32);
    const signer_base58 = try signer.toBase58(allocator);
    defer allocator.free(signer_base58);
    const writable = sdk.Pubkey.fromBytes(.{83} ** 32);
    const writable_base58 = try writable.toBase58(allocator);
    defer allocator.free(writable_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":true,\"is_writable\":false}},{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":true}}]",
        .{ signer_base58, writable_base58 },
    );
    defer allocator.free(accounts_json);

    var owned_instruction = try buildOwnedInstructionFromJson(
        allocator,
        program_id_base58,
        .{
            .accounts_json = accounts_json,
            .data = "ping",
            .data_encoding = .utf8,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expect(owned_instruction.instruction.program_id.eql(program_id));
    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(signer));
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(!owned_instruction.instruction.accounts[0].is_writable);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(writable));
    try std.testing.expect(!owned_instruction.instruction.accounts[1].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction merges typed accounts before json accounts" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{84} ** 32);
    const typed = sdk.Pubkey.fromBytes(.{85} ** 32);
    const json = sdk.Pubkey.fromBytes(.{86} ** 32);
    const json_base58 = try json.toBase58(allocator);
    defer allocator.free(json_base58);

    const accounts_json = try std.fmt.allocPrint(
        allocator,
        "[{{\"pubkey\":\"{s}\",\"is_signer\":false,\"is_writable\":true}}]",
        .{json_base58},
    );
    defer allocator.free(accounts_json);

    const typed_accounts = [_]sdk.AccountMeta{
        sdk.AccountMeta.init(typed, true, false),
    };

    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .accounts = &typed_accounts,
            .accounts_json = accounts_json,
            .data = "70696e67",
            .data_encoding = .hex,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), owned_instruction.instruction.accounts.len);
    try std.testing.expect(owned_instruction.instruction.accounts[0].pubkey.eql(typed));
    try std.testing.expect(owned_instruction.instruction.accounts[0].is_signer);
    try std.testing.expect(owned_instruction.instruction.accounts[1].pubkey.eql(json));
    try std.testing.expect(owned_instruction.instruction.accounts[1].is_writable);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}

test "program_invoke.buildOwnedInstruction decodes base64 data" {
    const allocator = std.testing.allocator;

    const program_id = sdk.Pubkey.fromBytes(.{87} ** 32);
    var owned_instruction = try buildOwnedInstruction(
        allocator,
        program_id,
        .{
            .data = "cGluZw==",
            .data_encoding = .base64,
        },
    );
    defer owned_instruction.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), owned_instruction.instruction.accounts.len);
    try std.testing.expectEqualStrings("ping", owned_instruction.instruction.data);
}
