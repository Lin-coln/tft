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

pub fn createRequests(self: *Self, options: Self.Options) !void {
    if (options.languages.len == 0) {
        return error.InvalidOptions;
    }
    if (!std.math.isFinite(options.minimum_text_height) or options.minimum_text_height < 0 or options.minimum_text_height > 1) {
        return error.InvalidOptions;
    }

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    self.request = objc.getClass("VNRecognizeTextRequest").?.msgSend(
        objc.Object,
        "alloc",
        .{},
    ).msgSend(objc.Object, "init", .{});
    errdefer self.request.release();
    if (self.request.value == null) return error.RequestCreationFailed;

    var language_values: std.ArrayList(objc.c.id) = .empty;
    defer language_values.deinit(self.allocator);
    try language_values.ensureTotalCapacity(self.allocator, options.languages.len);

    for (options.languages) |language| {
        const tag = language.tag();
        const value = objc.getClass("NSString").?.msgSend(
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

    self.request.setProperty("recognitionLevel", @intFromEnum(options.recognition_level));
    self.request.setProperty("recognitionLanguages", languages);
    self.request.setProperty("usesLanguageCorrection", options.uses_language_correction);
    self.request.setProperty("minimumTextHeight", options.minimum_text_height);

    const request_values = [_]objc.c.id{self.request.value};
    self.requests = objc.getClass("NSArray").?.msgSend(
        objc.Object,
        "alloc",
        .{},
    ).msgSend(
        objc.Object,
        "initWithObjects:count:",
        .{ &request_values, request_values.len },
    );
    errdefer self.requests.release();
    if (self.requests.value == null) return error.RequestArrayCreationFailed;
}
