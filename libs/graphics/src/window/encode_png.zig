const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const image_io = macos.ImageIO;

pub fn encode_png(allocator: std.mem.Allocator, sample_buffer: objc.Object) ![]u8 {
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
