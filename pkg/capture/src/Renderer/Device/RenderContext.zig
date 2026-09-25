const macos = @import("macos");
const objc = @import("objc");

const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const mtl = macos.Metal;
const Device = @import("Self.zig");
const Self = @This();

device: *Device,
output_buffer: cv.CVPixelBufferRef,
output_texture: cv.CVMetalTextureRef,
desc_render_pass: objc.Object,
command_buffer: objc.Object,
render_encoder: objc.Object,
encoder_ended: bool,

pub fn create(device: *Device) !*Self {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const self = try device.allocator.create(Self);
    errdefer device.allocator.destroy(self);
    self.* = .{
        .device = device,
        .output_buffer = undefined,
        .output_texture = undefined,
        .desc_render_pass = undefined,
        .command_buffer = undefined,
        .render_encoder = undefined,
        .encoder_ended = false,
    };

    self.output_buffer = blk: {
        var buffer_ref: ?cv.CVPixelBufferRef = null;
        if (cv.CVPixelBufferPoolCreatePixelBuffer(null, device.pixel_pool, &buffer_ref) != 0)
            return error.PixelBufferCreationFailed;
        break :blk buffer_ref orelse return error.PixelBufferCreationFailed;
    };
    errdefer cf.CFRelease(@ptrCast(self.output_buffer));

    self.output_texture = blk: {
        var texture_ref: ?cv.CVMetalTextureRef = null;
        if (cv.CVMetalTextureCacheCreateTextureFromImage(
            null,
            device.texture_cache,
            self.output_buffer,
            null,
            mtl.MTLPixelFormatBGRA8Unorm,
            device.width,
            device.height,
            0,
            &texture_ref,
        ) != 0) return error.TextureCreationFailed;
        break :blk texture_ref orelse return error.TextureCreationFailed;
    };
    errdefer cf.CFRelease(@ptrCast(self.output_texture));
    const target = cv.CVMetalTextureGetTexture(self.output_texture) orelse return error.TextureCreationFailed;

    self.desc_render_pass = blk: {
        const value = objc.getClass("MTLRenderPassDescriptor").?.msgSend(objc.Object, "new", .{});
        if (value.value == null) return error.RenderPassDescriptorCreationFailed;
        break :blk value;
    };
    errdefer self.desc_render_pass.release();
    const attachments = self.desc_render_pass.getProperty(objc.Object, "colorAttachments");
    const attachment = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    attachment.setProperty("texture", objc.Object.fromId(target));
    attachment.setProperty("loadAction", mtl.MTLLoadActionDontCare);
    attachment.setProperty("storeAction", mtl.MTLStoreActionStore);

    self.command_buffer = blk: {
        const value = device.command_queue.getProperty(objc.Object, "commandBuffer");
        if (value.value == null) return error.CommandBufferCreationFailed;
        break :blk value.retain();
    };
    errdefer self.command_buffer.release();

    self.render_encoder = blk: {
        const value = self.command_buffer.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{self.desc_render_pass});
        if (value.value == null) return error.RenderCommandEncoderCreationFailed;
        break :blk value.retain();
    };
    errdefer {
        self.render_encoder.msgSend(void, "endEncoding", .{});
        self.render_encoder.release();
    }
    return self;
}

pub fn destroy(self: *Self) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    if (!self.encoder_ended) self.render_encoder.msgSend(void, "endEncoding", .{});
    self.render_encoder.release();
    self.command_buffer.release();
    self.desc_render_pass.release();
    cf.CFRelease(@ptrCast(self.output_texture));
    cf.CFRelease(@ptrCast(self.output_buffer));
    self.device.allocator.destroy(self);
}

pub const drawBackground = @import("drawBackground.zig").drawBackground;
pub const drawSource = @import("drawSource.zig").drawSource;
pub const getOutput = @import("getOutput.zig").getOutput;
