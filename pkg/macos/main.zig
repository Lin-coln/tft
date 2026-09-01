pub const UInt32 = u32;
pub const FourCharCode = UInt32;
pub const OSType = FourCharCode;
pub const Boolean = u8;

pub const Foundation = @import("Foundation.zig");
pub const CoreFoundation = @import("CoreFoundation.zig");
pub const CoreGraphics = @import("CoreGraphics.zig");
pub const CoreVideo = @import("CoreVideo.zig");
pub const CoreMedia = @import("CoreMedia.zig");
pub const ImageIO = @import("ImageIO.zig");
pub const objc = @import("objc.zig");
pub const ScreenCaptureKit = @import("ScreenCaptureKit.zig");
