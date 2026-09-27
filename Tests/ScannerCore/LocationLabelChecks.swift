import Foundation
import ScannerCore

extension ScannerCoreChecks {
  static func testLocationLabelRequests() {
    let link = "https://foliobruma.com/l/1234567890abcdef"
    func handoff(_ title: String = "Box+12+%C2%B7+A%2BB", _ destination: String = link) -> URL {
      var parts = URLComponents(string: "foliobruma-scanner://label")!
      parts.percentEncodedQuery = "v=1&title=\(title)&url=" + destination.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
      return parts.url!
    }
    let valid = handoff()
    let request = LocationLabelRequest(url: valid)!
    precondition(request.title == "Box 12 · A+B" && request.link == link)
    precondition(LocationLabelRequest(url: handoff(String(repeating: "a", count: 180))) != nil)
    precondition(LocationLabelRequest(url: handoff(String(repeating: "a", count: 181))) == nil)
    for title in ["", "+", "%0A", "%00", "%7F"] {
      precondition(LocationLabelRequest(url: handoff(title)) == nil)
    }
    for destination in ["http://foliobruma.com/l/1234567890abcdef", "https://evil.example/l/1234567890abcdef",
      "https://foliobruma.com.evil.example/l/1234567890abcdef", "https://user@foliobruma.com/l/1234567890abcdef",
      link + "?print=1", link + "#fragment", "https://foliobruma.com:443/l/1234567890abcdef",
      "https://foliobruma.com/l/short", "https://foliobruma.com/l/1234567890abcdef/",
      "https://foliobruma.com/api/documents/1234567890abcdef"] {
      precondition(LocationLabelRequest(url: handoff("Box", destination)) == nil, destination)
    }
    for suffix in ["&title=Other", "&v=1", "&print=1", "&url=" + link, "&unknown=x", "&", "#fragment"] {
      precondition(LocationLabelRequest(url: URL(string: valid.absoluteString + suffix)!) == nil)
    }
    precondition(LocationLabelRequest(url: URL(string: valid.absoluteString.replacingOccurrences(of: "v=1", with: "v=2"))!) == nil)
    precondition(LocationLabelRequest(url: handoff("Box", "https://staging.foliobruma.com/l/1234567890abcdef")) != nil)
    print("PASS: bounded website label handoff, encoded titles, allowed destinations, duplicate and malformed fields")
  }
}
