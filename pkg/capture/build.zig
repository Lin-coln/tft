const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("capture requires a macOS target");
    }

    const macos = b.dependency("macos", .{
        .target = target,
        .optimize = optimize,
    }).module("macos");

    const objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
        .@"add-paths" = false,
    }).module("objc");

    const capture = b.addModule("capture", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "macos", .module = macos },
            .{ .name = "objc", .module = objc },
        },
    });

    capture.linkFramework("CoreFoundation", .{});
    capture.linkFramework("Metal", .{});
    capture.linkFramework("IOSurface", .{});
    capture.linkFramework("CoreGraphics", .{});
    capture.linkFramework("CoreMedia", .{});
    capture.linkFramework("CoreVideo", .{});
    capture.linkFramework("ScreenCaptureKit", .{});
    capture.linkFramework("VideoToolbox", .{});
    capture.linkSystemLibrary("objc", .{});

    const tests = b.addTest(.{
        .root_module = capture,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run capture tests");
    test_step.dependOn(&run_tests.step);
}
