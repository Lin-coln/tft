const objc = @import("objc");

pub fn ensure_initialized() !void {
    const application_class = objc.getClass("NSApplication") orelse
        return error.AppKitUnavailable;
    const application = application_class.msgSend(objc.Object, "sharedApplication", .{});
    if (application.value == null) return error.AppKitUnavailable;
}
