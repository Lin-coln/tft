const std = @import("std");
const macos = @import("macos");
const Capture = @import("Self.zig");
const Surface = @import("_update_surface.zig").Surface;
const cf = macos.CoreFoundation;
const ios = macos.IOSurface;

extern "c" fn IOSurfaceGetUseCount(surface: ios.IOSurfaceRef) i32;

test "get_surface keeps the slot and readers survive replacement" {
    const ref = try createSurface();
    defer cf.CFRelease(ref);
    var capture: Capture = undefined;
    capture.output_mutex = .init;
    capture.surface = Surface.init(ref);
    defer @import("_update_surface.zig")._update(&capture, null);

    const first = capture.get_surface().?;
    const second = capture.get_surface().?;
    try std.testing.expect(capture.surface != null);
    try std.testing.expectEqual(@as(i32, 3), IOSurfaceGetUseCount(ref));

    @import("_update_surface.zig")._update(&capture, null);
    try std.testing.expect(capture.get_surface() == null);
    try std.testing.expectEqual(@as(i32, 2), IOSurfaceGetUseCount(ref));
    try std.testing.expectEqual(@as(usize, 64), ios.IOSurfaceGetWidth(first.ref));
    first.deinit();
    second.deinit();
    try std.testing.expectEqual(@as(i32, 0), IOSurfaceGetUseCount(ref));
}

test "multiple readers retain surfaces while the producer replaces them" {
    const first = try createSurface();
    defer cf.CFRelease(first);
    const second = try createSurface();
    defer cf.CFRelease(second);

    var capture: Capture = undefined;
    capture.output_mutex = .init;
    capture.surface = Surface.init(first);
    defer @import("_update_surface.zig")._update(&capture, null);

    var threads: [4]std.Thread = undefined;
    var started: usize = 0;
    {
        defer for (threads[0..started]) |thread| thread.join();
        for (&threads) |*thread| {
            thread.* = try std.Thread.spawn(.{}, readSurfaces, .{&capture});
            started += 1;
        }
        for (0..1000) |index| {
            std.Io.Threaded.mutexLock(&capture.output_mutex);
            @import("_update_surface.zig")._update(&capture, Surface.init(if (index % 2 == 0) first else second));
            std.Io.Threaded.mutexUnlock(&capture.output_mutex);
        }
    }
    @import("_update_surface.zig")._update(&capture, null);
    try std.testing.expectEqual(@as(i32, 0), IOSurfaceGetUseCount(first));
    try std.testing.expectEqual(@as(i32, 0), IOSurfaceGetUseCount(second));
}

fn readSurfaces(capture: *Capture) void {
    for (0..1000) |_| {
        const surface = capture.get_surface() orelse continue;
        defer surface.deinit();
        std.debug.assert(ios.IOSurfaceGetWidth(surface.ref) == 64);
    }
}

fn createSurface() !ios.IOSurfaceRef {
    const properties = cf.CFDictionaryCreateMutable(null, 0, null, null) orelse return error.TestAllocationFailed;
    defer cf.CFRelease(properties);
    const keys = [_]cf.CFStringRef{
        ios.kIOSurfaceWidth,           ios.kIOSurfaceHeight,
        ios.kIOSurfaceBytesPerElement, ios.kIOSurfacePixelFormat,
    };
    const values = [_]i64{ 64, 64, 4, macos.CoreVideo.kCVPixelFormatType_32BGRA };
    var numbers: [values.len]cf.CFNumberRef = undefined;
    var initialized: usize = 0;
    defer for (numbers[0..initialized]) |number| cf.CFRelease(number);
    for (keys, values, 0..) |key, value, index| {
        numbers[index] = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &value) orelse return error.TestAllocationFailed;
        initialized += 1;
        cf.CFDictionarySetValue(properties, key, numbers[index]);
    }
    return ios.IOSurfaceCreate(properties) orelse error.TestSurfaceCreationFailed;
}
