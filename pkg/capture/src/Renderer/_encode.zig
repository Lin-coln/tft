const macos = @import("macos");

const Self = @import("Self.zig");
const FrameWorker = Self.FrameWorker;
const Frame = Self.Frame;
const Encoder = @import("../Encoder/Self.zig");
const Packet = Encoder.Packet;

const cm = macos.CoreMedia;

pub fn _init_encoder(self: *Self) !*Encoder {
    return try Encoder.init(self.allocator, .{
        .ctx = self,
        .handle_error = handleEncodeError,
        .handle_output = handleEncodeOutput,
    });
}

pub fn _init_worker(self: *Self) !*FrameWorker {
    return try FrameWorker.init(self.allocator, .{
        .ctx = self,
        .handle_execute = handleExecuteFrame,
    });
}

fn handleExecuteFrame(self: *Self, frame: *Frame) !void {
    self.encoder.encode(frame) catch |err| {
        handleEncodeError(self, err);
    };
}

fn handleEncodeError(ctx: *anyopaque, err: anyerror) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
    @panic(@errorName(err));
}

fn handleEncodeOutput(
    ctx: *anyopaque,
    borrowed: *Frame,
    sample_buffer: cm.CMSampleBufferRef,
) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const packet = try Packet.fromSampleBuffer(
        self.allocator,
        borrowed,
        sample_buffer,
    );
    defer packet.release();

    self.handle_output(self.ctx, packet);
}
