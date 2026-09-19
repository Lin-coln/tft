const std = @import("std");
const macos = @import("macos");
const cv = macos.CoreVideo;
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
pts: std.Io.Timestamp,
duration: std.Io.Duration,

image_buffer: cv.CVImageBufferRef,

pub fn create(
    allocator: Allocator,
    image_buffer: cv.CVImageBufferRef,
    pts: std.Io.Timestamp,
    duration: std.Io.Duration,
) !*Self {
    errdefer cv.CVBufferRelease(image_buffer);

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .pts = pts,
        .duration = duration,
        .image_buffer = image_buffer,
    };
    return self;
}

pub fn destroy(self: *Self) void {
    cv.CVBufferRelease(self.image_buffer);
    self.allocator.destroy(self);
}

pub fn addDuration(self: *Self, duration: std.Io.Duration) void {
    self.duration = .fromNanoseconds(
        self.duration.nanoseconds +| duration.nanoseconds,
    );
}
