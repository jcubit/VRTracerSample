//
//  ShaderTypes.h
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>



typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

typedef struct
{
    // TODO: These are the matrix that we are interested
//    matrix_float4x4 modelMatrix;
//      matrix_float4x4 viewMatrix;
//      matrix_float4x4 projectionMatrix;
    
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;




typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
};


#endif /* ShaderTypes_h */


