const std = @import("std");
const Self = @import("Self.zig");

const CaptureSource = @import("../CaptureSource/Self.zig");
const VideoCore = @import("../VideoCore/Self.zig");
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

    const video_core = try VideoCore.init(self.allocator, .{
        .ctx = self.stream_output,
        .source = source,
        .framerate = 60,
        .handle_output = @import("handleStreamOutput.zig").onReceivePacket,
    });
    errdefer video_core.deinit();

    if (self.video_core) |current| current.deinit();
    if (self.source) |current| current.destroy();
    self.video_core = null;
    self.source = null;
    self.window_id = null;
    self.queue.clear();

    self.source = source;
    self.video_core = video_core;
    self.window_id = window_id;
}
