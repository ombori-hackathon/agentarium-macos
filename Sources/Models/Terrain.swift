import Foundation

// MARK: - Position
struct Position: Codable {
    let x: Double
    let y: Double
    let z: Double
}

// MARK: - Folder
struct Folder: Codable, Identifiable {
    let path: String
    let name: String
    let depth: Int
    let fileCount: Int
    let position: Position
    let height: Double

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case path, name, depth, position, height
        case fileCount = "file_count"
    }
}

// MARK: - File
struct File: Codable, Identifiable {
    let path: String
    let name: String
    let folder: String
    let size: Int
    let position: Position

    var id: String { path }
}

// MARK: - FilesystemLayout
struct FilesystemLayout: Codable {
    let root: String
    let folders: [Folder]
    let files: [File]
    let scannedAt: String

    enum CodingKeys: String, CodingKey {
        case root, folders, files
        case scannedAt = "scanned_at"
    }
}
