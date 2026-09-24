// Automatic capture gates use elapsed time, not the number of camera callbacks.
public struct AutoCaptureGate {
  public init() {}
  public var clearSince: Double?
  public var cooldownUntil = 0.0
  public mutating func reset() { clearSince = nil }
  public mutating func captured(at now: Double) {
    clearSince = nil
    cooldownUntil = now + 0.8
  }
  public mutating func ready(at now: Double, moving: Bool, blocked: Bool, duplicate: Bool, hasPage: Bool)
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
public struct PreflightFeedbackGate {
  public init() {}
  public var reason: String?
  public var since = 0.0
  public var notified = false
  public mutating func observe(_ value: String?, at now: Double) -> Bool {
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
public struct DuplicateFeedbackGate {
  public init() {}
  public var notified = false
  public mutating func notify() -> Bool {
    guard !notified else { return false }
    notified = true
    return true
  }
  public mutating func reset() { notified = false }
}
