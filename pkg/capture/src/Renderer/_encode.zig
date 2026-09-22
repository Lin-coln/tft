const Self = @import("Self.zig");
const Frame = @import("tft/stream").Frame;

pub const Worker = @import("tft/pipeline").Worker.Of(*Self, *Frame);
pub const Encoder = @import("tft/stream").Encoder.Of(*Self);

pub fn createEncoder(renderer: *Self) !*Encoder {
    const block = struct {
        fn handleEncodeOutput(self: *Self, borrowed: *Encoder.Packet) !void {
            self.handle_output(self.ctx, borrowed);
        }
    };
    return try Encoder.create(renderer.allocator, .{
        .ctx = renderer,
        .handle_error = handleEncodeError,
        .handle_output = block.handleEncodeOutput,
    });
}

pub fn createWorker(renderer: *Self) !*Worker {
    const block = struct {
        fn handleExecuteFrame(self: *Self, frame: *Frame, flag: Worker.Flag) void {
            switch (flag) {
                .execute => self.encoder.encode(frame) catch |err| {
                    handleEncodeError(self, err);
                },
                .release => frame.destroy(),
            }
        }
        fn handleMerge(last: **Frame, frame: *Frame) !void {
            last.*.addDuration(frame.duration);
            frame.destroy();
        }
    };
    return try Worker.create(renderer.allocator, .{
        .ctx = renderer,
        .strategy = .{ .merge = .{
            .capacity = 6,
            .on_merge = block.handleMerge,
        } },
        .handle_loop = block.handleExecuteFrame,
    });
}

fn handleEncodeError(self: *Self, err: anyerror) void {
    _ = self;
    @panic(@errorName(err));
}
