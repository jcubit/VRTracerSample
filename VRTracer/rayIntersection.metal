//
//  rayIntersection.metal
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

#include <metal_stdlib>
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>

#include "ShaderTypes.h"

using namespace metal;


using Ray          = MPSRayOriginMinDistanceDirectionMaxDistance;
using Intersection = MPSIntersectionDistancePrimitiveIndexCoordinates;



/// Rays generated from a constant point (pinhole)
kernel void generateRays(device Ray* rays [[buffer(0)]],
                         constant Uniforms & uniforms,
                         uint2 coordinates [[thread_position_in_grid]],
                         uint2 size [[threads_per_grid]])
{
//    constant Camera & camera = uniforms.camera;
    
//    const float3 origin = float3(0.0f, 1.0f, 2.1f);
    const float3 origin = float3(0.0f, 0.0f, 2.1f);
    
    float aspectRation = float(size.x) / float(size.y);
    

    // Map pixel coordinates to [-1,1]
    float2 uv = float2(coordinates) / float2(size - 1);
    uv = uv * 2.0f -1.0f;
    // In one line: float2 uv = float2(coordinates) / float2(size - 1) * 2.0f - 1.0f;
    
    float3 direction = normalize(float3(aspectRation * uv.x, uv.y, -1.0f));
    
    uint rayIndex = coordinates.x + coordinates.y * size.x;

    rays[rayIndex].origin       = origin;
    rays[rayIndex].direction    = direction;
    rays[rayIndex].minDistance  = 0.0f;
    rays[rayIndex].maxDistance  = INFINITY;
}

/// Process the Intersection structs obtained from the intersection. It writes to the final texture
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
        // test red cube ------
//        float4 color(1,0,0,1);
//        image.write(color, coordinates);
    }
}


