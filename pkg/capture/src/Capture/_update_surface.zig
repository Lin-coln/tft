const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const cf = macos.CoreFoundation;
const IOSurface = macos.IOSurface.IOSurface;
const IOSurfaceRef = macos.IOSurface.IOSurfaceRef;
const IOSurfaceIncrementUseCount = macos.IOSurface.IOSurfaceIncrementUseCount;
const IOSurfaceDecrementUseCount = macos.IOSurface.IOSurfaceDecrementUseCount;

pub const Surface = struct {
    ref: IOSurfaceRef,

    pub fn init(ref: IOSurfaceRef) Surface {
        _ = cf.CFRetain(@ptrCast(ref));
        IOSurfaceIncrementUseCount(ref);
        return .{
            .ref = ref,
        };
    }

    pub fn deinit(self: Surface) void {
        IOSurfaceDecrementUseCount(self.ref);
        cf.CFRelease(@ptrCast(self.ref));
    }
};

const Self = @import("Self.zig");

pub fn _update(self: *Self, next: ?Surface) void {
    const prev = self.surface;
    self.surface = next;
    if (prev) |val| val.deinit();
}

pub fn _updateFromSampleBuffer(self: *Self, sample_buffer: cm.CMSampleBufferRef) void {
    if (cm.CMSampleBufferIsValid(sample_buffer) == 0) return;

    const surface = init: {
        var surface: ?IOSurfaceRef = null;
        const buffer = cm.CMSampleBufferGetImageBuffer(sample_buffer) orelse return;
        _ = cv.CVPixelBufferLockBaseAddress(buffer, 0);
        surface = cv.CVPixelBufferGetIOSurface(buffer);
        _ = cv.CVPixelBufferUnlockBaseAddress(buffer, 0);
        break :init surface;
    } orelse return;

    _update(self, Surface.init(surface));
}
