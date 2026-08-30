const Boolean = @import("main.zig").Boolean;
const UInt32 = @import("main.zig").UInt32;

pub const CFIndex = isize;
pub const CFNumberType = CFIndex;
pub const CFStringEncoding = UInt32;

pub const CFTypeRef = *const anyopaque;
pub const CFAllocator = opaque {};
pub const CFAllocatorRef = *const CFAllocator;
pub const CFArray = opaque {};
pub const CFArrayRef = *const CFArray;
pub const CFArrayCallBacks = opaque {};
pub const CFDictionary = opaque {};
pub const CFDictionaryRef = *const CFDictionary;
pub const CFMutableDictionaryRef = *CFDictionary;
pub const CFString = opaque {};
pub const CFStringRef = *const CFString;
pub const CFNumber = opaque {};
pub const CFNumberRef = *const CFNumber;
pub const CFDictionaryKeyCallBacks = opaque {};
pub const CFDictionaryValueCallBacks = opaque {};

pub const kCFNumberSInt32Type: CFNumberType = 3;
pub const kCFNumberSInt64Type: CFNumberType = 4;
pub const kCFNumberFloatType: CFNumberType = 12;
pub const kCFStringEncodingUTF8: CFStringEncoding = 0x08000100;

pub extern fn CFRetain(value: CFTypeRef) callconv(.c) CFTypeRef;
pub extern fn CFRelease(value: CFTypeRef) callconv(.c) void;
pub extern fn CFArrayGetCount(array: CFArrayRef) callconv(.c) CFIndex;
pub extern fn CFArrayGetValueAtIndex(array: CFArrayRef, index: CFIndex) callconv(.c) ?*const anyopaque;
pub extern fn CFArrayCreate(allocator: ?CFAllocatorRef, values: ?[*]const CFTypeRef, count: CFIndex, callbacks: ?*const CFArrayCallBacks) callconv(.c) ?CFArrayRef;
pub extern fn CFDictionaryGetValue(dictionary: CFDictionaryRef, key: *const anyopaque) callconv(.c) ?*const anyopaque;
pub extern fn CFDictionaryCreateMutable(allocator: ?CFAllocatorRef, capacity: CFIndex, key_callbacks: ?*const CFDictionaryKeyCallBacks, value_callbacks: ?*const CFDictionaryValueCallBacks) callconv(.c) ?CFMutableDictionaryRef;
pub extern fn CFDictionarySetValue(dictionary: CFMutableDictionaryRef, key: *const anyopaque, value: *const anyopaque) callconv(.c) void;
pub extern fn CFNumberCreate(allocator: ?CFAllocatorRef, number_type: CFNumberType, value: *const anyopaque) callconv(.c) ?CFNumberRef;
pub extern fn CFNumberGetValue(number: CFNumberRef, number_type: CFNumberType, value: *anyopaque) callconv(.c) Boolean;
pub extern fn CFStringGetLength(value: CFStringRef) callconv(.c) CFIndex;
pub extern fn CFStringGetMaximumSizeForEncoding(length: CFIndex, encoding: CFStringEncoding) callconv(.c) CFIndex;
pub extern fn CFStringGetCString(value: CFStringRef, buffer: [*]u8, size: CFIndex, encoding: CFStringEncoding) callconv(.c) Boolean;
