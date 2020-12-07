//
//  ViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 7/12/2020.
//

import UIKit
import Metal
import MetalKit
import ARKit

import SnapKit
import Combine

final class PointCloudCaptureViewController: UIViewController, ARSessionDelegate {
    private var cancellable: Set<AnyCancellable> = []
    
    private let isUIEnabled = true
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let maxPointsSlider = UISlider()
    private let particleSizeSlider = UISlider()
    private let rgbRadiusSlider = UISlider()
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session.delegate = self
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        
        // Run the view's session
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    @objc
    private func viewValueChanged(view: UIView) {
        switch view {
        case confidenceControl:
            renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex
        case maxPointsSlider:
            renderer.maxPoints = Int(maxPointsSlider.value)
        case particleSizeSlider:
            renderer.particleSize = particleSizeSlider.value
        case rgbRadiusSlider:
            renderer.rgbRadius = rgbRadiusSlider.value
        default:
            break
        }
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - UI Setup

extension PointCloudCaptureViewController {
    private func setupUI() {
        setupMetalRenderer()
        setupMetricsOverlay()
        setupControlsOverlay()
    }
    
    private func setupMetalRenderer() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        // Set the view to use the default device
        if let view = view as? MTKView {
            view.device = device
            
            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: device, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
        }
    }
    
    /// Configure the Metrics overlay
    private func setupMetricsOverlay() {
        let stackView = UIStackView()
        let backgroundView = UIView()
        
        generateMetricsUIElements()
            .forEach { (metricUIElement) in
                stackView.addArrangedSubview(metricUIElement)
            }
        
        stackView.isHidden = !isUIEnabled
        stackView.axis = .vertical
        stackView.spacing = 5
        
        backgroundView.addBlurEffectView()
        backgroundView.layer.cornerRadius = 10
        backgroundView.clipsToBounds = true
        
        backgroundView.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(10)
        }
        
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { (make) -> Void in
            make.width.equalToSuperview().multipliedBy(0.35)
            make.height.equalToSuperview().multipliedBy(0.1)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.right).offset(-10)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(10)
         }
    }
    
    private func generateMetricsUIElements() -> [UILabel] {
        // Current points count over max points
        let pointsLabel = UILabel()
        
        pointsLabel.font = UIFont(name: "HelveticaNeue", size: 9)
        pointsLabel.textColor = UIColor.systemBlue
        
        renderer.$currentPointCount
            .combineLatest(renderer.$maxPoints)
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: false)
            .sink { (args) in
                let (currentPointCount, maxPoints) = args
                pointsLabel.text = "Points : \(currentPointCount) / \(maxPoints)"
                pointsLabel.sizeToFit()
            }
            .store(in: &cancellable)
        
        // Particle size
        let particleSizeLabel = UILabel()
        
        particleSizeLabel.font = UIFont(name: "HelveticaNeue", size: 9)
        particleSizeLabel.textColor = UIColor.systemBlue
        renderer.$particleSize
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: false)
            .sink { (particleSize) in
                particleSizeLabel.text = "Particle size : \(particleSize.rounded())"
                particleSizeLabel.sizeToFit()
            }
            .store(in: &cancellable)
        
        return [pointsLabel, particleSizeLabel]
    }
    
    /// Configure the Controls overlay
    private func setupControlsOverlay() {
        let stackView = UIStackView()
        let backgroundView = UIView()
        
        setupControls()
        
        stackView.addArrangedSubview(confidenceControl)
        stackView.addArrangedSubview(maxPointsSlider)
        stackView.addArrangedSubview(particleSizeSlider)
        stackView.addArrangedSubview(rgbRadiusSlider)
        stackView.isHidden = !isUIEnabled
        stackView.axis = .vertical
        stackView.spacing = 20
        
        backgroundView.addBlurEffectView()
        backgroundView.layer.cornerRadius = 10
        backgroundView.clipsToBounds = true
        
        backgroundView.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(10)
        }
        
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-50)
        }
    }
    
    /// Configure the different controls the user can interact with
    private func setupControls() {
        // Confidence control
        confidenceControl.selectedSegmentIndex = renderer.confidenceThreshold
        confidenceControl.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // Max Points Control
        maxPointsSlider.maximumValueImage = UIImage.init(systemName: "aqi.low")
        maxPointsSlider.minimumValue = Float(Constants.Renderer.minMaxPoints)
        maxPointsSlider.maximumValue = Float(Constants.Renderer.maxMaxPoints)
        maxPointsSlider.isContinuous = true
        maxPointsSlider.value = Float(renderer.maxPoints)
        maxPointsSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // Point Size Control
        particleSizeSlider.minimumValueImage = UIImage.init(systemName: "smallcircle.fill.circle")
        particleSizeSlider.maximumValueImage = UIImage.init(systemName: "largecircle.fill.circle")
        particleSizeSlider.minimumValue = Constants.Renderer.minParticleSize
        particleSizeSlider.maximumValue = Constants.Renderer.maxParticleSize
        particleSizeSlider.isContinuous = true
        particleSizeSlider.value = renderer.particleSize
        particleSizeSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // RGB Radius control
        rgbRadiusSlider.minimumValueImage = UIImage.init(systemName: "video")
        rgbRadiusSlider.maximumValueImage = UIImage.init(systemName: "video.fill")
        rgbRadiusSlider.minimumValue = 0
        rgbRadiusSlider.maximumValue = 1.5
        rgbRadiusSlider.isContinuous = true
        rgbRadiusSlider.value = renderer.rgbRadius
        rgbRadiusSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
    }
}

// MARK: - MTKViewDelegate

extension PointCloudCaptureViewController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {
    
}
