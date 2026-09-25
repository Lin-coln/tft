const macos = @import("macos");
const objc = @import("objc");

const mtl = macos.Metal;
const Texture = @import("tft/stream").Texture;
const Device = @import("Self.zig");
const Self = @This();

device: *Device,
output_texture: *Texture,
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
        .output_texture = undefined,
        .desc_render_pass = undefined,
        .command_buffer = undefined,
        .render_encoder = undefined,
        .encoder_ended = false,
    };

    self.output_texture = try Texture.create(device.allocator, .{
        .device = device.device,
        .width = device.width,
        .height = device.height,
        .pixel_format = mtl.MTLPixelFormatBGRA8Unorm,
        .usage = mtl.MTLTextureUsageRenderTarget,
        .storage_mode = mtl.MTLStorageModePrivate,
    });
    errdefer self.output_texture.release();

    self.desc_render_pass = blk: {
        const value = objc.getClass("MTLRenderPassDescriptor").?.msgSend(objc.Object, "new", .{});
        if (value.value == null) return error.RenderPassDescriptorCreationFailed;
        break :blk value;
    };
    errdefer self.desc_render_pass.release();
    const attachments = self.desc_render_pass.getProperty(objc.Object, "colorAttachments");
    const attachment = attachments.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(usize, 0)});
    attachment.setProperty("texture", self.output_texture.obj);
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
    self.output_texture.release();
    self.device.allocator.destroy(self);
}

pub const drawBackground = @import("drawBackground.zig").drawBackground;
pub const drawSource = @import("drawSource.zig").drawSource;
pub const getBorrowedOuputTexture = @import("getBorrowedOuputTexture.zig").getBorrowedOuputTexture;
