//
//  Transforms.swift
//  VRTracer
//
//

import Foundation
import simd

public final class FlyCamera {
    
    private var eye  = SIMD3<Float>(0.0, 1.5, -2.72)
    private var look = SIMD3<Float>(0.0, 0.0, 0.0)
    private var up   = SIMD3<Float>(0.0, 1.0, 0)
    
    // speed of camera translation
    let eyeSpeed: Float = 6.0
    // speed of camera rotation
    let degreesPerCursorPoint: Float = 1.0
    let maxPitchRotationDegrees : Float = 89.0
    
    // viewMatrix which is the in-out parameter of flythrough_camera_upate
    var viewMatrix : simd_float4x4 {
        get {
            return makeLookAtCameraTransform(position: eye, target: eye + look, up: up)
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
            // TODO: refactor this with simd_float3x3
            let yaw = -cursorDelta.x * radians_from_degrees(degreesPerCursorPoint)
            let yawRotation = simd_float4x4(rotationAroundAxis: up, by: yaw)
            let forward = yawRotation*SIMD4<Float>(look,1)
            look = normalize(SIMD3<Float>(forward.x, forward.y, forward.z))
        }
        // apply pitch rotation (rotating around x-axis so that camera moves up or down)
        if cursorDelta.y != 0 {
            // TODO: complete 
        }

        
    }
}
