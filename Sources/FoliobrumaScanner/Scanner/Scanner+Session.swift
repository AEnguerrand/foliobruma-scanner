import ScannerCore
import AppKit

extension Scanner {
  func prepareFolder() throws {
    try SessionStore(folder: folder).prepare()
    if tracksActiveSession { UserDefaults.standard.set(folder.path, forKey: "activeSession") }
  }
  func restore() throws {
    if let restored = try SessionStore(folder: folder).loadIfPresent() {
      document = restored
      sessionSaved = true
    }
  }
  func commit(_ next: ScanDocument) throws {
    try SessionStore(folder: folder).save(next)
    document = next
    sessionSaved = true
    pdfIsCurrent = false
  }
  func persist() throws { try commit(document) }
  func image(_ p: ScanPage) -> NSImage? {
    NSImage(contentsOf: folder.appendingPathComponent(p.file))
  }
  func rotate(_ page: ScanPage) {
    guard !busy, let next = document.rotating(page) else { return }
    do { try commit(next) } catch { self.error = error.localizedDescription }
  }
  func remove(_ page: ScanPage) {
    guard !busy, let removal = document.removing(page) else { return }
    let next = removal.document
    let index = removal.index
    do {
      try commit(next)
      deleting = (page, index)
      if selected == page.id {
        selected = next.pages.isEmpty ? nil : next.pages[min(index, next.pages.count - 1)].id
      }
      status = L10n.text("Page removed · Undo available")
    } catch { self.error = error.localizedDescription }
  }
  func undo() {
    guard !busy, let removed = deleting else { return }
    let next = document.restoring(removed.page, at: removed.index)
    do {
      try commit(next)
      deleting = nil
      if reviewing { selected = removed.page.id }
      status = L10n.text("Page restored")
    } catch { self.error = error.localizedDescription }
  }
  func newDocument() {
    guard !busy else { return }
    if tracksActiveSession, uploadOnFinish, !document.pages.isEmpty {
      finishItem(nextDocument: true)
    } else { newDocumentLocally() }
  }
  func newDocumentLocally() {
    guard !busy else { return }
    autoCapture = false
    do {
      try createDocument(ScanDocument())
      status = L10n.text("New document · Previous session kept on disk")
    } catch { self.error = error.localizedDescription }
  }
  // Change the active record only after its manifest has been written.
  func createDocument(_ next: ScanDocument, preserveCaptureHistory: Bool = false) throws {
    try persist()
    let store = try SessionStore.create(next, in: root)
    folder = store.folder
    document = next
    resetWorkspace()
    sessionSaved = true
    selected = nil
    lastPDF = nil
    deleting = nil
    duplicateWarning = false
    duplicateFeedback.reset()
    qualityWarning = nil
    rejectedURL = nil
    if tracksActiveSession { UserDefaults.standard.set(folder.path, forKey: "activeSession") }
    if !preserveCaptureHistory { seedRecentPages() }
  }
  func openSession() {
    guard !busy else { return }
    autoCapture = false
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.directoryURL = root.appendingPathComponent("Sessions")
    panel.message = L10n.text("Choose a Foliobruma session folder.")
    if panel.runModal() == .OK, let u = panel.url {
      openSession(at: u)
    }
  }
}
