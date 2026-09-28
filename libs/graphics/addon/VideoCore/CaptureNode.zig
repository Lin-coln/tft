const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Capture = @import("tft/capture").Capture;
const Texture = @import("tft/stream").Texture;
const Renderer = @import("tft/stream").Renderer;
const Surface = @import("tft/capture").Surface;

const Allocator = std.mem.Allocator;
const mtl = macos.Metal;
const Context = Renderer.Context;

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

pub fn getSurface(self: *Self) ?Surface {
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
        .surface = surface.ref,
        .usage = mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModeShared,
    });
    defer texture.release();

    const canvas_width: f32 = @floatFromInt(ctx.width);
    const canvas_height: f32 = @floatFromInt(ctx.height);
    const source_width: f32 = @floatFromInt(texture.width());
    const source_height: f32 = @floatFromInt(texture.height());
    const scale = @min(canvas_width / source_width, canvas_height / source_height);
    const width = source_width * scale / canvas_width;
    const height = source_height * scale / canvas_height;
    const transform: [4]@Vector(4, f32) = .{
        .{ width * 2, 0, 0, 0 },
        .{ 0, height * -2, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ -width, height, 0, 1 },
    };
    const transform_size: usize = @sizeOf(@TypeOf(transform));
    const transform_index: usize = 0;

    ctx.encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    ctx.encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &transform, transform_size, transform_index });
    ctx.encoder.msgSend(void, "setFragmentTexture:atIndex:", .{ texture.obj, @as(usize, 0) });
    ctx.encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
}
