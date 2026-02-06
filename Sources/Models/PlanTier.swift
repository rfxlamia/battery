import Foundation

/// Claude subscription plan tiers detected from Keychain credentials.
enum PlanTier: String, Codable, CaseIterable {
    case pro = "pro"
    case max = "max"
    case max5x = "max_5x"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .pro: return "Pro"
        case .max: return "Max"
        case .max5x: return "Max 5x"
        case .unknown: return "Unknown"
        }
    }

    var hasOpusAccess: Bool {
        switch self {
        case .max, .max5x: return true
        case .pro, .unknown: return false
        }
    }

    var hasSonnetTracking: Bool {
        return true // All plans have Sonnet tracking
    }

    /// Map the rateLimitTier string from Keychain to a PlanTier.
    static func from(rateLimitTier: String) -> PlanTier {
        switch rateLimitTier.lowercased() {
        case let t where t.contains("max_5x") || t.contains("max5x"):
            return .max5x
        case let t where t.contains("max"):
            return .max
        case let t where t.contains("pro"):
            return .pro
        default:
            return .unknown
        }
    }
}
