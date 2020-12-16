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
    let viewModel = PointCloudCaptureViewModel()
    private var cancellable: Set<AnyCancellable> = []
    
    // Panels
    private let controlPanelView = UIView()
    private let metricsPanelView = UIView()
    // Metrics
    let pointsLabel = UILabel()
    let particleSizeLabel = UILabel()
    // Controls
    private let resetCaptureButton = UIButton()
    private let toggleCaptureButton = UIButton()
    private let viewCaptureButton = UIButton()
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let maxPointsSlider = UISlider()
    private let particleSizeSlider = UISlider()
    private let rgbRadiusSlider = UISlider()
    // AR Overlay
    let coachingOverlayView = ARCoachingOverlayView()
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.session.delegate = self
        viewModel.loadMetalView(in: view)
        setupUI()
        setupBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        coachingOverlayView.setActive(true, animated: true)
        UIView.animate(withDuration: 0, delay: 0.5, animations: {
            self.viewModel.startRenderer(overridingCurrentSession: false)
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        coachingOverlayView.setActive(false, animated: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.stopRenderer()
    }
    
    @objc
    private func viewValueChanged(view: UIView) {
        switch view {
        case confidenceControl:
            viewModel.confidenceThreshold = confidenceControl.selectedSegmentIndex
        case maxPointsSlider:
            viewModel.maxPoints = Int(maxPointsSlider.value)
        case particleSizeSlider:
            viewModel.particleSize = particleSizeSlider.value
        case rgbRadiusSlider:
            viewModel.rgbRadius = rgbRadiusSlider.value
        case resetCaptureButton:
            coachingOverlayView.setActive(true, animated: true)
            viewModel.startRenderer(overridingCurrentSession: true)
        case toggleCaptureButton:
            toggleCapture()
        case viewCaptureButton:
            viewModel.pauseCapture()
            navigateToScnViewer()
        default:
            break
        }
    }
        
    private func toggleCapture() {
        toggleCaptureButton.isSelected.toggle()
        switch toggleCaptureButton.isSelected {
        case false:
            coachingOverlayView.setActive(true, animated: true)
            viewModel.resumeCapture()
        case true:
            viewModel.pauseCapture()
        }
    }
    
    // Move to a viewModel/coordinator
    private func navigateToScnViewer() {
        let viewModel = SCNViewerViewModel(verticesFuture: self.viewModel.vertices)
        let viewerViewController = SCNViewerViewController(viewModel: viewModel)
        navigationController?.pushViewController(viewerViewController, animated: true)
    }
}

// MARK: - Setup

extension PointCloudCaptureViewController {
    private func setupUI() {
        setupMetricsOverlay()
        setupControlsOverlay()
        setupCoachingOverlay()
    }
    
    private func setupBindings() {
        viewModel.shouldShowUI
            .receive(on: DispatchQueue.main)
            .sink { [weak metricsPanelView, weak controlPanelView] (shouldShowUI) in
                metricsPanelView?.isHidden = !shouldShowUI
                controlPanelView?.isHidden = !shouldShowUI
                
            }
            .store(in: &cancellable)
        
        viewModel.$rendererIsCapturing
            .receive(on: DispatchQueue.main)
            .sink { [weak rgbRadiusSlider] (isCapturing) in
                UIView.animate(withDuration: 1) {
                    if isCapturing {
                        rgbRadiusSlider?.value = 0.5
                    } else {
                        rgbRadiusSlider?.value = 0.0
                    }
                }
            }
            .store(in: &cancellable)
        
        setupMetricsBindings()
        setupSlidersBindings()
    }
    
    private func setupMetricsBindings() {
        viewModel.$pointCountMetric
            .receive(on: DispatchQueue.main)
            .sink { [weak pointsLabel] pointCountMetric in
                pointsLabel?.text = pointCountMetric
            }
            .store(in: &cancellable)
        viewModel.$particleSizeMetric
            .receive(on: DispatchQueue.main)
            .sink { [weak particleSizeLabel] particleSizeMetric in
                particleSizeLabel?.text = particleSizeMetric
            }
            .store(in: &cancellable)
        
        // Buttons
        viewModel.$resetButtonIsEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak resetCaptureButton] isEnabled in
                resetCaptureButton?.isEnabled = isEnabled
            }
            .store(in: &cancellable)
        viewModel.$viewCaptureButtonIsEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak viewCaptureButton] isEnabled in
                viewCaptureButton?.isEnabled = isEnabled
            }
            .store(in: &cancellable)
        viewModel.$toggleCaptureButtonIsSelected
            .receive(on: DispatchQueue.main)
            .sink { [weak toggleCaptureButton] isSelected in
                toggleCaptureButton?.isSelected = isSelected
            }
            .store(in: &cancellable)
    }
    
    private func setupSlidersBindings() {
        viewModel.$rgbRadius
            .receive(on: DispatchQueue.main)
            .sink { [weak rgbRadiusSlider] rgbRadius in
                rgbRadiusSlider?.value = rgbRadius
            }
            .store(in: &cancellable)
        viewModel.$maxPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak maxPointsSlider] maxPoint in
                maxPointsSlider?.value = Float(maxPoint)
            }
            .store(in: &cancellable)
        viewModel.$particleSize
            .receive(on: DispatchQueue.main)
            .sink { [weak particleSizeSlider] particleSize in
                particleSizeSlider?.value = particleSize
            }
            .store(in: &cancellable)
    }
    
    /// Configure the Metrics overlay
    private func setupMetricsOverlay() {
        let stackView = UIStackView()
        let font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        
        // Current points count over max points
        pointsLabel.font = font
        pointsLabel.textColor = UIColor.amazon
        // Particle size
        particleSizeLabel.font = font
        particleSizeLabel.textColor = UIColor.amazon
        
        stackView.addArrangedSubview(pointsLabel)
        stackView.addArrangedSubview(particleSizeLabel)

        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 5
        
        let blurView = metricsPanelView.addBlurEffectView()
        metricsPanelView.layer.cornerRadius = 10
        metricsPanelView.clipsToBounds = true
        
        blurView?.contentView.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(10)
        }
        
        view.addSubview(metricsPanelView)
        metricsPanelView.snp.makeConstraints { (make) -> Void in
            make.width.equalToSuperview().multipliedBy(0.35)
            make.height.equalToSuperview().multipliedBy(0.05)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.right).offset(-10)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(10)
         }
    }
    
    /// Configure the Controls overlay
    private func setupControlsOverlay() {
        let stackView = UIStackView()
        let captureControlsStackView = UIStackView()
        
        setupControls()
        
        captureControlsStackView.addArrangedSubview(resetCaptureButton)
        captureControlsStackView.addArrangedSubview(toggleCaptureButton)
        captureControlsStackView.addArrangedSubview(viewCaptureButton)
        captureControlsStackView.axis = .horizontal
        captureControlsStackView.distribution = .fillEqually
        captureControlsStackView.spacing = 20
        
        stackView.addArrangedSubview(captureControlsStackView)
        stackView.addArrangedSubview(confidenceControl)
        stackView.addArrangedSubview(maxPointsSlider)
        stackView.addArrangedSubview(particleSizeSlider)
        stackView.addArrangedSubview(rgbRadiusSlider)
        stackView.axis = .vertical
        stackView.spacing = 20
        
        let blurView = controlPanelView.addBlurEffectView()
        controlPanelView.layer.cornerRadius = 10
        controlPanelView.clipsToBounds = true
        
        blurView?.contentView.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(10)
        }
        
        view.addSubview(controlPanelView)
        controlPanelView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-50)
        }
    }
    
    /// Configure the different controls the user can interact with
    private func setupControls() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)
        // Reset capture button
        resetCaptureButton.setImage(UIImage(systemName: "trash.circle", withConfiguration: symbolConfiguration), for: .normal)
        resetCaptureButton.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        
        // Toggle capturing
        toggleCaptureButton.setImage(UIImage(systemName: "pause.circle", withConfiguration: symbolConfiguration), for: .normal)
        toggleCaptureButton.setImage(UIImage(systemName: "record.circle", withConfiguration: symbolConfiguration), for: .selected)
        toggleCaptureButton.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        
        // View capture button
        viewCaptureButton.setImage(UIImage(systemName: "eye.circle", withConfiguration: symbolConfiguration),
                                   for: .normal)
        
        viewCaptureButton.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        viewCaptureButton.isEnabled = false
        // Redo that logic into a VM
        
        // Confidence control
        confidenceControl.selectedSegmentIndex = viewModel.confidenceThreshold
        confidenceControl.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // Max Points Control
        maxPointsSlider.maximumValueImage = UIImage.init(systemName: "aqi.low")
        maxPointsSlider.minimumValue = Float(Constants.Renderer.minMaxPoints)
        maxPointsSlider.maximumValue = Float(Constants.Renderer.maxMaxPoints)
        maxPointsSlider.isContinuous = true
        maxPointsSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // Point Size Control
        particleSizeSlider.minimumValueImage = UIImage.init(systemName: "smallcircle.fill.circle")
        particleSizeSlider.maximumValueImage = UIImage.init(systemName: "largecircle.fill.circle")
        particleSizeSlider.minimumValue = Constants.Renderer.minParticleSize
        particleSizeSlider.maximumValue = Constants.Renderer.maxParticleSize
        particleSizeSlider.isContinuous = true
        particleSizeSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // RGB Radius control
        rgbRadiusSlider.minimumValueImage = UIImage.init(systemName: "video")
        rgbRadiusSlider.maximumValueImage = UIImage.init(systemName: "video.fill")
        rgbRadiusSlider.minimumValue = 0
        rgbRadiusSlider.maximumValue = 1.5
        rgbRadiusSlider.isContinuous = true
        rgbRadiusSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
    }
}
