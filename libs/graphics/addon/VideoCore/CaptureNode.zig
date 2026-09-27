const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Capture = @import("tft/capture").Capture;
const Texture = @import("tft/stream").Texture;
const stream = @import("tft/stream");

const Allocator = std.mem.Allocator;
const ios = macos.IOSurface;
const mtl = macos.Metal;
const Context = stream.Renderer.Context;
const Quad = struct {
    origin: @Vector(2, f32),
    size: @Vector(2, f32),
    canvas: @Vector(2, f32),
};

const Self = @This();

allocator: Allocator,
capture: ?*Capture,

pub fn create(
    allocator: Allocator,
    opts: struct {
        target: objc.Object,
        frame_interval_value: i64,
        frame_interval_timescale: i32,
        shows_cursor: bool,
    },
) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .capture = undefined,
    };

    self.capture = try Capture.init(allocator, .{
        .target = opts.target,
        .frame_interval_value = opts.frame_interval_value,
        .frame_interval_timescale = opts.frame_interval_timescale,
        .shows_cursor = opts.shows_cursor,
    });
    errdefer self.capture.?.deinit();
    return self;
}

pub fn destroy(self: *Self) void {
    if (self.capture) |capture| capture.deinit();
    self.allocator.destroy(self);
}

pub fn getSurface(self: *Self) ?@import("tft/capture").Surface {
    const capture = self.capture orelse return null;
    return capture.get_surface();
}

pub fn draw(
    self: *Self,
    ctx: *Context,
    pipeline: objc.Object,
) !void {
    const surface = self.getSurface() orelse return;
    defer surface.deinit();

    const texture = try Texture.fromIOSurface(self.allocator, .{
        .device = ctx.device,
        .width = ios.IOSurfaceGetWidth(surface.ref),
        .height = ios.IOSurfaceGetHeight(surface.ref),
        .surface = surface.ref,
        .usage = mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModeShared,
    });
    defer texture.release();

    const canvas: @Vector(2, f32) = .{ @floatFromInt(ctx.width), @floatFromInt(ctx.height) };
    const source_size: @Vector(2, f32) = .{ @floatFromInt(texture.width()), @floatFromInt(texture.height()) };
    const scale = @min(canvas[0] / source_size[0], canvas[1] / source_size[1]);
    const size = source_size * @as(@Vector(2, f32), @splat(scale));
    const center = canvas / @as(@Vector(2, f32), @splat(2));
    const quad: Quad = .{
        .origin = center - size / @as(@Vector(2, f32), @splat(2)),
        .size = size,
        .canvas = canvas,
    };

    ctx.encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    ctx.encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    ctx.encoder.msgSend(void, "setFragmentTexture:atIndex:", .{ texture.obj, @as(usize, 0) });
    ctx.encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
}
