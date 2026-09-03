const objc = @import("objc");

pub const Error = error{
    NSDataClassUnavailable,
    NSDataCreationFailed,
};

/// Returns an owned NSData instance. The caller must call `release`.
pub fn allocNSDataFromBytes(bytes: []const u8) Error!objc.Object {
    if (bytes.len == 0) return error.NSDataCreationFailed;

    const NSData = objc.getClass("NSData") orelse
        return error.NSDataClassUnavailable;
    const allocated = NSData.msgSend(objc.Object, "alloc", .{});
    if (allocated.value == null) return error.NSDataCreationFailed;

    const data = allocated.msgSend(
        objc.Object,
        "initWithBytes:length:",
        .{ bytes.ptr, bytes.len },
    );
    if (data.value == null) return error.NSDataCreationFailed;
    return data;
}
