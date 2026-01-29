import SceneKit

class TerrainScene: SCNScene {
    private var folderNodes: [String: FolderNode] = [:]
    private var fileNodes: [String: FileNode] = [:]
    private var agentNodes: [String: AgentNode] = [:]

    // Hierarchy tracking
    private var folderChildren: [String: Set<String>] = [:]  // parent path -> child folder paths
    private var folderFiles: [String: Set<String>] = [:]  // folder path -> file paths
    private var currentlyHighlighted: Set<String> = []

    // Agent target highlighting (separate from hover highlights)
    private var agentHighlightedPath: String?

    // Label tracking
    private var currentlyLabeledNode: SCNNode?

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

        // Build hierarchy
        buildHierarchy(from: layout.folders, files: layout.files)

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

        // Build hierarchy
        buildHierarchy(from: layout.folders, files: layout.files)

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
    func nodeInfo(at point: CGPoint, in view: SCNView) -> (name: String, path: String, isFolder: Bool)? {
        let hitResults = view.hitTest(point, options: [:])
        for result in hitResults {
            var node: SCNNode? = result.node
            while let current = node {
                if let folderNode = current as? FolderNode {
                    return (folderNode.folderName, folderNode.folderPath, true)
                }
                if let fileNode = current as? FileNode {
                    return (fileNode.fileName, fileNode.filePath, false)
                }
                node = current.parent
            }
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

        // Thought bubble disabled - using activity log instead
        // if let thought = event.thought {
        //     agent.updateThought(thought)
        // }

        // File path label disabled - using activity log instead
        // if let targetPath = event.targetPath {
        //     agent.updateFilePath(targetPath)
        // }

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
        // Thought bubble disabled - using activity log instead
        // if let thought = event.thought {
        //     agent.updateThought(thought)
        // }

        // File path label disabled - using activity log instead
        // if let targetPath = event.targetPath {
        //     agent.updateFilePath(targetPath)
        // }

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
        // Thought bubble disabled - using activity log instead
        // if let thought = event.thought {
        //     agent.updateThought(thought)
        // } else {
        //     agent.clearThought()
        // }

        // Make sure idle animation is running
        agent.startIdleAnimation()
    }

    // MARK: - Hierarchy Tracking

    private func buildHierarchy(from folders: [FolderInfo], files: [FileInfo]) {
        folderChildren.removeAll()
        folderFiles.removeAll()

        for folder in folders {
            if let parent = folder.parentPath {
                folderChildren[parent, default: []].insert(folder.path)
            }
        }

        for file in files {
            folderFiles[file.folder, default: []].insert(file.path)
        }
    }

    private func getAllDescendants(of folderPath: String) -> (folders: Set<String>, files: Set<String>) {
        var resultFolders: Set<String> = []
        var resultFiles: Set<String> = []
        var queue = [folderPath]

        while !queue.isEmpty {
            let current = queue.removeFirst()

            // Add direct files
            if let files = folderFiles[current] {
                resultFiles.formUnion(files)
            }

            // Add child folders and queue them
            if let children = folderChildren[current] {
                resultFolders.formUnion(children)
                queue.append(contentsOf: children)
            }
        }

        return (resultFolders, resultFiles)
    }

    func highlightHierarchy(folderPath: String) {
        // Clear previous highlights
        clearAllHighlights()

        // Get all descendants
        let (descendantFolders, descendantFiles) = getAllDescendants(of: folderPath)

        // Highlight the hovered folder
        if let node = folderNodes[folderPath] {
            node.setHighlighted(true)
            currentlyHighlighted.insert(folderPath)
        }

        // Highlight descendant folders
        for path in descendantFolders {
            if let node = folderNodes[path] {
                node.setHighlighted(true)
                currentlyHighlighted.insert(path)
            }
        }

        // Highlight descendant files
        for path in descendantFiles {
            if let node = fileNodes[path] {
                node.setHighlighted(true)
                currentlyHighlighted.insert(path)
            }
        }
    }

    func clearAllHighlights() {
        for path in currentlyHighlighted {
            if let folderNode = folderNodes[path] {
                folderNode.setHighlighted(false)
            }
            if let fileNode = fileNodes[path] {
                fileNode.setHighlighted(false)
            }
        }
        currentlyHighlighted.removeAll()
    }

    // MARK: - Agent Target Highlighting

    func highlightAgentTarget(path: String?) {
        // Clear previous agent highlight
        if let prevPath = agentHighlightedPath {
            if let folder = folderNodes[prevPath] {
                folder.setHighlighted(false)
            }
        }

        // Find the folder to highlight
        guard let targetPath = path else {
            agentHighlightedPath = nil
            return
        }

        // If it's a file, get its containing folder
        var folderPath = targetPath
        if fileNodes[targetPath] != nil {
            folderPath = (targetPath as NSString).deletingLastPathComponent
        }

        // Walk up to find a visible folder (prefer depth 1-2 for visibility)
        // Keep walking up until we find a folder that exists, or reach a reasonable level
        var currentPath = folderPath
        var bestFolderPath: String?

        while !currentPath.isEmpty && currentPath != "/" {
            if folderNodes[currentPath] != nil {
                bestFolderPath = currentPath
                // If we found a folder, check if we should go higher for visibility
                // Stop at depth ~2 for good visibility on terrain
                let depth = currentPath.components(separatedBy: "/").count
                if depth <= 4 {
                    break
                }
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }

        // Set new highlight
        agentHighlightedPath = bestFolderPath
        if let folderToHighlight = bestFolderPath {
            if let folder = folderNodes[folderToHighlight] {
                folder.setHighlighted(true)
            }
        }
    }

    // MARK: - Label Management

    @MainActor
    func showLabelForNode(at point: CGPoint, in view: SCNView) {
        let hitResults = view.hitTest(point, options: [:])
        var foundNode: SCNNode?

        for result in hitResults {
            var node: SCNNode? = result.node
            while let current = node {
                if current is FolderNode || current is FileNode {
                    foundNode = current
                    break
                }
                node = current.parent
            }
            if foundNode != nil { break }
        }

        // Hide previous label if different node
        if let prev = currentlyLabeledNode, prev != foundNode {
            (prev as? FolderNode)?.hideLabel()
            (prev as? FileNode)?.hideLabel()
        }

        // Show new label
        if let node = foundNode {
            (node as? FolderNode)?.showLabel()
            (node as? FileNode)?.showLabel()
            currentlyLabeledNode = node
        } else {
            currentlyLabeledNode = nil
        }
    }

    @MainActor
    func hideAllLabels() {
        (currentlyLabeledNode as? FolderNode)?.hideLabel()
        (currentlyLabeledNode as? FileNode)?.hideLabel()
        currentlyLabeledNode = nil
    }
}
