const std = @import("std");
const macos = @import("macos");
const Frame = @import("../Renderer/Frame.zig");
const Self = @import("Self.zig");

const cf = macos.CoreFoundation;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const vt = macos.VideoToolbox;

pub fn encode(self: *Self, borrowed: *Frame) !void {
    const session = self.session orelse return error.NotConfigured;

    const frame = borrowed.retain();
    errdefer frame.release();

    var pixel_buffer: ?cv.CVPixelBufferRef = null;
    if (cv.CVPixelBufferCreateWithIOSurface(
        null,
        frame.surface,
        null,
        &pixel_buffer,
    ) != 0 or pixel_buffer == null) return error.PixelBufferCreationFailed;
    defer cf.CFRelease(@ptrCast(pixel_buffer.?));

    const pts, const duration = block: {
        const pts_value = std.math.cast(i64, frame.timestamp_ns) orelse
            return error.EncodeFailed;
        const duration_value = std.math.cast(i64, frame.duration_ns) orelse
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
