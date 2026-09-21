import AppKit

extension Scanner {
  func report(_ message: String) { DispatchQueue.main.async { self.status = message } }
  func updatePreflight(_ reason: String?) {
    guard autoCapture else {
      preflightWarning = nil
      _ = preflightFeedback.observe(nil, at: 0)
      return
    }
    if preflightFeedback.observe(reason, at: Date.timeIntervalSinceReferenceDate) {
      preflightWarning = reason
      if soundEnabled && tracksActiveSession { NSSound(named: "Pop")?.play() }
    } else if reason == nil {
      preflightWarning = nil
    }
  }
  func showDuplicate() {
    status = L10n.text("Already scanned · Turn the page")
    duplicateWarning = true
    if duplicateFeedback.notify(), soundEnabled, tracksActiveSession {
      NSSound(named: "Tink")?.play()
    }
  }
  func confirmCapture() {
    duplicateWarning = false
    duplicateFeedback.reset()
    captureSaved = true
    if tracksActiveSession, let window = NSApp?.mainWindow {
      NSAccessibility.post(
        element: window, notification: .announcementRequested,
        userInfo: [
          .announcement: self.isSheetBatch ? self.sheetCapturePrompt : L10n.text("Page saved. Turn the page."),
          .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }
    let id = UUID()
    feedbackID = id
    if soundEnabled && tracksActiveSession { NSSound(named: "Glass")?.play() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      if self.feedbackID == id { self.captureSaved = false }
    }
  }
}
