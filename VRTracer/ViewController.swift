//
//  ViewController.swift
//  VRTracer
//
//

import Cocoa
import MetalKit
import ModelIO




class ViewController: NSViewController {

    var mtkView  : MTKView!
    var renderer : Renderer!
    
    var camera = FlyCamera()
    
    var keysPressed = [Bool](repeating: false, count: Int(UInt16.max))
    var previousMousePoint = NSPoint.zero
    var currentMousePoint = NSPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up View without Storyboard
        mtkView = MTKView()

        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        

        
        var selectedDevice: MTLDevice!
        let devices = MTLCopyAllDevices()
        for device in devices {
            if(device.supportsRaytracing){
                selectedDevice = device
            }
        }
        
//        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = selectedDevice!
        print("Selected device: \(selectedDevice!.name)")
        
        
        // Specifies the pixel format to use for the buffer that will be rendered to the screen
        // Currently, using .rgba32Float cannot be set in the contentViewController. TODO: has this change?
        mtkView.colorPixelFormat = .rgba16Float
        
        // Create scene
        let scene = Scene(device: selectedDevice)
        
        // Create camera for RT renderer
        let windowSize = SIMD2<Float>(Float(mtkView.bounds.width), Float(mtkView.bounds.height))
        let perspectiveCamera = PerspectiveCamera(cameraToWorld: self.camera.viewMatrix, windowSize: windowSize)
        
        // Create renderer with a cube scene
        renderer = Renderer(view: mtkView,
                            device: selectedDevice,
                            scene: scene.newInstancedCubeScene(device: selectedDevice, useIntersectionFunctions: true),
                            camera: perspectiveCamera)
        
        mtkView.delegate = renderer
        
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {timer in
            self.updateCamera()
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewDidAppear() {
        self.view.window?.makeFirstResponder(self)
        self.view.window?.title = "VRTracer"
    }
    
    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    func updateCamera() {
        
        let timeStep : Float = 1.0 / 60.0
        
        let cursorDeltaX = Float(currentMousePoint.x - previousMousePoint.x)
        let cursorDeltaY = -Float(currentMousePoint.y - previousMousePoint.y) // sign which flips Y-Axis
        
        let forwardPressed  = keysPressed[kVK_ANSI_W]
        let backwardPressed = keysPressed[kVK_ANSI_S]
        let leftPressed  = keysPressed[kVK_ANSI_A]
        let rightPressed  = keysPressed[kVK_ANSI_D]
        
        let resetPressed = keysPressed[kVK_Space]
        
        self.camera.resetState(resetPressed: resetPressed)
        
        self.camera.update(timeStep: timeStep,
                           cursorDelta: SIMD2<Float>(cursorDeltaX, cursorDeltaY),
                           forwardPressed: forwardPressed,
                           leftPressed: leftPressed,
                           backwardPressed: backwardPressed,
                           rightPressed: rightPressed)
        

        self.renderer.camera.cameraToWorld = self.camera.cameraToWorld
                
    }
    
    // Click down events
    override func mouseDown(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        currentMousePoint  = mouseLocation
        previousMousePoint = mouseLocation
        
        print(mouseLocation)
    }
    
    // Dragging
    override func mouseDragged(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        previousMousePoint = currentMousePoint
        currentMousePoint  = mouseLocation
        print("dragging")
    }
    
    // Release click event
    override func mouseUp(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        currentMousePoint  = mouseLocation
        previousMousePoint = mouseLocation
    }
    
    override func keyDown(with event: NSEvent) {
        print("key pressed : ", Int(event.keyCode))
        keysPressed[Int(event.keyCode)] = true
    }

    override func keyUp(with event: NSEvent) {
        keysPressed[Int(event.keyCode)] = false
        print("key released : ", Int(event.keyCode))
    }
    


}

