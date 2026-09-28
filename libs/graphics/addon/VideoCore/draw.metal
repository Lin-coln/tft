#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };

vertex VertexOut vertex_quad(uint id [[vertex_id]], constant float4x4 &transform [[buffer(0)]]) {
    float2 uv = float2(id & 1, (id >> 1) & 1);
    VertexOut out;
    out.position = transform * float4(uv, 0.0, 1.0);
    out.uv = uv;
    return out;
}

fragment float4 draw_source(VertexOut in [[stage_in]], texture2d<float, access::sample> source [[texture(0)]]) {
    constexpr sampler linear_sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    return source.sample(linear_sampler, in.uv);
}
