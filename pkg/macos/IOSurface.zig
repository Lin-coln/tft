const cf = @import("main.zig").CoreFoundation;
const OSType = @import("main.zig").OSType;

pub const IOSurface = opaque {};
pub const IOSurfaceRef = *IOSurface;

pub extern const kIOSurfaceWidth: cf.CFStringRef;
pub extern const kIOSurfaceHeight: cf.CFStringRef;
pub extern const kIOSurfaceBytesPerElement: cf.CFStringRef;
pub extern const kIOSurfacePixelFormat: cf.CFStringRef;

pub extern fn IOSurfaceCreate(properties: cf.CFDictionaryRef) callconv(.c) ?IOSurfaceRef;
pub extern fn IOSurfaceIncrementUseCount(surface: IOSurfaceRef) callconv(.c) void;
pub extern fn IOSurfaceDecrementUseCount(surface: IOSurfaceRef) callconv(.c) void;
pub extern fn IOSurfaceGetWidth(surface: IOSurfaceRef) callconv(.c) usize;
pub extern fn IOSurfaceGetHeight(surface: IOSurfaceRef) callconv(.c) usize;
pub extern fn IOSurfaceGetPixelFormat(surface: IOSurfaceRef) callconv(.c) OSType;
