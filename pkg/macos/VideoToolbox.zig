const cf = @import("main.zig").CoreFoundation;
const cm = @import("main.zig").CoreMedia;
const cv = @import("main.zig").CoreVideo;

pub const OSStatus = @import("main.zig").OSStatus;
pub const VTEncodeInfoFlags = @import("main.zig").UInt32;

pub const kVTEncodeInfo_Asynchronous: VTEncodeInfoFlags = 1 << 0;
pub const kVTEncodeInfo_FrameDropped: VTEncodeInfoFlags = 1 << 1;

pub const VTCompressionSession = opaque {};
pub const VTCompressionSessionRef = *VTCompressionSession;
pub const VTSessionRef = cf.CFTypeRef;

pub extern const kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: cf.CFStringRef;
pub extern const kVTCompressionPropertyKey_RealTime: cf.CFStringRef;
pub extern const kVTCompressionPropertyKey_ExpectedFrameRate: cf.CFStringRef;
pub extern const kVTCompressionPropertyKey_AllowFrameReordering: cf.CFStringRef;
pub extern const kVTCompressionPropertyKey_ProfileLevel: cf.CFStringRef;
pub extern const kVTProfileLevel_H264_High_AutoLevel: cf.CFStringRef;

pub const VTCompressionOutputCallback = *const fn (
    output_callback_ref_con: ?*anyopaque,
    source_frame_ref_con: ?*anyopaque,
    status: OSStatus,
    info_flags: VTEncodeInfoFlags,
    sample_buffer: ?cm.CMSampleBufferRef,
) callconv(.c) void;

pub extern fn VTCompressionSessionCreate(
    allocator: ?cf.CFAllocatorRef,
    width: i32,
    height: i32,
    codec_type: cm.CMVideoCodecType,
    encoder_specification: ?cf.CFDictionaryRef,
    source_image_buffer_attributes: ?cf.CFDictionaryRef,
    compressed_data_allocator: ?cf.CFAllocatorRef,
    output_callback: ?VTCompressionOutputCallback,
    output_callback_ref_con: ?*anyopaque,
    compression_session_out: *?VTCompressionSessionRef,
) callconv(.c) OSStatus;

pub extern fn VTSessionSetProperty(
    session: VTSessionRef,
    property_key: cf.CFStringRef,
    property_value: ?cf.CFTypeRef,
) callconv(.c) OSStatus;

pub extern fn VTCompressionSessionPrepareToEncodeFrames(session: VTCompressionSessionRef) callconv(.c) OSStatus;
pub extern fn VTCompressionSessionEncodeFrame(
    session: VTCompressionSessionRef,
    image_buffer: cv.CVImageBufferRef,
    presentation_time_stamp: cm.CMTime,
    duration: cm.CMTime,
    frame_properties: ?cf.CFDictionaryRef,
    source_frame_ref_con: ?*anyopaque,
    info_flags_out: ?*VTEncodeInfoFlags,
) callconv(.c) OSStatus;
pub extern fn VTCompressionSessionCompleteFrames(
    session: VTCompressionSessionRef,
    complete_until_presentation_time_stamp: cm.CMTime,
) callconv(.c) OSStatus;
pub extern fn VTCompressionSessionInvalidate(session: VTCompressionSessionRef) callconv(.c) void;
