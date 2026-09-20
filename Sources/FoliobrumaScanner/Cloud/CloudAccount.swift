import Foundation
import Combine
import AppKit

struct CloudUser: Decodable { let id: String; let email: String }
struct CloudOrganisation: Decodable, Identifiable { let id: String; let name: String }

@MainActor final class CloudAccount: ObservableObject {
  static let shared = CloudAccount()
  let api = CloudAPI()
  @Published var user: CloudUser?
  @Published var organisations: [CloudOrganisation] = []
  @Published var working = false
  @Published var failure: String?
  @Published var organisationID = UserDefaults.standard.string(forKey: "cloudOrganisation") ?? "" {
    didSet { UserDefaults.standard.set(organisationID, forKey: "cloudOrganisation") }
  }
  @Published var automatic = UserDefaults.standard.bool(forKey: "cloudAutomatic") {
    didSet { UserDefaults.standard.set(automatic, forKey: "cloudAutomatic") }
  }
  @Published var printLabel = UserDefaults.standard.bool(forKey: "cloudPrintLabel") {
    didSet { UserDefaults.standard.set(printLabel, forKey: "cloudPrintLabel") }
  }
  @Published var pairingCode: String?
  @Published var signInURL: URL?
  private var signInTask: Task<Void, Never>?
  private var expiration: AnyCancellable?
  private var restored = false
  init() {
    expiration = NotificationCenter.default.publisher(for: CloudAPI.sessionExpired, object: api)
      .receive(on: DispatchQueue.main).sink { [weak self] _ in
        self?.user = nil
        self?.organisations = []
        self?.failure = L10n.text("Your session has expired. Sign in again in Settings.")
      }
  }
  func cancelSignIn() { signInTask?.cancel() }
  func openSignInPage() {
    if let signInURL { NSWorkspace.shared.open(signInURL) }
  }
  var ready: Bool { user != nil && organisations.contains { $0.id == organisationID } }
  func restore() async {
    guard !restored, !working else { return }
    restored = true
    working = true
    defer { working = false }
    do {
      guard let data = try CloudKeychain.read() else { return }
      try api.restore(data)
      try await loadAccount()
    } catch { failure = error.localizedDescription }
  }
  func connectOnWebsite() {
    guard !working else { return }
    working = true
    failure = nil
    signInTask = Task {
      defer { working = false; pairingCode = nil; signInURL = nil; signInTask = nil }
      do {
        let pairing = try CloudPairing.create()
        let body = try JSONSerialization.data(withJSONObject: ["challenge": pairing.challenge])
        let data = try await api.request("api/scanner/pair/start", method: "POST", body: body)
        try Task.checkCancellation()
        let ticket = try JSONDecoder().decode(CloudPairing.Ticket.self, from: data)
        let url = try pairing.browserURL(ticket: ticket)
        try CloudKeychain.remove()
        api.clear()
        try api.restore(JSONEncoder().encode(pairing.token))
        user = nil
        organisations = []
        organisationID = ""
        pairingCode = pairing.code
        signInURL = url
        guard NSWorkspace.shared.open(url) else { throw CloudFailure(message: "Could not open the browser. Try again.") }
        struct Poll: Decodable { let user: CloudUser? }
        while Date().timeIntervalSince1970 * 1000 < ticket.expires {
          try Task.checkCancellation()
          let response = try await api.request("api/scanner/pair/poll")
          try Task.checkCancellation()
          let result = try JSONDecoder().decode(Poll.self, from: response)
          if result.user != nil {
            try await loadAccount()
            // Closing a pending connection must not retain its credentials.
            if Task.isCancelled { try CloudKeychain.remove(); throw CancellationError() }
            return
          }
          try await Task.sleep(for: .seconds(3))
        }
        throw CloudFailure(message: "The connection request expired. Start again.")
      } catch {
        api.clear()
        user = nil
        organisations = []
        if !Task.isCancelled { failure = error.localizedDescription }
      }
    }
  }
  func loadAccount() async throws {
    struct Session: Decodable { let user: CloudUser }
    struct Archives: Decodable { let organisations: [CloudOrganisation] }
    guard let session = try JSONDecoder().decode(Session?.self, from: await api.request("api/auth/get-session")) else {
      api.clear()
      throw CloudFailure(message: "Your session has expired. Sign in again in Settings.")
    }
    let archives = try JSONDecoder().decode(Archives.self, from: await api.request("api/organisations"))
    try CloudKeychain.save(api.credentials())
    user = session.user
    organisations = archives.organisations
    if !organisations.contains(where: { $0.id == organisationID }) { organisationID = "" }
  }
  func signOut() async {
    guard !working else { return }
    working = true
    defer { working = false }
    do {
      try CloudKeychain.remove()
      automatic = false
      user = nil
      organisations = []
      organisationID = ""
      do { _ = try await api.request("api/auth/sign-out", method: "POST", body: Data("{}".utf8)); failure = nil }
      catch { failure = L10n.text("Signed out on this Mac. The server session could not be closed.") }
      api.clear()
    } catch { failure = error.localizedDescription }
  }
}
