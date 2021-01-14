//
//  SCNViewerViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Foundation
import SceneKit
import Combine
import ARKit

enum SCNViewerViewModelError: Error {
    case missingVertices
}

enum ViewerContentType {
    case pointCloud
    case meshes
}

final class SCNViewerViewModel {
    private var cancellable: Set<AnyCancellable> = []
    
    private lazy var temporaryDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    lazy var exportUrl = temporaryDirectoryUrl.appendingPathComponent("\(filename)")

    let presentedContent: ViewerContentType
    
    // Used for export
    @Published
    private (set) var vertices: [Vertex]? // if presenting point cloud // clean later
    // The scene being presented
    @Published
    private (set) var scene: SCNScene?
    
    var filename: String { "metraPointCloud_\(Date().humanReadableTimestamp)" }

    init(verticesFuture: Future<[Vertex], Error>) {
        presentedContent = .pointCloud
        // Wait for vertice export from renderer...
        verticesFuture
            .flatMap({ [unowned self] (vertices) -> Future<SCNScene, Never> in
                self.vertices = vertices
                return self.generateScene(using: vertices)
            })
            .sink(receiveCompletion: { (completion) in
                switch completion {
                case let .failure(error): fatalError("\(error.localizedDescription)")
                case .finished: ()
                }
            }, receiveValue: { [unowned self] (scene) in
                self.scene = scene
            })
            .store(in: &cancellable)
    }
    
    init(meshAnchors: [ARMeshAnchor]) {
        presentedContent = .meshes
        generateScene(using: meshAnchors)
            .compactMap { $0 }
            .assign(to: &$scene)
    }
}

extension Date {
    fileprivate var humanReadableTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.dateFormat = "HHmmssss"
        return formatter.string(from: self)
    }
}
