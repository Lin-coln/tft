const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .macos) {
        @panic("pkg/vision requires a macOS target");
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

    const vision = b.addModule("vision", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "macos", .module = macos },
            .{ .name = "objc", .module = objc },
        },
    });

    vision.linkFramework("CoreGraphics", .{});
    vision.linkFramework("CoreImage", .{});
    vision.linkFramework("IOSurface", .{});
    vision.linkFramework("CoreMedia", .{});
    vision.linkFramework("CoreVideo", .{});
    vision.linkFramework("Foundation", .{});
    vision.linkFramework("Vision", .{});
    vision.linkSystemLibrary("objc", .{});

    const cli = b.createModule(.{
        .root_source_file = b.path("src/run.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "vision", .module = vision }},
    });

    const executable = b.addExecutable(.{
        .name = "vision-ocr",
        .root_module = cli,
    });
    b.installArtifact(executable);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);

    const run_step = b.step("run", "Recognize text in a PNG image");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = vision });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run vision OCR tests");
    test_step.dependOn(&run_tests.step);
}
