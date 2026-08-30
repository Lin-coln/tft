const cf = @import("main.zig").CoreFoundation;
const cg = @import("main.zig").CoreGraphics;

pub const CGImageDestination = opaque {};
pub const CGImageDestinationRef = *CGImageDestination;

pub extern fn CGImageDestinationCreateWithData(data: cf.CFMutableDataRef, image_type: cf.CFStringRef, count: usize, options: ?cf.CFDictionaryRef) callconv(.c) ?CGImageDestinationRef;
pub extern fn CGImageDestinationAddImage(destination: CGImageDestinationRef, image: cg.CGImageRef, properties: ?cf.CFDictionaryRef) callconv(.c) void;
pub extern fn CGImageDestinationFinalize(destination: CGImageDestinationRef) callconv(.c) bool;
