import Foundation

// QL-600, 62 mm continuous tape at 300 dpi. The platform supplies black pixels.
public enum QL600Raster {
  public static let width = 696
  public static let height = 225

  public static func encode(width: Int, height: Int, isBlack: (Int, Int) throws -> Bool) throws -> Data {
    guard width == Self.width, height == Self.height else {
      throw CloudFailure(message: "The label dimensions are invalid.")
    }
    var result = Data(repeating: 0, count: 200)
    result.append(contentsOf: [0x1b, 0x40, 0x1b, 0x69, 0x61, 1])
    result.append(contentsOf: [0x1b, 0x69, 0x7a, 0xce, 0x0a, 62, 0, UInt8(height), 0, 0, 0, 0, 0])
    result.append(contentsOf: [0x1b, 0x69, 0x4d, 0x40, 0x1b, 0x69, 0x41, 1,
                              0x1b, 0x69, 0x4b, 8, 0x1b, 0x69, 0x64, 35, 0])
    for y in 0..<height {
      var row = [UInt8](repeating: 0, count: 90)
      for x in 0..<width {
        if try isBlack(x, y) {
          // Pins are numbered from the right edge of the head.
          let pin = 12 + width - 1 - x
          row[pin / 8] |= UInt8(0x80 >> (pin % 8))
        }
      }
      result.append(contentsOf: [0x67, 0, 90])
      result.append(contentsOf: row)
    }
    result.append(0x1a)
    return result
  }
}
