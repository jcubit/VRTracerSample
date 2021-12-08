//
//  Scene.swift
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

import simd
import Metal

///// Vertices of the triangle that forms the cube
//var allCubeVertices    = [SIMD4<Float>].init()
///// Vertex Indices of the triangle that forms the cube
//var allIndices         = [UInt32].init()
///// The color of each vertex that forms the triangle primitives for the cube
//var faceColors      = [SIMD3<Float>].init()
//
//
///// Adds a cube face into the vertex buffer, faceVertices
/////
///// Adapted from MTLRayTracingSample from WWDC20
/////
///// - Parameters:
/////   - faceVertices: total vertex buffer
/////   - faceColors: total color buffer
/////   - color: the color of each vertex in this face
/////   - cubeVertices: the array of vertices of the cube
/////   - i0: first vertex index of the face
/////   - i1: second vertex index of the face
/////   - i2: third vertex index of the face
/////   - i3: fourth vertex index of the face
//public func createCubeFace( faceVertices: inout [SIMD4<Float>],
//                            faceColors : inout [SIMD3<Float>],
//                            color:  SIMD3<Float>,
//                            cubeVertices: [SIMD4<Float>],
//                            i0 : Int,
//                            i1 : Int,
//                            i2 : Int,
//                            i3 : Int)
//{
//    faceVertices.append(cubeVertices[i0])
//    faceVertices.append(cubeVertices[i1])
//    faceVertices.append(cubeVertices[i2])
//    faceVertices.append(cubeVertices[i0])
//    faceVertices.append(cubeVertices[i2])
//    faceVertices.append(cubeVertices[i3])
//
//    allIndices.append(UInt32(i0))
//    allIndices.append(UInt32(i1))
//    allIndices.append(UInt32(i2))
//    allIndices.append(UInt32(i0))
//    allIndices.append(UInt32(i2))
//    allIndices.append(UInt32(i3))
//
//    for _ in 0..<6 {
//        faceColors.append(color)
//    }
//}
//
//public func createCube(color: SIMD3<Float>, transform: simd_float4x4){
//
//    let cubeVertices = [simd_float4].init(
//        arrayLiteral:
//            transform * simd_float4(x: -0.5, y: -0.5, z: -0.5, w: 1),
//            transform * simd_float4(x:  0.5, y: -0.5, z: -0.5, w: 1),
//            transform * simd_float4(x: -0.5, y:  0.5, z: -0.5, w: 1),
//            transform * simd_float4(x:  0.5, y:  0.5, z: -0.5, w: 1),
//            transform * simd_float4(x: -0.5, y: -0.5, z:  0.5, w: 1),
//            transform * simd_float4(x:  0.5, y: -0.5, z:  0.5, w: 1),
//            transform * simd_float4(x: -0.5, y:  0.5, z:  0.5, w: 1),
//            transform * simd_float4(x:  0.5, y:  0.5, z:  0.5, w: 1))
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 6, i3: 4)
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 1, i1: 3, i2: 7, i3: 5)
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 1, i2: 5, i3: 4)
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 2, i1: 6, i2: 7, i3: 3)
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 3, i3: 1)
//
//    createCubeFace(faceVertices: &allCubeVertices, faceColors: &faceColors, color: color, cubeVertices: cubeVertices, i0: 4, i1: 5, i2: 7, i3: 6)
//
//}


public class Scene {
    /// The device used to create the scene.
    let device : MTLDevice
    
    /// Array of geometries in the scene
    var geometries : [Geometry]
    /// Array of geometry instances in the scene
    var instances : [GeometryInstance]
    
    /// Camera origin
    var cameraPosition  : SIMD3<Float>
    
    ///  Camera "target" vector. The camera faces this point.
    var cameraTarget    : SIMD3<Float>
    
    ///  Camera "up" vector.
    var cameraUp        : SIMD3<Float>
    
    public init(device : MTLDevice){
        self.device = device
        
        cameraPosition  = SIMD3<Float>(0.0, 0.0, -1.0)
        cameraTarget    = SIMD3<Float>(0.0, 0.0, 0.0)
        cameraUp        = SIMD3<Float>(0.0, 1.0, 0.0)
        
        geometries = [Geometry]()
        instances = [GeometryInstance]()
    }
    
    public func addGeometry(geometry: Geometry){
        geometries.append(geometry)
    }
    
    public func addInstance(instance: GeometryInstance){
        instances.append(instance)
    }
    
    /// Creates a scene with a single cube
    public func newInstancedCubeScene(device : MTLDevice, useIntersectionFunctions: Bool) -> Scene {
        let scene = Scene(device: device)
        
        // Set up camera
        scene.cameraPosition  = SIMD3<Float>(0.0, 0.0, -1.72) //SIMD3<Float>(0.0, 0.0, -1.0)
        scene.cameraTarget    = SIMD3<Float>(0.0, 0.0, 0.0) // SIMD3<Float>(0.0, 0.0, 0.0)
        scene.cameraUp        = SIMD3<Float>(0.0, 1.0, 0.0) // SIMD3<Float>(0.0, 1.0, 0.0)
        
        // Sample Camera
        //        scene.cameraPosition  = SIMD3<Float>(0.0, 1.0, 10.0)
        //        scene.cameraTarget    = SIMD3<Float>(0.0, 1.0, 0.0)
        //        scene.cameraUp        = SIMD3<Float>(0.0, 1.0, 0.0)
        
        let transform = matrix_identity_float4x4
        
        let geometryMesh = Geometry(device: device)
        
        // set geometry mesh of cube
        geometryMesh.addCubeWithFaces(color: SIMD4<Float>(x: 1.0, y: 0.0, z: 0.0, w: 1), //SIMD4<Float>(x: 0.725, y: 0.71, z: 0.68, w: 1),
                                      transform: transform)
        
        scene.addGeometry(geometry: geometryMesh)
        
        // Create an instance of the cube
        let instance = GeometryInstance(geometry: geometryMesh, transform: transform)
        scene.addInstance(instance: instance)
        
        return scene
    }
    
    /// copies all the geometry buffers into MTLBuffers
    public func uploadToBuffers() {
        for geometry in geometries {
            geometry.uploadToBuffers()
        }
    }
    
    
} // class Scene

/// the different types of geometries available in the scene. Here we consider only
/// Geometry objects out of triangle primitives.  Each Geometry object has its
/// own primitive acceleration structure and, optionally, an intersection function.
/// The sample creates copies, or "instances" of geometry objects using the GeometryInstance
/// class.
///  Note: we need to inherit from NSObject in order to use Array.firstIndex
public class Geometry : NSObject {
    // Metal device used to create the acceleration structures.
    let device : MTLDevice;

    // Name of the intersection function to use for this geometry, or nil
    // for triangles.
    let intersectionFunctionName    : String?
    
    var vertexPositionBuffer        : MTLBuffer!
    var vertexColorBuffer           : MTLBuffer!
    
    var vertices                    = [SIMD4<Float>]()
    var colors                      = [SIMD4<Float>]()
    
    public init(device : MTLDevice){
        self.device = device

        self.intersectionFunctionName = nil
        
    }
    
    /// Copies a swift array of vertices into a MTLBuffer
    public func uploadToBuffers() {
        assert(vertices.count > 0 && colors.count > 0, "vertices or colors arrays have not being loaded")
        
        guard let vertexPositionBuffer = self.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * vertices.count,
                                                               options: .storageModeShared) else {
            fatalError("[Geometry.init] device could not make a buffer")
        }
        self.vertexPositionBuffer = vertexPositionBuffer


        guard let vertexColorBuffer = self.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * colors.count,
                                                               options: .storageModeShared) else {
            fatalError("[Geometry.init] device could not make a buffer")
        }
        self.vertexColorBuffer = vertexColorBuffer
        
        print("vertices count: ", vertices.count)
        print("colors count: ", colors.count)
        
        // For MacOs the storage option is Managed, while in iOS Shared
        let storageOption = MTLResourceOptions.storageModeManaged
        
        guard let vertexPositionBuffer = self.device.makeBuffer(bytes: vertices,
                                                                length: MemoryLayout<SIMD4<Float>>.stride * vertices.count,
                                                                options: storageOption) else {
            fatalError("[Geometry.init] device could not make a buffer out of a Swift Array")
        }
        // copy vertex array content into MTLBuffer
        self.vertexPositionBuffer = vertexPositionBuffer
        self.vertexPositionBuffer.contents().copyMemory(from: self.vertices, byteCount: vertexPositionBuffer.length)
//        self.vertexPositionBuffer.contents().initializeMemory(as: SIMD4<Float>.self, from: self.vertices, count: self.vertices.count)
        
        guard let vertexColorBuffer = self.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * colors.count,
                                                               options: storageOption) else {
            fatalError("[Geometry.init] device could not make a buffer")
        }
        // copy colors array content into MTLBuffer
        self.vertexColorBuffer = vertexColorBuffer
        self.vertexColorBuffer.contents().copyMemory(from: self.colors, byteCount: vertexColorBuffer.length)
//        self.vertexColorBuffer.contents().initializeMemory(as: SIMD4<Float>.self, from: self.colors, count: self.colors.count)
        
        vertexPositionBuffer.didModifyRange(0..<vertexPositionBuffer.length)
        vertexColorBuffer.didModifyRange(0..<vertexColorBuffer.length)
        
        
    }
    
    /// Gets the acceleration structure geometry descriptor for this piece of geometry.
    public func geometryDescriptor() -> MTLAccelerationStructureGeometryDescriptor? {
        // Metal represents each piece of piece of geometry in an acceleration structure using
        // a geometry descriptor. The App uses a triangle geometry descriptor to represent
        // triangle geometry. Each triangle geometry descriptor can have its own
        // vertex buffer, index buffer, and triangle count. The App uses a single geometry
        // descriptor since it already packed all of the vertex data into a single buffer.
        let descriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
        
        descriptor.vertexBuffer = self.vertexPositionBuffer;
        descriptor.vertexStride = MemoryLayout<SIMD4<Float>>.stride
        descriptor.triangleCount = self.vertices.count / 3;

        return descriptor;
    }
    
    public func resources() -> [MTLResource]{
        return [self.vertexColorBuffer]
    }
    
    public func clear(){
        self.vertices.removeAll()
        self.colors.removeAll()
    }
    
    /// Adds an entire cube to the scene
    public func addCubeWithFaces(color: SIMD4<Float>,
                                 transform : simd_float4x4)
    {
        let cubeVertices = [SIMD4<Float>](
            arrayLiteral:
                transform * SIMD4<Float>(x: -0.5, y: -0.5, z: -0.5, w: 1),
                transform * SIMD4<Float>(x:  0.5, y: -0.5, z: -0.5, w: 1),
                transform * SIMD4<Float>(x: -0.5, y:  0.5, z: -0.5, w: 1),
                transform * SIMD4<Float>(x:  0.5, y:  0.5, z: -0.5, w: 1),
                transform * SIMD4<Float>(x: -0.5, y: -0.5, z:  0.5, w: 1),
                transform * SIMD4<Float>(x:  0.5, y: -0.5, z:  0.5, w: 1),
                transform * SIMD4<Float>(x: -0.5, y:  0.5, z:  0.5, w: 1),
                transform * SIMD4<Float>(x:  0.5, y:  0.5, z:  0.5, w: 1))
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 6, i3: 4)
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 1, i1: 3, i2: 7, i3: 5)
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 0, i1: 1, i2: 5, i3: 4)
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 2, i1: 6, i2: 7, i3: 3)
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 0, i1: 2, i2: 3, i3: 1)
        
        addCubeFaceWithCubeVertices(color: color, cubeVertices: cubeVertices, i0: 4, i1: 5, i2: 7, i3: 6)
    }
    
    /// Adds a single cube face to the array of vertices
    private func addCubeFaceWithCubeVertices(color:  SIMD4<Float>,
                                             cubeVertices: [SIMD4<Float>],
                                             i0 : Int,
                                             i1 : Int,
                                             i2 : Int,
                                             i3 : Int)
    {
        self.vertices.append(cubeVertices[i0])
        self.vertices.append(cubeVertices[i1])
        self.vertices.append(cubeVertices[i2])
        self.vertices.append(cubeVertices[i0])
        self.vertices.append(cubeVertices[i2])
        self.vertices.append(cubeVertices[i3])
      
      for _ in 0..<6 {
          self.colors.append(color)
      }
    }
    
} // class Geometry

/// The different copies that a geometry object can have in the scene
public struct GeometryInstance {
    
    let geometry    : Geometry
    let transform   : simd_float4x4
    
    public init(geometry : Geometry, transform: simd_float4x4){
        self.geometry   = geometry
        self.transform  = transform
    }
    
} // struct GeometryInstance
