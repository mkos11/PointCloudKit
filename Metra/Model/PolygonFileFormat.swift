//
//  PolygonFileFormat.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation

/// Represents the .PLY format - http://paulbourke.net/dataformats/ply/
struct PolygonFileFormat {
    
    public struct HeaderLine {
        let key: String
        let value: String?
        
        static let start = HeaderLine(key: Keyword.start)
        static let end = HeaderLine(key: Keyword.end)
        
        private init(key: Keyword, value: String? = nil) {
            self.key = key.rawValue
            self.value = value
        }
        
        init(format: Format, version: String) {
            key = Keyword.format.rawValue
            value = "\(format) \(version)"
        }
        
        init(comment: String) {
            key = Keyword.comment.rawValue
            value = "\(comment)"
        }
        
        init(element: Element, count: Int) {
            key = "\(Keyword.element)"
            value = "\(element) \(count)"
        }
        
        init(property: Property, type: PropertyType) {
            key = "\(Keyword.property)"
            value = "\(property) \(type)"
        }
    }
    
    enum Keyword: String {
        case start = "ply", end = "end_header"
        case format, comment, element, property
    }
    
    enum Element: String {
        case vertex
        //        case Face
        //        case Edge
    }
    
    enum Format: String {
        case ascii
        //        case bin
    }
    
    enum Property: String {
        case positionX = "x", positionY = "y", positionZ = "z"
        case redComponent = "red", greenComponent = "green", blueComponent = "blue"
    }
    
    enum PropertyType: String {
        case float, uchar
    }
    
    let vertices: [Vertex]
    //    let faces: [Face]
    //    let edges: [Edge]
    let comments: [String]?
    
    init(vertices: [Vertex], comments: [String]? = nil) {
        self.vertices = vertices
        self.comments = comments
    }
}
