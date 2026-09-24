import ScannerCore
import Foundation
import CryptoKit
import AppKit
import PDFKit

extension CloudUpload {
  static func fingerprint(_ document: ScanDocument) throws -> String {
    SHA256.hash(data: try fingerprintData(document)).map { String(format: "%02x", $0) }.joined()
  }

  static func makePDF(_ document: ScanDocument, in folder: URL, file: String) throws {
    let pdf = PDFDocument()
    for source in document.pages {
      guard let image = NSImage(contentsOf: folder.appendingPathComponent(source.file)),
            let page = PDFPage(image: image) else {
        throw CloudFailure(message: "A page image is missing. PDF export stopped.")
      }
      page.rotation = source.rotation
      pdf.insert(page, at: pdf.pageCount)
    }
    guard let data = pdf.dataRepresentation(), data.count <= 500 * 1024 * 1024 else {
      throw CloudFailure(message: "The PDF could not be created or exceeds 500 MiB. Export it locally instead.")
    }
    try data.write(to: folder.appendingPathComponent(file), options: .atomic)
  }
}
