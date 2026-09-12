const std = @import("std");
const Surface = @import("Surface.zig");

const Self = @This();

allocator: std.mem.Allocator,
pts: std.Io.Timestamp,
duration: std.Io.Duration,

surface: *Surface,

pub fn create(
    allocator: std.mem.Allocator,
    surface: *Surface,
    pts: std.Io.Timestamp,
    duration: std.Io.Duration,
) !*Self {
    errdefer surface.release();

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .pts = pts,
        .duration = duration,
        .surface = surface,
    };
    return self;
}

pub fn addDuration(self: *Self, duration: std.Io.Duration) void {
    self.duration = .fromNanoseconds(
        self.duration.nanoseconds +| duration.nanoseconds,
    );
}

pub fn destroy(self: *Self) void {
    self.surface.release();
    self.allocator.destroy(self);
}
