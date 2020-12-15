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
    
    // The scene being presented
    @Published
    private(set) var scene: SCNScene?
    
    init(scenePublisher: PassthroughSubject<SCNScene, Never>) {
        scenePublisher.compactMap({ $0 }).assign(to: &$scene)
    }
    
    func writeScene(scene: SCNScene, completion: (() -> Void)?) {
        scene.write(to: exportUrl,
                    options: nil,
                    delegate: nil) { (_, error, _) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion?()
        }
    }
}
