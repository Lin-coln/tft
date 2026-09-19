const std = @import("std");
const macos = @import("macos");
const cv = macos.CoreVideo;
const ios = macos.IOSurface;
const mtl = macos.Metal;
const Texture = @import("tft/stream").Texture;
const Device = @import("Device/Self.zig");

const Self = @import("Self.zig");
const Frame = Self.Frame;

pub const Driver = @import("tft/pipeline").Driver.Of(Self, handleDriveLoop);

fn handleDriveLoop(
    self: *Self,
    ts: std.Io.Clock.Timestamp,
) ?std.Io.Duration {
    const pts = ts.raw;

    // render frame
    var frame: ?*Frame = block: {
        const surface = self.capture.get_surface() orelse break :block null;
        defer surface.deinit();
        const source = Texture.fromIOSurface(self.allocator, .{
            .device = self.device.device,
            .width = ios.IOSurfaceGetWidth(surface.ref),
            .height = ios.IOSurfaceGetHeight(surface.ref),
            .surface = surface.ref,
            .usage = mtl.MTLTextureUsageShaderRead,
            .storage_mode = mtl.MTLStorageModeShared,
        }) catch break :block null;
        defer source.release();
        const device = self.device;
        const image_buffer = renderCaptured(device, source) catch break :block null;
        break :block Frame.create(self.allocator, image_buffer, pts, .zero) catch null;
    };

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

        self.img_last = cv.CVBufferRetain(frame.?.image_buffer).?;
        cv.CVBufferRelease(prev);
        break :block frame;
    };

    // output
    if (frame) |next| {
        self.encode_worker.post(next) catch |err| {
            std.log.err("frame worker post failed: {s}", .{@errorName(err)});
            next.destroy();
        };
        return duration;
    } else {
        return null;
    }
}

fn renderCaptured(device: *Device, source: *Texture) !cv.CVImageBufferRef {
    const state = device.render_state;
    const center: @Vector(2, f32) = .{
        @as(f32, @floatFromInt(state.width)) / 2,
        @as(f32, @floatFromInt(state.height)) / 2,
    };
    try device.drawBackground(.{ 0.5, 0.5, 0.5, 1.0 });
    errdefer state.resetCommands();
    try device.drawSource(source, center);
    return try device.render();
}
