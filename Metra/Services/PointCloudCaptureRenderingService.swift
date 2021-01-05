//
//  PointCloudCaptureRenderingService.swift
//  Metra
//
//  Created by Alexandre Camilleri on 15/12/2020.
//

import Combine
import Metal
import MetalKit
import ARKit

final class PointCloudCaptureRenderingService: NSObject, MTKViewDelegate {
    private var cancellable: Set<AnyCancellable> = []
    private let device: MTLDevice
    let renderer: Renderer
    private let metalView = MTKView()
    
    // Create a world-tracking configuration, and
    // enable the scene depth frame-semantic.
    lazy private var configuration: ARConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth // .smoothedSceneDepth
        return configuration
    }()
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        metalView.device = device
        self.renderer = Renderer(metalDevice: device, renderDestination: metalView)
        self.device = device
        super.init()
        metalView.backgroundColor = UIColor.black
        // we need this to enable depth test
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.contentScaleFactor = 1
        metalView.delegate = self
    }
    
    func embedMetalView(in view: UIView) {
        view.addSubview(metalView)
        metalView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }
        renderer.drawRectResized(size: metalView.bounds.size)
    }
    
    // MARK: - Session
    
    func pause() {
        renderer.session.pause()
    }
    
    func resume() {
        renderer.session.run(configuration)
    }
    
    func start() {
        renderer.initializeBuffers()
        renderer.session.run(configuration, options: [.resetTracking, .resetSceneReconstruction,
                                                      .removeExistingAnchors, .stopTrackedRaycasts])
    }
    
    // MARK: - Capture
    
    func resumeCapture() {
        renderer.isAccumulating = true
    }
    
    func pauseCapture() {
        renderer.isAccumulating = false
    }
    
    // MARK: - SCNScene generation

    func vertices() -> [Vertex] {
        renderer.currentlyVisibleVertices
    }
}

// MARK: - MTKViewDelegate conformance
extension PointCloudCaptureRenderingService {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}
