#if SCANNER_TESTS
import Foundation
import AppKit
import Vision
import CoreImage
import PDFKit

private final class CloudStub: URLProtocol {
  static var requests: [URLRequest] = []
  static var parts = 0
  static var failPart = true
  static var failStart = false
  static var startCode = 503
  static let id = "11111111-1111-4111-8111-111111111111"
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests.append(request)
    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let action = query.first { $0.name == "action" }?.value
    var code = 200
    var json = "{}"
    var headers = ["Content-Type": "application/json"]
    if request.url!.path.contains("sign-in") {
      headers["Set-Cookie"] = "__Secure-better-auth.session_token=test-only; Path=/; Secure; HttpOnly; Max-Age=604800"
    } else if action == "start" {
      if Self.failStart { code = Self.startCode }
      else { json = "{\"id\":\"\(Self.id)\",\"partBytes\":8388608}" }
    } else if action == "complete" {
      if Self.parts < 2 { code = 409 }
      else { json = "{\"id\":\"\(Self.id)\",\"state\":\"ready\"}" }
    } else if request.httpMethod == "PUT" {
      let part = query.first { $0.name == "part" }?.value
      if part == "2" && Self.failPart { code = 503 }
      else { Self.parts = max(Self.parts, Int(part!)!) }
    }
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(json.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

enum CloudUploadTests {
  static func run() throws {
    var done = false
    var failure: Error?
    Task { @MainActor in
      do { try await exercise() } catch { failure = error }
      done = true
    }
    let deadline = Date().addingTimeInterval(30)
    while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    precondition(done, "Cloud test timed out")
    if let failure { throw failure }
    print("PASS: browser pairing challenge, URL and expiry; isolated scanner credentials; multipart retry; lost completion response; uncertain start guard; upload record recovery; private QR decoding")
  }
  static func exercise() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sourceImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 80, height: 120))
    let sourceBitmap = NSBitmapImageRep(cgImage: CIContext().createCGImage(sourceImage, from: sourceImage.extent)!)
    let source = sourceBitmap.representation(using: .jpeg, properties: [:])!
    try source.write(to: folder.appendingPathComponent("page.jpg"))
    var pages = ScanDocument()
    pages.pages = [ScanPage(file: "page.jpg", original: "page.jpg", rotation: 90),
                   ScanPage(file: "page.jpg", original: "page.jpg", rotation: 180)]
    pages.rejected = [RejectedScan(file: "not-included.jpg", reason: "Test", split: false, divider: 0.5)]
    try CloudUpload.makePDF(pages, in: folder, file: "rendered.pdf")
    let rendered = PDFDocument(url: folder.appendingPathComponent("rendered.pdf"))!
    precondition(rendered.pageCount == 2 && rendered.page(at: 0)?.rotation == 90 && rendered.page(at: 1)?.rotation == 180)
    let original = try Data(contentsOf: folder.appendingPathComponent("page.jpg"))
    precondition(original == source, "Upload rendering must preserve source images")
    pages.pages.append(ScanPage(file: "missing.jpg", original: "missing.jpg"))
    do { try CloudUpload.makePDF(pages, in: folder, file: "failed.pdf"); preconditionFailure("Expected missing page failure") }
    catch { }
    precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("failed.pdf").path))
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CloudStub.self]
    let api = CloudAPI(configuration: configuration)
    let pairing = try CloudPairing.create()
    precondition(pairing.token.count == 68 && pairing.challenge.count == 64)
    try api.restore(JSONEncoder().encode(pairing.token))
    let ticket = CloudPairing.Ticket(challenge: pairing.challenge, expires: Date().timeIntervalSince1970 * 1000 + 300_000, signature: String(repeating: "a", count: 64))
    let browserURL = try pairing.browserURL(ticket: ticket)
    precondition(browserURL.host == "foliobruma.com" && browserURL.scheme == "https")
    precondition(!browserURL.absoluteString.contains(pairing.token), "Browser URLs must not contain the device secret")
    let wrong = CloudPairing.Ticket(challenge: String(repeating: "b", count: 64), expires: ticket.expires, signature: ticket.signature)
    do { _ = try pairing.browserURL(ticket: wrong); preconditionFailure("Reject a mismatched pairing challenge") } catch { }
    let expired = CloudPairing.Ticket(challenge: pairing.challenge, expires: 0, signature: ticket.signature)
    do { _ = try pairing.browserURL(ticket: expired); preconditionFailure("Reject an expired pairing ticket") } catch { }
    let credentials = try api.credentials()
    api.clear()
    try api.restore(credentials)
    _ = try await api.request("api/organisations")
    precondition(CloudStub.requests.last!.value(forHTTPHeaderField: "Cookie") == nil)
    precondition(CloudStub.requests.last!.value(forHTTPHeaderField: "Authorization") == "Bearer " + pairing.token)
    precondition(CloudStub.requests.last!.value(forHTTPHeaderField: "Origin") == "https://foliobruma.com")
    let file = "upload-test.pdf"
    try Data(repeating: 42, count: 8 * 1024 * 1024 + 1024).write(to: folder.appendingPathComponent(file))
    var upload = CloudUpload(fingerprint: "test", userID: "user", organisationID: CloudStub.id, file: file, name: "test.pdf")
    do { try await upload.send(api: api, folder: folder) { _ in }; preconditionFailure("Expected part failure") }
    catch { }
    upload = try CloudUpload.load(in: folder)!
    precondition(upload.documentID == CloudStub.id && !upload.complete)
    CloudStub.failPart = false
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(upload.complete && upload.link != nil)
    let count = CloudStub.requests.count
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(CloudStub.requests.count == count, "Completed items must not upload again")
    upload.complete = false // Model loss of the completion response before saving locally.
    try await upload.send(api: api, folder: folder) { _ in }
    precondition(CloudStub.requests.count == count + 1 && upload.complete)
    precondition(CloudStub.requests.filter { $0.url!.query?.contains("action=start") == true }.count == 1)
    CloudStub.failStart = true
    var unknown = CloudUpload(fingerprint: "other", userID: "user", organisationID: CloudStub.id, file: file, name: "test.pdf")
    do { try await unknown.send(api: api, folder: folder) { _ in }; preconditionFailure("Expected start failure") }
    catch { }
    let before = CloudStub.requests.count
    unknown = try CloudUpload.load(in: folder)!
    do { try await unknown.send(api: api, folder: folder) { _ in }; preconditionFailure("Do not retry an uncertain start") }
    catch { }
    precondition(CloudStub.requests.count == before)
    CloudStub.startCode = 401
    var denied = CloudUpload(fingerprint: "denied", userID: "user", organisationID: CloudStub.id, file: file, name: "test.pdf")
    do { try await denied.send(api: api, folder: folder) { _ in }; preconditionFailure("Expected expired session") }
    catch { }
    let deniedRecord = try CloudUpload.load(in: folder)!
    precondition(!deniedRecord.started, "Explicit rejection must permit retry after sign-in")
    let clearedToken = try JSONDecoder().decode(String?.self, from: api.credentials())
    precondition(clearedToken == nil, "Expired credentials must be removed from memory")
    var document = ScanDocument()
    let fingerprint = try CloudUpload.fingerprint(document)
    document.metadata = ItemMetadata(webLink: upload.link!)
    let savedFingerprint = try CloudUpload.fingerprint(document)
    precondition(savedFingerprint == fingerprint, "Saving the cloud link must not trigger a new revision")
    let label = DocumentLabel(title: "Synthetic test", subtitle: "DOC-0001", link: upload.link!)
    precondition(DocumentLabel.validURL(label.link) != nil)
    let image = label.qrImage()!
    var bounds = CGRect(origin: .zero, size: image.size)
    let bitmap = image.cgImage(forProposedRect: &bounds, context: nil, hints: nil)!
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(cgImage: bitmap).perform([request])
    precondition(request.results?.first?.payloadStringValue == label.link)
  }
}
#endif
