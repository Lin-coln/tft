const std = @import("std");
const objc = @import("objc");

const Shader = @import("tft/stream").Device.Shader.Of(
    enum { draw_source },
    .{
        .draw_source = .kernel,
    },
);

const Allocator = std.mem.Allocator;
const Self = @This();

allocator: Allocator,
shader_draw: *Shader = undefined,
background: @Vector(4, f32),
width: usize,
height: usize,

pub fn create(allocator: Allocator, device: objc.Object, width: usize, height: usize) !*Self {
    if (width == 0 or height == 0) return error.InvalidDimensions;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .background = .{ 0.5, 0.5, 0.5, 1.0 },
        .width = width,
        .height = height,
    };

    self.shader_draw = try Shader.create(allocator, device, @embedFile("draw.metal"));
    errdefer self.shader_draw.destroy();
    return self;
}

pub fn destroy(self: *Self) void {
    self.shader_draw.destroy();
    self.allocator.destroy(self);
}
