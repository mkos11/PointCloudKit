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
    private let captureControlsStackView = UIStackView()
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let maxPointsSlider = UISlider()
    private let particleSizeSlider = UISlider()
    private let rgbRadiusSlider = UISlider()
    
    private let documentInteractionController = UIDocumentInteractionController()
    private let progressView =  UIProgressView()
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session.delegate = self
        documentInteractionController.delegate = self
        setupUI()
    }
    
    // Create a world-tracking configuration, and
    // enable the scene depth frame-semantic.
    lazy private var configuration: ARConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
//        configuration.environmentTexturing = .automatic // Use that later?
//        configuration.planeDetection = .horizontal
//        configuration.sceneReconstruction = .mesh
        return configuration
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
    
    private func resumeCapture() {
        renderer.isAccumulating = true
    }
    
    private func pauseCapture() {
        renderer.isAccumulating = false
    }
    
    private func pauseSession() {
        session.pause()
    }
    
    private func restartSession() {
        renderer.resetBuffers()
        session.run(configuration, options: [.resetTracking,
                                             .resetSceneReconstruction,
                                             .removeExistingAnchors,
                                             .stopTrackedRaycasts])
    }
}

// MARK: - UI Setup

extension PointCloudCaptureViewController {
    private func setupUI() {
        setupMetalRenderer()
        setupMetricsOverlay()
        setupControlsOverlay()
        setupProgressView()
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
        stackView.distribution = .fillEqually
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
            make.height.equalToSuperview().multipliedBy(0.05)
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
        
        stackView.addArrangedSubview(captureControlsStackView)
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
        // Capture control
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)
        // Reset capture session
        let resetCaptureButton = UIButton()
        resetCaptureButton.setImage(UIImage(systemName: "trash.circle", withConfiguration: symbolConfiguration), for: .normal)
        resetCaptureButton.addTarget(self, action: #selector(resetCapture), for: .touchUpInside)
        resetCaptureButton.isEnabled = false
        renderer.$currentPointCount
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: false)
            .sink { [unowned resetCaptureButton] (currentPointCount) in
                resetCaptureButton.isEnabled = (currentPointCount != 0)
            }
            .store(in: &cancellable)
        // Toggle capturing
        let toggleCaptureButton = UIButton()
        toggleCaptureButton.setImage(UIImage(systemName: "pause.circle", withConfiguration: symbolConfiguration), for: .normal)
        toggleCaptureButton.setImage(UIImage(systemName: "record.circle", withConfiguration: symbolConfiguration), for: .selected)
        toggleCaptureButton.addTarget(self, action: #selector(toggleCapture), for: .touchUpInside)
        // Export capture button
        let exportCaptureButton = UIButton()
        exportCaptureButton.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: symbolConfiguration), for: .normal)
        exportCaptureButton.addTarget(self, action: #selector(exportCapture), for: .touchUpInside)
        exportCaptureButton.isEnabled = false
        renderer.$currentPointCount
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: false)
            .sink { [unowned exportCaptureButton] (currentPointCount) in
                exportCaptureButton.isEnabled = (currentPointCount != 0)
            }
            .store(in: &cancellable)
        //
        captureControlsStackView.addArrangedSubview(resetCaptureButton)
        captureControlsStackView.addArrangedSubview(toggleCaptureButton)
        captureControlsStackView.addArrangedSubview(exportCaptureButton)
        captureControlsStackView.axis = .horizontal
        captureControlsStackView.distribution = .fillEqually
        captureControlsStackView.spacing = 20
        
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
    
    private func setupProgressView() {
        progressView.isHidden = true
        progressView.alpha = 0
        view.addSubview(progressView)
        progressView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(10)
            make.width.equalTo(300)
        }
    }
}

// MARK: - Capture controls
extension PointCloudCaptureViewController {
    @objc
    private func toggleCapture(sender: UIButton) {
        sender.isSelected.toggle()
        switch sender.isSelected {
        case false:
            resumeCapture()
        case true:
            pauseCapture()
        }
    }
    @objc
    private func resetCapture() {
        restartSession()
    }
    @objc
    private func exportCapture() {
        pauseCapture()
        let tmpDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = "metra3dfile\(UUID().uuidString)"
        let targetURL = tmpDirectoryURL.appendingPathComponent("\(fileName).scn")
        
        documentInteractionController.url = targetURL
        documentInteractionController.uti = "public.data, public.content"
        documentInteractionController.name = targetURL.lastPathComponent
        UIView.animate(withDuration: 1, animations: {
            self.progressView.isHidden = false
            self.progressView.alpha = 1
        }, completion: { _ in
            DispatchQueue.init(label: "Renderer.Export", qos: .background).async {
                self.renderer.exportPointCloudToFile(at: targetURL) { (progress) in
                    DispatchQueue.main.async {
                        self.updateExportUi(progress: progress, animated: true)
                    }
                }
            }
        })
    }
    
    private func updateExportUi(progress: Double, animated: Bool) {
        let animationDuration = animated ? 1 : 0.0
        progressView.setProgress(Float(progress), animated: animated)
        if progress == 1 {
            UIView.animate(withDuration: animationDuration, animations: {
                self.progressView.alpha = 0
            }, completion: { _ in
                self.progressView.isHidden = true
                self.documentInteractionController.presentOptionsMenu(from: self.captureControlsStackView.frame,
                                                                      in: self.view,
                                                                      animated: animated)
            })
        }
    }
}

extension PointCloudCaptureViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        resumeCapture()
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
