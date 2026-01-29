import SceneKit
import AppKit

class ToolIconNode: SCNNode {
    private let yOffset: Float = 3.0
    private let iconSize: CGFloat = 1.5

    init(toolName: String) {
        super.init()
        setupIcon(toolName: toolName)
        position = SCNVector3(0, yOffset, 0)
        opacity = 0.0 // Start invisible for fade in
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupIcon(toolName: String) {
        let emoji = emojiForTool(toolName)

        // Create text geometry with emoji
        let textGeometry = SCNText(string: emoji, extrusionDepth: 0.05)
        textGeometry.font = NSFont.systemFont(ofSize: 48) // Large for better visibility

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.lightingModel = .constant
        textGeometry.materials = [material]

        let textNode = SCNNode(geometry: textGeometry)

        // Center the text
        let (min, max) = textNode.boundingBox
        let width = max.x - min.x
        let height = max.y - min.y
        textNode.position = SCNVector3(-width / 2, -height / 2, 0)

        // Scale to target size
        let maxDimension = Swift.max(width, height)
        let scale = Float(iconSize) / Float(maxDimension)
        textNode.scale = SCNVector3(scale, scale, scale)

        addChildNode(textNode)

        // Billboard constraint to always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y]
        constraints = [billboardConstraint]

        // Add gentle rotation animation
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 3.0)
        let rotateForever = SCNAction.repeatForever(rotateAction)
        runAction(rotateForever, forKey: "rotate")

        // Add gentle bob animation
        let bobUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 0.8)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: 0.8)
        bobDown.timingMode = .easeInEaseOut
        let bobSequence = SCNAction.sequence([bobUp, bobDown])
        let bobForever = SCNAction.repeatForever(bobSequence)
        runAction(bobForever, forKey: "bob")
    }

    private func emojiForTool(_ toolName: String) -> String {
        switch toolName.lowercased() {
        case "read":
            return "📖"
        case "write":
            return "✏️"
        case "edit":
            return "🔧"
        case "bash":
            return "⚡"
        case "grep":
            return "🔍"
        case "glob":
            return "📁"
        default:
            return "🔨" // Default tool icon
        }
    }

    // MARK: - Animations

    func fadeIn(duration: TimeInterval = 0.3) {
        let fadeAction = SCNAction.fadeIn(duration: duration)
        runAction(fadeAction)
    }

    func fadeOut(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        let fadeAction = SCNAction.fadeOut(duration: duration)
        runAction(fadeAction) {
            completion?()
        }
    }
}
