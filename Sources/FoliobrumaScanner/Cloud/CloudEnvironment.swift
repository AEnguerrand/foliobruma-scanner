import Foundation
import CryptoKit

enum CloudEnvironment {
  static let production = URL(string: "https://foliobruma.com")!
  // Fixed for this app run. Pending requests never change destination mid-operation.
  static let activeOrigin: URL = {
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "scannerDeveloperMode") else { return production }
    return normalizedOrigin(defaults.string(forKey: "scannerServerURL") ?? "")
      ?? URL(string: "https://invalid.invalid")!
  }()

  static func normalizedOrigin(_ input: String) -> URL? {
    guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
          parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
          !host.contains(where: { $0.isWhitespace }), parts.user == nil, parts.password == nil,
          parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
          parts.port == nil || (1...65535).contains(parts.port!) else { return nil }
    parts.scheme = "https"
    parts.host = host.lowercased()
    parts.path = ""
    if parts.port == 443 { parts.port = nil }
    return parts.url
  }

  static func accountKey(for origin: URL) -> String {
    if origin == production { return "session" }
    return "session-" + SHA256.hash(data: Data(origin.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
  }
  static func archiveKey(for origin: URL) -> String {
    origin == production ? "cloudOrganisation" : "cloudOrganisation-" + accountKey(for: origin)
  }
}
