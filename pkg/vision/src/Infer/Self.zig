const std = @import("std");
const objc = @import("objc");

const Self = @This();

allocator: std.mem.Allocator,
candidate_count: usize,
request: objc.Object = undefined,
requests: objc.Object = undefined,

pub const Language = @import("createRequests.zig").Language;
pub const RecognitionLevel = @import("createRequests.zig").RecognitionLevel;
pub const Input = @import("createHandler.zig").Input;
pub const Region = @import("setRegionOfInterest.zig").Region;
pub const Results = @import("readResults.zig").Results;

pub const Options = struct {
    languages: []const Language = &.{ .simplified_chinese, .english_us },
    recognition_level: RecognitionLevel = .accurate,
    uses_language_correction: bool = false,
    minimum_text_height: f32 = 0,
    candidate_count: usize = 3,
};

pub const RunOptions = struct {
    region_of_interest: Region = .full,
};

pub fn create(allocator: std.mem.Allocator, options: Options) !*Self {
    if (options.candidate_count == 0) return error.InvalidOptions;

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .candidate_count = options.candidate_count,
    };
    try @import("createRequests.zig").createRequests(self, options);
    return self;
}

pub fn destroy(self: *Self) void {
    self.requests.release();
    self.request.release();
    self.allocator.destroy(self);
}

/// Synchronous; do not use the same instance concurrently.
/// Keep input storage alive and unchanged until this call returns.
pub fn run(self: *Self, input: Input, options: RunOptions) !Results {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    try @import("setRegionOfInterest.zig").setRegionOfInterest(self, options.region_of_interest);

    const handler = try @import("createHandler.zig").createHandler(input);
    defer handler.release();

    try @import("performRequests.zig").performRequests(self, handler);
    return @import("readResults.zig").readResults(self);
}

fn createAndDestroy(allocator: std.mem.Allocator) !void {
    const infer = try create(allocator, .{});
    defer infer.destroy();
}

test "create cleans up when allocation fails" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, createAndDestroy, .{});
}

test "create rejects invalid options" {
    try std.testing.expectError(error.InvalidOptions, create(std.testing.allocator, .{
        .candidate_count = 0,
    }));
    try std.testing.expectError(error.InvalidOptions, create(std.testing.allocator, .{
        .languages = &.{},
    }));
}

test "run accepts IOSurface and reuses the OCR request" {
    const macos = @import("macos");
    const cf = macos.CoreFoundation;
    const cv = macos.CoreVideo;
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

    const infer = try create(std.testing.allocator, .{});
    defer infer.destroy();
    for (0..2) |_| {
        const result = try infer.run(.{ .io_surface = surface }, .{});
        defer result.deinit();
    }
}
