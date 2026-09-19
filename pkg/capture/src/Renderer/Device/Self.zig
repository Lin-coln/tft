const std = @import("std");
const objc = @import("objc");
const RenderState = @import("RenderState.zig");

const Allocator = std.mem.Allocator;
const Self = @This();

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

allocator: Allocator,
device: objc.Object = undefined,
command_queue: objc.Object = undefined,
pipeline_draw: objc.Object = undefined,
render_state: *RenderState = undefined,

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator };

    self.device = objc.Object.fromId(MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable).retain();
    errdefer self.device.release();

    self.command_queue = blk: {
        const value = self.device.getProperty(objc.Object, "newCommandQueue");
        if (value.value == null) return error.CommandQueueCreationFailed;
        break :blk value;
    };
    errdefer self.command_queue.release();

    self.render_state = try RenderState.create(allocator, self.device, width, height);
    errdefer self.render_state.destroy();

    var pipeline_error: objc.c.id = null;
    self.pipeline_draw = blk: {
        const value = self.device.msgSend(objc.Object, "newComputePipelineStateWithFunction:error:", .{
            self.render_state.shader_draw.function(.draw_source), &pipeline_error,
        });
        if (value.value == null) return error.PipelineCreationFailed;
        break :blk value;
    };
    errdefer self.pipeline_draw.release();
    return self;
}

pub fn destroy(self: *Self) void {
    self.pipeline_draw.release();
    self.render_state.destroy();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}
