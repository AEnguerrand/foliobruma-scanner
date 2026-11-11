import AppKit
import ScannerCore

@MainActor final class LocationLabelPrinter: ObservableObject {
  @Published private(set) var request: LocationLabelRequest?
  @Published private(set) var qr: NSImage?
  @Published private(set) var printing = false
  @Published private(set) var state: LabelPrintStore.State?
  @Published private(set) var failure: String?
  @Published private(set) var printed = false
  private let folder: URL
  private let send: @Sendable (Data) async throws -> Void

  init(folder: URL? = nil, send: @escaping @Sendable (Data) async throws -> Void = { job in
    try await Task.detached(priority: .userInitiated) { try QL600Printer.send(job) }.value
  }) {
    self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sovenelia Scanner/Location Labels", isDirectory: true)
    self.send = send
  }

  var label: DocumentLabel? {
    request.map { DocumentLabel(title: $0.title, subtitle: L10n.text("Binder / box"), link: $0.link) }
  }

  // Opening a link only prepares the preview. The user must press Print.
  func prepare(_ request: LocationLabelRequest) {
    guard !printing else { return }
    self.request = request
    qr = nil
    printed = false
    failure = nil
    state = nil
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      state = try LabelPrintStore.state(in: folder, link: request.link)
      qr = label?.qrImage()
      if qr == nil { throw CloudFailure(message: "Could not create the QR code.") }
    } catch { failure = L10n.text(error.localizedDescription) }
  }

  func printLabel(reprint: Bool = false) async {
    guard !printing, qr != nil, failure == nil, let request, let label else { return }
    printing = true
    printed = false
    defer {
      printing = false
      do { state = try LabelPrintStore.state(in: folder, link: request.link) }
      catch { failure = L10n.text(error.localizedDescription); qr = nil }
    }
    do {
      let job = try QL600Printer.raster(QL600Printer.bitmap(label))
      let ticket = try LabelPrintStore.begin(in: folder, link: request.link, reprint: reprint, lock: MacLibraryLock())
      do { try await send(job) }
      catch {
        try LabelPrintStore.finish(ticket, in: folder, submitted: false,
          mayHavePrinted: (error as? QL600Failure)?.sent ?? true, lock: MacLibraryLock())
        throw error
      }
      try LabelPrintStore.finish(ticket, in: folder, submitted: true, mayHavePrinted: true, lock: MacLibraryLock())
      printed = true
    } catch { failure = L10n.text(error.localizedDescription) }
  }

  func retryPreparation() {
    if let request { prepare(request) }
  }
}
