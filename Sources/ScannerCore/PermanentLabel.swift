import Foundation

public struct PermanentLabel: Codable {
  public let code: String
  public let url: String
  public let organisationId: String
  public let documentId: String?
  public let revision: Int
  public let status: String

  public func validate(archive: String, code expectedCode: String? = nil, origin: URL = ArchiveServer.production) throws {
    guard code.range(of: "^[A-Za-z0-9_-]{16}$", options: .regularExpression) != nil,
          url == origin.absoluteString + "/d/" + code,
          organisationId == archive, revision >= 0,
          expectedCode == nil || code == expectedCode,
          documentId == nil || UUID(uuidString: documentId!) != nil else {
      throw CloudFailure(message: "The server returned an invalid permanent label.")
    }
  }
}

public extension CloudUpload {
  mutating func reserveLabel(api: any ArchiveTransport, folder: URL, title: String) async throws {
    try requireServer(api)
    if let permanentLabel {
      try permanentLabel.validate(archive: organisationID, origin: api.baseURL)
      return
    }
    // The SaaS requires canonical lowercase UUIDs. Normalize old unsent retries too.
    let requestID = (labelRequestID ?? UUID().uuidString).lowercased()
    if labelRequestID != requestID { labelRequestID = requestID; try save(in: folder) }
    var body = ["title": String(title.prefix(110)), "requestId": labelRequestID!]
    if complete, let documentID { body["documentId"] = documentID }
    let response = try await api.request("api/organisations/\(organisationID)/labels", method: "POST",
      body: JSONEncoder().encode(body))
    let label = try JSONDecoder().decode(PermanentLabel.self, from: response)
    try label.validate(archive: organisationID, origin: api.baseURL)
    guard label.documentId == nil || label.documentId == documentID else {
      throw CloudFailure(message: "This label belongs to another PDF. Check it on the website.")
    }
    permanentLabel = label
    try save(in: folder)
  }

  mutating func attachLabel(api: any ArchiveTransport, folder: URL) async throws {
    try requireServer(api)
    guard complete, let documentID, let reserved = permanentLabel else {
      throw CloudFailure(message: "Finish the upload before attaching its permanent label.")
    }
    let path = "api/labels/" + reserved.code
    func read() async throws -> PermanentLabel {
      let value = try JSONDecoder().decode(PermanentLabel.self, from: await api.request(path))
      try value.validate(archive: organisationID, code: reserved.code, origin: api.baseURL)
      return value
    }
    let current = try await read()
    if current.documentId == documentID && current.status == "ready" {
      permanentLabel = current
      try save(in: folder)
      return
    }
    guard current.documentId == nil, current.status == "pending", current.revision == reserved.revision else {
      throw CloudFailure(message: "The label changed on the website. Check it before attaching this PDF.")
    }
    let linked: PermanentLabel
    do {
      let response = try await api.request(path, method: "PATCH",
        body: JSONEncoder().encode(["documentId": documentID]), revision: current.revision)
      linked = try JSONDecoder().decode(PermanentLabel.self, from: response)
    } catch {
      // A lost PATCH reply must not cause a second reservation or overwrite a website edit.
      let recovered = try await read()
      guard recovered.documentId == documentID, recovered.status == "ready" else { throw error }
      linked = recovered
    }
    try linked.validate(archive: organisationID, code: reserved.code, origin: api.baseURL)
    guard linked.documentId == documentID, linked.status == "ready" else {
      throw CloudFailure(message: "The server did not confirm the permanent label link.")
    }
    permanentLabel = linked
    try save(in: folder)
  }
}
