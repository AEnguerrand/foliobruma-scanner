import ScannerCore
import Foundation
import CryptoKit

enum CloudEnvironment {
  static let production = ArchiveServer.production
  // Fixed for this app run. Pending requests never change destination mid-operation.
  static let activeOrigin: URL = {
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "scannerDeveloperMode") else { return production }
    return normalizedOrigin(defaults.string(forKey: "scannerServerURL") ?? "")
      ?? URL(string: "https://invalid.invalid")!
  }()

  static func normalizedOrigin(_ input: String) -> URL? {
    ArchiveServer.normalizedOrigin(input)
  }

  static func accountKey(for origin: URL) -> String {
    if origin == production { return "session" }
    return "session-" + SHA256.hash(data: Data(origin.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
  }
  static func archiveKey(for origin: URL) -> String {
    origin == production ? "cloudOrganisation" : "cloudOrganisation-" + accountKey(for: origin)
  }
}
