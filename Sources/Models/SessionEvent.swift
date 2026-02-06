import Foundation

/// Events written by the Claude Code hook script.
struct SessionEvent: Codable {
    let event: EventType
    let timestamp: Date
    let sessionId: String?
    let tool: String?

    enum EventType: String, Codable {
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case postToolUse = "PostToolUse"
        case stop = "Stop"
    }

    enum CodingKeys: String, CodingKey {
        case event
        case timestamp
        case sessionId = "session_id"
        case tool
    }
}
