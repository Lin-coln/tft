const objc = @import("objc");

pub fn ensure_initialized() !void {
    _ = init: {
        const Class = objc.getClass("NSApplication").?;
        const app = Class.msgSend(objc.Object, "sharedApplication", .{});
        break :init app;
    };
}
