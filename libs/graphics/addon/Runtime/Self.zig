const std = @import("std");
const napi = @import("napi-zig");
const cap = @import("capture");
const Queue = @import("Queue.zig");

const Capture = cap.Capture;
const Renderer = cap.Renderer;
const VideoIO = cap.VideoIO;
const Packet = cap.Encoder.Packet;
const ensureInitialized = @import("window").ensure_initialized;
const PngEncoder = @import("window").PngEncoder;

const Self = @This();
pub const StreamOutputFn = napi.ThreadsafeFn(StreamOutput);
pub const StreamOutputContext = struct {
    queue: *Queue,
    thread: *Thread,
    handle_stream_output: ?StreamOutputFn,
};
pub const Thread = @import("Thread.zig").Thread(StreamOutputContext);

pub const StreamOutput = struct {
    packet: *Packet,

    pub fn toJs(self: StreamOutput, env: napi.Env) !napi.Val {
        defer self.packet.release();

        const value = try env.createObject();
        const data = try env.createBuffer(self.packet.size);
        @memcpy(data.data, self.packet.data);

        try value.setNamedProperty(env, "data", data.val);
        try value.setNamedProperty(env, "size", try env.toJs(self.packet.size));
        try value.setNamedProperty(env, "pts", try env.toJs(self.packet.pts));
        try value.setNamedProperty(env, "duration", try env.toJs(self.packet.duration));
        try value.setNamedProperty(env, "timebaseNum", try env.toJs(self.packet.timebase_num));
        try value.setNamedProperty(env, "timebaseDen", try env.toJs(self.packet.timebase_den));
        try value.setNamedProperty(env, "frameCount", try env.toJs(self.packet.frame_count));
        try value.setNamedProperty(env, "keyframe", try env.toJs(self.packet.keyframe));
        return value;
    }
};

allocator: std.mem.Allocator,
png_encoder: PngEncoder,
queue: *Queue,
thread: *Thread,
stream_output: *StreamOutputContext,

window_id: ?u32,
capture: ?*Capture,
renderer: ?*Renderer,
io: ?*VideoIO,

pub fn init(
    env: napi.Env,
    handle_stream_output: ?napi.Callback,
) !Self {
    try ensureInitialized();
    const allocator = std.heap.smp_allocator;

    const png_encoder = try PngEncoder.init();
    errdefer png_encoder.deinit();

    const queue = try Queue.init(allocator);
    errdefer queue.deinit();

    const stream_output = try allocator.create(StreamOutputContext);
    errdefer allocator.destroy(stream_output);

    stream_output.* = .{
        .queue = queue,
        .thread = undefined,
        .handle_stream_output = if (handle_stream_output) |callback|
            try callback.threadsafe(env, "stream-output", StreamOutput)
        else
            null,
    };
    errdefer if (stream_output.handle_stream_output) |handle| handle.release() catch {};

    const thread = try Thread.init(allocator, .{
        .ctx = stream_output,
        .handle_run = @import("handleStreamOutput.zig").handleStreamOutput,
    });
    errdefer thread.deinit();
    stream_output.thread = thread;

    return .{
        .allocator = allocator,
        .png_encoder = png_encoder,
        .queue = queue,
        .thread = thread,
        .stream_output = stream_output,
        .window_id = null,
        .capture = null,
        .renderer = null,
        .io = null,
    };
}

pub fn deinit(self: *Self) void {
    self.deinitTarget();
    self.thread.deinit();
    self.queue.deinit();
    if (self.stream_output.handle_stream_output) |handle| handle.release() catch {};
    self.allocator.destroy(self.stream_output);
    self.png_encoder.deinit();
}

pub fn screenshot(self: *Self, env: napi.Env) !napi.Val {
    const capture = self.capture orelse return error.TargetUnavailable;
    const surface = capture.get_surface() orelse return error.SurfaceUnavailable;
    defer surface.deinit();

    const bytes = try self.png_encoder.encode(surface.ref);

    const arr_buff = try env.createBuffer(bytes.len);
    @memcpy(arr_buff.data, bytes);
    return arr_buff.val;
}

fn deinitTarget(self: *Self) void {
    if (self.renderer) |renderer| renderer.deinit();
    if (self.io) |io| io.deinit();
    if (self.capture) |capture| capture.deinit();
    self.renderer = null;
    self.io = null;
    self.capture = null;
    self.window_id = null;
}

pub const updateTarget = @import("updateTarget.zig").updateTarget;

pub fn getTarget(self: *const Self) ?u32 {
    return self.window_id;
}

pub const getStreamConfig = @import("getStreamConfig.zig").getStreamConfig;
