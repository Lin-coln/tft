const napi = @import("napi-zig");

comptime {
    napi.module(@This());
}

pub const listWindows = @import("listWindows.zig").listWindows;

pub const Runtime = napi.class("Runtime", @import("Runtime/Self.zig"));
