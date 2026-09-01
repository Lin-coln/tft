pub const ObjcClass = opaque {};
pub const ObjcObject = opaque {};
pub const ObjcSelector = opaque {};

pub const BOOL = i8;

pub extern fn objc_getClass(name: [*:0]const u8) callconv(.c) ?*ObjcClass;
pub extern fn sel_registerName(name: [*:0]const u8) callconv(.c) *ObjcSelector;
pub extern fn objc_msgSend() callconv(.c) void;
pub extern fn objc_msgSend_stret() callconv(.c) void;

pub extern var _NSConcreteStackBlock: [32]?*anyopaque;

pub extern fn _Block_copy(block: *const anyopaque) callconv(.c) *anyopaque;
pub extern fn _Block_release(block: *const anyopaque) callconv(.c) void;
