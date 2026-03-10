const std = @import("std");

pub const Idl = struct {
    address: ?[]const u8 = null,
    metadata: ?IdlMetadata = null,
    instructions: []const Instruction = &.{},
    types: []const TypeDef = &.{},
};

pub const IdlMetadata = struct {
    address: ?[]const u8 = null,
};

pub const TypeDef = struct {
    name: []const u8,
    type: std.json.Value = .null,
};

pub const IdlArg = struct {
    name: []const u8,
    @"type": std.json.Value = .null,
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

pub fn findInstruction(idl: *const Idl, name: []const u8) ?Instruction {
    for (idl.instructions) |instruction| {
        if (std.mem.eql(u8, instruction.name, name)) return instruction;
    }
    return null;
}

pub fn programAddress(idl: *const Idl) ?[]const u8 {
    if (idl.address) |value| return value;
    if (idl.metadata) |metadata| {
        if (metadata.address) |value| return value;
    }
    return null;
}

pub fn findType(idl: *const Idl, name: []const u8) ?TypeDef {
    for (idl.types) |type_def| {
        if (std.mem.eql(u8, type_def.name, name)) return type_def;
    }
    return null;
}
