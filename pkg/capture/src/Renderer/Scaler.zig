const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const ios = macos.IOSurface;
const metal = macos.Metal;
const foundation = macos.Foundation;
const Self = @This();

const Params = extern struct { origin: @Vector(2, f32), size: @Vector(2, f32) };

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

const shader_source =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\
    \\struct Params { float2 origin; float2 size; };
    \\
    \\kernel void scale_centered(
    \\    texture2d<float, access::sample> source [[texture(0)]],
    \\    texture2d<float, access::write> output [[texture(1)]],
    \\    constant Params &params [[buffer(0)]],
    \\    uint2 position [[thread_position_in_grid]])
    \\{
    \\    if (position.x >= output.get_width() || position.y >= output.get_height()) return;
    \\    float2 point = float2(position) + 0.5;
    \\    float2 uv = (point - params.origin) / params.size;
    \\    if (any(uv < 0.0) || any(uv > 1.0)) {
    \\        output.write(float4(0.0, 0.0, 0.0, 1.0), position);
    \\        return;
    \\    }
    \\    constexpr sampler linear_sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    \\    output.write(source.sample(linear_sampler, uv), position);
    \\}
;

allocator: std.mem.Allocator,
device: objc.Object,
command_queue: objc.Object,
pipeline: objc.Object,
pixel_pool: cv.CVPixelBufferPoolRef,
texture_cache: cv.CVMetalTextureCacheRef,
width: usize,
height: usize,

pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !*Self {
    if (width == 0 or height == 0) return error.InvalidDimensions;

    const device_id = MTLCreateSystemDefaultDevice();
    if (device_id == null) return error.MetalUnavailable;
    const device = objc.Object.fromId(device_id).retain();
    errdefer device.release();

    const command_queue = device.getProperty(objc.Object, "newCommandQueue");
    if (command_queue.value == null) return error.CommandQueueCreationFailed;
    errdefer command_queue.release();

    const pipeline = try createPipeline(device);
    errdefer pipeline.release();

    const pixel_pool = try createPixelPool(width, height);
    errdefer cf.CFRelease(@ptrCast(pixel_pool));

    var cache_ref: ?cv.CVMetalTextureCacheRef = null;
    if (cv.CVMetalTextureCacheCreate(null, null, device.value.?, null, &cache_ref) != 0)
        return error.TextureCacheCreationFailed;
    const texture_cache = cache_ref orelse return error.TextureCacheCreationFailed;
    errdefer cf.CFRelease(@ptrCast(texture_cache));

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .device = device,
        .command_queue = command_queue,
        .pipeline = pipeline,
        .pixel_pool = pixel_pool,
        .texture_cache = texture_cache,
        .width = width,
        .height = height,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    cf.CFRelease(@ptrCast(self.texture_cache));
    cf.CFRelease(@ptrCast(self.pixel_pool));
    self.pipeline.release();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}

/// Renders synchronously and returns an owned image buffer.
pub fn render(self: *Self, source: ios.IOSurfaceRef) !cv.CVImageBufferRef {
    const source_width = ios.IOSurfaceGetWidth(source);
    const source_height = ios.IOSurfaceGetHeight(source);
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    var buffer_ref: ?cv.CVPixelBufferRef = null;
    if (cv.CVPixelBufferPoolCreatePixelBuffer(null, self.pixel_pool, &buffer_ref) != 0)
        return error.PixelBufferCreationFailed;
    const image_buffer = buffer_ref orelse return error.PixelBufferCreationFailed;
    errdefer cf.CFRelease(@ptrCast(image_buffer));

    var texture_ref: ?cv.CVMetalTextureRef = null;
    if (cv.CVMetalTextureCacheCreateTextureFromImage(
        null,
        self.texture_cache,
        image_buffer,
        null,
        metal.MTLPixelFormatBGRA8Unorm,
        self.width,
        self.height,
        0,
        &texture_ref,
    ) != 0) return error.TextureCreationFailed;
    const output_texture = texture_ref orelse return error.TextureCreationFailed;
    defer cf.CFRelease(@ptrCast(output_texture));
    const output_obj = cv.CVMetalTextureGetTexture(output_texture) orelse return error.TextureCreationFailed;

    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();
    const source_texture = try Texture.fromIOSurface(self.allocator, .{
        .device = self.device,
        .width = source_width,
        .height = source_height,
        .surface = source,
        .usage = metal.MTLTextureUsageShaderRead,
        .storage_mode = metal.MTLStorageModeShared,
    });
    defer source_texture.release();

    const output_width: f32 = @floatFromInt(self.width);
    const output_height: f32 = @floatFromInt(self.height);
    const source_width_f: f32 = @floatFromInt(source_width);
    const source_height_f: f32 = @floatFromInt(source_height);
    const scale = @min(output_width / source_width_f, output_height / source_height_f);
    const params: Params = .{
        .origin = .{
            (output_width - source_width_f * scale) / 2,
            (output_height - source_height_f * scale) / 2,
        },
        .size = .{ source_width_f * scale, source_height_f * scale },
    };

    const command_buffer = self.command_queue.getProperty(objc.Object, "commandBuffer");
    if (command_buffer.value == null) return error.CommandBufferCreationFailed;
    const encoder = command_buffer.getProperty(objc.Object, "computeCommandEncoder");
    if (encoder.value == null) return error.CommandEncoderCreationFailed;
    encoder.msgSend(void, "setComputePipelineState:", .{self.pipeline});
    encoder.msgSend(void, "setTexture:atIndex:", .{ source_texture.obj, @as(usize, 0) });
    encoder.msgSend(void, "setTexture:atIndex:", .{ output_obj, @as(usize, 1) });
    encoder.msgSend(void, "setBytes:length:atIndex:", .{
        &params,
        @as(usize, @sizeOf(Params)),
        @as(usize, 0),
    });
    encoder.msgSend(void, "dispatchThreads:threadsPerThreadgroup:", .{
        metal.MTLSize{ .width = self.width, .height = self.height, .depth = 1 },
        metal.MTLSize{ .width = 16, .height = 16, .depth = 1 },
    });
    encoder.msgSend(void, "endEncoding", .{});
    command_buffer.msgSend(void, "commit", .{});
    command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (command_buffer.getProperty(usize, "status") == 5) return error.RenderFailed;

    return image_buffer;
}

fn createPipeline(device: objc.Object) !objc.Object {
    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();
    const source = try string(shader_source);
    defer source.release();
    var compile_error: objc.c.id = null;
    const library = device.msgSend(
        objc.Object,
        "newLibraryWithSource:options:error:",
        .{ source, @as(objc.c.id, null), &compile_error },
    );
    if (library.value == null) return error.ShaderCompilationFailed;
    defer library.release();

    const name = try string("scale_centered");
    defer name.release();
    const function = library.msgSend(objc.Object, "newFunctionWithName:", .{name});
    if (function.value == null) return error.ShaderFunctionMissing;
    defer function.release();

    var pipeline_error: objc.c.id = null;
    const pipeline = device.msgSend(
        objc.Object,
        "newComputePipelineStateWithFunction:error:",
        .{ function, &pipeline_error },
    );
    if (pipeline.value == null) return error.PipelineCreationFailed;
    return pipeline;
}

fn createPixelPool(width: usize, height: usize) !cv.CVPixelBufferPoolRef {
    const surface_properties = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(surface_properties);

    const attributes = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(attributes);

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

    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferWidthKey, width_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferHeightKey, height_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferPixelFormatTypeKey, format_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferMetalCompatibilityKey, cf.kCFBooleanTrue);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferIOSurfacePropertiesKey, surface_properties);

    var pool_ref: ?cv.CVPixelBufferPoolRef = null;
    if (cv.CVPixelBufferPoolCreate(null, null, attributes, &pool_ref) != 0)
        return error.PixelBufferPoolCreationFailed;
    const pixel_pool = pool_ref orelse return error.PixelBufferPoolCreationFailed;
    errdefer cf.CFRelease(@ptrCast(pixel_pool));
    return pixel_pool;
}

fn string(value: []const u8) !objc.Object {
    const class = objc.getClass("NSString") orelse return error.FoundationUnavailable;
    const allocated = class.msgSend(objc.Object, "alloc", .{});
    const result = allocated.msgSend(
        objc.Object,
        "initWithBytes:length:encoding:",
        .{ value.ptr, value.len, foundation.NSUTF8StringEncoding },
    );
    if (result.value == null) return error.StringCreationFailed;
    return result;
}
