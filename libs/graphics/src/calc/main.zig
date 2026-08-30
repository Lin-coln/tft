const std = @import("std");

pub fn add(a: f64, b: f64) f64 {
    return a + b;
}

pub fn subtract(a: f64, b: f64) f64 {
    return a - b;
}

pub fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

pub fn divide(a: f64, b: f64) !f64 {
    if (b == 0) return error.DivisionByZero;
    return a / b;
}

test "add" {
    try std.testing.expectEqual(@as(f64, 5), add(2, 3));
    try std.testing.expectEqual(@as(f64, -1.25), add(-2.5, 1.25));
}

test "subtract" {
    try std.testing.expectEqual(@as(f64, -1), subtract(2, 3));
    try std.testing.expectEqual(@as(f64, 3.75), subtract(1.25, -2.5));
}

test "multiply" {
    try std.testing.expectEqual(@as(f64, 6), multiply(2, 3));
    try std.testing.expectEqual(@as(f64, -3.125), multiply(-2.5, 1.25));
}

test "divide" {
    try std.testing.expectEqual(@as(f64, 2.5), try divide(5, 2));
    try std.testing.expectError(error.DivisionByZero, divide(1, 0));
}
