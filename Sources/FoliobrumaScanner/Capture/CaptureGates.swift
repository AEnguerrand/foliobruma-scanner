// Automatic capture gates use elapsed time, not the number of camera callbacks.
struct AutoCaptureGate {
  var clearSince: Double?
  var cooldownUntil = 0.0
  mutating func reset() { clearSince = nil }
  mutating func captured(at now: Double) {
    clearSince = nil
    cooldownUntil = now + 0.8
  }
  mutating func ready(at now: Double, moving: Bool, blocked: Bool, duplicate: Bool, hasPage: Bool)
    -> Bool
  {
    guard !moving, !blocked, !duplicate, hasPage, now >= cooldownUntil else {
      clearSince = nil
      return false
    }
    guard let start = clearSince else {
      clearSince = now
      return false
    }
    return now - start >= 0.55
  }
}
struct PreflightFeedbackGate {
  var reason: String?
  var since = 0.0
  var notified = false
  mutating func observe(_ value: String?, at now: Double) -> Bool {
    guard let value = value else {
      reason = nil
      notified = false
      return false
    }
    if reason != value {
      reason = value
      since = now
      notified = false
    }
    guard !notified, now - since >= 1.5 else { return false }
    notified = true
    return true
  }
}
struct DuplicateFeedbackGate {
  var notified = false
  mutating func notify() -> Bool {
    guard !notified else { return false }
    notified = true
    return true
  }
  mutating func reset() { notified = false }
}
