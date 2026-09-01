const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const image_io = macos.ImageIO;

pub fn encodeSurfacePng(
    allocator: std.mem.Allocator,
    ci_context: objc.Object,
    surface: macos.IOSurface.IOSurfaceRef,
) ![]u8 {
    const ci_image = init: {
        const Class = objc.getClass("CIImage").?;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        break :init allocated.msgSend(
            objc.Object,
            "initWithIOSurface:",
            .{surface},
        );
    };
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

    const image = ci_context.msgSend(
        ?cg.CGImageRef,
        "createCGImage:fromRect:",
        .{ ci_image, bounds },
    ) orelse return error.CGImageCreationFailed;
    defer cf.CFRelease(@ptrCast(image));

    const data = cf.CFDataCreateMutable(null, 0) orelse
        return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(data));

    const png_type = cf.CFStringCreateWithCString(
        null,
        "public.png",
        cf.kCFStringEncodingUTF8,
    ) orelse return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(png_type));

    const destination = image_io.CGImageDestinationCreateWithData(
        data,
        png_type,
        1,
        null,
    ) orelse return error.PNGEncodingFailed;
    defer cf.CFRelease(@ptrCast(destination));

    image_io.CGImageDestinationAddImage(destination, image, null);

    if (!image_io.CGImageDestinationFinalize(destination)) {
        return error.PNGEncodingFailed;
    }

    const length: usize = @intCast(cf.CFDataGetLength(data));
    const encoded = try allocator.alloc(u8, length);
    errdefer allocator.free(encoded);

    @memcpy(encoded, cf.CFDataGetBytePtr(data)[0..length]);
    return encoded;
}
