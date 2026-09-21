import SwiftUI

struct DeveloperSettings: View {
  @State private var clicks = 0
  @State private var unlocked = UserDefaults.standard.bool(forKey: "scannerDeveloperMode")
  @State private var enabled = UserDefaults.standard.bool(forKey: "scannerDeveloperMode")
  @State private var address = UserDefaults.standard.string(forKey: "scannerServerURL") ?? "https://staging.foliobruma.com"
  @State private var message: String?
  @State private var clientID = ""
  @State private var clientSecret = ""
  @ObservedObject private var account = CloudAccount.shared

  var body: some View {
    Section {
      Button {
        clicks += 1
        if clicks >= 5 { unlocked = true }
      } label: {
        Text("Foliobruma Scanner · " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"))
          .font(.caption).foregroundStyle(.secondary)
      }.buttonStyle(.plain)
      if unlocked {
        Toggle(L10n.text("Developer mode"), isOn: $enabled)
        if enabled {
          TextField(L10n.text("Server URL"), text: $address)
          Text(L10n.text("Use an HTTPS origin without a path. This server receives new uploads and issues label URLs. Its sign-in is separate from production."))
            .font(.caption).foregroundStyle(.secondary)
        }
        Button(L10n.text("Save server settings")) {
          guard !enabled || CloudEnvironment.normalizedOrigin(address) != nil else {
            message = L10n.text("Enter an HTTPS server URL without a path, query, or sign-in details.")
            return
          }
          if let url = CloudEnvironment.normalizedOrigin(address) {
            UserDefaults.standard.set(url.absoluteString, forKey: "scannerServerURL")
          }
          UserDefaults.standard.set(enabled, forKey: "scannerDeveloperMode")
          message = L10n.text("Saved. Quit and reopen the scanner to use this server. Current requests keep their original server.")
        }.disabled(account.working)
        Text(L10n.text("Current server") + ": " + account.api.baseURL.absoluteString)
          .font(.caption).textSelection(.enabled)
        if enabled && account.api.baseURL != CloudEnvironment.production {
          Text(L10n.text("Cloudflare Access token for current server")).font(.headline)
          TextField(L10n.text("Access client ID"), text: $clientID)
          SecureField(L10n.text("Access client secret"), text: $clientSecret)
          HStack {
            Button(L10n.text("Save Access token")) { saveAccess() }
              .disabled(account.working || clientID.isEmpty || clientSecret.isEmpty)
            Button(L10n.text("Remove Access token")) { saveAccess(remove: true) }
              .disabled(account.working || account.api.access == nil)
          }
          Text(L10n.text(account.api.access == nil ? "No Access token loaded." : "Access token loaded from Keychain."))
            .font(.caption)
        }
        if let message { Text(message).font(.callout).fixedSize(horizontal: false, vertical: true) }
      }
    }
  }

  private func saveAccess(remove: Bool = false) {
    let origin = account.api.baseURL
    guard CloudEnvironment.normalizedOrigin(address) == origin else {
      message = L10n.text("Save the server URL and restart before setting its Access token.")
      return
    }
    let value = CloudAccess(clientID: clientID, clientSecret: clientSecret)
    account.working = true
    Task { @MainActor in
      defer { account.working = false }
      do {
        try await Task.detached {
          if remove { try CloudAccess.remove(origin) }
          else { try value.save(origin) }
        }.value
        account.api.access = remove ? nil : value
        account.failure = nil
        clientID = ""
        clientSecret = ""
        message = L10n.text(remove ? "Access token removed." : "Access token saved in Keychain for the current server.")
      } catch { message = error.localizedDescription }
    }
  }
}
