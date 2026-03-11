const std = @import("std");

pub const Idl = struct {
    address: ?[]const u8 = null,
    programId: ?[]const u8 = null,
    program_id: ?[]const u8 = null,
    metadata: ?IdlMetadata = null,
    instructions: []const Instruction = &.{},
    types: []const TypeDef = &.{},
    accounts: []const TypeDef = &.{},
};

pub const IdlMetadata = struct {
    address: ?[]const u8 = null,
    programId: ?[]const u8 = null,
    program_id: ?[]const u8 = null,
};

pub const TypeDef = struct {
    name: []const u8,
    type: std.json.Value = .null,
};

pub const IdlArg = struct {
    name: []const u8,
    type: std.json.Value = .null,
};

pub const Instruction = struct {
    name: []const u8,
    discriminator: []const u8 = &.{},
    accounts: []const std.json.Value = &.{},
    args: []const IdlArg = &.{},

    pub fn hasZeroAccountsAndArgs(self: *const Instruction) bool {
        return self.accounts.len == 0 and self.args.len == 0;
    }
};

fn anchorIdlNameMatches(expected_name: []const u8, provided_name: []const u8) bool {
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

pub fn findInstruction(idl: *const Idl, name: []const u8) ?Instruction {
    for (idl.instructions) |instruction| {
        if (anchorIdlNameMatches(instruction.name, name)) return instruction;
    }
    return null;
}

pub fn programAddress(idl: *const Idl) ?[]const u8 {
    if (idl.address) |value| return value;
    if (idl.programId) |value| return value;
    if (idl.program_id) |value| return value;
    if (idl.metadata) |metadata| {
        if (metadata.address) |value| return value;
        if (metadata.programId) |value| return value;
        if (metadata.program_id) |value| return value;
    }
    return null;
}

pub fn findType(idl: *const Idl, name: []const u8) ?TypeDef {
    for (idl.types) |type_def| {
        if (std.mem.eql(u8, type_def.name, name)) return type_def;
    }
    for (idl.accounts) |type_def| {
        if (std.mem.eql(u8, type_def.name, name)) return type_def;
    }
    return null;
}

test "findInstruction matches camel and snake case aliases" {
    const idl = Idl{
        .instructions = &.{
            .{ .name = "initializeConfig" },
            .{ .name = "close_position" },
        },
    };

    try std.testing.expect(findInstruction(&idl, "initialize_config") != null);
    try std.testing.expect(findInstruction(&idl, "InitializeConfig") != null);
    try std.testing.expect(findInstruction(&idl, "closePosition") != null);
}
