import ScannerCore
import CoreImage

struct PageQuality {
  let sharpness: Double
  let contrast: Double
  let whiteLevel: Double
  var reason: String? {
    if whiteLevel < 55 { return "Too dark · Add light and rescan" }
    if contrast > 35 && sharpness < 12 {
      return "Scan looks blurred · Hold the page still and rescan"
    }
    return nil
  }
  static func touchesFrame(_ q: Quad) -> Bool {
    q.points.contains { $0.x <= 0.003 || $0.x >= 0.997 || $0.y <= 0.003 || $0.y >= 0.997 }
  }
  static func measure(_ image: CIImage, context: CIContext) -> PageQuality {
    let w = 512
    let h = max(8, Int(512 * image.extent.height / image.extent.width))
    let origin = image.transformed(
      by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    let small = origin.transformed(
      by: CGAffineTransform(
        scaleX: Double(w) / image.extent.width, y: Double(h) / image.extent.height))
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    context.render(
      small, toBitmap: &rgba, rowBytes: w * 4, bounds: CGRect(x: 0, y: 0, width: w, height: h),
      format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    var gray = [Double](repeating: 0, count: w * h)
    for i in 0..<w * h {
      gray[i] =
        (Double(rgba[i * 4]) * 3 + Double(rgba[i * 4 + 1]) * 6 + Double(rgba[i * 4 + 2])) / 10
    }
    var total = 0.0
    var count = 0
    var levels: [Double] = []
    for y in max(1, h / 20)..<min(h - 1, h * 19 / 20) {
      for x in w / 20..<w * 19 / 20 {
        let i = y * w + x
        let lap = gray[i - 1] + gray[i + 1] + gray[i - w] + gray[i + w] - 4 * gray[i]
        total += lap * lap
        count += 1
        levels.append(gray[i])
      }
    }
    levels.sort()
    let low = levels[levels.count / 20]
    let high = levels[levels.count * 19 / 20]
    return PageQuality(sharpness: total / Double(count), contrast: high - low, whiteLevel: high)
  }
}
