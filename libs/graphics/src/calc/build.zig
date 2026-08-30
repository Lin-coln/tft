const std = @import("std");
const Build = std.Build;
const Target = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = std.Build.Module;
const Step = std.Build.Step;

pub fn create_mod_calc(b: *Build, target: Target, optimize: OptimizeMode) *Module {
    return b.createModule(.{
        .root_source_file = b.path("src/calc/main.zig"),
        .target = target,
        .optimize = optimize,
    });
}

pub fn setup_test(b: *Build, test_step: *Step, module: *Module) void {
    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
