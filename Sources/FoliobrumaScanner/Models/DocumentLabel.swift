import AppKit
import CoreImage

struct DocumentLabel: Hashable {
  let title: String
  let subtitle: String
  let link: String
  static let size = NSSize(width: 62 * 72 / 25.4, height: 25 * 72 / 25.4)

  // A short HTTPS address keeps the code readable at this fixed label size.
  // No network request is made; the user supplies an existing destination.
  static func validURL(_ text: String) -> URL? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.utf8.count <= 100,
      !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }),
      let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https",
      let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
      let url = parts.url, url.absoluteString.utf8.count <= 100
    else { return nil }
    return url
  }

  func qrImage() -> NSImage? {
    guard let url = Self.validURL(link),
      let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let code = filter.outputImage else { return nil }
    // Core Image includes a narrow border. Add four full modules on every edge.
    let bounds = code.extent.insetBy(dx: -4, dy: -4)
    let white = CIImage(color: .white).cropped(to: bounds)
    let padded = code.composited(over: white).cropped(to: bounds)
    let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    guard let bitmap = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return NSImage(cgImage: bitmap, size: NSSize(width: bounds.width, height: bounds.height))
  }

  var printedLink: String {
    guard let url = Self.validURL(link) else { return "" }
    return String(url.absoluteString.dropFirst("https://".count))
  }
}

// The preview, PDF, and print operation use exactly the same drawing.
final class DocumentLabelView: NSView {
  let label: DocumentLabel
  let qr: NSImage
  override var isFlipped: Bool { true }

  init(label: DocumentLabel, qr: NSImage) {
    self.label = label
    self.qr = qr
    super.init(frame: NSRect(origin: .zero, size: DocumentLabel.size))
  }
  required init?(coder: NSCoder) { nil }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.white.setFill()
    bounds.fill()
    NSGraphicsContext.current?.imageInterpolation = .none
    let mm = 72.0 / 25.4
    qr.draw(in: NSRect(x: 1.5 * mm, y: 1.5 * mm, width: 22 * mm, height: 22 * mm),
             from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    let x = 25 * mm
    let width = 35.5 * mm
    drawText(label.title, x: x, y: 4 * mm, width: width, size: 8, bold: true)
    drawText(label.subtitle, x: x, y: 10 * mm, width: width, size: 7, bold: false)
    drawText(label.printedLink, x: x, y: 16 * mm, width: width, size: 5.5, bold: false)
  }

  private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                        size: CGFloat, bold: Bool) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 1.6),
      withAttributes: [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraph])
  }

  func printLabel() {
    let info = NSPrintInfo(dictionary: [:])
    if let name = NSPrinter.printerNames.first(where: { $0.localizedCaseInsensitiveContains("QL-600") }),
       let printer = NSPrinter(name: name) { info.printer = printer }
    info.paperSize = DocumentLabel.size
    info.topMargin = 0
    info.bottomMargin = 0
    info.leftMargin = 0
    info.rightMargin = 0
    info.horizontalPagination = .clip
    info.verticalPagination = .clip
    info.isHorizontallyCentered = true
    info.isVerticallyCentered = true
    info.scalingFactor = 1
    let operation = NSPrintOperation(view: self, printInfo: info)
    operation.showsPrintPanel = true
    operation.showsProgressPanel = true
    operation.run()
  }
}
