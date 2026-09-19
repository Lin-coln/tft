const std = @import("std");
const objc = @import("objc");
const RenderState = @import("RenderState.zig");
const foundation = @import("macos").Foundation;

const Allocator = std.mem.Allocator;
const Self = @This();

extern fn MTLCreateSystemDefaultDevice() callconv(.c) objc.c.id;

const shader_source =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\struct Params { float2 origin; float2 size; float4 background; };
    \\kernel void draw_source(
    \\    texture2d<float, access::sample> source [[texture(0)]],
    \\    texture2d<float, access::write> target [[texture(1)]],
    \\    constant Params &params [[buffer(0)]],
    \\    uint2 position [[thread_position_in_grid]])
    \\{
    \\    if (position.x >= target.get_width() || position.y >= target.get_height()) return;
    \\    float2 uv = (float2(position) + 0.5 - params.origin) / params.size;
    \\    if (any(uv < 0.0) || any(uv > 1.0)) {
    \\        target.write(params.background, position);
    \\        return;
    \\    }
    \\    constexpr sampler linear_sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    \\    target.write(source.sample(linear_sampler, uv), position);
    \\}
;

allocator: Allocator,
device: objc.Object,
command_queue: objc.Object,
draw_pipeline: objc.Object,
render_state: *RenderState,

pub fn create(allocator: Allocator, width: usize, height: usize) !*Self {
    const device_id = MTLCreateSystemDefaultDevice() orelse return error.MetalUnavailable;
    const device = objc.Object.fromId(device_id).retain();
    errdefer device.release();

    const command_queue = device.getProperty(objc.Object, "newCommandQueue");
    if (command_queue.value == null) return error.CommandQueueCreationFailed;
    errdefer command_queue.release();

    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();
    const library = block: {
        const source = try string(shader_source);
        defer source.release();
        var compile_error: objc.c.id = null;
        const result = device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{
            source, @as(objc.c.id, null), &compile_error,
        });
        if (result.value == null) return error.ShaderCompilationFailed;
        break :block result;
    };
    defer library.release();

    const draw_pipeline = try createPipeline(device, library, "draw_source");
    errdefer draw_pipeline.release();

    const render_state = try RenderState.create(allocator, device, width, height);
    errdefer render_state.destroy();

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .device = device,
        .command_queue = command_queue,
        .draw_pipeline = draw_pipeline,
        .render_state = render_state,
    };
    return self;
}

pub fn destroy(self: *Self) void {
    self.render_state.destroy();
    self.draw_pipeline.release();
    self.command_queue.release();
    self.device.release();
    self.allocator.destroy(self);
}

fn createPipeline(device: objc.Object, library: objc.Object, name_value: []const u8) !objc.Object {
    const name = try string(name_value);
    defer name.release();
    const function = library.msgSend(objc.Object, "newFunctionWithName:", .{name});
    if (function.value == null) return error.ShaderFunctionMissing;
    defer function.release();
    var pipeline_error: objc.c.id = null;
    const pipeline = device.msgSend(objc.Object, "newComputePipelineStateWithFunction:error:", .{
        function, &pipeline_error,
    });
    if (pipeline.value == null) return error.PipelineCreationFailed;
    return pipeline;
}

fn string(value: []const u8) !objc.Object {
    const class = objc.getClass("NSString") orelse return error.FoundationUnavailable;
    const allocated = class.msgSend(objc.Object, "alloc", .{});
    const result = allocated.msgSend(
        objc.Object,
        "initWithBytes:length:encoding:",
        .{ value.ptr, value.len, foundation.NSUTF8StringEncoding },
    );
    if (result.value == null) return error.StringCreationFailed;
    return result;
}
