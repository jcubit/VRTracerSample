//
//  Scene.swift
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

import simd

/// Vertices of the triangle that forms the cube
var allCubeVertices    = [simd_float4].init()
/// Vertex Indices of the triangle that forms the cube
var allIndices         = [UInt32].init()
/// The color of each vertex that forms the triangle primitives for the cube
var faceColors      = [simd_float3].init()


/// Adds a cube face into the vertex buffer, faceVertices
/// - Parameters:
///   - faceVertices: total vertex buffer
///   - faceColors: total color buffer
///   - color: the color of each vertex in this face
///   - cubeVertices: the array of vertices of the cube
///   - i0: first vertex index of the face
///   - i1: second vertex index of the face
///   - i2: third vertex index of the face
///   - i3: fourth vertex index of the face
public func createCubeFace( faceVertices: inout [simd_float4],
                            faceColors : inout [simd_float3],
                            color:  simd_float3,
                            cubeVertices: [simd_float4],
                            i0 : Int,
                            i1 : Int,
                            i2 : Int,
                            i3 : Int)
{
    faceVertices.append(cubeVertices[i0])
    faceVertices.append(cubeVertices[i1])
    faceVertices.append(cubeVertices[i2])
    faceVertices.append(cubeVertices[i0])
    faceVertices.append(cubeVertices[i2])
    faceVertices.append(cubeVertices[i3])

    allIndices.append(UInt32(i0))
    allIndices.append(UInt32(i1))
    allIndices.append(UInt32(i2))
    allIndices.append(UInt32(i0))
    allIndices.append(UInt32(i2))
    allIndices.append(UInt32(i3))
    
    for _ in 0..<6 {
        faceColors.append(color)
    }
}

public func createCube(color: simd_float3, transform: simd_float4x4){
    
    let cubeVertices = [simd_float4].init(
        arrayLiteral:
            transform * simd_float4(x: -0.5, y: -0.5, z: -0.5, w: 1),
            transform * simd_float4(x:  0.5, y: -0.5, z: -0.5, w: 1),
            transform * simd_float4(x: -0.5, y:  0.5, z: -0.5, w: 1),
            transform * simd_float4(x:  0.5, y:  0.5, z: -0.5, w: 1),
            transform * simd_float4(x: -0.5, y: -0.5, z:  0.5, w: 1),
            transform * simd_float4(x:  0.5, y: -0.5, z:  0.5, w: 1),
            transform * simd_float4(x: -0.5, y:  0.5, z:  0.5, w: 1),
            transform * simd_float4(x:  0.5, y:  0.5, z:  0.5, w: 1))
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 6, i3: 4)
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 1, i1: 3, i2: 7, i3: 5)
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 1, i2: 5, i3: 4)
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 2, i1: 6, i2: 7, i3: 3)
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 3, i3: 1)
    
    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 4, i1: 5, i2: 7, i3: 6)
    
}
