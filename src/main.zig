const std = @import("std");
const client = @import("solana_client_zig");
const cli = @import("./cli.zig");
const commands = @import("./commands.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    var parsed = try cli.parseCliArgs(allocator, if (raw_args.len > 1) raw_args[1..] else &[_][]const u8{});
    defer parsed.deinit(allocator);

    var rpc = try client.RpcClient.init(allocator, parsed.rpc_url);
    defer rpc.deinit();

    try commands.runCommand(allocator, &rpc, &parsed);
}
