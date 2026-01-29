import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var wsClient = WebSocketClient()
    @State private var selectedPath: String?
    @State private var terrainScene = TerrainScene()

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header with directory picker and status
            HStack(spacing: 16) {
                DirectoryPicker(selectedPath: $selectedPath) { path in
                    loadFilesystem(path: path)
                }

                Spacer()

                StatusIndicator(isConnected: wsClient.isConnected, error: wsClient.lastError)
            }
            .padding(12)
            .background(.ultraThinMaterial)

            Divider()

            // SceneKit view
            SceneView(
                scene: terrainScene,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
        }
        .onAppear {
            setupWebSocket()
            wsClient.connect()
        }
        .onDisappear {
            wsClient.disconnect()
        }
    }

    private func setupWebSocket() {
        wsClient.onFilesystemUpdate = { layout in
            print("ContentView: Received filesystem update")
            terrainScene.updateWithFilesystem(layout)
        }

        wsClient.onAgentEvent = { event in
            print("ContentView: Agent event - \(event.hookEventName)")
        }

        wsClient.onAgentSpawn = { spawn in
            print("ContentView: Agent spawned - \(spawn.agentId)")
        }

        wsClient.onAgentDespawn = { despawn in
            print("ContentView: Agent despawned - \(despawn.agentId)")
        }
    }

    private func loadFilesystem(path: String) {
        Task {
            do {
                guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "\(baseURL)/api/filesystem?path=\(encodedPath)") else {
                    print("Invalid URL")
                    return
                }

                print("Loading filesystem from: \(url)")
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status: \(httpResponse.statusCode)")
                }

                let layout = try JSONDecoder().decode(FilesystemLayout.self, from: data)
                print("Loaded filesystem: \(layout.folders.count) folders, \(layout.files.count) files")

                await MainActor.run {
                    terrainScene.updateWithFilesystem(layout)
                }
            } catch {
                print("Failed to load filesystem: \(error)")
            }
        }
    }
}
