//
//  blit.metal
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
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



//vertex BlitVertexOut blitVertex(const device BlitVertexIn* in [[buffer(0)]],
//                                constant Uniforms& uniforms [[ buffer(BufferIndexUniforms)]],
//                                uint vIdx [[vertex_id]])
//{
//    BlitVertexOut out;
//    out.position = uniforms.projectionMatrix * in[vIdx].position;
//
//    // Transforms from NDC [-1,1] space to Normalized Texture Space [0,1]
//    out.texelCoordinates = out.position.xy * 0.5 + 0.5;
//    return out;
//}


//constant constexpr static const float4 fullscreenTrianglePositions[36]
//{
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 6, i3: 2)
////
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 1, i1: 3, i2: 7, i3: 5)
////
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 1, i2: 5, i3: 4)
////
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 2, i1: 6, i2: 7, i3: 3)
////
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 3, i3: 1)
////
////    createCubeFace(faceVertices: &faceVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 4, i1: 5, i2: 7, i3: 6)
////
////    faceVertices.append(cubeVertices[i0])
////    faceVertices.append(cubeVertices[i1])
////    faceVertices.append(cubeVertices[i2])
////    faceVertices.append(cubeVertices[i0])
////    faceVertices.append(cubeVertices[i2])
////    faceVertices.append(cubeVertices[i3])
//
//
////    {-0.5, -0.5, -0.5, 1}, // 0
////    { 0.5, -0.5, -0.5, 1}, // 1
////    {-0.5,  0.5, -0.5, 1}, // 2
////    { 0.5,  0.5, -0.5, 1}, // 3
////    {-0.5, -0.5,  0.5, 1}, // 4
////    { 0.5, -0.5,  0.5, 1}, // 5
////    {-0.5,  0.5,  0.5, 1}, // 6
////    { 0.5,  0.5,  0.5, 1}, // 7
//
//        {-0.5, -0.5, -0.5, 1}, // 0
//        {-0.5,  0.5, -0.5, 1}, // 2
//        {-0.5,  0.5,  0.5, 1}, // 6
//        {-0.5, -0.5, -0.5, 1}, // 0
//        {-0.5,  0.5,  0.5, 1}, // 6
//        { 0.5,  0.5, -0.5, 1}, // 3
//    // second face
//        { 0.5, -0.5, -0.5, 1}, // 1
//        { 0.5,  0.5, -0.5, 1}, // 3
//        { 0.5,  0.5,  0.5, 1}, // 7
//        { 0.5, -0.5, -0.5, 1}, // 1
//        { 0.5,  0.5,  0.5, 1}, // 7
//        { 0.5, -0.5,  0.5, 1}, // 5
//    // third face
//        {-0.5, -0.5, -0.5, 1}, // 0
//        { 0.5, -0.5, -0.5, 1}, // 1
//        { 0.5, -0.5,  0.5, 1}, // 5
//        {-0.5, -0.5, -0.5, 1}, // 0
//        { 0.5, -0.5,  0.5, 1}, // 5
//        {-0.5, -0.5,  0.5, 1}, // 4
//
//
////    {-0.5,  0.5, -0.5, 1},
////    { 0.5,  0.5, -0.5, 1},
////    {-0.5, -0.5,  0.5, 1},
////    { 0.5, -0.5,  0.5, 1},
////    {-0.5,  0.5,  0.5, 1},
////    { 0.5,  0.5,  0.5, 1},
////    {-0.5, -0.5, -0.5, 1},
////    { 0.5, -0.5, -0.5, 1},
////    {-0.5,  0.5, -0.5, 1},
////    { 0.5,  0.5, -0.5, 1},
////    {-0.5, -0.5,  0.5, 1},
////    { 0.5, -0.5,  0.5, 1},
////    {-0.5,  0.5,  0.5, 1},
////    { 0.5,  0.5,  0.5, 1},
////    {-0.5, -0.5, -0.5, 1},
////    { 0.5, -0.5, -0.5, 1},
////    {-0.5,  0.5, -0.5, 1},
////    { 0.5,  0.5, -0.5, 1},
////    {-0.5, -0.5,  0.5, 1},
////    { 0.5, -0.5,  0.5, 1},
////    {-0.5,  0.5,  0.5, 1},
////    { 0.5,  0.5,  0.5, 1}
//
////    { 0.0, 0.0,  0.0, 1},
////    { 0.0,  1.0,  0.0, 1},
////    { 0.5,  0.5,  0.0, 1}
//};

constant constexpr static const float4 fullscreenTrianglePositions[3]
{
    {-1.0, -1.0, 0.0, 1.0},
    { 3.0, -1.0, 0.0, 1.0},
    {-1.0,  3.0, 0.0, 1.0}
};

vertex BlitVertexOut blitVertex(uint vertexIndex [[vertex_id]],
                                constant Uniforms& uniforms [[ buffer(BufferIndexUniforms)]])
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
