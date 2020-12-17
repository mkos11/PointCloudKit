/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The host app renderer.
*/

import Metal
import MetalKit
import ARKit
import Combine

struct Constants {}

extension Constants {
    struct Renderer {
        static let defaultConfidence = 1
        static let defaultNumGridPoints = 5000
        
        static let defaultMaxPoints = 3_000_000
        static let minMaxPoints = 50_000
        static let maxMaxPoints = 5_000_000
        
        static let defaultParticleSize: Float = 6.0
        static let minParticleSize: Float = 0.0
        static let maxParticleSize: Float = 10.0
        
        static let defaultRgbRadius: Float = 0.0
        static let minRgbRadius: Float = 0.0
        static let maxRgbRadius: Float = 1.5
    }
}

final class Renderer {
    var isAccumulating: Bool = true
    // Number of sample points on the grid
    private let numGridPoints = Constants.Renderer.defaultNumGridPoints
    // We only use portrait
    private let orientation = UIInterfaceOrientation.portrait
    // Camera's threshold values for detecting when the camera moves so that we can accumulate the points
    private let cameraRotationThreshold = cos(2 * .degreesToRadian)
    private let cameraTranslationThreshold: Float = pow(0.02, 2)   // (meter-squared)
    // The max number of command buffers in flight
    private let maxInFlightBuffers = 3

    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    
    /// The session captures video from the camera, tracks the device’s position and orientation
    /// in a modeled 3D space, and provides ARFrame objects.
    let session = ARSession()

    // Metal objects and textures
    private let device: MTLDevice
    private let library: MTLLibrary
    private let renderDestination: RenderDestinationProvider
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
    private lazy var rgbPipelineState = makeRGBPipelineState()!
    private lazy var particlePipelineState = makeParticlePipelineState()!
    // texture cache for captured image
    private lazy var textureCache = makeTextureCache()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private var depthTexture: CVMetalTexture?
    private var confidenceTexture: CVMetalTexture?

    // Multi-buffer rendering pipeline
    private let inFlightSemaphore: DispatchSemaphore
    private var currentBufferIndex = 0

    // The current viewport size
    private var viewportSize = CGSize()
    // The grid of sample points
    private lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                                            array: makeGridPoints(),
                                                            index: kGridPoints.rawValue, options: [])

    // RGB buffer
    private lazy var rgbUniforms: RGBUniforms = {
        var uniforms = RGBUniforms()
        uniforms.radius = rgbRadius
        uniforms.viewToCamera.copy(from: viewToCamera)
        uniforms.viewRatio = Float(viewportSize.height / viewportSize.width)
        return uniforms
    }()
    private var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
    // Point Cloud buffer
    private lazy var pointCloudUniforms: PointCloudUniforms = {
        var uniforms = PointCloudUniforms()
        uniforms.maxPoints = Int32(maxPoints)
        uniforms.confidenceThreshold = Int32(confidenceThreshold)
        uniforms.particleSize = particleSize
        uniforms.cameraResolution = cameraResolution
        return uniforms
    }()
    private var pointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()
    // Particles buffer
    private (set) var particlesBuffer: MetalBuffer<ParticleUniforms>
    private var currentPointIndex = 0
    @Published private (set) var currentPointCount = 0

    // Camera data
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height))
    private lazy var viewToCamera = sampleFrame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
    private lazy var lastCameraTransform = sampleFrame.camera.transform

    // interfaces
    @Published var confidenceThreshold = Constants.Renderer.defaultConfidence {
        didSet {
            // apply the change for the shader
            pointCloudUniforms.confidenceThreshold = Int32(confidenceThreshold)
        }
    }

    @Published var rgbRadius: Float = Float(Constants.Renderer.defaultRgbRadius) {
        didSet {
            // apply the change for the shader
            rgbUniforms.radius = rgbRadius
        }
    }
    
    // Maximum number of points we store in the point cloud
    @Published var maxPoints = Constants.Renderer.defaultMaxPoints {
        didSet {
            pointCloudUniforms.maxPoints = Int32(maxPoints)
        }
    }
    
    // Particle's size in pixels
    @Published var particleSize: Float = Float(Constants.Renderer.defaultParticleSize) {
        didSet {
            pointCloudUniforms.particleSize = particleSize
        }
    }

    init(metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.device = device
        self.renderDestination = renderDestination

        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!

        particlesBuffer = .init(device: device,
                                count: Constants.Renderer.maxMaxPoints,
                                index: kParticleUniforms.rawValue)

        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!

        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!

        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
        
        initializeBuffers()
    }

    func drawRectResized(size: CGSize) {
        viewportSize = size
    }

    /// Each `ARFrame` object’s `capturedImage` property contains a pixel buffer captured from the device camera.
    /// To draw this image as the backdrop for your custom view, you’ll need to create textures from the image
    /// content and submit GPU rendering commands that use those textures.
    ///
    /// The pixel buffer’s contents are encoded in a biplanar YCbCr (also called YUV) data format; to render the image you’ll need to convert this pixel data to a drawable RGB format. For rendering with Metal, you can perform this conversion most efficiently in GPU shader code. Use CVMetalTextureCache APIs to create two Metal textures from the pixel buffer—one each for the buffer’s luma (Y) and chroma (CbCr) planes:
    private func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return }

        capturedImageTextureY = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }

    /// This function update the DepthTexture and ConfidenceTexture, the dataset containing what is draw to represent texture and depth
    /// Seems this data is stored in the Frame, in sceneDepth.depthMap and confidenceMap
    private func updateDepthTextures(frame: ARFrame) -> Bool {
        guard let depthMap = frame.smoothedSceneDepth?.depthMap,
            let confidenceMap = frame.smoothedSceneDepth?.confidenceMap else {
                return false
        }

        depthTexture = makeTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
        confidenceTexture = makeTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)
        return true
    }

    private func update(frame: ARFrame) {
        // frame dependent info
        let camera = frame.camera
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
        pointCloudUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
        pointCloudUniforms.localToWorld = viewMatrixInversed * rotateToARCamera
        pointCloudUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
    }

    func draw() {
        guard let currentFrame = session.currentFrame,
            let renderDescriptor = renderDestination.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor) else {
                return
        }

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inFlightSemaphore.signal()
        }

        // update frame data
        update(frame: currentFrame)
        updateCapturedImageTextures(frame: currentFrame)

        // handle buffer rotating
        currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
        pointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms

        if shouldAccumulate(frame: currentFrame), updateDepthTextures(frame: currentFrame) {
            accumulatePoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        }

        // check and render rgb camera image using Luma and Chroma textures - if needed
        if rgbUniforms.radius > 0 {
            var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr]
            commandBuffer.addCompletedHandler { _ in
                retainingTextures.removeAll()
            }
            rgbUniformsBuffers[currentBufferIndex][0] = rgbUniforms

            renderEncoder.setDepthStencilState(relaxedStencilState)
            renderEncoder.setRenderPipelineState(rgbPipelineState)
            renderEncoder.setVertexBuffer(rgbUniformsBuffers[currentBufferIndex])
            renderEncoder.setFragmentBuffer(rgbUniformsBuffers[currentBufferIndex])
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        // render particles
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(particlePipelineState)
        renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentPointCount)
        renderEncoder.endEncoding() // Draws

        commandBuffer.present(renderDestination.currentDrawable!) // Present on screen
        commandBuffer.commit() // Finish operations and free retainedTextures
    }

    /// Decide wether new points should be added to the buffers:
    /// - `isAccumulating` is true (to pause/resume the capture)
    /// - If no point recorded yet (first frame of capture)
    /// - if camera moved (rotation/translation) beyond thresholds
    private func shouldAccumulate(frame: ARFrame) -> Bool {
        guard isAccumulating else { return false }
        let cameraTransform = frame.camera.transform
        return currentPointCount == 0
            || dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
            || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3) >= cameraTranslationThreshold
    }

    /// Add news points to Buffers
    private func accumulatePoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {
        pointCloudUniforms.pointCloudCurrentIndex = Int32(currentPointIndex)

        // Textures generated from the current frame previously in the update functions (Luma, Chroma, Depth and Confidence)
        var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture]
        commandBuffer.addCompletedHandler { _ in
            retainingTextures.removeAll()
        }

        renderEncoder.setDepthStencilState(relaxedStencilState)
        // This line inform which Metal func we will call
        renderEncoder.setRenderPipelineState(unprojectPipelineState)
        // This pass the arguments
        renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.setVertexBuffer(gridPointsBuffer)
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)

        currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % maxPoints
        currentPointCount = min(currentPointCount + gridPointsBuffer.count, maxPoints)
        lastCameraTransform = frame.camera.transform
    }
}

extension Renderer {
    func initializeBuffers() {
        for _ in 0 ..< maxInFlightBuffers {
            rgbUniformsBuffers.append(.init(device: device, count: 1, index: 0))
            pointCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
        }
        particlesBuffer.assign(with: Array(repeating: ParticleUniforms(), count: particlesBuffer.count))
        currentPointCount = 0
        currentPointIndex = 0
    }
    
    var currentlyVisibleVertices: [Vertex] {
        var vertices = [Vertex]()
        let confidenceRequierment = Float(confidenceThreshold) / 2.0
        for index in 0..<currentPointCount {
            guard particlesBuffer[index].confidence >= confidenceRequierment else { continue}
            vertices.append(particlesBuffer[index].vertex)
        }
        return vertices
    }
}

// MARK: - Metal Helpers

private extension Renderer {
    func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
        // Check that function in C shader code and make it possibly fail if something already at that position?
        guard let vertexFunction = library.makeFunction(name: "unprojectVertex") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func makeRGBPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "rgbVertex"),
            let fragmentFunction = library.makeFunction(name: "rgbFragment") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func makeParticlePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
            let fragmentFunction = library.makeFunction(name: "particleFragment") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    /// Makes sample points on camera image, also precompute the anchor point for animation
    func makeGridPoints() -> [Float2] {
        let gridArea = cameraResolution.x * cameraResolution.y
        let spacing = sqrt(gridArea / Float(numGridPoints))
        let deltaX = Int(round(cameraResolution.x / spacing))
        let deltaY = Int(round(cameraResolution.y / spacing))

        var points = [Float2]()
        for gridY in 0 ..< deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0 ..< deltaX {
                let cameraPoint = Float2(alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)

                points.append(cameraPoint)
            }
        }

        return points
    }

    func makeTextureCache() -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)

        return cache
    }

    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }

    static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
}

extension ParticleUniforms {
    fileprivate var vertex: Vertex {
        Vertex(x: position.x, y: position.y, z: position.z, r: color.x, g: color.y, b: color.z)
    }
}
