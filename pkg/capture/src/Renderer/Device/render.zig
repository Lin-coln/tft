const std = @import("std");
const macos = @import("macos");
const Texture = @import("tft/stream").Texture;

const cv = macos.CoreVideo;
const mtl = macos.Metal;

const RenderContext = @import("RenderContext.zig");

/// Finishes this render call and transfers the output pixel buffer to the caller.
pub fn finish(self: *RenderContext) !cv.CVImageBufferRef {
    const encoder = self.render_encoder orelse return error.NoDrawPending;
    encoder.msgSend(void, "endEncoding", .{});
    encoder.release();
    self.render_encoder = null;

    self.command_buffer.msgSend(void, "commit", .{});
    self.command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (self.command_buffer.getProperty(usize, "status") != 4) return error.RenderFailed;

    const output_buffer = self.output_buffer orelse unreachable;
    self.output_buffer = null;
    return output_buffer;
}

test "one render context owns one frame and shares its encoder across draws" {
    const Device = @import("Self.zig");
    const device = try Device.create(std.testing.allocator, 64, 64);
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

    const ctx = try RenderContext.create(device);
    defer ctx.destroy();
    const encoder = ctx.render_encoder.?;
    try device.drawBackground(ctx, .{ 0.5, 0.5, 0.5, 1.0 });
    try device.drawSource(ctx, source, .{ 32, 32 });
    try std.testing.expectEqual(encoder.value, ctx.render_encoder.?.value);

    const frame = try ctx.finish();
    defer cv.CVBufferRelease(frame);
    try std.testing.expect(ctx.render_encoder == null);
    try std.testing.expect(ctx.output_buffer == null);
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetWidth(frame));
    try std.testing.expectEqual(@as(usize, 64), cv.CVPixelBufferGetHeight(frame));
}
