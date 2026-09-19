#include <metal_stdlib>
using namespace metal;

struct Params { float2 origin; float2 size; float4 background; };

kernel void draw_source(
    texture2d<float, access::sample> source [[texture(0)]],
    texture2d<float, access::write> target [[texture(1)]],
    constant Params &params [[buffer(0)]],
    uint2 position [[thread_position_in_grid]])
{
    if (position.x >= target.get_width() || position.y >= target.get_height()) return;
    float2 uv = (float2(position) + 0.5 - params.origin) / params.size;
    if (any(uv < 0.0) || any(uv > 1.0)) {
        target.write(params.background, position);
        return;
    }
    constexpr sampler linear_sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    target.write(source.sample(linear_sampler, uv), position);
}
