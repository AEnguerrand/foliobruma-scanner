import Foundation

public struct Quad: Codable {
  public var tl: CGPoint
  public var tr: CGPoint
  public var br: CGPoint
  public var bl: CGPoint
  public init(tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) {
    self.tl = tl
    self.tr = tr
    self.br = br
    self.bl = bl
  }
  // Match the existing CGPoint [x, y] format without the CoreGraphics overlay.
  private enum CodingKeys: String, CodingKey { case tl, tr, br, bl }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    func point(_ key: CodingKeys) throws -> CGPoint {
      var coordinates = try values.nestedUnkeyedContainer(forKey: key)
      let x = try coordinates.decode(Double.self)
      let y = try coordinates.decode(Double.self)
      guard coordinates.isAtEnd else {
        throw DecodingError.dataCorruptedError(in: coordinates, debugDescription: "Expected two coordinates.")
      }
      return CGPoint(x: x, y: y)
    }
    self.init(tl: try point(.tl), tr: try point(.tr), br: try point(.br), bl: try point(.bl))
  }

  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    for (key, point) in [(CodingKeys.tl, tl), (.tr, tr), (.br, br), (.bl, bl)] {
      var coordinates = values.nestedUnkeyedContainer(forKey: key)
      try coordinates.encode(Double(point.x))
      try coordinates.encode(Double(point.y))
    }
  }

  public static let full = Quad(
    tl: .init(x: 0, y: 1), tr: .init(x: 1, y: 1), br: .init(x: 1, y: 0), bl: .init(x: 0, y: 0))
  public var bounds: CGRect {
    let xs = points.map(\.x), ys = points.map(\.y)
    var rect = CGRect()
    rect.origin = CGPoint(x: xs.min()!, y: ys.min()!)
    rect.size.width = xs.max()! - xs.min()!
    rect.size.height = ys.max()! - ys.min()!
    return rect
  }
  public var area: CGFloat {
    let p = points
    return abs((0..<4).reduce(CGFloat(0)) { $0 + p[$1].x * p[($1+1)%4].y - p[($1+1)%4].x * p[$1].y }) / 2
  }
  public func padded(_ fraction: CGFloat = 0.025) -> Quad {
    let center = CGPoint(x: points.map(\.x).reduce(0,+)/4, y: points.map(\.y).reduce(0,+)/4)
    func expand(_ p: CGPoint) -> CGPoint {
      CGPoint(x: min(1,max(0,center.x+(p.x-center.x)*(1+2*fraction))),
              y: min(1,max(0,center.y+(p.y-center.y)*(1+2*fraction))))
    }
    return Quad(tl: expand(tl), tr: expand(tr), br: expand(br), bl: expand(bl))
  }
  public var points: [CGPoint] { [tl, tr, br, bl] }
}
