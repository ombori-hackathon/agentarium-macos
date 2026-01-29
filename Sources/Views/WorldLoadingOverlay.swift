import SwiftUI

struct WorldLoadingOverlay: View {
    let message: String
    let folderCount: Int?
    let fileCount: Int?

    init(message: String = "Creating world...", folderCount: Int? = nil, fileCount: Int? = nil) {
        self.message = message
        self.folderCount = folderCount
        self.fileCount = fileCount
    }

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))

            Text(message)
                .font(.title2)
                .foregroundStyle(.white)

            if let folders = folderCount, let files = fileCount {
                Text("\(folders) folders, \(files) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
}

