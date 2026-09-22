const std = @import("std");
const macos = @import("macos");
const cv = macos.CoreVideo;
const Frame = @import("tft/stream").Frame;

const Self = @import("Self.zig");

pub const Driver = @import("tft/pipeline").Driver.Of(Self, handleDriveLoop);

fn handleDriveLoop(
    self: *Self,
    ts: std.Io.Clock.Timestamp,
) ?std.Io.Duration {
    const pts = ts.raw;

    // render frame
    var frame: ?*Frame = block: {
        const texture = (self.source.getTexture(self.device.device) catch break :block null) orelse break :block null;
        defer texture.release();

        const device = self.device;

        const state = device.render_state;

        device.drawBackground(.{ 0.5, 0.5, 0.5, 1.0 }) catch break :block null;
        const canvas: @Vector(2, f32) = .{ @floatFromInt(state.width), @floatFromInt(state.height) };
        const center = self.source.calcRect(canvas);
        device.drawSource(texture, center) catch {
            state.resetCommands();
            break :block null;
        };

        const image_buffer = device.render() catch break :block null;
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
