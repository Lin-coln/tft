const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const SCContentFilter = @import("sc/SCContentFilter.zig");
const SCStreamConfiguration = @import("sc/SCStreamConfiguration.zig");
const retainShareableContent = @import("sc/retainShareableContent.zig").retainShareableContent;
const retainSampleBuffer = @import("sc/retainSampleBuffer.zig").retainSampleBuffer;

const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const image_io = macos.ImageIO;

pub fn screenshot(allocator: std.mem.Allocator, window_id: u32) ![]u8 {
    if (window_id == cg.kCGNullWindowID) return error.InvalidWindowId;
    if (!cg.CGPreflightScreenCaptureAccess()) return error.ScreenCaptureKitUnavailable;

    const content = retainShareableContent() orelse return error.ScreenCaptureKitUnavailable;
    defer content.release();

    const target = find_window(content, window_id) orelse return error.ScreenshotTargetNotFound;
    defer target.release();

    const config = try SCStreamConfiguration.init();
    defer config.deinit();

    const frame = target.msgSend(cg.CGRect, "frame", .{});
    config.setWidth(initial_dimension(frame.size.width));
    config.setHeight(initial_dimension(frame.size.height));
    // config.setQueueDepth(8);
    config.setPixelFormat(cv.kCVPixelFormatType_ARGB2101010LEPacked);
    config.setColorSpaceName(cg.kCGColorSpaceDisplayP3);
    config.setShowsCursor(false);

    const filter = try SCContentFilter.initWithDesktopIndependentWindow(target);
    defer filter.deinit();

    const buffer = retainSampleBuffer(filter.obj, config.obj) orelse
        return error.ScreenCaptureKitUnavailable;
    defer buffer.release();

    return encode_png(allocator, buffer);
}

fn encode_png(allocator: std.mem.Allocator, sample_buffer: objc.Object) ![]u8 {
    const sample_buffer_ref: cm.CMSampleBufferRef = @ptrCast(@alignCast(sample_buffer.value));
    const pixel_buffer = cm.CMSampleBufferGetImageBuffer(sample_buffer_ref) orelse
        return error.SampleBufferHasNoImage;

    const ci_image_class = objc.getClass("CIImage") orelse return error.CoreImageUnavailable;
    const ci_image = ci_image_class.msgSend(objc.Object, "alloc", .{});
    if (ci_image.value == null) return error.CoreImageUnavailable;
    const initialized_image = ci_image.msgSend(objc.Object, "initWithCVPixelBuffer:", .{pixel_buffer});
    if (initialized_image.value == null) return error.CoreImageUnavailable;
    defer initialized_image.release();

    const ci_context_class = objc.getClass("CIContext") orelse return error.CoreImageUnavailable;
    const ci_context = ci_context_class.msgSend(objc.Object, "alloc", .{});
    if (ci_context.value == null) return error.CoreImageUnavailable;
    const initialized_context = ci_context.msgSend(objc.Object, "initWithOptions:", .{@as(objc.c.id, null)});
    if (initialized_context.value == null) return error.CoreImageUnavailable;
    defer initialized_context.release();

    const bounds = cg.CGRect{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{
            .width = @floatFromInt(cv.CVPixelBufferGetWidth(pixel_buffer)),
            .height = @floatFromInt(cv.CVPixelBufferGetHeight(pixel_buffer)),
        },
    };
    const image = initialized_context.msgSend(?cg.CGImageRef, "createCGImage:fromRect:", .{
        initialized_image,
        bounds,
    }) orelse return error.CGImageCreationFailed;
    defer cf.CFRelease(@ptrCast(image));

    const data = cf.CFDataCreateMutable(null, 0) orelse return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(data));

    const png_type = cf.CFStringCreateWithCString(null, "public.png", cf.kCFStringEncodingUTF8) orelse
        return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(png_type));

    const destination = image_io.CGImageDestinationCreateWithData(data, png_type, 1, null) orelse
        return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(destination));

    image_io.CGImageDestinationAddImage(destination, image, null);
    if (!image_io.CGImageDestinationFinalize(destination)) return error.PNGEncodingFailed;

    const encoded_length = cf.CFDataGetLength(data);
    if (encoded_length <= 0) return error.PNGEncodingFailed;
    const length: usize = @intCast(encoded_length);
    const encoded = try allocator.alloc(u8, length);
    errdefer allocator.free(encoded);
    @memcpy(encoded, cf.CFDataGetBytePtr(data)[0..length]);
    return encoded;
}

fn find_window(content: objc.Object, window_id: u32) ?objc.Object {
    const windows = content.msgSend(objc.Object, "windows", .{});
    if (windows.value == null) return null;

    var iterator = windows.iterate();
    while (iterator.next()) |candidate| {
        if (candidate.msgSend(u32, "windowID", .{}) != window_id) continue;
        return candidate.retain();
    }

    return null;
}

fn initial_dimension(points: f64) u32 {
    if (!std.math.isFinite(points) or points < 1) return 1;
    if (points >= std.math.maxInt(u32)) return std.math.maxInt(u32);
    return @intFromFloat(@ceil(points));
}
