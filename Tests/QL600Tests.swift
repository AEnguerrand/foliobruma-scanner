#if SCANNER_TESTS
import AppKit
import Vision
extension SessionTests {
 @MainActor static func testQL600Labels() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("ql600-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  var doc = ScanDocument()
  let before = try CloudUpload.fingerprint(doc)
  doc.automation = SessionAutomation(upload: true, printLabel: true, printerName: QL600Printer.destination)
  precondition(try! CloudUpload.fingerprint(doc) == before, "Printer setup must not create another PDF upload")
  let decoded = try JSONDecoder().decode(ScanDocument.self, from: JSONEncoder().encode(doc))
  precondition(decoded.automation == doc.automation)
  var upload = CloudUpload(fingerprint: "test", userID: "test", organisationID: "test", file: "test", name: "test")
  try upload.beginDirectLabel(in: root)
  try upload.finishDirectLabel(in: root, completed: false, mayHavePrinted: false)
  upload = try CloudUpload.load(in: root)!
  try upload.beginDirectLabel(in: root)
  try upload.finishDirectLabel(in: root, completed: false, mayHavePrinted: true)
  do { try upload.beginDirectLabel(in: root); preconditionFailure("Uncertain print must not repeat") } catch { }
  try upload.finishDirectLabel(in: root, completed: true, mayHavePrinted: true)
  do { try upload.beginDirectLabel(in: root); preconditionFailure("Completed print must not repeat") } catch { }
  for link in ["https://foliobruma.com/d/1234567890abcdef", "https://foliobruma.com/api/organisations/11111111-1111-1111-1111-111111111111/documents/22222222-2222-2222-2222-222222222222"] {
    let label = DocumentLabel(title: "Test sheet with a longer title", subtitle: "LET-1234", link: link)
    let bitmap = try QL600Printer.bitmap(label)
    if label.permanentCode != nil {
      var top = 225, bottom = -1
      for y in 0..<225 {
        for x in 0..<240 {
          if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.redComponent < 0.5 {
            top = min(top, y); bottom = max(bottom, y)
          }
        }
      }
      precondition(bottom - top + 1 == 225, "Permanent QR must use the full printable height")
    }
    let data = [UInt8](try QL600Printer.raster(bitmap))
    let header = 200 + 6 + 13 + 17
    precondition(data.count == header + 225 * 93 + 1 && data.last == 0x1a)
    let reconstructed = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 732, pixelsHigh: 295,
      bitsPerSample: 8, samplesPerPixel: 1, hasAlpha: false, isPlanar: false,
      colorSpaceName: .deviceWhite, bytesPerRow: 732, bitsPerPixel: 8)!
    memset(reconstructed.bitmapData!, 255, 732 * 295)
    for y in 0..<225 {
      let offset = header + y * 93
      precondition(Array(data[offset..<offset+3]) == [0x67, 0, 90])
      for x in 0..<696 {
        let pin = 12 + 695 - x
        let black = data[offset + 3 + pin / 8] & UInt8(0x80 >> (pin % 8)) != 0
        reconstructed.bitmapData![(y + 35) * 732 + x + 18] = black ? 0 : 255
      }
    }
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(cgImage: reconstructed.cgImage!, options: [:]).perform([request])
    precondition(request.results?.contains { $0.payloadStringValue == link } == true, "QR must survive final packed printer raster")
  }
  let scanner = Scanner(storageRoot: root.appendingPathComponent("library"))
  try scanner.createItem(title: "Test", metadata: ItemMetadata(batchID: UUID().uuidString, sheetBatch: true), scanPages: true)
  scanner.setSessionAutomation(doc.automation!)
  try scanner.createNextSheet(resumeCapture: false)
  precondition(scanner.document.automation == doc.automation, "Next sheet must retain session configuration")
  try scanner.createItem(title: "Other", metadata: ItemMetadata(), scanPages: true)
  precondition(!scanner.uploadOnFinish && !scanner.printOnFinish, "Unrelated sessions must not inherit automatic printing")
  print("PASS: session print settings, batch inheritance, upload identity, direct USB retry states, packed label QR decoding")
 }
}
#endif
