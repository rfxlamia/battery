import SwiftUI

/// A circular arc gauge that fills based on a 0-1 value.
struct GaugeRingView: View {
    let value: Double  // 0.0 to 1.0
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    init(value: Double, color: Color, size: CGFloat = 60, lineWidth: CGFloat = 6) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: value)

            // Center percentage
            Text("\(Int((value * 100).rounded()))")
                .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
