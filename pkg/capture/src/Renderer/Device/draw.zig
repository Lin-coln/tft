const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const mtl = macos.Metal;
const Params = extern struct { origin: @Vector(2, f32), size: @Vector(2, f32), background: @Vector(4, f32) };

const Self = @import("Self.zig");
const getCommandBuffer = @import("getCommandBuffer.zig").getCommandBuffer;

/// Encodes captured content into the persistent canvas texture.
pub fn draw(self: *Self, source: *Texture, center: @Vector(2, f32)) !void {
    const state = self.render_state;
    const target = state.target orelse return error.NoRenderTarget;
    const source_width = source.width();
    const source_height = source.height();
    if (source_width == 0 or source_height == 0) return error.InvalidSourceDimensions;

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const command_buffer = try getCommandBuffer(self);
    errdefer {
        state.command_buffer = null;
        command_buffer.release();
    }

    const output_width: f32 = @floatFromInt(state.width);
    const output_height: f32 = @floatFromInt(state.height);
    const source_width_f: f32 = @floatFromInt(source_width);
    const source_height_f: f32 = @floatFromInt(source_height);
    const scale = @min(output_width / source_width_f, output_height / source_height_f);
    const params: Params = .{
        .origin = center - @Vector(2, f32){ source_width_f * scale / 2, source_height_f * scale / 2 },
        .size = .{ source_width_f * scale, source_height_f * scale },
        .background = state.background,
    };

    const compute = command_buffer.getProperty(objc.Object, "computeCommandEncoder");
    if (compute.value == null) return error.CommandEncoderCreationFailed;
    compute.msgSend(void, "setComputePipelineState:", .{self.pipeline_draw});
    compute.msgSend(void, "setTexture:atIndex:", .{ source.obj, @as(usize, 0) });
    compute.msgSend(void, "setTexture:atIndex:", .{ target.obj, @as(usize, 1) });
    compute.msgSend(void, "setBytes:length:atIndex:", .{ &params, @as(usize, @sizeOf(Params)), @as(usize, 0) });
    compute.msgSend(void, "dispatchThreads:threadsPerThreadgroup:", .{
        mtl.MTLSize{ .width = state.width, .height = state.height, .depth = 1 },
        mtl.MTLSize{ .width = 16, .height = 16, .depth = 1 },
    });
    compute.msgSend(void, "endEncoding", .{});
}
