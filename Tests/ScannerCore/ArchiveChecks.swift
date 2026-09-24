import Foundation
import ScannerCore

private final class TestArchive: ArchiveTransport {
  var baseURL = ArchiveServer.production
  var requests: [ArchiveRequest] = []
  var response: (ArchiveRequest) throws -> Data = { _ in Data("{}".utf8) }
  func send(_ request: ArchiveRequest) async throws -> Data {
    requests.append(request)
    return try response(request)
  }
}

private func expectAsyncFailure(_ operation: () async throws -> Void) async {
  do { try await operation(); preconditionFailure("Expected operation to fail") } catch { }
}

extension ScannerCoreChecks {
  static func testSharedArchiveWorkflows() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let id = "11111111-1111-4111-8111-111111111111"
    let payload = Data(repeating: 42, count: 8 * 1024 * 1024 + 7)
    try payload.write(to: folder.appendingPathComponent("synthetic.pdf"))
    let api = TestArchive()
    var parts: [Int: Data] = [:]
    var failPart = true
    api.response = { request in
      let action = request.query.first { $0.name == "action" }?.value
      if action == "start" {
        try require(CloudUpload.load(in: folder)!.started, "Save intent before upload starts")
        return Data("{\"id\":\"\(id)\",\"partBytes\":8388608}".utf8)
      }
      if action == "complete" {
        guard parts.count == 2 else { throw CloudFailure(message: "Incomplete", status: 409) }
        return Data("{\"id\":\"\(id)\",\"state\":\"ready\"}".utf8)
      }
      if request.method == "PUT" {
        let part = Int(request.query.first { $0.name == "part" }!.value!)!
        if part == 2 && failPart { throw CloudFailure(message: "Retry", status: 503) }
        parts[part] = request.body!
        precondition(request.contentType == "application/octet-stream")
      }
      return Data("{}".utf8)
    }
    var upload = CloudUpload(fingerprint: "original", userID: "user", organisationID: id,
      file: "synthetic.pdf", name: "Synthetic.pdf")
    await expectAsyncFailure { try await upload.send(api: api, folder: folder) { _ in } }
    upload = try CloudUpload.load(in: folder)!
    precondition(upload.documentID == id && !upload.complete)
    failPart = false
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(upload.complete && parts[1]! + parts[2]! == payload)
    precondition(api.requests.filter { $0.query.contains(URLQueryItem(name: "action", value: "start")) }.count == 1)
    let count = api.requests.count
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(api.requests.count == count)
    upload.complete = false
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(api.requests.count == count + 1 && upload.complete, "Recover a lost completion reply")

    let unknownAPI = TestArchive()
    unknownAPI.response = { _ in throw CloudFailure(message: "Unknown start", status: 503) }
    var unknown = CloudUpload(fingerprint: "test", userID: "user", organisationID: id,
      file: "synthetic.pdf", name: "test.pdf")
    await expectAsyncFailure { try await unknown.send(api: unknownAPI, folder: folder) { _ in } }
    unknown = try CloudUpload.load(in: folder)!
    await expectAsyncFailure { try await unknown.send(api: unknownAPI, folder: folder) { _ in } }
    precondition(unknownAPI.requests.count == 1, "Do not repeat an uncertain start")
    var denied = CloudUpload(fingerprint: "test", userID: "user", organisationID: id,
      file: "synthetic.pdf", name: "test.pdf")
    unknownAPI.response = { _ in throw CloudFailure(message: "Denied", status: 401) }
    await expectAsyncFailure { try await denied.send(api: unknownAPI, folder: folder) { _ in } }
    try require(CloudUpload.load(in: folder)!.started == false)
    let wrongServer = TestArchive()
    wrongServer.baseURL = URL(string: "https://staging.example.com")!
    await expectAsyncFailure { try await upload.send(api: wrongServer, folder: folder) { _ in } }
    precondition(wrongServer.requests.isEmpty)
    expectFailure { _ = try CloudUpload.reusable(upload, fingerprint: "original", userID: "other", organisationID: id, api: api) }
    var pending = upload
    pending.complete = false
    expectFailure { _ = try CloudUpload.reusable(pending, fingerprint: "changed", userID: "user", organisationID: id, api: api) }

    var document = ScanDocument(title: "Synthetic")
    let fingerprint = try CloudUpload.fingerprintData(document)
    document.metadata = ItemMetadata(webLink: "https://example.com")
    document.automation = SessionAutomation(upload: true, printLabel: true)
    try require(CloudUpload.fingerprintData(document) == fingerprint)
    precondition(CloudUpload.pdfName(for: "A/\\B\n") == "AB.pdf")
    precondition(ArchiveServer.normalizedOrigin(" HTTPS://EXAMPLE.COM:443/ ") == URL(string: "https://example.com"))
    precondition(ArchiveServer.normalizedOrigin("https://user:password@example.com") == nil)
    try await testSharedLabels(folder: folder, upload: upload, api: api)
    print("PASS: shared multipart bytes and retries, persisted intent, server/account guards, upload fingerprint policy")
  }

  private static func testSharedLabels(folder: URL, upload original: CloudUpload, api: TestArchive) async throws {
    var upload = original
    var linked = false
    var conflict = false
    var loseReservation = true
    var reservations: [String] = []
    let code = "abcdefghijklmnop"
    func labelData() throws -> Data {
      var label: [String: Any] = ["code": code, "url": api.baseURL.absoluteString + "/d/" + code,
        "organisationId": upload.organisationID, "revision": linked || conflict ? 1 : 0,
        "status": linked ? "ready" : "pending"]
      if linked { label["documentId"] = upload.documentID! }
      return try JSONSerialization.data(withJSONObject: label)
    }
    // Capture fixed IDs, not the mutating upload value, in the transport callback.
    let archiveID = upload.organisationID
    let documentID = upload.documentID!
    api.response = { request in
      if request.method == "POST" && request.path.hasSuffix("/labels") {
        let body = try JSONDecoder().decode([String: String].self, from: request.body!)
        let requestID = body["requestId"]!
        try require(CloudUpload.load(in: folder)!.labelRequestID == requestID)
        reservations.append(requestID)
        if loseReservation { loseReservation = false; throw CloudFailure(message: "Lost reply") }
      }
      if request.method == "PATCH" {
        precondition(request.revision == 0)
        let body = try JSONDecoder().decode([String: String].self, from: request.body!)
        precondition(body["documentId"] == documentID)
        linked = true
        throw CloudFailure(message: "Lost attachment reply")
      }
      var data: [String: Any] = ["code": code, "url": api.baseURL.absoluteString + "/d/" + code,
        "organisationId": archiveID, "revision": linked || conflict ? 1 : 0,
        "status": linked ? "ready" : "pending"]
      if linked { data["documentId"] = documentID }
      return try JSONSerialization.data(withJSONObject: data)
    }
    await expectAsyncFailure { try await upload.reserveLabel(api: api, folder: folder, title: "Test") }
    upload = try CloudUpload.load(in: folder)!
    try await upload.reserveLabel(api: api, folder: folder, title: "Test")
    precondition(reservations.count == 2 && reservations[0] == reservations[1])
    try await upload.attachLabel(api: api, folder: folder)
    precondition(upload.permanentLabel?.status == "ready" && upload.link?.hasSuffix(code) == true)
    let count = api.requests.count
    try await upload.attachLabel(api: api, folder: folder)
    precondition(api.requests.count == count + 1)
    expectFailure { _ = try CloudUpload.reusable(upload, fingerprint: "changed", userID: upload.userID, organisationID: archiveID, api: api) }
    // A server revision change must stop before any PATCH.
    linked = false
    conflict = false
    upload.permanentLabel = try JSONDecoder().decode(PermanentLabel.self, from: labelData())
    conflict = true
    let patchCount = api.requests.filter { $0.method == "PATCH" }.count
    await expectAsyncFailure { try await upload.attachLabel(api: api, folder: folder) }
    precondition(api.requests.filter { $0.method == "PATCH" }.count == patchCount)
    print("PASS: shared label reservation identity, lost PATCH recovery, and revision conflict guard")
  }

  static func testSharedPrinterRules() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    var upload = CloudUpload(fingerprint: "test", userID: "user", organisationID: "archive", file: "test.pdf", name: "test.pdf")
    var jobs = 0
    expectFailure { try upload.submitSheetLabel(in: folder) { jobs += 1; return false } }
    precondition(jobs == 1 && upload.sheetLabelStarted == false)
    try upload.beginDirectLabel(in: folder)
    try require(CloudUpload.load(in: folder)!.labelNeedsReview)
    try upload.finishDirectLabel(in: folder, completed: false, mayHavePrinted: true)
    upload = try CloudUpload.load(in: folder)!
    expectFailure { try upload.submitSheetLabel(in: folder) { jobs += 1; return true } }
    precondition(jobs == 1)
    try upload.confirmLabelHandled(in: folder)
    try upload.submitSheetLabel(in: folder) { jobs += 1; return true }
    precondition(jobs == 1, "User confirmation must not send another print job")
    var blocked = CloudUpload(fingerprint: "test", userID: "user", organisationID: "archive", file: "test.pdf", name: "test.pdf")
    expectFailure { try blocked.submitSheetLabel(in: folder.appendingPathComponent("missing")) { jobs += 1; return true } }
    precondition(jobs == 1, "Do not print if saving intent failed")
    let raster = try QL600Raster.encode(width: 696, height: 225) { x, y in y == 0 && (x == 0 || x == 695) }
    precondition(raster.count == 21162 && raster.last == 0x1a)
    precondition(Array(raster[236..<239]) == [0x67, 0, 90])
    precondition(raster[239 + 1] == 0x08 && raster[239 + 88] == 0x10)
    precondition(raster[239] == 0 && raster[239 + 89] == 0, "Keep physical edge margins")
    precondition(raster[(236 + 93 + 3)..<(236 + 93 + 93)].allSatisfy { $0 == 0 })
    expectFailure { _ = try QL600Raster.encode(width: 1, height: 1) { _, _ in false } }
    print("PASS: shared print intent, unknown-result guard, no-repeat confirmation, and QL-600 raster bytes")
  }
}
