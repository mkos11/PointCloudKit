//
//  MeshCaptureViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 15/12/2020.
//

import Combine
import RealityKit
import ARKit
import MetalKit


var textureCache: CVMetalTextureCache?

final class MeshCaptureViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var hideMeshButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var planeDetectionButton: UIButton!

    let coachingOverlay = ARCoachingOverlayView()

    
    // Cache for 3D text geometries representing the classification values.
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool { true }

    lazy var configuration: ARConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        return configuration
    }()

    private var nodes = [SCNNode]()

    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.session.delegate = self
        
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false

        arView.session.run(configuration)

        createTextureCache()
    }

    func createTextureCache() {
        var newTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MTLCreateSystemDefaultDevice()!, nil, &newTextureCache) == kCVReturnSuccess {
            textureCache = newTextureCache
        } else {
            assertionFailure("Unable to allocate texture cache")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        arView.session.run(configuration, options: [.removeExistingAnchors, .resetSceneReconstruction])
    }
    
    /// Places virtual-text of the classification at the touch-location's real-world intersection with a mesh.
    /// Note - because classification of the tapped-mesh is retrieved asynchronously, we visualize the intersection
    /// point immediately to give instant visual feedback of the tap.
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) {
        print("no")
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
    @IBAction func toggleMeshButtonPressed(_ button: UIButton) {
        let isShowingMesh = arView.debugOptions.contains(.showSceneUnderstanding)
        if isShowingMesh {
            arView.debugOptions.remove(.showSceneUnderstanding)
            button.setTitle("Show Mesh", for: [])
        } else {
            arView.debugOptions.insert(.showSceneUnderstanding)
            button.setTitle("Hide Mesh", for: [])
        }
    }
    
    /// - Tag: TogglePlaneDetection
    @IBAction func togglePlaneDetectionButtonPressed(_ button: UIButton) {
        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
            return
        }
        if configuration.planeDetection == [] {
            configuration.planeDetection = [.horizontal, .vertical]
            button.setTitle("Stop Plane Detection", for: [])
        } else {
            configuration.planeDetection = []
            button.setTitle("Start Plane Detection", for: [])
        }
        arView.session.run(configuration)
    }

    @IBAction func viewScenePressed(_ sender: Any) {
        navigateToScnViewer()
    }

    // Move to a viewModel/coordinator
    private func navigateToScnViewer() {
        guard let frame = arView.session.currentFrame else { return }
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        let viewModel = SCNViewerViewModel(meshAnchors: meshAnchors)
        let viewerViewController = SCNViewerViewController(viewModel: viewModel)
        navigationController?.pushViewController(viewerViewController, animated: true)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

@IBDesignable
class RoundedButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        backgroundColor = tintColor
        layer.cornerRadius = 8
        clipsToBounds = true
        setTitleColor(.white, for: [])
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }
    
    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? tintColor : .gray
        }
    }
}

import VideoToolbox

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let unwrapperCgImage = cgImage else {
            return nil
        }
        self.init(cgImage: unwrapperCgImage)
    }
}

extension ARMeshGeometry {
    func vertex(at index: Int) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * index))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
}

extension CVPixelBuffer {
    
    func mtlTexture(from: CVPixelBuffer, textureCache: CVMetalTextureCache) -> MTLTexture {
        var texture: MTLTexture!
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format: MTLPixelFormat = .bgra8Unorm
        var textureRef: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                               textureCache,
                                                               self,
                                                               nil,
                                                               format,
                                                               width,
                                                               height,
                                                               0,
                                                               &textureRef)
        if status == kCVReturnSuccess, let textureRef = textureRef {
            texture = CVMetalTextureGetTexture(textureRef)
        }
        return texture
    }
}

//
//extension MeshCaptureViewController {
//    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        guard let frame = arView.session.currentFrame else { return }
//
//        // Not working -- WIP
//        anchors.forEach { (meshAnchor) in
//            guard let arMeshAnchor = meshAnchor as? ARMeshAnchor else { return }
//
//            let geometry = arMeshAnchor.geometry
//            let size = frame.camera.imageResolution
//            let camera = frame.camera
//
//            let modelMatrix = arMeshAnchor.transform
//
//            var textureCoordinates = [CGPoint]()
//
//            for index in 0..<geometry.vertices.count {
//                let vertex = geometry.vertex(at: index)
//
//                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
//                let worlVertex4 = simd_mul(modelMatrix, vertex4)
//                let worldVector3 = simd_float3(x: worlVertex4.x, y: worlVertex4.y, z: worlVertex4.z)
//                let projectPoint = camera.projectPoint(worldVector3,
//                                             orientation: .portrait,
//                                             viewportSize: CGSize(
//                                                width: CGFloat(size.height),
//                                                height: CGFloat(size.width)))
//                let textureCoordinate = CGPoint(x: projectPoint.y / size.width, y: 1.0 - projectPoint.x / size.height)
//                textureCoordinates.append(textureCoordinate)
//            }
//
//            // construct your vertices, normals and faces from the source geometry directly and supply the computed texture coords to create new geometry and then apply the texture.
//
//            let verticesSource = SCNGeometrySource(geometry.vertices, semantic: .vertex)
//            let normalsSource = SCNGeometrySource(geometry.normals, semantic: .normal)
//            let textureSource = SCNGeometrySource(textureCoordinates: textureCoordinates)
//            let faces = SCNGeometryElement(geometry.faces)
//            let scnGeometry = SCNGeometry(sources: [verticesSource,
//                                                    textureSource,
//                                                    normalsSource],
//                                          elements: [faces])
//
//            let imageMaterial = SCNMaterial()
//            imageMaterial.fillMode = .fill
//            imageMaterial.isDoubleSided = false
//            imageMaterial.diffuse.contents = UIColor.red//frame.capturedImage.mtlTexture(from: frame.capturedImage, textureCache: textureCache!)
//            scnGeometry.materials = [imageMaterial]
//            nodes.append(SCNNode(geometry: scnGeometry))
//        }
//
//    }
//}
