const std = @import("std");
const objc = @import("objc");
const utils = @import("utils.zig");

const dispatch = std.c.dispatch;

const SCContentFilter = @This();
const Self = SCContentFilter;

obj: objc.Object,

pub fn initWithDesktopIndependentWindow(window: objc.Object) !Self {
    const obj = try utils.init_object(
        "SCContentFilter",
        "initWithDesktopIndependentWindow:",
        .{window},
    );
    return .{
        .obj = obj,
    };
}

pub fn deinit(self: Self) void {
    self.obj.release();
}

pub fn getPointPixelScale(self: Self) f32 {
    return self.obj.msgSend(f32, "pointPixelScale", .{});
}
