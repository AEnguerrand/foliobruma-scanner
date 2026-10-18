import Foundation
import ScannerCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct StationFailure: Error { public let code: String }
private func require(_ condition: Bool, _ code: String) throws {
  if !condition { throw StationFailure(code: code) }
}
private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
  try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
}
private func decode<T: Decodable>(_ value: Any, as: T.Type) throws -> T {
  try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}

// One process owns this library. The OS releases the lock after a crash.
// Python owns HTTPS and devices; only this coordinator changes session state.
public final class Station {
  private let root: URL
  private var state: [String: Any]
  private let lock: Int32
  private let reserve: UInt64
  private var jobs: [String: [String: Any]] {
    get { state["jobs"] as? [String: [String: Any]] ?? [:] }
    set { state["jobs"] = newValue }
  }
  private var revisions: [String: Int] {
    get { state["revisions"] as? [String: Int] ?? [:] }
    set { state["revisions"] = newValue }
  }
  public init(root: URL, initialize: Bool, reserve: UInt64 = 512 * 1024 * 1024) throws {
    self.root = root.standardizedFileURL
    self.reserve = reserve
    let fm = FileManager.default
    if initialize {
      try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      let marker = root.appendingPathComponent("station-library")
      if !fm.fileExists(atPath: marker.path) { try Data("Foliobruma Pi 1\n".utf8).write(to: marker, options: .withoutOverwriting) }
    }
    try require(fm.fileExists(atPath: root.appendingPathComponent("station-library").path), "library_missing")
    lock = open(root.appendingPathComponent("station.lock").path, O_CREAT | O_RDWR, 0o600)
    try require(lock >= 0, "library_locked")
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { close(lock); throw StationFailure(code: "library_locked") }
    state = ["jobs": [:], "revisions": [:], "undo": [:]]
    let file = root.appendingPathComponent("station.json")
    if fm.fileExists(atPath: file.path) {
      state = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    }
    try fm.createDirectory(at: root.appendingPathComponent("Jobs"), withIntermediateDirectories: true)
    for (id, job) in jobs {
      if job["status"] as? String == "committing" { try commit(id) }
      else if job["status"] as? String == "processing" {
        var next = job; next["status"] = "failed"; next["error"] = "interrupted"; jobs[id] = next
      }
    }
    try persist()
  }
  deinit { flock(lock, LOCK_UN); close(lock) }

  private func sync(_ file: URL, directory: Bool = false) throws {
    let fd = open(file.path, O_RDONLY)
    try require(fd >= 0, "storage")
    defer { close(fd) }
    try require(fsync(fd) == 0, "storage")
  }
  private func write(_ data: Data, to file: URL) throws {
    try data.write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    try sync(file); try sync(file.deletingLastPathComponent(), directory: true)
  }
  private func checkLibrary() throws {
    let marker = root.appendingPathComponent("station-library")
    try require((try? String(contentsOf: marker, encoding: .utf8)) == "Foliobruma Pi 1\n", "library_missing")
  }
  private func persist() throws {
    try checkLibrary()
    try write(JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]), to: root.appendingPathComponent("station.json"))
  }
  private func uuid(_ value: Any?) throws -> String {
    guard let s = value as? String, UUID(uuidString: s) != nil else { throw StationFailure(code: "invalid") }
    return s.uppercased()
  }
  private func store(_ id: String) -> SessionStore { SessionStore(folder: root.appendingPathComponent("Sessions/" + id)) }
  private func checkSpace() throws {
    try checkLibrary()
    let a = try FileManager.default.attributesOfFileSystem(forPath: root.path)
    let free = (a[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
    try require(free > reserve + 128 * 1024 * 1024, "disk_full")
  }
  private func page(_ req: [String: Any], _ doc: ScanDocument) throws -> ScanPage {
    guard let p = doc.pages.first(where: { $0.id == req["page"] as? String }) else { throw StationFailure(code: "page_missing") }
    return p
  }
  private func safeFile(_ file: URL) throws -> String {
    let resolved = file.resolvingSymlinksInPath().path
    try require(resolved.hasPrefix(root.resolvingSymlinksInPath().path + "/"), "invalid")
    try require(FileManager.default.fileExists(atPath: resolved), "file_missing")
    return resolved
  }
  private func commit(_ id: String) throws {
    var job = jobs[id]!
    let sid = job["session"] as! String
    let doc = try decode(job["document"]!, as: ScanDocument.self)
    let target = store(sid)
    try target.prepare()
    try sync(root.appendingPathComponent("Sessions"), directory: true)
    try sync(root, directory: true)
    try target.save(doc)
    try sync(target.manifest); try sync(target.folder, directory: true)
    revisions[sid] = job["revision"] as? Int
    if let undo = job["undo"] {
      var undos = state["undo"] as? [String: Any] ?? [:]; undos[sid] = undo; state["undo"] = undos
    }
    job["status"] = "done"; job.removeValue(forKey: "document"); job.removeValue(forKey: "undo")
    jobs[id] = job; try persist()
  }
  private func prepareCommit(_ id: String, document: ScanDocument, undo: Any? = nil) throws {
    var job = jobs[id]!
    let sid = job["session"] as! String
    job["document"] = try object(document); job["revision"] = (revisions[sid] ?? 0) + 1
    job["status"] = "committing"
    if let undo { job["undo"] = undo }
    jobs[id] = job; try persist(); try commit(id)
  }
  public func handle(_ req: [String: Any]) throws -> [String: Any] {
    let op = req["op"] as? String ?? ""
    if op == "snapshot" {
      let docs = try revisions.keys.sorted().map { id -> [String: Any] in
        ["id": id, "revision": revisions[id]!, "document": try object(store(id).load()),
         "canUndo": !((state["undo"] as? [String: [String: Any]])?[id] ?? [:]).isEmpty]
      }
      return ["sessions": docs, "busy": jobs.values.contains { ["processing", "committing"].contains($0["status"] as? String ?? "") }]
    }
    let id = try uuid(req["id"])
    if op == "job" { guard let j = jobs[id] else { throw StationFailure(code: "job_missing") }; return j }
    if op == "file" {
      if req["kind"] as? String == "export" {
        guard let j = jobs[id], j["status"] as? String == "done", j["kind"] as? String == "export" else { throw StationFailure(code: "file_missing") }
        return ["path": try safeFile(root.appendingPathComponent("Jobs/\(id)/export.pdf"))]
      }
      try require(revisions[id] != nil, "session_missing")
      let p = try page(req, store(id).load())
      let rel = req["kind"] as? String == "original" ? p.original : p.file
      return ["path": try safeFile(store(id).folder.appendingPathComponent(rel)), "rotation": p.rotation]
    }
    if op == "fail" {
      guard var j = jobs[id], j["status"] as? String == "processing" else { throw StationFailure(code: "invalid") }
      j["status"] = "failed"; j["error"] = req["error"] as? String ?? "processing_failed"
      jobs[id] = j; try persist(); return j
    }
    if op == "finish" {
      guard let j = jobs[id], j["status"] as? String == "processing" else { throw StationFailure(code: "invalid") }
      let sid = j["session"] as! String
      let kind = j["kind"] as! String
      let staging = root.appendingPathComponent("Jobs/\(id)")
      if kind == "export" {
        try sync(staging.appendingPathComponent("export.pdf")); try sync(staging, directory: true)
        var next = j; next["status"] = "done"; jobs[id] = next; try persist()
      } else {
        let target = store(sid); try target.prepare()
        var doc = try target.load()
        let original: String
        let rotation: Int
        let oldPage = j["page"] as? String
        if kind == "crop" {
          let p = try page(["page": oldPage ?? ""], doc); original = p.original; rotation = p.rotation
        } else {
          original = "Originals/\(id).jpg"; rotation = 0
          try FileManager.default.moveItem(at: staging.appendingPathComponent("original.jpg"), to: target.folder.appendingPathComponent(original))
          try sync(target.folder.appendingPathComponent(original)); try sync(target.folder.appendingPathComponent("Originals"), directory: true)
        }
        let file = "Pages/\(id).jpg"
        try FileManager.default.moveItem(at: staging.appendingPathComponent("page.jpg"), to: target.folder.appendingPathComponent(file))
        try sync(target.folder.appendingPathComponent(file)); try sync(target.folder.appendingPathComponent("Pages"), directory: true)
        let p = ScanPage(id: oldPage ?? UUID().uuidString, file: file, original: original, rotation: rotation)
        doc = try doc.applyingCapture([p], replacing: oldPage, resolving: nil)
        try prepareCommit(id, document: doc)
      }
      return jobs[id]!
    }
    try require(op == "begin", "invalid")
    let body = req["command"] as? [String: Any] ?? [:]
    let canonical = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]).base64EncodedString()
    if let existing = jobs[id] {
      try require(existing["request"] as? String == canonical, "command_reused")
      return existing
    }
    try require(jobs.count < 10000, "journal_full")
    try require(!jobs.values.contains { ["processing", "committing"].contains($0["status"] as? String ?? "") }, "busy")
    try checkSpace()
    let kind = body["kind"] as? String ?? ""
    let sid = kind == "create" ? UUID().uuidString : try uuid(body["session"])
    var doc = ScanDocument(title: "", pages: [])
    if kind != "create" {
      try require(revisions[sid] != nil, "session_missing")
      try require(body["revision"] as? Int == revisions[sid], "stale")
      doc = try store(sid).load()
    }
    var job: [String: Any] = ["id": id, "kind": kind, "session": sid, "request": canonical, "status": "processing"]
    var undo: Any?
    switch kind {
    case "create", "rename":
      let title = body["title"] as? String ?? ""
      try require(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 160, "invalid")
      doc.title = title
    case "rotate": doc = doc.rotating(try page(body, doc))!
    case "move":
      try require([-1, 1].contains(body["delta"] as? Int ?? 0), "invalid")
      guard let next = doc.movingPage(id: try page(body, doc).id, by: body["delta"] as! Int) else { throw StationFailure(code: "invalid") }
      doc = next
    case "remove":
      let p = try page(body, doc); let removed = doc.removing(p)!
      doc = removed.document; undo = ["page": try object(p), "index": removed.index]
    case "undo":
      guard let saved = (state["undo"] as? [String: [String: Any]])?[sid], let p = saved["page"], let index = saved["index"] as? Int else { throw StationFailure(code: "invalid") }
      doc = doc.restoring(try decode(p, as: ScanPage.self), at: index); undo = [String: String]()
    case "capture", "crop", "export":
      try require(doc.pages.count < 500 || kind != "capture", "page_limit")
      let folder = root.appendingPathComponent("Jobs/\(id)")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
      try sync(folder.deletingLastPathComponent(), directory: true)
      job["folder"] = folder.path
      if kind == "crop" {
        let p = try page(body, doc); job["page"] = p.id
        job["source"] = try safeFile(store(sid).folder.appendingPathComponent(p.original))
      }
      if kind == "export" {
        try require(!doc.pages.isEmpty, "invalid")
        job["inputs"] = try doc.pages.map { p in ["path": try safeFile(store(sid).folder.appendingPathComponent(p.file)), "rotation": p.rotation] as [String: Any] }
      }
    default: throw StationFailure(code: "invalid")
    }
    jobs[id] = job
    if ["capture", "crop", "export"].contains(kind) { try persist() }
    else { try prepareCommit(id, document: doc, undo: undo) }
    return jobs[id]!
  }
}
