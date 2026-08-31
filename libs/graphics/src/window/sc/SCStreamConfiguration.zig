const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");
const utils = @import("utils.zig");

const cm = macos.CoreMedia;
const cg = macos.CoreGraphics;
const cf = macos.CoreFoundation;
const sc = macos.ScreenCaptureKit;

const dispatch = std.c.dispatch;

const SCStreamConfiguration = @This();
const Self = SCStreamConfiguration;

const SetMinimumFrameInterval = *const fn (
    object: objc.c.id,
    selector: objc.c.SEL,
    time: cm.CMTime,
) callconv(.c) void;

obj: objc.Object,

pub fn init() !Self {
    const obj = try utils.init_object("SCStreamConfiguration", "init", .{});
    return .{ .obj = obj };
}

pub fn deinit(self: Self) void {
    self.obj.release();
}

pub fn setWidth(self: Self, width: u32) void {
    self.obj.msgSend(void, "setWidth:", .{@as(usize, width)});
}

pub fn setHeight(self: Self, height: u32) void {
    self.obj.msgSend(void, "setHeight:", .{@as(usize, height)});
}

pub fn setMinimumFrameInterval(
    self: Self,
    value: cm.CMTimeValue,
    timescale: cm.CMTimeScale,
) void {
    const msg_send: SetMinimumFrameInterval = @ptrCast(&objc.c.objc_msgSend);
    msg_send(
        self.obj.value,
        objc.sel("setMinimumFrameInterval:").value,
        cm.CMTimeMake(value, timescale),
    );
}

pub fn setQueueDepth(self: Self, depth: isize) void {
    self.obj.msgSend(void, "setQueueDepth:", .{depth});
}

pub fn setPixelFormat(self: Self, format: u32) void {
    self.obj.msgSend(void, "setPixelFormat:", .{format});
}

pub fn setColorSpaceName(self: Self, name: cf.CFStringRef) void {
    self.obj.msgSend(void, "setColorSpaceName:", .{name});
}

pub fn setShowsCursor(self: Self, show: bool) void {
    self.obj.msgSend(void, "setShowsCursor:", .{utils.objc_bool(show)});
}

pub fn setCaptureResolution(self: Self, resolution: sc.SCCaptureResolutionType) void {
    self.obj.msgSend(void, "setCaptureResolution:", .{resolution});
}

pub fn setBackgroundColor(self: Self, color: cg.CGColorRef) void {
    self.obj.msgSend(void, "setBackgroundColor:", .{color});
}
