const IDLE_TIMEOUT_SECONDS = 300;

export interface HookEvent {
  event: string;
  timestamp: string;
  sessionId?: string;
  tool?: string;
}

export interface SessionState {
  isActive: boolean;
  currentSessionId: string | null;
}

/**
 * Reduce a list of hook events to a session state snapshot.
 *
 * Matches Swift HookFileWatcher.parseRecentEvents() behavior:
 * - Walk all events, tracking latestSessionStart, latestSessionEnd, latestActivity.
 * - If SessionEnd.timestamp >= SessionStart.timestamp → inactive.
 * - Otherwise, compute mostRecentTime = latestActivity?.timestamp ?? SessionStart.timestamp.
 *   If now - mostRecentTime < 300s → active; else idle/inactive.
 * - PostToolUse (and "stop") without a prior SessionStart activates a session.
 * - lastActivity is set from the event timestamp (startup recovery semantics).
 */
export function reduceSessionState(events: HookEvent[], nowMs: number): SessionState {
  let latestSessionStart: HookEvent | null = null;
  let latestSessionEnd: HookEvent | null = null;
  let latestActivity: HookEvent | null = null;

  for (const event of events) {
    switch (event.event) {
      case 'SessionStart':
        latestSessionStart = event;
        break;
      case 'SessionEnd':
        latestSessionEnd = event;
        break;
      case 'PostToolUse':
      case 'stop':
        latestActivity = event;
        if (!latestSessionStart) {
          // Activate session from PostToolUse even without prior SessionStart
          latestSessionStart = { ...event, event: 'SessionStart' };
        }
        break;
    }
  }

  if (!latestSessionStart) {
    return { isActive: false, currentSessionId: null };
  }

  // SessionEnd takes precedence if it's >= SessionStart
  if (latestSessionEnd) {
    const endTs = new Date(latestSessionEnd.timestamp).getTime();
    const startTs = new Date(latestSessionStart.timestamp).getTime();
    if (endTs >= startTs) {
      return { isActive: false, currentSessionId: null };
    }
  }

  // Determine most recent activity time
  const mostRecentActivity = latestActivity ?? latestSessionStart;
  const mostRecentMs = new Date(mostRecentActivity.timestamp).getTime();
  const secondsSinceActivity = (nowMs - mostRecentMs) / 1000;

  if (secondsSinceActivity >= IDLE_TIMEOUT_SECONDS) {
    return { isActive: false, currentSessionId: null };
  }

  return {
    isActive: true,
    currentSessionId: latestSessionStart.sessionId ?? null,
  };
}
