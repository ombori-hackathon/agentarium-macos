import SceneKit

class LabelNode: SCNNode {
    private var textNode: SCNNode!
    private let initialYOffset: Float

    init(text: String, yOffset: Float = 1.0, fontSize: CGFloat = 12) {
        self.initialYOffset = yOffset
        super.init()

        setupText(text, fontSize: fontSize)
        position = SCNVector3(0, yOffset, 0)

        // Billboard constraint - always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y]  // Only rotate around Y axis
        constraints = [billboardConstraint]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupText(_ text: String, fontSize: CGFloat = 12) {
        // Remove existing text node if any
        textNode?.removeFromParentNode()

        // Create 3D text geometry
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        textGeometry.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)  // SF Mono
        textGeometry.flatness = 0.1

        // Green material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0, green: 1, blue: 0x88 / 255.0, alpha: 1.0)  // #00ff88
        material.lightingModel = .constant
        textGeometry.materials = [material]

        // Create node with text
        textNode = SCNNode(geometry: textGeometry)

        // Center the text horizontally
        let (min, max) = textGeometry.boundingBox
        let width = max.x - min.x
        textNode.position = SCNVector3(-width / 2, 0, 0)

        // Add text node as child
        addChildNode(textNode)
    }

    func updateText(_ text: String) {
        setupText(text)
    }
}
