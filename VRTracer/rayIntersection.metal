//
//  rayIntersection.metal
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

#include <metal_stdlib>
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>

using namespace metal;


using Ray          = MPSRayOriginMinDistanceDirectionMaxDistance;
using Intersection = MPSIntersectionDistancePrimitiveIndexCoordinates;

///
kernel void generateRays(device Ray* rays [[buffer(0)]],
                         uint2 coordinates [[thread_position_in_grid]],
                         uint2 size [[threads_per_grid]])
{
    uint rayIndex = coordinates.x + coordinates.y * size.x;
    float2 uv = float2(coordinates) / float2(size - 1);
    rays[rayIndex].origin       = MPSPackedFloat3(uv.x, uv.y, -1.0);
    rays[rayIndex].direction    = MPSPackedFloat3(0.0, 0.0, 1.0);
    rays[rayIndex].minDistance  = 0.0f;
    rays[rayIndex].maxDistance  = 2.0f;
}


kernel void handleIntersections(texture2d<float, access::write> image [[texture(0)]],
                                device const Intersection* intersections [[buffer(0)]],
                                uint2 coordinates [[thread_position_in_grid]],
                                uint2 size [[threads_per_grid]])
{
    uint rayIndex = coordinates.x + coordinates.y * size.x;
    device const Intersection& hit = intersections[rayIndex];
    if(hit.distance > 0.0f)
    {
        float w = 1.0 - hit.coordinates.x - hit.coordinates.y;
        image.write(float4(hit.coordinates, w, 1.0), coordinates);
    }
}
