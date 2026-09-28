const objc = @import("objc");

pub const Error = error{
    NSDataCreationFailed,
};

/// Returns an owned NSData instance. The caller must call `release`.
pub fn allocNSDataFromBytes(bytes: []const u8) Error!objc.Object {
    if (bytes.len == 0) return error.NSDataCreationFailed;

    const data = objc.getClass("NSData").?.msgSend(
        objc.Object,
        "alloc",
        .{},
    ).msgSend(
        objc.Object,
        "initWithBytes:length:",
        .{ bytes.ptr, bytes.len },
    );
    if (data.value == null) return error.NSDataCreationFailed;
    return data;
}
