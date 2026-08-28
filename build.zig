const std = @import("std");
const napi_zig = @import("napi_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const napi_dependency = b.dependency("napi_zig", .{});

    napi_zig.addLib(b, napi_dependency, .{
        .name = "calc",
        .root = b.path("src/calc.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/calc.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("napi-zig", napi_dependency.module("napi"));
    const calc_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_calc_tests = b.addRunArtifact(calc_tests);

    const test_step = b.step("test", "Run calculator tests");
    test_step.dependOn(&run_calc_tests.step);
}
