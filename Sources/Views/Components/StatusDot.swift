import SwiftUI

/// A small color-coded status indicator dot.
struct StatusDot: View {
    let color: Color
    let size: CGFloat

    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
