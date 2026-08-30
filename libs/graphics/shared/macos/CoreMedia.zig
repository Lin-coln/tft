const cv = @import("main.zig").CoreVideo;

pub const opaqueCMSampleBuffer = opaque {};
pub const CMSampleBufferRef = *opaqueCMSampleBuffer;

pub extern fn CMSampleBufferGetImageBuffer(sample_buffer: CMSampleBufferRef) callconv(.c) ?cv.CVImageBufferRef;
