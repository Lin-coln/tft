const std = @import("std");
const macos = @import("macos");
const Texture = @import("tft/stream").Texture;
const mtl = macos.Metal;

const RenderContext = @import("RenderContext.zig");

/// Submits this render and returns a texture borrowed from this context.
pub fn getBorrowedOuputTexture(self: *RenderContext) !*Texture {
    if (self.encoder_ended) return error.NoDrawPending;
    self.render_encoder.msgSend(void, "endEncoding", .{});
    self.encoder_ended = true;

    self.command_buffer.msgSend(void, "commit", .{});
    self.command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (self.command_buffer.getProperty(usize, "status") != 4) return error.RenderFailed;

    return self.output_texture;
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

    const ctx = try device.createContext();
    defer ctx.destroy();
    const encoder = ctx.render_encoder;
    try ctx.drawBackground(.{ 0.5, 0.5, 0.5, 1.0 });
    try ctx.drawSource(source, .{ 32, 32 });
    try std.testing.expectEqual(encoder.value, ctx.render_encoder.value);

    const output = try ctx.getBorrowedOuputTexture();
    try std.testing.expect(ctx.encoder_ended);
    try std.testing.expectEqual(ctx.output_texture, output);
    try std.testing.expectEqual(@as(usize, 64), output.width());
    try std.testing.expectEqual(@as(usize, 64), output.height());
}
