//
//  Renderer+Export.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Metal
import MetalKit
import ARKit
import Combine

extension Renderer {
    
    struct PointCloudVertex {
        // swiftlint:disable identifier_name
        let x: Float, y: Float, z: Float
        // swiftlint:disable identifier_name
        let r: Float, g: Float, b: Float
    }
    
    func exportPointCloudToFile(at url: URL, progressHandler: ((Double) -> Void)? = nil) {
        let scene = SCNScene()
        var vertices = [PointCloudVertex]()
        let confidenceRequiered = Float(confidenceThreshold) / 2.0
        
        for index in 0..<currentPointCount {
            let point = particlesBuffer[index]
            // Skip if below selected confidence (So that export reflect what's seen on screen)
            guard point.confidence >= confidenceRequiered else { continue}
            let vertex = PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z,
                                          r: point.color.x, g: point.color.y, b: point.color.z)
            vertices.append(vertex)
        }
        progressHandler?(0.3)
        let vertexData = Data(bytes: &vertices, count: MemoryLayout<PointCloudVertex>.size * vertices.count)
        let positionSource = SCNGeometrySource(data: vertexData,
                                               semantic: SCNGeometrySource.Semantic.vertex,
                                               vectorCount: vertices.count,
                                               usesFloatComponents: true,
                                               componentsPerVector: 3,
                                               bytesPerComponent: MemoryLayout<Float>.size,
                                               dataOffset: 0,
                                               dataStride: MemoryLayout<PointCloudVertex>.size)
        progressHandler?(0.5)
        let colorSource = SCNGeometrySource(data: vertexData,
                                            semantic: SCNGeometrySource.Semantic.color,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: MemoryLayout<Float>.size * 3,
                                            dataStride: MemoryLayout<PointCloudVertex>.size)
        progressHandler?(0.7)
        let elements = SCNGeometryElement(data: nil,
                                          primitiveType: .point,
                                          primitiveCount: vertices.count,
                                          bytesPerIndex: MemoryLayout<Int>.size)
        progressHandler?(0.9)
        
        // ANY ways to optimize pointcloud here?
        let pointCloud = SCNGeometry(sources: [positionSource, colorSource], elements: [elements])
        let pcNode = SCNNode(geometry: pointCloud)
        scene.rootNode.addChildNode(pcNode)
        
        scene.write(to: url,
                    options: nil,
                    delegate: nil) { (progress, error, _) in
            if let error = error { fatalError(error.localizedDescription) }
            progressHandler?(0.9 + Double(progress) / 10)
        }
    }
}
