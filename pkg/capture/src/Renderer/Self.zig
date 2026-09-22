const std = @import("std");
const macos = @import("macos");
const Capture = @import("tft/capture").Capture;

const Allocator = std.mem.Allocator;

const cv = macos.CoreVideo;

const Device = @import("Device/Self.zig");
const Driver = @import("handleDriveLoop.zig").Driver;

const Self = @This();
const Encoder = @import("tft/stream").Encoder.Of(*Self);
const Packet = Encoder.Packet;

allocator: Allocator,
driver: *Driver,

capture: *Capture,

img_last: ?cv.CVImageBufferRef,
img_last_mutext: std.Io.Mutex,

device: *Device,

encoder: *Encoder,

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
        .device = undefined,
        .img_last = null,
        .img_last_mutext = .init,
        .encoder = undefined,
        .capture = opts.capture,
        .ctx = opts.ctx,
        .handle_output = opts.handle_output,
    };

    self.driver = try Driver.create(allocator, .{
        .ctx = self,
        .interval = .fromNanoseconds(std.time.ns_per_s / opts.framerate),
    });
    errdefer self.driver.destroy();

    self.encoder = block: {
        const Handler = struct {
            fn handleOutput(renderer: *Self, borrowed: *Packet) !void {
                renderer.handle_output(renderer.ctx, borrowed);
            }
            fn handleError(_: *Self, err: anyerror) void {
                @panic(@errorName(err));
            }
        };
        break :block try Encoder.create(allocator, .{
            .ctx = self,
            .capacity = 6,
            .handle_error = Handler.handleError,
            .handle_output = Handler.handleOutput,
        });
    };
    errdefer self.encoder.destroy();

    self.device = try Device.create(allocator, 1920, 1080);
    errdefer self.device.destroy();

    try self.encoder.configure(.{
        .width = 1920,
        .height = 1080,
        .framerate = @intCast(opts.framerate),
    });
    try self.encoder.start();
    try self.driver.start();

    return self;
}

pub fn deinit(self: *Self) void {
    self.driver.destroy();
    self.encoder.destroy();
    cv.CVBufferRelease(self.img_last);
    self.device.destroy();
    self.allocator.destroy(self);
}
