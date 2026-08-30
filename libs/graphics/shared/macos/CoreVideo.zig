pub const __CVBuffer = opaque {};
pub const CVBufferRef = *__CVBuffer;
pub const CVImageBufferRef = CVBufferRef;
pub const CVPixelBufferRef = CVImageBufferRef;

pub extern fn CVPixelBufferGetWidth(pixel_buffer: CVPixelBufferRef) callconv(.c) usize;
pub extern fn CVPixelBufferGetHeight(pixel_buffer: CVPixelBufferRef) callconv(.c) usize;
