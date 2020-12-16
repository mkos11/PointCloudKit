//
//  SCNViewerViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Foundation
import SceneKit
import Combine
import UniformTypeIdentifiers

final class SCNViewerViewModel {
    private lazy var temporaryDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    
    lazy var filename = "metraPointCloud\(Date())"
    lazy var exportUrl = temporaryDirectoryUrl.appendingPathComponent("\(filename)")
    let exportUti = "public.data, public.content"
    
    let supportedExportTypes: [UTType] = [.polygonFile, .sceneKitScene]
    
    // Used for export
    let vertices: [Vertex]
    
    // The scene being presented
    @Published
    private(set) var scene: SCNScene?
    
    init(vertices: [Vertex]) {
        self.vertices = vertices
        // Start SCNScene generation in the background
        generateScene()
            .compactMap({ $0 }) // Do error handling
            .assign(to: &$scene)
    }
    
    func writeScene(scene: SCNScene, completion: (() -> Void)?) {
        scene.write(to: exportUrl.appendingPathExtension(for: .sceneKitScene),
                    options: nil,
                    delegate: nil) { (_, error, _) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion?()
        }
    }
}

extension UTType {
    
    /// A type that represent a PolygonFileFormat file (.ply)
    static let polygonFile: UTType = UTType(importedAs: ".ply", conformingTo: .plainText)
}
