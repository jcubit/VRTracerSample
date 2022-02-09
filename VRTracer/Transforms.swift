//
//  Transforms.swift
//  VRTracer
//
//

import Foundation
import simd


extension simd_float4x4 {
    
    
    /// initializer of a rotation matrix
    /// - Parameters:
    ///   - axis: axis of rotation
    ///   - angle: angle of rotation in radians
    init(rotationAroundAxis axis: SIMD3<Float>, by angle: Float) {
        let unitAxis = normalize(axis)
        let ct = cosf(angle)
        let st = sinf(angle)
        let ci = 1 - ct
        let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
        self.init(columns:(SIMD4<Float>(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                           SIMD4<Float>(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                           SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                           SIMD4<Float>(                  0,                   0,                   0, 1)))
    }
    
    init(translationBy v: SIMD3<Float>) {
        self.init(columns:(SIMD4<Float>(1, 0, 0, 0),
                           SIMD4<Float>(0, 1, 0, 0),
                           SIMD4<Float>(0, 0, 1, 0),
                           SIMD4<Float>(v.x, v.y, v.z, 1)))
    }
    
    init(scaleBy s: SIMD3<Float>){
        self.init(columns: (SIMD4<Float>(s.x, 0, 0, 0),
                            SIMD4<Float>(0, s.y, 0, 0),
                            SIMD4<Float>(0, 0, s.z, 0),
                            SIMD4<Float>(0, 0, 0, 1)))
    }
    
    init(perspectiveProjectionRHFovY fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {
        let ys = 1 / tanf(fovy * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        self.init(columns:(SIMD4<Float>(xs,  0, 0,   0),
                           SIMD4<Float>( 0, ys, 0,   0),
                           SIMD4<Float>( 0,  0, zs, -1),
                           SIMD4<Float>( 0,  0, zs * nearZ, 0)))
    }
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}


/// Gives a transformation from world to camera space. This function is particularly useful for placing a camera in the scene.
/// The camera space is assumed to be right-handed. The latter means that the camera is pointing in the -z direction w.r.t his
/// own coordinate system
/// - Parameters:
///   - position: the desired position of the camera in world coordinates
///   - target: the point the camera is looking at in world coordinates
///   - up: the "up" vector that orients the camera along the viewing direction implied by position and target. This vector is
///   recomputed to ensure that the final axes are perpendicular. This can be usually set to (0,1,0) and is given in world coordinates
/// - Returns: world to camera affine transformation
func makeLookAtCameraTransform(position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    var cameraToWorld = matrix_identity_float4x4
    
    // define where the camera is looking at
    let forward = normalize(target - position)
    let rightSide = normalize(cross(forward, normalize(up)))
    let newUp = normalize(cross(rightSide, forward))
    
    cameraToWorld.columns.0 = SIMD4<Float>(rightSide, 0)
    cameraToWorld.columns.1 = SIMD4<Float>(newUp, 0)
    cameraToWorld.columns.2 = SIMD4<Float>(-forward, 0)
    cameraToWorld.columns.3 = SIMD4<Float>(position, 1)
    
    return cameraToWorld.inverse
}
