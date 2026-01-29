import AppKit
@preconcurrency import SceneKit

class ThoughtBubbleNode: SCNNode {
    private var backgroundNode: SCNNode!
    private var textNode: SCNNode!
    private var fadeTimer: Timer?

    private let maxWidth: CGFloat = 200
    private let padding: CGFloat = 12
    private let yOffset: Float = 2.8  // Adjusted for smaller mascot-style agent

    init(text: String) {
        super.init()
        setupBubble(with: text)
        position = SCNVector3(0, yOffset, 0)
        scheduleAutoFade()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupBubble(with text: String) {
        // Create text geometry
        let attributedString = createAttributedString(text)
        let textGeometry = SCNText(string: attributedString, extrusionDepth: 0.1)

        let material = SCNMaterial()
        material.diffuse.contents = NSColor.darkGray
        material.lightingModel = .constant
        textGeometry.materials = [material]

        textNode = SCNNode(geometry: textGeometry)

        // Calculate text bounds
        let (min, max) = textNode.boundingBox
        let textWidth = CGFloat(max.x - min.x)
        let textHeight = CGFloat(max.y - min.y)

        // Create background rounded rectangle
        let bgWidth = textWidth + padding * 2
        let bgHeight = textHeight + padding * 2

        let backgroundGeometry = SCNPlane(width: bgWidth, height: bgHeight)
        backgroundGeometry.cornerRadius = bgHeight / 6

        let bgMaterial = SCNMaterial()
        bgMaterial.diffuse.contents = NSColor.white.withAlphaComponent(0.9)
        bgMaterial.lightingModel = .constant
        bgMaterial.isDoubleSided = true
        backgroundGeometry.materials = [bgMaterial]

        backgroundNode = SCNNode(geometry: backgroundGeometry)
        backgroundNode.position = SCNVector3(Float(textWidth / 2), Float(textHeight / 2), -0.05)
        addChildNode(backgroundNode)

        // Position text
        textNode.position = SCNVector3(Float(padding), Float(padding), 0)
        addChildNode(textNode)

        // Billboard constraint to always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y]
        constraints = [billboardConstraint]
    }

    private func createAttributedString(_ text: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.darkGray,
            .paragraphStyle: paragraphStyle,
        ]

        // Wrap text to max width
        let wrappedText = wrapText(text, font: font, maxWidth: maxWidth - padding * 2)

        return NSAttributedString(string: wrappedText, attributes: attributes)
    }

    private func wrapText(_ text: String, font: NSFont, maxWidth: CGFloat) -> String {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : currentLine + " " + String(word)
            let size = (testLine as NSString).size(withAttributes: [.font: font])

            if size.width > maxWidth {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Updates

    func updateText(_ text: String) {
        // Cancel existing fade timer
        fadeTimer?.invalidate()

        // Remove old nodes
        textNode?.removeFromParentNode()
        backgroundNode?.removeFromParentNode()

        // Recreate with new text
        setupBubble(with: text)

        // Reset opacity
        opacity = 1.0

        // Schedule new auto-fade
        scheduleAutoFade()
    }

    private func scheduleAutoFade() {
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    // MARK: - Animations

    func fadeOut(completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()

        let fadeAction = SCNAction.fadeOut(duration: 0.5)
        runAction(fadeAction) {
            self.removeFromParentNode()
            completion?()
        }
    }

    deinit {
        fadeTimer?.invalidate()
    }
}
