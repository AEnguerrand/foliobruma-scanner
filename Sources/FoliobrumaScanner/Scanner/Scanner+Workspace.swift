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
    guard let number = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
      number > 0, number <= document.pages.count else { return nil }
    return number - 1
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
    guard !busy, let index = selectedIndex else { return }
    let nextIndex = index + delta
    guard document.pages.indices.contains(nextIndex) else { return }
    var next = document
    next.pages.swapAt(index, nextIndex)
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
    var next = document
    if let id = id {
      guard pages.count == 1, let index = next.pages.firstIndex(where: { $0.id == id }) else {
        throw NSError(
          domain: "Scanner", code: 10,
          userInfo: [NSLocalizedDescriptionKey: L10n.text("The page to replace is no longer available.")])
      }
      var replacement = pages[0]
      replacement.id = id
      next.pages[index] = replacement
    } else {
      next.pages += pages
    }
    if let rejected = rejected {
      next.rejected?.removeAll { $0.file == rejected }
      next.resolvedRejections = Array(Set((next.resolvedRejections ?? []) + [rejected]))
    }
    try commit(next)
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
      let restored = try JSONDecoder().decode(
        ScanDocument.self,
        from: Data(contentsOf: url.appendingPathComponent("session.json")))
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
    let base = root.appendingPathComponent("Sessions")
    DispatchQueue.global(qos: .userInitiated).async {
      let folders =
        (try? FileManager.default.contentsOfDirectory(
          at: base,
          includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
      let items = folders.compactMap { url -> SavedSession? in
        let manifest = url.appendingPathComponent("session.json")
        guard let data = try? Data(contentsOf: manifest),
          let doc = try? JSONDecoder().decode(ScanDocument.self, from: data)
        else { return nil }
        let date =
          (try? manifest.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? .distantPast
        return SavedSession(
          folder: url, title: doc.displayTitle, pageCount: doc.pages.count, modified: date,
          reference: doc.metadata?.reference, batchName: doc.metadata?.batchName)
      }.sorted { $0.modified > $1.modified }
      DispatchQueue.main.async {
        self.sessions = items
        self.loadingSessions = false
      }
    }
  }
  func loadLegacyRejections() {
    let urls =
      (try? FileManager.default.contentsOfDirectory(
        at: folder.appendingPathComponent("Rejected"),
        includingPropertiesForKeys: nil)) ?? []
    let known = Set(rejectedScans.map(\.file) + (document.resolvedRejections ?? []))
    let recovered = urls.filter {
      $0.pathExtension.lowercased() == "jpg" && !known.contains("Rejected/" + $0.lastPathComponent)
    }.map {
      RejectedScan(
        file: "Rejected/" + $0.lastPathComponent,
        reason:
          "Recovered photo. Check it before keeping it. Earlier crop settings may be unavailable.",
        quad: nil, split: false, divider: 0.5)
    }
    document.rejected = rejectedScans + recovered
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
    var next = document
    next.rejected?.removeAll { $0.id == scan.id }
    next.resolvedRejections = Array(Set((next.resolvedRejections ?? []) + [scan.file]))
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
