pub const Infer = @import("src/Infer/Self.zig");

pub const InferSession = @import("src/InferSession/Self.zig");

pub const allocNSDataFromBytes = @import("src/allocNSDataFromBytes.zig").allocNSDataFromBytes;

test {
    _ = Infer;
    _ = InferSession;
}
