import Foundation
import ScannerCore

extension ItemReference {
  static func reserve(in root: URL, letter: Bool) throws -> String {
    try reserve(in: root, letter: letter, locking: MacLibraryLock())
  }
}
