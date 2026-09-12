const std = @import("std");
const macos = @import("macos");
const Frame = @import("../Renderer/Frame.zig");
const Self = @import("Self.zig");

const cf = macos.CoreFoundation;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const vt = macos.VideoToolbox;

/// Takes ownership of `frame`; VideoToolbox releases it from the callback.
pub fn encode(self: *Self, frame: *Frame) !void {
    errdefer frame.destroy();
    const session = self.session orelse return error.NotConfigured;

    var pixel_buffer: ?cv.CVPixelBufferRef = null;
    if (cv.CVPixelBufferCreateWithIOSurface(
        null,
        frame.surface.ref,
        null,
        &pixel_buffer,
    ) != 0 or pixel_buffer == null) return error.PixelBufferCreationFailed;
    defer cf.CFRelease(@ptrCast(pixel_buffer.?));

    const pts, const duration = block: {
        const pts_value = std.math.cast(i64, frame.pts.nanoseconds) orelse
            return error.EncodeFailed;
        const duration_value = std.math.cast(i64, frame.duration.nanoseconds) orelse
            return error.EncodeFailed;
        const timescale: cm.CMTimeScale = @intCast(std.time.ns_per_s);

        break :block .{
            cm.CMTimeMake(pts_value, timescale),
            cm.CMTimeMake(duration_value, timescale),
        };
    };

    if (vt.VTCompressionSessionEncodeFrame(
        session,
        pixel_buffer.?,
        pts,
        duration,
        null,
        frame,
        null,
    ) != 0) return error.EncodeFailed;
}
