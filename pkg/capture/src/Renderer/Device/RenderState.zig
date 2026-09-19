const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const Shader = @import("tft/stream").Device.Shader.Of(
    enum { draw_source },
    .{
        .draw_source = .kernel,
    },
);

const Allocator = std.mem.Allocator;
const mtl = macos.Metal;
const Self = @This();

allocator: Allocator,
shader_draw: *Shader = undefined,
target: ?*Texture = null,
command_buffer: ?objc.Object = null,
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

    self.target = try Texture.create(allocator, .{
        .device = device,
        .width = width,
        .height = height,
        .pixel_format = mtl.MTLPixelFormatBGRA8Unorm,
        .usage = mtl.MTLTextureUsageShaderWrite | mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModePrivate,
    });
    errdefer self.target.?.release();
    return self;
}

pub fn destroy(self: *Self) void {
    if (self.command_buffer) |command_buffer| command_buffer.release();
    if (self.target) |target| target.release();
    self.shader_draw.destroy();
    self.allocator.destroy(self);
}
