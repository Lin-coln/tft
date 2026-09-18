const std = @import("std");
const Capture = @import("tft/capture").Capture;

const Allocator = std.mem.Allocator;

const cv = @import("macos").CoreVideo;
const Scaler = @import("Scaler.zig");
const Driver = @import("_driver.zig").Driver;
const _encode = @import("_encode.zig");

pub const Frame = @import("Frame.zig");
pub const Packet = _encode.Packet;

const Self = @This();

allocator: Allocator,
driver: *Driver,

capture: *Capture,

frame_last: ?cv.CVImageBufferRef,
frame_last_mutex: std.Io.Mutex,

encode_worker: *_encode.Worker,
encoder: *_encode.Encoder,
scaler: *Scaler,

ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,

pub fn init(
    allocator: Allocator,
    opts: struct {
        ctx: *anyopaque,
        capture: *Capture,
        framerate: u32,
        handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
    },
) !*Self {
    if (opts.framerate == 0 or opts.framerate > std.time.ns_per_s)
        return error.InvalidFramerate;

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .driver = undefined,
        .encode_worker = undefined,
        .encoder = undefined,
        .scaler = undefined,
        .frame_last = null,
        .frame_last_mutex = .init,
        .capture = opts.capture,
        .ctx = opts.ctx,
        .handle_output = opts.handle_output,
    };
    self.driver = try Driver.create(allocator, .{
        .ctx = self,
        .interval = .fromNanoseconds(std.time.ns_per_s / opts.framerate),
    });
    errdefer self.driver.destroy();

    self.encoder = try _encode.createEncoder(self);
    errdefer self.encoder.destroy();

    self.scaler = try .init(allocator, 1920, 1080);
    errdefer self.scaler.deinit();

    self.encode_worker = try _encode.createWorker(self);
    errdefer self.encode_worker.destroy();

    try self.encoder.configure(.{
        .width = 1920,
        .height = 1080,
        .framerate = @intCast(opts.framerate),
    });
    try self.encode_worker.start();
    try self.driver.start();

    return self;
}

pub fn deinit(self: *Self) void {
    self.driver.destroy();
    self.encode_worker.destroy();
    self.encoder.destroy();
    cv.CVBufferRelease(self.frame_last);
    self.scaler.deinit();
    self.allocator.destroy(self);
}
