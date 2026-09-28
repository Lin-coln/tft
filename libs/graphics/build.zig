const std = @import("std");
const napi_zig = @import("napi_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const napi_dep = b.dependency("napi_zig", .{});

    if (target.result.os.tag != .macos) {
        @panic("graphics requires a macOS target");
    }

    const mod_macos = b.dependency("macos", .{
        .target = target,
        .optimize = optimize,
    }).module("macos");

    const mod_objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
        .@"add-paths" = false,
    }).module("objc");

    mod_macos.linkFramework("AppKit", .{});
    mod_macos.linkFramework("CoreFoundation", .{});
    mod_macos.linkFramework("CoreGraphics", .{});
    mod_macos.linkFramework("CoreImage", .{});
    mod_macos.linkFramework("CoreMedia", .{});
    mod_macos.linkFramework("CoreVideo", .{});
    mod_macos.linkFramework("ImageIO", .{});
    mod_macos.linkFramework("IOSurface", .{});
    mod_macos.linkFramework("ScreenCaptureKit", .{});
    mod_objc.linkSystemLibrary("objc", .{});

    const mod_tft_capture = b.dependency("tft_capture", .{
        .target = target,
        .optimize = optimize,
    }).module("capture");

    const mod_tft_stream = b.dependency("tft_stream", .{
        .target = target,
        .optimize = optimize,
    }).module("stream");

    const mod_inference = b.dependency("inference", .{
        .target = target,
        .optimize = optimize,
    }).module("inference");

    napi_zig.addLib(b, napi_dep, .{
        .name = "addon",
        .root = b.path("addon/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "macos", .module = mod_macos },
            .{ .name = "objc", .module = mod_objc },
            .{ .name = "tft/capture", .module = mod_tft_capture },
            .{ .name = "tft/stream", .module = mod_tft_stream },
            .{ .name = "inference", .module = mod_inference },
        },
    });

    const target_tests = b.createModule(.{
        .root_source_file = b.path("addon/target/PngEncoder.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "macos", .module = mod_macos },
            .{ .name = "objc", .module = mod_objc },
        },
    });
    const tests = b.addTest(.{ .root_module = target_tests });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
