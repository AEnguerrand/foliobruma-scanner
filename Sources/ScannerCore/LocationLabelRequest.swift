import Foundation

// A website can request a preview, never a print operation. No credentials or
// arbitrary destinations are accepted through the registered URL scheme.
public struct LocationLabelRequest: Equatable, Sendable {
  public let title: String
  public let link: String

  public init?(url: URL) {
    guard url.absoluteString.utf8.count <= 4096,
      let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == "foliobruma-scanner", parts.host == "label",
      parts.path.isEmpty, parts.user == nil, parts.password == nil,
      parts.port == nil, parts.fragment == nil,
      let query = parts.percentEncodedQuery else { return nil }
    var values: [String: String] = [:]
    for item in query.split(separator: "&", omittingEmptySubsequences: false) {
      let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      guard pair.count == 2,
        let key = String(pair[0]).removingPercentEncoding,
        let value = String(pair[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding,
        ["v", "title", "url"].contains(key), values[key] == nil else { return nil }
      values[key] = value
    }
    guard values.count == 3, values["v"] == "1", let title = values["title"],
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      title.utf16.count <= 180,
      !title.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
      let link = values["url"], link.utf8.count <= 100,
      let destination = URLComponents(string: link), destination.scheme == "https",
      ["foliobruma.com", "staging.foliobruma.com"].contains(destination.host ?? ""),
      destination.user == nil, destination.password == nil, destination.port == nil,
      destination.query == nil, destination.fragment == nil,
      destination.percentEncodedPath.range(of: #"^/l/[A-Za-z0-9_-]{16}$"#, options: .regularExpression) != nil,
      destination.url?.absoluteString == link else { return nil }
    self.title = title
    self.link = link
  }
}
