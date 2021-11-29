//
//  ViewController.swift
//  VRTracer
//
//  Created by Javier Cuesta on 22.11.21.
//

import Cocoa
import MetalKit
import ModelIO




class ViewController: NSViewController {

    var mtkView  : MTKView!
    var renderer : Renderer!
    
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


        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        
        // Specifies the pixel format to use for the buffer that will be rendered to the screen
        // using .rgba32Float cannot be set in the contentViewController. TODO: Investigate why
        mtkView.colorPixelFormat = .rgba16Float
        
        renderer = Renderer(view: mtkView, device: device)
        
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
        
        var eye  : [Float] = [0, 0, 8]
        var look : [Float] = [0, 0, -1]
        var up   : [Float] = [0, 1, 0]
        
        var view = [Float](repeating: 0.0, count: 16)
        
        let timeStep : Float = 1.0 / 60.0
        
        // speed of translation
        let eyeSpeed: Float = 6.0
        // speed of rotation
        let degreesPerCursorPoint: Float = 1.0
        let maxPitchRotationDegrees : Float = 89.0
        
        let cursorDeltaX = Int32(currentMousePoint.x - previousMousePoint.x)
        let cursorDeltaY = -Int32(currentMousePoint.y - previousMousePoint.y)
        
        let forwardPressed  = keysPressed[kVK_ANSI_W]
        let backwardPressed = keysPressed[kVK_ANSI_S]
        let leftPressed  = keysPressed[kVK_ANSI_A]
        let rightPressed  = keysPressed[kVK_ANSI_D]
        let jumpPressed : Int32 = 0
        let crouchPressed : Int32 = 0
        let flags : UInt32 = 0
        
        
        flythrough_camera_update(&eye,
                                 &look,
                                 &up,
                                 &view,
                                 timeStep,
                                 eyeSpeed,
                                 degreesPerCursorPoint,
                                 maxPitchRotationDegrees,
                                 cursorDeltaX,
                                 cursorDeltaY,
                                 forwardPressed ? 1 : 0,
                                 leftPressed ? 1 : 0,
                                 backwardPressed ? 1 : 0,
                                 rightPressed ? 1 : 0,
                                 jumpPressed, crouchPressed, flags)
        
        let viewMatrix = matrix_float4x4(columns: (SIMD4<Float>(view[0], view[1], view[2], view[3]),
                                                   SIMD4<Float>(view[4], view[5], view[6], view[7]),
                                                   SIMD4<Float>(view[8], view[9], view[10], view[11]),
                                                   SIMD4<Float>(view[12], view[13], view[14], view[15])))
        
        self.renderer.viewMatrix = viewMatrix
        
        
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

