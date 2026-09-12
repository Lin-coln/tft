const std = @import("std");
const Capture = @import("../Capture/Self.zig");

pub const Frame = @import("Frame.zig");
const Surface = @import("Surface.zig");
const Encoder = @import("../Encoder/Self.zig");
const Packet = Encoder.Packet;
const Scaler = @import("Scaler.zig");

const Self = @This();
const Driver = @import("Driver.zig").Driver(Self);
pub const FrameWorker = @import("FrameWorker.zig").FrameWorker(Self);

allocator: std.mem.Allocator,
driver: *Driver,

capture: *Capture,

frame_last: ?*Surface,
frame_last_mutex: std.Io.Mutex,

encode_worker: *FrameWorker,
encoder: *Encoder,
scaler: *Scaler,

ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,

pub const Options = struct {
    ctx: *anyopaque,
    capture: *Capture,
    framerate: u32,
    handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
};
pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
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
    self.driver = try .init(allocator, .{
        .ctx = self,
        .interval = .fromNanoseconds(std.time.ns_per_s / opts.framerate),
        .handle_loop = handleLoop,
    });
    errdefer self.driver.deinit();

    self.encoder = try @import("_encode.zig")._init_encoder(self);
    errdefer self.encoder.deinit();

    self.scaler = try .init(allocator, 1920, 1080);
    errdefer self.scaler.deinit();

    self.encode_worker = try @import("_encode.zig")._init_worker(self);
    errdefer self.encode_worker.deinit();

    try self.encoder.configure(.{
        .width = 1920,
        .height = 1080,
        .framerate = @intCast(opts.framerate),
    });
    try self.encode_worker.run();
    try self.driver.run();

    return self;
}

pub fn deinit(self: *Self) void {
    self.driver.deinit();
    self.encode_worker.deinit();
    self.encoder.deinit();
    if (self.frame_last) |surface| surface.release();
    self.scaler.deinit();
    self.allocator.destroy(self);
}

fn handleLoop(
    self: *Self,
    ts: std.Io.Clock.Timestamp,
) ?std.Io.Duration {
    const pts = ts.raw;

    // render frame
    var frame: ?*Frame = block: {
        const surface = self.capture.get_surface() orelse break :block null;
        defer surface.deinit();
        const rendered = self.scaler.render(surface.ref) catch break :block null;
        break :block Frame.create(self.allocator, rendered, pts, .zero) catch null;
    };

    // frame
    const duration = self.driver.calcDuration(ts);
    if (frame) |next| next.addDuration(duration);

    frame = block: {
        std.Io.Threaded.mutexLock(&self.frame_last_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.frame_last_mutex);

        const prev = self.frame_last;
        if (frame == null) {
            break :block if (prev) |surface|
                Frame.create(self.allocator, surface.retain(), pts, duration) catch null
            else
                null;
        }

        self.frame_last = frame.?.surface.retain();
        if (prev) |surface| surface.release();
        break :block frame;
    };

    // output
    if (frame) |next| {
        self.encode_worker.push(next);
        return duration;
    } else {
        return null;
    }
}
