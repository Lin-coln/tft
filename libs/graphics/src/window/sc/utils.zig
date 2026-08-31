const std = @import("std");
const objc = @import("objc");

pub fn init_object(
    class_name: [:0]const u8,
    comptime initializer: [:0]const u8,
    args: anytype,
) !objc.Object {
    const class = objc.getClass(class_name) orelse
        return error.ObjectiveCClassUnavailable;

    const allocated = class.msgSend(objc.Object, "alloc", .{});
    if (allocated.value == null) return error.OutOfMemory;

    const initialized = allocated.msgSend(objc.Object, initializer, args);
    if (initialized.value == null) return error.ObjectiveCClassInitFailed;

    return initialized;
}

pub fn add_pointer_ivar(class: objc.Class, name: [:0]const u8) !void {
    if (!objc_bool_value(objc.c.class_addIvar(
        class.value,
        name,
        @sizeOf(?*anyopaque),
        @ctz(@as(usize, @alignOf(?*anyopaque))),
        "^v",
    ))) {
        return error.ObjectiveCIvarUnavailable;
    }
}

pub fn objc_bool(value: bool) objc.c.BOOL {
    return switch (objc.c.BOOL) {
        bool => value,
        i8 => @intFromBool(value),
        else => @compileError("unexpected Objective-C BOOL type"),
    };
}

fn objc_bool_value(value: objc.c.BOOL) bool {
    return switch (objc.c.BOOL) {
        bool => value,
        i8 => value != 0,
        else => @compileError("unexpected Objective-C BOOL type"),
    };
}
