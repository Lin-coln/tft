const macos = @import("macos");
const objc_rt = macos.objc;
const std = @import("std");

pub const Object = objc_rt.ObjcObject;
pub const Class = objc_rt.ObjcClass;
pub const Selector = objc_rt.ObjcSelector;

pub fn retain(obj: *Object) void {
    _ = send(*Object, obj, "retain", .{});
}

pub fn release(obj: *Object) void {
    send(void, obj, "release", .{});
}

pub fn class_init(class_name: [*:0]const u8) ?*Object {
    return class_alloc(class_name, "init", .{});
}

pub fn class_send(class_name: [*:0]const u8, selector_name: [*:0]const u8, args: anytype) ?*Object {
    const class = objc_rt.objc_getClass(class_name) orelse
        return null;
    return send(?*Object, class, selector_name, args);
}

pub fn class_alloc(class_name: [*:0]const u8, selector_name: [*:0]const u8, args: anytype) ?*Object {
    const class = objc_rt.objc_getClass(class_name) orelse
        return null;

    const allocated = send(?*Object, class, "alloc", .{}) orelse
        return null;

    return send(?*Object, allocated, selector_name, args);
}

pub fn send_obj(receiver: anytype, selector_name: [*:0]const u8, args: anytype) ?*Object {
    return send(?*Object, receiver, selector_name, args);
}

pub fn send_void(receiver: anytype, selector_name: [*:0]const u8, args: anytype) void {
    return send(void, receiver, selector_name, args);
}

pub fn send(
    comptime Return: type,
    receiver: anytype,
    selector_name: [*:0]const u8,
    args: anytype,
) Return {
    const Receiver = @TypeOf(receiver);
    const Args = @TypeOf(args);

    const args_info = @typeInfo(Args).@"struct";

    comptime var param_types: [args_info.fields.len + 2]type = undefined;
    comptime var param_attrs: [args_info.fields.len + 2]std.builtin.Type.Fn.Param.Attributes =
        @splat(.{});

    param_types[0] = Receiver;
    param_types[1] = *Selector;

    inline for (args_info.fields, 0..) |field, i| {
        param_types[i + 2] = field.type;
    }

    const Function = @Fn(
        &param_types,
        &param_attrs,
        Return,
        .{ .@"callconv" = .c },
    );

    const function: *const Function =
        @ptrCast(&objc_rt.objc_msgSend);

    const selector = objc_rt.sel_registerName(selector_name);

    return @call(
        .auto,
        function,
        .{ receiver, selector } ++ args,
    );
}
