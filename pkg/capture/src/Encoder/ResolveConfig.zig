const std = @import("std");
const macos = @import("macos");

const cm = macos.CoreMedia;

const Self = @This();

allocator: std.mem.Allocator,
ref_count: std.atomic.Value(usize),
data: []u8,
size: usize,
width: u32,
height: u32,
nal_length_size: u8,

pub fn fromSampleBuffer(
    allocator: std.mem.Allocator,
    sample_buffer: cm.CMSampleBufferRef,
) !*Self {
    const format = cm.CMSampleBufferGetFormatDescription(sample_buffer) orelse
        return error.MissingFormatDescription;

    const sps, const pps, const nal_length_size = block: {
        var parameter_set_count: usize = 0;
        var nal_length_size: c_int = 0;
        if (cm.CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            0,
            null,
            null,
            &parameter_set_count,
            &nal_length_size,
        ) != 0 or parameter_set_count < 2) return error.MissingParameterSets;

        var sps_ptr: ?[*]const u8 = null;
        var sps_size: usize = 0;
        if (cm.CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            0,
            &sps_ptr,
            &sps_size,
            null,
            null,
        ) != 0 or sps_ptr == null) return error.MissingSPS;

        var pps_ptr: ?[*]const u8 = null;
        var pps_size: usize = 0;
        if (cm.CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            1,
            &pps_ptr,
            &pps_size,
            null,
            null,
        ) != 0 or pps_ptr == null) return error.MissingPPS;

        if (sps_size < 4 or sps_size > std.math.maxInt(u16))
            return error.InvalidSPS;
        if (pps_size == 0 or pps_size > std.math.maxInt(u16))
            return error.InvalidPPS;
        if (nal_length_size < 1 or nal_length_size > 4)
            return error.InvalidNALLengthSize;

        break :block .{
            sps_ptr.?[0..sps_size],
            pps_ptr.?[0..pps_size],
            @as(u8, @intCast(nal_length_size)),
        };
    };

    const data, const size = block: {
        const size = 11 + sps.len + pps.len;
        const data = try allocator.alloc(u8, size);
        errdefer allocator.free(data);

        data[0] = 1;
        data[1] = sps[1];
        data[2] = sps[2];
        data[3] = sps[3];
        data[4] = 0xfc | (nal_length_size - 1);
        data[5] = 0xe1;
        std.mem.writeInt(u16, data[6..8], @intCast(sps.len), .big);
        @memcpy(data[8..][0..sps.len], sps);

        var offset = 8 + sps.len;
        data[offset] = 1;
        offset += 1;
        std.mem.writeInt(u16, data[offset..][0..2], @intCast(pps.len), .big);
        offset += 2;
        @memcpy(data[offset..][0..pps.len], pps);

        break :block .{ data, size };
    };
    errdefer allocator.free(data);

    const width, const height = block: {
        const dimensions = cm.CMVideoFormatDescriptionGetDimensions(format);
        const width = std.math.cast(u32, dimensions.width) orelse
            return error.InvalidDimensions;
        const height = std.math.cast(u32, dimensions.height) orelse
            return error.InvalidDimensions;
        if (width == 0 or height == 0) return error.InvalidDimensions;
        break :block .{ width, height };
    };

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .ref_count = .init(1),
        .data = data,
        .size = size,
        .width = width,
        .height = height,
        .nal_length_size = nal_length_size,
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
