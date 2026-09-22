const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");
const Capture = @import("tft/capture").Capture;
const Texture = @import("tft/stream").Texture;

const Allocator = std.mem.Allocator;
const ios = macos.IOSurface;
const mtl = macos.Metal;

const Self = @This();

allocator: Allocator,
capture: ?*Capture,

pub fn create(allocator: Allocator, opts: struct {
    target: objc.Object,
    frame_interval_value: i64,
    frame_interval_timescale: i32,
    shows_cursor: bool,
}) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .capture = undefined };
    self.capture = try Capture.init(allocator, .{
        .target = opts.target,
        .frame_interval_value = opts.frame_interval_value,
        .frame_interval_timescale = opts.frame_interval_timescale,
        .shows_cursor = opts.shows_cursor,
    });
    errdefer self.capture.?.deinit();
    return self;
}

pub fn destroy(self: *Self) void {
    if (self.capture) |capture| capture.deinit();
    self.allocator.destroy(self);
}

pub fn getSurface(self: *Self) ?@import("tft/capture").Surface {
    const capture = self.capture orelse return null;
    return capture.get_surface();
}

pub fn getTexture(self: *Self, device: objc.Object) !?*Texture {
    const surface = self.getSurface() orelse return null;
    defer surface.deinit();

    return try Texture.fromIOSurface(self.allocator, .{
        .device = device,
        .width = ios.IOSurfaceGetWidth(surface.ref),
        .height = ios.IOSurfaceGetHeight(surface.ref),
        .surface = surface.ref,
        .usage = mtl.MTLTextureUsageShaderRead,
        .storage_mode = mtl.MTLStorageModeShared,
    });
}

pub fn calcRect(_: *Self, canvas: @Vector(2, f32)) @Vector(2, f32) {
    return canvas / @as(@Vector(2, f32), @splat(2));
}
