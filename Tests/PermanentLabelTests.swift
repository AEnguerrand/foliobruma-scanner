#if SCANNER_TESTS
import Foundation

private final class LabelStub: URLProtocol {
  static let archive = "11111111-1111-1111-1111-111111111111"
  static let document = "22222222-2222-2222-2222-222222222222"
  static var failReservation = true
  static var failAttachment = true
  static var linked: String?
  static var revision = 0
  static var requestIDs: [String] = []
  static var patches = 0
  static var invalidURL = false
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    var status = 200
    if request.httpMethod == "POST" {
      var data = request.httpBody ?? Data()
      if let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
          let count = stream.read(&buffer, maxLength: buffer.count)
          if count <= 0 { break }
          data.append(contentsOf: buffer.prefix(count))
        }
      }
      let body = try! JSONDecoder().decode([String: String].self, from: data)
      precondition(body["requestId"]!.range(of: "^[a-f0-9-]{36}$", options: .regularExpression) != nil,
        "Reservation IDs must match the SaaS lowercase UUID contract")
      Self.requestIDs.append(body["requestId"]!)
      if Self.failReservation { status = 503; Self.failReservation = false }
    }
    if request.httpMethod == "PATCH" {
      precondition(request.value(forHTTPHeaderField: "If-Match") == "\"0\"")
      Self.patches += 1
      Self.linked = Self.document
      Self.revision = 1
      if Self.failAttachment { status = 503; Self.failAttachment = false }
    }
    let code = "0123456789abcdef"
    let body: [String: Any] = ["code": code, "url": Self.invalidURL ? "https://example.com/d/" + code : "https://foliobruma.com/d/" + code,
      "organisationId": Self.archive, "documentId": Self.linked as Any? ?? NSNull(),
      "revision": Self.revision, "status": Self.linked == nil ? "pending" : "ready"]
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: body))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

enum PermanentLabelTests {
 static func run() throws {
  var done = false
  var error: Error?
  Task { @MainActor in
    do { try await exercise() } catch let failure { error = failure }
    done = true
  }
  let deadline = Date().addingTimeInterval(20)
  while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
  precondition(done)
  if let error { throw error }
  print("PASS: permanent label reservation retry, lost attachment response, stable URL, website-edit guard, server URL validation")
 }
 static func exercise() async throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent("label-api-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [LabelStub.self]
  let api = CloudAPI(configuration: configuration)
  var upload = CloudUpload(fingerprint: "test", userID: "test", organisationID: LabelStub.archive, file: "test.pdf", name: "test.pdf")
  upload.labelRequestID = "ABCDEFAB-1234-4321-ABCD-123456ABCDEF"
  do { try await upload.reserveLabel(api: api, folder: folder, title: "Test"); preconditionFailure() } catch { }
  upload = try CloudUpload.load(in: folder)!
  let requestID = upload.labelRequestID!
  precondition(requestID == "abcdefab-1234-4321-abcd-123456abcdef")
  try await upload.reserveLabel(api: api, folder: folder, title: "Test")
  precondition(LabelStub.requestIDs == [requestID, requestID])
  let url = upload.link
  upload.complete = true
  upload.documentID = LabelStub.document
  try await upload.attachLabel(api: api, folder: folder)
  upload = try CloudUpload.load(in: folder)!
  precondition(upload.permanentLabel?.documentId == LabelStub.document && upload.link == url)
  try await upload.attachLabel(api: api, folder: folder)
  precondition(LabelStub.patches == 1)
  LabelStub.linked = "33333333-3333-3333-3333-333333333333"
  do { try await upload.attachLabel(api: api, folder: folder); preconditionFailure("Do not overwrite website changes") } catch { }
  precondition(LabelStub.patches == 1)
  LabelStub.invalidURL = true
  do { try await upload.attachLabel(api: api, folder: folder); preconditionFailure("Reject an unexpected link origin") } catch { }
 }
}
#endif
