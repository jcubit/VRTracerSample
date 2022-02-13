//
//  Renderer.swift
//  VRTracer
//
//

import Foundation
import MetalKit
import simd


// The 256 byte aligned size of our uniform structure. In other words,
// the chosen stride of the Uniforms. Use 16 bytes on iOS.
let alignedUniformsFlyCameraSize = (MemoryLayout<UniformsFlyCamera>.size + 0xFF) & -0x100
// Triple Buffering to avoid stalling
let maxBuffersInFlight = 3

class Renderer : NSObject {
    
    /// Metal Fundamentals
    let device                      : MTLDevice
    var commandQueue                : MTLCommandQueue!
    var library                     : MTLLibrary!
    
    /// Blit (Copy) Render Pipeline
    var blitPipelineState           : MTLRenderPipelineState!
    
    /// Ray Tracing Pipeline
    var rayTracingPipeline          : MTLComputePipelineState!
    
    /// Acceleration Structures
    var instanceAccelerationStructure   : MTLAccelerationStructure! // "instances = copies"
    var primitiveAccelerationStructures = [MTLAccelerationStructure]()
    
    /// Destination Image
    var outputImage          : MTLTexture?
    var outputImageSize      = MTLSize()
    
    /// Alternative to one destinationImage
    var accumulationTargets = [MTLTexture]()
    
    /// Functions used in Metal's Intersection stage
    var intersectionFunctionTable   : MTLIntersectionFunctionTable!
    
    var resourcesStride                 : UInt32!
    var useIntersectionFunctions        : Bool!
    
    /// Argument buffer that stores buffers, textures, samplers and inlined constant data
    var resourceBuffer          : MTLBuffer!
    var instanceBuffer          : MTLBuffer!
    
    /// Semaphore
    var dispatchSemaphore       : DispatchSemaphore!
    
    /// Dynamic uniform Buffer for static camera
    var dynamicUniformBuffer            : MTLBuffer!
    /// Dynamic uniform Buffer for fly camera
    var dynamicUniformBufferFlyCamera   : MTLBuffer!
    ///index to keep track of the current buffer in use
    var uniformBufferIndex = 0
    /// Current offset of the triple buffer
    var uniformBufferOffset = 0
    /// Current offset of the triple buffer for fly camera
    var uniformBufferOffsetFlyCamera = 0
    /// Frame Index
    var frameIndex = 0
    /// Triple buffer of Uniforms holding FlyCamera
    var uniformsFlycamera : UnsafeMutablePointer<UniformsFlyCamera>!
    
    var scene               : Scene
    
    /// Affine transformation from World to Camera coordinates
    public var camera : RTCamera
    
    
    init(view: MTKView, device: MTLDevice, scene: Scene, camera: RTCamera){

        self.device = device
        self.scene = scene
        self.camera = camera
        
        self.dispatchSemaphore = DispatchSemaphore(value: frameIndex)
        
        super.init()
        
        loadMetal()
        createBuffersFlyCamera()
        createAccelerationStructures()
        createPipelines()

        }
    
    /// Loads the CommandQueue and the Metal's library
    private func loadMetal() {
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available as it was not possible to make a commandQueue")
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        self.library = library
        
    }
    
    
    
    /// Create a compute pipeline state with an optional array of additional functions to link the compute
    /// function with. The App uses this to link the ray-tracing kernel with any intersection functions.
    ///
    /// The link functions are Metal's function pointers
    ///
    /// - Parameters:
    ///   - function: main compute function
    ///   - linkedFunctions: linked function objects to the compute pipeline
    private func newComputePipelineState(function: MTLFunction, linkedFunctions: [MTLFunction]) -> MTLComputePipelineState?
    {
        
        let mtlLinkedFunctions = MTLLinkedFunctions()
        if(!linkedFunctions.isEmpty){
            mtlLinkedFunctions.functions = linkedFunctions
        }
        
        let descriptor = MTLComputePipelineDescriptor()
        // Set the main compute function
        descriptor.computeFunction = function
        // Attach the linked functions object to the compute pipeline descriptor
        descriptor.linkedFunctions = mtlLinkedFunctions
        
        // Set this to true if you can guarantee that the compute function will
        // always be dispatched with a threadgroup size that is a multiple of the thread execution width
        descriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        
        do {
            let pipeline = try device.makeComputePipelineState(descriptor: descriptor,
                                                               options: .argumentInfo,
                                                               reflection: nil)
            return pipeline
        } catch let error {
            print("Failed to create \(function.name) pipeline state: \(error.localizedDescription)")
            return nil
        }
        
    }
    
    /// Loads a function from the metal library
    /// - Parameter name: name of the specialized function
    /// - Returns: MTLFunction?
    private func specializedFunction(withName name: String)-> MTLFunction?
    {
        let constants = MTLFunctionConstantValues()
        
        // The first constant is the stride between entries in the resource buffer. The sample
        // uses this to allow intersection functions to look up any resources they use.
        var resourcesStride = self.resourcesStride
        constants.setConstantValue(&resourcesStride, type: .uint, index: 0)
        
        // The second constant turns the use of intersection functions on and off.
        constants.setConstantValue(&self.useIntersectionFunctions, type: .bool, index: 1)
        
        // Finally, load the function from the Metal library.
        do {
            let function = try self.library.makeFunction(name: name, constantValues: constants)
            return function
        } catch let error {
            print("Failed to create function \(name) : \(error.localizedDescription)")
            return nil
        }
        
    }
    
    /// Sets the RT pipeline as well as the Blit-Rendering Pipeline
    private func createPipelines() {
        
        self.useIntersectionFunctions = false
        
        // Check if any scene geometry has an intersection function
        for geometry in self.scene.geometries {
            if geometry.intersectionFunctionName != nil {
                self.useIntersectionFunctions = true
                break
            }
        }
        
        // Maps intersection function names to actual MTLFunctions
        var intersectionFunctions = Dictionary<String, MTLFunction>()
        
        // First, load all the intersection functions since the App needs them to create the final
        // ray-tracing compute pipeline state.
        for geometry in self.scene.geometries {
            // Skip if the geometry doesn't have an intersection function or if the app already loaded it
            guard let functionName = geometry.intersectionFunctionName else {
                continue
            }
            if intersectionFunctions.keys.contains(functionName) {
                           continue
            }
                
            // Specialize function constants used by the intersection function.
            let intersectionFunction = self.specializedFunction(withName: functionName)
            
            // Add the function to the dictionary
            intersectionFunctions[functionName] = intersectionFunction
        }
        
        
        // Main RT Function
        guard let raytracingFunction = self.specializedFunction(withName: "raytracingKernelFlyCamera") else {
            fatalError("failed to load the main raytracing kernel")
        }
        
        self.rayTracingPipeline = newComputePipelineState(function: raytracingFunction,
                                                     linkedFunctions: Array<MTLFunction>(intersectionFunctions.values))
        
        // Create the intersection function table
        if useIntersectionFunctions {
            let intersectionFunctionTableDescriptor = MTLIntersectionFunctionTableDescriptor()
            
            intersectionFunctionTableDescriptor.functionCount = self.scene.geometries.count
            
            // Create a table large enough to hold all of the intersection functions. Metal
            // links intersection functions into the compute pipeline state, potentially with
            // a different address for each compute pipeline. Therefore, the intersection
            // function table is specific to the compute pipeline state that created it and you
            // can only use it with that pipeline.
            guard let intersectionFunctionTable = rayTracingPipeline.makeIntersectionFunctionTable(descriptor: intersectionFunctionTableDescriptor) else {
                fatalError("[Renderer.createPipelines] could not create MTLIntersectionFunctionTable")
            }
            
            // Bind the buffer used to pass resources to the intersection functions.
            intersectionFunctionTable.setBuffer(self.resourceBuffer, offset: 0, index: 0)
            
            // Map each piece of scene geometry to its intersection function.
            for (geometryIndex, geometry) in self.scene.geometries.enumerated() {
                guard let functionName = geometry.intersectionFunctionName else { continue }
                guard let intersectionFunction = intersectionFunctions[functionName] else {
                    continue
                }
                
                // Create a handle to the copy of the intersection function linked into the
                // ray-tracing compute pipeline state. Create a different handle for each pipeline
                // it is linked with.
                let handle = rayTracingPipeline.functionHandle(function: intersectionFunction)
                
                // Insert the handle into the intersection function table. This ultimately maps the
                // geometry's index to its intersection function.
                intersectionFunctionTable.setFunction(handle, index: geometryIndex)
            }
            
        }
        
        // Create a render pipeline state which copies the rendered scene into the MTKView
        let blitPipelineDescritor                                       = MTLRenderPipelineDescriptor()
        blitPipelineDescritor.vertexFunction                            = library.makeFunction(name: "copyVertex")
        blitPipelineDescritor.fragmentFunction                          = library.makeFunction(name: "copyFragment")
        blitPipelineDescritor.colorAttachments[0].pixelFormat           = .rgba16Float
        
        do {
            self.blitPipelineState = try device.makeRenderPipelineState(descriptor: blitPipelineDescritor)
        } catch let error {
            print("Failed to create the blit pipeline state: \(error.localizedDescription)")
        }
        
    }
    
    /// Create an argument encoder which encodes references to a set of resources into a buffer.
    private func newArgumentEncoderForResources(resources : [MTLResource]) -> MTLArgumentEncoder? {
        
        var arguments = [MTLArgumentDescriptor]()
        
        for resource in resources {
            let argumentDescriptor = MTLArgumentDescriptor()
            
            argumentDescriptor.index = arguments.count
            argumentDescriptor.access = .readOnly
            
            if resource.conforms(to: MTLBuffer.self) {
                argumentDescriptor.dataType = .pointer
            } else if resource.conforms(to: MTLTexture.self) {
                let texture = resource as! MTLTexture
                argumentDescriptor.dataType = .texture
                argumentDescriptor.textureType = texture.textureType
            }
            
            arguments.append(argumentDescriptor)
        }
        
        return device.makeArgumentEncoder(arguments: arguments)
    }
    
    
    /// Initializes the dynamic uniforms buffer
    private func createBuffersFlyCamera() {
        // The uniform buffer contains a few small values which change from frame to frame. The
        // sample can have up to 3 frames in flight at once, so allocate a range of the buffer
        // for each frame. The GPU reads from one chunk while the CPU writes to the next chunk.
        // Align the chunks to 256 bytes on macOS and 16 bytes on iOS.
        let uniformBufferSize = alignedUniformsFlyCameraSize * maxBuffersInFlight
        
        // For MacOs the storage option is Managed, while in iOS Shared
        let storageOption = MTLResourceOptions.storageModeManaged
        
        self.dynamicUniformBufferFlyCamera = self.device.makeBuffer(length: uniformBufferSize,
                                                           options: [storageOption])!
        self.dynamicUniformBufferFlyCamera.label = "UniformFlyCameraBuffer"
        
        // Upload scene data to buffers.
        self.scene.uploadToBuffers()
        
        self.resourcesStride = 0
        
        // Each intersection function has its own set of resources. Determine the maximum size over all
        // intersection functions. This will become the stride used by intersection functions to find
        // the starting address for their resources.
        for geometry in scene.geometries {
            guard let encoder = newArgumentEncoderForResources(resources: geometry.resources()) else {
                fatalError("[Renderer.createBuffers] newArgumentEncoderForResources returned nil")
            }
            
            if encoder.encodedLength > self.resourcesStride {
                self.resourcesStride = UInt32(encoder.encodedLength)
            }
                
        }
        
        // Create the resource buffer.
        self.resourceBuffer = device.makeBuffer(length: Int(resourcesStride) * scene.geometries.count,
                                                options: storageOption)
        
        for (geometryIndex, geometry) in scene.geometries.enumerated() {
            
            // Create an argument encoder for this geometry's intersection function's resources
            guard let encoder = newArgumentEncoderForResources(resources: geometry.resources()) else {
                fatalError("[createBuffers] could not create newArgumentEncoderForResources")
            }
            
            // Bind the argument encoder to the resource buffer at this geometry's offset.
            encoder.setArgumentBuffer(self.resourceBuffer,
                                      offset: Int(self.resourcesStride) * geometryIndex)

            // Encode the arguments into the resource buffer.
            for (argumentIndex, resource) in geometry.resources().enumerated() {
                if(resource.conforms(to: MTLBuffer.self)){
                    encoder.setBuffer(resource as? MTLBuffer,
                                      offset: 0,
                                      index: argumentIndex)
                } else if resource.conforms(to: MTLTexture.self) {
                    encoder.setTexture(resource as? MTLTexture, index: argumentIndex)
                }
            }
        }
        
        resourceBuffer.didModifyRange(0..<resourceBuffer.length)
    }
    
    /// Create and compact an acceleration structure, given an acceleration structure descriptor.
    /// - Parameter descriptor: MTLAccelerationStructureDescriptor
    /// - Returns: MTLAccelerationStructure
    private func newAccelerationStructure(descriptor : MTLAccelerationStructureDescriptor) -> MTLAccelerationStructure?
    {
        // Query for the sizes needed to store and build the acceleration structure.
        let accelSizes = self.device.accelerationStructureSizes(descriptor: descriptor)
        
        // Allocate an acceleration structure large enough for this descriptor. This doesn't actually
        // build the acceleration structure, just allocates memory.
        guard let accelerationStructure = self.device.makeAccelerationStructure(size: accelSizes.accelerationStructureSize) else {
            print("[newAccelerationStructure] device could not make (allocate) a AccelerationStructure")
            return nil
        }
        
        // Allocate scratch space used by Metal to build the acceleration structure.
        // Use MTLResourceStorageModePrivate for best performance since the App
        // doesn't need access to buffer's contents.
        guard let scratchBuffer = self.device.makeBuffer(length: accelSizes.buildScratchBufferSize,
                                                         options: .storageModePrivate) else {
            print("[newAccelerationStructure] could not make a buffer")
            return nil
        }
        
        // Create a command buffer which will perform the acceleration structure build
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("[newAccelerationStructure] could not make a command buffer")
            return nil
        }
        
        // Create an acceleration structure command encoder.
        guard let commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
            print("[newAccelerationStructure] could not make a command encoder")
            return nil
        }

        // Allocate a buffer for Metal to write the compacted accelerated structure's size into.
        guard let compactedSizeBuffer = self.device.makeBuffer(length: MemoryLayout<UInt32>.size,
                                                               options: .storageModeShared) else {
            print("[newAccelerationStructure] device could not make a buffer")
            return nil
        }
        
        // Schedule the actual acceleration structure build
        commandEncoder.build(accelerationStructure: accelerationStructure,
                              descriptor: descriptor,
                              scratchBuffer: scratchBuffer,
                              scratchBufferOffset: 0)
        
        // Compute and write the compacted acceleration structure size into the buffer. You
        // must already have a built accelerated structure because Metal determines the compacted
        // size based on the final size of the acceleration structure. Compacting an acceleration
        // structure can potentially reclaim significant amounts of memory since Metal must
        // create the initial structure using a conservative approach.
        commandEncoder.writeCompactedSize(accelerationStructure: accelerationStructure,
                                           buffer: compactedSizeBuffer,
                                           offset: 0)
        
        // End encoding and commit the command buffer so the GPU can start building the
        // acceleration structure.
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return accelerationStructure
        
//  ---------- [Optimization] Compacting Accelerating Structures when the Accelerating structures are large
//
//        // The sample waits for Metal to finish executing the command buffer so that it can
//        // read back the compacted size.
//
//        // Note: Don't wait for Metal to finish executing the command buffer if you aren't compacting
//        // the acceleration structure, as doing so requires CPU/GPU synchronization. You don't have
//        // to compact acceleration structures, but you should when creating large static acceleration
//        // structures, such as static scene geometry. Avoid compacting acceleration structures that
//        // you rebuild every frame, as the synchronization cost may be significant.
//        commandBuffer.waitUntilCompleted()
//
//        let compactedSize = compactedSizeBuffer.contents().load(as: UInt32.self)
////        uint32_t compactedSize = *(uint32_t *)compactedSizeBuffer.contents;
//
//        // Allocate a smaller acceleration structure based on the returned size.
//        let compactedAccelerationStructure = self.device.makeAccelerationStructure(size: Int(compactedSize))
//
//        // Create another command buffer and encoder.
//        commandBuffer = commandQueue.makeCommandBuffer()!
//
//        commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder()!
//
//        // Encode the command to copy and compact the acceleration structure into the
//        // smaller acceleration structure.
//        commandEncoder.copyAndCompact(sourceAccelerationStructure: accelerationStructure,
//                                      destinationAccelerationStructure: compactedAccelerationStructure!)
//
//        // End encoding and commit the command buffer. You don't need to wait for Metal to finish
//        // executing this command buffer as long as you synchronize any ray-intersection work
//        // to run after this command buffer completes. The App relies on Metal's default
//        // dependency tracking on resources to automatically synchronize access to the new
//        // compacted acceleration structure.
//        commandEncoder.endEncoding()
//        commandBuffer.commit()
//
//        return compactedAccelerationStructure
    } 
    
    /// Create acceleration structures for the scene. The scene contains primitive acceleration
    /// structures and an instance acceleration structure. The primitive acceleration structures
    /// contain primitives such as triangles and spheres. The instance acceleration structure contains
    /// copies or "instances" of the primitive acceleration structures, each with their own
    /// transformation matrix describing where to place them in the scene.
    private func createAccelerationStructures()
    {
        // For MacOs the storage option is Managed, while in iOS Shared
        let storageOption = MTLResourceOptions.storageModeManaged
        
        // Create a primitive acceleration structure for each piece of geometry in the scene.
        for (geometryIndex, geometry) in self.scene.geometries.enumerated() {
            guard let geometryDescriptor = geometry.geometryDescriptor() else {
                print("[createAccelerationStructures] Warning: there is no geometry descriptor")
                continue
            }
            
            // Assign each piece of geometry a consecutive slot in the intersection function table.
            geometryDescriptor.intersectionFunctionTableOffset = geometryIndex

            // Create a primitive acceleration structure descriptor to contain the single piece
            // of acceleration structure geometry.
            let accelerationDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
            accelerationDescriptor.geometryDescriptors = [geometryDescriptor]
            
            // Build the acceleration structure.
            guard let accelerationStructure = self.newAccelerationStructure(descriptor: accelerationDescriptor) else {
                fatalError("[createAccelerationStructures] could not create acceleration structure for geometry")
            }
            
            // Add the acceleration structure to the array of primitive acceleration structures.
            self.primitiveAccelerationStructures.append(accelerationStructure)
        }
        
        // Allocate a buffer of acceleration structure instance descriptors. Each descriptor represents
        // an instance of one of the primitive acceleration structures created above, with its own
        // transformation matrix.
        self.instanceBuffer = self.device.makeBuffer(length: MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride * scene.instances.count,
                                                     options: storageOption)
        
        let instanceDescriptors = self.instanceBuffer.contents().assumingMemoryBound(to: MTLAccelerationStructureInstanceDescriptor.self)
        
        // Fill out instance descriptors.
        for (instanceIndex, instance) in self.scene.instances.enumerated(){
            guard let geometryIndex = self.scene.geometries.firstIndex(where: {element in element == instance.geometry}) else {
                print("[createAccelerationStructures] Warning: the geometry of the instance could not be found")
                continue
            }
            
            // Map the instance to its acceleration structure.
            instanceDescriptors[instanceIndex].accelerationStructureIndex = UInt32(geometryIndex)
            
            // Mark the instance as opaque if it doesn't have an intersection function so that the
            // ray intersector doesn't attempt to execute a function that doesn't exist.
            instanceDescriptors[instanceIndex].options = instance.geometry.intersectionFunctionName != nil ? MTLAccelerationStructureInstanceOptions.opaque : .nonOpaque
            
            // Metal adds the geometry intersection function table offset and instance intersection
            // function table offset together to determine which intersection function to execute.
            // The App mapped geometries directly to their intersection functions above, so it
            // sets the instance's table offset to 0.
            instanceDescriptors[instanceIndex].intersectionFunctionTableOffset = 0;

            // Set the instance mask, which the sample uses to filter out intersections between rays
            // and geometry. For example, it uses masks to prevent light sources from being visible
            // to secondary rays, which would result in their contribution being double-counted.
            instanceDescriptors[instanceIndex].mask = UInt32(1) // zero masks the object out


            // Copy the first three rows of the instance transformation matrix. Metal assumes that
            // the bottom row is (0, 0, 0, 1).
            // This allows instance descriptors to be tightly packed in memory.
            let col0 = MTLPackedFloat3Make(instance.transform.columns.0.x, instance.transform.columns.0.y, instance.transform.columns.0.z)
            let col1 = MTLPackedFloat3Make(instance.transform.columns.1.x, instance.transform.columns.1.y, instance.transform.columns.1.z)
            let col2 = MTLPackedFloat3Make(instance.transform.columns.2.x, instance.transform.columns.2.y, instance.transform.columns.2.z)
            let col3 = MTLPackedFloat3Make(instance.transform.columns.3.x, instance.transform.columns.3.y, instance.transform.columns.3.z)
            instanceDescriptors[instanceIndex].transformationMatrix.columns = (col0,col1,col2,col3)
        }
        
        self.instanceBuffer.didModifyRange(0..<self.instanceBuffer.length)
        
        // Create an instance acceleration structure descriptor.
        let accelDescriptor = MTLInstanceAccelerationStructureDescriptor()

        accelDescriptor.instancedAccelerationStructures = self.primitiveAccelerationStructures;
        accelDescriptor.instanceCount = self.scene.instances.count;
        accelDescriptor.instanceDescriptorBuffer = self.instanceBuffer;

        // Finally, create the instance acceleration structure containing all of the instances
        // in the scene.
        guard let instanceAccelerationStructure = newAccelerationStructure(descriptor: accelDescriptor) else {
            fatalError("[createAccelerationStructure] could not create acceleration structure")
        }
        self.instanceAccelerationStructure = instanceAccelerationStructure
    }
    
    
    
    /// updates camera parameters before rendering.
    /// windowSize will update the other parameters of the perspective camera
    private func updateCameraState(windowSize: SIMD2<Float>) {
        if let perspectiveCamera = camera as? PerspectiveCamera {
            perspectiveCamera.windowSize = windowSize
        }
    }
    
    
    /// updates flythrough camera parameters and the triple dynamic buffer
    private func updateUniformsWithFlyCamera(){
        self.uniformBufferOffsetFlyCamera = alignedUniformsFlyCameraSize * uniformBufferIndex
        
        uniformsFlycamera = UnsafeMutableRawPointer(dynamicUniformBufferFlyCamera.contents() + uniformBufferOffsetFlyCamera).bindMemory(to: UniformsFlyCamera.self,
                                                                                                                                        capacity: 1)

        uniformsFlycamera.pointee.camera.cameraToWorld = self.camera.cameraToWorld
        uniformsFlycamera.pointee.camera.viewportToCamera = self.camera.viewportToCamera
        
        uniformsFlycamera.pointee.width = UInt32(self.outputImageSize.width)
        uniformsFlycamera.pointee.height = UInt32(self.outputImageSize.height)
        
        uniformsFlycamera.pointee.frameIndex = UInt32(frameIndex)
        frameIndex += 1
        
        dynamicUniformBufferFlyCamera.didModifyRange(uniformBufferOffsetFlyCamera..<(uniformBufferOffsetFlyCamera + alignedUniformsFlyCameraSize))
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
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
        outputImageDescriptor.textureType = .type2D
        outputImageDescriptor.width       = Int(size.width)
        outputImageDescriptor.height      = Int(size.height)
        outputImageDescriptor.usage       = [.shaderWrite, .shaderRead]
        
        // Stored in private memory because only the GPU will read or write this texture.
        outputImageDescriptor.storageMode = .private

        guard let outputImage = device.makeTexture(descriptor: outputImageDescriptor) else {
            fatalError("[Renderer.mtkView] failed to make texture")
        }
        self.outputImage = outputImage
        
        // Add accumulatorTargets
        for _ in 0..<2 {
            guard let accumulatorTarget = device.makeTexture(descriptor: outputImageDescriptor) else {
                fatalError("[Renderer.mtkView] failed to make texture")
            }
            self.accumulationTargets.append(accumulatorTarget)
        }
        
        self.frameIndex = 0
        
        // Eventually update perspective camera parameters
        if let perspectiveCamera = camera as? PerspectiveCamera {
            perspectiveCamera.windowSize = SIMD2<Float>(Float(size.width), Float(size.height))
        }
        
    }
    
    func draw(in view: MTKView) {
        
        // TODO: Upate this with new raytracingPipeline with two accumulation targets
        
        // TODO: Search if there is a modern alternative to dispatch_semaphore_wait approach
        // The App uses the uniform buffer to stream uniform data to the GPU, so it
        // needs to wait until the GPU finishes processing the oldest GPU frame before
        // it can reuse that space in the buffer.
//        dispatchSemaphore.wait(timeout: .distantFuture)

        
        // Create a command for the frame's commands.
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        let sem = dispatchSemaphore!
        // When the GPU finishes processing command buffer for the frame, signal the
        // semaphore to make the space in uniform available for future frames.

        // Note: Completion handlers should be as fast as possible as the GPU driver may
        // have other work scheduled on the underlying dispatch queue.
        commandBuffer.addCompletedHandler {cb in
            sem.signal()
        }

        
        let windowSize = SIMD2<Float>(Float(self.outputImageSize.width), Float(self.outputImageSize.height))
        updateCameraState(windowSize: windowSize)
        self.updateUniformsWithFlyCamera()
        
        // Launch a rectangular grid of threads on the GPU to perform ray tracing, with one thread per
        // pixel. The App needs to align the number of threads to a multiple of the threadgroup
        // size, because earlier, when it created the pipeline objects, it declared that the pipeline
        // would always use a threadgroup size that's a multiple of the thread execution width
        // (SIMD group size). An 8x8 threadgroup is a safe threadgroup size and small enough to be
        // supported on most devices. A more advanced app would choose the threadgroup size dynamically.
        let threadsPerThreadgroup = MTLSizeMake(8, 8, 1)
        let threadsgroups = MTLSizeMake((self.outputImageSize.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                                        (self.outputImageSize.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                                        1)
        
        
        // Create a compute encoder to encode GPU commands.
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("[draw] It could not create a commandEncoder")
        }
        
        // Bind buffers
        computeEncoder.setBuffer(self.dynamicUniformBufferFlyCamera, offset: self.uniformBufferOffsetFlyCamera, index: 0)
        computeEncoder.setBuffer(self.resourceBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(self.instanceBuffer, offset: 0, index: 2)
        
        // Bind acceleration structure and intersection function table. These bind to normal buffer binding slots.
        computeEncoder.setAccelerationStructure(instanceAccelerationStructure, bufferIndex: 3)
        computeEncoder.setIntersectionFunctionTable(intersectionFunctionTable, bufferIndex: 4)
        
        // Bind textures. The ray tracing kernel reads from _accumulationTargets[0], averages the
        // result with this frame's samples, and writes to _accumulationTargets[1].
        computeEncoder.setTexture(outputImage, index: 0)
//        [computeEncoder setTexture:_accumulationTargets[0] atIndex:1];
//        [computeEncoder setTexture:_accumulationTargets[1] atIndex:2];
        
        // Mark any resources used by intersection functions as "used". The App does this because
        // it only references these resources indirectly via the resource buffer. Metal makes all the
        // marked resources resident in memory before the intersection functions execute.
        // Normally, the App would also mark the resource buffer itself since the
        // intersection table references it indirectly. However, the App also binds the resource
        // buffer directly, so it doesn't need to mark it explicitly.
        for geometry in scene.geometries {
            for resource in geometry.resources() {
                computeEncoder.useResource(resource, usage: .read)
            }
        }
        
        // Also mark primitive acceleration structures as used since only the instance acceleration
        // structure references them.
        for primitiveAccelerationStructure in self.primitiveAccelerationStructures {
            computeEncoder.useResource(primitiveAccelerationStructure, usage: .read)
        }
        
        // Bind the compute pipeline state.
        computeEncoder.setComputePipelineState(self.rayTracingPipeline)

        // Dispatch the compute kernel to perform ray tracing.
        computeEncoder.dispatchThreadgroups(threadsgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        
        // Swap the source and destination accumulation targets for the next frame.
//        std::swap(_accumulationTargets[0], _accumulationTargets[1]);
        
        if let currentView = view.currentDrawable {
            // Copy the resulting image into the view using the graphics pipeline since the App
            // can't write directly to it using the compute kernel. The App delays getting the
            // current render pass descriptor as long as possible to avoid a lenghty stall waiting
            // for the GPU/compositor to release a drawable. The drawable may be nil if
            // the window moved off screen.
            let renderPassDescriptor = MTLRenderPassDescriptor()
            
            renderPassDescriptor.colorAttachments[0].texture = currentView.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

            // Create a render command encoder.
            guard let blitEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            blitEncoder.setRenderPipelineState(blitPipelineState)
            blitEncoder.setFragmentTexture(outputImage, index: 0)
            
            // Draw a quad which fills the screen.
            blitEncoder.drawPrimitives(type: .triangle,
                                        vertexStart: 0,
                                        vertexCount: 6 ) // 6 vertices if we use a quad
            blitEncoder.endEncoding()
            
            commandBuffer.present(currentView)
            commandBuffer.commit()
            // End drawing ------------------------------------------------------------------------------------------------------
            
            
        }
        

    }
    
}

