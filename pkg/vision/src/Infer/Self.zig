const std = @import("std");
const objc = @import("objc");

const read = @import("readResults.zig");

const log = std.log.scoped(.vision);

const Self = @This();

request: objc.Object,
handler: objc.Object,

pub const Results = read.Results;

pub fn init(image_data: objc.Object) Self {
    const request = init: {
        const Class = objc.getClass("VNRecognizeTextRequest").?;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        break :init allocated.msgSend(objc.Object, "init", .{});
    };

    const NSString = objc.getClass("NSString").?;
    const language_values = [_]objc.c.id{
        NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"zh-Hans"}).value,
        NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"en-US"}).value,
    };
    const languages = objc.getClass("NSArray").?.msgSend(
        objc.Object,
        "arrayWithObjects:count:",
        .{ &language_values, language_values.len },
    );

    request.setProperty("recognitionLevel", @as(isize, 0));
    request.setProperty("recognitionLanguages", languages);
    request.setProperty("usesLanguageCorrection", false);
    request.setProperty("minimumTextHeight", @as(f32, 0));

    const handler = init: {
        const Class = objc.getClass("VNImageRequestHandler").?;
        const allocated = Class.msgSend(objc.Object, "alloc", .{});
        const options = objc.getClass("NSDictionary").?.msgSend(
            objc.Object,
            "dictionary",
            .{},
        );
        break :init allocated.msgSend(
            objc.Object,
            "initWithData:options:",
            .{ image_data, options },
        );
    };

    return .{
        .request = request,
        .handler = handler,
    };
}

pub fn deinit(self: Self) void {
    self.handler.release();
    self.request.release();
}

pub fn perform(self: Self) !void {
    const requests = objc.getClass("NSArray").?.msgSend(
        objc.Object,
        "arrayWithObject:",
        .{self.request},
    );
    var error_id: objc.c.id = null;
    const succeeded = self.handler.msgSend(
        bool,
        "performRequests:error:",
        .{ requests, &error_id },
    );
    if (succeeded) return;

    if (error_id != null) {
        const description = objc.Object.fromId(error_id).getProperty(
            objc.Object,
            "localizedDescription",
        );
        const string = description.msgSend([*c]const u8, "UTF8String", .{});
        if (string != null) log.err("Vision request failed: {s}", .{string});
    }
    return error.PerformRequestFailed;
}

pub fn readResults(self: Self, allocator: std.mem.Allocator) !Results {
    return read.read(allocator, self.request);
}
