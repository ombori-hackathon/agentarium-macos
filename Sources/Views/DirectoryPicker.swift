import SwiftUI
import AppKit

struct DirectoryPicker: View {
    @Binding var selectedPath: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let path = selectedPath {
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No directory selected")
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Select Directory...") {
                selectDirectory()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a codebase directory"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            selectedPath = path
            onSelect(path)
            print("Selected directory: \(path)")
        }
    }
}
