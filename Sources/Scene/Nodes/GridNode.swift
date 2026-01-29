import SceneKit

class GridNode: SCNNode {
    init(size: Int = 200, spacing: Float = 10.0) {
        super.init()

        let lineColor = NSColor(red: 0, green: 1, blue: 1, alpha: 0.4) // #00ffff at 40% opacity
        let material = SCNMaterial()
        material.diffuse.contents = lineColor
        material.lightingModel = .constant
        material.isDoubleSided = true

        let halfSize = Float(size) / 2.0
        let lineCount = size / Int(spacing)

        // Create lines parallel to X-axis
        for i in 0...lineCount {
            let z = Float(i) * spacing - halfSize
            let vertices: [SCNVector3] = [
                SCNVector3(-halfSize, 0, z),
                SCNVector3(halfSize, 0, z)
            ]
            let line = createLine(from: vertices, material: material)
            addChildNode(line)
        }

        // Create lines parallel to Z-axis
        for i in 0...lineCount {
            let x = Float(i) * spacing - halfSize
            let vertices: [SCNVector3] = [
                SCNVector3(x, 0, -halfSize),
                SCNVector3(x, 0, halfSize)
            ]
            let line = createLine(from: vertices, material: material)
            addChildNode(line)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createLine(from vertices: [SCNVector3], material: SCNMaterial) -> SCNNode {
        let indices: [Int32] = [0, 1]
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )

        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }
}
