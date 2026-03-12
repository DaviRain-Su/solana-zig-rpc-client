const std = @import("std");
const sdk = @import("../sdk.zig");
const idl_types = @import("./types.zig");
const idl_encode = @import("./encode.zig");

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;
const ParseIdlError = @typeInfo(@typeInfo(@TypeOf(idl_types.parseJson)).@"fn".return_type.?).error_union.error_set;
const EncodeInstructionDataError = @typeInfo(@typeInfo(@TypeOf(idl_encode.encodeInstructionDataNamed)).@"fn".return_type.?).error_union.error_set;

pub const BuildError = Allocator.Error || ParseIdlError || EncodeInstructionDataError || error{
    MissingAnchorIdlProgramId,
    MissingAnchorIdlAccountBinding,
    InvalidAnchorIdlAccountSpec,
    UnsupportedAnchorIdlAccountFeature,
};

pub const AccountBinding = struct {
    path: []const u8,
    pubkey: sdk.Pubkey,
};

pub const BuildInstructionOptions = struct {
    program_id: ?sdk.Pubkey = null,
    args_json: ?[]const u8 = null,
    account_bindings: []const AccountBinding = &.{},
    remaining_accounts: []const sdk.AccountMeta = &.{},
    default_signer: ?sdk.Pubkey = null,
};

pub const OwnedInstruction = struct {
    instruction: sdk.Instruction,

    pub fn deinit(self: *OwnedInstruction, allocator: Allocator) void {
        allocator.free(self.instruction.accounts);
        allocator.free(self.instruction.data);
        self.* = undefined;
    }
};

fn pathSegmentMatches(expected_name: []const u8, provided_name: []const u8) bool {
    if (std.mem.eql(u8, expected_name, provided_name)) return true;
    if (expected_name.len == 0 or provided_name.len == 0) return false;

    var expected_index: usize = 0;
    var provided_index: usize = 0;
    while (true) {
        while (expected_index < expected_name.len and expected_name[expected_index] == '_') {
            expected_index += 1;
        }
        while (provided_index < provided_name.len and provided_name[provided_index] == '_') {
            provided_index += 1;
        }

        if (expected_index == expected_name.len or provided_index == provided_name.len) break;
        if (std.ascii.toLower(expected_name[expected_index]) != std.ascii.toLower(provided_name[provided_index])) {
            return false;
        }

        expected_index += 1;
        provided_index += 1;
    }

    while (expected_index < expected_name.len and expected_name[expected_index] == '_') {
        expected_index += 1;
    }
    while (provided_index < provided_name.len and provided_name[provided_index] == '_') {
        provided_index += 1;
    }

    return expected_index == expected_name.len and provided_index == provided_name.len;
}

fn fullPathMatches(expected_path: []const u8, provided_path: []const u8) bool {
    var expected_rest = expected_path;
    var provided_rest = provided_path;

    while (true) {
        const expected_dot = std.mem.indexOfScalar(u8, expected_rest, '.');
        const provided_dot = std.mem.indexOfScalar(u8, provided_rest, '.');

        const expected_segment = expected_rest[0 .. expected_dot orelse expected_rest.len];
        const provided_segment = provided_rest[0 .. provided_dot orelse provided_rest.len];
        if (!pathSegmentMatches(expected_segment, provided_segment)) return false;

        if (expected_dot == null or provided_dot == null) {
            return expected_dot == null and provided_dot == null;
        }

        expected_rest = expected_rest[expected_dot.? + 1 ..];
        provided_rest = provided_rest[provided_dot.? + 1 ..];
    }
}

fn normalizeAccountPath(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".key")) return path[0 .. path.len - 4];
    if (std.mem.endsWith(u8, path, ".pubkey")) return path[0 .. path.len - 7];
    if (std.mem.endsWith(u8, path, ".publicKey")) return path[0 .. path.len - 10];
    if (std.mem.endsWith(u8, path, ".public_key")) return path[0 .. path.len - 11];
    if (std.mem.endsWith(u8, path, ".address")) return path[0 .. path.len - 8];
    if (std.mem.endsWith(u8, path, ".programId")) return path[0 .. path.len - 10];
    if (std.mem.endsWith(u8, path, ".program_id")) return path[0 .. path.len - 11];
    return path;
}

fn findBoundPubkey(bindings: []const AccountBinding, full_name: []const u8, leaf_name: []const u8) ?sdk.Pubkey {
    for (bindings) |binding| {
        if (fullPathMatches(binding.path, full_name) or fullPathMatches(binding.path, leaf_name)) return binding.pubkey;

        const normalized_path = normalizeAccountPath(binding.path);
        if (!std.mem.eql(u8, normalized_path, binding.path)) {
            if (fullPathMatches(normalized_path, full_name) or fullPathMatches(normalized_path, leaf_name)) {
                return binding.pubkey;
            }
        }
    }
    return null;
}

fn countLeafAccounts(accounts: []const std.json.Value) BuildError!usize {
    var count: usize = 0;
    for (accounts) |account_value| {
        if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
        _ = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            count += try countLeafAccounts(nested_value.array.items);
        } else {
            count += 1;
        }
    }
    return count;
}

fn findLiteralPubkey(allocator: Allocator, account_value: std.json.Value) BuildError!?sdk.Pubkey {
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    inline for (.{ "address", "publicKey", "public_key", "pubkey", "key", "programId", "program_id" }) |field_name| {
        if (account_value.object.get(field_name)) |field_value| {
            if (field_value != .string) return error.InvalidAnchorIdlAccountSpec;
            return sdk.Pubkey.fromBase58(allocator, field_value.string) catch return error.InvalidAnchorIdlAccountSpec;
        }
    }
    return null;
}

fn parseAccountBoolFlag(
    account_value: std.json.Value,
    primary_field: []const u8,
    alias_field: []const u8,
    snake_alias_field: []const u8,
) BuildError!bool {
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    if (account_value.object.get(primary_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    if (account_value.object.get(alias_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    if (account_value.object.get(snake_alias_field)) |value| {
        if (value != .bool) return error.InvalidAnchorIdlAccountSpec;
        return value.bool;
    }
    return false;
}

fn isWritableAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "writable", "isMut", "is_mut");
}

fn isSignerAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "signer", "isSigner", "is_signer");
}

fn isOptionalAccount(account_value: std.json.Value) BuildError!bool {
    return parseAccountBoolFlag(account_value, "optional", "isOptional", "is_optional");
}

fn isEventCpiAccount(accounts: []const std.json.Value, account_index: usize, expected_name: []const u8) BuildError!bool {
    if (account_index >= accounts.len) return false;
    const account_value = accounts[account_index];
    if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
    const name_value = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
    if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;

    const matches_expected = if (std.mem.eql(u8, expected_name, "eventAuthority"))
        std.mem.eql(u8, name_value.string, "eventAuthority") or std.mem.eql(u8, name_value.string, "event_authority")
    else
        std.mem.eql(u8, name_value.string, expected_name);
    if (!matches_expected) return false;

    if (std.mem.eql(u8, expected_name, "eventAuthority")) {
        if (account_index + 1 >= accounts.len) return false;
        const next_value = accounts[account_index + 1];
        if (next_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const next_name = next_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (next_name != .string) return error.InvalidAnchorIdlAccountSpec;
        return std.mem.eql(u8, next_name.string, "program");
    }

    if (std.mem.eql(u8, expected_name, "program")) {
        if (account_index == 0) return false;
        const prev_value = accounts[account_index - 1];
        if (prev_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const prev_name = prev_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (prev_name != .string) return error.InvalidAnchorIdlAccountSpec;
        return std.mem.eql(u8, prev_name.string, "eventAuthority") or std.mem.eql(u8, prev_name.string, "event_authority");
    }

    return false;
}

fn createProgramAddress(seeds: []const []const u8, program_id: sdk.Pubkey) BuildError!sdk.Pubkey {
    for (seeds) |seed| {
        if (seed.len > 32) return error.InvalidAnchorIdlAccountSpec;
    }

    var hasher = Sha256.init(.{});
    for (seeds) |seed| hasher.update(seed);
    hasher.update(&program_id.bytes);
    hasher.update("ProgramDerivedAddress");

    var hash: [32]u8 = undefined;
    hasher.final(&hash);
    if (std.crypto.ecc.Edwards25519.fromBytes(hash)) |_| {
        return error.InvalidAnchorIdlAccountSpec;
    } else |_| {}
    return sdk.Pubkey.fromBytes(hash);
}

fn findProgramAddress(allocator: Allocator, seeds: []const []const u8, program_id: sdk.Pubkey) BuildError!sdk.Pubkey {
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
    return error.InvalidAnchorIdlAccountSpec;
}

fn resolveBuiltinAccountPubkey(allocator: Allocator, account_name: []const u8) BuildError!?sdk.Pubkey {
    const builtin_base58: ?[]const u8 = if (std.mem.eql(u8, account_name, "systemProgram") or
        std.mem.eql(u8, account_name, "system_program") or
        std.mem.eql(u8, account_name, "systemProgramId") or
        std.mem.eql(u8, account_name, "system_program_id"))
        "11111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "tokenProgram") or
        std.mem.eql(u8, account_name, "token_program") or
        std.mem.eql(u8, account_name, "tokenProgramId") or
        std.mem.eql(u8, account_name, "token_program_id"))
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    else if (std.mem.eql(u8, account_name, "associatedTokenProgram") or
        std.mem.eql(u8, account_name, "associated_token_program") or
        std.mem.eql(u8, account_name, "associatedTokenProgramId") or
        std.mem.eql(u8, account_name, "associated_token_program_id"))
        "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    else if (std.mem.eql(u8, account_name, "token2022Program") or
        std.mem.eql(u8, account_name, "token_2022_program") or
        std.mem.eql(u8, account_name, "token2022_program") or
        std.mem.eql(u8, account_name, "token_program_2022") or
        std.mem.eql(u8, account_name, "token2022ProgramId") or
        std.mem.eql(u8, account_name, "token_2022_program_id") or
        std.mem.eql(u8, account_name, "token2022_program_id") or
        std.mem.eql(u8, account_name, "token_program_2022_id"))
        "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    else if (std.mem.eql(u8, account_name, "rent") or
        std.mem.eql(u8, account_name, "rentSysvar") or
        std.mem.eql(u8, account_name, "rent_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_rent") or
        std.mem.eql(u8, account_name, "rentSysvarId") or
        std.mem.eql(u8, account_name, "rent_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_rent_id"))
        "SysvarRent111111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "clock") or
        std.mem.eql(u8, account_name, "clockSysvar") or
        std.mem.eql(u8, account_name, "clock_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_clock") or
        std.mem.eql(u8, account_name, "clockSysvarId") or
        std.mem.eql(u8, account_name, "clock_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_clock_id"))
        "SysvarC1ock11111111111111111111111111111111"
    else if (std.mem.eql(u8, account_name, "instructions") or
        std.mem.eql(u8, account_name, "instructionsSysvar") or
        std.mem.eql(u8, account_name, "instructions_sysvar") or
        std.mem.eql(u8, account_name, "instructionSysvar") or
        std.mem.eql(u8, account_name, "instruction_sysvar") or
        std.mem.eql(u8, account_name, "sysvar_instructions") or
        std.mem.eql(u8, account_name, "instructionsSysvarId") or
        std.mem.eql(u8, account_name, "instructions_sysvar_id") or
        std.mem.eql(u8, account_name, "instructionSysvarId") or
        std.mem.eql(u8, account_name, "instruction_sysvar_id") or
        std.mem.eql(u8, account_name, "sysvar_instructions_id"))
        "Sysvar1nstructions1111111111111111111111111"
    else
        null;

    if (builtin_base58) |value| {
        return sdk.Pubkey.fromBase58(allocator, value) catch return error.InvalidAnchorIdlAccountSpec;
    }
    return null;
}

fn appendInstructionAccounts(
    allocator: Allocator,
    accounts: []const std.json.Value,
    bindings: []const AccountBinding,
    default_signer: ?sdk.Pubkey,
    program_id: sdk.Pubkey,
    metas: []sdk.AccountMeta,
    next_index: *usize,
    parent_path: ?[]const u8,
) BuildError!void {
    for (accounts, 0..) |account_value, account_index| {
        if (account_value != .object) return error.InvalidAnchorIdlAccountSpec;
        const name_value = account_value.object.get("name") orelse return error.InvalidAnchorIdlAccountSpec;
        if (name_value != .string) return error.InvalidAnchorIdlAccountSpec;

        const full_name = if (parent_path) |value|
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ value, name_value.string })
        else
            try allocator.dupe(u8, name_value.string);
        defer allocator.free(full_name);

        if (account_value.object.get("accounts")) |nested_value| {
            if (nested_value != .array) return error.InvalidAnchorIdlAccountSpec;
            try appendInstructionAccounts(
                allocator,
                nested_value.array.items,
                bindings,
                default_signer,
                program_id,
                metas,
                next_index,
                full_name,
            );
            continue;
        }

        const is_optional = try isOptionalAccount(account_value);
        const is_signer = try isSignerAccount(account_value);
        const is_writable = try isWritableAccount(account_value);
        var resolved_pubkey = findBoundPubkey(bindings, full_name, name_value.string);
        var missing_optional_account = false;

        if (resolved_pubkey == null) {
            resolved_pubkey = try findLiteralPubkey(allocator, account_value);
        }
        if (resolved_pubkey == null) {
            if (default_signer) |value| {
                if (is_signer and !is_optional) resolved_pubkey = value;
            }
        }
        if (resolved_pubkey == null) {
            resolved_pubkey = try resolveBuiltinAccountPubkey(allocator, name_value.string);
        }
        if (resolved_pubkey == null) {
            if (try isEventCpiAccount(accounts, account_index, "eventAuthority")) {
                resolved_pubkey = try findProgramAddress(allocator, &.{"__event_authority"}, program_id);
            } else if (try isEventCpiAccount(accounts, account_index, "program")) {
                resolved_pubkey = program_id;
            }
        }
        if (resolved_pubkey == null and is_optional) {
            resolved_pubkey = program_id;
            missing_optional_account = true;
        }
        if (resolved_pubkey == null and (account_value.object.get("pda") != null or account_value.object.get("relations") != null)) {
            return error.UnsupportedAnchorIdlAccountFeature;
        }

        metas[next_index.*] = .{
            .pubkey = resolved_pubkey orelse return error.MissingAnchorIdlAccountBinding,
            .is_signer = if (missing_optional_account) false else is_signer,
            .is_writable = if (missing_optional_account) false else is_writable,
        };
        next_index.* += 1;
    }
}

pub fn buildOwnedInstruction(
    allocator: Allocator,
    idl: *const idl_types.Idl,
    instruction_name: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    const instruction = idl_types.findInstruction(idl, instruction_name) orelse return error.MissingAnchorIdlInstruction;
    const program_id = if (options.program_id) |value|
        value
    else if (idl_types.programAddress(idl)) |value|
        sdk.Pubkey.fromBase58(allocator, value) catch return error.InvalidAnchorIdlAccountSpec
    else
        return error.MissingAnchorIdlProgramId;

    const data = try idl_encode.encodeInstructionDataNamed(allocator, idl, instruction_name, options.args_json);
    errdefer allocator.free(data);

    const leaf_account_count = try countLeafAccounts(instruction.accounts);
    const accounts = try allocator.alloc(sdk.AccountMeta, leaf_account_count + options.remaining_accounts.len);
    errdefer allocator.free(accounts);

    var next_index: usize = 0;
    try appendInstructionAccounts(
        allocator,
        instruction.accounts,
        options.account_bindings,
        options.default_signer,
        program_id,
        accounts,
        &next_index,
        null,
    );
    @memcpy(accounts[next_index .. next_index + options.remaining_accounts.len], options.remaining_accounts);
    next_index += options.remaining_accounts.len;

    return .{
        .instruction = .{
            .program_id = program_id,
            .accounts = accounts[0..next_index],
            .data = data,
        },
    };
}

pub fn buildOwnedInstructionFromJson(
    allocator: Allocator,
    idl_json_source: []const u8,
    instruction_name: []const u8,
    options: BuildInstructionOptions,
) BuildError!OwnedInstruction {
    const parsed_idl = try idl_types.parseJson(allocator, idl_json_source);
    defer parsed_idl.deinit();

    return try buildOwnedInstruction(allocator, &parsed_idl.value, instruction_name, options);
}
