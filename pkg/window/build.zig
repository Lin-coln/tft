const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("window requires a macOS target");
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

    const window = b.addModule("window", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "macos", .module = macos },
            .{ .name = "objc", .module = objc },
        },
    });

    window.linkFramework("AppKit", .{});
    window.linkFramework("CoreFoundation", .{});
    window.linkFramework("CoreGraphics", .{});
    window.linkFramework("CoreImage", .{});
    window.linkFramework("CoreMedia", .{});
    window.linkFramework("CoreVideo", .{});
    window.linkFramework("ImageIO", .{});
    window.linkFramework("IOSurface", .{});
    window.linkFramework("ScreenCaptureKit", .{});
    window.linkSystemLibrary("objc", .{});

    const tests = b.addTest(.{
        .root_module = window,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run window tests");
    test_step.dependOn(&run_tests.step);
}
