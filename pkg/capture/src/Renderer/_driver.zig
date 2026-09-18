const std = @import("std");
const cv = @import("macos").CoreVideo;

const Self = @import("Self.zig");
const Frame = Self.Frame;

pub const Driver = @import("tft/pipeline").Driver.Of(Self, handleLoop);

fn handleLoop(
    self: *Self,
    ts: std.Io.Clock.Timestamp,
) ?std.Io.Duration {
    const pts = ts.raw;

    // render frame
    var frame: ?*Frame = block: {
        const surface = self.capture.get_surface() orelse break :block null;
        defer surface.deinit();
        const image_buffer = self.scaler.render(surface.ref) catch break :block null;
        break :block Frame.create(self.allocator, image_buffer, pts, .zero) catch null;
    };

    // frame
    const duration = self.driver.calcDuration(ts);
    if (frame) |next| next.addDuration(duration);

    frame = block: {
        std.Io.Threaded.mutexLock(&self.frame_last_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.frame_last_mutex);

        const prev = self.frame_last;
        if (frame == null) {
            break :block if (prev) |image_buffer|
                Frame.create(self.allocator, cv.CVBufferRetain(image_buffer).?, pts, duration) catch null
            else
                null;
        }

        self.frame_last = cv.CVBufferRetain(frame.?.image_buffer).?;
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
