import SceneKit

class AgentNode: SCNNode {
    private var bodyNode: SCNNode!
    private var legNodes: [SCNNode] = []
    private var glowNode: SCNNode!
    private var thoughtBubble: ThoughtBubbleNode?
    private var toolIcon: ToolIconNode?

    private var isWalking = false
    private var isIdling = false

    init(color: String = "#e07850") {
        super.init()

        // Parse color
        let nsColor = parseColor(color)
        let darkerColor = darkenColor(nsColor, factor: 0.8)

        setupBody(color: nsColor)
        setupEyes()
        setupLegs(color: darkerColor)
        setupGlow(color: nsColor)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupBody(color: NSColor) {
        // Body: 4W × 3H × 3D with rounded corners
        let body = SCNBox(width: 4.0, height: 3.0, length: 3.0, chamferRadius: 0.4)

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.2)
        material.lightingModel = .physicallyBased

        body.materials = [material]

        bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 1.5 + 0.6, 0) // Half body height + leg height
        addChildNode(bodyNode)
    }

    private func setupEyes() {
        // Two square eyes on front face
        let eyeGeometry = SCNBox(width: 0.7, height: 0.7, length: 0.1, chamferRadius: 0.05)

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.black
        material.lightingModel = .constant

        eyeGeometry.materials = [material]

        // Left eye
        let leftEye = SCNNode(geometry: eyeGeometry)
        leftEye.position = SCNVector3(-0.4, 0.5, 1.5) // Upper third, left side
        bodyNode.addChildNode(leftEye)

        // Right eye
        let rightEye = SCNNode(geometry: eyeGeometry)
        rightEye.position = SCNVector3(0.4, 0.5, 1.5) // Upper third, right side
        bodyNode.addChildNode(rightEye)
    }

    private func setupLegs(color: NSColor) {
        // 4 stubby legs at corners
        let legGeometry = SCNBox(width: 0.6, height: 1.2, length: 0.6, chamferRadius: 0.1)

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased

        legGeometry.materials = [material]

        // Leg positions: 4 corners, inset 0.3 from body edges
        let inset: Float = 1.7 // (4.0/2 - 0.3)
        let legY: Float = 0.6 // Half leg height

        let positions = [
            SCNVector3(-inset, legY, -1.2),  // Front left
            SCNVector3(inset, legY, -1.2),   // Front right
            SCNVector3(-inset, legY, 1.2),   // Back left
            SCNVector3(inset, legY, 1.2)     // Back right
        ]

        for position in positions {
            let leg = SCNNode(geometry: legGeometry)
            leg.position = position
            addChildNode(leg)
            legNodes.append(leg)
        }
    }

    private func setupGlow(color: NSColor) {
        // Circular plane beneath agent
        let glowGeometry = SCNPlane(width: 6.0, height: 6.0)
        glowGeometry.cornerRadius = 3.0

        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.3)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.blendMode = .add

        glowGeometry.materials = [material]

        glowNode = SCNNode(geometry: glowGeometry)
        glowNode.position = SCNVector3(0, 0.1, 0)
        glowNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // Rotate to lie flat
        addChildNode(glowNode)
    }

    // MARK: - Animations

    func startWalkAnimation() {
        guard !isWalking else { return }
        isWalking = true
        stopIdleAnimation()

        // Body bob: Y oscillates ±0.2 over 0.3s
        let bobUp = SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.15)
        let bobDown = SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.15)
        let bobSequence = SCNAction.sequence([bobUp, bobDown])
        let bobRepeat = SCNAction.repeatForever(bobSequence)
        bodyNode.runAction(bobRepeat, forKey: "walk_bob")

        // Leg cycle: Alternate pairs move up/down ±0.3
        let legUp = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.15)
        let legDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.15)
        let legSequence1 = SCNAction.sequence([legUp, legDown])
        let legSequence2 = SCNAction.sequence([legDown, legUp])
        let legRepeat = SCNAction.repeatForever(legSequence1)

        // Front-left and back-right move together
        legNodes[0].runAction(legRepeat, forKey: "walk_leg")
        legNodes[3].runAction(legRepeat, forKey: "walk_leg")

        // Front-right and back-left move together (opposite phase)
        let legRepeatAlt = SCNAction.repeatForever(legSequence2)
        legNodes[1].runAction(legRepeatAlt, forKey: "walk_leg")
        legNodes[2].runAction(legRepeatAlt, forKey: "walk_leg")
    }

    func stopWalkAnimation() {
        guard isWalking else { return }
        isWalking = false

        bodyNode.removeAction(forKey: "walk_bob")
        legNodes.forEach { $0.removeAction(forKey: "walk_leg") }

        // Reset positions smoothly
        let resetBodyAction = SCNAction.move(to: SCNVector3(0, 1.5 + 0.6, 0), duration: 0.1)
        bodyNode.runAction(resetBodyAction)

        for (index, leg) in legNodes.enumerated() {
            let inset: Float = 1.7
            let legY: Float = 0.6
            let positions = [
                SCNVector3(-inset, legY, -1.2),
                SCNVector3(inset, legY, -1.2),
                SCNVector3(-inset, legY, 1.2),
                SCNVector3(inset, legY, 1.2)
            ]
            leg.runAction(SCNAction.move(to: positions[index], duration: 0.1))
        }

        startIdleAnimation()
    }

    func startIdleAnimation() {
        guard !isIdling && !isWalking else { return }
        isIdling = true

        // Breathing: Scale pulses 1.0 → 1.02 → 1.0 over 2s
        let scaleUp = SCNAction.scale(to: 1.02, duration: 1.0)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SCNAction.scale(to: 1.0, duration: 1.0)
        scaleDown.timingMode = .easeInEaseOut
        let breathSequence = SCNAction.sequence([scaleUp, scaleDown])
        let breathRepeat = SCNAction.repeatForever(breathSequence)
        bodyNode.runAction(breathRepeat, forKey: "idle_breath")
    }

    func stopIdleAnimation() {
        guard isIdling else { return }
        isIdling = false

        bodyNode.removeAction(forKey: "idle_breath")
        bodyNode.scale = SCNVector3(1, 1, 1)
    }

    // MARK: - Movement

    func moveTo(position: SCNVector3, duration: TimeInterval, completion: (() -> Void)? = nil) {
        startWalkAnimation()

        let moveAction = SCNAction.move(to: position, duration: duration)
        moveAction.timingMode = .easeInEaseOut

        runAction(moveAction) {
            self.stopWalkAnimation()
            completion?()
        }
    }

    // MARK: - Thought Bubble

    func updateThought(_ text: String) {
        if thoughtBubble == nil {
            thoughtBubble = ThoughtBubbleNode(text: text)
            addChildNode(thoughtBubble!)
        } else {
            thoughtBubble?.updateText(text)
        }
    }

    func clearThought() {
        thoughtBubble?.fadeOut()
        thoughtBubble = nil
    }

    // MARK: - Tool Icon

    func showToolIcon(_ toolName: String) {
        // Remove existing icon
        toolIcon?.removeFromParentNode()

        // Create new icon
        toolIcon = ToolIconNode(toolName: toolName)
        addChildNode(toolIcon!)
        toolIcon?.fadeIn()
    }

    func hideToolIcon() {
        toolIcon?.fadeOut {
            self.toolIcon?.removeFromParentNode()
            self.toolIcon = nil
        }
    }

    // MARK: - Helpers

    private func parseColor(_ hexString: String) -> NSColor {
        var hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0

        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func darkenColor(_ color: NSColor, factor: CGFloat) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }
        return NSColor(
            red: rgb.redComponent * factor,
            green: rgb.greenComponent * factor,
            blue: rgb.blueComponent * factor,
            alpha: rgb.alphaComponent
        )
    }
}
