const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const image_io = macos.ImageIO;
const Self = @This();

ci_context: objc.Object,
data: cf.CFMutableDataRef,
png_type: cf.CFStringRef,

pub fn init() !Self {
    const ci_context = @import("retainCIContext.zig").retainCIContext();
    if (ci_context.value == null) return error.CIContextCreationFailed;
    errdefer ci_context.release();

    const data = cf.CFDataCreateMutable(null, 0) orelse return error.PNGEncodingFailed;
    errdefer cf.CFRelease(data);
    const png_type = cf.CFStringCreateWithCString(null, "public.png", cf.kCFStringEncodingUTF8) orelse
        return error.PNGEncodingFailed;
    return .{ .ci_context = ci_context, .data = data, .png_type = png_type };
}

pub fn deinit(self: Self) void {
    cf.CFRelease(self.data);
    cf.CFRelease(self.png_type);
    self.ci_context.release();
}

/// Returns borrowed PNG bytes, invalidated by the next encode (even if it fails)
/// or deinit. Serialize encode and consumption of its bytes on this instance.
pub fn encode(self: *Self, surface: macos.IOSurface.IOSurfaceRef) ![]const u8 {
    cf.CFDataSetLength(self.data, 0);
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const ci_image = init: {
        const Class = objc.getClass("CIImage").?;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        break :init allocated.msgSend(
            objc.Object,
            "initWithIOSurface:",
            .{surface},
        );
    };
    if (ci_image.value == null) return error.CIImageCreationFailed;
    defer ci_image.release();

    const bounds = cg.CGRect{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{
            .width = @floatFromInt(
                macos.IOSurface.IOSurfaceGetWidth(surface),
            ),
            .height = @floatFromInt(
                macos.IOSurface.IOSurfaceGetHeight(surface),
            ),
        },
    };

    const image = self.ci_context.msgSend(
        ?cg.CGImageRef,
        "createCGImage:fromRect:",
        .{ ci_image, bounds },
    ) orelse return error.CGImageCreationFailed;
    defer cf.CFRelease(@ptrCast(image));

    // A finalized destination cannot be reused; only its output buffer is reused.
    const destination = image_io.CGImageDestinationCreateWithData(
        self.data,
        self.png_type,
        1,
        null,
    ) orelse return error.PNGEncodingFailed;
    defer cf.CFRelease(destination);

    image_io.CGImageDestinationAddImage(destination, image, null);
    if (!image_io.CGImageDestinationFinalize(destination)) return error.PNGEncodingFailed;

    const length: usize = @intCast(cf.CFDataGetLength(self.data));
    return cf.CFDataGetBytePtr(self.data)[0..length];
}

test "PNG buffer reuse handles changing dimensions and encoding failure" {
    var encoder = try Self.init();
    defer encoder.deinit();
    const large = try createTestSurface(64);
    defer cf.CFRelease(large);
    const small = try createTestSurface(16);
    defer cf.CFRelease(small);

    const context = encoder.ci_context;
    const first = try encoder.encode(large);
    try expectPng(first, 64);
    const copied = try std.testing.allocator.dupe(u8, first);
    defer std.testing.allocator.free(copied);

    const data = encoder.data;
    const png_type = encoder.png_type;
    try expectPng(try encoder.encode(small), 16);
    try std.testing.expect(encoder.ci_context.value == context.value);
    try std.testing.expect(encoder.data == data);
    try std.testing.expect(encoder.png_type == png_type);
    try expectPng(copied, 64);

    {
        // Simulate a failed render without changing ownership of the real context.
        encoder.ci_context = .{ .value = null };
        defer encoder.ci_context = context;
        try std.testing.expectError(error.CGImageCreationFailed, encoder.encode(small));
    }
    try expectPng(try encoder.encode(large), 64);
}

fn expectPng(bytes: []const u8, size: u32) !void {
    try std.testing.expect(bytes.len >= 33);
    try std.testing.expectEqualStrings("\x89PNG\r\n\x1a\n", bytes[0..8]);
    try std.testing.expectEqualStrings("IHDR", bytes[12..16]);
    try std.testing.expectEqual(size, std.mem.readInt(u32, bytes[16..20], .big));
    try std.testing.expectEqual(size, std.mem.readInt(u32, bytes[20..24], .big));
    var offset: usize = 8;
    while (offset < bytes.len) {
        try std.testing.expect(bytes.len - offset >= 12);
        const length: usize = std.mem.readInt(u32, bytes[offset..][0..4], .big);
        try std.testing.expect(length <= bytes.len - offset - 12);
        const end = offset + 12 + length;
        const crc = std.hash.crc.Crc32.hash(bytes[offset + 4 .. end - 4]);
        try std.testing.expectEqual(crc, std.mem.readInt(u32, bytes[end - 4 ..][0..4], .big));
        if (std.mem.eql(u8, bytes[offset + 4 ..][0..4], "IEND")) {
            try std.testing.expectEqual(@as(usize, 0), length);
            try std.testing.expectEqual(bytes.len, end);
            return;
        }
        offset = end;
    }
    return error.MissingPngEnd;
}

fn createTestSurface(size: i64) !macos.IOSurface.IOSurfaceRef {
    const ios = macos.IOSurface;
    const properties = cf.CFDictionaryCreateMutable(null, 0, null, null) orelse return error.TestAllocationFailed;
    defer cf.CFRelease(properties);
    const keys = [_]cf.CFStringRef{
        ios.kIOSurfaceWidth,           ios.kIOSurfaceHeight,
        ios.kIOSurfaceBytesPerElement, ios.kIOSurfacePixelFormat,
    };
    const values = [_]i64{ size, size, 4, macos.CoreVideo.kCVPixelFormatType_32BGRA };
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
