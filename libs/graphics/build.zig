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

    const mod_vision = b.dependency("vision", .{
        .target = target,
        .optimize = optimize,
    }).module("vision");

    napi_zig.addLib(b, napi_dep, .{
        .name = "addon",
        .root = b.path("addon/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "window", .module = mod_window },
            .{ .name = "capture", .module = mod_capture },
            .{ .name = "vision", .module = mod_vision },
        },
    });

    const tests = b.addTest(.{ .root_module = mod_window });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const session_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("addon/InferSession.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "capture", .module = mod_capture },
                .{ .name = "vision", .module = mod_vision },
            },
        }),
    });
    const run_session_tests = b.addRunArtifact(session_tests);
    test_step.dependOn(&run_session_tests.step);
    b.step("test-session", "Test inference session without screen capture permission").dependOn(&run_session_tests.step);
}
