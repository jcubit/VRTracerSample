#  VRTracer

## Things that differ from the Sample

- View creation in ViewController without storyboard and we do not call `renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.bounds.size)`
- The `func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)`in the Renderer Class. We just use one output texture.

- Semaphore is not fully implemented in VRTracer

- In `createAccelerationStructure` we need to set to one all the mask instances so they are visible: `instanceDescriptors[instanceIndex].mask = UInt32(1)`. We were obtaining no hits because the the mask was set to zero before.

# Constants

for a centered unit cube `[-0.5, 0.5]^3` and a camera with a FOV of 45 degrees, we need z to be at least -1.707 = 0.5 / tan(FOV/2).


