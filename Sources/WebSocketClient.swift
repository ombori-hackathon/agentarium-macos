import Foundation

@MainActor
class WebSocketClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0

    var onFilesystemUpdate: ((FilesystemLayout) -> Void)?
    var onAgentEvent: ((AgentEvent) -> Void)?
    var onAgentSpawn: ((AgentSpawn) -> Void)?
    var onAgentDespawn: ((AgentDespawn) -> Void)?
    var onTerrainLoading: ((TerrainLoading) -> Void)?
    var onTerrainComplete: ((TerrainComplete) -> Void)?

    init(url: URL = URL(string: "ws://localhost:8000/ws")!) {
        self.url = url
    }

    func connect() {
        guard webSocketTask == nil else {
            print("WebSocket already connected or connecting")
            return
        }

        print("Connecting to WebSocket: \(url)")
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        reconnectAttempts = 0
        lastError = nil

        receiveMessage()
    }

    func disconnect() {
        print("Disconnecting WebSocket")
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message)
                    self.receiveMessage()
                }

            case .failure(let error):
                Task { @MainActor in
                    print("WebSocket error: \(error)")
                    self.lastError = error.localizedDescription
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }

        @unknown default:
            print("Unknown WebSocket message type")
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("Failed to convert message to data")
            return
        }

        do {
            // First decode just the type
            let typeWrapper = try JSONDecoder().decode(TypeWrapper.self, from: data)

            switch typeWrapper.type {
            case "filesystem":
                // For filesystem, data is nested
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageData = json?["data"] else {
                    print("Invalid filesystem message format")
                    return
                }
                let dataJson = try JSONSerialization.data(withJSONObject: messageData)
                let layout = try JSONDecoder().decode(FilesystemLayout.self, from: dataJson)
                print("Received filesystem update: \(layout.folders.count) folders")
                onFilesystemUpdate?(layout)

            case "agent_event":
                let event = try JSONDecoder().decode(AgentEvent.self, from: data)
                print("Received agent event: \(event.eventType)")
                onAgentEvent?(event)

            case "agent_spawn":
                let spawn = try JSONDecoder().decode(AgentSpawn.self, from: data)
                print("Received agent spawn: \(spawn.agentId)")
                onAgentSpawn?(spawn)

            case "agent_despawn":
                let despawn = try JSONDecoder().decode(AgentDespawn.self, from: data)
                print("Received agent despawn: \(despawn.agentId)")
                onAgentDespawn?(despawn)

            case "terrain_loading":
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageData = json?["data"] else {
                    print("Invalid terrain_loading message format")
                    return
                }
                let dataJson = try JSONSerialization.data(withJSONObject: messageData)
                let loading = try JSONDecoder().decode(TerrainLoading.self, from: dataJson)
                print("Received terrain loading: \(loading.cwd)")
                onTerrainLoading?(loading)

            case "terrain_complete":
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageData = json?["data"] else {
                    print("Invalid terrain_complete message format")
                    return
                }
                let dataJson = try JSONSerialization.data(withJSONObject: messageData)
                let complete = try JSONDecoder().decode(TerrainComplete.self, from: dataJson)
                print("Received terrain complete: \(complete.folderCount) folders, \(complete.fileCount) files")
                onTerrainComplete?(complete)

            default:
                print("Unknown message type: \(typeWrapper.type)")
            }

        } catch {
            print("Failed to parse message: \(error)")
        }
    }

    private func handleDisconnect() {
        webSocketTask = nil
        isConnected = false

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            print("Reconnecting in \(reconnectDelay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(reconnectDelay))
                connect()
            }
        } else {
            print("Max reconnect attempts reached")
            lastError = "Connection failed after \(maxReconnectAttempts) attempts"
        }
    }

    deinit {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
    }
}

// Helper to decode just the type field
private struct TypeWrapper: Codable {
    let type: String
}
