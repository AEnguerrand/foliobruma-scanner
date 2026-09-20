import Foundation
import Combine

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
  private var restored = false
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
  func signIn(email: String, password: String) async {
    guard !working else { return }
    working = true
    failure = nil
    defer { working = false }
    do {
      try CloudKeychain.remove()
      api.clear()
      organisationID = ""
      let body = try JSONSerialization.data(withJSONObject: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
      _ = try await api.request("api/auth/sign-in/email", method: "POST", body: body)
      try await loadAccount()
    } catch { user = nil; organisations = []; api.clear(); failure = error.localizedDescription }
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
