const cv = @import("main.zig").CoreVideo;
const cf = @import("main.zig").CoreFoundation;
const Boolean = @import("main.zig").Boolean;
const UInt32 = @import("main.zig").UInt32;

pub const CMTimeValue = i64;
pub const CMTimeScale = i32;
pub const CMTimeFlags = UInt32;
pub const CMTimeEpoch = i64;

pub const CMTime = extern struct {
    value: CMTimeValue align(4),
    timescale: CMTimeScale,
    flags: CMTimeFlags,
    epoch: CMTimeEpoch align(4),
};

pub const CMSampleBuffer = opaque {};
pub const CMSampleBufferRef = *CMSampleBuffer;

pub extern fn CMTimeMake(value: CMTimeValue, timescale: CMTimeScale) callconv(.c) CMTime;
pub extern fn CMSampleBufferIsValid(sample_buffer: CMSampleBufferRef) callconv(.c) Boolean;
pub extern fn CMSampleBufferGetImageBuffer(sample_buffer: CMSampleBufferRef) callconv(.c) ?cv.CVImageBufferRef;
pub extern fn CMSampleBufferGetSampleAttachmentsArray(sample_buffer: CMSampleBufferRef, create_if_necessary: Boolean) callconv(.c) ?cf.CFArrayRef;
