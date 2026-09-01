const cf = @import("main.zig").CoreFoundation;

pub const CGFloat = f64;
pub const CGWindowID = u32;
pub const CGWindowListOption = u32;

pub const CGColor = opaque {};
pub const CGColorRef = *CGColor;
pub const CGColorSpace = opaque {};
pub const CGColorSpaceRef = *CGColorSpace;
pub const CGImage = opaque {};
pub const CGImageRef = *CGImage;

pub const CGPoint = extern struct { x: CGFloat, y: CGFloat };
pub const CGSize = extern struct { width: CGFloat, height: CGFloat };
pub const CGRect = extern struct { origin: CGPoint, size: CGSize };

pub const kCGWindowListOptionAll: CGWindowListOption = 0;
pub const kCGWindowListOptionOnScreenOnly: CGWindowListOption = 1 << 0;
pub const kCGWindowListExcludeDesktopElements: CGWindowListOption = 1 << 4;
pub const kCGNullWindowID: CGWindowID = 0;
pub const kCGWindowIDCFNumberType = cf.kCFNumberSInt32Type;

pub extern const kCGWindowNumber: cf.CFStringRef;
pub extern const kCGWindowLayer: cf.CFStringRef;
pub extern const kCGWindowBounds: cf.CFStringRef;
pub extern const kCGWindowOwnerName: cf.CFStringRef;
pub extern const kCGWindowName: cf.CFStringRef;
pub extern const kCGColorSpaceDisplayP3: cf.CFStringRef;
pub extern const kCGColorSpaceSRGB: cf.CFStringRef;
pub extern const kCGColorClear: cf.CFStringRef;

pub extern fn CGRectMakeWithDictionaryRepresentation(dictionary: ?cf.CFDictionaryRef, rect: ?*CGRect) callconv(.c) bool;
pub extern fn CGWindowListCopyWindowInfo(options: CGWindowListOption, relative_to: CGWindowID) callconv(.c) ?cf.CFArrayRef;
pub extern fn CGWindowListCreateDescriptionFromArray(window_ids: ?cf.CFArrayRef) callconv(.c) ?cf.CFArrayRef;
pub extern fn CGPreflightScreenCaptureAccess() callconv(.c) bool;
pub extern fn CGRequestScreenCaptureAccess() callconv(.c) bool;
pub extern fn CGColorGetConstantColor(name: ?cf.CFStringRef) callconv(.c) ?CGColorRef;
pub extern fn CGColorSpaceCreateWithName(name: ?cf.CFStringRef) callconv(.c) ?CGColorSpaceRef;
