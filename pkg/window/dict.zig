const std = @import("std");
const macos = @import("macos");
const cf = macos.CoreFoundation;

pub fn get_i32(ref: cf.CFDictionaryRef, key: cf.CFStringRef) ?i32 {
    const raw_value = cf.CFDictionaryGetValue(ref, key) orelse return null;
    const number: cf.CFNumberRef = @ptrCast(raw_value);
    var value: i32 = 0;
    if (cf.CFNumberGetValue(number, cf.kCFNumberSInt32Type, &value) == 0) return null;
    return value;
}

pub fn get_u32(ref: cf.CFDictionaryRef, key: cf.CFStringRef) ?u32 {
    const raw_value = cf.CFDictionaryGetValue(ref, key) orelse return null;
    const number: cf.CFNumberRef = @ptrCast(raw_value);
    var value: i64 = 0;
    if (cf.CFNumberGetValue(number, cf.kCFNumberSInt64Type, &value) == 0) return null;
    if (value < 0 or value > std.math.maxInt(u32)) return null;
    return @intCast(value);
}

pub fn dupe(
    ref: cf.CFDictionaryRef,
    allocator: std.mem.Allocator,
    key: cf.CFStringRef,
) !?[]u8 {
    const raw_value = cf.CFDictionaryGetValue(ref, key) orelse return null;
    const string: cf.CFStringRef = @ptrCast(raw_value);
    const length = cf.CFStringGetLength(string);
    const maximum_size = cf.CFStringGetMaximumSizeForEncoding(
        length,
        cf.kCFStringEncodingUTF8,
    );
    if (maximum_size < 0) return error.InvalidString;

    const buffer_size: usize = @intCast(maximum_size + 1);
    const buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(buffer);

    if (cf.CFStringGetCString(
        string,
        buffer.ptr,
        @intCast(buffer.len),
        cf.kCFStringEncodingUTF8,
    ) == 0) return error.InvalidString;

    const string_length = std.mem.indexOfScalar(u8, buffer, 0) orelse
        return error.InvalidString;
    return try allocator.realloc(buffer, string_length);
}
