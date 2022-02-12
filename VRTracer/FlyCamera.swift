//
//  Transforms.swift
//  VRTracer
//
//

import Foundation
import simd

public final class FlyCamera {
    
    /// position of the camera in world coordinates
    private var eye  = SIMD3<Float>(0.0, 1.5, -2.72)
    /// where the camera is looking at, i.e. look = target - eye
    private var look = -SIMD3<Float>(0.0, 1.5, -2.72)
    private var up   = SIMD3<Float>(0.0, 1.0, 0)
    
    /// speed of camera translation
    let eyeSpeed: Float = 6.0
    /// speed of camera rotation
    let degreesPerCursorPoint: Float = 0.5
    /// minimum tolerance for maximal pitch angle
    let minTolerance : Float = cosf(toDegress(radians: 88))
    
    /// viewMatrix, i.e. world to camera transformation
    var viewMatrix : simd_float4x4 {
            return makeLookAtCameraTransform(position: eye, target: look + eye, up: up)
    }
    
    var cameraToWorld: simd_float4x4 {
        return makeCameraToWorld(position: eye, target: look + eye, up: up)
    }
    
    /// resets camera to initial pose
    func resetState(resetPressed: Bool){
        if resetPressed {
            eye  = SIMD3<Float>(0.0, 1.5, -2.72)
            look = -SIMD3<Float>(0.0, 1.5, -2.72)
            up = SIMD3<Float>(0.0, 1.0, 0)
        }
    }
    
    func update(timeStep: Float,
                cursorDelta: SIMD2<Float>,
                forwardPressed: Bool,
                leftPressed: Bool,
                backwardPressed: Bool,
                rightPressed: Bool){
        
        let rightDir = normalize(cross(look,up))
        let forward = normalize(look)


        // apply eye movement in the xz plane
        if ((rightPressed && !leftPressed) || (!rightPressed && leftPressed) ||
            (forwardPressed && !backwardPressed) || (!forwardPressed && backwardPressed)){
            let xMovement: Float = (leftPressed ? -1.0 : 0.0) + (rightPressed ? 1.0 : 0.0)
            let zMovement: Float = (backwardPressed ? -1.0 : 0.0) + (forwardPressed ? 1.0 : 0.0)
            
            let xzMovement = xMovement * rightDir + zMovement * forward
            
            // update camera position
            self.eye += self.eyeSpeed * timeStep * normalize(xzMovement)
        }
        
        // apply yaw rotation (rotating around y-axis so that the camera moves left or right)
        if cursorDelta.x != 0 {
            // rotation here is counter-clockwise because sin/cos are counter-clockwise
            let yaw = -cursorDelta.x * toRadians(degrees: degreesPerCursorPoint)
            let yawRotation = simd_float3x3(rotationAroundAxis: up, by: yaw)
            let newLook = yawRotation * look
            look = normalize(newLook)
            // note that we do not update the rightDir here
            // rightDir = normalize(cross(look,up))
        }
        // apply pitch rotation (rotating around x-axis so that camera moves up or down)
        if cursorDelta.y != 0 {
            let pitch = cursorDelta.y * toRadians(degrees: degreesPerCursorPoint)
            let pitchRotation = simd_float3x3(rotationAroundAxis: rightDir, by: pitch)
            let requestedLook = normalize(pitchRotation * look)
            
            let orthogonalRequestedLook = simd_float3x3(rotationAroundAxis: rightDir, by: 90) * requestedLook
            let tolerance : Float = dot(orthogonalRequestedLook, up)

            if (tolerance > 0.02){
                look = requestedLook
            }
        }
    }
} // class FlyCamera
