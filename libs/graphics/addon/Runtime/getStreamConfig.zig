const napi = @import("napi-zig");
const cap = @import("capture");
const Self = @import("Self.zig");

const ResolveConfig = cap.Encoder.ResolveConfig;

pub fn getStreamConfig(self: *Self, env: napi.Env) !napi.Val {
    const renderer = self.renderer orelse return env.createNull();
    const cfg = renderer.encoder.getResolvedConfig() orelse return env.createNull();
    defer cfg.release();

    return streamConfigToJs(env, cfg);
}

fn streamConfigToJs(env: napi.Env, cfg: *ResolveConfig) !napi.Val {
    const value = try env.createObject();
    const data = try env.createBuffer(cfg.size);
    @memcpy(data.data, cfg.data);

    try value.setNamedProperty(env, "data", data.val);
    try value.setNamedProperty(env, "size", try env.toJs(cfg.size));
    try value.setNamedProperty(env, "width", try env.toJs(cfg.width));
    try value.setNamedProperty(env, "height", try env.toJs(cfg.height));
    try value.setNamedProperty(env, "nalLengthSize", try env.toJs(cfg.nal_length_size));
    return value;
}
