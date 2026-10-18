import Foundation
import ScannerCore

// The input is a QR module matrix from the local libqrencode adapter.
// Four white modules surround the symbol. Each module is five printer dots.
do {
  guard CommandLine.arguments.count == 3 else {
    throw NSError(domain: "Usage: DiagnosticLabel matrix.txt label.raster", code: 1)
  }
  let rows = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    .split(separator: "\n").map { Array($0) }
  let size = rows.count
  guard (21...33).contains(size), (size - 21) % 4 == 0,
        rows.allSatisfy({ $0.count == size && $0.allSatisfy { $0 == "0" || $0 == "1" } }) else {
    throw NSError(domain: "Invalid diagnostic QR matrix", code: 2)
  }
  let scale = 5
  let side = (size + 8) * scale
  let left = (QL600Raster.width - side) / 2
  let top = (QL600Raster.height - side) / 2
  let raster = try QL600Raster.encode(width: QL600Raster.width, height: QL600Raster.height) { x, y in
    let column = (x - left) / scale - 4
    let row = (y - top) / scale - 4
    guard x >= left, y >= top, column >= 0, row >= 0, column < size, row < size else { return false }
    return rows[row][column] == "1"
  }
  let output = URL(fileURLWithPath: CommandLine.arguments[2])
  guard !FileManager.default.fileExists(atPath: output.path) else {
    throw NSError(domain: "Output already exists", code: 3)
  }
  try raster.write(to: output, options: .withoutOverwriting)
  print("Synthetic label: \(QL600Raster.width) x \(QL600Raster.height) dots; \(raster.count) bytes")
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
