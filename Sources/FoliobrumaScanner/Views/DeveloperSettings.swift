import SwiftUI

struct DeveloperSettings: View {
  @State private var clicks = 0
  @State private var unlocked = UserDefaults.standard.bool(forKey: "scannerDeveloperMode")
  @State private var enabled = UserDefaults.standard.bool(forKey: "scannerDeveloperMode")
  @State private var address = UserDefaults.standard.string(forKey: "scannerServerURL") ?? "https://staging.foliobruma.com"
  @State private var message: String?
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
        if let message { Text(message).font(.callout).fixedSize(horizontal: false, vertical: true) }
      }
    }
  }
}
