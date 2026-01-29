import SceneKit
import SwiftUI

struct ContentView: View {
    @State private var terrainScene = TerrainScene()
    @State private var apiStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var webSocketClient = WebSocketClient()

    // Loading state
    @State private var isLoadingTerrain = false
    @State private var loadingMessage = "Waiting for Claude Code..."
    @State private var currentCwd: String?
    @State private var folderCount: Int?
    @State private var fileCount: Int?
    @State private var sceneView: SCNView?

    // Activity log
    @State private var activityEntries: [ActivityEntry] = []

    private let baseURL = "http://localhost:8000"

    var body: some View {
        ZStack {
            // SceneKit View - fullscreen
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Text("Start API: cd services/api && uv run fastapi dev")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0x0a / 255.0, green: 0x0a / 255.0, blue: 0x12 / 255.0))
            } else {
                SceneViewWrapper(
                    scene: terrainScene,
                    sceneView: $sceneView
                )
            }

            // Loading overlay
            if isLoadingTerrain {
                WorldLoadingOverlay(
                    message: loadingMessage,
                    folderCount: folderCount,
                    fileCount: fileCount
                )
                .transition(.opacity)
            }

            // Activity log overlay (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if !activityEntries.isEmpty {
                        ActivityLogView(entries: activityEntries)
                            .padding()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoadingTerrain)
        .task {
            await checkHealth()
            setupWebSocket()
        }
    }

    private func setupWebSocket() {
        // Connect to WebSocket (URL is set in WebSocketClient init)
        webSocketClient.connect()

        // Set up message handlers
        webSocketClient.onTerrainLoading = { loading in
            isLoadingTerrain = true
            loadingMessage = loading.message
            currentCwd = loading.cwd
            folderCount = nil
            fileCount = nil
        }

        webSocketClient.onFilesystemUpdate = { layout in
            isLoadingTerrain = true  // Ensure loading shows
            folderCount = layout.folders.count
            fileCount = layout.files.count
            loadingMessage = "Building world..."

            Task {
                await terrainScene.updateTerrainWithAnimation(with: layout)
                // Hide after animation completes
                isLoadingTerrain = false
            }
        }

        webSocketClient.onTerrainComplete = { complete in
            folderCount = complete.folderCount
            fileCount = complete.fileCount

            // Hide overlay after a short delay for animation to complete
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                isLoadingTerrain = false
            }
        }

        webSocketClient.onAgentSpawn = { spawn in
            terrainScene.spawnAgent(spawn: spawn)
        }

        webSocketClient.onAgentDespawn = { despawn in
            terrainScene.despawnAgent(despawn: despawn)
        }

        webSocketClient.onAgentEvent = { event in
            terrainScene.handleAgentEvent(event)

            // Add to activity log (keep last 10)
            let entry = ActivityEntry.from(event: event)
            activityEntries.append(entry)
            if activityEntries.count > 10 {
                activityEntries.removeFirst()
            }

            // Highlight target folder in scene and move agent there
            if let folderPosition = terrainScene.highlightAgentTarget(path: event.targetPath) {
                terrainScene.moveAgent(agentId: event.agentId, to: folderPosition)
            }
        }
    }

    private func checkHealth() async {
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            apiStatus = health.status
        } catch {
            apiStatus = "offline"
            errorMessage = "API not running"
        }
    }
}

// MARK: - SceneView Wrapper for Hover Tracking

struct SceneViewWrapper: NSViewRepresentable {
    let scene: TerrainScene
    @Binding var sceneView: SCNView?

    func makeNSView(context: Context) -> HoverTrackingSCNView {
        let view = HoverTrackingSCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            sceneView = view
        }

        return view
    }

    func updateNSView(_ nsView: HoverTrackingSCNView, context: Context) {
        nsView.terrainScene = scene
    }
}

// Custom SCNView subclass that tracks mouse hover
class HoverTrackingSCNView: SCNView {
    var terrainScene: TerrainScene?
    private var lastHoveredPath: String?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }

        // Add new tracking area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let locationInView = convert(event.locationInWindow, from: nil)

        guard let scene = terrainScene else {
            return
        }

        Task { @MainActor in
            // Show label for hovered node
            scene.showLabelForNode(at: locationInView, in: self)

            // Update hierarchy highlights
            if let info = scene.nodeInfo(at: locationInView, in: self) {
                // Only update highlights if path changed
                if info.path != lastHoveredPath {
                    lastHoveredPath = info.path

                    if info.isFolder {
                        scene.highlightHierarchy(folderPath: info.path)
                    } else {
                        scene.clearAllHighlights()
                    }
                }
            } else {
                if lastHoveredPath != nil {
                    lastHoveredPath = nil
                    scene.clearAllHighlights()
                }
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        lastHoveredPath = nil
        if let scene = terrainScene {
            scene.clearAllHighlights()
            scene.hideAllLabels()
        }
    }
}
