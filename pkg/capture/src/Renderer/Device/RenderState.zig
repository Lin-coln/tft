const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const Allocator = std.mem.Allocator;
const cf = macos.CoreFoundation;
const cv = macos.CoreVideo;
const Self = @This();

allocator: Allocator,
background: @Vector(4, f32),
pixel_pool: cv.CVPixelBufferPoolRef,
texture_cache: cv.CVMetalTextureCacheRef,
width: usize,
height: usize,

pub fn create(allocator: Allocator, device: objc.Object, width: usize, height: usize) !*Self {
    if (width == 0 or height == 0) return error.InvalidDimensions;
    const pixel_pool = try createPixelPool(width, height);
    errdefer cf.CFRelease(@ptrCast(pixel_pool));

    var cache_ref: ?cv.CVMetalTextureCacheRef = null;
    if (cv.CVMetalTextureCacheCreate(null, null, device.value.?, null, &cache_ref) != 0)
        return error.TextureCacheCreationFailed;
    const texture_cache = cache_ref orelse return error.TextureCacheCreationFailed;
    errdefer cf.CFRelease(@ptrCast(texture_cache));

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .background = .{ 0.5, 0.5, 0.5, 1.0 },
        .pixel_pool = pixel_pool,
        .texture_cache = texture_cache,
        .width = width,
        .height = height,
    };
    return self;
}

pub fn destroy(self: *Self) void {
    cf.CFRelease(@ptrCast(self.texture_cache));
    cf.CFRelease(@ptrCast(self.pixel_pool));
    self.allocator.destroy(self);
}

fn createPixelPool(width: usize, height: usize) !cv.CVPixelBufferPoolRef {
    const surface_properties = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(surface_properties);

    const attributes = cf.CFDictionaryCreateMutable(
        null,
        0,
        &cf.kCFTypeDictionaryKeyCallBacks,
        &cf.kCFTypeDictionaryValueCallBacks,
    ) orelse return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(attributes);

    const width_value: i64 = @intCast(width);
    const width_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &width_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(width_number));
    const height_value: i64 = @intCast(height);
    const height_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &height_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(height_number));
    const format_value: i64 = cv.kCVPixelFormatType_32BGRA;
    const format_number = cf.CFNumberCreate(null, cf.kCFNumberSInt64Type, &format_value) orelse
        return error.PixelBufferAttributesCreationFailed;
    defer cf.CFRelease(@ptrCast(format_number));

    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferWidthKey, width_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferHeightKey, height_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferPixelFormatTypeKey, format_number);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferMetalCompatibilityKey, cf.kCFBooleanTrue);
    cf.CFDictionarySetValue(attributes, cv.kCVPixelBufferIOSurfacePropertiesKey, surface_properties);

    var pool_ref: ?cv.CVPixelBufferPoolRef = null;
    if (cv.CVPixelBufferPoolCreate(null, null, attributes, &pool_ref) != 0)
        return error.PixelBufferPoolCreationFailed;
    const pixel_pool = pool_ref orelse return error.PixelBufferPoolCreationFailed;
    errdefer cf.CFRelease(@ptrCast(pixel_pool));
    return pixel_pool;
}
