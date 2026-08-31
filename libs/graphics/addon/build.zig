const std = @import("std");
const napi_zig = @import("napi_zig");
const Build = std.Build;
const Dependency = std.Build.Dependency;
const Target = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = std.Build.Module;

pub fn add_addon(
    b: *Build,
    napi_dep: *Dependency,
    target: Target,
    optimize: OptimizeMode,
    window: *Module,
) void {
    napi_zig.addLib(b, napi_dep, .{
        .name = "addon",
        .root = b.path("addon/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "window", .module = window },
        },
    });
}
