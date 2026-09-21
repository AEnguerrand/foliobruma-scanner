import AppKit

extension Scanner {
  var isSheetBatch: Bool { document.metadata?.sheetBatch == true }
  var sheetIsFull: Bool { isSheetBatch && document.pages.count >= 2 }
  var sheetCapturePrompt: String {
    switch document.pages.count {
    case 0: return L10n.text("Place the front of the next sheet under the camera.")
    case 1: return L10n.text("Front saved · Turn over, or press Finish sheet")
    default: return L10n.text("Both sides saved · Press Finish sheet")
    }
  }

  func finishSheet() {
    guard isSheetBatch, !busy, !document.pages.isEmpty else { return }
    guard rejectedScans.isEmpty else {
      beginReview()
      showRejected = true
      return
    }
    finishItem(nextSheet: true)
  }

  func createNextSheet(resumeCapture: Bool) throws {
    guard let details = document.metadata, isSheetBatch else { return }
    try createItem(title: "", metadata: details.nextLetter, scanPages: true,
                   preserveCaptureHistory: true)
    // Keep the recent fingerprints across the boundary. The finished sheet may
    // still be under the camera while its label is attached.
    autoCapture = resumeCapture && connected
    status = sheetCapturePrompt
  }

  func prepareSheetGroups() {
    guard !busy else { return }
    beginReview()
    showSheetGroups = true
  }

  // Settings last only for this batch and app run. A cancelled or failed print
  // keeps the current sheet open so that its label cannot be assigned to another.
  func printSheetLabel(_ label: DocumentLabel, qr: NSImage, upload: inout CloudUpload) throws {
    if printBatchID != document.metadata?.batchID {
      batchPrintInfo = nil
      printBatchID = document.metadata?.batchID
    }
    let info = batchPrintInfo ?? DocumentLabelView.labelPrintInfo()
    let view = DocumentLabelView(label: label, qr: qr)
    do {
      try upload.submitSheetLabel(in: folder) {
        view.printLabel(info: info, showPanel: batchPrintInfo == nil)
      }
      if let completed = view.completedPrintInfo { batchPrintInfo = completed }
    } catch {
      batchPrintInfo = nil
      throw error
    }
  }

  func confirmSheetLabelHandled() {
    guard isSheetBatch, !busy else { return }
    autoCapture = false
    let panel = NSAlert()
    panel.messageText = L10n.text("Confirm label handled?")
    panel.informativeText = L10n.text("Check that this sheet has its correct label. This clears an unknown print result without sending another print job.")
    panel.addButton(withTitle: L10n.text("Confirm label handled"))
    panel.addButton(withTitle: L10n.text("Cancel"))
    guard panel.runModal() == .alertFirstButtonReturn else { return }
    do {
      guard var upload = try CloudUpload.load(in: folder), upload.sheetLabelStarted == true else { return }
      upload.sheetLabelStarted = false
      upload.sheetLabelSubmitted = true
      try upload.save(in: folder)
    } catch { self.error = error.localizedDescription }
  }
}
