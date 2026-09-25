const std = @import("std");
const objc = @import("objc");

const Allocator = std.mem.Allocator;

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

const PipelinePool = @import("tft/stream").Device.PipelinePool;

const Self = @This();
const Shader = @import("tft/stream").Device.Shader.Of(
    enum { vertex_quad, draw_background, draw_source },
    .{
        .vertex_quad = .vertex,
        .draw_background = .fragment,
        .draw_source = .fragment,
    },
);

allocator: Allocator,
device: objc.Object,
command_queue: objc.Object,
pipeline_pool: *PipelinePool,
shader_draw: *Shader,
width: usize,
height: usize,

pub const RenderContext = @import("RenderContext.zig");

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    if (width == 0 or height == 0) return error.InvalidDimensions;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .device = undefined,
        .command_queue = undefined,
        .pipeline_pool = undefined,
        .shader_draw = undefined,
        .width = width,
        .height = height,
    };

    self.device = objc.Object.fromId(MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable).retain();
    errdefer self.device.release();

    self.command_queue = blk: {
        const value = self.device.getProperty(objc.Object, "newCommandQueue");
        if (value.value == null) return error.CommandQueueCreationFailed;
        break :blk value;
    };
    errdefer self.command_queue.release();

    self.pipeline_pool = try PipelinePool.create(allocator, self.device);
    errdefer self.pipeline_pool.destroy();

    self.shader_draw = try Shader.create(allocator, self.device, @embedFile("draw.metal"));
    errdefer self.shader_draw.destroy();

    return self;
}

pub fn destroy(self: *Self) void {
    self.shader_draw.destroy();
    self.pipeline_pool.destroy();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}

pub fn createContext(self: *Self) !*RenderContext {
    return RenderContext.create(self);
}
