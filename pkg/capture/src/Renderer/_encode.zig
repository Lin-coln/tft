const Self = @import("Self.zig");

pub const Encoder = @import("tft/stream").Encoder.Of(*Self);

pub fn createEncoder(renderer: *Self) !*Encoder {
    const block = struct {
        fn handleEncodeOutput(self: *Self, borrowed: *Encoder.Packet) !void {
            self.handle_output(self.ctx, borrowed);
        }
    };
    return try Encoder.create(renderer.allocator, .{
        .ctx = renderer,
        .capacity = 6,
        .handle_error = handleEncodeError,
        .handle_output = block.handleEncodeOutput,
    });
}

fn handleEncodeError(self: *Self, err: anyerror) void {
    _ = self;
    @panic(@errorName(err));
}
