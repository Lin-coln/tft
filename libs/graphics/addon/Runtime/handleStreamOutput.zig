const cap = @import("capture");
const Self = @import("Self.zig");

const Packet = cap.Encoder.Packet;
const StreamOutputContext = Self.StreamOutputContext;

pub fn onReceivePacket(ctx: *anyopaque, borrowed: *Packet) void {
    const stream_output: *StreamOutputContext = @ptrCast(@alignCast(ctx));
    stream_output.queue.push(borrowed) catch |err| @panic(@errorName(err));
    stream_output.thread.notify();
}

pub fn handleStreamOutput(stream_output: *StreamOutputContext) void {
    handleStreamOutputInner(stream_output) catch |err| @panic(@errorName(err));
}

fn handleStreamOutputInner(stream_output: *StreamOutputContext) !void {
    const packet = stream_output.queue.shift() orelse return;
    errdefer packet.release();

    const handle = stream_output.handle_stream_output orelse {
        packet.release();
        return;
    };
    try handle.call(.{ .packet = packet }, .non_blocking);
}
