const std = @import("std");
const macos = @import("macos");
const cv = macos.CoreVideo;
const Self = @import("Self.zig");

fn initAndDeinit(allocator: std.mem.Allocator) !void {
    const infer = try Self.init(.{ .allocator = allocator });
    defer infer.deinit();
}

test "init cleans up when allocation fails" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, initAndDeinit, .{});
}

test "init rejects invalid options" {
    try std.testing.expectError(error.InvalidOptions, Self.init(.{
        .allocator = std.testing.allocator,
        .candidate_count = 0,
    }));
    try std.testing.expectError(error.InvalidOptions, Self.init(.{
        .allocator = std.testing.allocator,
        .languages = &.{},
    }));
}

test "run accepts IOSurface and reuses the OCR request" {
    const cf = macos.CoreFoundation;
    const ios = macos.IOSurface;
    const properties = cf.CFDictionaryCreateMutable(null, 0, null, null) orelse
        return error.TestAllocationFailed;
    defer cf.CFRelease(properties);

    const keys = [_]cf.CFStringRef{
        ios.kIOSurfaceWidth,
        ios.kIOSurfaceHeight,
        ios.kIOSurfaceBytesPerElement,
        ios.kIOSurfacePixelFormat,
    };
    const values = [_]i64{ 64, 64, 4, cv.kCVPixelFormatType_32BGRA };
    var numbers: [values.len]cf.CFNumberRef = undefined;
    var initialized: usize = 0;
    defer for (numbers[0..initialized]) |number| cf.CFRelease(number);
    for (keys, values, 0..) |key, value, index| {
        numbers[index] = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &value) orelse
            return error.TestAllocationFailed;
        initialized += 1;
        cf.CFDictionarySetValue(properties, key, numbers[index]);
    }
    const surface = ios.IOSurfaceCreate(properties) orelse return error.TestSurfaceCreationFailed;
    defer cf.CFRelease(surface);

    const infer = try Self.init(.{ .allocator = std.testing.allocator });
    defer infer.deinit();
    for (0..2) |_| {
        const result = try infer.run(.{ .io_surface = surface }, .{});
        defer result.deinit();
    }
}
