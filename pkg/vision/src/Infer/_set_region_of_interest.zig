const std = @import("std");
const macos = @import("macos");
const Self = @import("Self.zig");
const cg = macos.CoreGraphics;

/// A normalized Vision region with a lower-left origin.
pub const Region = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,

    pub const full: Region = .{
        .x = 0,
        .y = 0,
        .width = 1,
        .height = 1,
    };

    fn rect(self: Region) cg.CGRect {
        return .{
            .origin = .{ .x = self.x, .y = self.y },
            .size = .{ .width = self.width, .height = self.height },
        };
    }

    fn isValid(self: Region) bool {
        return self.x >= 0 and self.y >= 0 and
            self.width > 0 and self.height > 0 and
            self.x + self.width <= 1 and
            self.y + self.height <= 1;
    }
};

pub fn _setRegionOfInterest(self: *Self, region: Region) !void {
    if (!region.isValid()) return error.InvalidRegionOfInterest;
    self.request.setProperty("regionOfInterest", region.rect());
}

test "Region validates normalized rectangles" {
    try std.testing.expect(Region.full.isValid());
    try std.testing.expect((Region{ .x = 0.1, .y = 0.2, .width = 0.3, .height = 0.4 }).isValid());
    try std.testing.expect(!(Region{ .x = -0.1, .y = 0, .width = 1, .height = 1 }).isValid());
    try std.testing.expect(!(Region{ .x = 0.5, .y = 0, .width = 0.6, .height = 1 }).isValid());
}
