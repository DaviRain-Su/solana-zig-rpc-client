const std = @import("std");

pub fn sendRequest(self: anytype, method: []const u8, params_json: []const u8) ![]u8 {
    const request_body = try std.fmt.allocPrint(
        self.allocator,
        "{{\"jsonrpc\":\"2.0\",\"id\":{},\"method\":\"{s}\",\"params\":{s}}}",
        .{ self.request_id, method, params_json },
    );
    errdefer self.allocator.free(request_body);
    self.request_id +%= 1;

    var response_writer = std.io.Writer.Allocating.init(self.allocator);
    errdefer response_writer.deinit();

    const headers = [_]std.http.Header{
        .{ .name = "content-type", .value = "application/json" },
        .{ .name = "accept", .value = "application/json" },
    };

    var response: std.http.Client.FetchResult = undefined;
    var attempts: usize = 0;

    while (true) {
        attempts += 1;
        const request_start = std.time.milliTimestamp();

        response = self.http_client.fetch(.{
            .location = .{ .url = self.endpoint },
            .method = .POST,
            .payload = request_body,
            .extra_headers = &headers,
            .response_writer = &response_writer.writer,
        }) catch |err| switch (err) {
            error.HttpConnectionClosing,
            error.ConnectionResetByPeer,
            error.ReadFailed,
            => {
                response_writer.deinit();
                response_writer = std.io.Writer.Allocating.init(self.allocator);

                self.http_client.deinit();
                self.http_client = .{ .allocator = self.allocator };

                continue;
            },
            else => return err,
        };

        const elapsed_ms = std.time.milliTimestamp() - request_start;
        if (elapsed_ms > 0) {
            self.transport_stats.elapsed_time_ms += @intCast(@max(elapsed_ms, 0));
            if (response.status == .too_many_requests) {
                self.transport_stats.rate_limited_time_ms += @intCast(@max(elapsed_ms, 0));
            }
        }

        break;
    }

    self.transport_stats.request_count += attempts;

    self.allocator.free(request_body);

    if (response.status != .ok) {
        return switch (response.status) {
            .request_timeout => error.Timeout,
            else => error.HttpError,
        };
    }

    return try response_writer.toOwnedSlice();
}
