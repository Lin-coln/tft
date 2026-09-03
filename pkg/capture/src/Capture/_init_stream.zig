const std = @import("std");
const objc = @import("objc");

const SCStream = @import("SCStream/Self.zig");

const Self = @import("Self.zig");

pub fn _init_stream(self: *Self, window: objc.Object) void {
    const filter = init: {
        const Class = objc.getClass("SCContentFilter").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(
            objc.Object,
            "initWithDesktopIndependentWindow:",
            .{window},
        );
        break :init id_init;
    };
    defer filter.release();

    const config = @import("_init_config.zig")._init_config(window);

    const stream = SCStream.init(filter, config.obj, self.delegate);

    self.stream = stream;
    self.config = config;
}
