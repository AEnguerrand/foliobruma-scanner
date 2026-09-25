import ScannerCore
import AppKit

extension Scanner {
  var finishActionTitle: String {
    L10n.text(isSheetBatch ? "Finish sheet" : (document.metadata?.batchID != nil ? "Next letter" : "Finish item"))
  }

  func finishCurrentItem() {
    if isSheetBatch { finishSheet() }
    else if document.metadata?.batchID != nil { nextLetter() }
    else { finishItem() }
  }

  func prepareNewItem() {
    guard !busy else { return }
    autoCapture = false
    showNewItem = true
  }

  func createItem(title: String, metadata: ItemMetadata, scanPages: Bool, preserveCaptureHistory: Bool = false, automation: SessionAutomation? = nil) throws {
    guard !busy else { return }
    autoCapture = false
    var details = metadata
    details.reference = try ItemReference.reserve(in: root, letter: details.batchID != nil)
    var next = ScanDocument()
    next.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    next.metadata = details
    next.automation = automation
    try createDocument(next, preserveCaptureHistory: preserveCaptureHistory)
    metadataWorkspace = !scanPages
    if details.batchID != nil { book = false; split = false }
    status = L10n.text("Item saved on this Mac")
  }

  func saveMetadata(title: String, metadata: ItemMetadata) throws {
    guard !busy else { return }
    var details = metadata
    if let current = document.metadata {
      details.reference = current.reference
      details.batchID = current.batchID
      details.sheetBatch = current.sheetBatch
    } else {
      details.reference = try ItemReference.reserve(in: root, letter: false)
    }
    var next = document
    next.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    next.metadata = details
    let wasCurrent = pdfIsCurrent
    try commit(next)
    pdfIsCurrent = wasCurrent
    status = L10n.text("Item saved on this Mac")
  }

  func nextLetter() {
    if isSheetBatch { finishSheet(); return }
    guard !busy, document.metadata?.batchID != nil else { return }
    if tracksActiveSession, uploadOnFinish, !document.pages.isEmpty {
      finishItem(nextLetter: true)
    } else { createNextLetter() }
  }

  func createNextLetter() {
    guard !busy, let details = document.metadata, details.batchID != nil else { return }
    let scanPages = !metadataWorkspace
    do {
      try createItem(title: "", metadata: details.nextLetter, scanPages: scanPages, automation: document.automation)
    } catch { self.error = error.localizedDescription }
  }

  func showItemMetadata() {
    guard !busy else { return }
    autoCapture = false
    showMetadata = true
  }

  func showItemLabel() {
    guard !busy else { return }
    autoCapture = false
    showLabel = true
  }

  func showCatalog() {
    guard !busy else { return }
    beginReview()
    metadataWorkspace = true
  }
}
