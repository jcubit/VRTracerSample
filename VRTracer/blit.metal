//
//  blit.metal
//  VRTracer
//
//

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;


struct BlitVertexIn {
  float4 position [[attribute(0)]];
};

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
    
//    {-0.5, -0.5, 0.0, 1.0},
//    { 1.0, -0.5, 0.0, 1.0},
//    {-0.5,  1.0, 0.0, 1.0}
};

vertex BlitVertexOut blitVertex(uint vertexIndex [[vertex_id]],
                                constant Uniforms& uniforms [[ buffer(2)]])
{
    BlitVertexOut out;
    out.position = fullscreenTrianglePositions[vertexIndex];

    // Transforms texture coordinates from NDC [-1,1] space to Normalized Texture Space [0,1]
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


// ----------------  2nd Version  of blit ----------------------------------------------

// Screen filling quad in normalized device coordinates.
constant float2 quadVertices[] = {
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1)
};

struct CopyVertexOut {
    float4 position [[position]];
    float2 uv;
};

// Simple vertex shader which passes through NDC quad positions.
vertex CopyVertexOut copyVertex(unsigned short vid [[vertex_id]]) {
    float2 position = quadVertices[vid];

    CopyVertexOut out;

    out.position = float4(position, 0, 1);
    // set texture coordinates from [-1,1] to [0,1]
    out.uv = position * 0.5f + 0.5f;

    return out;
}

// Simple fragment shader which copies a texture and applies a simple tonemapping function.
fragment float4 copyFragment(CopyVertexOut in [[stage_in]],
                             texture2d<float> tex [[texture(0)]])
{
    constexpr sampler sam(min_filter::nearest, mag_filter::nearest, mip_filter::none);

    float3 color = tex.sample(sam, in.uv).xyz;

    // Apply a very simple tonemapping function to reduce the dynamic range of the
    // input image into a range which the screen can display.
//    color = color / (1.0f + color);

    return float4(color, 1.0f);
}






