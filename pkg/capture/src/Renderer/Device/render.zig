const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const mtl = macos.Metal;

const Self = @import("Self.zig");
const getCommandBuffer = @import("getCommandBuffer.zig").getCommandBuffer;

/// Copies the complete canvas into an owned encoder input buffer.
pub fn render(self: *Self) !cv.CVImageBufferRef {
    const state = self.render_state;
    const command_buffer = state.command_buffer orelse return error.NoDrawPending;
    defer state.resetCommands();
    const target = state.target orelse return error.NoRenderTarget;
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

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
        mtl.MTLPixelFormatBGRA8Unorm,
        state.width,
        state.height,
        0,
        &texture_ref,
    ) != 0) return error.TextureCreationFailed;
    const output_texture = texture_ref orelse return error.TextureCreationFailed;
    defer cf.CFRelease(@ptrCast(output_texture));
    const output_obj = cv.CVMetalTextureGetTexture(output_texture) orelse return error.TextureCreationFailed;

    const blit = command_buffer.getProperty(objc.Object, "blitCommandEncoder");
    if (blit.value == null) return error.BlitCommandEncoderCreationFailed;
    blit.msgSend(void, "copyFromTexture:toTexture:", .{ target.obj, output_obj });
    blit.msgSend(void, "endEncoding", .{});

    command_buffer.msgSend(void, "commit", .{});
    command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (command_buffer.getProperty(usize, "status") != 4) return error.RenderFailed;
    return image_buffer;
}

test "Renderer draws to canvas and copies it into an encoder buffer" {
    const device = try Self.create(std.testing.allocator, 64, 64);
    defer device.destroy();

    const source = try Texture.create(std.testing.allocator, .{
        .device = device.device,
        .width = 32,
        .height = 32,
        .pixel_format = mtl.MTLPixelFormatBGRA8Unorm,
        .usage = mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModePrivate,
    });
    defer source.release();

    try std.testing.expectEqual(@as(usize, 64), device.render_state.target.?.width());
    try std.testing.expectEqual(@as(usize, 64), device.render_state.target.?.height());
    try device.drawBackground(.{ 0.5, 0.5, 0.5, 1.0 });
    try device.drawSource(source, .{ 32, 32 });
    const command_buffer = device.render_state.command_buffer.?;
    try std.testing.expect(command_buffer.value == (try getCommandBuffer(device)).value);
    const frame = try device.render();
    defer cv.CVBufferRelease(frame);
    try std.testing.expect(device.render_state.command_buffer == null);
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetWidth(frame));
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetHeight(frame));
}
