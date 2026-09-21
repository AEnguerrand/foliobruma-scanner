import AppKit

extension Scanner {
  func prepareFolder() throws {
    try FileManager.default.createDirectory(
      at: folder.appendingPathComponent("Originals"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: folder.appendingPathComponent("Pages"), withIntermediateDirectories: true)
    if tracksActiveSession { UserDefaults.standard.set(folder.path, forKey: "activeSession") }
  }
  func restore() throws {
    let u = folder.appendingPathComponent("session.json")
    if FileManager.default.fileExists(atPath: u.path) {
      document = try JSONDecoder().decode(ScanDocument.self, from: Data(contentsOf: u))
      sessionSaved = true
    }
  }
  func commit(_ next: ScanDocument) throws {
    try JSONEncoder().encode(next).write(
      to: folder.appendingPathComponent("session.json"), options: .atomic)
    document = next
    sessionSaved = true
    pdfIsCurrent = false
  }
  func persist() throws { try commit(document) }
  func image(_ p: ScanPage) -> NSImage? {
    NSImage(contentsOf: folder.appendingPathComponent(p.file))
  }
  func rotate(_ page: ScanPage) {
    guard !busy, let i = document.pages.firstIndex(where: { $0.id == page.id }) else { return }
    var next = document
    next.pages[i].rotation = (page.rotation + 90) % 360
    do { try commit(next) } catch { self.error = error.localizedDescription }
  }
  func remove(_ page: ScanPage) {
    guard !busy, let index = document.pages.firstIndex(where: { $0.id == page.id }) else { return }
    var next = document
    next.pages.remove(at: index)
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
    guard !sheetIsFull else {
      error = L10n.text("Remove a side before restoring this side. A sheet can have only two sides.")
      return
    }
    var next = document
    next.pages.insert(removed.page, at: min(removed.index, next.pages.count))
    do {
      try commit(next)
      deleting = nil
      if reviewing { selected = removed.page.id }
      status = L10n.text("Page restored")
    } catch { self.error = error.localizedDescription }
  }
  func newDocument() {
    guard !busy else { return }
    if tracksActiveSession, UserDefaults.standard.bool(forKey: "cloudAutomatic"), !document.pages.isEmpty {
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
    let nextFolder = root.appendingPathComponent("Sessions/" + UUID().uuidString)
    try FileManager.default.createDirectory(
      at: nextFolder.appendingPathComponent("Originals"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: nextFolder.appendingPathComponent("Pages"), withIntermediateDirectories: true)
    try JSONEncoder().encode(next).write(
      to: nextFolder.appendingPathComponent("session.json"), options: .atomic)
    folder = nextFolder
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
