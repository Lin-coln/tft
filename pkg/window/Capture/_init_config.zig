const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const SCStreamConfiguration = @import("SCStreamConfiguration/Self.zig");

const ns = macos.Foundation;
const cv = macos.CoreVideo;
const cm = macos.CoreMedia;
const cg = macos.CoreGraphics;
const sc = macos.ScreenCaptureKit;

const Self = @import("Self.zig");

pub fn _init_config(win: objc.Object) SCStreamConfiguration {
    const cfg = SCStreamConfiguration.init();
    cfg.setMinimumFrameInterval(cm.CMTimeMake(1, 60));

    const frame = win.getProperty(cg.CGRect, "frame");
    const config = cfg.obj;
    config.setProperty("width", ceil(frame.size.width));
    config.setProperty("height", ceil(frame.size.height));
    config.setProperty("captureResolution", sc.SCCaptureResolutionBest);
    config.setProperty("pixelFormat", cv.kCVPixelFormatType_ARGB2101010LEPacked);
    config.setProperty("colorSpaceName", cg.kCGColorSpaceDisplayP3);
    config.setProperty("showsCursor", false);
    config.setProperty("queueDepth", @as(ns.NSInteger, 8));
    config.setProperty("backgroundColor", cg.CGColorGetConstantColor(cg.kCGColorClear).?);

    return cfg;
}

pub fn _syncFromCaptureStates(self: *Self) void {
    const frame = self.frame orelse return;
    const cfg = self.config;
    const config = cfg.obj;
    config.setProperty("width", ceil(frame.size.width));
    config.setProperty("height", ceil(frame.size.height));
}

fn ceil(points: f64) u32 {
    if (!std.math.isFinite(points) or points < 1) return 1;
    if (points >= std.math.maxInt(u32)) return std.math.maxInt(u32);
    return @intFromFloat(@ceil(points));
}
