import ScannerCore
import Foundation
import CryptoKit
import Security

struct CloudPairing {
  let token: String
  var challenge: String {
    SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
  }
  var code: String {
    let value = String(challenge.prefix(8)).uppercased()
    return String(value.prefix(4)) + "–" + String(value.suffix(4))
  }
  static func create() throws -> CloudPairing {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw CloudFailure(message: "Could not start sign-in. Try again.")
    }
    return CloudPairing(token: "fs1_" + bytes.map { String(format: "%02x", $0) }.joined())
  }
  struct Ticket: Decodable {
    let challenge: String
    let expires: Double
    let signature: String
  }
  func browserURL(ticket: Ticket, now: Date = Date(), origin: URL = CloudAPI.origin) throws -> URL {
    guard ticket.challenge == challenge, ticket.signature.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
      ticket.expires > now.timeIntervalSince1970 * 1000,
      ticket.expires <= now.timeIntervalSince1970 * 1000 + 610_000 else {
      throw CloudFailure(message: "The server response is invalid.")
    }
    var fragment = URLComponents()
    fragment.queryItems = [URLQueryItem(name: "scanner", value: challenge),
                           URLQueryItem(name: "expires", value: String(format: "%.0f", ticket.expires)),
                           URLQueryItem(name: "signature", value: ticket.signature)]
    var url = URLComponents(url: origin.appendingPathComponent("app/"), resolvingAgainstBaseURL: false)!
    url.fragment = fragment.query
    return url.url!
  }
}
