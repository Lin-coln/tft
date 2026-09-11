const objc = @import("objc");

pub fn ensureInitialized() !void {
    _ = init: {
        const Class = objc.getClass("NSApplication").?;
        const app = Class.msgSend(objc.Object, "sharedApplication", .{});
        break :init app;
    };
}
