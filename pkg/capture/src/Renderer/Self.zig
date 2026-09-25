const std = @import("std");
const macos = @import("macos");
const cf = macos.CoreFoundation;
const CaptureSource = @import("../CaptureSource.zig");

const Allocator = std.mem.Allocator;

const cv = macos.CoreVideo;

const Device = @import("Device/Self.zig");
const Driver = @import("handleDriveLoop.zig").Driver;

const Self = @This();
const Encoder = @import("tft/stream").Encoder.Of(*Self);
const Packet = Encoder.Packet;

allocator: Allocator,
driver: *Driver,

source: *CaptureSource,

img_last: ?cv.CVImageBufferRef,
img_last_mutext: std.Io.Mutex,

device: *Device,
pixel_pool: cv.CVPixelBufferPoolRef,
texture_cache: cv.CVMetalTextureCacheRef,

encoder: *Encoder,

ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,

pub fn init(
    allocator: Allocator,
    opts: struct {
        ctx: *anyopaque,
        source: *CaptureSource,
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
        .device = undefined,
        .pixel_pool = undefined,
        .texture_cache = undefined,
        .driver = undefined,
        .img_last = null,
        .img_last_mutext = .init,
        .encoder = undefined,
        .source = opts.source,
        .ctx = opts.ctx,
        .handle_output = opts.handle_output,
    };

    self.device = try Device.create(allocator, 1920, 1080);
    errdefer self.device.destroy();

    self.pixel_pool = try createPixelPool(self.device.width, self.device.height);
    errdefer cf.CFRelease(@ptrCast(self.pixel_pool));

    self.texture_cache = blk: {
        var cache_ref: ?cv.CVMetalTextureCacheRef = null;
        if (cv.CVMetalTextureCacheCreate(null, null, self.device.device.value.?, null, &cache_ref) != 0)
            return error.TextureCacheCreationFailed;
        break :blk cache_ref orelse return error.TextureCacheCreationFailed;
    };
    errdefer cf.CFRelease(@ptrCast(self.texture_cache));

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
    cf.CFRelease(@ptrCast(self.texture_cache));
    cf.CFRelease(@ptrCast(self.pixel_pool));
    self.device.destroy();
    self.allocator.destroy(self);
}

fn createPixelPool(width: usize, height: usize) !cv.CVPixelBufferPoolRef {
    const props = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(props);

    const attrs = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(attrs);

    const width_value: i64 = @intCast(width);
    const width_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &width_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(width_number));
    const height_value: i64 = @intCast(height);
    const height_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &height_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(height_number));
    const format_value: i64 = cv.kCVPixelFormatType_32BGRA;
    const format_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &format_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(format_number));

    cf.CFDictionarySetValue(attrs, cv.kCVPixelBufferWidthKey, width_number);
    cf.CFDictionarySetValue(attrs, cv.kCVPixelBufferHeightKey, height_number);
    cf.CFDictionarySetValue(attrs, cv.kCVPixelBufferPixelFormatTypeKey, format_number);
    cf.CFDictionarySetValue(attrs, cv.kCVPixelBufferMetalCompatibilityKey, cf.kCFBooleanTrue);
    cf.CFDictionarySetValue(attrs, cv.kCVPixelBufferIOSurfacePropertiesKey, props);

    var pool_ref: ?cv.CVPixelBufferPoolRef = null;
    if (cv.CVPixelBufferPoolCreate(null, null, attrs, &pool_ref) != 0)
        return error.PixelBufferPoolCreationFailed;
    const pixel_pool = pool_ref orelse return error.PixelBufferPoolCreationFailed;
    errdefer cf.CFRelease(@ptrCast(pixel_pool));
    return pixel_pool;
}
