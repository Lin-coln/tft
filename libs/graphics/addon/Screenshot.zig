const std = @import("std");
const napi = @import("napi-zig");
const window = @import("window");
const Perf = @import("Perf.zig");

const Self = @This();

native: window.Screenshot,

pub fn init(window_id: u32) !Self {
    try window.ensure_initialized();
    return .{ .native = try window.Screenshot.init(window_id) };
}

pub fn deinit(self: *Self) void {
    self.native.deinit();
}

pub fn get_window_id(self: *const Self) u32 {
    return self.native.window_id;
}

pub fn screenshot(self: *Self, env: napi.Env) !napi.Val {
    const io = std.Io.Threaded.global_single_threaded.io();
    var perf = Perf.init("screenshot", io);
    defer perf.deinit();

    const buffer = try self.native.sample();
    defer buffer.release();
    perf.lap("sample");

    const allocator = env.allocator();
    const bytes = try window.encode_png(allocator, buffer);
    defer allocator.free(bytes);
    perf.lap("encode_png");

    const arr_buff = try env.createBuffer(bytes.len);
    @memcpy(arr_buff.data, bytes);
    perf.lap("memcpy");

    return arr_buff.val;
}
