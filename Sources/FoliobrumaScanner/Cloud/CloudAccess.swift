import Foundation
import Security

struct CloudAccess: Codable {
  let clientID: String
  let clientSecret: String

  func validate() throws {
    guard !clientID.isEmpty, !clientSecret.isEmpty,
          [clientID, clientSecret].allSatisfy({ value in
            value.utf8.allSatisfy { $0 > 32 && $0 < 127 }
          }) else {
      throw CloudFailure(message: "Enter both Access token fields without spaces or line breaks.")
    }
  }

  static func query(_ origin: URL) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "org.sovenelia.scanner.cloudflare-access",
     kSecAttrAccount as String: CloudEnvironment.accountKey(for: origin)]
  }
  static func read(_ origin: URL) throws -> CloudAccess? {
    guard origin != CloudEnvironment.production else { return nil }
    var values = query(origin)
    values[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(values as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw CloudFailure(message: "Could not read the Access token from Keychain.")
    }
    let value = try JSONDecoder().decode(Self.self, from: data)
    try value.validate()
    return value
  }
  func save(_ origin: URL) throws {
    try validate()
    guard origin != CloudEnvironment.production else {
      throw CloudFailure(message: "Access tokens are only available for developer servers.")
    }
    let attributes = [kSecValueData as String: try JSONEncoder().encode(self)]
    let status = SecItemUpdate(Self.query(origin) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var values = Self.query(origin).merging(attributes) { _, new in new }
      values[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else {
        throw CloudFailure(message: "Could not save the Access token in Keychain.")
      }
    } else if status != errSecSuccess {
      throw CloudFailure(message: "Could not save the Access token in Keychain.")
    }
  }
  static func remove(_ origin: URL) throws {
    let status = SecItemDelete(query(origin) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CloudFailure(message: "Could not remove the Access token from Keychain.")
    }
  }
}
