import Foundation
import Security

struct CloudFailure: LocalizedError {
  let message: String
  var status: Int? = nil
  var errorDescription: String? { L10n.text(message) }
}

// An isolated cookie jar prevents account cookies from entering shared browser storage.
final class CloudAPI: NSObject, URLSessionTaskDelegate {
  static let origin = URL(string: "https://foliobruma.com")!
  private var cookies: [HTTPCookie] = []
  private let configuration: URLSessionConfiguration
  private lazy var session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  init(configuration: URLSessionConfiguration = .ephemeral) {
    self.configuration = configuration
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 120
    super.init()
  }
  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }
  private struct StoredCookie: Codable {
    let name: String
    let value: String
    let path: String
    let expires: Date?
  }
  func restore(_ data: Data) throws {
    let values = try JSONDecoder().decode([StoredCookie].self, from: data)
    cookies = values.compactMap { value in
      var properties: [HTTPCookiePropertyKey: Any] = [
        .name: value.name, .value: value.value, .path: value.path,
        .domain: "foliobruma.com", .secure: "TRUE"]
      if let expires = value.expires { properties[.expires] = expires }
      return HTTPCookie(properties: properties)
    }
  }
  func credentials() throws -> Data {
    try JSONEncoder().encode(cookies.map {
      StoredCookie(name: $0.name, value: $0.value, path: $0.path, expires: $0.expiresDate)
    })
  }
  func clear() { cookies = [] }
  func request(_ path: String, method: String = "GET", body: Data? = nil,
               type: String = "application/json", query: [URLQueryItem] = []) async throws -> Data {
    var parts = URLComponents(url: Self.origin.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    parts.queryItems = query.isEmpty ? nil : query
    var request = URLRequest(url: parts.url!)
    request.httpMethod = method
    request.httpBody = body
    request.setValue(Self.origin.absoluteString, forHTTPHeaderField: "Origin")
    request.setValue(type, forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let valid = cookies.filter { ($0.expiresDate ?? .distantFuture) > Date() }
    for (key, value) in HTTPCookie.requestHeaderFields(with: valid) { request.setValue(value, forHTTPHeaderField: key) }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw CloudFailure(message: "The server response is invalid.") }
    if http.statusCode == 401 {
      clear()
      throw CloudFailure(message: "Your session has expired. Sign in again in Settings.", status: 401)
    }
    guard (200..<300).contains(http.statusCode) else {
      // Do not display arbitrary HTML, server traces, or credentials in the interface.
      throw CloudFailure(message: "The server could not complete the request. Check your account, connection, and archive storage.", status: http.statusCode)
    }
    let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, entry in
      if let key = entry.key as? String, let value = entry.value as? String { result[key] = value }
    }
    for cookie in HTTPCookie.cookies(withResponseHeaderFields: headers, for: Self.origin)
      where cookie.domain == "foliobruma.com" && cookie.isSecure {
      cookies.removeAll { $0.name == cookie.name }
      cookies.append(cookie)
    }
    return data
  }
}

enum CloudKeychain {
  static var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "org.sovenelia.scanner.foliobruma",
     kSecAttrAccount as String: "session"]
  }
  static func read() throws -> Data? {
    var values = query
    values[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(values as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw CloudFailure(message: "Could not read the session from Keychain.") }
    return item as? Data
  }
  static func save(_ data: Data) throws {
    let attributes = [kSecValueData as String: data]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var values = query.merging(attributes) { _, new in new }
      values[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else {
        throw CloudFailure(message: "Could not save the session in Keychain.")
      }
    } else if status != errSecSuccess { throw CloudFailure(message: "Could not save the session in Keychain.") }
  }
  static func remove() throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CloudFailure(message: "Could not remove the session from Keychain.")
    }
  }
}
