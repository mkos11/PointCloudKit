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
    lazy var exportUrl = temporaryDirectoryUrl.appendingPathComponent("\(filename)")
    // Used for export
    let vertices: [Vertex]
    // The scene being presented
    @Published
    private(set) var scene: SCNScene?
    
    var filename: String { "metraPointCloud_\(Date().humanReadableTimestamp)" }
    
    init(vertices: [Vertex]) {
        self.vertices = vertices
        // Start SCNScene generation in the background
        generateScene()
            .compactMap({ $0 }) // Do error handling
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
