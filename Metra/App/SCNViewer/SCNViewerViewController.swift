//
//  SCNViewerViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import UIKit
import Combine
import SceneKit
import SnapKit
import UniformTypeIdentifiers

final class SCNViewerViewController: UIViewController {
    private var cancellable: Set<AnyCancellable> = []

    private let viewModel: SCNViewerViewModel
    
    private let controlsStackView = UIStackView()
    private let activityIndicatorView = UIActivityIndicatorView()
    private let sceneView = SCNView()
    private let documentInteractionController = UIDocumentInteractionController()
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool { true }
    
    init(viewModel: SCNViewerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupControls()
        setupObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // private func loadScene(from file: URL) {
    //     let scene = SCNSceneSource(url: viewModel.scnFileLocation)?.scene()
    
    private func load(scene: SCNScene) {
        // 2: Add camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // 3: Place camera
        cameraNode.position = scene.rootNode.worldPosition
        cameraNode.position.z += 30
        // 4: Set camera on scene
        scene.rootNode.addChildNode(cameraNode)

        // 6: Creating and adding ambient light to scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Allow user to manipulate camera
        sceneView.allowsCameraControl = true
        
        // Show FPS logs and timming
        sceneView.showsStatistics = true
        if viewModel.presentedContent == .meshes {
            sceneView.debugOptions.insert(.renderAsWireframe)
        }
        
        // Set background color
        sceneView.backgroundColor = UIColor.black
        
        // Allow user translate image
        sceneView.cameraControlConfiguration.allowsTranslation = false
        
        // Set scene settings
        sceneView.scene = scene
        sceneView.alpha = 1
    }
    
    @objc
    private func presentExportTypeSelection() {
        let exportTypeSelection = UIAlertController(title: "Supported Export Formats", message: nil, preferredStyle: .actionSheet)
        let scnExport = UIAlertAction(title: UTType.sceneKitScene.localizedDescription, style: .default) { [weak self] _ in
            self?.export(type: .sceneKitScene)
        }
        let plyExport = UIAlertAction(title: UTType.polygonFile.localizedDescription, style: .default) { [weak self] _ in
            self?.export(type: .polygonFile)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        
        exportTypeSelection.addAction(scnExport)
        exportTypeSelection.addAction(plyExport)
        exportTypeSelection.addAction(cancelAction)
        present(exportTypeSelection, animated: true, completion: nil)
    }
    
    private func export(type: UTType) {
        let url = viewModel.exportUrl.appendingPathExtension(for: type)
        
        activityIndicatorView.startAnimating()
        switch type {
        case .polygonFile:
            exportPly(to: url)
        case .sceneKitScene:
            exportScn(to: url)
        default:
            return
        }
        documentInteractionController.url = url
        documentInteractionController.uti = type.identifier
        documentInteractionController.name = url.lastPathComponent
    }
    
    private func exportPly(to url: URL) {
        guard viewModel.presentedContent != .meshes, let vertices = viewModel.vertices else {
            let alertController = UIAlertController(title: "Coming soon",
                                                    message: "Feature not implemented yet", preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Sigh", style: .cancel, handler: nil)
            alertController.addAction(dismissAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        viewModel.generatePly(from: vertices)
            .sink(receiveCompletion: { [weak self] (_) in
                DispatchQueue.main.async { self?.activityIndicatorView.stopAnimating() }
            }, receiveValue: { [weak self] (ply) in
                do {
                    try ply.generateAscii()?.write(to: url, options: [.atomicWrite])
                } catch {
                    let alertController = UIAlertController(title: "Error",
                                                            message: "Error while generating PLY file", preferredStyle: .alert)
                    let dismissAction = UIAlertAction(title: "Sigh", style: .cancel, handler: nil)
                    alertController.addAction(dismissAction)
                    DispatchQueue.main.async { self?.present(alertController, animated: true, completion: nil) }
                }
                DispatchQueue.main.async { self?.presentDocumentInteractionController() }
            })
            .store(in: &cancellable)
    }
    
    private func exportScn(to url: URL) {
        guard let scene = viewModel.scene else { return }
        scene.write(to: url, options: nil, delegate: nil) { [weak self] (progress, error, _) in
            DispatchQueue.main.async { self?.activityIndicatorView.stopAnimating() }
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if progress == 1 {
                DispatchQueue.main.async { self?.presentDocumentInteractionController() }
            }
        }
    }
    
    private func presentDocumentInteractionController() {
        documentInteractionController.presentOptionsMenu(from: view.frame, in: view, animated: true)
    }
}

extension SCNViewerViewController {
    
    private func setupUI() {
        view.backgroundColor = UIColor.black

        let loadingLabel = UILabel()
        loadingLabel.text = "Converting capture to SCN scene..."
        loadingLabel.textColor = UIColor.amazon
        view.addSubview(loadingLabel)
        loadingLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(60)
        }

        // Scene view
        view.addSubview(sceneView)
        sceneView.snp.makeConstraints { (make) in
            make.edges.equalTo(view.safeAreaInsets)
        }
        sceneView.alpha = 0
        // Activity indicator view
        activityIndicatorView.style = .large
        activityIndicatorView.color = UIColor.amazon
        view.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints { (make) in
            make.center.equalTo(view.center)
        }
    }
    
    private func setupObservers() {
        // Wait for scene to be ready and loads it
        activityIndicatorView.startAnimating()
        viewModel.$scene
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (scene) in
                guard let scene = scene else { return }
                self?.activityIndicatorView.stopAnimating()
                UIView.animate(withDuration: 0.5) {
                    self?.load(scene: scene)
                }
            }
            .store(in: &cancellable)
    }
    
    private func setupControls() {
        // Export button
        let exportCaptureButton = UIBarButtonItem(title: "💾", style: .plain,
                                                  target: self, action: #selector(presentExportTypeSelection))
        navigationItem.rightBarButtonItem = exportCaptureButton
    }
}
