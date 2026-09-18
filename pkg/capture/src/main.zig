pub const Renderer = @import("Renderer/Self.zig");

pub const Packet = @import("tft/stream").Packet;
pub const ResolveConfig = @import("tft/stream").ResolveConfig;

test {
    _ = Renderer.Encoder;

    _ = @import("Renderer/Scaler.zig");
}
