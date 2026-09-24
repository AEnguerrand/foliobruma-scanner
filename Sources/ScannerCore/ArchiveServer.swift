import Foundation

public enum ArchiveServer {
  public static let production = URL(string: "https://foliobruma.com")!
  public static func normalizedOrigin(_ input: String) -> URL? {
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

}
