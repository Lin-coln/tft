const std = @import("std");
const macos = @import("macos");
const mtl = macos.Metal;

const Self = @import("Self.zig");

pub const Shader = @import("tft/stream").Device.Shader.Of(
    enum { vertex_quad, draw_source },
    .{
        .vertex_quad = .vertex,
        .draw_source = .fragment,
    },
);

const Frame = @import("tft/stream").Renderer.Frame;
const Context = @import("tft/stream").Renderer.Context;
pub const Renderer = @import("tft/stream").Renderer.Of(
    Self,
    handleRender,
    handleFrame,
);

fn handleRender(core: *Self, context: *Context) void {
    const Block = struct {
        fn draw(self: *Self, ctx: *Context) !void {
            const pipeline = try self.renderer.device.pipelines.getByOptions(.{
                .vertexFunction = self.shader_draw.function(.vertex_quad),
                .fragmentFunction = self.shader_draw.function(.draw_source),
                .color = .{ .pixelFormat = mtl.MTLPixelFormatBGRA8Unorm },
            });

            try self.source.draw(ctx, pipeline);
        }
    };
    Block.draw(core, context) catch |err| {
        std.log.err("render failed: {s}", .{@errorName(err)});
    };
}

fn handleFrame(self: *Self, frame: *Frame) void {
    self.encoder.post(frame) catch |err| {
        std.log.err("frame post failed: {s}", .{@errorName(err)});
        frame.destroy();
    };
}
