const std = @import("std");
const macos = @import("macos");

const ios = macos.IOSurface;
const cf = macos.CoreFoundation;
const IOSurfaceRef = ios.IOSurfaceRef;
const IOSurfaceIncrementUseCount = ios.IOSurfaceIncrementUseCount;
const IOSurfaceDecrementUseCount = ios.IOSurfaceDecrementUseCount;

const Self = @This();

allocator: std.mem.Allocator,
ref_count: std.atomic.Value(usize),
surface: IOSurfaceRef,
timestamp_ns: u64,
duration_ns: u64,
frame_count: u32,
width: i32,
height: i32,

pub fn init(
    allocator: std.mem.Allocator,
    surface: IOSurfaceRef,
    timestamp_ns: u64,
    duration_ns: u64,
    frame_count: u32,
) !*Self {
    _ = cf.CFRetain(@ptrCast(surface));
    IOSurfaceIncrementUseCount(surface);
    errdefer {
        IOSurfaceDecrementUseCount(surface);
        cf.CFRelease(@ptrCast(surface));
    }

    const width, const height = block: {
        const width = std.math.cast(i32, ios.IOSurfaceGetWidth(surface)) orelse
            return error.InvalidDimensions;
        const height = std.math.cast(i32, ios.IOSurfaceGetHeight(surface)) orelse
            return error.InvalidDimensions;

        if (width == 0 or height == 0) return error.InvalidDimensions;
        break :block .{ width, height };
    };

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .ref_count = .init(1),
        .surface = surface,
        .timestamp_ns = timestamp_ns,
        .duration_ns = duration_ns,
        .frame_count = frame_count,
        .width = width,
        .height = height,
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

    IOSurfaceDecrementUseCount(self.surface);
    cf.CFRelease(@ptrCast(self.surface));
    self.allocator.destroy(self);
}
