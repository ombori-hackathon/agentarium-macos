import SwiftUI

struct StatusIndicator: View {
    let isConnected: Bool
    let error: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isConnected ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusText: String {
        if isConnected {
            return "CONNECTED"
        } else if let error = error {
            return "ERROR: \(error)"
        } else {
            return "DISCONNECTED"
        }
    }
}
