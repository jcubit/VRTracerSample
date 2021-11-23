//
//  blit.metal
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

#include <metal_stdlib>
using namespace metal;

struct BlitVertexOut
{
    float4 position [[position]];
    float2 texelCoordinates;
};

constant constexpr static const float4 fullscreenTrianglePositions[3]
{
    {-1.0, -1.0, 0.0, 1.0},
    { 3.0, -1.0, 0.0, 1.0},
    {-1.0,  3.0, 0.0, 1.0}
};

vertex BlitVertexOut blitVertex(uint vertexIndex [[vertex_id]])
{
    BlitVertexOut out;
    out.position = fullscreenTrianglePositions[vertexIndex];
    // Transforms from NDC [-1,1] space to Normalized Texture Space [0,1]
    out.texelCoordinates = out.position.xy * 0.5 + 0.5;
    return out;
}

fragment float4 blitFragment(BlitVertexOut in [[stage_in]],
                             texture2d<float> image [[texture(0)]])
{
    constexpr sampler linearSampler(coord::normalized, filter::nearest);
    float4 color = image.sample(linearSampler, in.texelCoordinates);
    return color;
}
