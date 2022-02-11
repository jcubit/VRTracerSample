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
    

}

func toRadians(degrees: Float) -> Float {
    return (degrees / Float(180.0)) * .pi
}


/// Gives a transformation from world to camera space. This function is particularly useful for placing a camera in the scene.
///
/// - Note: The camera space is assumed to be right-handed. The latter means that the camera is pointing in the -z direction w.r.t his
/// own coordinate system
///
/// - SeeAlso: `makeCameraToWorld`which computes manually the inverse of this transformation
///
/// - Parameters:
///   - position: the desired position of the camera in world coordinates
///   - target: the point the camera is looking at in world coordinates
///   - up: the "up" vector that orients the camera along the viewing direction implied by position and target. This vector is
///   recomputed to ensure that the final axes are perpendicular. This can be usually set to (0,1,0) and is given in world coordinates
/// - Returns: world to camera affine transformation
func makeLookAtCameraTransform(position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    // define where the camera is looking at
    let forward = normalize(target - position)
    let rightSide = normalize(cross(forward, normalize(up)))
    let newUp = normalize(cross(rightSide, forward))
    
    let translation = -SIMD3<Float>(dot(rightSide, position), dot(newUp, position), dot(-forward, position))
    let worldToCamera = matrix_float4x4(rows: [SIMD4<Float>(rightSide, translation.x),
                                               SIMD4<Float>(newUp, translation.y),
                                               SIMD4<Float>(-forward, translation.z),
                                               SIMD4<Float>(0,0,0, 1.0)])
    return worldToCamera
}

/// Gives a transformation from camera to world space.
///
/// - Note: The camera space is assumed to be right-handed. The latter means that the camera is pointing in the -z direction w.r.t his
/// own coordinate system
///
/// - SeeAlso `makeLookAtCameraTransform` which computes manually the inverse of this transformation for numerical precision
///
/// - Parameters:
///   - position: the desired position of the camera in world coordinates
///   - target: the point the camera is looking at in world coordinates
///   - up: the "up" vector that orients the camera along the viewing direction implied by position and target. This vector is
///   recomputed to ensure that the final axes are perpendicular. This can be usually set to (0,1,0) and is given in world coordinates
///   
/// - Returns: camera to world affine transformation
func makeCameraToWorld(position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    var cameraToWorld = matrix_identity_float4x4
    // define where the camera is looking at
    let forward = normalize(target - position)
    let rightSide = normalize(cross(forward, normalize(up)))
    let newUp = normalize(cross(rightSide, forward))
    
    cameraToWorld.columns.0 = SIMD4<Float>(rightSide, 0)
    cameraToWorld.columns.1 = SIMD4<Float>(newUp, 0)
    cameraToWorld.columns.2 = SIMD4<Float>(-forward, 0)
    cameraToWorld.columns.3 = SIMD4<Float>(position, 1)

    return cameraToWorld
}


/// Returns the scaled perspective transformation which converts points from camera to NDC space
///
///  - Note: This is an invertible transformation as long as `0 < zNear < zFar`.
///
/// This matrix transforms the viewing frustum (defined by the given near and far plane distances) into
/// the cube [-1,1]x[-1,1]x[0,1]
/// The camera is at z = 0 and the near plane is mapped there as well. The far plane is mapped to z = 1.
/// The field of view parameter given by the user is used to scaled the screen coordinates (x,y) to [-1, 1]
/// The camera is assume to have Right-handed orientation, so its pointing in the -z directions
///
/// - Parameters
///     - fovyInDegrees:  Y - field of view angle in degrees
///     - aspectRatio: the ratio of width and height of the image
///     - zNear: distance of near plane. It must be different from zero and less than `zFar`
///     - zFar distance of far plane
///
/// - Returns:`simd_float4x4`scaled perspective transformation
func PerspectiveTransformation(fovyInDegrees : Float, aspectRatio: Float, zNear : Float = 1e-2, zFar : Float = 1000) -> simd_float4x4 {
    assert(zNear != Float(0), "[Error] Cannot construct an invertible perspective transformation with zNear equal to zero")
    assert(zNear < zFar, "[Error] cannot construct perspective transformation with zNear bigger than zFar")
    
    // Constructed assuming Right-handed system with camera pointing in the -z direction
    let perspectiveMatrix = PerspectiveMatrix(zNear: zNear, zFar: zFar)

    let invTanAngY = 1.0 / tan(toRadians(degrees: fovyInDegrees) / 2.0);
    let invTanAngX = invTanAngY / aspectRatio;
    return simd_float4x4(diagonal: SIMD4<Float>(invTanAngX, invTanAngY, 1, 1)) * perspectiveMatrix;
}


/// returns the perspective matrix without X-Y scaling
///
/// - Note: This matrix is invertible as long as `0 < zNear < zFar`
/// - SeeAlso: `PerspectiveTransformation` and `InversePerspectiveMatrix`
///
/// The camera is assume to have Right-handed orientation, so its pointing in the -z directions
///
/// - Parameters
///     - zNear: distance of near plane
///     - zFar distance of far plane
///
/// - Returns:`simd_float4x4` perspective matrix
func PerspectiveMatrix(zNear : Float = 1e-2, zFar : Float = 1000) -> simd_float4x4 {
    assert(0<zNear && zNear < zFar, "[Error] zNear must be greater than zero and less than zFar")
    
    return simd_float4x4(rows: [SIMD4<Float>(1, 0,      0,                              0                 ),
                                SIMD4<Float>(0, 1,      0,                              0                 ),
                                SIMD4<Float>(0, 0, -zFar / (zFar - zNear), -(zFar * zNear) / (zFar - zNear)),
                                SIMD4<Float>(0, 0,      -1,                              0                 )])
}


/// computes the inverse of the perspective matrix (without X-Y scaling) manually for numerical precision
///
/// - SeeAlso: `PerspectiveTransformation` and `PerspectiveMatrix`
///
/// The camera is assume to have Right-handed orientation, so its pointing in the -z directions
///
/// - Parameters
///     - zNear: distance of near plane
///     - zFar distance of far plane
///
/// - Returns:`simd_float4x4` inverse of perspective matrix
func InversePerspectiveMatrix(zNear : Float = 1e-2, zFar : Float = 1000) -> simd_float4x4 {
    assert(0<zNear && zNear < zFar, "[Error] zNear must be greater than zero and less than zFar")
    
    return simd_float4x4(rows: [SIMD4<Float>(1, 0,      0,                       0             ),
                                SIMD4<Float>(0, 1,      0,                       0             ),
                                SIMD4<Float>(0, 0,      0,                      -1             ),
                                SIMD4<Float>(0, 0, 1 / zFar - 1 / zNear,      1 / zNear        )])
}
