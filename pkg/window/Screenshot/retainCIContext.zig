const objc = @import("objc");

pub fn retainCIContext() objc.Object {
    const ci_context = init: {
        const Class = objc.getClass("CIContext").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(objc.Object, "initWithOptions:", .{@as(objc.c.id, null)});
        break :init id_init;
    };

    return ci_context;
}
