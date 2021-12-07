#  VRTracer

## Things that differ from the Sample

- View creation in ViewController without storyboard and we do not call `renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.bounds.size)`
- The `func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)`in the Renderer Class. We just use one output texture.

- Semaphore is not fully implemented in VRTracer
