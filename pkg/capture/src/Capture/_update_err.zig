const std = @import("std");
const objc = @import("objc");

const Self = @import("Self.zig");

pub fn _update(self: *Self, err: ?objc.Object) void {
    const prev = self.err;
    self.err = err;
    if (prev) |obj| obj.release();
}
