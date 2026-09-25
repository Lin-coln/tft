const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const Allocator = std.mem.Allocator;
const mtl = macos.Metal;
const Self = @This();

allocator: Allocator,
desc_render_pass: objc.Object,
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
        .desc_render_pass = undefined,
        .target = null,
        .command_buffer = null,
        .background = .{ 0.5, 0.5, 0.5, 1.0 },
        .width = width,
        .height = height,
    };

    self.target = try Texture.create(allocator, .{
        .device = device,
        .width = width,
        .height = height,
        .pixel_format = mtl.MTLPixelFormatBGRA8Unorm,
        .usage = mtl.MTLTextureUsageRenderTarget | mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModePrivate,
    });
    errdefer self.target.?.release();

    self.desc_render_pass = blk: {
        const value = objc.getClass("MTLRenderPassDescriptor").?.msgSend(objc.Object, "new", .{});
        if (value.value == null) return error.RenderPassDescriptorCreationFailed;
        break :blk value;
    };
    errdefer self.desc_render_pass.release();
    return self;
}

pub fn destroy(self: *Self) void {
    self.resetCommands();
    self.desc_render_pass.release();
    if (self.target) |target| target.release();
    self.allocator.destroy(self);
}

pub fn resetCommands(self: *Self) void {
    if (self.command_buffer) |command_buffer| command_buffer.release();
    self.command_buffer = null;
}
