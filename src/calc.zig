const std = @import("std");

export fn add(a: f64, b: f64) callconv(.c) f64 {
    return a + b;
}

export fn subtract(a: f64, b: f64) callconv(.c) f64 {
    return a - b;
}

export fn multiply(a: f64, b: f64) callconv(.c) f64 {
    return a * b;
}

export fn divide(a: f64, b: f64) callconv(.c) f64 {
    return a / b;
}

test "basic arithmetic" {
    try std.testing.expectEqual(@as(f64, 5), add(2, 3));
    try std.testing.expectEqual(@as(f64, -1), subtract(2, 3));
    try std.testing.expectEqual(@as(f64, 6), multiply(2, 3));
    try std.testing.expectEqual(@as(f64, 2.5), divide(5, 2));
}
