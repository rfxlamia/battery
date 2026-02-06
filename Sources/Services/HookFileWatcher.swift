import Foundation
import Combine

/// Watches the hook events file for Claude Code session activity.
/// Uses DispatchSource to detect appends to ~/.battery/events.jsonl
/// and updates session state for adaptive polling.
class HookFileWatcher: ObservableObject {
    @Published var isSessionActive: Bool = false
    @Published var lastActivity: Date?
    @Published var currentSessionStart: Date?
    @Published var currentSessionId: String?

    private let eventsFilePath: String
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var lastFileOffset: UInt64 = 0

    /// How long after last activity before we consider the session idle
    private let idleTimeout: TimeInterval = 300  // 5 minutes

    private var idleTimer: Timer?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.eventsFilePath = home.appendingPathComponent(".battery/events.jsonl").path
    }

    func startWatching() {
        // Ensure the directory and file exist
        let dir = (eventsFilePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: eventsFilePath) {
            FileManager.default.createFile(atPath: eventsFilePath, contents: nil)
        }

        // Open file handle for reading
        guard let handle = FileHandle(forReadingAtPath: eventsFilePath) else {
            print("HookFileWatcher: Could not open \(eventsFilePath)")
            return
        }
        self.fileHandle = handle

        // Seek to end so we only process new events
        handle.seekToEndOfFile()
        lastFileOffset = handle.offsetInFile

        // Watch the file descriptor for writes
        let fd = handle.fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.readNewEvents()
        }

        source.setCancelHandler { [weak self] in
            self?.fileHandle?.closeFile()
            self?.fileHandle = nil
        }

        self.source = source
        source.resume()

        // Parse any recent events to determine current state
        parseRecentEvents()

        // Start idle timer
        startIdleTimer()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Private

    private func readNewEvents() {
        guard let handle = fileHandle else { return }

        handle.seek(toFileOffset: lastFileOffset)
        let newData = handle.readDataToEndOfFile()
        lastFileOffset = handle.offsetInFile

        guard !newData.isEmpty,
              let text = String(data: newData, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            processEventLine(line)
        }
    }

    private func processEventLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let event = try? decoder.decode(SessionEvent.self, from: data) else {
            print("HookFileWatcher: Failed to parse event: \(line)")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: SessionEvent) {
        lastActivity = Date()

        switch event.event {
        case .sessionStart:
            isSessionActive = true
            currentSessionStart = event.timestamp
            currentSessionId = event.sessionId

        case .sessionEnd:
            isSessionActive = false
            currentSessionStart = nil
            currentSessionId = nil

        case .postToolUse, .stop:
            // Activity during a session keeps it active
            if !isSessionActive {
                isSessionActive = true
                currentSessionStart = currentSessionStart ?? event.timestamp
            }
        }

        // Reset idle timer on any activity
        resetIdleTimer()
    }

    /// Parse the last few lines of the events file to determine current state on launch.
    private func parseRecentEvents() {
        guard let data = FileManager.default.contents(atPath: eventsFilePath),
              let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        // Look at last 20 events to determine current state
        let recentLines = lines.suffix(20)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var latestSessionStart: SessionEvent?
        var latestSessionEnd: SessionEvent?
        var latestActivity: SessionEvent?

        for line in recentLines {
            guard let data = line.data(using: .utf8),
                  let event = try? decoder.decode(SessionEvent.self, from: data) else { continue }

            switch event.event {
            case .sessionStart:
                latestSessionStart = event
            case .sessionEnd:
                latestSessionEnd = event
            case .postToolUse, .stop:
                latestActivity = event
            }
        }

        // Determine if a session is currently active
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let start = latestSessionStart {
                // Session started - check if it ended after
                if let end = latestSessionEnd, end.timestamp >= start.timestamp {
                    self.isSessionActive = false
                } else {
                    // Session started but not ended - check if recent activity
                    let mostRecentTime = latestActivity?.timestamp ?? start.timestamp
                    if Date().timeIntervalSince(mostRecentTime) < self.idleTimeout {
                        self.isSessionActive = true
                        self.currentSessionStart = start.timestamp
                        self.currentSessionId = start.sessionId
                        self.lastActivity = latestActivity?.timestamp ?? start.timestamp
                    } else {
                        // Too long since last activity, consider idle
                        self.isSessionActive = false
                    }
                }
            }
        }
    }

    private func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    private func resetIdleTimer() {
        // The timer checks periodically; lastActivity is updated on events
    }

    private func checkIdle() {
        guard isSessionActive, let lastActivity = lastActivity else { return }
        if Date().timeIntervalSince(lastActivity) >= idleTimeout {
            isSessionActive = false
            currentSessionStart = nil
            currentSessionId = nil
        }
    }
}
