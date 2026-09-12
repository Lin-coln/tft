const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Surface = @import("Surface.zig");

const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const ios = macos.IOSurface;
const metal = macos.Metal;
const foundation = macos.Foundation;
const Self = @This();

const pool_capacity = 12;

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
slots: []*Surface,
next_slot: std.atomic.Value(usize),
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

    const slots = try allocator.alloc(*Surface, pool_capacity);
    errdefer allocator.free(slots);
    var initialized: usize = 0;
    errdefer for (slots[0..initialized]) |surface| surface.release();
    while (initialized < slots.len) : (initialized += 1) {
        slots[initialized] = try createSlot(allocator, device, width, height);
    }

    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator,
        .device = device,
        .command_queue = command_queue,
        .pipeline = pipeline,
        .slots = slots,
        .next_slot = .init(0),
        .width = width,
        .height = height,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.slots) |surface| {
        std.debug.assert(surface.ref_count.load(.acquire) == 1);
        surface.release();
    }
    self.allocator.free(self.slots);
    self.pipeline.release();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}

/// Renders synchronously and returns an owned reference to a fixed-size surface.
pub fn render(self: *Self, source: ios.IOSurfaceRef) !*Surface {
    const source_width = ios.IOSurfaceGetWidth(source);
    const source_height = ios.IOSurfaceGetHeight(source);
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    const surface = self.acquireSurface() orelse return error.SurfacePoolExhausted;
    errdefer surface.release();

    const pixel_format = switch (ios.IOSurfaceGetPixelFormat(source)) {
        cv.kCVPixelFormatType_32BGRA => metal.MTLPixelFormatBGRA8Unorm,
        cv.kCVPixelFormatType_ARGB2101010LEPacked => metal.MTLPixelFormatBGR10A2Unorm,
        else => return error.UnsupportedPixelFormat,
    };

    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();
    const source_texture = try createTexture(
        self.device,
        source,
        source_width,
        source_height,
        pixel_format,
        metal.MTLTextureUsageShaderRead,
    );
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
    encoder.msgSend(void, "setTexture:atIndex:", .{ source_texture, @as(usize, 0) });
    encoder.msgSend(void, "setTexture:atIndex:", .{ surface.texture, @as(usize, 1) });
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

    return surface;
}

fn acquireSurface(self: *Self) ?*Surface {
    const start = self.next_slot.fetchAdd(1, .monotonic);
    for (0..self.slots.len) |offset| {
        const surface = self.slots[(start + offset) % self.slots.len];
        if (surface.tryRetainAvailable()) return surface;
    }
    return null;
}

fn createSlot(
    allocator: std.mem.Allocator,
    device: objc.Object,
    width: usize,
    height: usize,
) !*Surface {
    const surface_ref = try createIOSurface(width, height);
    defer cf.CFRelease(@ptrCast(surface_ref));
    const texture = try createTexture(
        device,
        surface_ref,
        width,
        height,
        metal.MTLPixelFormatBGRA8Unorm,
        metal.MTLTextureUsageShaderWrite,
    );
    return Surface.create(allocator, surface_ref, texture);
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

fn createTexture(
    device: objc.Object,
    surface: ios.IOSurfaceRef,
    width: usize,
    height: usize,
    pixel_format: usize,
    usage: usize,
) !objc.Object {
    const descriptor_class = objc.getClass("MTLTextureDescriptor") orelse return error.MetalUnavailable;
    const descriptor = descriptor_class.msgSend(
        objc.Object,
        "texture2DDescriptorWithPixelFormat:width:height:mipmapped:",
        .{ pixel_format, width, height, false },
    );
    if (descriptor.value == null) return error.TextureDescriptorCreationFailed;
    descriptor.setProperty("usage", usage);
    const texture = device.msgSend(
        objc.Object,
        "newTextureWithDescriptor:iosurface:plane:",
        .{ descriptor, surface, @as(usize, 0) },
    );
    if (texture.value == null) return error.TextureCreationFailed;
    return texture;
}

fn createIOSurface(width: usize, height: usize) !ios.IOSurfaceRef {
    const properties = cf.CFDictionaryCreateMutable(null, 0, null, null) orelse
        return error.SurfacePropertyCreationFailed;
    defer cf.CFRelease(properties);
    const keys = [_]cf.CFStringRef{
        ios.kIOSurfaceWidth,
        ios.kIOSurfaceHeight,
        ios.kIOSurfaceBytesPerElement,
        ios.kIOSurfacePixelFormat,
    };
    const values = [_]i64{ @intCast(width), @intCast(height), 4, cv.kCVPixelFormatType_32BGRA };
    var numbers: [values.len]cf.CFNumberRef = undefined;
    var initialized: usize = 0;
    defer for (numbers[0..initialized]) |number| cf.CFRelease(number);
    for (keys, values, 0..) |key, value, index| {
        numbers[index] = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &value) orelse
            return error.SurfacePropertyCreationFailed;
        initialized += 1;
        cf.CFDictionarySetValue(properties, key, numbers[index]);
    }
    return ios.IOSurfaceCreate(properties) orelse error.SurfaceCreationFailed;
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
