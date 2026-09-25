const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const Allocator = std.mem.Allocator;
const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

const PipelinePool = @import("tft/stream").Device.PipelinePool;

const Self = @This();
const Shader = @import("tft/stream").Device.Shader.Of(
    enum { vertex_quad, draw_background, draw_source },
    .{
        .vertex_quad = .vertex,
        .draw_background = .fragment,
        .draw_source = .fragment,
    },
);

allocator: Allocator,
device: objc.Object,
command_queue: objc.Object,
pipeline_pool: *PipelinePool,
shader_draw: *Shader,
pixel_pool: cv.CVPixelBufferPoolRef,
texture_cache: cv.CVMetalTextureCacheRef,
width: usize,
height: usize,

pub const RenderContext = @import("RenderContext.zig");
pub const drawBackground = @import("drawBackground.zig").drawBackground;
pub const drawSource = @import("drawSource.zig").drawSource;

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    if (width == 0 or height == 0) return error.InvalidDimensions;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .device = undefined,
        .command_queue = undefined,
        .pipeline_pool = undefined,
        .shader_draw = undefined,
        .pixel_pool = undefined,
        .texture_cache = undefined,
        .width = width,
        .height = height,
    };

    self.device = objc.Object.fromId(MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable).retain();
    errdefer self.device.release();

    self.command_queue = blk: {
        const value = self.device.getProperty(objc.Object, "newCommandQueue");
        if (value.value == null) return error.CommandQueueCreationFailed;
        break :blk value;
    };
    errdefer self.command_queue.release();

    self.pipeline_pool = try PipelinePool.create(allocator, self.device);
    errdefer self.pipeline_pool.destroy();

    self.shader_draw = try Shader.create(allocator, self.device, @embedFile("draw.metal"));
    errdefer self.shader_draw.destroy();

    self.pixel_pool = try createPixelPool(width, height);
    errdefer cf.CFRelease(@ptrCast(self.pixel_pool));

    self.texture_cache = blk: {
        var cache_ref: ?cv.CVMetalTextureCacheRef = null;
        if (cv.CVMetalTextureCacheCreate(null, null, self.device.value.?, null, &cache_ref) != 0)
            return error.TextureCacheCreationFailed;
        break :blk cache_ref orelse return error.TextureCacheCreationFailed;
    };
    errdefer cf.CFRelease(@ptrCast(self.texture_cache));

    return self;
}

pub fn destroy(self: *Self) void {
    cf.CFRelease(@ptrCast(self.texture_cache));
    cf.CFRelease(@ptrCast(self.pixel_pool));
    self.shader_draw.destroy();
    self.pipeline_pool.destroy();
    self.command_queue.release();
    self.device.release();
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
