const std = @import("std");
const objc = @import("objc");
const Self = @import("Self.zig");
const log = std.log.scoped(.vision);

pub fn _performRequests(self: *Self, handler: objc.Object) !void {
    var error_id: objc.c.id = null;
    const succeeded = handler.msgSend(bool, "performRequests:error:", .{ self.requests, &error_id });
    if (!succeeded) {
        logVisionError(error_id);
        return error.PerformRequestFailed;
    }
}

fn logVisionError(error_id: objc.c.id) void {
    if (error_id == null) return;

    const description = objc.Object.fromId(error_id).getProperty(
        objc.Object,
        "localizedDescription",
    );
    const string = description.msgSend([*c]const u8, "UTF8String", .{});
    if (string != null) log.err("Vision request failed: {s}", .{string});
}
