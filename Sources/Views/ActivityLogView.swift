import SwiftUI

struct ActivityLogView: View {
    let entries: [ActivityEntry]

    // Get the most recent entry with a target path
    private var currentFile: String? {
        entries.last { $0.targetPath != nil }?.targetPath
    }

    private var currentFileName: String {
        guard let path = currentFile else { return "—" }
        return (path as NSString).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current file header
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT FILE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                Text(currentFileName)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))

            // Divider
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)

            // Activity header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 9))
                Text("ACTIVITY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(entries) { entry in
                            HStack(alignment: .center, spacing: 6) {
                                Text(entry.icon)
                                    .font(.system(size: 11))
                                Text(entry.message)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .id(entry.id)
                        }
                    }
                }
                .onChange(of: entries.count) { _, _ in
                    if let last = entries.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 200)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
    }
}
