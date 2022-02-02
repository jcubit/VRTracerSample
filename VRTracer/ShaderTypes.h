//
//  ShaderTypes.h
//  VRTracer
//
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

//#ifdef __METAL_VERSION__
//#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
//#define NSInteger metal::int32_t
//#else
//#import <Foundation/Foundation.h>
//#endif

#include <simd/simd.h>



//typedef NS_ENUM(NSInteger, BufferIndex)
//{
//    BufferIndexMeshPositions = 0,
//    BufferIndexMeshGenerics  = 1,
//    BufferIndexUniforms      = 2
//};
//
//typedef NS_ENUM(NSInteger, VertexAttribute)
//{
//    VertexAttributePosition  = 0,
//    VertexAttributeTexcoord  = 1,
//};


struct Camera {
    simd_float3 position;
    simd_float3 right;
    simd_float3 up;
    simd_float3 forward;
};


struct Uniforms
{
    unsigned int width;
    unsigned int height;
    unsigned int frameIndex;
    struct Camera camera;
    
// TODO: Refactor Uniforms to include these matrices
//    matrix_float4x4 modelMatrix;
//      matrix_float4x4 viewMatrix;
//      matrix_float4x4 projectionMatrix;
// or
//    matrix_float4x4 modelViewMatrix;
} ;




//typedef NS_ENUM(NSInteger, TextureIndex)
//{
//    TextureIndexColor    = 0,
//};


#endif /* ShaderTypes_h */


