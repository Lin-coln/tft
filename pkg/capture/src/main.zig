pub const Renderer = @import("Renderer/Self.zig");

pub const Packet = @import("tft/stream").Encoder.Packet;
pub const ResolveConfig = @import("tft/stream").Encoder.ResolveConfig;

pub const CaptureSource = @import("CaptureSource.zig");

test {
    _ = Renderer;
    _ = CaptureSource;

    _ = @import("Renderer/Device/render.zig");
}
