const std = @import("std");
const napi = @import("napi-zig");
const Perf = @import("Perf.zig");

const Capture = @import("window").Capture;
const ensure_initialized = @import("window").ensure_initialized;
const resolveTarget = @import("window").resolveTarget;
const retainCIContext = @import("window").retainCIContext;
const encodeSurfacePng = @import("window").encodeSurfacePng;

const Self = @This();

window_id: u32,
capture: *Capture,

pub fn init(window_id: u32) !Self {
    try ensure_initialized();
    const allocator = std.heap.smp_allocator;

    const target = try resolveTarget(window_id);
    defer target.release();

    const capture = try Capture.init(.{
        .allocator = allocator,
        .target = target,
        .frame_interval_value = 1,
        .frame_interval_timescale = 60,
        .shows_cursor = false,
    });

    return .{
        .window_id = window_id,
        .capture = capture,
    };
}

pub fn deinit(self: *Self) void {
    self.capture.deinit();
}

pub fn get_window_id(self: *const Self) u32 {
    return self.window_id;
}

pub fn screenshot(self: *Self, env: napi.Env) !napi.Val {
    const io = std.Io.Threaded.global_single_threaded.io();
    var perf = Perf.init("screenshot", io);
    defer perf.deinit();

    const surface = self.capture.take_surface() orelse
        return error.TakeSurfaceFailed;
    defer surface.deinit();
    perf.lap("take_surface");

    const ci_context = retainCIContext();
    defer ci_context.release();
    perf.lap("retainCIContext");

    const allocator = env.allocator();
    const bytes = try encodeSurfacePng(allocator, ci_context, surface.ref);
    defer allocator.free(bytes);
    perf.lap("encode_surface_png");

    const arr_buff = try env.createBuffer(bytes.len);
    @memcpy(arr_buff.data, bytes);
    perf.lap("memcpy");

    return arr_buff.val;
}
