import Foundation
import Security

struct CloudFailure: LocalizedError {
  let message: String
  var status: Int? = nil
  var errorDescription: String? { L10n.text(message) }
}

// A separate scanner credential never reads or stores browser cookies.
final class CloudAPI: NSObject, URLSessionTaskDelegate {
  static let origin = CloudEnvironment.production
  let baseURL: URL
  private var token: String?
  var access: CloudAccess?
  static let sessionExpired = Notification.Name("FoliobrumaScannerSessionExpired")
  private let configuration: URLSessionConfiguration
  private lazy var session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  init(configuration: URLSessionConfiguration = .ephemeral, origin: URL = CloudAPI.origin) {
    self.baseURL = origin
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
  func restore(_ data: Data) throws {
    guard let value = try? JSONDecoder().decode(String.self, from: data),
      value.range(of: "^fs1_[a-f0-9]{64}$", options: .regularExpression) != nil else {
      throw CloudFailure(message: "Sign in on the website to connect this version of the scanner.")
    }
    token = value
  }
  func credentials() throws -> Data { try JSONEncoder().encode(token) }
  func clear() { token = nil }
  func request(_ path: String, method: String = "GET", body: Data? = nil,
               type: String = "application/json", query: [URLQueryItem] = [], revision: Int? = nil) async throws -> Data {
    guard baseURL.host != "invalid.invalid" else { throw CloudFailure(message: "Set a valid HTTPS server URL in developer settings, then restart the app.") }
    var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    parts.queryItems = query.isEmpty ? nil : query
    var request = URLRequest(url: parts.url!)
    request.httpMethod = method
    request.httpBody = body
    request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
    request.setValue(type, forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if baseURL != CloudEnvironment.production, let access {
      try access.validate()
      request.setValue(access.clientID, forHTTPHeaderField: "CF-Access-Client-Id")
      request.setValue(access.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
    }
    if let revision { request.setValue("\"\(revision)\"", forHTTPHeaderField: "If-Match") }
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw CloudFailure(message: "The server response is invalid.") }
    if (300..<400).contains(http.statusCode) {
      throw CloudFailure(message: "The server requires a browser redirect. Check its access policy for native scanner clients.", status: http.statusCode)
    }
    if http.statusCode == 401 {
      clear()
      NotificationCenter.default.post(name: Self.sessionExpired, object: self)
      throw CloudFailure(message: "Your session has expired. Sign in again in Settings.", status: 401)
    }
    guard (200..<300).contains(http.statusCode) else {
      // Do not display arbitrary HTML, server traces, or credentials in the interface.
      throw CloudFailure(message: "The server could not complete the request. Check your account, connection, and archive storage.", status: http.statusCode)
    }
    return data
  }
}

enum CloudKeychain {
  static func query(for origin: URL = CloudAPI.origin) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "org.sovenelia.scanner.foliobruma",
     kSecAttrAccount as String: CloudEnvironment.accountKey(for: origin)]
  }
  static func read(origin: URL = CloudAPI.origin) throws -> Data? {
    var values = query(for: origin)
    values[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(values as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw CloudFailure(message: "Could not read the session from Keychain.") }
    return item as? Data
  }
  static func save(_ data: Data, origin: URL = CloudAPI.origin) throws {
    let attributes = [kSecValueData as String: data]
    let status = SecItemUpdate(query(for: origin) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var values = query(for: origin).merging(attributes) { _, new in new }
      values[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else {
        throw CloudFailure(message: "Could not save the session in Keychain.")
      }
    } else if status != errSecSuccess { throw CloudFailure(message: "Could not save the session in Keychain.") }
  }
  static func remove(origin: URL = CloudAPI.origin) throws {
    let status = SecItemDelete(query(for: origin) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CloudFailure(message: "Could not remove the session from Keychain.")
    }
  }
}
