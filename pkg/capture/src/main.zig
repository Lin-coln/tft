pub const Capture = @import("Capture/Self.zig");
pub const Surface = @import("Capture/_update_surface.zig").Surface;

pub const Encoder = @import("Encoder/Self.zig");

pub const Renderer = @import("Renderer/Self.zig");

test {
    _ = @import("Capture/_tests.zig");
    _ = @import("Encoder/Self.zig");
    _ = @import("Renderer/Scaler.zig");
}
