//
//  PolygonFileFormat+Ascii.swift
//  Metra
//
//  Created by Alexandre Camilleri on 16/12/2020.
//

import Foundation

extension PolygonFileFormat {
    
    /// Generates a `Data` instance representing a PolygonFileFormat.
    /// - Returns: The `Data` representation of the PolygonFileFormat instance.
    ///
    /// Example file (remove {comments} from final file):
    ///
    /// ply
    /// format ascii 1.0           { ascii/binary, format version number }
    /// comment made by Greg Turk  { comments keyword specified, like all lines }
    /// comment this file is a cube
    /// element vertex 8           { define "vertex" element, 8 of them in file }
    /// property float x           { vertex contains float "x" coordinate }
    /// property float y           { y coordinate is also a vertex property }
    /// property float z           { z coordinate, too }
    /// element face 6             { there are 6 "face" elements in the file }
    /// property list uchar int vertex_index { "vertex_indices" is a list of ints }
    /// end_header                 { delimits the end of the header }
    /// 0 0 0                      { start of vertex list }
    /// 0 0 1
    /// 0 1 1
    /// 0 1 0
    /// 1 0 0
    /// 1 0 1
    /// 1 1 1
    /// 1 1 0
    /// 4 0 1 2 3                  { start of face list }
    /// 4 7 6 5 4
    /// 4 0 4 5 1
    /// 4 1 5 6 2
    /// 4 2 6 7 3
    /// 4 3 7 4 0
    ///
    func generateAscii() -> Data? {
        var header = [HeaderLine]()
        
        header.append(.start)
        header.append(.init(format: .ascii, version: "1.0"))
        // Add comments
        comments?.forEach({ (comment) in
            header.append(.init(comment: comment))
        })
        // Define Vertice property, if contains any
        if !vertices.isEmpty {
            header.append(.init(element: .vertex, count: vertices.count))
            header.append(.init(property: .positionX, type: .float))
            header.append(.init(property: .positionY, type: .float))
            header.append(.init(property: .positionZ, type: .float))
            header.append(.init(property: .redComponent, type: .uchar))
            header.append(.init(property: .greenComponent, type: .uchar))
            header.append(.init(property: .blueComponent, type: .uchar))
        }
        header.append(.end)
        
        var lines = [AsciiRepresentable]()
        
        lines.append(contentsOf: header)
        lines.append(contentsOf: vertices)
        
        return lines.joinedAsciiRepresentation().data(using: .ascii)
    }
}

private protocol AsciiRepresentable {
    var ascii: String { get }
}

extension Vertex: AsciiRepresentable {
    fileprivate var ascii: String { "\(x) \(y) \(z) \(r) \(g) \(b)" }
}

extension PolygonFileFormat.HeaderLine: AsciiRepresentable {
    fileprivate var ascii: String { "\(key) \(value ?? "")" }
}

extension Sequence where Iterator.Element == AsciiRepresentable {
    fileprivate func joinedAsciiRepresentation(separator: String = "\n") -> String {
        map { "\($0.ascii)" }.joined(separator: separator)
    }
}
