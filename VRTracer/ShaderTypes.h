//
//  ShaderTypes.h
//  VRTracer
//
//

#ifndef ShaderTypes_h
#define ShaderTypes_h


#include <simd/simd.h>



struct FlyCamera {
//    simd_float4x4 worldToCamera;
    simd_float4x4 cameraToWorld;
//    simd_float4x4 viewportToNDC;
//    simd_float4x4 NDCToCamera;
    simd_float4x4 viewportToCamera;
};

struct UniformsFlyCamera
{
    unsigned int width;
    unsigned int height;
    unsigned int frameIndex;
    struct FlyCamera camera;
};



#endif /* ShaderTypes_h */


