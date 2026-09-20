import AppKit

extension Scanner {
  func performUSBAction(_ action: USBButtonAction) {
    guard !busy, error == nil, !showNewItem, !showMetadata, !showLabel,
      !showSessions, !showRejected, !showExport, !showCrop, !showFraming else { return }
    switch action {
    case .capture:
      capture()
    case .autoCapture:
      guard connected, !reviewing, !metadataWorkspace, replacementID == nil else { return }
      autoCapture.toggle()
      status = autoCapture ? L10n.text("Waiting for a clear, still page") : L10n.text("Capture paused")
    case .nextDocument:
      guard !document.pages.isEmpty else { return }
      newDocument()
    case .newItem:
      prepareNewItem()
    case .nextLetter:
      nextLetter()
    case .review:
      guard !document.pages.isEmpty else { return }
      beginReview()
    case .export:
      prepareExport()
    }
  }
}
