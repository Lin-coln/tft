const objc = @import("objc");

pub fn retainCIContext() objc.Object {
    return init: {
        const Class = objc.getClass("CIContext").?;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        break :init allocated.msgSend(
            objc.Object,
            "initWithOptions:",
            .{@as(objc.c.id, null)},
        );
    };
}
