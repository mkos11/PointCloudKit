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
//
//    func generateScene(using nodes: [SCNNode]) -> Future<SCNScene, Never> {
//        Future<SCNScene, Never> { (promise) in
//            DispatchQueue.global(qos: .background).async {
//                promise(.success(SCNViewerViewModel.generateScene(using: nodes)))
//            }
//        }
//    }

    func generateScene(using vertices: [Vertex]) -> Future<SCNScene, Never> {
        Future<SCNScene, Never> { (promise) in
            DispatchQueue.global(qos: .background).async {
                promise(.success(SCNViewerViewModel.generateScene(using: vertices)))
            }
        }
    }

    func generateScene(using arMeshAnchors: [ARMeshAnchor]) -> Future<SCNScene, Never> {
        Future<SCNScene, Never> { (promise) in
            DispatchQueue.global(qos: .background).async {
                promise(.success(SCNViewerViewModel.generateScene(using: arMeshAnchors)))
            }
        }
    }

//    private static func generateScene(using nodes: [SCNNode]) -> SCNScene {
//        let scene = SCNScene()
//        nodes.forEach { (node) in
//            scene.rootNode.addChildNode(node)
//        }
//        return scene
//    }

    private static func generateScene(using vertices: [Vertex]) -> SCNScene {
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

    private static func generateScene(using arMeshAnchors: [ARMeshAnchor]) -> SCNScene {
        let scene = SCNScene()
        // convert anchors to a SCN Scene

        var lastNode: SCNNode = scene.rootNode
        arMeshAnchors.forEach { (meshAnchor) in
            guard meshAnchor.geometry.classificationOf(faceWithIndex: 0) != .none else { return }

            let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)
            let defaultMaterial = SCNMaterial()
//            defaultMaterial.fillMode = .fill
            defaultMaterial.diffuse.contents = meshAnchor.geometry.classificationOf(faceWithIndex: 0).color
            geometry.firstMaterial = defaultMaterial

            let newNode = SCNNode(geometry: geometry)
            lastNode.addChildNode(newNode)
            lastNode = newNode
        }
        return scene
    }
}
