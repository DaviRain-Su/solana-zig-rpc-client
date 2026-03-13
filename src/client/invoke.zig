const std = @import("std");
const client = @import("../root.zig");

const Allocator = std.mem.Allocator;

pub const InvokeFamily = enum {
    instructions,
    program,
    anchor_idl,
};

pub fn sendInvocationSpecJson(
    allocator: Allocator,
    rpc: *client.RpcClient,
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
    return switch (family) {
        .instructions => if (versioned)
            if (confirm)
                client.instructions_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .instruction_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.instructions_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .instruction_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.instructions_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.instructions_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
        .program => if (versioned)
            if (confirm)
                client.program_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .program_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.program_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, .{
                    .program_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.program_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.program_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
        .anchor_idl => if (versioned)
            if (confirm)
                client.anchor_idl_invoke.sendAndConfirmVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                    .anchor_idl_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                    .commitment = confirm_commitment,
                    .search_transaction_history = search_transaction_history,
                    .timeout_ms = timeout_ms,
                    .poll_interval_ms = poll_interval_ms,
                })
            else
                client.anchor_idl_invoke.sendVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                    .anchor_idl_invocation_spec_json = invocation_spec_json,
                    .blockhash_commitment = blockhash_commitment,
                    .send_transaction_options = send_transaction_options,
                })
        else if (confirm)
            client.anchor_idl_invoke.sendAndConfirmLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
                .commitment = confirm_commitment,
                .search_transaction_history = search_transaction_history,
                .timeout_ms = timeout_ms,
                .poll_interval_ms = poll_interval_ms,
            })
        else
            client.anchor_idl_invoke.sendLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .send_transaction_options = send_transaction_options,
            }),
    };
}

pub fn simulateInvocationSpecJson(
    allocator: Allocator,
    rpc: *client.RpcClient,
    family: InvokeFamily,
    versioned: bool,
    invocation_spec_json: []const u8,
    blockhash_commitment: ?client.Commitment,
    simulate_options: ?client.SimulateTransactionOptions,
) !client.SimulatedTransaction {
    return switch (family) {
        .instructions => if (versioned)
            client.instructions_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.instructions_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .instruction_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
        .program => if (versioned)
            client.program_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.program_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, .{
                .program_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
        .anchor_idl => if (versioned)
            client.anchor_idl_invoke.simulateVersionedTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            })
        else
            client.anchor_idl_invoke.simulateLegacyTransactionFromInvocationSpecJson(rpc, allocator, .{
                .anchor_idl_invocation_spec_json = invocation_spec_json,
                .blockhash_commitment = blockhash_commitment,
                .simulate_options = simulate_options,
            }),
    };
}
