import ScannerCore
import AppKit
import CoreImage

struct QL600Failure: LocalizedError {
  let message: String
  let sent: Bool
  var errorDescription: String? { message }
}

// Brother QL-600 Raster Command Reference 1.02, 62 mm continuous tape at 300 dpi.
// https://download.brother.com/welcome/docp000698/cv_ql600710720_eng_raster_102.pdf
// Use Apple's USB framework; no CUPS queue, vendor driver, or runtime package.
enum QL600Printer {
  static let destination = "Brother QL-600 · USB"
  static let width = QL600Raster.width
  static let height = QL600Raster.height // Plus two 35-dot feed margins: about 25 mm total.

  @MainActor static func bitmap(_ label: DocumentLabel) throws -> NSBitmapImageRep {
    guard DocumentLabel.validURL(label.link) != nil,
          let filter = CIFilter(name: "CIQRCodeGenerator") else { throw CloudFailure(message: "Could not create the QR code.") }
    filter.setValue(Data(label.link.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let code = filter.outputImage else { throw CloudFailure(message: "Could not create the QR code.") }
    // The roll adds 18 white dots across its edge and 35 dots at each cut.
    // Count those physical margins in the four-module QR quiet zone.
    let bounds = code.extent.insetBy(dx: 1, dy: 1)
    guard let cg = CIContext().createCGImage(code, from: bounds) else { throw CloudFailure(message: "Could not create the QR code.") }
    let qr = NSImage(cgImage: cg, size: bounds.size)
    let modules = Int(bounds.width)
    // Fill the available height instead of rounding the scale down to an integer.
    // Nearest-neighbour drawing keeps edges black or white; individual modules
    // differ by at most one device dot. Include four modules of white paper.
    let edge = CGFloat(min(height, (height + 70) * modules / (modules + 8)))
    let quiet = ceil(4 * edge / CGFloat(modules))
    let qrX = max(0, quiet - 18)
    let textX = max(230, qrX + edge + quiet)
    let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { rect in
      NSColor.white.setFill(); rect.fill()
      NSGraphicsContext.current?.imageInterpolation = .none
      qr.draw(in: NSRect(x: qrX, y: (225 - edge) / 2, width: edge, height: edge),
              from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
      let style = NSMutableParagraphStyle()
      if let code = label.permanentCode {
        style.lineBreakMode = .byClipping
        (code as NSString).draw(in: NSRect(x: textX, y: 36, width: 696 - textX, height: 64), withAttributes: [
          .font: NSFont.monospacedSystemFont(ofSize: 42, weight: .semibold),
          .foregroundColor: NSColor.black, .paragraphStyle: style])
        style.lineBreakMode = .byWordWrapping
        (label.title as NSString).draw(in: NSRect(x: textX, y: 116, width: 696 - textX, height: 100), withAttributes: [
          .font: NSFont.systemFont(ofSize: 30), .foregroundColor: NSColor.black, .paragraphStyle: style])
      } else {
        for (text, y, size, bold) in [(label.title, 0.0, 46.0, true), (label.subtitle, 112.0, 44.0, false), (label.printedLink, 188.0, 28.0, false)] {
          style.lineBreakMode = bold ? .byWordWrapping : .byTruncatingTail
          (text as NSString).draw(in: NSRect(x: textX, y: y, width: 696 - textX, height: bold ? 110 : min(size * 1.6, 225 - y)), withAttributes: [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.black, .paragraphStyle: style])
        }
      }
      return true
    }
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          bitmap.pixelsWide == width, bitmap.pixelsHigh == height else {
      throw CloudFailure(message: "Could not render the label.")
    }
    return bitmap
  }

  static func raster(_ bitmap: NSBitmapImageRep) throws -> Data {
    try QL600Raster.encode(width: bitmap.pixelsWide, height: bitmap.pixelsHigh) { x, y in
      guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
        throw CloudFailure(message: "Could not read the label pixels.")
      }
      return (color.redComponent + color.greenComponent + color.blueComponent) / 3 < 0.5
    }
  }

  static func send(_ job: Data) throws {
    var status = [UInt8](repeating: 0, count: 32)
    var sent: Int32 = 0
    var message = [CChar](repeating: 0, count: 256)
    let result = job.withUnsafeBytes { raw in
      ql600_transfer(raw.bindMemory(to: UInt8.self).baseAddress, job.count, &status, &sent, &message, message.count)
    }
    if result != 0 { throw QL600Failure(message: String(cString: message), sent: sent != 0) }
  }
}
