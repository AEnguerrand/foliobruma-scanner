import Foundation

public struct RejectedScan: Codable, Identifiable {
  public var id: String { file }
  public var file: String
  public var reason: String
  public var quad: Quad?
  public var split: Bool
  public var divider: Double
  public var replacementID: String?
  public init(file: String, reason: String, quad: Quad? = nil, split: Bool,
              divider: Double, replacementID: String? = nil) {
    self.file = file
    self.reason = reason
    self.quad = quad
    self.split = split
    self.divider = divider
    self.replacementID = replacementID
  }
}
