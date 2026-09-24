import ScannerCore
import AppKit
import CoreImage

extension Scanner {
  var rejectedScans: [RejectedScan] { document.rejected ?? [] }
  var selectedIndex: Int? { document.pages.firstIndex { $0.id == selected } }
  var selectedPage: ScanPage? { selectedIndex.map { document.pages[$0] } }

  func beginReview(_ id: String? = nil) {
    autoCapture = false
    replacementID = nil
    if busy {
      pendingReview = true
      return
    }
    metadataWorkspace = false
    reviewing = true
    selected = id ?? selected ?? document.pages.first?.id
    captureSaved = false
    status = L10n.text("Capture paused · Review your pages")
  }
  func finishPendingReview() {
    if pendingReview {
      pendingReview = false
      beginReview()
    }
  }
  func showCamera() {
    guard !busy else { return }
    metadataWorkspace = false
    reviewing = false
    selected = nil
    autoCapture = false
    status = connected ? L10n.text("Capture paused · Ready when you are") : L10n.text("Select a camera to scan")
  }
  func pageIndex(for text: String) -> Int? {
    document.pageIndex(for: text)
  }
  func goToPage(_ text: String) {
    guard !busy, let index = pageIndex(for: text) else { return }
    beginReview(document.pages[index].id)
  }
  func navigatePage(_ delta: Int) {
    guard !busy, let index = selectedIndex else { return }
    let next = index + delta
    guard document.pages.indices.contains(next) else { return }
    beginReview(document.pages[next].id)
  }
  func movePage(_ delta: Int) {
    guard !busy, let selected, let next = document.movingPage(id: selected, by: delta) else { return }
    do { try commit(next) } catch { self.error = error.localizedDescription }
  }
  func replaceSelectedPage() {
    guard !busy, let page = selectedPage else { return }
    autoCapture = false
    replacementID = page.id
    metadataWorkspace = false
    reviewing = false
    selected = nil
    status = L10n.text("Place one page under the camera, then capture its replacement")
  }
  func applyCapture(_ pages: [ScanPage], replacing id: String?, resolving rejected: String?) throws
  {
    try commit(document.applyingCapture(pages, replacing: id, resolving: rejected))
  }

  func resetWorkspace() {
    metadataWorkspace = false
    reviewing = false
    selected = nil
    replacementID = nil
    captureReplacementID = nil
    pendingReview = false
    keptRejection = nil
    qualityWarning = nil
    rejectedURL = nil
    captureSaved = false
    duplicateWarning = false
    lastPDF = nil
    pdfIsCurrent = false
    deleting = nil
    framingImages = []
    captureOptions = nil
  }
  func openSession(at url: URL) {
    guard !busy else { return }
    autoCapture = false
    do {
      let restored = try SessionStore(folder: url).load()
      folder = url
      document = restored
      if isSheetBatch { book = false; split = false }
      resetWorkspace()
      sessionSaved = true
      loadLegacyRejections()
      if tracksActiveSession { UserDefaults.standard.set(url.path, forKey: "activeSession") }
      seedRecentPages()
      beginReview()
      metadataWorkspace = restored.pages.isEmpty && restored.metadata != nil
      showSessions = false
    } catch { self.error = L10n.text("This folder does not contain a valid scanner session.") }
  }
  func browseSessions() {
    guard !busy else { return }
    autoCapture = false
    showSessions = true
    loadingSessions = true
    let base = root
    DispatchQueue.global(qos: .userInitiated).async {
      let items = SessionStore.list(in: base).map { record in
        SavedSession(folder: record.folder, title: record.document.displayTitle,
          pageCount: record.document.pages.count, modified: record.modified,
          reference: record.document.metadata?.reference, batchName: record.document.metadata?.batchName)
      }
      DispatchQueue.main.async {
        self.sessions = items
        self.loadingSessions = false
      }
    }
  }
  func loadLegacyRejections() {
    document = SessionStore(folder: folder).recoveringRejections(in: document)
  }

  func reviewRejected(_ scan: RejectedScan) {
    guard !busy else { return }
    autoCapture = false
    qualityWarning = L10n.text(scan.reason)
    rejectedURL = folder.appendingPathComponent(scan.file)
    captureOptions = (scan.quad, scan.split, scan.divider, false)
    captureReplacementID = scan.replacementID
    showRejected = true
  }
  func dismissRejected(_ scan: RejectedScan) {
    guard !busy else { return }
    let next = document.resolvingRejection(scan.file)
    do {
      try commit(next)
      if rejectedURL?.lastPathComponent == URL(fileURLWithPath: scan.file).lastPathComponent {
        rejectedURL = nil
        qualityWarning = nil
      }
    } catch { self.error = error.localizedDescription }
  }
  func prepareExport() {
    guard !busy, !document.pages.isEmpty else { return }
    autoCapture = false
    showExport = true
  }
}
