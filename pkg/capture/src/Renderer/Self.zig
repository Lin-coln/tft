const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const stream = @import("tft/stream");
const CaptureSource = @import("../CaptureSource.zig");
const Quad = struct {
    origin: @Vector(2, f32),
    size: @Vector(2, f32),
    canvas: @Vector(2, f32),
};

const Allocator = std.mem.Allocator;

const mtl = macos.Metal;
const Texture = stream.Texture;

const Self = @This();
const Encoder = stream.Encoder.Of(*Self);
const Shader = stream.Device.Shader.Of(
    enum { vertex_quad, draw_source },
    .{
        .vertex_quad = .vertex,
        .draw_source = .fragment,
    },
);
const Renderer = stream.Renderer.Of(Self, handleRender, handleFrame);
const Context = stream.Renderer.Context;
const Frame = stream.Renderer.Frame;
const Packet = Encoder.Packet;

allocator: Allocator,
source: *CaptureSource,
ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
encoder: *Encoder = undefined,
renderer: *Renderer = undefined,
shader_draw: *Shader = undefined,

pub fn init(
    allocator: Allocator,
    opts: struct {
        ctx: *anyopaque,
        source: *CaptureSource,
        framerate: u32,
        handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
    },
) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .source = opts.source,
        .ctx = opts.ctx,
        .handle_output = opts.handle_output,
    };

    self.encoder = try Encoder.create(allocator, .{
        .ctx = self,
        .capacity = 6,
        .handle_error = handleEncodeError,
        .handle_output = handleEncodedPacket,
    });
    errdefer self.encoder.destroy();

    try self.encoder.configure(.{
        .width = 1920,
        .height = 1080,
        .framerate = @intCast(opts.framerate),
    });
    try self.encoder.start();

    self.renderer = try Renderer.create(allocator, .{
        .ctx = self,
        .width = 1920,
        .height = 1080,
        .framerate = opts.framerate,
    });
    errdefer self.renderer.destroy();

    self.shader_draw = try Shader.create(allocator, self.renderer.device.device, @embedFile("draw.metal"));
    errdefer self.shader_draw.destroy();

    try self.renderer.driver.start();
    return self;
}

pub fn deinit(self: *Self) void {
    self.renderer.destroy();
    self.encoder.destroy();
    self.shader_draw.destroy();
    self.allocator.destroy(self);
}

fn handleRender(self: *Self, ctx: *Context) void {
    self.draw(ctx) catch |err| std.log.err("render failed: {s}", .{@errorName(err)});
}

fn draw(self: *Self, ctx: *Context) !void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const texture = (try self.source.getTexture(self.renderer.device.device)) orelse return;
    defer texture.release();

    try self.drawSource(ctx, texture);
}

fn drawSource(self: *Self, ctx: *Context, source: *Texture) !void {
    const canvas: @Vector(2, f32) = .{ @floatFromInt(self.renderer.width), @floatFromInt(self.renderer.height) };
    const source_size: @Vector(2, f32) = .{ @floatFromInt(source.width()), @floatFromInt(source.height()) };
    const scale = @min(canvas[0] / source_size[0], canvas[1] / source_size[1]);
    const size = source_size * @as(@Vector(2, f32), @splat(scale));
    const center = self.source.calcRect(canvas);
    const quad: Quad = .{ .origin = center - size / @as(@Vector(2, f32), @splat(2)), .size = size, .canvas = canvas };
    const pipeline = try self.renderer.device.piplines.getByOptions(.{
        .vertexFunction = self.shader_draw.function(.vertex_quad),
        .fragmentFunction = self.shader_draw.function(.draw_source),
        .color = .{ .pixelFormat = mtl.MTLPixelFormatBGRA8Unorm },
    });

    ctx.encoder.msgSend(void, "setRenderPipelineState:", .{pipeline});
    ctx.encoder.msgSend(void, "setVertexBytes:length:atIndex:", .{ &quad, @as(usize, @sizeOf(Quad)), @as(usize, 0) });
    ctx.encoder.msgSend(void, "setFragmentTexture:atIndex:", .{ source.obj, @as(usize, 0) });
    ctx.encoder.msgSend(void, "drawPrimitives:vertexStart:vertexCount:", .{ mtl.MTLPrimitiveTypeTriangleStrip, @as(usize, 0), @as(usize, 4) });
}

fn handleFrame(self: *Self, frame: *Frame) void {
    self.encoder.post(frame) catch |err| {
        std.log.err("frame post failed: {s}", .{@errorName(err)});
        frame.destroy();
    };
}

fn handleEncodedPacket(self: *Self, borrowed: *Packet) !void {
    self.handle_output(self.ctx, borrowed);
}

fn handleEncodeError(_: *Self, err: anyerror) void {
    @panic(@errorName(err));
}
