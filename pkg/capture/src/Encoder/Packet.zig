const std = @import("std");
const macos = @import("macos");
const Frame = @import("../Renderer/Frame.zig");

const cm = macos.CoreMedia;
const cf = macos.CoreFoundation;

const Self = @This();

allocator: std.mem.Allocator,
ref_count: std.atomic.Value(usize),
data: []u8,
size: usize,
pts: u64,
duration: u64,
timebase_num: i32,
timebase_den: i32,
frame_count: u32,
keyframe: bool,

pub fn fromSampleBuffer(
    allocator: std.mem.Allocator,
    borrowed: *Frame,
    sample_buffer: cm.CMSampleBufferRef,
) !*Self {
    const attachment: ?cf.CFDictionaryRef = block: {
        const attachments = cm.CMSampleBufferGetSampleAttachmentsArray(sample_buffer, 0) orelse
            break :block null;
        if (cf.CFArrayGetCount(attachments) == 0) break :block null;
        const raw = cf.CFArrayGetValueAtIndex(attachments, 0) orelse
            break :block null;
        break :block @ptrCast(raw);
    };

    const keyframe = if (attachment) |value| block: {
        const not_sync_raw = cf.CFDictionaryGetValue(
            value,
            @ptrCast(cm.kCMSampleAttachmentKey_NotSync),
        ) orelse break :block true;
        const not_sync: cf.CFBooleanRef = @ptrCast(not_sync_raw);
        break :block cf.CFBooleanGetValue(not_sync) == 0;
    } else true;

    const pts, const duration, const timebase_num, const timebase_den = block: {
        const timebase_num: i32 = 1;
        const timebase_den: i32 = std.time.ns_per_s;
        const pts = std.math.cast(
            u64,
            @as(u128, borrowed.timestamp_ns) * @as(u128, @intCast(timebase_den)) /
                (@as(u128, std.time.ns_per_s) * @as(u128, @intCast(timebase_num))),
        ) orelse return error.InvalidTimestamp;
        const duration = std.math.cast(
            u64,
            @as(u128, borrowed.duration_ns) * @as(u128, @intCast(timebase_den)) /
                (@as(u128, std.time.ns_per_s) * @as(u128, @intCast(timebase_num))),
        ) orelse return error.InvalidDuration;
        break :block .{ pts, duration, timebase_num, timebase_den };
    };

    const data, const size = block: {
        const data_buffer = cm.CMSampleBufferGetDataBuffer(sample_buffer) orelse
            return error.MissingEncodedData;
        const size = cm.CMBlockBufferGetDataLength(data_buffer);
        if (size == 0) return error.MissingEncodedData;

        const data = try allocator.alloc(u8, size);
        errdefer allocator.free(data);

        if (cm.CMBlockBufferCopyDataBytes(data_buffer, 0, size, data.ptr) != 0)
            return error.EncodedDataCopyFailed;
        break :block .{ data, size };
    };
    errdefer allocator.free(data);

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .ref_count = .init(1),
        .data = data,
        .size = size,
        .pts = pts,
        .duration = duration,
        .timebase_num = timebase_num,
        .timebase_den = timebase_den,
        .frame_count = borrowed.frame_count,
        .keyframe = keyframe,
    };
    return self;
}

pub fn retain(self: *Self) *Self {
    const prev = self.ref_count.fetchAdd(1, .monotonic);
    std.debug.assert(prev > 0);
    return self;
}

pub fn release(self: *Self) void {
    const prev = self.ref_count.fetchSub(1, .acq_rel);
    std.debug.assert(prev > 0);
    if (prev != 1) return;

    self.allocator.free(self.data);
    self.allocator.destroy(self);
}
