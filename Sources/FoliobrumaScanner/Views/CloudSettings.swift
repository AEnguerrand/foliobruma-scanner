import SwiftUI

struct CloudSettings: View {
  @ObservedObject private var account = CloudAccount.shared
  @State private var email = ""
  @State private var password = ""
  var body: some View {
    Section(L10n.text("Foliobruma account")) {
      if let user = account.user {
        LabeledContent(L10n.text("Signed in as"), value: user.email)
        Picker(L10n.text("Upload archive"), selection: $account.organisationID) {
          Text(L10n.text("Select an archive")).tag("")
          ForEach(account.organisations) { archive in Text(archive.name).tag(archive.id) }
        }
        if account.organisations.isEmpty {
          Text(L10n.text("Create or join an archive on foliobruma.com, then sign in again."))
        }
        Button(L10n.text("Sign out")) { Task { await account.signOut() } }
      } else {
        TextField(L10n.text("Email"), text: $email).textContentType(.username)
        SecureField(L10n.text("Password"), text: $password).textContentType(.password)
        Button(L10n.text("Sign in")) {
          let secret = password
          password = ""
          Task { await account.signIn(email: email, password: secret) }
        }.disabled(email.isEmpty || password.isEmpty)
      }
      Toggle(L10n.text("Upload when I finish an item"), isOn: $account.automatic)
      Toggle(L10n.text("Print a label after upload"), isOn: $account.printLabel)
      Text(L10n.text("Finish item uploads all saved pages as one PDF. Next letter also finishes the current letter. Both options are off by default."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("Scans stay on this Mac. Upload requires an account and an archive. Labels open a private PDF link; sign in on the reading device first."))
        .font(.caption).foregroundStyle(.secondary)
      Link(L10n.text("Open Foliobruma"), destination: CloudAPI.origin.appendingPathComponent("app/"))
      if account.working { ProgressView().controlSize(.small) }
      if let failure = account.failure { Text(failure).foregroundStyle(.red).textSelection(.enabled) }
    }.disabled(account.working)
      .task { await account.restore() }
  }
}
