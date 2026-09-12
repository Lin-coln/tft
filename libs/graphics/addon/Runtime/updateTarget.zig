const std = @import("std");
const cap = @import("capture");
const Self = @import("Self.zig");

const Capture = cap.Capture;
const Renderer = cap.Renderer;
const resolveTarget = @import("../target/resolveTarget.zig").resolveTarget;

pub fn updateTarget(self: *Self, window_id: u32) !void {
    if (self.window_id == window_id) return;

    const target = try resolveTarget(window_id);
    defer target.release();

    const capture = try Capture.init(.{
        .allocator = self.allocator,
        .target = target,
        .frame_interval_value = 1,
        .frame_interval_timescale = 60,
        .shows_cursor = false,
    });
    errdefer capture.deinit();

    const renderer = try Renderer.init(self.allocator, .{
        .ctx = self.stream_output,
        .capture = capture,
        .framerate = 60,
        .handle_output = @import("handleStreamOutput.zig").onReceivePacket,
    });
    errdefer renderer.deinit();

    if (self.renderer) |current| current.deinit();
    if (self.capture) |current| current.deinit();
    self.renderer = null;
    self.capture = null;
    self.window_id = null;
    self.queue.clear();

    self.capture = capture;
    self.renderer = renderer;
    self.window_id = window_id;
}
