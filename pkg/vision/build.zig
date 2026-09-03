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

    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "objc", .module = objc }},
    });

    root.linkFramework("Foundation", .{});
    root.linkFramework("Vision", .{});
    root.linkSystemLibrary("objc", .{});

    const executable = b.addExecutable(.{
        .name = "vision-ocr",
        .root_module = root,
    });
    b.installArtifact(executable);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);

    const run_step = b.step("run", "Recognize text in a PNG image");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = root });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run vision OCR tests");
    test_step.dependOn(&run_tests.step);
}
