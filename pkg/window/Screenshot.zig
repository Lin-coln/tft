const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const SCContentFilter = @import("sc/SCContentFilter.zig");
const SCStreamConfiguration = @import("sc/SCStreamConfiguration.zig");
const retainShareableContent = @import("sc/getShareableContent.zig").retain;
const retainSampleBuffer = @import("sc/captureSampleBuffer.zig").retain;

const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const image_io = macos.ImageIO;
const sc = macos.ScreenCaptureKit;

const Self = @This();

window_id: u32,
shareable_content: objc.Object,
ci_context: objc.Object,

pub fn init(window_id: u32) !Self {
    if (window_id == cg.kCGNullWindowID) return error.InvalidWindowId;
    if (!cg.CGPreflightScreenCaptureAccess()) return error.ScreenCaptureKitUnavailable;

    const content = try retainShareableContent();
    errdefer content.release();

    const ci_context = init: {
        const Class = objc.getClass("CIContext").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(objc.Object, "initWithOptions:", .{@as(objc.c.id, null)});
        break :init id_init;
    };
    errdefer ci_context.release();

    return .{
        .window_id = window_id,
        .shareable_content = content,
        .ci_context = ci_context,
    };
}

pub fn deinit(self: Self) void {
    self.ci_context.release();
    self.shareable_content.release();
}

pub fn sample(self: Self) !objc.Object {
    const target = find_window(self.shareable_content, self.window_id) orelse
        return error.ScreenshotTargetNotFound;
    defer target.release();

    const filter = SCContentFilter.create(target);
    defer filter.release();

    const config = SCStreamConfiguration.create();
    defer config.release();

    const frame = target.getProperty(cg.CGRect, "frame");
    const scale = filter.getProperty(f32, "pointPixelScale");
    config.setProperty("width", pixel_dimension(frame.size.width, scale));
    config.setProperty("height", pixel_dimension(frame.size.height, scale));
    config.setProperty("captureResolution", sc.SCCaptureResolutionBest);
    config.setProperty("pixelFormat", cv.kCVPixelFormatType_ARGB2101010LEPacked);
    config.setProperty("colorSpaceName", cg.kCGColorSpaceDisplayP3);
    config.setProperty("showsCursor", false);
    // config.setQueueDepth(8);

    return try retainSampleBuffer(filter, config);
}

fn find_window(shareable_content: objc.Object, window_id: u32) ?objc.Object {
    const windows = shareable_content.getProperty(objc.Object, "windows");

    var iterator = windows.iterate();
    while (iterator.next()) |candidate| {
        if (candidate.getProperty(u32, "windowID") != window_id)
            continue;
        return candidate.retain();
    }

    return null;
}

fn pixel_dimension(points: f64, point_pixel_scale: f32) u32 {
    if (!std.math.isFinite(points) or points < 1) return 1;
    if (!std.math.isFinite(point_pixel_scale) or point_pixel_scale <= 0) return 1;

    const pixels = @ceil(points * @as(f64, point_pixel_scale));
    if (pixels >= std.math.maxInt(u32)) return std.math.maxInt(u32);
    return @intFromFloat(pixels);
}
