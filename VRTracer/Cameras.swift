//
//  Cameras.swift
//  VRTracer
//
//

import Foundation


/// General protocol for source cameras
protocol RTCamera : AnyObject {

    var cameraToWorld : simd_float4x4 { get set }
    var viewportToCamera : simd_float4x4 { get }
    
} // Camera protocol


/// Protocol for Projective Cameras where perspective is important
protocol ProjectiveCamera : RTCamera {
    
    var inversePerspective : simd_float4x4 { get }
    var viewportToNDC : simd_float4x4 { get set }
    var ndcToCamera : simd_float4x4 { get set }
    
} // ProjectiveCamera protocol


public final class PerspectiveCamera : ProjectiveCamera {

    // ProjectiveCamera Data
    // MARK: - Properties
    public var cameraToWorld : simd_float4x4
    public var windowSize : SIMD2<Float> {
        willSet{
#if os(iOS)
            self.windowToViewport =  matrix_identity_float4x4
#else
            self.windowToViewport = makeWindowToViewport(windowSize: windowSize)
#endif
            
            self.viewportToNDC    = makeViewportToNDC(windowSize: windowSize)
            self.ndcToCamera      = makeNDCtoCamera(windowSize: windowSize)
        }
    }
    /// Tangent of the Y-field of view divided by two
    private var TanFOVYByTwo : Float
    
    public let inversePerspective : simd_float4x4
    private var windowToViewport    : simd_float4x4 = matrix_identity_float4x4
    public var viewportToNDC    : simd_float4x4
    public var ndcToCamera    : simd_float4x4


    
    public var worldToCamera    : simd_float4x4 {
        get { cameraToWorld.inverse }
    }
    
    /// computes the viewport to camera space transformation. It takes into account the window to view transformation
    public var viewportToCamera : simd_float4x4 {
            return ndcToCamera * viewportToNDC * windowToViewport
    }

    
    /// Perspective camera constructor
    /// - Parameters:
    ///   - cameraToWorld: camera to world affine transformation
    ///   - windowSize: size of the be rendered window
    ///   - fieldOfViewY: Field of view with respect to the Y-axis in degrees
    ///   - zNear: distance of the near plane with respect to the camera space
    ///   - zFar: distance of the far plane with respect to the camera space
    init(cameraToWorld : simd_float4x4, windowSize: SIMD2<Float>, fieldOfViewY: Float = 45, zNear : Float = 0.01, zFar : Float = 1000) {
        self.cameraToWorld  = cameraToWorld
        self.windowSize     = windowSize
        self.TanFOVYByTwo   = tanf(toRadians(degrees: fieldOfViewY) / Float(2.0))

#if os(iOS)
        self.windowToViewport =  matrix_identity_float4x4
#else
        self.windowToViewport =  simd_float4x4(columns: (SIMD4<Float>(1,          0 ,   0  ,    0),
                                                         SIMD4<Float>(0,          -1,   0  ,    0),
                                                         SIMD4<Float>(0,          0 ,   1  ,    0),
                                                         SIMD4<Float>(0,windowSize.x,   0  ,    1)))
#endif


        self.viewportToNDC = simd_float4x4(columns: (SIMD4<Float>(2.0 / windowSize.x,            0.0     , 0.0, 0.0),
                                                     SIMD4<Float>(        0         , -2.0 / windowSize.y, 0.0, 0.0),
                                                     SIMD4<Float>(        0         ,            0.0     , -1 , 0.0),
                                                     SIMD4<Float>(      -1.0        ,           1.0      ,  0.0,1.0)))
        
        
        let aspectRatio : Float = windowSize.x / windowSize.y
        let scaleToImagePlane = simd_float4x4(scaleBy: SIMD3<Float>( aspectRatio * self.TanFOVYByTwo,
                                                                     self.TanFOVYByTwo,
                                                                     1))
        self.inversePerspective = InversePerspectiveMatrix(zNear: zNear, zFar: zFar)
        
        self.ndcToCamera = self.inversePerspective * scaleToImagePlane
        
    }
    
    private func makeWindowToViewport(windowSize: SIMD2<Float>) -> matrix_float4x4 {
        return simd_float4x4(columns: (SIMD4<Float>(1,          0 ,   0  ,    0),
                                       SIMD4<Float>(0,          -1,   0  ,    0),
                                       SIMD4<Float>(0,          0 ,   1  ,    0),
                                       SIMD4<Float>(0,windowSize.y,   0  ,    1)))
    }
    
    private func makeViewportToNDC(windowSize: SIMD2<Float>) -> matrix_float4x4 {
        return simd_float4x4(columns: (SIMD4<Float>(2.0 / windowSize.x,            0.0     , 0.0, 0.0),
                                       SIMD4<Float>(        0         , -2.0 / windowSize.y, 0.0, 0.0),
                                       SIMD4<Float>(        0         ,            0.0     , -1 , 0.0),
                                       SIMD4<Float>(      -1.0        ,           1.0      ,  0.0,1.0)))
    }
    
    private func makeNDCtoCamera(windowSize: SIMD2<Float>) -> matrix_float4x4 {
        return self.inversePerspective * makeScaleToImagePlane(windowSize: windowSize)
    }
    
    private func makeScaleToImagePlane(windowSize: SIMD2<Float>) -> matrix_float4x4 {
        let aspectRatio = windowSize.x / windowSize.y
        return simd_float4x4(scaleBy: SIMD3<Float>( aspectRatio * self.TanFOVYByTwo,
                                                    self.TanFOVYByTwo,
                                                    1))
    }


} // Class perspectiveCamera
