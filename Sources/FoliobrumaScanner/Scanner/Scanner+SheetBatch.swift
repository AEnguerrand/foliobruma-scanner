import ScannerCore
import AppKit

extension Scanner {
  var isSheetBatch: Bool { document.isSheetBatch }
  var sheetCapturePrompt: String {
    switch document.pages.count {
    case 0: return L10n.text("Place the front of the next sheet under the camera.")
    default: return L10n.format("%ld captures saved · Show the next side or panel, or press Finish sheet", document.pages.count)
    }
  }

  func finishSheet() {
    guard isSheetBatch, !busy, !document.pages.isEmpty else { return }
    guard !document.sheetNeedsReview else {
      beginReview()
      showRejected = true
      return
    }
    finishItem(nextSheet: true)
  }

  func createNextSheet(resumeCapture: Bool) throws {
    guard let details = document.metadata, isSheetBatch else { return }
    let automation = document.automation
    try createItem(title: "", metadata: details.nextLetter, scanPages: true,
                   preserveCaptureHistory: true, automation: automation)
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

  var uploadOnFinish: Bool { document.uploadOnFinish }
  var printOnFinish: Bool { document.printOnFinish }

  func setSessionAutomation(_ value: SessionAutomation) {
    guard !busy else { return }
    do {
      var next = document
      next.automation = value
      let wasCurrent = pdfIsCurrent
      try commit(next)
      pdfIsCurrent = wasCurrent
    } catch { self.error = error.localizedDescription }
  }

  @MainActor func printSessionLabel(_ label: DocumentLabel, qr: NSImage, upload: inout CloudUpload) async throws {
    let name = document.automation?.printerName ?? ""
    if name == QL600Printer.destination {
      let job = try QL600Printer.raster(QL600Printer.bitmap(label))
      try upload.beginDirectLabel(in: folder)
      do {
        try await Task.detached(priority: .userInitiated) { try QL600Printer.send(job) }.value
        try upload.finishDirectLabel(in: folder, completed: true, mayHavePrinted: true)
      } catch {
        let mayHavePrinted = (error as? QL600Failure)?.sent ?? true
        try upload.finishDirectLabel(in: folder, completed: false, mayHavePrinted: mayHavePrinted)
        throw error
      }
      return
    }
    guard !name.isEmpty, NSPrinter.printerNames.contains(name), let printer = NSPrinter(name: name) else {
      throw CloudFailure(message: "Select an available label printer in the Foliobruma session settings. The item is still open.")
    }
    let info = DocumentLabelView.labelPrintInfo()
    info.printer = printer
    let view = DocumentLabelView(label: label, qr: qr)
    try upload.submitSheetLabel(in: folder) {
      view.printLabel(info: info, showPanel: false)
    }
  }

  func confirmSheetLabelHandled() {
    guard !busy else { return }
    autoCapture = false
    let panel = NSAlert()
    panel.messageText = L10n.text("Confirm label handled?")
    panel.informativeText = L10n.text("Check that this sheet has its correct label. This clears an unknown print result without sending another print job.")
    panel.addButton(withTitle: L10n.text("Confirm label handled"))
    panel.addButton(withTitle: L10n.text("Cancel"))
    guard panel.runModal() == .alertFirstButtonReturn else { return }
    do {
      guard var upload = try CloudUpload.load(in: folder), upload.labelNeedsReview else { return }
      try upload.confirmLabelHandled(in: folder)
    } catch { self.error = error.localizedDescription }
  }
}
