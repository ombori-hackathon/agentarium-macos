import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var terrainScene = TerrainScene()
    @State private var apiStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var selectedPath: String = ""
    @State private var webSocketClient = WebSocketClient()

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("agentarium")
                    .font(.title.bold())
                Spacer()

                // Directory path input
                TextField("Codebase path", text: $selectedPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                Button("Load") {
                    Task {
                        await loadFilesystem()
                    }
                }
                .disabled(selectedPath.isEmpty)

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
        .task {
            await checkHealth()
            setupWebSocket()
        }
    }

    private func setupWebSocket() {
        // Connect to WebSocket (URL is set in WebSocketClient init)
        webSocketClient.connect()

        // Set up message handlers
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

    private func loadFilesystem() async {
        errorMessage = nil

        guard !selectedPath.isEmpty else {
            errorMessage = "Please enter a path"
            return
        }

        do {
            let urlString = "\(baseURL)/api/filesystem?path=\(selectedPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else {
                errorMessage = "Invalid URL"
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let layout = try JSONDecoder().decode(FilesystemLayout.self, from: data)

            await terrainScene.updateTerrain(with: layout)
        } catch {
            errorMessage = "Failed to load filesystem: \(error.localizedDescription)"
        }
    }
}
