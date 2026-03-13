const std = @import("std");
const client = @import("../root.zig");

const Allocator = std.mem.Allocator;
const sdk = client.sdk;
const rpc_types = client.rpc_types;

pub const InvokeFamily = enum {
    instructions,
    program,
    anchor_idl,
};

pub const SendInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    send_transaction_options: ?client.SendTransactionOptions = null,
};

pub const SimulateInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    simulate_options: ?client.SimulateTransactionOptions = null,
};

pub const BuildInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
};

pub const GetFeeForInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    commitment: ?client.Commitment = null,
};

pub const SendAndConfirmInvocationSpecOptions = struct {
    blockhash_commitment: ?client.Commitment = null,
    send_transaction_options: ?client.SendTransactionOptions = null,
    commitment: ?client.Commitment = null,
    search_transaction_history: bool = false,
    timeout_ms: u64 = client.poll_for_signature_confirmation_timeout_ms,
    poll_interval_ms: u64 = client.signature_poll_interval_ms,
};

pub const OwnedInvocationMessage = union(enum) {
    legacy: sdk.OwnedLegacyMessage,
    versioned: sdk.OwnedVersionedMessageV0,

    pub fn deinit(self: *OwnedInvocationMessage, allocator: Allocator) void {
        switch (self.*) {
            .legacy => |*owned| owned.deinit(allocator),
            .versioned => |*owned| owned.deinit(allocator),
        }
    }
};

pub const SignedInvocationTransaction = union(enum) {
    legacy: sdk.SignedLegacyTransaction,
    versioned: sdk.SignedVersionedTransaction,
};

pub const OwnedInvocationSpec = client.instructions_invoke.OwnedInvocationSpec;

pub fn buildInstructionInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) ![]u8 {
    return switch (family) {
        .instructions => try allocator.dupe(u8, invocation_spec_json),
        .program => try client.program_invoke.buildInstructionInvocationSpecJsonFromProgramInvokeSpec(
            allocator,
            invocation_spec_json,
        ),
        .anchor_idl => try client.anchor_idl_invoke.buildInstructionInvocationSpecJsonFromAnchorIdlInvokeSpec(
            allocator,
            invocation_spec_json,
        ),
    };
}

pub fn buildOwnedInvocationSpecFromInvocationSpecJson(
    allocator: Allocator,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
) !OwnedInvocationSpec {
    if (family == .instructions) {
        return try client.instructions_invoke.buildOwnedInvocationSpecFromJson(
            allocator,
            invocation_spec_json,
        );
    }

    const instruction_spec_json = try buildInstructionInvocationSpecJson(
        allocator,
        family,
        invocation_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    return try client.instructions_invoke.buildOwnedInvocationSpecFromJson(
        allocator,
        instruction_spec_json,
    );
}

pub fn sendInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    confirm: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    send_transaction_options: anytype,
    confirm_commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    if (confirm) {
        return sendAndConfirmInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
            .blockhash_commitment = blockhash_commitment,
            .send_transaction_options = send_transaction_options,
            .commitment = confirm_commitment,
            .search_transaction_history = search_transaction_history,
            .timeout_ms = timeout_ms,
            .poll_interval_ms = poll_interval_ms,
        });
    }
    return sendTransactionFromInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
        .blockhash_commitment = blockhash_commitment,
        .send_transaction_options = send_transaction_options,
    });
}

pub fn simulateInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    simulate_options: ?client.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return simulateTransactionFromInvocationSpecJson(allocator, rpc, family, versioned, invocation_spec_json, .{
        .blockhash_commitment = blockhash_commitment,
        .simulate_options = simulate_options,
    });
}

pub fn sendTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
        .program => if (versioned)
            client.program_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.program_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            })
        else
            client.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
            }),
    };
}

pub fn sendAndConfirmInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .program => if (versioned)
            client.program_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.program_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
    };
}

pub fn simulateTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SimulateInvocationSpecOptions,
) !client.SimulatedTransaction {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
        .program => if (versioned)
            client.program_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.program_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            })
        else
            client.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .simulate_options = options.simulate_options,
            }),
    };
}

pub fn sendAndConfirmInvocationSpecJsonWithSpinner(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    send_transaction_options: ?client.SendTransactionOptions,
    confirm_commitment: ?client.Commitment,
    search_transaction_history: bool,
    timeout_ms: u64,
    poll_interval_ms: u64,
) ![]const u8 {
    return sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{
            .blockhash_commitment = blockhash_commitment,
            .send_transaction_options = send_transaction_options,
            .commitment = confirm_commitment,
            .search_transaction_history = search_transaction_history,
            .timeout_ms = timeout_ms,
            .poll_interval_ms = poll_interval_ms,
        },
    );
}

pub fn sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: SendAndConfirmInvocationSpecOptions,
) ![]const u8 {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.instructions_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .program => if (versioned)
            client.program_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.program_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.sendAndConfirmVersionedTransactionWithSpinnerFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionWithSpinnerFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
                .send_transaction_options = options.send_transaction_options,
                .commitment = options.commitment,
                .search_transaction_history = options.search_transaction_history,
                .timeout_ms = options.timeout_ms,
                .poll_interval_ms = options.poll_interval_ms,
            }),
    };
}

pub fn getFeeForMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    commitment: ?client.Commitment,
) !client.FeeForMessage {
    return getFeeForInvocationSpecJson(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{
            .blockhash_commitment = blockhash_commitment,
            .commitment = commitment,
        },
    );
}

pub fn getFeeForInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: GetFeeForInvocationSpecOptions,
) !client.FeeForMessage {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.instructions_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
        .program => if (versioned)
            client.program_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.program_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.getFeeForVersionedMessageFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            })
        else
            client.anchor_idl_invoke.getFeeForLegacyMessageFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = options.blockhash_commitment,
            }, .{
                .commitment = options.commitment,
            }),
    };
}

pub fn buildTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyTransactionBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedTransactionBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedLegacyMessage {
    return buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedLegacyMessage {
    return switch (family) {
        .instructions => client.instructions_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildOwnedLegacyMessageFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildLegacyMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyMessageBytesFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildLegacyMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildLegacyMessageBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildOwnedMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !OwnedInvocationMessage {
    return buildOwnedMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !OwnedInvocationMessage {
    return if (versioned)
        .{
            .versioned = try buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        }
    else
        .{
            .legacy = try buildOwnedLegacyMessageFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        };
}

pub fn buildMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return if (versioned)
        try buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        )
    else
        try buildLegacyMessageBase64FromInvocationSpecJsonWithOptions(
            allocator,
            rpc,
            family,
            invocation_spec_json,
            options,
        );
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedLegacyTransaction {
    return buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.SignedLegacyTransaction {
    return switch (family) {
        .instructions => client.instructions_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildSignedLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildSignedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !SignedInvocationTransaction {
    return buildSignedTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        versioned,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !SignedInvocationTransaction {
    return if (versioned)
        .{
            .versioned = try buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        }
    else
        .{
            .legacy = try buildSignedLegacyTransactionFromInvocationSpecJsonWithOptions(
                allocator,
                rpc,
                family,
                invocation_spec_json,
                options,
            ),
        };
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.OwnedVersionedMessageV0 {
    return buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildOwnedVersionedMessageFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.OwnedVersionedMessageV0 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildOwnedVersionedMessageFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedMessageBytesFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBytesFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedMessageBytesFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildVersionedMessageBase64FromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) ![]u8 {
    return buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) ![]u8 {
    return switch (family) {
        .instructions => client.instructions_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildVersionedMessageBase64FromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJson(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
) !sdk.SignedVersionedTransaction {
    return buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
        allocator,
        rpc,
        family,
        invocation_spec_json,
        .{ .blockhash_commitment = blockhash_commitment },
    );
}

pub fn buildSignedVersionedTransactionFromInvocationSpecJsonWithOptions(
    allocator: Allocator,
    rpc: anytype,
    family: InvokeFamily,
    invocation_spec_json: []const u8,
    options: BuildInvocationSpecOptions,
) !sdk.SignedVersionedTransaction {
    return switch (family) {
        .instructions => client.instructions_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, .{
            .instruction_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .program => client.program_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, .{
            .program_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
        .anchor_idl => client.anchor_idl_invoke.buildSignedVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
            .anchor_idl_invocation_spec_json = invocation_spec_json,
            .blockhash_commitment = options.blockhash_commitment,
        }),
    };
}

fn allocMinimalInstructionsInvocationSpecJson(
    allocator: Allocator,
    payer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
}

fn allocMinimalProgramInvocationSpecJson(
    allocator: Allocator,
    payer_fill: u8,
    program_fill: u8,
    blockhash_fill: u8,
) ![]u8 {
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{payer_fill} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{program_fill} ** 32);
    const recent_blockhash_bytes = [_]u8{blockhash_fill} ** 32;

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try sdk.encodeBase58(allocator, &recent_blockhash_bytes);
    defer allocator.free(recent_blockhash_base58);

    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "program_id":"{s}",
        \\  "accounts":[{{"pubkey":"{s}","isSigner":true,"isWritable":false}}],
        \\  "dataBytes":[9,8,7]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
            program_id_base58,
        },
    );
}

test "invoke.buildInstructionInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 41, 42, 43);
    defer allocator.free(program_spec_json);

    const instruction_spec_json = try buildInstructionInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer allocator.free(instruction_spec_json);

    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"instructions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"program_id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, instruction_spec_json, "\"payer_secret_key\"") != null);
}

test "invoke.buildOwnedInvocationSpecFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const program_spec_json = try allocMinimalProgramInvocationSpecJson(allocator, 51, 52, 53);
    defer allocator.free(program_spec_json);

    var owned = try buildOwnedInvocationSpecFromInvocationSpecJson(
        allocator,
        .program,
        program_spec_json,
    );
    defer owned.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), owned.instructions.len);
    try std.testing.expectEqual(@as(usize, 0), owned.additional_signers.len);
    try std.testing.expectEqual(@as(usize, 0), owned.address_lookup_tables.len);
    try std.testing.expectEqual(@as(usize, 1), owned.instructions[0].accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 9, 8, 7 }, owned.instructions[0].data);
}

test "invoke.buildLegacyMessageBytesFromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 11, 12, 13);
    defer allocator.free(spec_json);

    const expected = try buildMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{ .blockhash_commitment = .processed },
    );
    defer allocator.free(expected);

    const actual = try buildLegacyMessageBytesFromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .processed },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 21, 22, 23);
    defer allocator.free(spec_json);

    const expected = try buildTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        false,
        spec_json,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(expected);

    const actual = try buildLegacyTransactionBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .confirmed },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildVersionedMessageBase64FromInvocationSpecJsonWithOptions matches generic builder" {
    const allocator = std.testing.allocator;
    const DummyRpc = struct {};

    const spec_json = try allocMinimalInstructionsInvocationSpecJson(allocator, 31, 32, 33);
    defer allocator.free(spec_json);

    const expected = try buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        true,
        spec_json,
        .{ .blockhash_commitment = .finalized },
    );
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        DummyRpc{},
        .instructions,
        spec_json,
        .{ .blockhash_commitment = .finalized },
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.sendAndConfirmInvocationSpecJsonWithSpinner dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{96} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{97} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{98} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{99} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[7]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_signer_count: usize = 0,
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,
        captured_timeout_ms: u64 = 0,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            self.captured_signer_count = signers_arg.len;
            self.captured_query = options_arg.?.blockhash_query.?;
            self.captured_nonce_authority = options_arg.?.nonce_authority.?;
            self.captured_commitment = options_arg.?.commitment.?;
            self.captured_timeout_ms = options_arg.?.timeout_ms;
            return try self.allocator.dupe(u8, "sig-spec-legacy-spinner");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmInvocationSpecJsonWithSpinner(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .confirmed,
        null,
        .finalized,
        false,
        777,
        10,
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spec-legacy-spinner", signature);
    try std.testing.expectEqual(@as(usize, 2), rpc.captured_signer_count);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .confirmed } },
        rpc.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, rpc.captured_nonce_authority.?);
    try std.testing.expectEqual(.finalized, rpc.captured_commitment.?);
    try std.testing.expectEqual(@as(u64, 777), rpc.captured_timeout_ms);
}

test "invoke.getFeeForMessageFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        captured_query: ?rpc_types.BlockhashQuery = null,
        captured_nonce_authority: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn getFeeForLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            options: ?rpc_types.LegacyInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer;
            _ = instructions;
            self.captured_query = options.?.blockhash_query.?;
            self.captured_nonce_authority = options.?.nonce_authority.?;
            self.captured_commitment = commitment;
            return .{ .value = 2468 };
        }
    };

    var mock = MockLegacyInvocationFeeClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{161} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes(.{162} ** 32);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{163} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account = sdk.Pubkey.fromBytes(.{164} ** 32);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7],
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
        },
    );
    defer allocator.free(spec_json);

    const fee = try getFeeForMessageFromInvocationSpecJson(
        allocator,
        &mock,
        .program,
        false,
        spec_json,
        .finalized,
        .confirmed,
    );

    try std.testing.expectEqual(@as(?u64, 2468), fee.value);
    try std.testing.expectEqualDeep(
        rpc_types.BlockhashQuery{ .nonce_account = .{ .pubkey = nonce_account, .commitment = .finalized } },
        mock.captured_query.?,
    );
    try std.testing.expectEqual(nonce_authority_raw.public_key, mock.captured_nonce_authority.?);
    try std.testing.expectEqual(.confirmed, mock.captured_commitment.?);
}

test "invoke.buildTransactionBase64FromInvocationSpecJson dispatches instructions versioned family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{171} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{172} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{173} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedTransactionBase64FromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildTransactionBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        true,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildLegacyMessageBase64FromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{181} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{182} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{183} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildLegacyMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildVersionedMessageBytesFromInvocationSpecJson dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{184} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{185} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{186} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{187} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{188} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[4,5,6]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBytesFromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildVersionedMessageBase64FromInvocationSpecJson dispatches anchor family" {
    const allocator = std.testing.allocator;
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
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{189} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{190} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{191} ** 32);
    const recent_blockhash = [_]u8{0xD4} ** 32;
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
            idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    var dummy = try client.RpcClient.newMock(allocator, &.{});
    defer dummy.deinit();
    const expected = try client.anchor_idl_invoke.buildVersionedMessageBase64FromInvocationSpecJson(
        &dummy,
        allocator,
        .{ .anchor_idl_invocation_spec_json = spec_json },
    );
    defer allocator.free(expected);

    const actual = try buildVersionedMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .anchor_idl,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildMessageBase64FromInvocationSpecJson dispatches program family generically" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{192} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{193} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{194} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBase64FromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "invoke.buildMessageBytesFromInvocationSpecJson dispatches instructions family generically" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{195} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{196} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{197} ** 32);
    const lookup_table_key = sdk.Pubkey.fromBytes(.{198} ** 32);
    const lookup_table_address = sdk.Pubkey.fromBytes(.{199} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);
    const lookup_table_key_base58 = try lookup_table_key.toBase58(allocator);
    defer allocator.free(lookup_table_key_base58);
    const lookup_table_address_base58 = try lookup_table_address.toBase58(allocator);
    defer allocator.free(lookup_table_address_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "recent_blockhash":"{s}",
        \\  "address_lookup_tables":[{{"account_key":"{s}","addresses":["{s}"]}}],
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[4,5,6]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            recent_blockhash_base58,
            lookup_table_key_base58,
            lookup_table_address_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.instructions_invoke.buildVersionedMessageBytesFromInvocationSpecJson(&dummy, .{
        .instruction_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBytesFromInvocationSpecJson(
        allocator,
        &dummy,
        .instructions,
        true,
        spec_json,
        null,
    );
    defer allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "invoke.buildOwnedMessageFromInvocationSpecJson returns typed union" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{200} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{201} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{202} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    var owned = try buildOwnedMessageFromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );
    defer owned.deinit(allocator);

    switch (owned) {
        .legacy => {},
        .versioned => return error.UnexpectedResult,
    }
}

test "invoke.buildSignedTransactionFromInvocationSpecJson returns typed union" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{203} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{204} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{205} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const signed = try buildSignedTransactionFromInvocationSpecJson(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        null,
    );

    switch (signed) {
        .legacy => {},
        .versioned => return error.UnexpectedResult,
    }
}

test "invoke.sendTransactionFromInvocationSpecJson dispatches program family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{206} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{207} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_program_id: ?sdk.Pubkey = null,
        captured_skip_preflight: bool = false,

        pub fn sendLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.SendLegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer;
            _ = signers;
            self.captured_program_id = instructions[0].program_id;
            self.captured_skip_preflight = options.?.send_transaction_options.?.skip_preflight;
            return "invoke-program-send";
        }
    };

    var rpc = MockRpc{};
    const signature = try sendTransactionFromInvocationSpecJson(
        allocator,
        &rpc,
        .program,
        false,
        spec_json,
        .{ .send_transaction_options = .{ .skip_preflight = true } },
    );

    try std.testing.expectEqualStrings("invoke-program-send", signature);
    try std.testing.expect(rpc.captured_program_id.?.eql(program_id));
    try std.testing.expect(rpc.captured_skip_preflight);
}

test "invoke.sendAndConfirmInvocationSpecJson dispatches anchor family" {
    const allocator = std.testing.allocator;
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
    const payer_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{208} ** 32);
    const authority_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{209} ** 32);
    const target_raw = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic([_]u8{210} ** 32);
    const target = client.Pubkey.fromBytes(target_raw.public_key.toBytes());
    const payer_keypair = try client.Keypair.fromSecretKeyBytes(payer_raw.secret_key.toBytes());
    const authority = try client.Keypair.fromSecretKeyBytes(authority_raw.secret_key.toBytes());
    const payer_secret_key_base58 = try client.encodeBase58(allocator, &payer_keypair.secret_key);
    defer allocator.free(payer_secret_key_base58);
    const authority_secret_key_base58 = try client.encodeBase58(allocator, &authority.secret_key);
    defer allocator.free(authority_secret_key_base58);
    const target_base58 = try target.toBase58(allocator);
    defer allocator.free(target_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "default_signer_secret_key":"{s}",
        \\  "idl":{s},
        \\  "instruction_name":"setValue",
        \\  "args":{{"value":42}},
        \\  "account_bindings":{{"target":"{s}"}}
        \\}}
    ,
        .{
            payer_secret_key_base58,
            authority_secret_key_base58,
            idl_json,
            target_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_program_id: ?sdk.Pubkey = null,
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn sendAndConfirmLegacyInstructionsWithOptions(
            self: *@This(),
            payer_pubkey: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_pubkey;
            _ = signers;
            self.captured_program_id = instructions[0].program_id;
            self.captured_commitment = options.?.commitment.?;
            return "invoke-anchor-confirm";
        }
    };

    var rpc = MockRpc{};
    const signature = try sendAndConfirmInvocationSpecJson(
        allocator,
        &rpc,
        .anchor_idl,
        false,
        spec_json,
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqualStrings("invoke-anchor-confirm", signature);
    try std.testing.expect(rpc.captured_program_id != null);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, rpc.captured_commitment.?);
}

test "invoke.simulateTransactionFromInvocationSpecJson dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{211} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{212} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[1,2,3]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        captured_sig_verify: bool = false,

        pub fn simulateLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            signers: []const sdk.Keypair,
            options: ?rpc_types.LegacyInstructionsSimulationOptions,
        ) !rpc_types.SimulatedTransaction {
            _ = payer;
            _ = instructions;
            _ = signers;
            self.captured_sig_verify = options.?.simulate_transaction_options.?.sig_verify;
            return .{
                .context_slot = 1,
                .logs = null,
                .accounts = null,
                .units_consumed = null,
                .return_data = null,
                .inner_instructions = null,
                .replacement_blockhash = null,
                .err_json = null,
                .fee = null,
                .loaded_accounts_data_size = null,
            };
        }
    };

    var rpc = MockRpc{};
    _ = try simulateTransactionFromInvocationSpecJson(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .{ .simulate_options = .{ .sig_verify = true } },
    );

    try std.testing.expect(rpc.captured_sig_verify);
}

test "invoke.sendAndConfirmInvocationSpecJsonWithSpinnerOptions dispatches instructions family" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{213} ** 32);
    const nonce_authority_raw = try sdk.Keypair.fromSecretKeyBytes([_]u8{214} ** 32);
    const program_id = sdk.Pubkey.fromBytes([_]u8{215} ** 32);
    const nonce_account = sdk.Pubkey.fromBytes([_]u8{216} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const nonce_authority_secret_key = nonce_authority_raw.secret_key.toBytes();
    const nonce_authority_secret_key_base58 = try sdk.encodeBase58(allocator, &nonce_authority_secret_key);
    defer allocator.free(nonce_authority_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const nonce_account_base58 = try nonce_account.toBase58(allocator);
    defer allocator.free(nonce_account_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "nonce_account":"{s}",
        \\  "nonce_authority_secret_key":"{s}",
        \\  "instructions":[{{"program_id":"{s}","dataBytes":[7]}}]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            nonce_account_base58,
            nonce_authority_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const MockRpc = struct {
        allocator: Allocator,
        captured_timeout_ms: u64 = 0,

        fn sendAndConfirmLegacyInstructionsWithSpinnerAndOptions(
            self: *@This(),
            payer_arg: sdk.Pubkey,
            instructions_arg: []const sdk.Instruction,
            signers_arg: []const sdk.Keypair,
            options_arg: ?rpc_types.LegacyInstructionsOptions,
        ) ![]const u8 {
            _ = payer_arg;
            _ = instructions_arg;
            _ = signers_arg;
            self.captured_timeout_ms = options_arg.?.timeout_ms;
            return try self.allocator.dupe(u8, "sig-spinner-options");
        }
    };

    var rpc = MockRpc{ .allocator = allocator };
    const signature = try sendAndConfirmInvocationSpecJsonWithSpinnerOptions(
        allocator,
        &rpc,
        .instructions,
        false,
        spec_json,
        .{ .timeout_ms = 321 },
    );
    defer allocator.free(signature);

    try std.testing.expectEqualStrings("sig-spinner-options", signature);
    try std.testing.expectEqual(@as(u64, 321), rpc.captured_timeout_ms);
}

test "invoke.getFeeForInvocationSpecJson dispatches options form" {
    const allocator = std.testing.allocator;

    const MockLegacyInvocationFeeClient = struct {
        captured_commitment: ?rpc_types.Commitment = null,

        pub fn getFeeForLegacyInstructionsWithOptions(
            self: *@This(),
            payer: sdk.Pubkey,
            instructions: []const sdk.Instruction,
            options: ?rpc_types.LegacyInstructionsBuildOptions,
            commitment: ?rpc_types.Commitment,
        ) !rpc_types.FeeForMessage {
            _ = payer;
            _ = instructions;
            _ = options;
            self.captured_commitment = commitment;
            return .{ .value = 1357 };
        }
    };

    var mock = MockLegacyInvocationFeeClient{};
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{217} ** 32);
    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id = sdk.Pubkey.fromBytes(.{218} ** 32);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[9,8,7]
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
        },
    );
    defer allocator.free(spec_json);

    const fee = try getFeeForInvocationSpecJson(
        allocator,
        &mock,
        .program,
        false,
        spec_json,
        .{ .commitment = .confirmed },
    );

    try std.testing.expectEqual(@as(?u64, 1357), fee.value);
    try std.testing.expectEqual(rpc_types.Commitment.confirmed, mock.captured_commitment.?);
}

test "invoke.buildMessageBase64FromInvocationSpecJsonWithOptions dispatches options form" {
    const allocator = std.testing.allocator;
    const payer_raw = try sdk.Keypair.fromSecretKeyBytes(.{219} ** 32);
    const program_id = sdk.Pubkey.fromBytes(.{220} ** 32);
    const recent_blockhash = sdk.Hash.fromBytes(.{221} ** 32);

    const payer_secret_key = payer_raw.secret_key.toBytes();
    const payer_secret_key_base58 = try sdk.encodeBase58(allocator, &payer_secret_key);
    defer allocator.free(payer_secret_key_base58);
    const program_id_base58 = try program_id.toBase58(allocator);
    defer allocator.free(program_id_base58);
    const recent_blockhash_base58 = try recent_blockhash.toBase58(allocator);
    defer allocator.free(recent_blockhash_base58);

    const spec_json = try std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "payer_secret_key":"{s}",
        \\  "program_id":"{s}",
        \\  "dataBytes":[1,2,3],
        \\  "recent_blockhash":"{s}"
        \\}}
    ,
        .{
            payer_secret_key_base58,
            program_id_base58,
            recent_blockhash_base58,
        },
    );
    defer allocator.free(spec_json);

    const Dummy = struct { allocator: Allocator };
    var dummy = Dummy{ .allocator = allocator };
    const expected = try client.program_invoke.buildLegacyMessageBase64FromInvocationSpecJson(&dummy, .{
        .program_invocation_spec_json = spec_json,
    });
    defer allocator.free(expected);

    const actual = try buildMessageBase64FromInvocationSpecJsonWithOptions(
        allocator,
        &dummy,
        .program,
        false,
        spec_json,
        .{},
    );
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
