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
    
    func generateScene() -> PassthroughSubject<SCNScene, Never>  {
        let sceneSubject = PassthroughSubject<SCNScene, Never>()
        DispatchQueue.init(label: "Renderer.SceneGeneration", qos: .background).async {
            let scene: SCNScene = self.generateScene()
            sceneSubject.send(scene)
        }
        return sceneSubject
    }
    
    private func generateScene() -> SCNScene {
        let scene = SCNScene()
        var vertices = [PointCloudVertex]()
        let confidenceRequierment = Float(confidenceThreshold) / 2.0
        
        for index in 0..<currentPointCount {
            let point = particlesBuffer[index]
            // Skip if below selected confidence (So that export reflect what's seen on screen)
            guard point.confidence >= confidenceRequierment else { continue}
            let vertex = PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z,
                                          r: point.color.x, g: point.color.y, b: point.color.z)
            vertices.append(vertex)
        }
        let vertexData = Data(bytes: &vertices, count: MemoryLayout<PointCloudVertex>.size * vertices.count)
        let positionSource = SCNGeometrySource(data: vertexData,
                                               semantic: SCNGeometrySource.Semantic.vertex,
                                               vectorCount: vertices.count,
                                               usesFloatComponents: true,
                                               componentsPerVector: 3,
                                               bytesPerComponent: MemoryLayout<Float>.size,
                                               dataOffset: 0,
                                               dataStride: MemoryLayout<PointCloudVertex>.size)
        let colorSource = SCNGeometrySource(data: vertexData,
                                            semantic: SCNGeometrySource.Semantic.color,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: MemoryLayout<Float>.size * 3,
                                            dataStride: MemoryLayout<PointCloudVertex>.size)
        let elements = SCNGeometryElement(data: nil,
                                          primitiveType: .point,
                                          primitiveCount: vertices.count,
                                          bytesPerIndex: MemoryLayout<Int>.size)
        
        // ANY ways to optimize pointcloud here?
        let pointCloud = SCNGeometry(sources: [positionSource, colorSource], elements: [elements])
        let pcNode = SCNNode(geometry: pointCloud)
        scene.rootNode.addChildNode(pcNode)
        return scene
    }
}
