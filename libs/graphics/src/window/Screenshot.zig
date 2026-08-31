const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const SCContentFilter = @import("sc/SCContentFilter.zig");
const SCStreamConfiguration = @import("sc/SCStreamConfiguration.zig");
const retainShareableContent = @import("sc/retainShareableContent.zig").retainShareableContent;
const retainSampleBuffer = @import("sc/retainSampleBuffer.zig").retainSampleBuffer;

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

    const content = retainShareableContent() orelse return error.ScreenCaptureKitUnavailable;
    errdefer content.release();

    const ci_context = try init_ci_context();
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
    const target = find_window(
        self.shareable_content,
        self.window_id,
    ) orelse return error.ScreenshotTargetNotFound;
    defer target.release();

    const filter = try SCContentFilter.initWithDesktopIndependentWindow(target);
    defer filter.deinit();

    const config = try SCStreamConfiguration.init();
    defer config.deinit();
    const frame = target.msgSend(cg.CGRect, "frame", .{});
    const point_pixel_scale = filter.getPointPixelScale();
    config.setWidth(pixel_dimension(frame.size.width, point_pixel_scale));
    config.setHeight(pixel_dimension(frame.size.height, point_pixel_scale));
    config.setCaptureResolution(sc.SCCaptureResolutionBest);
    // config.setQueueDepth(8);
    config.setPixelFormat(cv.kCVPixelFormatType_ARGB2101010LEPacked);
    config.setColorSpaceName(cg.kCGColorSpaceDisplayP3);
    config.setShowsCursor(false);

    return retainSampleBuffer(filter.obj, config.obj) orelse
        return error.ScreenCaptureKitUnavailable;
}

fn init_ci_context() !objc.Object {
    const class = objc.getClass("CIContext") orelse return error.CoreImageUnavailable;
    const allocated = class.msgSend(objc.Object, "alloc", .{});
    if (allocated.value == null) return error.CoreImageUnavailable;

    const context = allocated.msgSend(objc.Object, "initWithOptions:", .{@as(objc.c.id, null)});
    if (context.value == null) return error.CoreImageUnavailable;
    return context;
}

fn find_window(shareable_content: objc.Object, window_id: u32) ?objc.Object {
    const windows = shareable_content.msgSend(objc.Object, "windows", .{});
    if (windows.value == null) return null;

    var iterator = windows.iterate();
    while (iterator.next()) |candidate| {
        if (candidate.msgSend(u32, "windowID", .{}) != window_id) continue;
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
