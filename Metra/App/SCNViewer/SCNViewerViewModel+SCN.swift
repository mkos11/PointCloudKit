//
//  SCNViewerViewModel+SCN.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Metal
import MetalKit
import ARKit
import Combine

extension SCNViewerViewModel {

    func generateScene() -> PassthroughSubject<SCNScene, Never> {
        let sceneSubject = PassthroughSubject<SCNScene, Never>()
        DispatchQueue.global(qos: .background).async {
            let scene = self.generateScene(from: self.vertices)
            sceneSubject.send(scene)
        }
        return sceneSubject
    }

    private func generateScene(from vertices: [Vertex]) -> SCNScene {
        let scene = SCNScene()
        let vertexData = Data(bytes: vertices, count: MemoryLayout<Vertex>.size * vertices.count)
        let positionSource = SCNGeometrySource(data: vertexData,
                                               semantic: SCNGeometrySource.Semantic.vertex,
                                               vectorCount: vertices.count,
                                               usesFloatComponents: true,
                                               componentsPerVector: 3,
                                               bytesPerComponent: MemoryLayout<Float>.size,
                                               dataOffset: 0,
                                               dataStride: MemoryLayout<Vertex>.size)
        let colorSource = SCNGeometrySource(data: vertexData,
                                            semantic: SCNGeometrySource.Semantic.color,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: MemoryLayout<Float>.size * 3,
                                            dataStride: MemoryLayout<Vertex>.size)
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
