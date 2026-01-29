import SwiftUI

struct TooltipView: View {
    let name: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(path)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
    }
}
