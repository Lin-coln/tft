pub const Renderer = @import("Renderer/Self.zig");

pub const Packet = @import("tft/stream").Packet;
pub const ResolveConfig = @import("tft/stream").ResolveConfig;

test {
    _ = Renderer;

    _ = @import("Renderer/Device/render.zig");
    _ = @import("Renderer/Device/RenderState.zig");
}
