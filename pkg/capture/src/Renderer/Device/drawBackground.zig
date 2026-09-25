const macos = @import("macos");
const objc = @import("objc");

const mtl = macos.Metal;
const Self = @import("Self.zig");
const RenderContext = @import("RenderContext.zig");
const Quad = @import("Quad.zig");

pub fn drawBackground(self: *Self, ctx: *RenderContext, color: @Vector(4, f32)) !void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ctx.encoder_ended) return error.RenderEncoderUnavailable;
    const encoder = ctx.render_encoder;
    const pipeline = try self.pipeline_pool.getByOptions(.{
        .vertexFunction = self.shader_draw.function(.vertex_quad),
        .fragmentFunction = self.shader_draw.function(.draw_background),
        .color = .{ .pixelFormat = mtl.MTLPixelFormatBGRA8Unorm },
    });

    const canvas: @Vector(2, f32) = .{ @floatFromInt(self.width), @floatFromInt(self.height) };
    const quad: Quad = .{ .origin = .{ 0, 0 }, .size = canvas, .canvas = canvas };
    encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    encoder.msgSend(void, "setFragmentBytes:length:atIndex:", .{ &color, @as(usize, @sizeOf(@TypeOf(color))), @as(usize, 0) });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
}
