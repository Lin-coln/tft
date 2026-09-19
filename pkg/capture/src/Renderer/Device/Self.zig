const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const Allocator = std.mem.Allocator;
const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;

const RenderState = @import("RenderState.zig");

const Self = @This();

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

allocator: Allocator,
device: objc.Object = undefined,
command_queue: objc.Object = undefined,
pipeline_draw: objc.Object = undefined,
pixel_pool: cv.CVPixelBufferPoolRef = undefined,
texture_cache: cv.CVMetalTextureCacheRef = undefined,
render_state: *RenderState = undefined,

pub const draw = @import("draw.zig").draw;
pub const render = @import("render.zig").render;

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator };

    self.device = objc.Object.fromId(MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable).retain();
    errdefer self.device.release();

    self.command_queue = blk: {
        const value = self.device.getProperty(objc.Object, "newCommandQueue");
        if (value.value == null) return error.CommandQueueCreationFailed;
        break :blk value;
    };
    errdefer self.command_queue.release();

    self.render_state = try RenderState.create(allocator, self.device, width, height);
    errdefer self.render_state.destroy();

    var pipeline_error: objc.c.id = null;
    self.pipeline_draw = blk: {
        const value = self.device.msgSend(objc.Object, "newComputePipelineStateWithFunction:error:", .{
            self.render_state.shader_draw.function(.draw_source), &pipeline_error,
        });
        if (value.value == null) return error.PipelineCreationFailed;
        break :blk value;
    };
    errdefer self.pipeline_draw.release();

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
    self.pipeline_draw.release();
    self.render_state.destroy();
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
