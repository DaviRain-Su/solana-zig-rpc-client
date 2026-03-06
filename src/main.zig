const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");
const commands = @import("./commands.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const exit_code = run(allocator) catch |err| printUnhandledError(err);

    _ = gpa.deinit();
    if (exit_code != 0) std.process.exit(exit_code);
}

fn run(allocator: std.mem.Allocator) !u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var parsed = cli.parseCliArgs(allocator, if (args.len > 1) args[1..] else &[_][]const u8{}) catch |err| switch (err) {
        error.InvalidCli => return printCliError("error: invalid arguments\n"),
        else => return err,
    };
    defer parsed.deinit(allocator);

    if (parsed.show_usage or !parsed.has_command) {
        std.debug.print("{s}", .{cli.usage_text});
        return 0;
    }

    var rpc = try client.RpcClient.init(allocator, parsed.rpc_url);
    defer rpc.deinit();

    commands.runCommand(allocator, &rpc, &parsed) catch |err| switch (err) {
        error.InvalidCli => return printCliError("error: invalid arguments\n"),
        error.AccountNotFound => return printError("error: account not found\n"),
        error.HttpError => return printError("error: request failed\n"),
        error.Timeout => return printError("error: request timed out\n"),
        error.RpcError => return printRpcError(&rpc),
        error.TransactionFailed => return printError("error: transaction failed\n"),
        error.TransactionNotConfirmed => return printError("error: transaction was not confirmed before timeout\n"),
        error.TransactionNotFound => return printError("error: transaction not found\n"),
        else => return printUnhandledError(err),
    };

    return 0;
}

fn printCliError(message: []const u8) u8 {
    std.debug.print("{s}\n{s}", .{ message, cli.usage_text });
    return 1;
}

fn printError(message: []const u8) u8 {
    std.debug.print("{s}", .{message});
    return 1;
}

fn printRpcError(rpc: *client.RpcClient) u8 {
    if (rpc.getLastError()) |last_error| {
        std.debug.print("rpc error {}: {s}\n", .{ last_error.code, last_error.message });
    } else {
        std.debug.print("rpc error\n", .{});
    }

    return 1;
}

fn printUnhandledError(err: anyerror) u8 {
    std.debug.print("error: {s}\n", .{@errorName(err)});
    return 1;
}
