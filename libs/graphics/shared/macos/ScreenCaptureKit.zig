const ns = @import("main.zig").Foundation;

pub const SCStreamFrameInfo = *ns.NSString;

pub extern const SCStreamFrameInfoScaleFactor: SCStreamFrameInfo;
pub extern const SCStreamFrameInfoContentScale: SCStreamFrameInfo;
pub extern const SCStreamFrameInfoContentRect: SCStreamFrameInfo;

pub const SCShareableContent = opaque {};
pub const SCWindow = opaque {};
pub const SCContentFilter = opaque {};
pub const SCStreamConfiguration = opaque {};
