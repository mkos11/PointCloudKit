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
    
    // MARK: - Tweakable parameters
    let confidenceThreshold: CurrentValueSubject<Int, Never>
    let maxPoints: CurrentValueSubject<Int, Never>
    let particleSize: CurrentValueSubject<Float, Never>
    let rgbRadius: CurrentValueSubject<Float, Never>
    let shouldShowUI: CurrentValueSubject<Bool, Never>

    init() {
        confidenceThreshold = CurrentValueSubject<Int, Never>(rendererService.renderer.confidenceThreshold)
        maxPoints = CurrentValueSubject<Int, Never>(rendererService.renderer.maxPoints)
        particleSize = CurrentValueSubject<Float, Never>(rendererService.renderer.particleSize)
        rgbRadius = CurrentValueSubject<Float, Never>(rendererService.renderer.rgbRadius)
        shouldShowUI = CurrentValueSubject<Bool, Never>(false)
        
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
