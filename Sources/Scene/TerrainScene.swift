import SceneKit

class TerrainScene: SCNScene {
    private let cameraNode = SCNNode()
    private let gridNode = GridNode()

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        // Set dark background color (#0a0a12)
        background.contents = NSColor(red: 0x0a/255.0, green: 0x0a/255.0, blue: 0x12/255.0, alpha: 1.0)

        // Add grid floor
        rootNode.addChildNode(gridNode)

        // Setup camera
        setupCamera()

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.3, alpha: 1.0)
        rootNode.addChildNode(ambientLight)

        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = NSColor(white: 0.5, alpha: 1.0)
        directionalLight.position = SCNVector3(10, 20, 10)
        directionalLight.look(at: SCNVector3Zero)
        rootNode.addChildNode(directionalLight)
    }

    private func setupCamera() {
        // Create camera
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 1000

        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 60, 100)
        cameraNode.look(at: SCNVector3Zero)

        rootNode.addChildNode(cameraNode)
    }

    func updateWithFilesystem(_ layout: FilesystemLayout) {
        print("TerrainScene: Updating with filesystem data")
        // This is where we'll add folder/file nodes in M2
        // For M1, we just log that we received the data
    }
}
