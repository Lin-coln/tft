const std = @import("std");
const objc = @import("objc");

pub fn create() objc.Object {
    const filter = init: {
        const Class = objc.getClass("SCStreamConfiguration").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(objc.Object, "init", .{});
        break :init id_init;
    };

    return filter;
}
