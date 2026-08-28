const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const calc = b.addLibrary(.{
        .name = "calc",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/calc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(calc);

    const calc_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/calc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_calc_tests = b.addRunArtifact(calc_tests);

    const test_step = b.step("test", "Run calculator tests");
    test_step.dependOn(&run_calc_tests.step);
}
