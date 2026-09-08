const std = @import("std");
const cap = @import("capture");
const Self = @import("Self.zig");

const Capture = cap.Capture;
const Renderer = cap.Renderer;
const VideoIO = cap.VideoIO;
const resolveTarget = @import("window").resolveTarget;

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

    const io = try VideoIO.init(self.allocator, .{
        .ctx = self.stream_output,
        .handle_output = @import("handleStreamOutput.zig").onReceivePacket,
    });
    errdefer io.deinit();

    try io.encoder.configure(.{
        .width = 1920,
        .height = 1080,
        .framerate = 60,
    });

    const renderer = try Renderer.init(
        self.allocator,
        std.time.ns_per_s / 60,
        capture,
    );
    errdefer renderer.deinit();

    if (self.renderer) |current| current.deinit();
    if (self.io) |current| current.deinit();
    if (self.capture) |current| current.deinit();
    self.renderer = null;
    self.io = null;
    self.capture = null;
    self.window_id = null;
    self.queue.clear();

    try renderer.addOutputHandler(.{
        .ctx = io,
        .handle = VideoIO.onReceiveFrame,
    });

    self.capture = capture;
    self.io = io;
    self.renderer = renderer;
    self.window_id = window_id;
}
