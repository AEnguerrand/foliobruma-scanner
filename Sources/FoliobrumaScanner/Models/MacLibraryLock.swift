import Foundation
import Darwin
import ScannerCore

struct MacLibraryLock: LibraryLocking {
  func withLock<T>(at url: URL, _ body: () throws -> T) throws -> T {
    let descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw POSIXError(.EIO) }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
    defer { flock(descriptor, LOCK_UN) }
    return try body()
  }
}
