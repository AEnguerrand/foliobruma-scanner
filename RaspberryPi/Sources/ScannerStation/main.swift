import Foundation
import StationCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

// Private, serial IPC. HTTP requests never reach this pipe directly.
umask(0o077)
do {
  let args = CommandLine.arguments
  guard args.count >= 2 else { throw StationFailureForCLI.usage }
  let reserve = args.firstIndex(of: "--reserve-bytes").flatMap { $0 + 1 < args.count ? UInt64(args[$0 + 1]) : nil } ?? 512 * 1024 * 1024
  let station = try Station(root: URL(fileURLWithPath: args[1]), initialize: args.contains("--initialize"), reserve: reserve)
  while let line = readLine() {
    do {
      guard line.utf8.count <= 65536, let data = line.data(using: .utf8),
            let request = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw StationFailureForCLI.usage }
      let result = try station.handle(request)
      let output = try JSONSerialization.data(withJSONObject: ["ok": result], options: [.sortedKeys])
      print(String(decoding: output, as: UTF8.self))
    } catch {
      let code = (error as? StationFailure)?.code ?? "storage"
      print("{\"error\":\"\(code)\"}")
      if !(error is StationFailure) || code == "library_missing" { fflush(stdout); exit(1) }
    }
    fflush(stdout)
  }
} catch {
  let code = (error as? StationFailure)?.code ?? "startup_failed"
  FileHandle.standardError.write(Data("Station: \(code)\n".utf8)); exit(1)
}
enum StationFailureForCLI: Error { case usage }
