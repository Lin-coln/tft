const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const cg = macos.CoreGraphics;
const Window = @import("Window.zig");

const retainShareableContent = @import("getShareableContent.zig").retain;

pub fn listWindows(allocator: std.mem.Allocator) ![]Window {
    const content = try retainShareableContent();
    defer content.release();

    const shareable_windows = content.getProperty(objc.Object, "windows");

    var list: std.ArrayList(Window) = .empty;
    errdefer list.deinit(allocator);

    var iterator = shareable_windows.iterate();
    while (iterator.next()) |shareable_window| {
        const id = shareable_window.getProperty(u32, "windowID");
        if (id == cg.kCGNullWindowID) continue;

        const candidate = Window.init(id);
        if (candidate.get_layer() != 0) continue;
        if (!has_non_empty_names(shareable_window)) continue;
        try list.append(allocator, candidate);
    }

    return list.toOwnedSlice(allocator);
}

fn has_non_empty_names(window: objc.Object) bool {
    const app = window.getProperty(objc.Object, "owningApplication");
    const name = app.getProperty(objc.Object, "applicationName");
    if (name.getProperty(usize, "length") == 0)
        return false;

    const title = window.getProperty(objc.Object, "title");
    if (title.value == null) return false;

    return title.getProperty(usize, "length") != 0;
}

test "Screenshot/listWindows" {
    const allocator = std.testing.allocator;
    const windows = try listWindows(allocator);
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
