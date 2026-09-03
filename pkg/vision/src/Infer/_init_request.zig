const std = @import("std");
const objc = @import("objc");
const Self = @import("Self.zig");

const NSUTF8StringEncoding: usize = 4;

pub const Language = union(enum) {
    simplified_chinese,
    traditional_chinese,
    english_us,
    custom: []const u8,

    fn tag(self: Language) []const u8 {
        return switch (self) {
            .simplified_chinese => "zh-Hans",
            .traditional_chinese => "zh-Hant",
            .english_us => "en-US",
            .custom => |value| value,
        };
    }
};

pub const RecognitionLevel = enum(isize) {
    accurate = 0,
    fast = 1,
};

pub fn _initRequest(self: *Self, options: Self.Options) !void {
    if (options.languages.len == 0) {
        return error.InvalidOptions;
    }
    if (!std.math.isFinite(options.minimum_text_height) or options.minimum_text_height < 0 or options.minimum_text_height > 1) {
        return error.InvalidOptions;
    }

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const request = init: {
        const Class = objc.getClass("VNRecognizeTextRequest") orelse return error.VisionClassUnavailable;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        if (allocated.value == null) return error.RequestCreationFailed;
        break :init allocated.msgSend(objc.Object, "init", .{});
    };
    if (request.value == null) return error.RequestCreationFailed;
    errdefer request.release();

    var language_values: std.ArrayList(objc.c.id) = .empty;
    defer language_values.deinit(self.allocator);
    try language_values.ensureTotalCapacity(self.allocator, options.languages.len);

    const NSString = objc.getClass("NSString").?;
    for (options.languages) |language| {
        const tag = language.tag();
        const value = NSString.msgSend(
            objc.Object,
            "stringWithBytes:length:encoding:",
            .{ tag.ptr, tag.len, NSUTF8StringEncoding },
        );
        if (value.value == null) return error.InvalidLanguage;
        language_values.appendAssumeCapacity(value.value);
    }

    const languages = objc.getClass("NSArray").?.msgSend(
        objc.Object,
        "arrayWithObjects:count:",
        .{ language_values.items.ptr, language_values.items.len },
    );

    if (languages.value == null) return error.LanguageArrayCreationFailed;

    request.setProperty("recognitionLevel", @intFromEnum(options.recognition_level));
    request.setProperty("recognitionLanguages", languages);
    request.setProperty("usesLanguageCorrection", options.uses_language_correction);
    request.setProperty("minimumTextHeight", options.minimum_text_height);

    const request_values = [_]objc.c.id{request.value};
    const requests = init: {
        const allocated = objc.getClass("NSArray").?.msgSend(objc.Object, "alloc", .{});
        if (allocated.value == null) return error.RequestArrayCreationFailed;
        break :init allocated.msgSend(
            objc.Object,
            "initWithObjects:count:",
            .{ &request_values, request_values.len },
        );
    };
    if (requests.value == null) return error.RequestArrayCreationFailed;

    self.request = request;
    self.requests = requests;
}
