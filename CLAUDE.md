# AgentariumClient - SwiftUI App

macOS desktop app that communicates with the FastAPI backend.

## Commands
- Build: `swift build` or `make build`
- Run: `swift run AgentariumClient` or `make run`
- Test: `swift test` or `make test`
- Lint: `make lint` (check formatting)
- Format: `make format` (auto-fix formatting)
- Install hooks: `make install-hooks` (set up pre-commit)

## Code Quality

### Pre-commit Hooks
Install git hooks to run checks before each commit:
```bash
make install-hooks
```

This runs:
1. `swift format lint` - checks code formatting
2. `swift build` - ensures code compiles

### Formatting
Uses `swift format` with config in `.swift-format`. Run `make format` to auto-fix issues.

### Known Warnings
SceneKit has Sendable warnings in Swift 6 strict concurrency mode. These are framework limitations, not code issues. Files use `@preconcurrency import SceneKit` to minimize noise.

## Architecture
- SwiftUI app with native macOS window
- Entry point: Sources/AgentariumApp.swift
- Main view: Sources/ContentView.swift
- Data models: Sources/Models.swift
- 3D Scene: Sources/Scene/TerrainScene.swift
- Agent nodes: Sources/Scene/Nodes/
- Uses async/await with URLSession
- Targets macOS 14+, Swift 6.0

## API Integration
- Backend runs at http://localhost:8000
- Health check: GET /health
- Sample data: GET /items (returns list of items)
- WebSocket: ws://localhost:8000/ws (agent events)

## Adding Features
1. Create new SwiftUI views in Sources/
2. Add new async functions for API calls in views or a dedicated APIClient
3. Use `URLSession.shared.data(from:)` for GET requests
4. Use `URLSession.shared.data(for:)` for POST/PUT with URLRequest
