const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const cf = macos.CoreFoundation;
const ios = macos.IOSurface;
const Self = @This();

allocator: std.mem.Allocator,
ref: ios.IOSurfaceRef,
texture: objc.Object,
ref_count: std.atomic.Value(usize),

pub fn create(
    allocator: std.mem.Allocator,
    ref: ios.IOSurfaceRef,
    texture: objc.Object,
) !*Self {
    errdefer texture.release();

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    _ = cf.CFRetain(@ptrCast(ref));
    ios.IOSurfaceIncrementUseCount(ref);
    self.* = .{
        .allocator = allocator,
        .ref = ref,
        .texture = texture,
        .ref_count = .init(1),
    };
    return self;
}

pub fn retain(self: *Self) *Self {
    const prev = self.ref_count.fetchAdd(1, .monotonic);
    std.debug.assert(prev > 0);
    return self;
}

pub fn tryRetainAvailable(self: *Self) bool {
    return self.ref_count.cmpxchgStrong(1, 2, .acq_rel, .acquire) == null;
}

pub fn release(self: *Self) void {
    const prev = self.ref_count.fetchSub(1, .acq_rel);
    std.debug.assert(prev > 0);
    if (prev != 1) return;

    self.texture.release();
    ios.IOSurfaceDecrementUseCount(self.ref);
    cf.CFRelease(@ptrCast(self.ref));
    self.allocator.destroy(self);
}
