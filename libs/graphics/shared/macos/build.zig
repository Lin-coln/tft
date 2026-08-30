const std = @import("std");
const Build = std.Build;
const Target = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = std.Build.Module;

pub fn create_mod_macos(b: *Build, target: Target, optimize: OptimizeMode) *Module {
    if (target.result.os.tag != .macos) {
        @panic("macos requires a macOS target");
    }

    const mod = b.createModule(.{
        .root_source_file = b.path("shared/macos/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.linkFramework("CoreFoundation", .{});
    mod.linkFramework("CoreGraphics", .{});
    return mod;
}
