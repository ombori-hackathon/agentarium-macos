import SceneKit

class GridNode: SCNNode {
    private let spacing: CGFloat = 10.0
    private let extent: CGFloat = 200.0
    private let lineColor = NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.4) // cyan at 40%

    override init() {
        super.init()
        createGrid()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createGrid() {
        let halfExtent = extent / 2
        let lineCount = Int(extent / spacing) + 1

        var vertices: [SCNVector3] = []

        // Lines parallel to X axis (going left-right)
        for i in 0..<lineCount {
            let z = -halfExtent + CGFloat(i) * spacing
            vertices.append(SCNVector3(-halfExtent, 0, z))
            vertices.append(SCNVector3(halfExtent, 0, z))
        }

        // Lines parallel to Z axis (going forward-back)
        for i in 0..<lineCount {
            let x = -halfExtent + CGFloat(i) * spacing
            vertices.append(SCNVector3(x, 0, -halfExtent))
            vertices.append(SCNVector3(x, 0, halfExtent))
        }

        // Create geometry source
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        // Create geometry elements for line segments
        var indices: [Int32] = []
        for i in 0..<vertices.count {
            indices.append(Int32(i))
        }

        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .line,
            primitiveCount: vertices.count / 2,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

        // Set material
        let material = SCNMaterial()
        material.diffuse.contents = lineColor
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]

        self.geometry = geometry
    }
}
