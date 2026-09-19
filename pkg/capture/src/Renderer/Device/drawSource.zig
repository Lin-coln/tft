const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const mtl = macos.Metal;
const Self = @import("Self.zig");
const Quad = @import("Quad.zig");
const getCommandBuffer = @import("getCommandBuffer.zig").getCommandBuffer;

pub fn drawSource(self: *Self, source: *Texture, center: @Vector(2, f32)) !void {
    const state = self.render_state;
    const target = state.target orelse return error.NoRenderTarget;
    const source_width = source.width();
    const source_height = source.height();
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const command_buffer = try getCommandBuffer(self);
    errdefer state.resetCommands();

    const desc = objc.getClass("MTLRenderPassDescriptor").?.msgSend(objc.Object, "renderPassDescriptor", .{});
    if (desc.value == null) return error.RenderPassDescriptorCreationFailed;
    const attachments = desc.getProperty(objc.Object, "colorAttachments");
    const attachment = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    attachment.setProperty("texture", target.obj);
    attachment.setProperty("loadAction", mtl.MTLLoadActionLoad);
    attachment.setProperty("storeAction", mtl.MTLStoreActionStore);

    const encoder = command_buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{desc});
    if (encoder.value == null) return error.RenderCommandEncoderCreationFailed;

    const canvas: @Vector(2, f32) = .{ @floatFromInt(state.width), @floatFromInt(state.height) };
    const source_size: @Vector(2, f32) = .{ @floatFromInt(source_width), @floatFromInt(source_height) };
    const scale = @min(canvas[0] / source_size[0], canvas[1] / source_size[1]);
    const size = source_size * @as(@Vector(2, f32), @splat(scale));
    const quad: Quad = .{ .origin = center - size / @as(@Vector(2, f32), @splat(2)), .size = size, .canvas = canvas };

    encoder.msgSend(void, "setRenderPipelineState:", .{self.pipeline_source});
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    encoder.msgSend(void, "setFragmentTexture:atIndex:", .{ source.obj, @as(usize, 0) });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
    encoder.msgSend(void, "endEncoding", .{});
}
