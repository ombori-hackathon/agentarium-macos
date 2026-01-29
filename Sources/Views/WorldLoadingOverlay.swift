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
        VStack {
            HStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                if let folders = folderCount, let files = fileCount {
                    Text("(\(folders) folders, \(files) files)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .shadow(color: .black, radius: 4, x: 0, y: 1)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
