const macos = @import("macos");
const objc = @import("objc");

const mtl = macos.Metal;
const Self = @import("Self.zig");
const Quad = @import("Quad.zig");
const getCommandBuffer = @import("getCommandBuffer.zig").getCommandBuffer;
const getPipelineByDesc = @import("getPipelineByDesc.zig").getPipelineByDesc;

pub fn drawBackground(self: *Self, color: @Vector(4, f32)) !void {
    const state = self.render_state;
    const target = state.target orelse return error.NoRenderTarget;

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const command_buffer = try getCommandBuffer(self);
    errdefer state.resetCommands();
    const pipeline = try getPipelineByDesc(self, state.desc_ppl_background);

    const attachments = state.desc_render_pass.getProperty(objc.Object, "colorAttachments");
    const attachment = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    attachment.setProperty("texture", target.obj);
    attachment.setProperty("loadAction", mtl.MTLLoadActionDontCare);
    attachment.setProperty("storeAction", mtl.MTLStoreActionStore);

    const encoder = blk: {
        const value = command_buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{state.desc_render_pass});
        if (value.value == null) return error.RenderCommandEncoderCreationFailed;
        break :blk value;
    };

    const canvas: @Vector(2, f32) = .{ @floatFromInt(state.width), @floatFromInt(state.height) };
    const quad: Quad = .{ .origin = .{ 0, 0 }, .size = canvas, .canvas = canvas };
    encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    encoder.msgSend(void, "setFragmentBytes:length:atIndex:", .{ &color, @as(usize, @sizeOf(@TypeOf(color))), @as(usize, 0) });
    encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
    encoder.msgSend(void, "endEncoding", .{});
}
