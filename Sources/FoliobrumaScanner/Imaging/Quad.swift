import CoreGraphics

struct Quad: Codable {
  var tl: CGPoint
  var tr: CGPoint
  var br: CGPoint
  var bl: CGPoint
  static let full = Quad(
    tl: .init(x: 0, y: 1), tr: .init(x: 1, y: 1), br: .init(x: 1, y: 0), bl: .init(x: 0, y: 0))
  var bounds: CGRect {
    let xs = points.map(\.x), ys = points.map(\.y)
    return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
  }
  var area: CGFloat {
    let p = points
    return abs((0..<4).reduce(CGFloat(0)) { $0 + p[$1].x * p[($1+1)%4].y - p[($1+1)%4].x * p[$1].y }) / 2
  }
  func padded(_ fraction: CGFloat = 0.025) -> Quad {
    let center = CGPoint(x: points.map(\.x).reduce(0,+)/4, y: points.map(\.y).reduce(0,+)/4)
    func expand(_ p: CGPoint) -> CGPoint {
      CGPoint(x: min(1,max(0,center.x+(p.x-center.x)*(1+2*fraction))),
              y: min(1,max(0,center.y+(p.y-center.y)*(1+2*fraction))))
    }
    return Quad(tl: expand(tl), tr: expand(tr), br: expand(br), bl: expand(bl))
  }
  var points: [CGPoint] { [tl, tr, br, bl] }
}
