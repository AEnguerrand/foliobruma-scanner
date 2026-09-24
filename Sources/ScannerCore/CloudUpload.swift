import Foundation

// The sidecar records the destination before upload. It contains no account credentials.
public struct CloudUpload: Codable {
  public var fingerprint: String
  public var userID: String
  public var organisationID: String
  public var documentID: String?
  public var serverOrigin: String?
  public var labelRequestID: String?
  public var permanentLabel: PermanentLabel?
  public var started = false
  public var complete = false
  public var labelOffered = false
  public var sheetLabelStarted: Bool?
  public var sheetLabelSubmitted: Bool?
  public var file: String
  public var name: String

  public init(fingerprint: String, userID: String, organisationID: String, file: String, name: String) {
    self.fingerprint = fingerprint
    self.userID = userID
    self.organisationID = organisationID
    self.file = file
    self.name = name
  }

  public var path: String { "api/organisations/\(organisationID)/documents" }
  public var link: String? {
    if let permanentLabel { return permanentLabel.url }
    guard complete, let documentID, let origin else { return nil }
    return origin.appendingPathComponent(path + "/" + documentID).absoluteString
  }
  public var origin: URL? { ArchiveServer.normalizedOrigin(serverOrigin ?? ArchiveServer.production.absoluteString) }
  public func requireServer(_ api: any ArchiveTransport) throws {
    guard (serverOrigin ?? ArchiveServer.production.absoluteString) == api.baseURL.absoluteString else {
      throw CloudFailure(message: "This upload belongs to another server. Switch back to its server before continuing.")
    }
  }
  public static func load(in folder: URL) throws -> CloudUpload? {
    let url = folder.appendingPathComponent("cloud-upload.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }
  public func save(in folder: URL) throws {
    try JSONEncoder().encode(self).write(to: folder.appendingPathComponent("cloud-upload.json"), options: .atomic)
  }
  public var labelNeedsReview: Bool { sheetLabelStarted == true || (sheetLabelSubmitted == nil && labelOffered) }

  // Save the intent before submitting a print job. After a crash, do not
  // silently send another label when the result of the earlier job is unknown.
  public mutating func submitSheetLabel(in folder: URL, submit: () -> Bool) throws {
    if sheetLabelSubmitted == true { return }
    guard !labelNeedsReview else {
      throw CloudFailure(message: "The label print result is unknown. Check the printer, then use Create label to print it if needed. Use Confirm label handled to continue.")
    }
    sheetLabelStarted = true
    try save(in: folder)
    let submitted = submit()
    sheetLabelStarted = false
    sheetLabelSubmitted = submitted
    try save(in: folder)
    guard submitted else {
      throw CloudFailure(message: "Label printing stopped. Check the printer, then finish the item again to retry. The item is still open.")
    }
  }

  public mutating func beginDirectLabel(in folder: URL) throws {
    guard sheetLabelSubmitted != true, !labelNeedsReview else {
      throw CloudFailure(message: "The label print result is unknown. Check the printer, then use Create label to print it if needed. Use Confirm label handled to continue.")
    }
    sheetLabelStarted = true
    try save(in: folder)
  }

  public mutating func finishDirectLabel(in folder: URL, completed: Bool, mayHavePrinted: Bool) throws {
    sheetLabelSubmitted = completed
    sheetLabelStarted = !completed && mayHavePrinted
    try save(in: folder)
  }

  // Parts and completion are idempotent on the server. Reuse the exact PDF on retry.
  public mutating func send(api: any ArchiveTransport, folder: URL, progress: @escaping (Double) async -> Void) async throws {
    try requireServer(api)
    if complete { return }
    let handle = try FileHandle(forReadingFrom: folder.appendingPathComponent(file))
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    try handle.seek(toOffset: 0)
    guard size > 0, size <= 500 * 1024 * 1024 else { throw CloudFailure(message: "The upload PDF is missing or too large.") }
    if documentID == nil {
      guard !started else {
        throw CloudFailure(message: "The upload start was not confirmed. Check the archive on the website before clearing the upload record.")
      }
      started = true
      try save(in: folder)
      struct Start: Decodable { let id: String; let partBytes: Int }
      let data: Data
      do {
        data = try await api.request(path, method: "POST", query: [
          URLQueryItem(name: "action", value: "start"), URLQueryItem(name: "name", value: name),
          URLQueryItem(name: "size", value: String(size))])
      } catch {
        // Explicit client errors do not create an upload. Network and server failures are uncertain.
        if let failure = error as? CloudFailure, let status = failure.status,
           (400..<500).contains(status) {
          started = false
          try save(in: folder)
        }
        throw error
      }
      let result = try JSONDecoder().decode(Start.self, from: data)
      guard UUID(uuidString: result.id) != nil, result.partBytes == 8 * 1024 * 1024 else {
        throw CloudFailure(message: "The server response is invalid.")
      }
      documentID = result.id
      try save(in: folder)
    }
    let destination = path + "/" + documentID!
    // A lost completion response can leave a ready document. Completion is safe to retry.
    struct Completion: Decodable { let id: String; let state: String }
    func confirm() async throws -> Bool {
      let data = try await api.request(destination, method: "POST", query: [URLQueryItem(name: "action", value: "complete")])
      let result = try JSONDecoder().decode(Completion.self, from: data)
      return result.id == documentID && result.state == "ready"
    }
    if (try? await confirm()) != true {
      var sent = 0
      var part = 1
      while let bytes = try handle.read(upToCount: 8 * 1024 * 1024), !bytes.isEmpty {
        _ = try await api.request(destination, method: "PUT", body: bytes, type: "application/octet-stream",
                                  query: [URLQueryItem(name: "part", value: String(part))])
        sent += bytes.count
        part += 1
        await progress(Double(sent) / Double(size))
      }
      guard try await confirm() else { throw CloudFailure(message: "The server did not confirm the upload.") }
    }
    complete = true
    try save(in: folder)
  }
}
