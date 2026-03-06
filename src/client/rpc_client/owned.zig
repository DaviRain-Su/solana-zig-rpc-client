const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const AccountInfo = rpc_types.AccountInfo;
const JsonParsedAccountInfo = rpc_types.JsonParsedAccountInfo;
const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const ProgramAccount = rpc_types.ProgramAccount;
const RpcAccountInfoResult = rpc_types.RpcAccountInfoResult;
const RpcJsonParsedAccountInfoResult = rpc_types.RpcJsonParsedAccountInfoResult;
const RpcJsonParsedProgramAccountResult = rpc_types.RpcJsonParsedProgramAccountResult;
const RpcProgramAccountResult = rpc_types.RpcProgramAccountResult;

pub fn cloneAccountInfo(self: anytype, source: RpcAccountInfoResult) !AccountInfo {
    return AccountInfo{
        .lamports = source.lamports,
        .owner = try self.allocator.dupe(u8, source.owner),
        .executable = source.executable,
        .rent_epoch = source.rentEpoch,
        .space = source.space,
        .data = if (source.data) |entry|
            if (entry.len >= 1) try self.allocator.dupe(u8, entry[0]) else null
        else
            null,
        .data_encoding = if (source.data) |entry|
            if (entry.len >= 2) try self.allocator.dupe(u8, entry[1]) else null
        else
            null,
    };
}

pub fn freeOwnedAccountInfo(self: anytype, info: AccountInfo) void {
    self.allocator.free(info.owner);
    if (info.data) |value| self.allocator.free(value);
    if (info.data_encoding) |value| self.allocator.free(value);
}

pub fn cloneOptionalAccountInfos(self: anytype, source: []const ?RpcAccountInfoResult) ![]?AccountInfo {
    const copied = try self.allocator.alloc(?AccountInfo, source.len);
    var copied_len: usize = 0;
    errdefer {
        for (copied[0..copied_len]) |maybe_info| {
            if (maybe_info) |info| {
                self.freeOwnedAccountInfo(info);
            }
        }
        self.allocator.free(copied);
    }

    for (source, 0..) |maybe_info, index| {
        copied[index] = if (maybe_info) |info| try self.cloneAccountInfo(info) else null;
        copied_len += 1;
    }

    return copied;
}

pub fn cloneOptionalJsonParsedAccountInfos(
    self: anytype,
    source: []const ?RpcJsonParsedAccountInfoResult,
) ![]?JsonParsedAccountInfo {
    const copied = try self.allocator.alloc(?JsonParsedAccountInfo, source.len);
    var copied_len: usize = 0;
    errdefer {
        for (copied[0..copied_len]) |maybe_info| {
            if (maybe_info) |info| {
                self.allocator.free(info.owner);
                self.allocator.free(info.data_json);
            }
        }
        self.allocator.free(copied);
    }

    for (source, 0..) |maybe_info, index| {
        copied[index] = if (maybe_info) |info| try self.cloneJsonParsedAccountInfo(info) else null;
        copied_len += 1;
    }

    return copied;
}

pub fn cloneStringList(self: anytype, source: []const []const u8) ![][]const u8 {
    const copied = try self.allocator.alloc([]const u8, source.len);
    var copied_len: usize = 0;
    errdefer {
        for (copied[0..copied_len]) |entry| {
            self.allocator.free(entry);
        }
        self.allocator.free(copied);
    }

    for (source, 0..) |entry, index| {
        copied[index] = try self.allocator.dupe(u8, entry);
        copied_len += 1;
    }

    return copied;
}

pub fn cloneJsonParsedAccountInfo(self: anytype, source: RpcJsonParsedAccountInfoResult) !JsonParsedAccountInfo {
    return JsonParsedAccountInfo{
        .lamports = source.lamports,
        .owner = try self.allocator.dupe(u8, source.owner),
        .executable = source.executable,
        .rent_epoch = source.rentEpoch,
        .space = source.space,
        .data_json = try json.Stringify.valueAlloc(self.allocator, source.data, .{}),
    };
}

pub fn cloneProgramAccounts(self: anytype, source: []const RpcProgramAccountResult) ![]ProgramAccount {
    const copied = try self.allocator.alloc(ProgramAccount, source.len);
    var copied_len: usize = 0;
    errdefer {
        for (copied[0..copied_len]) |entry| {
            self.allocator.free(entry.pubkey);
            self.freeOwnedAccountInfo(entry.account);
        }
        self.allocator.free(copied);
    }

    for (source, 0..) |entry, index| {
        copied[index] = ProgramAccount{
            .pubkey = try self.allocator.dupe(u8, entry.pubkey),
            .account = try self.cloneAccountInfo(entry.account),
        };
        copied_len += 1;
    }

    return copied;
}

pub fn cloneJsonParsedProgramAccounts(
    self: anytype,
    source: []const RpcJsonParsedProgramAccountResult,
) ![]JsonParsedProgramAccount {
    const copied = try self.allocator.alloc(JsonParsedProgramAccount, source.len);
    var copied_len: usize = 0;
    errdefer {
        for (copied[0..copied_len]) |entry| {
            self.allocator.free(entry.pubkey);
            self.allocator.free(entry.account.owner);
            self.allocator.free(entry.account.data_json);
        }
        self.allocator.free(copied);
    }

    for (source, 0..) |entry, index| {
        copied[index] = JsonParsedProgramAccount{
            .pubkey = try self.allocator.dupe(u8, entry.pubkey),
            .account = try self.cloneJsonParsedAccountInfo(entry.account),
        };
        copied_len += 1;
    }

    return copied;
}
