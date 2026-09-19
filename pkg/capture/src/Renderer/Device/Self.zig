const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const Allocator = std.mem.Allocator;
const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const mtl = macos.Metal;

const RenderState = @import("RenderState.zig");

const Self = @This();

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

allocator: Allocator,
device: objc.Object = undefined,
command_queue: objc.Object = undefined,
pipeline_background: objc.Object = undefined,
pipeline_source: objc.Object = undefined,
pixel_pool: cv.CVPixelBufferPoolRef = undefined,
texture_cache: cv.CVMetalTextureCacheRef = undefined,
render_state: *RenderState = undefined,

pub const drawBackground = @import("drawBackground.zig").drawBackground;
pub const drawSource = @import("drawSource.zig").drawSource;
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

    self.pipeline_background = try createPipeline(
        self.device,
        self.render_state.shader_draw.function(.vertex_quad),
        self.render_state.shader_draw.function(.draw_background),
    );
    errdefer self.pipeline_background.release();

    self.pipeline_source = try createPipeline(
        self.device,
        self.render_state.shader_draw.function(.vertex_quad),
        self.render_state.shader_draw.function(.draw_source),
    );
    errdefer self.pipeline_source.release();

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
    self.pipeline_source.release();
    self.pipeline_background.release();
    self.render_state.destroy();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}

fn createPipeline(device: objc.Object, vertex: objc.Object, fragment: objc.Object) !objc.Object {
    const desc = blk: {
        const value = objc.getClass("MTLRenderPipelineDescriptor").?.msgSend(objc.Object, "new", .{});
        if (value.value == null) return error.PipelineDescriptorCreationFailed;
        break :blk value;
    };
    defer desc.release();

    desc.setProperty("vertexFunction", vertex);
    desc.setProperty("fragmentFunction", fragment);
    const attachments = desc.getProperty(objc.Object, "colorAttachments");
    const color = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    color.setProperty("pixelFormat", mtl.MTLPixelFormatBGRA8Unorm);

    var pipeline_error: objc.c.id = null;
    const pipeline = blk: {
        const value = device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{ desc, &pipeline_error });
        if (value.value == null) return error.PipelineCreationFailed;
        break :blk value;
    };
    errdefer pipeline.release();
    return pipeline;
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
