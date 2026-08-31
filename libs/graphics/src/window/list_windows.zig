const std = @import("std");
const macos = @import("macos");
const cg = macos.CoreGraphics;
const cf = macos.CoreFoundation;
const dict = @import("dict.zig");
const Window = @import("Window.zig");

pub fn list_windows(allocator: std.mem.Allocator) ![]Window {
    const opts =
        cg.kCGWindowListOptionAll |
        cg.kCGWindowListExcludeDesktopElements;

    const list = try create_window_list(allocator, opts);
    errdefer allocator.free(list);

    var filtered_len: usize = 0;
    for (list) |candidate| {
        if (candidate.get_layer() != 0) continue;
        list[filtered_len] = candidate;
        filtered_len += 1;
    }

    if (filtered_len == list.len) return list;
    return allocator.realloc(list, filtered_len);
}

fn create_window_list(allocator: std.mem.Allocator, opts: cg.CGWindowListOption) ![]Window {
    const window_info = cg.CGWindowListCopyWindowInfo(opts, cg.kCGNullWindowID) orelse
        return error.WindowListUnavailable;
    defer cf.CFRelease(window_info);

    var windows: std.ArrayList(Window) = .empty;
    errdefer windows.deinit(allocator);

    const count = cf.CFArrayGetCount(window_info);
    var index: cf.CFIndex = 0;
    while (index < count) : (index += 1) {
        const raw_value = cf.CFArrayGetValueAtIndex(window_info, index) orelse continue;
        const ref: cf.CFDictionaryRef = @ptrCast(raw_value);

        const id = dict.get_u32(ref, cg.kCGWindowNumber) orelse continue;
        try windows.append(allocator, .{ .id = id });
    }

    return windows.toOwnedSlice(allocator);
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
