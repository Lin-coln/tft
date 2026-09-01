const std = @import("std");
const objc = @import("objc");
const dispatch = std.c.dispatch;

pub fn bindVar(comptime Ivar: [:0]const u8, comptime Type: type) type {
    return struct {
        pub fn set(obj: objc.Object, ptr: ?*Type) void {
            _ = objc.c.object_setInstanceVariable(obj.value, Ivar, if (ptr) |p| @ptrCast(p) else null);
        }

        pub fn get(id: objc.c.id) ?*Type {
            var raw: ?*anyopaque = null;
            _ = objc.c.object_getInstanceVariable(id, Ivar, &raw);
            return @ptrCast(@alignCast(raw orelse return null));
        }

        pub fn define(Class: objc.Class) void {
            check(objc.c.class_addIvar(
                Class.value,
                Ivar,
                @sizeOf(*anyopaque),
                @intCast(@ctz(@as(usize, @alignOf(*anyopaque)))),
                "^v",
            ));
        }
    };
}

pub fn defineClass(comptime ClassName: [:0]const u8, comptime onBinding: anytype) *const fn () objc.Class {
    const Impl = struct {
        var class: objc.Class = undefined;
        var once: dispatch.once_t = .init;

        fn getClass() objc.Class {
            once.once(null, &create);
            return class;
        }

        fn create(_: ?*anyopaque) callconv(.c) void {
            if (objc.getClass(ClassName)) |existing| {
                class = existing;
                return;
            }

            const NSObject = objc.getClass("NSObject").?;
            const Class = objc.allocateClassPair(NSObject, ClassName).?;

            onBinding(Class);

            objc.registerClassPair(Class);

            class = Class;
        }
    };

    return &Impl.getClass;
}

pub fn addProtocol(Class: objc.Class, comptime ProtocolName: [:0]const u8) void {
    // bun cannot getProtocol
    const Protocol = objc.getProtocol(ProtocolName) orelse return;
    // const Protocol = objc.getProtocol(ProtocolName).?;
    check(objc.c.class_addProtocol(Class.value, Protocol.value));
}

pub fn addMethod(Class: objc.Class, comptime name: [:0]const u8, impl: anytype) void {
    check(Class.addMethod(name, impl));
}

fn check(result: anytype) void {
    const ok = if (@TypeOf(result) == bool)
        result
    else
        result != 0;

    if (!ok) @panic("objc class setup failed");
}
