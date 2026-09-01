const std = @import("std");
const macos = @import("macos");
const cg = macos.CoreGraphics;
const cf = macos.CoreFoundation;
const dict = @import("dict.zig");
const Window = @This();
const Self = Window;

id: u32,

pub fn init(id: u32) Self {
    return .{ .id = id };
}

pub fn get_layer(self: Self) ?i32 {
    const window_info = self.retain_window_info() orelse return null;
    defer cf.CFRelease(window_info);

    return dict.get_i32(window_info, cg.kCGWindowLayer);
}

pub fn get_owner_name(self: Self, allocator: std.mem.Allocator) !?[]u8 {
    const window_info = self.retain_window_info() orelse return null;
    defer cf.CFRelease(window_info);

    return dict.dupe(window_info, allocator, cg.kCGWindowOwnerName);
}

pub fn get_name(self: Self, allocator: std.mem.Allocator) !?[]u8 {
    const window_info = self.retain_window_info() orelse return null;
    defer cf.CFRelease(window_info);

    return dict.dupe(window_info, allocator, cg.kCGWindowName);
}

fn retain_window_info(self: Self) ?cf.CFDictionaryRef {
    if (self.id == 0) return null;

    const values = [_]cf.CFTypeRef{@ptrFromInt(self.id)};
    const window_ids = cf.CFArrayCreate(null, &values, values.len, null) orelse return null;
    defer cf.CFRelease(window_ids);

    const window_info = cg.CGWindowListCreateDescriptionFromArray(window_ids) orelse return null;
    defer cf.CFRelease(window_info);

    if (cf.CFArrayGetCount(window_info) == 0) return null;

    const raw_value = cf.CFArrayGetValueAtIndex(window_info, 0) orelse return null;
    return @ptrCast(cf.CFRetain(raw_value));
}
