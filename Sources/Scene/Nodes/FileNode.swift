import SceneKit

class FileNode: SCNNode {
    init(file: File) {
        super.init()

        // Position from API
        position = SCNVector3(
            Float(file.position.x),
            Float(file.position.y),
            Float(file.position.z)
        )

        // Small cube
        let cube = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0)

        // Green at 60% opacity
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0, green: 1, blue: 0x88/255.0, alpha: 0.6) // #00ff88 at 60%
        material.lightingModel = .blinn
        material.transparency = 0.6

        cube.materials = [material]

        geometry = cube
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
