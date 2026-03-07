const std = @import("std");
const client = @import("solana_client_zig");

const Allocator = std.mem.Allocator;

pub const CommandTestSender = struct {
    sender: client.MockSender,

    pub fn init(allocator: Allocator) CommandTestSender {
        return .{ .sender = client.MockSender.init(allocator) };
    }

    pub fn deinit(self: *CommandTestSender) void {
        self.sender.deinit();
    }
};

pub fn commandCapturedRequest(context: *const CommandTestSender) []const u8 {
    const requests = context.sender.capturedRequests();
    return if (requests.len == 0) &.{} else requests[requests.len - 1].request_body;
}

pub fn commandCapturedRequestAt(context: *const CommandTestSender, index: usize) []const u8 {
    return context.sender.capturedRequests()[index].request_body;
}

pub fn commandCapturedRequestCount(context: *const CommandTestSender) usize {
    return context.sender.capturedRequests().len;
}
