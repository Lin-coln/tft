const std = @import("std");
const napi = @import("napi-zig");
const macos = @import("macos");
const objc = @import("objc");

const cg = macos.CoreGraphics;
const Window = @import("Window.zig");
const ensureInitialized = @import("ensureInitialized.zig").ensureInitialized;
const retainShareableContent = @import("getShareableContent.zig").retain;

const WindowInfo = struct {
    id: u32,
    name: []const u8,
    owner_name: []const u8,

    pub fn toJs(self: WindowInfo, env: napi.Env) !napi.Val {
        const value = try env.createObject();
        try value.setNamedProperty(env, "id", try env.toJs(self.id));
        try value.setNamedProperty(env, "name", try env.toJs(self.name));
        try value.setNamedProperty(env, "owner_name", try env.toJs(self.owner_name));
        return value;
    }
};

pub fn listWindows(env: napi.Env) ![]WindowInfo {
    try ensureInitialized();
    const allocator = env.allocator();

    const windows = try retainWindows(allocator);
    defer allocator.free(windows);

    const result = try allocator.alloc(WindowInfo, windows.len);
    errdefer allocator.free(result);
    for (windows, result) |window, *item| {
        item.* = .{
            .id = window.id,
            .name = try window.getName(allocator) orelse "",
            .owner_name = try window.getOwnerName(allocator) orelse "",
        };
    }
    return result;
}

fn retainWindows(allocator: std.mem.Allocator) ![]Window {
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
        if (candidate.getLayer() != 0) continue;
        if (!hasNonEmptyNames(shareable_window)) continue;
        try list.append(allocator, candidate);
    }
    return list.toOwnedSlice(allocator);
}

fn hasNonEmptyNames(window: objc.Object) bool {
    const app = window.getProperty(objc.Object, "owningApplication");
    const name = app.getProperty(objc.Object, "applicationName");
    if (name.getProperty(usize, "length") == 0) return false;

    const title = window.getProperty(objc.Object, "title");
    if (title.value == null) return false;
    return title.getProperty(usize, "length") != 0;
}
