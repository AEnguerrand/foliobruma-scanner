import CoreGraphics

struct Quad: Codable {
  var tl: CGPoint
  var tr: CGPoint
  var br: CGPoint
  var bl: CGPoint
  static let full = Quad(
    tl: .init(x: 0, y: 1), tr: .init(x: 1, y: 1), br: .init(x: 1, y: 0), bl: .init(x: 0, y: 0))
  var points: [CGPoint] { [tl, tr, br, bl] }
}
