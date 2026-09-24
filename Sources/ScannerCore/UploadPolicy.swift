import Foundation

public extension CloudUpload {
  // Keep canonical input shared; the platform supplies SHA-256.
  static func fingerprintData(_ document: ScanDocument) throws -> Data {
    var copy = document
    if copy.metadata == nil { copy.metadata = ItemMetadata() }
    copy.metadata?.webLink = ""
    copy.automation = nil
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try encoder.encode(copy)
  }

  static func pdfName(for title: String) -> String {
    let safeTitle = String(title.unicodeScalars.filter {
      !CharacterSet.controlCharacters.contains($0) && $0 != "/" && $0 != "\\"
    }.map(String.init).joined().prefix(110))
    return safeTitle + ".pdf"
  }

  // nil permits a new PDF; a returned record must reuse its exact saved PDF.
  static func reusable(_ previous: Self?, fingerprint: String, userID: String,
                       organisationID: String, api: any ArchiveTransport) throws -> Self? {
    try previous?.requireServer(api)
    if let saved = previous, !saved.complete || saved.fingerprint == fingerprint {
      guard saved.userID == userID, saved.organisationID == organisationID else {
        throw CloudFailure(message: "This item has an upload in another account or archive. Select its original destination to continue.")
      }
      guard saved.fingerprint == fingerprint else {
        throw CloudFailure(message: "The pages changed during an incomplete upload. Clear its upload record before uploading the changed item.")
      }
      return saved
    }
    guard previous?.permanentLabel == nil else {
      throw CloudFailure(message: "This item already has a permanent label. Replace its PDF on the website to keep the same label.")
    }
    return nil
  }

  // Call only after the user has checked the physical label. This sends no job.
  mutating func confirmLabelHandled(in folder: URL) throws {
    guard labelNeedsReview else { return }
    sheetLabelStarted = false
    sheetLabelSubmitted = true
    try save(in: folder)
  }
}
