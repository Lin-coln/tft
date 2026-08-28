const builtin = @import("builtin");
const napi = @import("napi-zig");
const std = @import("std");

comptime {
    if (!builtin.is_test) napi.module(@This());
}

pub fn add(a: f64, b: f64) f64 {
    return a + b;
}

pub fn subtract(a: f64, b: f64) f64 {
    return a - b;
}

pub fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

pub fn divide(a: f64, b: f64) f64 {
    return a / b;
}

test "basic arithmetic" {
    try std.testing.expectEqual(@as(f64, 5), add(2, 3));
    try std.testing.expectEqual(@as(f64, -1), subtract(2, 3));
    try std.testing.expectEqual(@as(f64, 6), multiply(2, 3));
    try std.testing.expectEqual(@as(f64, 2.5), divide(5, 2));
}
