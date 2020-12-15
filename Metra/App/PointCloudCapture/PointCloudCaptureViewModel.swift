//
//  PointCloudCaptureViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 15/12/2020.
//

import Foundation
import Combine
import Metal
import MetalKit
import ARKit

final class PointCloudCaptureViewModel {
    private var cancellable: Set<AnyCancellable> = []
    private let rendererService = PointCloudCaptureRenderingService()
    var session: ARSession { rendererService.renderer.session }
    
    @Published
    private var rendererIsRunning: Bool = false
    @Published
    private (set) var rendererIsCapturing: Bool = false
    
    @Published 
    var pointCountMetric: String = "-"
    @Published
    var particleSizeMetric: String = "-"
    @Published
    var resetButtonIsEnabled: Bool = false
    @Published
    var viewCaptureButtonIsEnabled: Bool = false
    @Published
    var toggleCaptureButtonIsSelected: Bool = false
    
    let shouldShowUI: CurrentValueSubject<Bool, Never>
    
    // MARK: - Tweakable parameters
    @Published
    var confidenceThreshold: Int {
        didSet {
            rendererService.renderer.confidenceThreshold = confidenceThreshold
        }
    }
    @Published
    var maxPoints: Int {
        didSet {
            rendererService.renderer.maxPoints = maxPoints
        }
    }
    @Published
    var particleSize: Float {
        didSet {
            rendererService.renderer.particleSize = particleSize
        }
    }
    @Published
    var rgbRadius: Float {
        didSet {
            rendererService.renderer.rgbRadius = rgbRadius
        }
    }

    init() {
        shouldShowUI = CurrentValueSubject<Bool, Never>(false)
        
        confidenceThreshold = rendererService.renderer.confidenceThreshold
        maxPoints = rendererService.renderer.maxPoints
        particleSize = rendererService.renderer.particleSize
        rgbRadius = rendererService.renderer.rgbRadius
        
        $confidenceThreshold.assign(to: &rendererService.renderer.$confidenceThreshold)
        $maxPoints.assign(to: &rendererService.renderer.$maxPoints)
        $particleSize.assign(to: &rendererService.renderer.$particleSize)
        $rgbRadius.assign(to: &rendererService.renderer.$rgbRadius)
        
        rendererService.renderer.$currentPointCount
            .combineLatest(rendererService.renderer.$maxPoints)
            .throttle(for: 1, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { (args) in
                let (currentPointCount, maxPoints) = args
                self.pointCountMetric = "Points: \(currentPointCount / 1000)k / \(maxPoints / 1000)k"
            }
            .store(in: &cancellable)
        
        rendererService.renderer.$particleSize
            .throttle(for: 1, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { (particleSize) in
                self.particleSizeMetric = "Particle size: \(particleSize.rounded())"
            }
            .store(in: &cancellable)
        
        $rendererIsRunning.assign(to: &$resetButtonIsEnabled)
        $rendererIsRunning.assign(to: &$viewCaptureButtonIsEnabled)
        $rendererIsCapturing.map({ isRunning in !isRunning }).assign(to: &$toggleCaptureButtonIsSelected)
    }
    
    func loadMetalView(in view: UIView) {
        rendererService.embedMetalView(in: view)
    }
    
    // MARK: - Session control
    func startRenderer(overridingCurrentSession: Bool = false) {
        if overridingCurrentSession {
            rendererService.start()
        } else if !rendererIsRunning {
            rendererService.resume()
        } else {
            resumeCapture()
        }
        rendererIsRunning = true
    }
    
    func stopRenderer() {
        rendererIsRunning = false
        rendererIsCapturing = false
        rendererService.pause()
    }
    
    // MARK: - Capture control
    func resumeCapture() {
        rendererIsCapturing = true
        rendererService.resumeCapture()
    }
    
    func pauseCapture() {
        rendererIsCapturing = false
        rendererService.pauseCapture()
    }
    
    func generateScene() -> PassthroughSubject<SCNScene, Never> {
        rendererService.generateScene()
    }
}
