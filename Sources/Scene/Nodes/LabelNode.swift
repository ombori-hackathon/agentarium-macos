import SceneKit

class LabelNode: SCNNode {
    init(text: String, yOffset: Float = 1.0) {
        super.init()

        // Create 3D text geometry
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        textGeometry.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular) // SF Mono, 12pt
        textGeometry.flatness = 0.1

        // Green material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0, green: 1, blue: 0x88/255.0, alpha: 1.0) // #00ff88
        material.lightingModel = .constant
        textGeometry.materials = [material]

        // Create node with text
        let textNode = SCNNode(geometry: textGeometry)

        // Center the text horizontally
        let (min, max) = textGeometry.boundingBox
        let width = max.x - min.x
        textNode.position = SCNVector3(-width / 2, 0, 0)

        // Add text node as child
        addChildNode(textNode)

        // Position above folder
        position = SCNVector3(0, yOffset, 0)

        // Billboard constraint - always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y] // Only rotate around Y axis
        constraints = [billboardConstraint]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
