/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Type-safe utility for working with MTLBuffers.
 */

import MetalKit

protocol Resource {
    associatedtype Element
}

/// A wrapper around MTLBuffer which provides type safe access and assignment to the underlying MTLBuffer's contents.

struct MetalBuffer<Element>: Resource {

    /// The underlying MTLBuffer.
    fileprivate let buffer: MTLBuffer

    /// The index that the buffer should be bound to during encoding.
    /// Should correspond with the index that the buffer is expected to be at in Metal shaders.
    fileprivate let index: Int

    /// The number of elements of T the buffer can hold.
    let count: Int
    var stride: Int {
        MemoryLayout<Element>.stride
    }
    
    var rawMtlBuffer: MTLBuffer {
        return buffer
    }

    /// Initializes the buffer with zeros, the buffer is given an appropriate length based on the provided element count.
    init(device: MTLDevice, count: Int, index: UInt32, label: String? = nil, options: MTLResourceOptions = []) {
        // Maybe need to add a .storageModeShared to sync between GPU and CPU if cannot do GPU -> GPU between Metal and OpenGL
        guard let buffer = device.makeBuffer(length: MemoryLayout<Element>.stride * count, options: options) else {
            fatalError("Failed to create MTLBuffer.")
        }
        self.buffer = buffer
        self.buffer.label = label
        self.count = count
        self.index = Int(index)
    }

    /// Initializes the buffer with the contents of the provided array.
    init(device: MTLDevice, array: [Element], index: UInt32, options: MTLResourceOptions = []) {

        guard let buffer = device.makeBuffer(bytes: array, length: MemoryLayout<Element>.stride * array.count, options: .storageModeShared) else {
            fatalError("Failed to create MTLBuffer")
        }
        self.buffer = buffer
        self.count = array.count
        self.index = Int(index)
    }

    /// Replaces the buffer's memory at the specified element index with the provided value.
    func assign<T>(_ value: T, at index: Int = 0) {
        precondition(index <= count - 1, "Index \(index) is greater than maximum allowable index of \(count - 1) for this buffer.")
        withUnsafePointer(to: value) {
            buffer.contents().advanced(by: index * stride).copyMemory(from: $0, byteCount: stride)
        }
    }

    /// Replaces the buffer's memory with the values in the array.
    func assign<Element>(with array: [Element]) {
        let byteCount = array.count * stride
        precondition(byteCount == buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        buffer.contents().copyMemory(from: array, byteCount: byteCount)
    }

    /// Returns a copy of the value at the specified element index in the buffer.
    subscript(index: Int) -> Element {
        get {
            precondition(stride * index <= buffer.length - stride, "This buffer is not large enough to have an element at the index: \(index)")
            return buffer.contents().advanced(by: index * stride).load(as: Element.self)
        }

        set {
            assign(newValue, at: index)
        }
    }

}

// Note: This extension is in this file because access to Buffer<T>.buffer is fileprivate.
// Access to Buffer<T>.buffer was made fileprivate to ensure that only this file can touch the underlying MTLBuffer.
extension MTLRenderCommandEncoder {
    func setVertexBuffer<T>(_ vertexBuffer: MetalBuffer<T>, offset: Int = 0) {
        setVertexBuffer(vertexBuffer.buffer, offset: offset, index: vertexBuffer.index)
    }

    func setFragmentBuffer<T>(_ fragmentBuffer: MetalBuffer<T>, offset: Int = 0) {
        setFragmentBuffer(fragmentBuffer.buffer, offset: offset, index: fragmentBuffer.index)
    }

    func setVertexResource<R: Resource>(_ resource: R) {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setVertexBuffer(buffer)
        }

        if let texture = resource as? Texture {
            setVertexTexture(texture.texture, index: texture.index)
        }
    }

    func setFragmentResource<R: Resource>(_ resource: R) {
        if let buffer = resource as? MetalBuffer<R.Element> {
            setFragmentBuffer(buffer)
        }

        if let texture = resource as? Texture {
            setFragmentTexture(texture.texture, index: texture.index)
        }
    }
}

struct Texture: Resource {
    typealias Element = Any

    let texture: MTLTexture
    let index: Int
}

// MARK: - C compatible -- see https://stackoverflow.com/questions/63606753/reading-contents-from-a-generic-mtlbuffer

// MARK: Convenience
typealias MTLCStructMemberFormat = MTLVertexFormat

@_functionBuilder
struct ArrayLayout { static func buildBlock<T>(_ arr: T...) -> [T] { arr } }

extension MTLCStructMemberFormat {
    var stride: Int {
        switch self {
        case .float2:  return MemoryLayout<simd_float2>.stride
        case .float3:  return MemoryLayout<simd_float3>.stride
        default:       fatalError("Case unaccounted for")
        }
    }
}

// MARK: Custom Protocol
protocol CMetalStruct {
    /// Returns the type of the `ith` member
    static var memoryLayouts: [MTLCStructMemberFormat] { get }
}

extension MetalBuffer where Element: CMetalStruct {
    func readBufferContents<T>(elementPositionInArray index: Int, memberID: Int, expectedType type: T.Type = T.self)
        -> T {
        let pointerAddition = index * MemoryLayout<Element>.stride
            let valueToIncrement = Element.memoryLayouts[0..<memberID].reduce(0) { $0 + $1.stride }
        return buffer.contents().advanced(by: pointerAddition + valueToIncrement).bindMemory(to: T.self, capacity: 1).pointee
    }
    
    func extractMembers<T>(memberID: Int, expectedType type: T.Type = T.self, upperBound: Int = 0) -> [T] {
        var array: [T] = []
        let endIndex = upperBound == 0 ? count : upperBound
        for index in 0..<endIndex {
            let pointerAddition = index * MemoryLayout<Element>.stride
            let valueToIncrement = Element.memoryLayouts[0..<memberID].reduce(0) { $0 + $1.stride }
            let contents = buffer.contents().advanced(by: pointerAddition + valueToIncrement).bindMemory(to: T.self, capacity: 1).pointee
            array.append(contents)
        }
        
        return array
    }
}

extension ParticleUniforms: CMetalStruct {
    @ArrayLayout static var memoryLayouts: [MTLCStructMemberFormat] {
        MTLCStructMemberFormat.float3
        MTLCStructMemberFormat.float3
    }
}

//var CTypes = [CustomC(testA: .init(59, 99, 0), testB: .init(102, 111, 52)), CustomC(testA: .init(10, 11, 5), testB: .one), CustomC(testA: .zero, testB: .init(5, 5, 5))]
//
//let allocator = CustomBufferAllocator<CustomC>(bytes: &CTypes, count: 3)
//let value = allocator.readBufferContents(element_position_in_array: 1, memberID: 0, expectedType: simd_float3.self)
//print(value)
//
//// Prints SIMD3<Float>(10.0, 11.0, 5.0)
//
//let group = allocator.extractMembers(memberID: 1, expectedType: simd_float3.self)
//print(group)
//
//// Prints [SIMD3<Float>(102.0, 111.0, 52.0), SIMD3<Float>(1.0, 1.0, 1.0), SIMD3<Float>(5.0, 5.0, 5.0)]
