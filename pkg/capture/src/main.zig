pub const Capture = @import("Capture/Self.zig");
pub const Surface = @import("Capture/_update_surface.zig").Surface;

test {
    _ = @import("Capture/_tests.zig");
}
