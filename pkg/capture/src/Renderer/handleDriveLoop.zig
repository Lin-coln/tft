const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const mtl = macos.Metal;
const Frame = @import("tft/stream").Frame;

const Self = @import("Self.zig");

pub const Driver = @import("tft/pipeline").Driver.Of(Self, handleDriveLoop);

fn handleDriveLoop(
    self: *Self,
    ts: std.Io.Clock.Timestamp,
) ?std.Io.Duration {
    const pts = ts.raw;

    var frame: ?*Frame = if (render(self)) |image_buffer|
        Frame.create(self.allocator, image_buffer, pts, .zero) catch null
    else |_| null;

    // frame
    const duration = self.driver.calcDuration(ts);
    if (frame) |next| next.addDuration(duration);

    frame = block: {
        std.Io.Threaded.mutexLock(&self.img_last_mutext);
        defer std.Io.Threaded.mutexUnlock(&self.img_last_mutext);

        const prev = self.img_last;
        if (frame == null) {
            break :block if (prev) |image_buffer|
                Frame.create(self.allocator, cv.CVBufferRetain(image_buffer).?, pts, duration) catch null
            else
                null;
        }

        self.img_last = cv.CVBufferRetain(frame.?.getImageBuffer()).?;
        cv.CVBufferRelease(prev);
        break :block frame;
    };

    // output
    if (frame) |next| {
        self.encoder.post(next) catch |err| {
            std.log.err("frame post failed: {s}", .{@errorName(err)});
            next.destroy();
        };
        return duration;
    } else {
        return null;
    }
}

fn render(self: *Self) !cv.CVImageBufferRef {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const texture = (try self.source.getTexture(self.device.device)) orelse return error.NoSourceTexture;
    defer texture.release();

    const device = self.device;
    const ctx = try device.createContext();
    defer ctx.destroy();

    try ctx.drawBackground(.{ 0.5, 0.5, 0.5, 1.0 });
    const canvas: @Vector(2, f32) = .{ @floatFromInt(device.width), @floatFromInt(device.height) };
    const center = self.source.calcRect(canvas);
    try ctx.drawSource(texture, center);

    const output = try ctx.getBorrowedOuputTexture();

    const output_buffer = blk: {
        var buffer_ref: ?cv.CVPixelBufferRef = null;
        if (cv.CVPixelBufferPoolCreatePixelBuffer(null, self.pixel_pool, &buffer_ref) != 0)
            return error.PixelBufferCreationFailed;
        break :blk buffer_ref orelse return error.PixelBufferCreationFailed;
    };
    errdefer cf.CFRelease(@ptrCast(output_buffer));

    const output_texture = blk: {
        var texture_ref: ?cv.CVMetalTextureRef = null;
        if (cv.CVMetalTextureCacheCreateTextureFromImage(
            null,
            self.texture_cache,
            output_buffer,
            null,
            mtl.MTLPixelFormatBGRA8Unorm,
            device.width,
            device.height,
            0,
            &texture_ref,
        ) != 0) return error.TextureCreationFailed;
        break :blk texture_ref orelse return error.TextureCreationFailed;
    };
    defer cf.CFRelease(@ptrCast(output_texture));

    const target = cv.CVMetalTextureGetTexture(output_texture) orelse return error.TextureCreationFailed;
    const command_buffer = blk: {
        const value = device.command_queue.getProperty(objc.Object, "commandBuffer");
        if (value.value == null) return error.CommandBufferCreationFailed;
        break :blk value.retain();
    };
    defer command_buffer.release();

    const blit_encoder = blk: {
        const value = command_buffer.getProperty(objc.Object, "blitCommandEncoder");
        if (value.value == null) return error.BlitCommandEncoderCreationFailed;
        break :blk value.retain();
    };
    defer blit_encoder.release();

    blit_encoder.msgSend(void, "copyFromTexture:toTexture:", .{ output.obj, objc.Object.fromId(target) });
    blit_encoder.msgSend(void, "endEncoding", .{});
    command_buffer.msgSend(void, "commit", .{});
    command_buffer.msgSend(void, "waitUntilCompleted", .{});
    if (command_buffer.getProperty(usize, "status") != 4) return error.RenderFailed;

    return output_buffer;
}
