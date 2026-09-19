const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Texture = @import("tft/stream").Texture;

const Shader = @import("tft/stream").Device.Shader.Of(
    enum { vertex_quad, draw_background, draw_source },
    .{
        .vertex_quad = .vertex,
        .draw_background = .fragment,
        .draw_source = .fragment,
    },
);

const Allocator = std.mem.Allocator;
const mtl = macos.Metal;
const Self = @This();

allocator: Allocator,
shader_draw: *Shader = undefined,
desc_ppl_background: objc.Object = undefined,
desc_ppl_source: objc.Object = undefined,
desc_render_pass: objc.Object = undefined,
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

    self.desc_ppl_background = try createPipelineDesc(
        self.shader_draw.function(.vertex_quad),
        self.shader_draw.function(.draw_background),
    );
    errdefer self.desc_ppl_background.release();

    self.desc_ppl_source = try createPipelineDesc(
        self.shader_draw.function(.vertex_quad),
        self.shader_draw.function(.draw_source),
    );
    errdefer self.desc_ppl_source.release();

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
    self.desc_ppl_source.release();
    self.desc_ppl_background.release();
    self.shader_draw.destroy();
    self.allocator.destroy(self);
}

fn createPipelineDesc(vertex: objc.Object, fragment: objc.Object) !objc.Object {
    const desc = blk: {
        const value = objc.getClass("MTLRenderPipelineDescriptor").?.msgSend(objc.Object, "new", .{});
        if (value.value == null) return error.PipelineDescriptorCreationFailed;
        break :blk value;
    };
    errdefer desc.release();

    desc.setProperty("vertexFunction", vertex);
    desc.setProperty("fragmentFunction", fragment);
    const attachments = desc.getProperty(objc.Object, "colorAttachments");
    const color = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    color.setProperty("pixelFormat", mtl.MTLPixelFormatBGRA8Unorm);
    return desc;
}

pub fn resetCommands(self: *Self) void {
    if (self.command_buffer) |command_buffer| command_buffer.release();
    self.command_buffer = null;
}
