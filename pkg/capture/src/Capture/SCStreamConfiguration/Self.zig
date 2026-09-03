const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const ns = macos.Foundation;
const cm = macos.CoreMedia;

const Self = @This();

obj: objc.Object,

pub fn init() Self {
    const config = init: {
        const Class = objc.getClass("SCStreamConfiguration").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(objc.Object, "init", .{});
        break :init id_init;
    };

    return .{ .obj = config };
}

pub fn deinit(self: Self) void {
    self.obj.release();
}

pub fn setMinimumFrameInterval(self: Self, time: cm.CMTime) void {
    // zig-objc will unwrap CMTime when use obj.msgSend and that is unexcepted.
    const SetMinimumFrameInterval = *const fn (object: objc.c.id, selector: objc.c.SEL, time: cm.CMTime) callconv(.c) void;
    const msg_send: SetMinimumFrameInterval = @ptrCast(&objc.c.objc_msgSend);
    msg_send(
        self.obj.value,
        objc.sel("setMinimumFrameInterval:").value,
        time,
    );
}
