const objc = @import("objc");

pub const Window = @import("Screenshot/Window.zig");
pub const listWindows = @import("Screenshot/listWindows.zig").listWindows;

pub const resolveTarget = @import("Screenshot/resolveTarget.zig").resolveTarget;
pub const retainCIContext = @import("Screenshot/retainCIContext.zig").retainCIContext;
pub const encodeSurfacePng = @import("Screenshot/encodeSurfacePng.zig").encodeSurfacePng;

pub fn ensure_initialized() !void {
    _ = init: {
        const Class = objc.getClass("NSApplication").?;
        const app = Class.msgSend(objc.Object, "sharedApplication", .{});
        break :init app;
    };
}
