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
    private var rendererService = PointCloudCaptureRenderingService()
    var session: ARSession { rendererService.renderer.session }

    @Published
    private var rendererIsRunning: Bool = false
    @Published
    private (set) var rendererIsCapturing: Bool = false

    @Published
    var currentPointCount: Int = 0
    
    @Published
    var samplePerFrameMetric: String = "-"
    @Published
    var currentPointMetric: String = "-"
    @Published
    var maxPointsMetric: String = "-"
    @Published
    var particleSizeMetric: String = "-"
    @Published
    var confidenceMetric: String = "-"
    @Published
    var statusMetric: String = "-"

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
    var numGridPoints: Int {
        didSet {
            rendererService.renderer.numGridPoints = numGridPoints
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
        numGridPoints = rendererService.renderer.numGridPoints
        maxPoints = rendererService.renderer.maxPoints
        particleSize = rendererService.renderer.particleSize
        rgbRadius = rendererService.renderer.rgbRadius

        $confidenceThreshold.assign(to: &rendererService.renderer.$confidenceThreshold)
        $numGridPoints.assign(to: &rendererService.renderer.$numGridPoints)
        $maxPoints.assign(to: &rendererService.renderer.$maxPoints)
        $particleSize.assign(to: &rendererService.renderer.$particleSize)
        $rgbRadius.assign(to: &rendererService.renderer.$rgbRadius)

        rendererService.renderer.$numGridPoints
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self]  (numGridPoints) in
                self?.samplePerFrameMetric = "\(numGridPoints) samples per frame"
            }
            .store(in: &cancellable)

        rendererService.renderer.$currentPointCount
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self] (currentPointCount) in
                self?.currentPointMetric = "Captured points: \(currentPointCount / 1000)k"
                self?.currentPointCount = currentPointCount
            }
            .store(in: &cancellable)

        rendererService.renderer.$maxPoints
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self] (maxPoints) in
                self?.maxPointsMetric = "Capture size: \(maxPoints / 1000)k"
            }
            .store(in: &cancellable)

        rendererService.renderer.$particleSize
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self]  (particleSize) in
                self?.particleSizeMetric = "Particle size: \(particleSize.rounded())"
            }
            .store(in: &cancellable)

        rendererService.renderer.$confidenceThreshold
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self] (confidence) in
                self?.confidenceMetric = "Confidence treshold: \(confidence)"
            }
            .store(in: &cancellable)

        $rendererIsCapturing
            .throttle(for: 0.33, scheduler: DispatchQueue.global(qos: .utility), latest: false)
            .sink { [weak self] (isCapturing) in
                self?.statusMetric = isCapturing ? "Capturing..." : "Capture Paused"
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
    
    var vertices: Future<[Vertex], Error> {
        Future<[Vertex], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ARError(.requestFailed)))
                return
            }
            DispatchQueue.global(qos: .background).async {
                promise(.success(self.rendererService.renderer.currentlyVisibleVertices))
            }
        }
    }
    
    var particlesBuffer: MTLBuffer {
//        / Either convert everything to CPU memory here - 0.5sec per 100k point in debug mod -- TO STUDY
//        / Other option is to pass an unsafe MTLBuffer and the count, and do some processing in the VTkLoader
//        print(Date().timeIntervalSince1970)
//        let test = rendererService.renderer.particlesBuffer.extractMembers(memberID: 0,
//                                                                           expectedType: ParticleUniforms.self,
//                                                                           upperBound: currentPointCount)
//        print(Date().timeIntervalSince1970)
//        print(test.count)
//        
//        var index = 0
//        while index < 10 {
//            print("Before cast point (%d) %f, %f, %f -- and confidence %f",
//                  index,
//                  test[index].position.x,
//                  test[index].position.y,
//                  test[index].position.z,
//                  test[index].confidence)
//            index += 1
//        }
    
    return rendererService.renderer.particlesBuffer.rawMtlBuffer
    }
}
