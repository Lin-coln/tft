const std = @import("std");
const cap = @import("capture");
const Self = @import("Self.zig");

const CaptureSource = cap.CaptureSource;
const Renderer = cap.Renderer;
const resolveTarget = @import("../target/resolveTarget.zig").resolveTarget;

pub fn updateTarget(self: *Self, window_id: u32) !void {
    if (self.window_id == window_id) return;

    const target = try resolveTarget(window_id);
    defer target.release();

    const source = try CaptureSource.create(self.allocator, .{
        .target = target,
        .frame_interval_value = 1,
        .frame_interval_timescale = 60,
        .shows_cursor = false,
    });
    errdefer source.destroy();

    const renderer = try Renderer.init(self.allocator, .{
        .ctx = self.stream_output,
        .source = source,
        .framerate = 60,
        .handle_output = @import("handleStreamOutput.zig").onReceivePacket,
    });
    errdefer renderer.deinit();

    if (self.renderer) |current| current.deinit();
    if (self.source) |current| current.destroy();
    self.renderer = null;
    self.source = null;
    self.window_id = null;
    self.queue.clear();

    self.source = source;
    self.renderer = renderer;
    self.window_id = window_id;
}
