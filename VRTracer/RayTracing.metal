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


// Return type for a bounding box intersection function
struct BoundingBoxIntersection {
    bool accept       [[accept_intersection]]; // whether to accept or reject the intersection.
    float distance    [[distance]];
};

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


/*
 Custom sphere intersection function. The [[intersection]] keyword marks this as an intersection
 function. The [[bounding_box]] keyword means that this intersection function handles intersecting rays
 with bounding box primitives. To create sphere primitives, the sample creates bounding boxes that
 enclose the sphere primitives.

 The [[triangle_data]] and [[instancing]] keywords indicate that the intersector that calls this
 intersection function returns barycentric coordinates for triangle intersections and traverses
 an instance acceleration structure. These keywords must match between the intersection functions,
 intersection function table, intersector, and intersection result to ensure that Metal propagates
 data correctly between stages. Using fewer tags when possible may result in better performance,
 as Metal may need to store less data and pass less data between stages. For example, if you do not
 need barycentric coordinates, omitting [[triangle_data]] means Metal can avoid computing and storing
 them.

 The arguments to the intersection function contain information about the ray, primitive to be
 tested, and so on. The ray intersector provides this datas when it calls the intersection function.
 Metal provides other built-in arguments but this sample doesn't use them.
 */

[[intersection(bounding_box, triangle_data, instancing)]]
BoundingBoxIntersection boundingboxIntersectionFunction(//Ray parameters passed to the ray intersector below
                                                        float3 origin               [[origin]],
                                                        float3 direction            [[direction]],
                                                        float minDistance           [[min_distance]],
                                                        float maxDistance           [[max_distance]],
                                                        // Information about the primitive.
                                                        unsigned int primitiveIndex [[primitive_id]],
                                                        unsigned int geometryIndex  [[geometry_intersection_function_table_offset]],
                                                        // Custom resources bound to the intersection function table.
                                                        device void* resources      [[buffer(0)]])
{
    // TODO: Complete and Adapt Example for a normal boundingBox
    BoundingBoxIntersection result;
    result.accept = true;
    return result;
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
kernel void raytracingKernel(uint2 tid [[thread_position_in_grid]],
                             constant Uniforms& uniforms,
                             texture2d<float, access::write> dstTex,
                             device void* resources,
                             device MTLAccelerationStructureInstanceDescriptor* instances,
                             instance_acceleration_structure accelerationStructure,
                             intersection_function_table<triangle_data, instancing> intersectionFunctionTable)
{
    // The App aligns the thread count to the threadgroup size. which means the thread count
    // may be different than the bounds of the texture. Test to make sure this thread
    // is referencing a pixel within the bounds of the texture.
    if(tid.x < uniforms.width && tid.y < uniforms.height) {
        // The ray to cast
        ray ray;
        
        // pixel coordinates for this thread
        float2 pixel = (float2)tid;
        
        //Map pixel coordinates to [-1,1]
        float2 uv = (float2)pixel / float2(uniforms.width, uniforms.height);
        uv = uv * 2.0f - 1.0f;
        
        constant Camera& camera = uniforms.camera;
        
        // Ray start at the camera position (world space coordinates)
        ray.origin = camera.position; // (0,0,-1)
        
        // Map normalized pixel coordinates into camera's coordinate system (right-handed)
        // i.e. toCamera * (u,v,1)
        ray.direction = normalize(uv.x * camera.right +
                                  uv.y * camera.up +
                                  camera.forward);
        
        // Don't limit intersection distance.
        ray.max_distance = INFINITY;
        
        // Start with a fully white color. The kernel scales the light each time the
        // ray bounces off of a surface, based on how much of each light component
        // the surface absorbs.
        
        float3 color = float3(1.0f, 1.0f, 1.0f);
        
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
//            intersection = intersectorTest.intersect(ray, accelerationStructure, 0, intersectionFunctionTable);
        } else {
            intersection = intersectorTest.intersect(ray, accelerationStructure);
//            intersection = intersectorTest.intersect(ray, accelerationStructure, 0);
        }
        
        unsigned int instanceIndex = intersection.instance_id;
        
        // Stop if the ray didn't hit anything and has bounced out of the scene.
        if(intersection.type == intersection_type::none){
            dstTex.write(float4(accumulatedColor, 1.0f), tid);
            return;
        }
        else {
            dstTex.write(float4(0.0f,1.0f,0.0f, 1.0f), tid);
            //return; // we can stop here for a basic intersection test
        
        
        // The ray hit something. Look up the transformation matrix for this instance.
        float4x4 objectToWorldSpaceTransform(1.0f);
        
        for (int column = 0; column < 4; ++column){
            for (int row = 0; row < 3; ++row) {
                objectToWorldSpaceTransform[column][row] = instances[instanceIndex].transformationMatrix[column][row];
            }
        }
        
        // Compute intersection point in world space
        float3 worldSpaceIntersectionPoint = ray.origin + ray.direction * intersection.distance;
        
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
        
        // Average this frame's sample with all of the previous frames
//        if (uniforms.frameIndex > 0) {
//            float3 previousColor = previousTex.read(tid).xyz;
//            previousColor += uniforms.frameIndex;
//
//            accumulatedColor += previousColor;
//            accumulatedColor /= (uniforms.frameIndex + 1);
//        }
        
        dstTex.write(float4(color, 1.0f), tid);

        }
        
        
    }
}


// ----------------- rayTracing flycamera ------------------------------

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
        
        
        // set ray's direction is in world space coordinates
        // compute raster (viewport) and camera sample positions
        float3 pInPixels  = float3(tid.x, tid.y, 1); // as seen in the viewport space
        float3 pNDC       = camera.viewportToNDC * pInPixels;
        float4 pCamera    = camera.NDCToCamera * float4(pNDC.x, pNDC.y, pNDC.z,1);
        pCamera *= pCamera.w;
        
        ray.direction = normalize(float3(pCamera.x, pCamera.y, pCamera.z));


        // Don't limit intersection distance.
        ray.max_distance = INFINITY;
        
        // Start with a fully white color. The kernel scales the light each time the
        // ray bounces off of a surface, based on how much of each light component
        // the surface absorbs.
        
        float3 color = float3(1.0f, 1.0f, 1.0f);
        
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
//            intersection = intersectorTest.intersect(ray, accelerationStructure, 0, intersectionFunctionTable);
        } else {
            intersection = intersectorTest.intersect(ray, accelerationStructure);
//            intersection = intersectorTest.intersect(ray, accelerationStructure, 0);
        }
        
        unsigned int instanceIndex = intersection.instance_id;
        
        // Stop if the ray didn't hit anything and has bounced out of the scene.
        if(intersection.type == intersection_type::none){
            dstTex.write(float4(accumulatedColor, 1.0f), tid);
            return;
        }
        else {
            dstTex.write(float4(0.0f,1.0f,0.0f, 1.0f), tid);
            //return; // we can stop here for a basic intersection test
        
        
        // The ray hit something. Look up the transformation matrix for this instance.
        float4x4 objectToWorldSpaceTransform(1.0f);
        
        for (int column = 0; column < 4; ++column){
            for (int row = 0; row < 3; ++row) {
                objectToWorldSpaceTransform[column][row] = instances[instanceIndex].transformationMatrix[column][row];
            }
        }
        
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

