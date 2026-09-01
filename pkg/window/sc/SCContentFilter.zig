const std = @import("std");
const objc = @import("objc");

pub fn create(window: objc.Object) objc.Object {
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

    return filter;
}
