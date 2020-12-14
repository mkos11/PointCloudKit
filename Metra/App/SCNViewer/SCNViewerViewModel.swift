//
//  SCNViewerViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Foundation
import SceneKit
import Combine

final class SCNViewerViewModel {
    private lazy var temporaryDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    
    lazy var filename = "metra3dfile\(UUID().uuidString)"
    lazy var exportUrl = temporaryDirectoryUrl.appendingPathComponent("\(filename).scn")
    let exportUti = "public.data, public.content"
    
    let scenePublisher: PassthroughSubject<SCNScene, Never>
    
    init(scenePublisher: PassthroughSubject<SCNScene, Never>) {
        self.scenePublisher = scenePublisher
    }
    
    func writeScene(scene: SCNScene) {
        scene.write(to: exportUrl,
                    options: nil,
                    delegate: nil) { (progress, error, _) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
        }
    }
}
