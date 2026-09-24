import Foundation

// Implementations must hold an exclusive cross-process lock until the body returns.
// There is deliberately no default or no-op production lock.
public protocol LibraryLocking {
  func withLock<T>(at url: URL, _ body: () throws -> T) throws -> T
}
