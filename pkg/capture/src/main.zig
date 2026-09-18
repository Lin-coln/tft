pub const Renderer = @import("Renderer/Self.zig");

pub const Encoder = Renderer.Encoder;

pub const Packet = @import("tft/stream").Packet;

test {
    _ = Encoder;
    _ = @import("Renderer/Scaler.zig");
}
