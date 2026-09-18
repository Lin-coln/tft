const std = @import("std");

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
        const rendered = self.scaler.render(surface.ref) catch break :block null;
        break :block Frame.create(self.allocator, rendered, pts, .zero) catch null;
    };

    // frame
    const duration = self.driver.calcDuration(ts);
    if (frame) |next| next.addDuration(duration);

    frame = block: {
        std.Io.Threaded.mutexLock(&self.frame_last_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.frame_last_mutex);

        const prev = self.frame_last;
        if (frame == null) {
            break :block if (prev) |surface|
                Frame.create(self.allocator, surface.retain(), pts, duration) catch null
            else
                null;
        }

        self.frame_last = frame.?.surface.retain();
        if (prev) |surface| surface.release();
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
