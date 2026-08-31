const std = @import("std");
const builtin = @import("builtin");
const macos = @import("macos");
const objc = @import("objc");

const dispatch = std.c.dispatch;
const cg = macos.cg;
const sc = macos.ScreenCaptureKit;

const Completion = objc.Block(
    struct { result: *objc.c.id, semaphore: dispatch.semaphore_t },
    .{ objc.c.id, objc.c.id },
    void,
);

pub fn retainShareableContent() ?objc.Object {
    const semaphore = dispatch.semaphore_create(0) orelse return null;
    defer dispatch.release(semaphore.as_object());

    var content_id: objc.c.id = null;
    const content = objc.getClass("SCShareableContent") orelse return null;
    var completion = Completion.init(
        .{ .result = &content_id, .semaphore = semaphore },
        callback,
    );

    const excluding_desktop_windows = true;
    const on_screen_windows_only = false;

    dispatch.retain(semaphore.as_object());
    content.msgSend(void, "getShareableContentExcludingDesktopWindows:onScreenWindowsOnly:completionHandler:", .{
        excluding_desktop_windows,
        on_screen_windows_only,
        &completion,
    });
    _ = dispatch.semaphore_wait(semaphore, .FOREVER);

    if (content_id == null) return null;
    return objc.Object.fromId(content_id);
}

fn callback(
    completion: *const Completion.Context,
    content_id: objc.c.id,
    error_value: objc.c.id,
) callconv(.c) void {
    if (error_value == null) {
        if (content_id) |id| {
            const content_object = objc.Object.fromId(id);
            completion.result.* = content_object.retain().value;
        }
    } else {
        // log_ns_error("failed to getShareableContent", error_value);
    }
    _ = dispatch.semaphore_signal(completion.semaphore);
    dispatch.release(completion.semaphore.as_object());
}
