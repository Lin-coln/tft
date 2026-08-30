const std = @import("std");
const create_mod_macos = @import("shared/macos/build.zig").create_mod_macos;
const add_addon = @import("src/addon/build.zig").add_addon;
const create_mod_calc = @import("src/calc/build.zig").create_mod_calc;
const create_mod_window = @import("src/window/build.zig").create_mod_window;
const setup_test_calc = @import("src/calc/build.zig").setup_test;
const setup_test_window = @import("src/window/build.zig").setup_test;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const napi_dep = b.dependency("napi_zig", .{});

    const mod_macos = create_mod_macos(b, target, optimize);

    const mod_calc = create_mod_calc(b, target, optimize);

    const mod_window = create_mod_window(b, target, optimize);
    mod_window.addImport("macos", mod_macos);

    add_addon(b, napi_dep, target, optimize, mod_calc, mod_window);

    const test_step = b.step("test", "Run unit tests");
    setup_test_calc(b, test_step, mod_calc);
    setup_test_window(b, test_step, mod_window);
}
