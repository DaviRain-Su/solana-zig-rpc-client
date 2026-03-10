const std = @import("std");

pub const Idl = struct {
    address: ?[]const u8 = null,
    instructions: []const Instruction = &.{},
};

pub const Instruction = struct {
    name: []const u8,
    discriminator: []const u8 = &.{},
    accounts: []const std.json.Value = &.{},
    args: []const std.json.Value = &.{},

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
