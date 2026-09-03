const std = @import("std");
const napi_zig = @import("napi_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const napi_dep = b.dependency("napi_zig", .{});

    const mod_window = b.dependency("window", .{
        .target = target,
        .optimize = optimize,
    }).module("window");

    const mod_capture = b.dependency("capture", .{
        .target = target,
        .optimize = optimize,
    }).module("capture");

    napi_zig.addLib(b, napi_dep, .{
        .name = "addon",
        .root = b.path("addon/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "window", .module = mod_window },
            .{ .name = "capture", .module = mod_capture },
        },
    });

    const tests = b.addTest(.{ .root_module = mod_window });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
