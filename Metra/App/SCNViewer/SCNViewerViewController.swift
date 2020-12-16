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
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 5)
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
        sceneView.debugOptions.insert(.showFeaturePoints)
        sceneView.debugOptions.insert(.renderAsWireframe)
        
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
        let exportTypeSelection = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let scnExport = UIAlertAction(title: UTType.sceneKitScene.localizedDescription, style: .default, handler: exportScn)
        exportTypeSelection.addAction(scnExport)
        
        let plyExport = UIAlertAction(title: UTType.polygonFile.localizedDescription, style: .default, handler: exportPly)
        exportTypeSelection.addAction(plyExport)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: dismissPresentedPopup)
        exportTypeSelection.addAction(cancelAction)
        
        present(exportTypeSelection, animated: true, completion: nil)
    }
    
    private func exportScn(_ sender: UIAlertAction) {
        export(type: .sceneKitScene)
    }
    
    private func exportPly(_ sender: UIAlertAction) {
        export(type: .polygonFile)
    }
    
    private func dismissPresentedPopup(_ sender: UIAlertAction) {
        dismiss(animated: true, completion: nil)
    }
    
    private func export(type: UTType) {
        let exportUrl: URL
        activityIndicatorView.startAnimating()
        switch type {
        case .polygonFile:
            exportUrl = viewModel.exportUrl.appendingPathExtension(for: type)
            viewModel.generatePly()
                .sink { [weak self] plyData in
                    do {
                        try plyData.generateAscii()?.write(to: exportUrl, options: [.atomicWrite])
                    } catch {
                        fatalError("Failed to write PLY file \(error)")
                    }
                    DispatchQueue.main.async { self?.presentDocumentInteractionController() }
                }
                .store(in: &cancellable)
        case .sceneKitScene:
            exportUrl = viewModel.exportUrl.appendingPathExtension(for: type)
            guard let scene = viewModel.scene else { return }
            let progressHandler: SCNSceneExportProgressHandler = { [weak self] (progress, error, _) in
                if let error = error {
                    fatalError(error.localizedDescription)
                }
                if progress == 1 {
                    DispatchQueue.main.async { self?.presentDocumentInteractionController() }
                }
            }
            scene.write(to: exportUrl,
                        options: nil,
                        delegate: nil,
                        progressHandler: progressHandler)
        default:
            return
        }
        documentInteractionController.url = exportUrl
        documentInteractionController.uti = type.identifier
        documentInteractionController.name = exportUrl.lastPathComponent
    }
    
    private func presentDocumentInteractionController() {
        activityIndicatorView.stopAnimating()
        documentInteractionController.presentOptionsMenu(from: view.frame, in: view, animated: true)
    }
}

extension SCNViewerViewController {
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
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
                UIView.animate(withDuration: 1) {
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
