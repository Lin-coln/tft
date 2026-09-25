const std = @import("std");
const macos = @import("macos");
const cv = macos.CoreVideo;
const Frame = @import("tft/stream").Frame;
const RenderContext = @import("Device/RenderContext.zig");

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
    const texture = (try self.source.getTexture(self.device.device)) orelse return error.NoSourceTexture;
    defer texture.release();

    const device = self.device;
    const ctx = try RenderContext.create(device);
    defer ctx.destroy();

    try device.drawBackground(ctx, .{ 0.5, 0.5, 0.5, 1.0 });
    const canvas: @Vector(2, f32) = .{ @floatFromInt(device.width), @floatFromInt(device.height) };
    const center = self.source.calcRect(canvas);
    try device.drawSource(ctx, texture, center);

    return ctx.finish();
}
