import Foundation

// One print history per session, shared by manual and automatic printing.
// A pending job is an unknown result after a crash; it must never retry silently.
public struct LabelPrintStore: Codable {
  public enum State: String, Codable { case pending, submitted }
  fileprivate struct Entry: Codable {
    var state: State
    var job: UUID
  }
  public struct Ticket {
    fileprivate let link: String
    fileprivate let job: UUID
    fileprivate let previous: Entry?
  }
  private var entries: [String: Entry] = [:]

  private static func load(in folder: URL) throws -> Self {
    let file = folder.appendingPathComponent("label-prints.json")
    guard FileManager.default.fileExists(atPath: file.path) else { return Self() }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
  }
  private func save(in folder: URL) throws {
    try JSONEncoder().encode(self).write(to: folder.appendingPathComponent("label-prints.json"), options: .atomic)
  }
  private func entry(in folder: URL, link: String) throws -> Entry? {
    if let entry = entries[link] { return entry }
    // Old automatic jobs remain protected when opening an existing session.
    if let upload = try CloudUpload.load(in: folder), upload.link == link {
      if upload.labelNeedsReview { return Entry(state: .pending, job: UUID()) }
      if upload.sheetLabelSubmitted == true { return Entry(state: .submitted, job: UUID()) }
    }
    return nil
  }
  public static func state(in folder: URL, link: String) throws -> State? {
    try load(in: folder).entry(in: folder, link: link)?.state
  }
  public static func begin(in folder: URL, link: String, reprint: Bool = false,
                           lock: any LibraryLocking) throws -> Ticket {
    try lock.withLock(at: folder.appendingPathComponent(".label-print.lock")) {
      var store = try load(in: folder)
      let previous = try store.entry(in: folder, link: link)
      guard reprint || previous == nil else {
        throw CloudFailure(message: "This label was already sent or its print result is unknown. Check the printer before choosing Reprint.")
      }
      let job = UUID()
      store.entries[link] = Entry(state: .pending, job: job)
      try store.save(in: folder)
      return Ticket(link: link, job: job, previous: previous)
    }
  }
  public static func finish(_ ticket: Ticket, in folder: URL, submitted: Bool,
                            mayHavePrinted: Bool, lock: any LibraryLocking) throws {
    try lock.withLock(at: folder.appendingPathComponent(".label-print.lock")) {
      var store = try load(in: folder)
      guard store.entries[ticket.link]?.job == ticket.job else {
        throw CloudFailure(message: "The label print record changed. Check the printer before continuing.")
      }
      if submitted { store.entries[ticket.link]?.state = .submitted }
      else if !mayHavePrinted { store.entries[ticket.link] = ticket.previous }
      try store.save(in: folder)
    }
  }
  public static func confirmHandled(in folder: URL, link: String, lock: any LibraryLocking) throws {
    try lock.withLock(at: folder.appendingPathComponent(".label-print.lock")) {
      var store = try load(in: folder)
      store.entries[link] = Entry(state: .submitted, job: UUID())
      try store.save(in: folder)
    }
  }
}
