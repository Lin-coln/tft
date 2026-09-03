const objc = @import("objc");
const macos = @import("macos");

/// Borrowed storage; the caller owns its lifetime and producer synchronization.
pub const Input = union(enum) {
    data: objc.Object,
    io_surface: macos.IOSurface.IOSurfaceRef,
    pixel_buffer: macos.CoreVideo.CVPixelBufferRef,
    sample_buffer: macos.CoreMedia.CMSampleBufferRef,
};

/// Returns an owned VNImageRequestHandler. The caller must release it.
pub fn _initHandler(input: Input) !objc.Object {
    const Class = objc.getClass("VNImageRequestHandler") orelse return error.VisionClassUnavailable;
    const Dictionary = objc.getClass("NSDictionary") orelse return error.FoundationClassUnavailable;
    const options = Dictionary.msgSend(objc.Object, "dictionary", .{});
    if (options.value == null) return error.HandlerOptionsCreationFailed;

    // Prepare CIImage before allocating the handler so a failed conversion leaks neither.
    const image: ?objc.Object = switch (input) {
        .io_surface => |surface| try initSurfaceImage(surface),
        else => null,
    };
    defer if (image) |value| value.release();

    const allocated = Class.msgSend(objc.Object, "alloc", .{});
    if (allocated.value == null) return error.HandlerCreationFailed;
    const handler = switch (input) {
        .data => |data| allocated.msgSend(objc.Object, "initWithData:options:", .{ data, options }),
        .io_surface => allocated.msgSend(objc.Object, "initWithCIImage:options:", .{ image.?, options }),
        .pixel_buffer => |buffer| allocated.msgSend(objc.Object, "initWithCVPixelBuffer:options:", .{ buffer, options }),
        .sample_buffer => |buffer| allocated.msgSend(objc.Object, "initWithCMSampleBuffer:options:", .{ buffer, options }),
    };
    if (handler.value == null) return error.HandlerCreationFailed;
    return handler;
}

fn initSurfaceImage(surface: macos.IOSurface.IOSurfaceRef) !objc.Object {
    // Wrap the IOSurface without CPU readback or PNG encoding.
    const Class = objc.getClass("CIImage") orelse return error.CoreImageClassUnavailable;
    const allocated = Class.msgSend(objc.Object, "alloc", .{});
    if (allocated.value == null) return error.ImageCreationFailed;
    const image = allocated.msgSend(objc.Object, "initWithIOSurface:", .{surface});
    if (image.value == null) return error.ImageCreationFailed;
    return image;
}
