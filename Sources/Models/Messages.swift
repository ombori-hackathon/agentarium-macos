import Foundation

// MARK: - WebSocket Message Types

enum WSMessageType: String, Codable {
    case filesystem
    case agentEvent = "agent_event"
    case agentSpawn = "agent_spawn"
    case agentDespawn = "agent_despawn"
}

struct WSMessage: Codable {
    let type: String
    let data: Data

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        // Store raw JSON data for later decoding based on type
        data = try container.decode(Data.self, forKey: .data)
    }
}

// MARK: - Filesystem Layout

struct FilesystemLayout: Codable {
    let root: String
    let folders: [FolderInfo]
    let files: [FileInfo]
    let scannedAt: String

    enum CodingKeys: String, CodingKey {
        case root
        case folders
        case files
        case scannedAt = "scanned_at"
    }
}

struct FolderInfo: Codable {
    let path: String
    let name: String
    let depth: Int
    let fileCount: Int
    let position: Position?
    let height: Double?

    enum CodingKeys: String, CodingKey {
        case path
        case name
        case depth
        case fileCount = "file_count"
        case position
        case height
    }
}

struct FileInfo: Codable {
    let path: String
    let name: String
    let folder: String
    let size: Int
    let position: Position?
}

// MARK: - Position

struct Position: Codable {
    let x: Double
    let y: Double
    let z: Double
}

// MARK: - Agent Event

struct AgentEvent: Codable {
    let type: String
    let agentId: String
    let eventType: String
    let targetPath: String?
    let targetPosition: Position?
    let thought: String?
    let toolName: String?
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case type
        case agentId = "agent_id"
        case eventType = "event_type"
        case targetPath = "target_path"
        case targetPosition = "target_position"
        case thought
        case toolName = "tool_name"
        case timestamp
    }
}

// MARK: - Agent Spawn

struct AgentSpawn: Codable {
    let type: String
    let agentId: String
    let position: Position
    let color: String

    enum CodingKeys: String, CodingKey {
        case type
        case agentId = "agent_id"
        case position
        case color
    }
}

// MARK: - Agent Despawn

struct AgentDespawn: Codable {
    let type: String
    let agentId: String

    enum CodingKeys: String, CodingKey {
        case type
        case agentId = "agent_id"
    }
}

// MARK: - Helper for Dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
