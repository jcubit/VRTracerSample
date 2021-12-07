//
//  Transforms.swift
//  VRTracer
//
//  Created by Javier Cuesta on 30.11.21.
//

import Foundation
import simd


extension simd_float4x4 {
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
