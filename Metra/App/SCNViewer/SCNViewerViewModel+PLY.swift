//
//  SCNViewerViewModel+PLY.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation
import Combine

extension SCNViewerViewModel {

    func generatePly() -> PassthroughSubject<PolygonFileFormat, Never> {
        let plySubject = PassthroughSubject<PolygonFileFormat, Never>()
        DispatchQueue.global(qos: .background).async {
            let ply = self.generatePly(from: self.vertices)
            plySubject.send(ply)
        }
        return plySubject
    }
    
    private func generatePly(from vertices: [Vertex]) -> PolygonFileFormat {
        // MARK: - Vertices
        let comments = ["author: iOSMetraApp - Download at [insert url later]",
                        "object: colored point cloud scan"]
        return PolygonFileFormat(vertices: vertices, comments: comments)
    }
}
