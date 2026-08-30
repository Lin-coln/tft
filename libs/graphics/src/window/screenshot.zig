const std = @import("std");
const builtin = @import("builtin");
const macos = @import("macos");
const cf = macos.CoreFoundation;
const cg = macos.CoreGraphics;
const cm = macos.CoreMedia;
const cv = macos.CoreVideo;
const image_io = macos.ImageIO;
const objc_rt = macos.objc;
const sc = macos.ScreenCaptureKit;
const objc = @import("objc.zig");

const BlockDescriptor = extern struct {
    reserved: usize = 0,
    size: usize,
};

const ContentResult = struct {
    done: std.atomic.Value(bool) = .init(false),
    content: ?*sc.SCShareableContent = null,
};

const ContentBlock = extern struct {
    isa: *anyopaque,
    flags: i32 = 0,
    reserved: i32 = 0,
    invoke: *const fn (*ContentBlock, ?*sc.SCShareableContent, ?*objc.Object) callconv(.c) void,
    descriptor: *const BlockDescriptor,
    result: *ContentResult,
};

const SampleBufferResult = struct {
    done: std.atomic.Value(bool) = .init(false),
    sample_buffer: ?cm.CMSampleBufferRef = null,
};

const SampleBufferBlock = extern struct {
    isa: *anyopaque,
    flags: i32 = 0,
    reserved: i32 = 0,
    invoke: *const fn (*SampleBufferBlock, ?cm.CMSampleBufferRef, ?*objc.Object) callconv(.c) void,
    descriptor: *const BlockDescriptor,
    result: *SampleBufferResult,
};

const content_block_descriptor: BlockDescriptor = .{ .size = @sizeOf(ContentBlock) };
const sample_buffer_block_descriptor: BlockDescriptor = .{ .size = @sizeOf(SampleBufferBlock) };

pub fn screenshot(allocator: std.mem.Allocator, window_id: u32) ![]u8 {
    if (window_id == cg.kCGNullWindowID) return error.InvalidWindowId;

    const content = try retain_shareable_content();
    defer objc.release(@ptrCast(content));

    const window = find_window(content, window_id) orelse return error.WindowNotFound;
    const filter = create_filter(window) orelse return error.FilterUnavailable;
    defer objc.release(@ptrCast(filter));

    const configuration = create_configuration(filter, window) orelse
        return error.ConfigurationUnavailable;
    defer objc.release(@ptrCast(configuration));

    const sample_buffer = try retain_sample_buffer(filter, configuration);
    defer cf.CFRelease(@ptrCast(sample_buffer));

    return encode_png(allocator, sample_buffer);
}

fn retain_shareable_content() !*sc.SCShareableContent {
    var result: ContentResult = .{};
    var stack_block: ContentBlock = .{
        .isa = @ptrCast(&objc_rt._NSConcreteStackBlock),
        .invoke = complete_content,
        .descriptor = &content_block_descriptor,
        .result = &result,
    };
    const block = objc_rt._Block_copy(&stack_block);
    defer objc_rt._Block_release(block);

    const class = objc_rt.objc_getClass("SCShareableContent") orelse
        return error.ScreenCaptureKitUnavailable;
    objc.send_void(
        class,
        "getShareableContentExcludingDesktopWindows:onScreenWindowsOnly:completionHandler:",
        .{ @as(objc_rt.BOOL, 0), @as(objc_rt.BOOL, 0), block },
    );

    wait(&result.done);
    return result.content orelse error.ShareableContentUnavailable;
}

fn find_window(content: *sc.SCShareableContent, window_id: u32) ?*sc.SCWindow {
    const windows = objc.send_obj(content, "windows", .{}) orelse return null;
    const count = objc.send(usize, windows, "count", .{});

    for (0..count) |index| {
        const window = objc.send_obj(windows, "objectAtIndex:", .{index}) orelse continue;
        if (objc.send(u32, window, "windowID", .{}) == window_id) return @ptrCast(window);
    }

    return null;
}

fn create_filter(window: *sc.SCWindow) ?*sc.SCContentFilter {
    const filter = objc.class_alloc(
        "SCContentFilter",
        "initWithDesktopIndependentWindow:",
        .{window},
    ) orelse return null;
    return @ptrCast(filter);
}

fn create_configuration(filter: *sc.SCContentFilter, window: *sc.SCWindow) ?*sc.SCStreamConfiguration {
    const raw_configuration = objc.class_init("SCStreamConfiguration") orelse return null;
    const configuration: *sc.SCStreamConfiguration = @ptrCast(raw_configuration);

    const frame = get_frame(window);
    const scale = objc.send(f32, filter, "pointPixelScale", .{});
    const width = pixel_size(frame.size.width, scale) orelse {
        objc.release(raw_configuration);
        return null;
    };
    const height = pixel_size(frame.size.height, scale) orelse {
        objc.release(raw_configuration);
        return null;
    };

    objc.send_void(configuration, "setWidth:", .{width});
    objc.send_void(configuration, "setHeight:", .{height});
    objc.send_void(configuration, "setShowsCursor:", .{@as(objc_rt.BOOL, 0)});
    return configuration;
}

fn retain_sample_buffer(
    filter: *sc.SCContentFilter,
    configuration: *sc.SCStreamConfiguration,
) !cm.CMSampleBufferRef {
    var result: SampleBufferResult = .{};
    var stack_block: SampleBufferBlock = .{
        .isa = @ptrCast(&objc_rt._NSConcreteStackBlock),
        .invoke = complete_sample_buffer,
        .descriptor = &sample_buffer_block_descriptor,
        .result = &result,
    };
    const block = objc_rt._Block_copy(&stack_block);
    defer objc_rt._Block_release(block);

    const class = objc_rt.objc_getClass("SCScreenshotManager") orelse
        return error.ScreenCaptureKitUnavailable;
    objc.send_void(
        class,
        "captureSampleBufferWithFilter:configuration:completionHandler:",
        .{ filter, configuration, block },
    );

    wait(&result.done);
    return result.sample_buffer orelse error.CaptureFailed;
}

fn encode_png(allocator: std.mem.Allocator, sample_buffer: cm.CMSampleBufferRef) ![]u8 {
    const pixel_buffer: cv.CVPixelBufferRef = cm.CMSampleBufferGetImageBuffer(sample_buffer) orelse
        return error.PixelBufferUnavailable;

    const ci_image = objc.class_alloc("CIImage", "initWithCVPixelBuffer:", .{pixel_buffer}) orelse
        return error.CIImageUnavailable;
    defer objc.release(ci_image);

    const ci_context = objc.class_send("CIContext", "context", .{}) orelse
        return error.CIContextUnavailable;
    objc.retain(ci_context);
    defer objc.release(ci_context);

    const width = cv.CVPixelBufferGetWidth(pixel_buffer);
    const height = cv.CVPixelBufferGetHeight(pixel_buffer);
    const image = objc.send(?cg.CGImageRef, ci_context, "createCGImage:fromRect:", .{
        ci_image,
        cg.CGRect{
            .origin = .{ .x = 0, .y = 0 },
            .size = .{
                .width = @floatFromInt(width),
                .height = @floatFromInt(height),
            },
        },
    }) orelse return error.CGImageUnavailable;
    defer cf.CFRelease(@ptrCast(image));

    const data = cf.CFDataCreateMutable(null, 0) orelse return error.DataUnavailable;
    defer cf.CFRelease(data);

    const png_type = cf.CFStringCreateWithCString(
        null,
        "public.png",
        cf.kCFStringEncodingUTF8,
    ) orelse return error.PNGTypeUnavailable;
    defer cf.CFRelease(png_type);

    const destination = image_io.CGImageDestinationCreateWithData(data, png_type, 1, null) orelse
        return error.ImageDestinationUnavailable;
    defer cf.CFRelease(@ptrCast(destination));

    image_io.CGImageDestinationAddImage(destination, image, null);
    if (!image_io.CGImageDestinationFinalize(destination)) return error.PNGEncodingFailed;

    const length = cf.CFDataGetLength(data);
    if (length <= 0) return error.PNGEncodingFailed;
    return allocator.dupe(u8, cf.CFDataGetBytePtr(data)[0..@intCast(length)]);
}

fn complete_content(
    block: *ContentBlock,
    content: ?*sc.SCShareableContent,
    error_value: ?*objc.Object,
) callconv(.c) void {
    if (error_value == null and content != null) {
        objc.retain(@ptrCast(content.?));
        block.result.content = content.?;
    }
    block.result.done.store(true, .release);
}

fn complete_sample_buffer(
    block: *SampleBufferBlock,
    sample_buffer: ?cm.CMSampleBufferRef,
    error_value: ?*objc.Object,
) callconv(.c) void {
    if (error_value == null and sample_buffer != null) {
        _ = cf.CFRetain(@ptrCast(sample_buffer.?));
        block.result.sample_buffer = sample_buffer.?;
    }
    block.result.done.store(true, .release);
}

fn get_frame(window: *sc.SCWindow) cg.CGRect {
    if (builtin.target.cpu.arch == .x86_64) {
        var frame: cg.CGRect = undefined;
        const send = @as(
            *const fn (*cg.CGRect, *sc.SCWindow, *objc.Selector) callconv(.c) void,
            @ptrCast(&objc_rt.objc_msgSend_stret),
        );
        send(&frame, window, objc_rt.sel_registerName("frame"));
        return frame;
    }
    return objc.send(cg.CGRect, window, "frame", .{});
}

fn pixel_size(points: cg.CGFloat, scale: f32) ?usize {
    if (!std.math.isFinite(points) or !std.math.isFinite(scale)) return null;
    if (points <= 0 or scale <= 0) return null;

    const pixels = @ceil(points * @as(cg.CGFloat, @floatCast(scale)));
    if (pixels > @as(cg.CGFloat, @floatFromInt(std.math.maxInt(usize)))) return null;
    return @intFromFloat(pixels);
}

fn wait(done: *const std.atomic.Value(bool)) void {
    while (!done.load(.acquire)) {
        std.Thread.yield() catch std.atomic.spinLoopHint();
    }
}

test "reject null window id" {
    try std.testing.expectError(
        error.InvalidWindowId,
        screenshot(std.testing.allocator, cg.kCGNullWindowID),
    );
}
