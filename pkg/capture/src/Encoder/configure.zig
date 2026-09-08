const std = @import("std");
const macos = @import("macos");
const Frame = @import("../Renderer/Frame.zig");
const Self = @import("Self.zig");
const Packet = Self.Packet;
const ResolveConfig = Self.ResolveConfig;

const cf = macos.CoreFoundation;
const cm = macos.CoreMedia;
const vt = macos.VideoToolbox;

pub const Config = struct {
    width: i32,
    height: i32,
    framerate: i32,
};

pub fn configure(self: *Self, cfg: Config) !void {
    if (self.session != null) return error.AlreadyConfigured;
    if (cfg.width <= 0 or cfg.height <= 0 or cfg.framerate <= 0)
        return error.InvalidOptions;

    const spec = block: {
        const keys = [_]cf.CFTypeRef{
            @ptrCast(vt.kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder),
        };
        const values = [_]cf.CFTypeRef{
            @ptrCast(cf.kCFBooleanTrue),
        };
        break :block cf.CFDictionaryCreate(
            null,
            &keys,
            &values,
            keys.len,
            null,
            null,
        ) orelse return error.EncoderSpecificationCreationFailed;
    };
    defer cf.CFRelease(@ptrCast(spec));

    const session = block: {
        var session: ?vt.VTCompressionSessionRef = null;
        const status = vt.VTCompressionSessionCreate(
            null,
            cfg.width,
            cfg.height,
            cm.kCMVideoCodecType_H264,
            spec,
            null,
            null,
            handleCallback,
            self,
            &session,
        );
        if (status != 0) return error.SessionCreationFailed;
        break :block session orelse return error.SessionCreationFailed;
    };
    errdefer {
        vt.VTCompressionSessionInvalidate(session);
        cf.CFRelease(@ptrCast(session));
    }

    try setProperty(session, vt.kVTCompressionPropertyKey_RealTime, @ptrCast(cf.kCFBooleanTrue));
    try setProperty(session, vt.kVTCompressionPropertyKey_AllowFrameReordering, @ptrCast(cf.kCFBooleanFalse));
    try setProperty(session, vt.kVTCompressionPropertyKey_ProfileLevel, @ptrCast(vt.kVTProfileLevel_H264_High_AutoLevel));

    const framerate = cf.CFNumberCreate(null, cf.kCFNumberSInt32Type, &cfg.framerate) orelse
        return error.FramerateCreationFailed;
    defer cf.CFRelease(@ptrCast(framerate));
    try setProperty(session, vt.kVTCompressionPropertyKey_ExpectedFrameRate, @ptrCast(framerate));

    // TODO: Configure kVTCompressionPropertyKey_AverageBitRate when bitrate control is required.

    if (vt.VTCompressionSessionPrepareToEncodeFrames(session) != 0)
        return error.SessionPreparationFailed;

    self.cfg = cfg;
    self.session = session;
}

fn setProperty(session: vt.VTCompressionSessionRef, key: cf.CFStringRef, value: cf.CFTypeRef) !void {
    if (vt.VTSessionSetProperty(@ptrCast(session), key, value) != 0)
        return error.SessionPropertyConfigurationFailed;
}

fn handleCallback(
    self_raw: ?*anyopaque,
    frame_raw: ?*anyopaque,
    status: vt.OSStatus,
    info_flags: vt.VTEncodeInfoFlags,
    sample_buffer: ?cm.CMSampleBufferRef,
) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(self_raw orelse return));
    const frame: *Frame = @ptrCast(@alignCast(frame_raw orelse return));
    defer frame.release();

    if (status != 0) {
        self.handle_error(self.ctx, error.EncodeFailed);
        return;
    }

    if (info_flags & vt.kVTEncodeInfo_FrameDropped != 0) {
        Self.log.warn("frame dropped: timestamp_ns={d}, frame_count={d}", .{
            frame.timestamp_ns,
            frame.frame_count,
        });
        return;
    }

    if (sample_buffer) |encoded| {
        handleUpdateResolveConfig(self, encoded) catch |err| {
            self.handle_error(self.ctx, err);
            return;
        };
        self.handle_output(self.ctx, frame, encoded) catch |err| {
            self.handle_error(self.ctx, err);
        };
    } else {
        self.handle_error(self.ctx, error.MissingEncodedSample);
    }
}

fn handleUpdateResolveConfig(
    self: *Self,
    sample_buffer: cm.CMSampleBufferRef,
) !void {
    std.Io.Threaded.mutexLock(&self.cfg_resolved_mutex);
    if (self.cfg_resolved != null) {
        std.Io.Threaded.mutexUnlock(&self.cfg_resolved_mutex);
        return;
    }
    std.Io.Threaded.mutexUnlock(&self.cfg_resolved_mutex);

    const cfg = try ResolveConfig.fromSampleBuffer(self.allocator, sample_buffer);
    errdefer cfg.release();

    std.Io.Threaded.mutexLock(&self.cfg_resolved_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.cfg_resolved_mutex);

    if (self.cfg_resolved != null) {
        cfg.release();
        return;
    }
    self.cfg_resolved = cfg;
}
