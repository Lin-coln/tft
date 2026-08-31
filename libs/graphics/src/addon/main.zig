const napi = @import("napi-zig");
const calc = @import("calc");
const window = @import("window");

comptime {
    napi.module(@This());
}

pub const add = calc.add;
pub const subtract = calc.subtract;
pub const multiply = calc.multiply;
pub const divide = calc.divide;

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

pub fn list_windows(env: napi.Env) ![]WindowInfo {
    try window.ensure_initialized();

    const allocator = env.allocator();
    const windows = try window.list_windows(allocator);
    defer allocator.free(windows);

    const result = try allocator.alloc(WindowInfo, windows.len);
    for (windows, result) |win, *item| {
        item.* = .{
            .id = win.id,
            .name = try win.get_name(allocator) orelse "",
            .owner_name = try win.get_owner_name(allocator) orelse "",
        };
    }

    return result;
}

pub fn screenshot(env: napi.Env, window_id: u32) !napi.Val {
    if (window_id == 0) return error.InvalidWindowId;
    try window.ensure_initialized();

    const allocator = env.allocator();
    const bytes = try window.screenshot(allocator, window_id);
    defer allocator.free(bytes);

    const buffer = try env.createBuffer(bytes.len);
    @memcpy(buffer.data, bytes);
    return buffer.val;
}
