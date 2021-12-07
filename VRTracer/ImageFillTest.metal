//
//  ImageFillTest.metal
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

#include <metal_stdlib>
using namespace metal;

/// Fills the complete image with interpolated values
kernel void imageFillTest(texture2d<float, access::write> image [[texture(0)]],
                          uint2 coordinates [[thread_position_in_grid]],
                          uint2 size [[threads_per_grid]])
{
    float2 uv = float2(coordinates) / float2(size - 1);
    image.write(float4(uv, 0.0, 1.0), coordinates);
}

