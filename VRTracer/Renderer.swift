//
//  Renderer.swift
//  VRTracer
//
//  Created by Javier Cuesta on 23.11.21.
//

import SwiftGeo

import Foundation
import MetalKit
import MetalPerformanceShaders

typealias Ray = MetalPerformanceShaders.MPSRayOriginMinDistanceDirectionMaxDistance
typealias Intersection = MetalPerformanceShaders.MPSIntersectionDistancePrimitiveIndexCoordinates

// The 256 byte aligned size of our uniform structure. In other words, the chosen stride of the Uniforms
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100
// Triple Buffering to avoid
let maxBuffersInFlight = 3

class Renderer : NSObject {
    
    let device               : MTLDevice
    var computePipelineState : MTLComputePipelineState!
    var blitPipelineState    : MTLRenderPipelineState!
    var commandQueue         : MTLCommandQueue!
    
    var outputImage          : MTLTexture?
    var outputImageSize      = MTLSize()
    
    var rayIntersector         : MPSRayIntersector!
    var rayGenerator           : MTLComputePipelineState!
    var accelerationStructure  : MPSTriangleAccelerationStructure!
    var intersectionHandler    : MTLComputePipelineState!
    
    var rayBuffer              : MTLBuffer!
    var intersectionBuffer     : MTLBuffer!
    
    var rayCount               = Int32(0)
    
    var dynamicUniformBuffer   : MTLBuffer
    ///index to keep track of the current buffer in use
    var uniformBufferIndex = 0
    /// Current offset of the triple buffer
    var uniformBufferOffset = 0
    /// Triple buffer of Uniforms
    var uniforms : UnsafeMutablePointer<Uniforms>
    
    public var viewMatrix : matrix_float4x4 = matrix_identity_float4x4
    var projectionMatrix  : matrix_float4x4 = matrix_identity_float4x4
    
    var rotationValue : Float = 0.0
    
    init(view: MTKView, device: MTLDevice){
        
        self.device = device
        print("Init metal device ", device.name)
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available as it was not possible to make a commandQueue")
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        // Set the Test Compute Pipeline
        guard let testComputeShader = library.makeFunction(name: "imageFillTest") else {
            fatalError("imageFillTest shader function not found")
        }
        do {
            computePipelineState = try device.makeComputePipelineState(function: testComputeShader)
        } catch let error {
            print(error.localizedDescription)
        }
        
        // set Blit render pipeline
        let blitPipelineDescritor                                       = MTLRenderPipelineDescriptor()
        blitPipelineDescritor.vertexFunction                            = library.makeFunction(name: "blitVertex")
        blitPipelineDescritor.fragmentFunction                          = library.makeFunction(name: "blitFragment")
        blitPipelineDescritor.colorAttachments[0].pixelFormat           = view.colorPixelFormat
        blitPipelineDescritor.depthAttachmentPixelFormat                = view.depthStencilPixelFormat
        
//        let vertexDescriptor = MTLVertexDescriptor()
//        vertexDescriptor.attributes[0].format = .float4
//        vertexDescriptor.attributes[0].bufferIndex = 0
//        vertexDescriptor.attributes[0].offset = 0
//        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride
//        
//        blitPipelineDescritor.vertexDescriptor = vertexDescriptor
        
        do {
            self.blitPipelineState = try device.makeRenderPipelineState(descriptor: blitPipelineDescritor)
        } catch let error {
            print(error.localizedDescription)
        }
        
        // Set the Ray Compute Pipeline
        guard let rayGeneratorShader = library.makeFunction(name: "generateRays") else {
            fatalError("generateRays shader function not found")
        }
        do {
            rayGenerator = try device.makeComputePipelineState(function: rayGeneratorShader)
        } catch let error {
            print(error.localizedDescription)
        }
        
        // Set Intersection Handler Pipeline
        guard let intersectionHandlerShader = library.makeFunction(name: "handleIntersections") else {
            fatalError("handleIntersections shader function not found")
        }
        do {
            intersectionHandler = try device.makeComputePipelineState(function: intersectionHandlerShader)
        } catch let error {
            print(error.localizedDescription)
        }
        
        // Initialize Uniforms
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        self.dynamicUniformBuffer = self.device.makeBuffer(length: uniformBufferSize,
                                                   options: [.storageModeShared])!
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to: Uniforms.self,
                                                                                            capacity: 1)
        
        
        super.init()
        

        
        // Initialize Ray Tracing
        self.initializeRayTracing()
        
        
//        // ---------- Sampler -----------------------------------------------
//        let samplerDescriptor = MTLSamplerDescriptor()
//        samplerDescriptor.normalizedCoordinates = false
//        samplerDescriptor.sAddressMode          = .clampToZero // width address mode
//        samplerDescriptor.tAddressMode          = .clampToZero    // height address mode
//        samplerDescriptor.minFilter             = .linear
//        samplerDescriptor.magFilter             = .nearest
//
//
//        let sampler = device.makeSamplerState(descriptor: samplerDescriptor)
//        // --------------------------------------------------------------
        
            }
    
    /// Updates the state of our uniform buffers before rendering
    private func updateDynamicBufferState() {
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to: Uniforms.self,
                                                                                                             capacity: 1)
    }
    
    
    func dispatchComputeShader(computePSO : MTLComputePipelineState, with commandBuffer: MTLCommandBuffer, setupBlock : (MTLComputeCommandEncoder)-> Void){
        
        guard let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("[dispatchComputeShader] Could not make a computeCommandEncoder")
        }
//        print("maxTotalThreadsPerThreadgroup = ", computePipelineState.maxTotalThreadsPerThreadgroup) // 1024
        
        // call the given set of methods on the command encoder
        setupBlock(computeCommandEncoder)
        
        // Common set of methods of the command encoder
        computeCommandEncoder.setComputePipelineState(computePSO)
        computeCommandEncoder.dispatchThreads(outputImageSize,
                                              threadsPerThreadgroup: MTLSize(width: 8,height: 8,depth: 1))
        computeCommandEncoder.endEncoding()
    }
    
    private func initializeRayTracing() {
       
//        let triangleVertices = [simd_float4(x: 0.25, y: 0.25, z: 0.0, w: 1), simd_float4(x: 0.75, y: 0.25, z: 0.0, w: 1), simd_float4(x: 0.5, y: 0.75, z: 0, w: 1)]
//
//        let vertexBuffer = device.makeBuffer(bytes: triangleVertices,
//                                             length: MemoryLayout<simd_float4>.stride * triangleVertices.count,
//                                             options: .storageModeManaged)
        
        // create cube scene. Initializes allCubeVertices
        createScene()
        
        let vertexBuffer = device.makeBuffer(bytes: allCubeVertices,
                                             length: MemoryLayout<simd_float4>.stride * allCubeVertices.count,
                                             options: .storageModeManaged)
        
        // Indices when the vertexBuffer is a unique set of vertices
//        let indices = allIndices
        
        // Indices when the vertices are repeated
        let indices = Array(UInt32(0)...UInt32(35))
        let indexBuffer = device.makeBuffer(bytes: indices,
                                            length: MemoryLayout<UInt32>.stride * indices.count,
                                            options: .storageModeManaged)
        
        accelerationStructure = MPSTriangleAccelerationStructure(device: device)
        accelerationStructure.vertexBuffer = vertexBuffer
        accelerationStructure.vertexStride = MemoryLayout<simd_float4>.stride
        accelerationStructure.indexBuffer = indexBuffer
        accelerationStructure.indexType   = .uInt32
        accelerationStructure.triangleCount = allCubeVertices.count / 3
        accelerationStructure.rebuild()
        

        
        rayIntersector = MPSRayIntersector.init(device: device)
        rayIntersector.rayDataType = .originMinDistanceDirectionMaxDistance
        rayIntersector.rayStride = MemoryLayout<Ray>.stride
        rayIntersector.intersectionDataType = .distancePrimitiveIndexCoordinates
        rayIntersector.intersectionStride   = MemoryLayout<Intersection>.stride
    }
    
    /// Creates a scene with a cube
    func createScene() {
        let transform = simd_float4x4(diagonal: simd_float4(1,1,1,1))
        createCube(color: simd_float3(x: 0.725, y: 0.71, z: 0.68), transform: transform)
    }
    
    /// updates camera parameters before rendering
    private func updateCameraState() {
        uniforms[0].projectionMatrix = projectionMatrix
        
        let rotationAxis = SIMD3<Float>(1,1,0)
        
        uniforms[0].modelViewMatrix = viewMatrix
        
    }
    
    
}


extension Renderer : MTKViewDelegate {
    
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        // Update output image size
        self.outputImageSize.width  = Int(size.width)
        self.outputImageSize.height = Int(size.height)
        self.outputImageSize.depth  = 1
        
        // reload texture if the size changes
        let outputImageDescriptor = MTLTextureDescriptor()
        outputImageDescriptor.pixelFormat = .rgba32Float
//        outputImageDescriptor.pixelFormat = .r32Float // one dimensional outcome for monochrone images
        outputImageDescriptor.width       = Int(size.width)
        outputImageDescriptor.height      = Int(size.height)
        outputImageDescriptor.usage       = [.shaderWrite, .shaderRead]
        outputImageDescriptor.storageMode = .private // Since we are going to use this texture only on GPU
        
        guard let outputImage = device.makeTexture(descriptor: outputImageDescriptor) else {
            fatalError("failed to make texture in mtkView")
        }
        self.outputImage = outputImage
        
        
        self.rayCount       = Int32(size.width) * Int32(size.height);
        rayBuffer           = device.makeBuffer(length: MemoryLayout<Ray>.size * Int(rayCount),
                                                options: .storageModePrivate)
        intersectionBuffer  = device.makeBuffer(length: MemoryLayout<Intersection>.size * Int(rayCount),
                                                options: .storageModePrivate)
        
        // Eventually update projectionMatrix, if we add an aspectRation parameter
        
    }
    
    func draw(in view: MTKView) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        self.updateDynamicBufferState()
        
        self.updateCameraState()
        
        /// Dispatch Test Encoder (Fill Image)
        self.dispatchComputeShader(computePSO: computePipelineState, with: commandBuffer, setupBlock: {commandEncoder in commandEncoder.setTexture(outputImage, index: 0)})
        
        /// Generate rays
        self.dispatchComputeShader(computePSO: rayGenerator, with: commandBuffer, setupBlock: {commandEncoder in commandEncoder.setBuffer(self.rayBuffer, offset: 0, index: 0) })
        
        /// Intersect rays with triangles inside acceleration structure
        rayIntersector.encodeIntersection(commandBuffer: commandBuffer,
                                          intersectionType: .nearest, // return the intersections that are closest to the camera
                                          rayBuffer: rayBuffer,
                                          rayBufferOffset: 0,
                                          intersectionBuffer: intersectionBuffer,
                                          intersectionBufferOffset: 0,
                                          rayCount: Int(rayCount),
                                          accelerationStructure: accelerationStructure)
        
        ///  Handle Intersections
        self.dispatchComputeShader(computePSO: intersectionHandler, with: commandBuffer, setupBlock: {commandEncoder in
            commandEncoder.setTexture(outputImage, index: 0)
            commandEncoder.setBuffer(self.intersectionBuffer, offset: 0, index: 0)
        })
        
        
        
        guard let blitEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!) else {
            return
        }
        
        // Output views parameters
        let viewport = view.bounds
        let width = Float(viewport.size.width)
        let height = Float(viewport.size.height)
        let aspectRatio = width / height
        
        print("view of size (\(width), \(height)) with aspect ratio \(aspectRatio)")
        
        // drawing goes here -----------------------------------------------------------------------------------------------
        
        // TODO: The dynamic buffer should be passed to rayIntersection encoder where the ray directions are defined.
        blitEncoder.setVertexBuffer(dynamicUniformBuffer,
                                      offset:uniformBufferOffset,
                                      index: BufferIndex.uniforms.rawValue)
        blitEncoder.setRenderPipelineState(blitPipelineState)
        blitEncoder.setFragmentTexture(outputImage, index: 0)
        blitEncoder.drawPrimitives(type: .triangle,
                                    vertexStart: 0,
                                    vertexCount: 3 ) // faceVertices.count / 3
        blitEncoder.endEncoding()
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        // End drawing ------------------------------------------------------------------------------------------------------
    }
    
}
