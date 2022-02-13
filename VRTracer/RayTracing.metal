//
//  RayTracing.metal
//  VRTracer
//
//

#include "ShaderTypes.h"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

using namespace raytracing;

constant unsigned int resourcesStride   [[function_constant(0)]];
constant bool useIntersectionFunctions  [[function_constant(1)]];

// Resources for a piece of triangle geometry.
struct TriangleResources {
    device float3* vertexColors;
};

// Interpolates vertex attribute of an arbitrary type across the surface of a triangle
// given the barycentric coordinates and triangle index in an intersection structure.
template<typename T>
inline T interpolateVertexAttribute(device T *attributes, unsigned int primitiveIndex, float2 uv) {
    // Look up value for each vertex.
    T T0 = attributes[primitiveIndex * 3 + 0];
    T T1 = attributes[primitiveIndex * 3 + 1];
    T T2 = attributes[primitiveIndex * 3 + 2];

    // Compute sum of vertex attributes weighted by barycentric coordinates.
    // Barycentric coordinates sum to one.
    return (1.0f - uv.x - uv.y) * T0 + uv.x * T1 + uv.y * T2;
}


__attribute__((always_inline))
float3 transformPoint(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 1.0f)).xyz;
}

__attribute__((always_inline))
float3 transformDirection(float3 p, float4x4 transform) {
    return (transform * float4(p.x, p.y, p.z, 0.0f)).xyz;
}
                                                       

// Main ray tracing kernel
kernel void raytracingKernelFlyCamera(uint2 tid [[thread_position_in_grid]],
                                     constant UniformsFlyCamera& uniformsFlyCamera,
                                     texture2d<float, access::write> dstTex,
                                     device void* resources,
                                     device MTLAccelerationStructureInstanceDescriptor* instances,
                                     instance_acceleration_structure accelerationStructure,
                                     intersection_function_table<triangle_data, instancing> intersectionFunctionTable)
{
    // The App aligns the thread count to the threadgroup size. which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if(tid.x < uniformsFlyCamera.width && tid.y < uniformsFlyCamera.height) {
        // The ray to cast
        ray ray;
        
        constant FlyCamera& camera = uniformsFlyCamera.camera;
        
        // Ray start at the camera position (world space coordinates)
        float4 cameraPosition = camera.cameraToWorld * float4(0,0,0,1);
        ray.origin = float3(cameraPosition.x, cameraPosition.y, cameraPosition.z);
        
        
        // set ray's direction in world space coordinates
        float4 pViewport  = float4(tid.x, tid.y, 1, 1); // as seen in the viewport space in homogeneous coordinates
        float4 pCamera    = camera.viewportToCamera * pViewport;
        pCamera.w = 1;
        
        float4 pWorld       = camera.cameraToWorld * pCamera;
        float4 rayDirection = pWorld - cameraPosition;
        ray.direction = normalize(float3(rayDirection.x, rayDirection.y, rayDirection.z));
        // we could have alternative compute the vector in camera space and transformed into world coordinates by
        // the affine trafo cameraToWorld
//        float4 dirInCameraSpace = float4(pCamera.x, pCamera.y, pCamera.z, 0);
//        float4 rayDirection = camera.cameraToWorld * dirInCameraSpace;
//        ray.direction = normalize(float3(rayDirection.x, rayDirection.y, rayDirection.z));


        // Don't limit intersection distance.
        ray.max_distance = INFINITY;
        
        // Start with a fully white color. The kernel scales the light each time the
        // ray bounces off of a surface, based on how much of each light component
        // the surface absorbs.
        float3 color = float3(1.0f, 1.0f, 1.0f);
        
        // We use it here as the background color
        float3 accumulatedColor = float3(1.0f, 0.0f, 0.0f);
        
        // Create an intersector to test for intersection between the ray and the geometry in the scene.
        intersector<triangle_data, instancing> intersectorTest;
        
        // If the sample isn't using intersection functions, provide some hints to Metal for
        // better performance
        if (!useIntersectionFunctions) {
            intersectorTest.assume_geometry_type(geometry_type::triangle);
            intersectorTest.force_opacity(forced_opacity::opaque);
        }
        
        typename metal::raytracing::intersector<triangle_data, instancing>::result_type intersection;
        
        intersectorTest.accept_any_intersection(false);
        
        // Check for intersection between the ray and the acceleration structure. If the App
        // isn't using intersection functions, it doesn't need to include one.
        if (useIntersectionFunctions) {
            intersection = intersectorTest.intersect(ray, accelerationStructure, intersectionFunctionTable);
        } else {
            intersection = intersectorTest.intersect(ray, accelerationStructure);
        }
        
        unsigned int instanceIndex = intersection.instance_id;
        
        // Stop if the ray didn't hit anything and has bounced out of the scene.
        if(intersection.type == intersection_type::none){
            dstTex.write(float4(accumulatedColor, 1.0f), tid);
            return;
        }
        else {
        
        unsigned primitiveIndex = intersection.primitive_id;
        unsigned int geometryIndex = instances[instanceIndex].accelerationStructureIndex;
        float2 barycentric_coords = intersection.triangle_barycentric_coord;
        
        float3 surfaceColor = 0.0f;
        
        // The ray hit a triangle. Look up the corresponding geometry's normal and UV buffers.
        device TriangleResources& triangleResources = *(device TriangleResources *) ((device char *)resources + resourcesStride * geometryIndex);
        
        // Interpolate the vertex color at the intersection point.
        surfaceColor = interpolateVertexAttribute(triangleResources.vertexColors, primitiveIndex, barycentric_coords);
        
        // Scale the ray color by the color of the surface. This simulates light being absorbed into
        // the surface.
        color *= surfaceColor;
        
        dstTex.write(float4(color, 1.0f), tid);
        }
    }
}

