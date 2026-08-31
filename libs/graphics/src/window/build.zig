const std = @import("std");
const Build = std.Build;
const Target = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = std.Build.Module;
const Step = std.Build.Step;

pub fn create_mod_window(
    b: *Build,
    target: Target,
    optimize: OptimizeMode,
    macos: *Module,
) *Module {
    const objc = b.dependency("zig_objc", .{
        .target = target,
        .optimize = optimize,
        .@"add-paths" = false,
    }).module("objc");

    const mod = b.createModule(.{
        .root_source_file = b.path("src/window/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "objc", .module = objc },
            .{ .name = "macos", .module = macos },
        },
    });

    mod.linkFramework("AppKit", .{});
    mod.linkFramework("CoreFoundation", .{});
    mod.linkFramework("CoreGraphics", .{});
    mod.linkFramework("CoreImage", .{});
    mod.linkFramework("CoreMedia", .{});
    mod.linkFramework("CoreVideo", .{});
    mod.linkFramework("ImageIO", .{});
    mod.linkFramework("ScreenCaptureKit", .{});
    mod.linkSystemLibrary("objc", .{});

    return mod;
}

pub fn setup_test(b: *Build, test_step: *Step, module: *Module) void {
    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
