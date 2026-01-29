import SwiftUI
import SceneKit

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

    private let baseURL = "http://localhost:8000"

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("agentarium")
                        .font(.title.bold())

                    Spacer()

                    if let cwd = currentCwd {
                        Text(cwd)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Waiting for Claude Code session...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Circle()
                        .fill(apiStatus == "healthy" ? .green : .red)
                        .frame(width: 12, height: 12)
                    Text(apiStatus)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)

                Divider()

                // SceneKit View
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
                } else {
                    SceneView(
                        scene: terrainScene,
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                }
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
            folderCount = layout.folders.count
            fileCount = layout.files.count
            loadingMessage = "Building terrain..."

            Task {
                await terrainScene.updateTerrainWithAnimation(with: layout)
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
