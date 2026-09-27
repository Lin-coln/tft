const std = @import("std");
const macos = @import("macos");
const stream = @import("tft/stream");
const CaptureNode = @import("CaptureNode.zig");

const Allocator = std.mem.Allocator;

const mtl = macos.Metal;

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
source: *CaptureNode,
ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
encoder: *Encoder = undefined,
renderer: *Renderer = undefined,
shader_draw: *Shader = undefined,

pub fn init(
    allocator: Allocator,
    opts: struct {
        ctx: *anyopaque,
        source: *CaptureNode,
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
        .interval = .fromNanoseconds(std.time.ns_per_s / opts.framerate),
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

fn handleEncodedPacket(self: *Self, borrowed: *Packet) !void {
    self.handle_output(self.ctx, borrowed);
}

fn handleEncodeError(_: *Self, err: anyerror) void {
    @panic(@errorName(err));
}
