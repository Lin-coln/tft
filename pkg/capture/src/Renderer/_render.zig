const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;
const Device = @import("Device/Self.zig");

const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const mtl = macos.Metal;
const Params = extern struct { origin: @Vector(2, f32), size: @Vector(2, f32), background: @Vector(4, f32) };

/// Draws a texture onto the gray render target and produces an owned encoder input buffer.
pub fn render(device: *Device, source: *Texture) !cv.CVImageBufferRef {
    const state = device.render_state;
    const source_width = source.width();
    const source_height = source.height();
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();

    var buffer_ref: ?cv.CVPixelBufferRef = null;
    if (cv.CVPixelBufferPoolCreatePixelBuffer(null, device.pixel_pool, &buffer_ref) != 0)
        return error.PixelBufferCreationFailed;
    const image_buffer = buffer_ref orelse return error.PixelBufferCreationFailed;
    errdefer cf.CFRelease(@ptrCast(image_buffer));

    var texture_ref: ?cv.CVMetalTextureRef = null;
    if (cv.CVMetalTextureCacheCreateTextureFromImage(
        null,
        device.texture_cache,
        image_buffer,
        null,
        mtl.MTLPixelFormatBGRA8Unorm,
        state.width,
        state.height,
        0,
        &texture_ref,
    ) != 0) return error.TextureCreationFailed;
    const output_texture = texture_ref orelse return error.TextureCreationFailed;
    defer cf.CFRelease(@ptrCast(output_texture));
    const output_obj = cv.CVMetalTextureGetTexture(output_texture) orelse return error.TextureCreationFailed;

    const command_buffer = device.command_queue.getProperty(objc.Object, "commandBuffer");
    if (command_buffer.value == null) return error.CommandBufferCreationFailed;

    const output_width: f32 = @floatFromInt(state.width);
    const output_height: f32 = @floatFromInt(state.height);
    const source_width_f: f32 = @floatFromInt(source_width);
    const source_height_f: f32 = @floatFromInt(source_height);
    const scale = @min(output_width / source_width_f, output_height / source_height_f);
    const params: Params = .{
        .origin = .{
            (output_width - source_width_f * scale) / 2,
            (output_height - source_height_f * scale) / 2,
        },
        .size = .{ source_width_f * scale, source_height_f * scale },
        .background = state.background,
    };

    const draw = command_buffer.getProperty(objc.Object, "computeCommandEncoder");
    if (draw.value == null) return error.CommandEncoderCreationFailed;
    draw.msgSend(void, "setComputePipelineState:", .{device.pipeline_draw});
    draw.msgSend(void, "setTexture:atIndex:", .{ source.obj, @as(usize, 0) });
    draw.msgSend(void, "setTexture:atIndex:", .{ output_obj, @as(usize, 1) });
    draw.msgSend(void, "setBytes:length:atIndex:", .{ &params, @as(usize, @sizeOf(Params)), @as(usize, 0) });
    draw.msgSend(void, "dispatchThreads:threadsPerThreadgroup:", .{
        mtl.MTLSize{ .width = state.width, .height = state.height, .depth = 1 },
        mtl.MTLSize{ .width = 16, .height = 16, .depth = 1 },
    });
    draw.msgSend(void, "endEncoding", .{});

    command_buffer.msgSend(void, "commit", .{});
    command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (command_buffer.getProperty(usize, "status") == 5) return error.RenderFailed;
    return image_buffer;
}

test "Renderer draws a texture into an encoder buffer" {
    const device = try Device.create(std.testing.allocator, 64, 64);
    defer device.destroy();

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const desc = objc.getClass("MTLTextureDescriptor").?.msgSend(
        objc.Object,
        "texture2DDescriptorWithPixelFormat:width:height:mipmapped:",
        .{ mtl.MTLPixelFormatBGRA8Unorm, @as(usize, 32), @as(usize, 32), false },
    );
    try std.testing.expect(desc.value != null);
    desc.msgSend(void, "setUsage:", .{mtl.MTLTextureUsageShaderRead});
    const texture_obj = blk: {
        const value = device.device.msgSend(objc.Object, "newTextureWithDescriptor:", .{desc});
        if (value.value == null) return error.TextureCreationFailed;
        break :blk value;
    };
    defer texture_obj.release();

    var texture = Texture{
        .allocator = std.testing.allocator,
        .ref_count = .init(1),
        .obj = texture_obj,
    };
    const frame = try render(device, &texture);
    defer cv.CVBufferRelease(frame);
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetWidth(frame));
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetHeight(frame));
}
