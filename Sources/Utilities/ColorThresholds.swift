import SwiftUI

/// Maps utilization percentages to color-coded severity levels.
enum UsageLevel: String, CaseIterable {
    case low       // 0-50%  green
    case moderate  // 50-75% yellow
    case high      // 75-90% orange
    case critical  // 90%+   red

    static func from(utilization: Double) -> UsageLevel {
        switch utilization {
        case ..<50:
            return .low
        case 50..<75:
            return .moderate
        case 75..<90:
            return .high
        default:
            return .critical
        }
    }

    var color: Color {
        switch self {
        case .low:      return .green
        case .moderate: return .yellow
        case .high:     return .orange
        case .critical: return .red
        }
    }

    var sfSymbol: String {
        switch self {
        case .low:      return "battery.75percent"
        case .moderate: return "battery.50percent"
        case .high:     return "battery.25percent"
        case .critical: return "battery.25percent"
        }
    }

    var label: String {
        switch self {
        case .low:      return "Good"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }
}
