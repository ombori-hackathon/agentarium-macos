@preconcurrency import SceneKit

class AgentNode: SCNNode {
    private var bodyNode: SCNNode!
    private var legNodes: [SCNNode] = []
    private var armNodes: [SCNNode] = []
    private var glowNode: SCNNode!
    private var thoughtBubble: ThoughtBubbleNode?
    private var toolIcon: ToolIconNode?
    private var pathLabel: LabelNode?

    private var isWalking = false
    private var isIdling = false

    // Movement state
    private var isMoving = false

    init(color: String = "#c08060") {
        super.init()

        // Parse color - using warmer terracotta like the pixel art
        let nsColor = parseColor(color)
        let darkerColor = darkenColor(nsColor, factor: 0.75)

        setupBody(color: nsColor)
        setupEyes()
        setupArms(color: darkerColor)
        setupLegs(color: darkerColor)
        setupGlow(color: nsColor)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupBody(color: NSColor) {
        // Body: Rectangular box like pixel art mascot
        // Dimensions: 1.4W × 1.0H × 0.8D with minimal chamfer for blocky look
        let body = SCNBox(width: 1.4, height: 1.0, length: 0.8, chamferRadius: 0.05)

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.15)
        material.lightingModel = .physicallyBased

        body.materials = [material]

        bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.5 + 0.3, 0)  // Half body height + leg height
        addChildNode(bodyNode)
    }

    private func setupEyes() {
        // Two small square eyes like pixel art
        let eyeGeometry = SCNBox(width: 0.15, height: 0.15, length: 0.05, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.black
        material.lightingModel = .constant

        eyeGeometry.materials = [material]

        // Left eye - positioned in upper area of face
        let leftEye = SCNNode(geometry: eyeGeometry)
        leftEye.position = SCNVector3(-0.25, 0.2, 0.41)  // Upper area, slightly left
        bodyNode.addChildNode(leftEye)

        // Right eye
        let rightEye = SCNNode(geometry: eyeGeometry)
        rightEye.position = SCNVector3(0.25, 0.2, 0.41)  // Upper area, slightly right
        bodyNode.addChildNode(rightEye)
    }

    private func setupArms(color: NSColor) {
        // Two tiny arm stubs on the sides like pixel art
        let armGeometry = SCNBox(width: 0.15, height: 0.25, length: 0.2, chamferRadius: 0.02)

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased

        armGeometry.materials = [material]

        // Left arm - sticks out from left side at mid-height
        let leftArm = SCNNode(geometry: armGeometry)
        leftArm.position = SCNVector3(-0.775, 0, 0)  // Just outside body width
        bodyNode.addChildNode(leftArm)
        armNodes.append(leftArm)

        // Right arm - sticks out from right side
        let rightArm = SCNNode(geometry: armGeometry)
        rightArm.position = SCNVector3(0.775, 0, 0)
        bodyNode.addChildNode(rightArm)
        armNodes.append(rightArm)
    }

    private func setupLegs(color: NSColor) {
        // Two small feet at bottom like pixel art
        let legGeometry = SCNBox(width: 0.2, height: 0.15, length: 0.25, chamferRadius: 0.02)

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased

        legGeometry.materials = [material]

        // Two feet positioned at bottom, slightly apart
        let legY: Float = 0.075  // Half leg height (very short feet)
        let legSpacing: Float = 0.35  // Distance from center

        let positions = [
            SCNVector3(-legSpacing, legY, 0),  // Left foot
            SCNVector3(legSpacing, legY, 0),  // Right foot
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
        let glowGeometry = SCNPlane(width: 2.0, height: 2.0)
        glowGeometry.cornerRadius = 1.0

        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.3)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.blendMode = .add

        glowGeometry.materials = [material]

        glowNode = SCNNode(geometry: glowGeometry)
        glowNode.position = SCNVector3(0, 0.05, 0)
        glowNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)  // Rotate to lie flat
        addChildNode(glowNode)
    }

    // MARK: - Animations

    func startWalkAnimation() {
        guard !isWalking else { return }
        isWalking = true
        stopIdleAnimation()

        // Body bob: Y oscillates ±0.08 over 0.3s
        let bobUp = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.15)
        let bobDown = SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.15)
        let bobSequence = SCNAction.sequence([bobUp, bobDown])
        let bobRepeat = SCNAction.repeatForever(bobSequence)
        bodyNode.runAction(bobRepeat, forKey: "walk_bob")

        // Leg cycle: Alternate feet move up/down ±0.08
        let legUp = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.15)
        let legDown = SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.15)
        let legSequence1 = SCNAction.sequence([legUp, legDown])
        let legSequence2 = SCNAction.sequence([legDown, legUp])

        // Left and right feet alternate
        legNodes[0].runAction(SCNAction.repeatForever(legSequence1), forKey: "walk_leg")
        legNodes[1].runAction(SCNAction.repeatForever(legSequence2), forKey: "walk_leg")
    }

    func stopWalkAnimation() {
        guard isWalking else { return }
        isWalking = false

        bodyNode.removeAction(forKey: "walk_bob")
        legNodes.forEach { $0.removeAction(forKey: "walk_leg") }

        // Reset positions smoothly
        let resetBodyAction = SCNAction.move(to: SCNVector3(0, 0.5 + 0.3, 0), duration: 0.1)
        bodyNode.runAction(resetBodyAction)

        // Reset foot positions
        let legY: Float = 0.075
        let legSpacing: Float = 0.35
        let positions = [
            SCNVector3(-legSpacing, legY, 0),  // Left foot
            SCNVector3(legSpacing, legY, 0),  // Right foot
        ]

        for (index, leg) in legNodes.enumerated() {
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

    func moveTo(position: SCNVector3, duration: TimeInterval = 0, completion: (() -> Void)? = nil) {
        // Cancel any in-progress movement - skip to latest target
        removeAction(forKey: "agent_move")

        // Calculate duration based on distance if not provided
        let finalDuration: TimeInterval
        if duration > 0 {
            finalDuration = duration
        } else {
            let distance = self.position.distance(to: position)
            let speed: Float = 10.0  // units per second
            var calculatedDuration = TimeInterval(distance / speed)
            calculatedDuration = max(0.2, min(calculatedDuration, 1.5))  // Faster response
            finalDuration = calculatedDuration
        }

        // Start moving
        isMoving = true
        startWalkAnimation()

        let moveAction = SCNAction.move(to: position, duration: finalDuration)
        moveAction.timingMode = .easeInEaseOut

        runAction(moveAction, forKey: "agent_move") { [weak self] in
            self?.stopWalkAnimation()
            self?.isMoving = false
            completion?()
        }
    }

    // MARK: - File Path Label

    func updateFilePath(_ path: String?) {
        if let path = path {
            if pathLabel == nil {
                pathLabel = LabelNode(text: path)
                pathLabel?.position = SCNVector3(0, -0.5, 0)  // Below agent (adjusted for smaller size)
                addChildNode(pathLabel!)
            } else {
                pathLabel?.updateText(path)
            }
        } else {
            pathLabel?.removeFromParentNode()
            pathLabel = nil
        }
    }

    // MARK: - Despawn

    func despawn(completion: (() -> Void)? = nil) {
        let fadeOut = SCNAction.fadeOut(duration: 0.5)
        let remove = SCNAction.removeFromParentNode()
        runAction(SCNAction.sequence([fadeOut, remove])) {
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

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    func distance(to other: SCNVector3) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        let dxSquared = dx * dx
        let dySquared = dy * dy
        let dzSquared = dz * dz
        let sum = dxSquared + dySquared + dzSquared
        return Float(sqrt(Double(sum)))
    }
}
