const std = @import("std");
const objc = @import("objc");
const RenderState = @import("RenderState.zig");

const Allocator = std.mem.Allocator;
const Self = @This();

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

allocator: Allocator,
device: objc.Object,
command_queue: objc.Object,
pipeline_draw: objc.Object,
render_state: *RenderState,

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    const device_id = MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable;
    const device = objc.Object.fromId(device_id).retain();
    errdefer device.release();

    const command_queue = device.getProperty(objc.Object, "newCommandQueue");
    if (command_queue.value == null) return error.CommandQueueCreationFailed;
    errdefer command_queue.release();

    const render_state = try RenderState.create(allocator, device, width, height);
    errdefer render_state.destroy();

    var pipeline_error: objc.c.id = null;
    const pipeline_draw = device.msgSend(objc.Object, "newComputePipelineStateWithFunction:error:", .{
        render_state.shader_draw.function(.draw_source), &pipeline_error,
    });
    if (pipeline_draw.value == null) return error.PipelineCreationFailed;
    errdefer pipeline_draw.release();

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .device = device,
        .command_queue = command_queue,
        .pipeline_draw = pipeline_draw,
        .render_state = render_state,
    };
    return self;
}

pub fn destroy(self: *Self) void {
    self.pipeline_draw.release();
    self.render_state.destroy();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}
