//
//  SCNViewerViewModel+PLY.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation
import Combine

extension SCNViewerViewModel {
    
    func generatePly(from vertices: [Vertex]) -> Future<PolygonFileFormat, Never> {
        Future<PolygonFileFormat, Never> { (promise) in
            DispatchQueue.global(qos: .background).async {
                promise(.success(SCNViewerViewModel.generatePly(using: vertices)))
            }
        }
    }
    
    private static func generatePly(using vertices: [Vertex]) -> PolygonFileFormat {
        // MARK: - Vertices
        let comments = ["author: PointCloudKit - Download at [https://apps.apple.com/us/app/pointcloudkit/id1546476130]",
                        "object: colored point cloud scan"]
        return PolygonFileFormat(vertices: vertices, comments: comments)
    }
}
