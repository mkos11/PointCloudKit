//
//  Renderer+PLY.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation
import Combine

extension Renderer {

    func generatePly() -> PassthroughSubject<PolygonFileFormat, Never> {
        let plySubject = PassthroughSubject<PolygonFileFormat, Never>()
        DispatchQueue.global(qos: .background).async {
            let ply: PolygonFileFormat = self.generatePly()
            plySubject.send(ply)
        }
        return plySubject
    }
    
    private func generatePly() -> PolygonFileFormat {
        // MARK: - Vertices
        var vertices = [Vertex]()
        let confidenceRequierment = Float(confidenceThreshold) / 2.0
        for index in 0..<currentPointCount {
            let point = particlesBuffer[index]
            // Skip if below selected confidence (So that export reflect what's seen on screen)
            guard point.confidence >= confidenceRequierment else { continue}
            let vertex = Vertex(x: point.position.x, y: point.position.y, z: point.position.z,
                                          r: point.color.x, g: point.color.y, b: point.color.z)
            vertices.append(vertex)
        }
        let comments = ["author: iOSMetraApp - Download at [insert url later]",
                        "object: colored point cloud scan"]
        return PolygonFileFormat(vertices: vertices, comments: comments)
    }
}
