const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const mtl = macos.Metal;
const RenderContext = @import("RenderContext.zig");
const Quad = @import("Quad.zig");

pub fn drawSource(ctx: *RenderContext, source: *Texture, center: @Vector(2, f32)) !void {
    const source_width = source.width();
    const source_height = source.height();
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ctx.encoder_ended) return error.RenderEncoderUnavailable;
    const encoder = ctx.render_encoder;
    const pipeline = try ctx.device.pipeline_pool.getByOptions(.{
        .vertexFunction = ctx.device.shader_draw.function(.vertex_quad),
        .fragmentFunction = ctx.device.shader_draw.function(.draw_source),
        .color = .{ .pixelFormat = mtl.MTLPixelFormatBGRA8Unorm },
    });

    const canvas: @Vector(2, f32) = .{ @floatFromInt(ctx.device.width), @floatFromInt(ctx.device.height) };
    const source_size: @Vector(2, f32) = .{ @floatFromInt(source_width), @floatFromInt(source_height) };
    const scale = @min(canvas[0] / source_size[0], canvas[1] / source_size[1]);
    const size = source_size * @as(@Vector(2, f32), @splat(scale));
    const quad: Quad = .{ .origin = center - size / @as(@Vector(2, f32), @splat(2)), .size = size, .canvas = canvas };

    encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    encoder.msgSend(void, "setFragmentTexture:atIndex:", .{ source.obj, @as(usize, 0) });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
}
