import Foundation

struct ActivityEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let icon: String
    let message: String
    let targetPath: String?

    static func from(event: AgentEvent) -> ActivityEntry {
        let icon = iconFor(eventType: event.eventType)
        let message = formatMessage(event: event)
        return ActivityEntry(
            timestamp: Date(),
            icon: icon,
            message: message,
            targetPath: event.targetPath
        )
    }

    private static func iconFor(eventType: String) -> String {
        switch eventType {
        case "read": return "📖"
        case "write": return "✏️"
        case "edit": return "🔧"
        case "bash": return "⚡"
        case "grep": return "🔍"
        case "glob": return "📁"
        case "move": return "🚶"
        case "idle": return "💭"
        default: return "•"
        }
    }

    private static func formatMessage(event: AgentEvent) -> String {
        if let thought = event.thought, !thought.isEmpty {
            return thought
        }
        if let path = event.targetPath {
            let filename = (path as NSString).lastPathComponent
            return "\(event.eventType) \(filename)"
        }
        return event.eventType
    }
}
