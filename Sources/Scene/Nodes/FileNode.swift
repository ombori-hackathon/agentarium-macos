import SceneKit

class FileNode: SCNNode {
    let fileName: String
    let filePath: String
    private var defaultMaterial: SCNMaterial!
    private var highlightedMaterial: SCNMaterial!

    init(file: FileInfo) {
        self.fileName = file.name
        self.filePath = file.path
        super.init()

        // Position from API (use origin if not provided)
        if let pos = file.position {
            position = SCNVector3(Float(pos.x), Float(pos.y), Float(pos.z))
        } else {
            position = SCNVector3(0, 0, 0)
        }

        // Store name and path in node for tooltip access
        name = "\(file.name)|\(file.path)"

        // Small cube
        let cube = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0)

        // Green at 60% opacity
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0, green: 1, blue: 0x88 / 255.0, alpha: 0.6)  // #00ff88 at 60%
        material.lightingModel = .blinn
        material.transparency = 0.6

        cube.materials = [material]

        geometry = cube

        // Setup highlight materials
        setupMaterials()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMaterials() {
        // Default material (existing)
        defaultMaterial = geometry?.firstMaterial ?? SCNMaterial()

        // Highlighted material (brighter emission)
        highlightedMaterial = SCNMaterial()
        highlightedMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.9)
        highlightedMaterial.emission.contents = NSColor(red: 0.3, green: 1.0, blue: 0.6, alpha: 0.8)
        highlightedMaterial.lightingModel = .blinn
        highlightedMaterial.transparency = 0.85
    }

    func setHighlighted(_ highlighted: Bool, animated: Bool = true) {
        let target = highlighted ? highlightedMaterial! : defaultMaterial!
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            geometry?.materials = [target]
            SCNTransaction.commit()
        } else {
            geometry?.materials = [target]
        }
    }
}
