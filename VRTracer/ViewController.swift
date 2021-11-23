//
//  ViewController.swift
//  VRTracer
//
//  Created by Javier Cuesta on 22.11.21.
//

import Cocoa
import MetalKit
import ModelIO



class AppView : MTKView {
    
    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    override func keyDown(with event: NSEvent) {
        print("key pressed")
    }
    
    override func keyUp(with event: NSEvent) {
        print("key released")
    }
}

class ViewController: NSViewController {

//    var mtkView  : AppView!
    var mtkView  : MTKView!
    var renderer : Renderer!
    
    var keysPressed = [Bool](repeating: false, count: Int(UInt16.max))
    var previousMousePoint = NSPoint.zero
    var currentMousePoint = NSPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set View with storyboard
//        guard let mtkView = view as? AppView else {
//            fatalError("metal view not set up in storyboard")
//        }
        
        // Set up View witho Storyboard
//        mtkView = AppView()
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

