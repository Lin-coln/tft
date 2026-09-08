const cv = @import("main.zig").CoreVideo;
const cf = @import("main.zig").CoreFoundation;
const Boolean = @import("main.zig").Boolean;
const OSStatus = @import("main.zig").OSStatus;
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

pub const CMVideoCodecType = @import("main.zig").FourCharCode;
pub const kCMVideoCodecType_H264: CMVideoCodecType = 0x61766331;

pub extern const kCMTimeInvalid: CMTime;

pub const CMSampleBuffer = opaque {};
pub const CMSampleBufferRef = *CMSampleBuffer;
pub const CMFormatDescription = opaque {};
pub const CMFormatDescriptionRef = *CMFormatDescription;
pub const CMVideoFormatDescriptionRef = CMFormatDescriptionRef;
pub const CMVideoDimensions = extern struct {
    width: i32,
    height: i32,
};
pub const CMBlockBuffer = opaque {};
pub const CMBlockBufferRef = *CMBlockBuffer;

pub extern const kCMSampleAttachmentKey_NotSync: cf.CFStringRef;

pub extern fn CMTimeMake(value: CMTimeValue, timescale: CMTimeScale) callconv(.c) CMTime;
pub extern fn CMSampleBufferIsValid(sample_buffer: CMSampleBufferRef) callconv(.c) Boolean;
pub extern fn CMSampleBufferGetFormatDescription(sample_buffer: CMSampleBufferRef) callconv(.c) ?CMFormatDescriptionRef;
pub extern fn CMSampleBufferGetDataBuffer(sample_buffer: CMSampleBufferRef) callconv(.c) ?CMBlockBufferRef;
pub extern fn CMSampleBufferGetImageBuffer(sample_buffer: CMSampleBufferRef) callconv(.c) ?cv.CVImageBufferRef;
pub extern fn CMSampleBufferGetSampleAttachmentsArray(sample_buffer: CMSampleBufferRef, create_if_necessary: Boolean) callconv(.c) ?cf.CFArrayRef;
pub extern fn CMBlockBufferGetDataLength(buffer: CMBlockBufferRef) callconv(.c) usize;
pub extern fn CMBlockBufferCopyDataBytes(
    source_buffer: CMBlockBufferRef,
    offset_to_data: usize,
    data_length: usize,
    destination: *anyopaque,
) callconv(.c) OSStatus;
pub extern fn CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
    video_description: CMFormatDescriptionRef,
    parameter_set_index: usize,
    parameter_set_pointer_out: ?*?[*]const u8,
    parameter_set_size_out: ?*usize,
    parameter_set_count_out: ?*usize,
    nal_unit_header_length_out: ?*c_int,
) callconv(.c) OSStatus;
pub extern fn CMVideoFormatDescriptionGetDimensions(
    video_description: CMVideoFormatDescriptionRef,
) callconv(.c) CMVideoDimensions;
