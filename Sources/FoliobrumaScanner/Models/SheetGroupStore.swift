import Foundation
import ScannerCore

extension SheetGroupStore {
  mutating func save(_ group: SheetGroup, in root: URL) throws {
    try save(group, in: root, locking: MacLibraryLock())
  }
}
