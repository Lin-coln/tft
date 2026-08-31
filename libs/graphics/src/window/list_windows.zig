const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const cg = macos.CoreGraphics;
const retainShareableContent = @import("sc/retainShareableContent.zig").retainShareableContent;
const Window = @import("Window.zig");

pub fn list_windows(allocator: std.mem.Allocator) ![]Window {
    const content = retainShareableContent() orelse
        return error.ScreenCaptureKitUnavailable;
    defer content.release();

    const shareable_windows = content.msgSend(objc.Object, "windows", .{});
    if (shareable_windows.value == null) return error.ScreenCaptureKitUnavailable;

    var list: std.ArrayList(Window) = .empty;
    errdefer list.deinit(allocator);

    var iterator = shareable_windows.iterate();
    while (iterator.next()) |shareable_window| {
        const id = shareable_window.msgSend(u32, "windowID", .{});
        if (id == cg.kCGNullWindowID) continue;

        const candidate = Window.init(id);
        if (candidate.get_layer() != 0) continue;
        if (!has_non_empty_names(shareable_window)) continue;
        try list.append(allocator, candidate);
    }

    return list.toOwnedSlice(allocator);
}

fn has_non_empty_names(window: objc.Object) bool {
    const application = window.msgSend(objc.Object, "owningApplication", .{});
    if (application.value == null) return false;

    const application_name = application.msgSend(objc.Object, "applicationName", .{});
    if (application_name.value == null or application_name.msgSend(usize, "length", .{}) == 0)
        return false;

    const title = window.msgSend(objc.Object, "title", .{});
    return title.value != null and title.msgSend(usize, "length", .{}) != 0;
}

test "list windows" {
    const allocator = std.testing.allocator;
    const windows = try list_windows(allocator);
    defer allocator.free(windows);

    for (windows) |window| {
        try std.testing.expect(window.id != 0);
        try std.testing.expectEqual(@as(?i32, 0), window.get_layer());
    }

    if (windows.len != 0) {
        _ = windows[0].get_layer();

        const owner_name = try windows[0].get_owner_name(allocator);
        defer if (owner_name) |value| allocator.free(value);

        const name = try windows[0].get_name(allocator);
        defer if (name) |value| allocator.free(value);
    }
}
