const std = @import("std");
const json = std.json;
const rpc_types = @import("../rpc_types.zig");

const JsonParsedProgramAccount = rpc_types.JsonParsedProgramAccount;
const JsonParsedProgramAccountsResponse = rpc_types.JsonParsedProgramAccountsResponse;
const ProgramAccount = rpc_types.ProgramAccount;
const ProgramAccountsQueryOptions = rpc_types.ProgramAccountsQueryOptions;
const ProgramAccountsResponse = rpc_types.ProgramAccountsResponse;
const RpcJsonParsedProgramAccountResult = rpc_types.RpcJsonParsedProgramAccountResult;
const RpcProgramAccountResult = rpc_types.RpcProgramAccountResult;
const commitmentToString = rpc_types.commitmentToString;

fn lessThanProgramAccount(_: void, lhs: ProgramAccount, rhs: ProgramAccount) bool {
    return std.mem.order(u8, lhs.pubkey, rhs.pubkey) == .lt;
}

fn lessThanJsonParsedProgramAccount(_: void, lhs: JsonParsedProgramAccount, rhs: JsonParsedProgramAccount) bool {
    return std.mem.order(u8, lhs.pubkey, rhs.pubkey) == .lt;
}

fn maybeSortProgramAccounts(accounts: []ProgramAccount, sort_results: bool) void {
    if (!sort_results) return;
    std.mem.sort(ProgramAccount, accounts, {}, lessThanProgramAccount);
}

fn maybeSortJsonParsedProgramAccounts(accounts: []JsonParsedProgramAccount, sort_results: bool) void {
    if (!sort_results) return;
    std.mem.sort(JsonParsedProgramAccount, accounts, {}, lessThanJsonParsedProgramAccount);
}

pub fn serializeProgramAccountsParams(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]u8 {
    const DataSlice = struct {
        offset: u64,
        length: u64,
    };
    const DataSizeFilter = struct {
        dataSize: u64,
    };
    const MemcmpFilter = struct {
        memcmp: struct {
            offset: u64,
            bytes: []const u8,
        },
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const min_context_slot = if (options) |value| value.min_context_slot else null;
    const with_context = if (options) |value| value.with_context else false;
    const has_data_size = if (options) |value| value.data_size != null else false;
    const has_memcmp = if (options) |value| value.memcmp_offset != null and value.memcmp_bytes != null else false;
    const has_data_slice = if (options) |value| value.data_slice_offset != null and value.data_slice_length != null else false;

    if (!has_data_size and !has_memcmp and !has_data_slice and resolved_commitment == null and min_context_slot == null and !with_context) {
        return try self.serializeParams(.{program_id});
    }

    if (has_data_size and has_memcmp and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{
                    DataSizeFilter{ .dataSize = options.?.data_size.? },
                    MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } },
                },
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size and has_memcmp) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .filters = .{
                    DataSizeFilter{ .dataSize = options.?.data_size.? },
                    MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } },
                },
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{DataSizeFilter{ .dataSize = options.?.data_size.? }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_memcmp and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .filters = .{DataSizeFilter{ .dataSize = options.?.data_size.? }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_memcmp) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .filters = .{MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
            },
        };
        return try self.serializeParams(params);
    }

    const params = .{
        program_id,
        .{
            .commitment = resolved_commitment,
            .minContextSlot = min_context_slot,
            .withContext = with_context,
        },
    };
    return try self.serializeParams(params);
}

pub fn serializeProgramUiAccountsParams(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]u8 {
    const DataSlice = struct {
        offset: u64,
        length: u64,
    };
    const DataSizeFilter = struct {
        dataSize: u64,
    };
    const MemcmpFilter = struct {
        memcmp: struct {
            offset: u64,
            bytes: []const u8,
        },
    };

    const resolved_commitment = self.resolveCommitmentString(if (options) |value| value.commitment else null);
    const min_context_slot = if (options) |value| value.min_context_slot else null;
    const with_context = if (options) |value| value.with_context else false;
    const has_data_size = if (options) |value| value.data_size != null else false;
    const has_memcmp = if (options) |value| value.memcmp_offset != null and value.memcmp_bytes != null else false;
    const has_data_slice = if (options) |value| value.data_slice_offset != null and value.data_slice_length != null else false;

    if (!has_data_size and !has_memcmp and !has_data_slice and resolved_commitment == null and min_context_slot == null and !with_context) {
        return try self.serializeParams(.{
            program_id,
            .{ .encoding = "jsonParsed" },
        });
    }

    if (has_data_size and has_memcmp and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{
                    DataSizeFilter{ .dataSize = options.?.data_size.? },
                    MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } },
                },
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size and has_memcmp) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .filters = .{
                    DataSizeFilter{ .dataSize = options.?.data_size.? },
                    MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } },
                },
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{DataSizeFilter{ .dataSize = options.?.data_size.? }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_memcmp and has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
                .filters = .{MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_size) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .filters = .{DataSizeFilter{ .dataSize = options.?.data_size.? }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_memcmp) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .filters = .{MemcmpFilter{ .memcmp = .{ .offset = options.?.memcmp_offset.?, .bytes = options.?.memcmp_bytes.? } }},
            },
        };
        return try self.serializeParams(params);
    }

    if (has_data_slice) {
        const params = .{
            program_id,
            .{
                .commitment = resolved_commitment,
                .minContextSlot = min_context_slot,
                .withContext = with_context,
                .encoding = "jsonParsed",
                .dataSlice = DataSlice{
                    .offset = options.?.data_slice_offset.?,
                    .length = options.?.data_slice_length.?,
                },
            },
        };
        return try self.serializeParams(params);
    }

    const params = .{
        program_id,
        .{
            .commitment = resolved_commitment,
            .minContextSlot = min_context_slot,
            .withContext = with_context,
            .encoding = "jsonParsed",
        },
    };
    return try self.serializeParams(params);
}

pub fn getProgramAccountsResponseWithOptions(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) !ProgramAccountsResponse {
    const params_json = try self.serializeProgramAccountsParams(program_id, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getProgramAccounts", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    if (options != null and options.?.with_context) {
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?struct {
                context: struct {
                    slot: u64 = 0,
                } = .{ .slot = 0 },
                value: []RpcProgramAccountResult = &.{},
            } = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.cloneProgramAccounts(result.value);
        maybeSortProgramAccounts(copied, if (options) |value| value.sort_results else false);
        return ProgramAccountsResponse{
            .context_slot = result.context.slot,
            .accounts = copied,
        };
    }

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?[]RpcProgramAccountResult = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const source = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.cloneProgramAccounts(source);
    maybeSortProgramAccounts(copied, if (options) |value| value.sort_results else false);
    return ProgramAccountsResponse{
        .context_slot = null,
        .accounts = copied,
    };
}

pub fn getProgramAccountsResponseWithConfig(
    self: anytype,
    program_id: []const u8,
    options: ?ProgramAccountsQueryOptions,
) !ProgramAccountsResponse {
    return try self.getProgramAccountsResponseWithOptions(program_id, options);
}

pub fn getProgramAccountsWithOptions(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]ProgramAccount {
    const response = try self.getProgramAccountsResponseWithOptions(program_id, options);
    return response.accounts;
}

pub fn getProgramAccountsWithConfig(
    self: anytype,
    program_id: []const u8,
    options: ?ProgramAccountsQueryOptions,
) ![]ProgramAccount {
    return try self.getProgramAccountsWithOptions(program_id, options);
}

pub fn getProgramAccounts(self: anytype, program_id: []const u8, commitment: ?rpc_types.Commitment) ![]ProgramAccount {
    const options = if (commitment) |value|
        ProgramAccountsQueryOptions{ .commitment = value }
    else
        null;
    return try self.getProgramAccountsWithOptions(program_id, options);
}

pub fn getProgramUiAccountsResponseWithOptions(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) !JsonParsedProgramAccountsResponse {
    const params_json = try self.serializeProgramUiAccountsParams(program_id, options);
    defer self.allocator.free(params_json);

    const response = try self.sendRequest("getProgramAccounts", params_json);
    defer self.allocator.free(response);

    try self.captureRpcError(response);

    if (options != null and options.?.with_context) {
        const ParsedEnvelope = struct {
            jsonrpc: []const u8 = "",
            id: u64 = 0,
            result: ?struct {
                context: struct {
                    slot: u64 = 0,
                } = .{ .slot = 0 },
                value: []RpcJsonParsedProgramAccountResult = &.{},
            } = null,
        };

        const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const result = parsed.value.result orelse return error.InvalidResponse;
        const copied = try self.cloneJsonParsedProgramAccounts(result.value);
        maybeSortJsonParsedProgramAccounts(copied, if (options) |value| value.sort_results else false);
        return JsonParsedProgramAccountsResponse{
            .context_slot = result.context.slot,
            .accounts = copied,
        };
    }

    const ParsedEnvelope = struct {
        jsonrpc: []const u8 = "",
        id: u64 = 0,
        result: ?[]RpcJsonParsedProgramAccountResult = null,
    };

    const parsed = try json.parseFromSlice(ParsedEnvelope, self.allocator, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const source = parsed.value.result orelse return error.InvalidResponse;
    const copied = try self.cloneJsonParsedProgramAccounts(source);
    maybeSortJsonParsedProgramAccounts(copied, if (options) |value| value.sort_results else false);
    return JsonParsedProgramAccountsResponse{
        .context_slot = null,
        .accounts = copied,
    };
}

pub fn getProgramUiAccountsResponseWithConfig(
    self: anytype,
    program_id: []const u8,
    options: ?ProgramAccountsQueryOptions,
) !JsonParsedProgramAccountsResponse {
    return try self.getProgramUiAccountsResponseWithOptions(program_id, options);
}

pub fn getProgramUiAccountsWithOptions(self: anytype, program_id: []const u8, options: ?ProgramAccountsQueryOptions) ![]JsonParsedProgramAccount {
    const response = try self.getProgramUiAccountsResponseWithOptions(program_id, options);
    return response.accounts;
}

pub fn getProgramUiAccountsWithConfig(
    self: anytype,
    program_id: []const u8,
    options: ?ProgramAccountsQueryOptions,
) ![]JsonParsedProgramAccount {
    return try self.getProgramUiAccountsWithOptions(program_id, options);
}

pub fn getProgramUiAccounts(self: anytype, program_id: []const u8, commitment: ?rpc_types.Commitment) ![]JsonParsedProgramAccount {
    const options = if (commitment) |value|
        ProgramAccountsQueryOptions{ .commitment = value }
    else
        null;
    return try self.getProgramUiAccountsWithOptions(program_id, options);
}
