import AppKit
import SwiftUI

struct BrandIcon: View {
  private static let image: NSImage? = {
    guard let url = Bundle.main.url(forResource: "ScannerIcon", withExtension: "png") else { return nil }
    return NSImage(contentsOf: url)
  }()

  var body: some View {
    if let image = Self.image {
      Image(nsImage: image).resizable().renderingMode(.original).scaledToFit()
    }
  }
}
