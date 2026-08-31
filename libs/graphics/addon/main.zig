const napi = @import("napi-zig");

comptime {
    napi.module(@This());
}

pub const listWindows = @import("listWindows.zig").listWindows;

pub const Screenshot = napi.class("Screenshot", @import("Screenshot.zig"));
