const std = @import("std");
const napi = @import("napi-zig");
const Perf = @import("Perf.zig");
// const InferSession = @import("InferSession.zig");

const Capture = @import("capture").Capture;
const ensure_initialized = @import("window").ensure_initialized;
const resolveTarget = @import("window").resolveTarget;
const PngEncoder = @import("window").PngEncoder;

const Self = @This();

window_id: u32,
png_encoder: PngEncoder,
capture: *Capture,
// session: InferSession,

pub fn init(window_id: u32) !Self {
    try ensure_initialized();
    const allocator = std.heap.smp_allocator;

    const target = try resolveTarget(window_id);
    defer target.release();

    const png_encoder = try PngEncoder.init();
    errdefer png_encoder.deinit();

    const capture = try Capture.init(.{
        .allocator = allocator,
        .target = target,
        .frame_interval_value = 1,
        .frame_interval_timescale = 60,
        .shows_cursor = false,
    });
    errdefer capture.deinit();

    // const session = try InferSession.init(.{ .allocator = allocator, .capture = capture });

    return .{
        .window_id = window_id,
        .png_encoder = png_encoder,
        .capture = capture,
        // .session = session,
    };
}

pub fn deinit(self: *Self) void {
    // self.session.deinit();
    self.capture.deinit();
    self.png_encoder.deinit();
}

pub fn get_window_id(self: *const Self) u32 {
    return self.window_id;
}

pub fn screenshot(self: *Self, env: napi.Env) !napi.Val {
    const io = std.Io.Threaded.global_single_threaded.io();
    var perf = Perf.init("screenshot", io);
    defer perf.deinit();

    const surface = self.capture.get_surface() orelse
        return error.SurfaceUnavailable;
    defer surface.deinit();
    perf.lap("get_surface");

    const bytes = try self.png_encoder.encode(surface.ref);
    perf.lap("encode_surface_png");

    const arr_buff = try env.createBuffer(bytes.len);
    @memcpy(arr_buff.data, bytes);
    perf.lap("memcpy");

    return arr_buff.val;
}
