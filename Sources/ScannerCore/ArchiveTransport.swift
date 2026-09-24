import Foundation

// The platform translates errors for display. HTTP adapters preserve status codes.
public struct CloudFailure: Error {
  public let message: String
  public var status: Int?
  public init(message: String, status: Int? = nil) {
    self.message = message
    self.status = status
  }
}

public struct ArchiveRequest {
  public let path: String
  public let method: String
  public let body: Data?
  public let contentType: String
  public let query: [URLQueryItem]
  public let revision: Int?
}

// Credentials and HTTP policy belong to the adapter. Do not follow redirects or
// change baseURL during an operation. Report HTTP failures as CloudFailure.
public protocol ArchiveTransport {
  var baseURL: URL { get }
  func send(_ request: ArchiveRequest) async throws -> Data
}

public extension ArchiveTransport {
  func request(_ path: String, method: String = "GET", body: Data? = nil,
               type: String = "application/json", query: [URLQueryItem] = [], revision: Int? = nil) async throws -> Data {
    try await send(ArchiveRequest(path: path, method: method, body: body,
      contentType: type, query: query, revision: revision))
  }
}
