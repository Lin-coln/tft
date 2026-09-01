const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const retainShareableContent = @import("../sc/getShareableContent.zig").retain;

const cg = macos.CoreGraphics;

pub fn resolveTarget(window_id: u32) !objc.Object {
    if (window_id == cg.kCGNullWindowID) return error.InvalidWindowId;

    const shareable_content = try retainShareableContent();
    defer shareable_content.release();

    const target = find_window(shareable_content, window_id) orelse
        return error.ScreenshotTargetNotFound;

    return target;
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
