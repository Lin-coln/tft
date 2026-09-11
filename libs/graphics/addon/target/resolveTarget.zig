const macos = @import("macos");
const objc = @import("objc");

const cg = macos.CoreGraphics;
const retainShareableContent = @import("getShareableContent.zig").retain;

pub fn resolveTarget(window_id: u32) !objc.Object {
    if (window_id == cg.kCGNullWindowID) return error.InvalidWindowId;

    const shareable_content = try retainShareableContent();
    defer shareable_content.release();

    return findWindow(shareable_content, window_id) orelse
        error.ScreenshotTargetNotFound;
}

fn findWindow(shareable_content: objc.Object, window_id: u32) ?objc.Object {
    const windows = shareable_content.getProperty(objc.Object, "windows");

    var iterator = windows.iterate();
    while (iterator.next()) |candidate| {
        if (candidate.getProperty(u32, "windowID") != window_id) continue;
        return candidate.retain();
    }

    return null;
}
