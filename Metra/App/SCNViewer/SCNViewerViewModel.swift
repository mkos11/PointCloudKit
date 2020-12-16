//
//  SCNViewerViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Foundation
import SceneKit
import Combine

enum SCNViewerViewModelError: Error {
    case missingVertices
}

final class SCNViewerViewModel {
    private var cancellable: Set<AnyCancellable> = []
    
    private lazy var temporaryDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    lazy var exportUrl = temporaryDirectoryUrl.appendingPathComponent("\(filename)")
    // Used for export
    @Published
    private (set) var vertices: [Vertex]?
    // The scene being presented
    @Published
    private (set) var scene: SCNScene?
    
    var filename: String { "metraPointCloud_\(Date().humanReadableTimestamp)" }
    
    init(verticesFuture: Future<[Vertex], Error>) {
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
}

extension Date {
    fileprivate var humanReadableTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.dateFormat = "HHmmssss"
        return formatter.string(from: self)
    }
}
