const napi = @import("napi-zig");

comptime {
    napi.module(@This());
}

pub const list_windows = @import("list_windows.zig").list_windows;

pub const Screenshot = napi.class("Screenshot", @import("Screenshot.zig"));
