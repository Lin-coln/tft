const macos = @import("macos");

const cm = macos.CoreMedia;

const Self = @import("Self.zig");
const Frame = Self.Frame;

pub const Worker = @import("tft/pipeline").Worker.Of(*Self, *Frame);
pub const Encoder = @import("tft/stream").Encoder.Of(*Self, Frame);
pub const Packet = @import("tft/stream").Packet;
pub const ResolveConfig = @import("tft/stream").ResolveConfig;

pub fn _init_encoder(self: *Self) !*Encoder {
    return try Encoder.init(self.allocator, .{
        .ctx = self,
        .handle_error = handleEncodeError,
        .handle_output = handleEncodeOutput,
    });
}

pub fn _init_worker(self: *Self) !*Worker {
    return try Worker.create(self.allocator, .{
        .ctx = self,
        .strategy = .{ .merge = .{ .capacity = 6, .on_merge = mergeFrames } },
        .handle_loop = handleExecuteFrame,
    });
}

fn mergeFrames(last: **Frame, frame: *Frame) !void {
    last.*.addDuration(frame.duration);
    frame.destroy();
}

fn handleExecuteFrame(self: *Self, frame: *Frame, flag: Worker.Flag) void {
    switch (flag) {
        .execute => self.encoder.encode(frame) catch |err| {
            handleEncodeError(self, err);
        },
        .release => frame.destroy(),
    }
}

fn handleEncodeError(self: *Self, err: anyerror) void {
    _ = self;
    @panic(@errorName(err));
}

fn handleEncodeOutput(
    self: *Self,
    borrowed: *Frame,
    sample_buffer: cm.CMSampleBufferRef,
) !void {
    const packet = try Packet.fromSampleBuffer(self.allocator, .{
        .pts = borrowed.pts,
        .duration = borrowed.duration,
        .sample_buffer = sample_buffer,
    });
    defer packet.release();

    self.handle_output(self.ctx, packet);
}
