const std = @import("std");
const macos = @import("macos");
const objc = @import("objc");

const Self = @import("Self.zig");

pub fn getCommandBuffer(self: *Self) !objc.Object {
    if (self.render_state.command_buffer) |command_buffer| return command_buffer;

    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const command_buffer = blk: {
        const value = self.command_queue.getProperty(objc.Object, "commandBuffer");
        if (value.value == null) return error.CommandBufferCreationFailed;
        break :blk value.retain();
    };
    errdefer command_buffer.release();
    self.render_state.command_buffer = command_buffer;
    return command_buffer;
}
