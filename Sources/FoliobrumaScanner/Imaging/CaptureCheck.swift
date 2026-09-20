import CoreImage
import ImageIO
import Vision

enum CaptureCheck {
  static func reduced(_ image: CIImage) -> CIImage {
    image.transformed(
      by: CGAffineTransform(scaleX: 640 / image.extent.width, y: 640 / image.extent.width))
  }
  // Keep page detail. A general image feature print can match different text pages.
  struct Fingerprint {
    let pixels: [UInt8]
    let aspect: Double
  }
  static func fingerprint(_ image: CIImage, context: CIContext) -> Fingerprint? {
    let extent = image.extent
    guard extent.width > 0, extent.height > 0, !extent.isInfinite else { return nil }
    let frame = image.transformed(
      by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
    ).transformed(by: CGAffineTransform(scaleX: 512 / extent.width, y: 512 / extent.height))
    var pixels = [UInt8](repeating: 0, count: 512 * 512)
    context.render(
      frame, toBitmap: &pixels, rowBytes: 512,
      bounds: CGRect(x: 0, y: 0, width: 512, height: 512),
      format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    return Fingerprint(pixels: pixels, aspect: Double(extent.width / extent.height))
  }
  static func duplicate(_ print: Fingerprint, of recent: [Fingerprint]) -> Bool {
    recent.contains { other in
      guard print.pixels.count == 512 * 512, other.pixels.count == print.pixels.count,
        abs(print.aspect - other.aspect) < 0.01 else { return false }
      // Allow a small uniform exposure change, but require detail to match in every tile.
      let offset = zip(print.pixels, other.pixels).reduce(0.0) {
        $0 + Double($1.0) - Double($1.1)
      } / Double(print.pixels.count)
      guard abs(offset) <= 12 else { return false }
      for by in stride(from: 0, to: 512, by: 32) {
        for bx in stride(from: 0, to: 512, by: 32) {
          var changed = 0
          for y in by..<by + 32 {
            for x in bx..<bx + 32 {
              let i = y * 512 + x
              if abs(Double(print.pixels[i]) - Double(other.pixels[i]) - offset) > 18 {
                changed += 1
              }
            }
          }
          if changed > 20 { return false }
        }
      }
      return true
    }
  }
  static func hasHands(_ image: CIImage, context: CIContext) throws -> Bool {
    let frame = reduced(image)
    // Overhead cameras see hands from every side; normalize orientation for the model.
    for orientation in [CGImagePropertyOrientation.up, .left, .right, .down] {
      let r = VNDetectHumanHandPoseRequest()
      r.maximumHandCount = 2
      try VNImageRequestHandler(ciImage: frame, orientation: orientation, options: [:]).perform([r])
      if !(r.results ?? []).isEmpty { return true }
    }
    // Inspect overlapping regions: clipped hands can be too small in the full view.
    for y in [0.0, 0.4] {
      let region = CGRect(
        x: image.extent.minX, y: image.extent.minY + image.extent.height * y,
        width: image.extent.width, height: image.extent.height * 0.6)
      let crop = image.cropped(to: region).transformed(
        by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
      let check = VNDetectHumanHandPoseRequest()
      check.maximumHandCount = 2
      try VNImageRequestHandler(ciImage: reduced(crop), options: [:]).perform([check])
      if !(check.results ?? []).isEmpty { return true }
    }
    return false
  }
  static func motion(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    guard a.count == b.count, a.count == 64 * 48 * 4 else { return true }
    // Check small regions, so an arm is not diluted by the unchanged background.
    for by in stride(from: 0, to: 48, by: 8) {
      for bx in stride(from: 0, to: 64, by: 8) {
        var total = 0.0
        for y in by..<by + 8 {
          for x in bx..<bx + 8 {
            let i = (y * 64 + x) * 4
            total += abs(Double(a[i]) - Double(b[i]))
          }
        }
        if total / 64 > 9 { return true }
      }
    }
    return false
  }
}
