const ns = @import("main.zig").Foundation;

pub const SCStreamFrameInfo = *ns.NSString;

pub const SCCaptureResolutionType = ns.NSInteger;
pub const SCCaptureResolutionAutomatic: SCCaptureResolutionType = 0;
pub const SCCaptureResolutionBest: SCCaptureResolutionType = 1;
pub const SCCaptureResolutionNominal: SCCaptureResolutionType = 2;

pub extern const SCStreamFrameInfoScaleFactor: SCStreamFrameInfo;
pub extern const SCStreamFrameInfoContentScale: SCStreamFrameInfo;
pub extern const SCStreamFrameInfoContentRect: SCStreamFrameInfo;

pub const SCShareableContent = opaque {};
pub const SCWindow = opaque {};
pub const SCContentFilter = opaque {};
pub const SCStreamConfiguration = opaque {};
