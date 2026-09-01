const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cf = macos.CoreFoundation;
const sck = macos.ScreenCaptureKit;

const Self = @import("Self.zig");

pub fn _update(self: *Self, next: ?cg.CGRect) void {
    self.frame = next;
}

pub fn _updateFromSampleBuffer(self: *Self, buffer: *cm.CMSampleBuffer) void {
    const frame = resolveFrameFromSampleBuffer(buffer) orelse return;

    const prev = self.frame;
    _update(self, frame);

    const changed =
        if (prev) |rect|
            rect.size.width != frame.size.width or
                rect.size.height != frame.size.height
        else
            true;
    if (!changed) return;

    @import("_init_config.zig")._syncFromCaptureStates(self);
    self.stream.updateConfig(self.config.obj);
}

fn resolveFrameFromSampleBuffer(buffer: *cm.CMSampleBuffer) ?cg.CGRect {
    const dict: *const cf.CFDictionary = block: {
        const arr = cm.CMSampleBufferGetSampleAttachmentsArray(buffer, 0) orelse
            return null;
        if (cf.CFArrayGetCount(arr) < 1)
            return null;
        const item = cf.CFArrayGetValueAtIndex(arr, 0) orelse
            return null;
        break :block @ptrCast(item);
    };

    const rect = cf.CFDictionaryGetValue(dict, @ptrCast(sck.SCStreamFrameInfoContentRect)) orelse
        return null;

    const scale: f32 = block: {
        const raw = cf.CFDictionaryGetValue(
            dict,
            @ptrCast(sck.SCStreamFrameInfoContentScale),
        ) orelse return null;

        var value: f32 = undefined;
        if (cf.CFNumberGetValue(@ptrCast(raw), cf.kCFNumberFloatType, &value) == 0)
            return null;
        if (value == 0)
            return null;

        break :block value;
    };

    const scale_factor: f32 = block: {
        const raw = cf.CFDictionaryGetValue(
            dict,
            @ptrCast(sck.SCStreamFrameInfoScaleFactor),
        ) orelse return null;

        var value: f32 = undefined;
        if (cf.CFNumberGetValue(@ptrCast(raw), cf.kCFNumberFloatType, &value) == 0)
            return null;

        break :block value;
    };

    var frame: cg.CGRect = .{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = 0, .height = 0 },
    };
    if (!cg.CGRectMakeWithDictionaryRepresentation(@ptrCast(rect), &frame))
        return null;

    const content_scale: f64 = @floatCast(scale);
    const frame_scale_factor: f64 = @floatCast(scale_factor);
    frame.size.width = frame.size.width / content_scale * frame_scale_factor;
    frame.size.height = frame.size.height / content_scale * frame_scale_factor;

    return frame;
}
