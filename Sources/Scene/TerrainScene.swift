import SceneKit

class TerrainScene: SCNScene {
    private var folderNodes: [String: SCNNode] = [:]
    private var fileNodes: [String: SCNNode] = [:]
    private var agentNodes: [String: AgentNode] = [:]

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        // Background color: #0a0a12
        background.contents = NSColor(red: 0x0a / 255.0, green: 0x0a / 255.0, blue: 0x12 / 255.0, alpha: 1.0)

        // Fog
        fogStartDistance = 50
        fogEndDistance = 150
        fogColor = background.contents as! NSColor

        // Add grid floor
        let gridNode = GridNode(size: 200, spacing: 10)
        rootNode.addChildNode(gridNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 30, 50)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        rootNode.addChildNode(cameraNode)

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = NSColor(white: 0.3, alpha: 1.0)
        rootNode.addChildNode(ambientLight)

        // Directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = NSColor(white: 0.5, alpha: 1.0)
        directionalLight.position = SCNVector3(10, 20, 10)
        directionalLight.look(at: SCNVector3(0, 0, 0))
        rootNode.addChildNode(directionalLight)
    }

    @MainActor
    func updateTerrain(with layout: FilesystemLayout) async {
        // Clear existing nodes
        folderNodes.values.forEach { $0.removeFromParentNode() }
        fileNodes.values.forEach { $0.removeFromParentNode() }
        folderNodes.removeAll()
        fileNodes.removeAll()

        let batchSize = 50

        // Spawn folder nodes in batches
        for batchStart in stride(from: 0, to: layout.folders.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, layout.folders.count)
            let batch = layout.folders[batchStart..<batchEnd]

            for folder in batch {
                let folderNode = FolderNode(folder: folder)
                rootNode.addChildNode(folderNode)
                folderNodes[folder.path] = folderNode
            }

            // Yield to keep UI responsive
            await Task.yield()
        }

        // Spawn file nodes in batches
        for batchStart in stride(from: 0, to: layout.files.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, layout.files.count)
            let batch = layout.files[batchStart..<batchEnd]

            for file in batch {
                let fileNode = FileNode(file: file)
                rootNode.addChildNode(fileNode)
                fileNodes[file.path] = fileNode
            }

            // Yield to keep UI responsive
            await Task.yield()
        }
    }

    @MainActor
    func updateTerrainWithAnimation(with layout: FilesystemLayout) async {
        // Clear existing nodes
        folderNodes.values.forEach { $0.removeFromParentNode() }
        fileNodes.values.forEach { $0.removeFromParentNode() }
        folderNodes.removeAll()
        fileNodes.removeAll()

        // Spawn all nodes below ground first, then animate all at once
        for folder in layout.folders {
            let folderNode = FolderNode(folder: folder)
            let targetY = CGFloat(folder.position?.y ?? 0)
            folderNode.position.y = targetY - 10
            folderNode.opacity = 0
            rootNode.addChildNode(folderNode)
            folderNodes[folder.path] = folderNode
        }

        for file in layout.files {
            let fileNode = FileNode(file: file)
            let targetY = CGFloat(file.position?.y ?? 0)
            fileNode.position.y = targetY - 10
            fileNode.opacity = 0
            rootNode.addChildNode(fileNode)
            fileNodes[file.path] = fileNode
        }

        // Fire all animations at once (non-blocking) with slight stagger
        var delay: Double = 0
        let staggerIncrement: Double = 0.01  // 10ms between each node

        for folder in layout.folders {
            if let node = folderNodes[folder.path] {
                let targetY = CGFloat(folder.position?.y ?? 0)
                let riseAction = SCNAction.move(
                    to: SCNVector3(node.position.x, targetY, node.position.z),
                    duration: 0.3
                )
                riseAction.timingMode = .easeOut
                let fadeIn = SCNAction.fadeIn(duration: 0.2)
                let delayAction = SCNAction.wait(duration: delay)
                // Use completion handler version to fire-and-forget
                node.runAction(
                    SCNAction.sequence([delayAction, SCNAction.group([riseAction, fadeIn])]), completionHandler: nil)
                delay += staggerIncrement
            }
        }

        for file in layout.files {
            if let node = fileNodes[file.path] {
                let targetY = CGFloat(file.position?.y ?? 0)
                let riseAction = SCNAction.move(
                    to: SCNVector3(node.position.x, targetY, node.position.z),
                    duration: 0.3
                )
                riseAction.timingMode = .easeOut
                let fadeIn = SCNAction.fadeIn(duration: 0.2)
                let delayAction = SCNAction.wait(duration: delay)
                // Use completion handler version to fire-and-forget
                node.runAction(
                    SCNAction.sequence([delayAction, SCNAction.group([riseAction, fadeIn])]), completionHandler: nil)
                delay += staggerIncrement
            }
        }

        // Wait for animations to complete (max delay + animation duration)
        let totalWait = delay + 0.4
        try? await Task.sleep(for: .milliseconds(Int(totalWait * 1000)))
    }

    // MARK: - Hit Testing for Tooltips

    @MainActor
    func nodeInfo(at point: CGPoint, in view: SCNView) -> (name: String, path: String)? {
        let hitResults = view.hitTest(
            point,
            options: [
                .boundingBoxOnly: false,
                .firstFoundOnly: true,
                .ignoreHiddenNodes: true,
            ])

        guard let firstHit = hitResults.first else { return nil }

        // Walk up the node hierarchy to find a node with a name (our folder/file nodes)
        var node: SCNNode? = firstHit.node
        while node != nil {
            if let nodeName = node?.name, nodeName.contains("|") {
                let parts = nodeName.split(separator: "|", maxSplits: 1)
                if parts.count == 2 {
                    return (name: String(parts[0]), path: String(parts[1]))
                }
            }
            node = node?.parent
        }

        return nil
    }

    // MARK: - Agent Management

    func spawnAgent(spawn: AgentSpawn) {
        // Don't spawn if already exists
        guard agentNodes[spawn.agentId] == nil else { return }

        let agent = AgentNode(color: spawn.color)
        agent.position = SCNVector3(
            Float(spawn.position.x),
            Float(spawn.position.y),
            Float(spawn.position.z)
        )

        rootNode.addChildNode(agent)
        agentNodes[spawn.agentId] = agent

        // Start idle animation
        agent.startIdleAnimation()

        print("Agent spawned: \(spawn.agentId) at (\(spawn.position.x), \(spawn.position.y), \(spawn.position.z))")
    }

    func despawnAgent(despawn: AgentDespawn) {
        guard let agent = agentNodes[despawn.agentId] else { return }

        // Use the agent's despawn method with fade animation
        agent.despawn {
            // Clean up reference after fade completes
        }

        agentNodes.removeValue(forKey: despawn.agentId)

        print("Agent despawned: \(despawn.agentId)")
    }

    func handleAgentEvent(_ event: AgentEvent) {
        guard let agent = agentNodes[event.agentId] else {
            print("Agent not found: \(event.agentId)")
            return
        }

        print("Agent event: \(event.eventType) for \(event.agentId)")

        switch event.eventType {
        case "move":
            handleMoveEvent(agent: agent, event: event)

        case "read", "write", "edit", "bash", "grep", "glob":
            handleToolEvent(agent: agent, event: event)

        case "idle":
            handleIdleEvent(agent: agent, event: event)

        default:
            print("Unknown event type: \(event.eventType)")
        }
    }

    private func handleMoveEvent(agent: AgentNode, event: AgentEvent) {
        guard let targetPosition = event.targetPosition else {
            print("Move event missing target position")
            return
        }

        let target = SCNVector3(
            Float(targetPosition.x),
            Float(targetPosition.y),
            Float(targetPosition.z)
        )

        // Update thought if provided
        if let thought = event.thought {
            agent.updateThought(thought)
        }

        // Update file path label if provided
        if let targetPath = event.targetPath {
            agent.updateFilePath(targetPath)
        }

        // Show tool icon if provided
        if let toolName = event.toolName {
            agent.showToolIcon(toolName)
        }

        // Move to target (duration calculated automatically)
        agent.moveTo(position: target) {
            // Hide tool icon after arrival
            agent.hideToolIcon()
        }
    }

    private func handleToolEvent(agent: AgentNode, event: AgentEvent) {
        // Update thought
        if let thought = event.thought {
            agent.updateThought(thought)
        }

        // Update file path label if provided
        if let targetPath = event.targetPath {
            agent.updateFilePath(targetPath)
        }

        // Show tool icon
        if let toolName = event.toolName {
            agent.showToolIcon(toolName)

            // Auto-hide after 2 seconds - do it with an action instead
            let waitAction = SCNAction.wait(duration: 2.0)
            let hideAction = SCNAction.run { _ in
                agent.hideToolIcon()
            }
            agent.runAction(SCNAction.sequence([waitAction, hideAction]), forKey: "auto_hide_tool")
        }

        // Move to target if position provided
        if let targetPosition = event.targetPosition {
            let target = SCNVector3(
                Float(targetPosition.x),
                Float(targetPosition.y),
                Float(targetPosition.z)
            )

            agent.moveTo(position: target)
        }
    }

    private func handleIdleEvent(agent: AgentNode, event: AgentEvent) {
        // Update thought if provided
        if let thought = event.thought {
            agent.updateThought(thought)
        } else {
            agent.clearThought()
        }

        // Make sure idle animation is running
        agent.startIdleAnimation()
    }
}
