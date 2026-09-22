#include <metal_stdlib>
using namespace metal;

struct Quad { float2 origin; float2 size; float2 canvas; };
struct VertexOut { float4 position [[position]]; float2 uv; };

vertex VertexOut vertex_quad(uint id [[vertex_id]], constant Quad &quad [[buffer(0)]]) {
    float2 uv = float2(id & 1, (id >> 1) & 1);
    float2 pixel = quad.origin + uv * quad.size;
    VertexOut out;
    out.position = float4(
      pixel.x / quad.canvas.x * 2.0 - 1.0,
      1.0 - pixel.y / quad.canvas.y * 2.0,
      0.0,
      1.0
    );
    out.uv = uv;
    return out;
}

fragment float4 draw_background(VertexOut in [[stage_in]], constant float4 &color [[buffer(0)]]) {
    (void)in;
    return color;
}

fragment float4 draw_source(VertexOut in [[stage_in]], texture2d<float, access::sample> source [[texture(0)]]) {
    constexpr sampler linear_sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    return source.sample(linear_sampler, in.uv);
}
