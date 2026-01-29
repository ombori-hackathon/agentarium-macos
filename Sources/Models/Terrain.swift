import Foundation
import SceneKit

// MARK: - Terrain Models

struct Folder {
    let path: String
    let name: String
    let depth: Int
    let fileCount: Int
    var position: SCNVector3 = SCNVector3Zero

    init(from info: FolderInfo) {
        self.path = info.path
        self.name = info.name
        self.depth = info.depth
        self.fileCount = info.fileCount
    }
}

struct File {
    let path: String
    let name: String
    let folder: String
    let size: Int
    var position: SCNVector3 = SCNVector3Zero

    init(from info: FileInfo) {
        self.path = info.path
        self.name = info.name
        self.folder = info.folder
        self.size = info.size
    }
}

// MARK: - Terrain Layout

class TerrainLayout {
    private(set) var folders: [String: Folder] = [:]
    private(set) var files: [String: File] = [:]
    private(set) var root: String = ""

    func update(from layout: FilesystemLayout) {
        root = layout.root
        folders = Dictionary(uniqueKeysWithValues: layout.folders.map { info in
            (info.path, Folder(from: info))
        })
        files = Dictionary(uniqueKeysWithValues: layout.files.map { info in
            (info.path, File(from: info))
        })

        print("Terrain updated: \(folders.count) folders, \(files.count) files")
    }

    func clear() {
        folders.removeAll()
        files.removeAll()
        root = ""
    }
}
