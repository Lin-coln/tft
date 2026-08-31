const OSType = @import("main.zig").OSType;

pub const CVOptionFlags = u64;
pub const CVReturn = i32;
pub const CVPixelBufferLockFlags = CVOptionFlags;

pub const CVBuffer = opaque {};
pub const CVBufferRef = *CVBuffer;
pub const CVImageBufferRef = CVBufferRef;
pub const CVPixelBufferRef = CVImageBufferRef;

pub const kCVPixelFormatType_32BGRA: OSType = 0x42475241;
pub const kCVPixelFormatType_ARGB2101010LEPacked: OSType = 0x6c313072;
pub const kCVPixelFormatType_64RGBAHalf: OSType = 0x52476841;

pub extern fn CVPixelBufferGetWidth(pixel_buffer: CVPixelBufferRef) callconv(.c) usize;
pub extern fn CVPixelBufferGetHeight(pixel_buffer: CVPixelBufferRef) callconv(.c) usize;
pub extern fn CVPixelBufferLockBaseAddress(pixel_buffer: CVPixelBufferRef, lock_flags: CVPixelBufferLockFlags) callconv(.c) CVReturn;
pub extern fn CVPixelBufferUnlockBaseAddress(pixel_buffer: CVPixelBufferRef, lock_flags: CVPixelBufferLockFlags) callconv(.c) CVReturn;
