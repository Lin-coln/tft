const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("pkg/inference requires a macOS target");
    }

    const objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
        .@"add-paths" = false,
    }).module("objc");

    const macos = b.dependency("macos", .{
        .target = target,
        .optimize = optimize,
    }).module("macos");

    const tft_pipeline = b.dependency("tft_pipeline", .{
        .target = target,
        .optimize = optimize,
    }).module("pipeline");

    const inference = b.addModule("inference", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "macos", .module = macos },
            .{ .name = "objc", .module = objc },
            .{ .name = "tft/pipeline", .module = tft_pipeline },
        },
    });

    inference.linkFramework("CoreGraphics", .{});
    inference.linkFramework("CoreImage", .{});
    inference.linkFramework("IOSurface", .{});
    inference.linkFramework("CoreMedia", .{});
    inference.linkFramework("CoreVideo", .{});
    inference.linkFramework("Foundation", .{});
    inference.linkFramework("Vision", .{});
    inference.linkSystemLibrary("objc", .{});

    const cli = b.createModule(.{
        .root_source_file = b.path("src/run.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "inference", .module = inference }},
    });

    const executable = b.addExecutable(.{
        .name = "inference-ocr",
        .root_module = cli,
    });
    b.installArtifact(executable);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);

    const run_step = b.step("run", "Recognize text in a PNG image");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = inference });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run vision OCR tests");
    test_step.dependOn(&run_tests.step);
}
