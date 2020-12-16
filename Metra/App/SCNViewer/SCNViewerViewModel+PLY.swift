//
//  SCNViewerViewModel+PLY.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation
import Combine

extension SCNViewerViewModel {
    
    func generatePly() -> Future<PolygonFileFormat, Error> {
        Future<PolygonFileFormat, Error> { [weak self] (promise) in
            guard let vertices = self?.vertices else {
                promise(.failure(SCNViewerViewModelError.missingVertices))
                return
            }
            DispatchQueue.global(qos: .background).async {
                promise(.success(SCNViewerViewModel.generatePly(using: vertices)))
            }
        }
    }
    
    private static func generatePly(using vertices: [Vertex]) -> PolygonFileFormat {
        // MARK: - Vertices
        let comments = ["author: iOSMetraApp - Download at [insert url later]",
                        "object: colored point cloud scan"]
        return PolygonFileFormat(vertices: vertices, comments: comments)
    }
}
