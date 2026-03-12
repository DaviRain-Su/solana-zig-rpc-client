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

    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
    defer if (home_dir) |value| allocator.free(value);

    const solana_config_override = std.process.getEnvVarOwned(allocator, "SOLANA_CONFIG") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
    defer if (solana_config_override) |value| allocator.free(value);

    var solana_cli_config = try cli.loadDefaultSolanaCliConfig(allocator, .{
        .home_dir = home_dir,
        .config_path_override = solana_config_override,
    });
    defer solana_cli_config.deinit(allocator);

    cli.applySolanaCliConfigDefaults(&parsed, &solana_cli_config);

    if (parsed.show_usage or !parsed.has_command) {
        if (parsed.help_command) |command|
            try cli.printCommandUsageToFile(.stderr(), command)
        else
            try cli.printUsageToFile(.stderr());
        return 0;
    }

    var rpc = if (commands.toClientCommitment(parsed.commitment)) |commitment|
        try client.RpcClient.newWithCommitment(allocator, parsed.rpc_url, commitment)
    else
        try client.RpcClient.init(allocator, parsed.rpc_url);
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
        error.BlockhashExpired => return printError("error: transaction blockhash expired before confirmation\n"),
        else => return printUnhandledError(err),
    };

    return 0;
}

fn printCliError(message: []const u8) u8 {
    std.debug.print("{s}", .{message});
    cli.printUsageToFile(.stderr()) catch {};
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
