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
        background.contents = NSColor(red: 0x0a/255.0, green: 0x0a/255.0, blue: 0x12/255.0, alpha: 1.0)

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

    func updateTerrain(with layout: FilesystemLayout) {
        // Clear existing nodes
        folderNodes.values.forEach { $0.removeFromParentNode() }
        fileNodes.values.forEach { $0.removeFromParentNode() }
        folderNodes.removeAll()
        fileNodes.removeAll()

        // Spawn folder nodes
        for folder in layout.folders {
            let folderNode = FolderNode(folder: folder)
            rootNode.addChildNode(folderNode)
            folderNodes[folder.path] = folderNode
        }

        // Spawn file nodes
        for file in layout.files {
            let fileNode = FileNode(file: file)
            rootNode.addChildNode(fileNode)
            fileNodes[file.path] = fileNode
        }
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

        // Fade out and remove
        let fadeAction = SCNAction.fadeOut(duration: 0.5)
        agent.runAction(fadeAction) {
            agent.removeFromParentNode()
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

        // Calculate duration based on distance (distance / 10.0 seconds)
        let distance = agent.position.distance(to: target)
        let duration = TimeInterval(distance / 10.0)

        // Update thought if provided
        if let thought = event.thought {
            agent.updateThought(thought)
        }

        // Show tool icon if provided
        if let toolName = event.toolName {
            agent.showToolIcon(toolName)
        }

        // Move to target
        agent.moveTo(position: target, duration: duration) {
            // Hide tool icon after arrival
            agent.hideToolIcon()
        }
    }

    private func handleToolEvent(agent: AgentNode, event: AgentEvent) {
        // Update thought
        if let thought = event.thought {
            agent.updateThought(thought)
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

            let distance = agent.position.distance(to: target)
            let duration = TimeInterval(distance / 10.0)

            agent.moveTo(position: target, duration: duration)
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
