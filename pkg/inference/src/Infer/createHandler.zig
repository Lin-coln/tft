const objc = @import("objc");
const macos = @import("macos");

const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const ios = macos.IOSurface;

/// Borrowed storage; the caller owns its lifetime and producer synchronization.
pub const Input = union(enum) {
    data: objc.Object,
    io_surface: ios.IOSurfaceRef,
    pixel_buffer: cv.CVPixelBufferRef,
    sample_buffer: cm.CMSampleBufferRef,
};

/// Returns an owned VNImageRequestHandler. The caller must release it.
pub fn createHandler(input: Input) !objc.Object {
    const options = objc.getClass("NSDictionary").?.msgSend(objc.Object, "dictionary", .{});
    if (options.value == null) return error.HandlerOptionsCreationFailed;

    // Prepare CIImage before allocating the handler so a failed conversion leaks neither.
    const image: ?objc.Object = switch (input) {
        .io_surface => |surface| try createSurfaceImage(surface),
        else => null,
    };
    defer if (image) |value| value.release();

    const handler = switch (input) {
        .data => |data| objc.getClass("VNImageRequestHandler").?.msgSend(
            objc.Object,
            "alloc",
            .{},
        ).msgSend(objc.Object, "initWithData:options:", .{ data, options }),
        .io_surface => objc.getClass("VNImageRequestHandler").?.msgSend(
            objc.Object,
            "alloc",
            .{},
        ).msgSend(objc.Object, "initWithCIImage:options:", .{ image.?, options }),
        .pixel_buffer => |buffer| objc.getClass("VNImageRequestHandler").?.msgSend(
            objc.Object,
            "alloc",
            .{},
        ).msgSend(objc.Object, "initWithCVPixelBuffer:options:", .{ buffer, options }),
        .sample_buffer => |buffer| objc.getClass("VNImageRequestHandler").?.msgSend(
            objc.Object,
            "alloc",
            .{},
        ).msgSend(objc.Object, "initWithCMSampleBuffer:options:", .{ buffer, options }),
    };
    if (handler.value == null) return error.HandlerCreationFailed;
    return handler;
}

fn createSurfaceImage(surface: ios.IOSurfaceRef) !objc.Object {
    // Wrap the IOSurface without CPU readback or PNG encoding.
    const image = objc.getClass("CIImage").?.msgSend(
        objc.Object,
        "alloc",
        .{},
    ).msgSend(objc.Object, "initWithIOSurface:", .{surface});
    if (image.value == null) return error.ImageCreationFailed;
    return image;
}
