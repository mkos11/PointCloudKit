//
//  SCNViewerViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import SceneKit

final class SCNViewerViewController: UIViewController {

    private let viewModel: SCNViewerViewModel
    
    init(viewModel: SCNViewerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let sceneView = view as? SCNView {
            let scene = SCNSceneSource(url: viewModel.scnFileLocation)?.scene()
            sceneView.scene = scene
        }
    }
}
