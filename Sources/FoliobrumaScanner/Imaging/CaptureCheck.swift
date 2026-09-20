import CoreImage
import ImageIO
import Vision

enum CaptureCheck {
  static func reduced(_ image: CIImage) -> CIImage {
    image.transformed(
      by: CGAffineTransform(scaleX: 640 / image.extent.width, y: 640 / image.extent.width))
  }
  static func fingerprint(_ image: CIImage) throws -> VNFeaturePrintObservation? {
    let r = VNGenerateImageFeaturePrintRequest()
    r.revision = VNGenerateImageFeaturePrintRequestRevision2
    try VNImageRequestHandler(ciImage: reduced(image), options: [:]).perform([r])
    return r.results?.first
  }
  static func duplicate(_ print: VNFeaturePrintObservation, of recent: [VNFeaturePrintObservation])
    -> Bool
  {
    recent.contains { other in
      var distance: Float = 1
      do {
        try print.computeDistance(&distance, to: other)
        return distance < 0.18
      } catch { return false }
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
