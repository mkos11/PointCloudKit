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
    
    private func load(scene: SCNScene) {
        // 1: Load .scn file
//        let scene = SCNSceneSource(url: viewModel.scnFileLocation)?.scene()
        
        // 2: Add camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // 3: Place camera
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 5)
        // 4: Set camera on scene
        scene.rootNode.addChildNode(cameraNode)
        
//        // 5: Adding light to scene
//        let lightNode = SCNNode()
//        lightNode.light = SCNLight()
//        lightNode.light?.type = .omni
//        lightNode.position = SCNVector3(x: 0, y: 0, z: 40)
//        scene.rootNode.addChildNode(lightNode)

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
        
        // Set background color
        sceneView.backgroundColor = UIColor.white
        
        // Allow user translate image
        sceneView.cameraControlConfiguration.allowsTranslation = false
        
        // Set scene settings
        sceneView.scene = scene
        
        sceneView.alpha = 1
    }
    
    @objc
    private func export() {
        documentInteractionController.url = viewModel.exportUrl
        documentInteractionController.uti = viewModel.exportUti
        documentInteractionController.name = viewModel.filename
        documentInteractionController.presentOptionsMenu(from: view.frame,
                                                         in: view,
                                                         animated: true)
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
        activityIndicatorView.color = .darkGray
        view.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints { (make) in
            make.center.equalTo(view.center)
        }
    }
    
    private func setupObservers() {
        // Wait for scene to be ready and loads it
        activityIndicatorView.startAnimating()
        viewModel.scenePublisher
            .sink { [unowned self] (scene) in
                DispatchQueue.main.async {
                    self.activityIndicatorView.stopAnimating()
                    UIView.animate(withDuration: 1) {
                        self.load(scene: scene)
                    }
                }
            }
            .store(in: &cancellable)
    }
    
    private func setupControls() {
        // Export button
        let exportCaptureButton = UIBarButtonItem(title: "Save", style: .plain,
                                                  target: self, action: #selector(export))
        navigationItem.rightBarButtonItem = exportCaptureButton
    }
}
