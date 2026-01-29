import SceneKit

class FolderNode: SCNNode {
    let folderName: String
    let folderPath: String
    private var pyramidNode: SCNNode!
    private var defaultMaterial: SCNMaterial!
    private var highlightedMaterial: SCNMaterial!

    init(folder: FolderInfo) {
        self.folderName = folder.name
        self.folderPath = folder.path
        super.init()

        // Position from API (use origin if not provided)
        if let pos = folder.position {
            position = SCNVector3(Float(pos.x), Float(pos.y), Float(pos.z))
        } else {
            position = SCNVector3(0, 0, 0)
        }

        // Store name and path in node for tooltip access
        name = "\(folder.name)|\(folder.path)"

        // Base size scales with file count
        let baseSize = Float(2.0 + log(Double(folder.fileCount + 1)))
        let height = Float(folder.height ?? 3.0)

        // Create wireframe pyramid
        pyramidNode = createWireframePyramid(baseSize: baseSize, height: height)
        addChildNode(pyramidNode)

        // Setup highlight materials
        setupMaterials()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createWireframePyramid(baseSize: Float, height: Float) -> SCNNode {
        let halfBase = baseSize / 2.0

        // Pyramid vertices
        // Base corners
        let v0 = SCNVector3(-halfBase, 0, -halfBase)
        let v1 = SCNVector3(halfBase, 0, -halfBase)
        let v2 = SCNVector3(halfBase, 0, halfBase)
        let v3 = SCNVector3(-halfBase, 0, halfBase)
        // Apex
        let v4 = SCNVector3(0, height, 0)

        // Define edges as line segments
        let vertices = [v0, v1, v2, v3, v4]
        let indices: [Int32] = [
            // Base square
            0, 1,
            1, 2,
            2, 3,
            3, 0,
            // Edges to apex
            0, 4,
            1, 4,
            2, 4,
            3, 4,
        ]

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )

        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

        // Green glow material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0, green: 1, blue: 0x88 / 255.0, alpha: 1.0)  // #00ff88
        material.emission.contents = NSColor(red: 0, green: 1, blue: 0x88 / 255.0, alpha: 0.3)
        material.lightingModel = .constant
        material.isDoubleSided = true

        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }

    private func setupMaterials() {
        // Default material (existing)
        defaultMaterial = pyramidNode.geometry?.firstMaterial ?? SCNMaterial()

        // Highlighted material (brighter emission)
        highlightedMaterial = SCNMaterial()
        highlightedMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.9)
        highlightedMaterial.emission.contents = NSColor(red: 0.3, green: 1.0, blue: 0.6, alpha: 0.8)
        highlightedMaterial.lightingModel = .constant
        highlightedMaterial.isDoubleSided = true
        highlightedMaterial.transparency = 0.85
    }

    func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
        let target = highlighted ? highlightedMaterial! : defaultMaterial!
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            pyramidNode.geometry?.materials = [target]
            SCNTransaction.commit()
        } else {
            pyramidNode.geometry?.materials = [target]
        }
    }
}
