import SwiftUI

struct CloudSettings: View {
  @ObservedObject private var account = CloudAccount.shared
  var body: some View {
    Section(L10n.text("Foliobruma account")) {
      if let user = account.user {
        LabeledContent(L10n.text("Signed in as"), value: user.email)
        Picker(L10n.text("Upload archive"), selection: $account.organisationID) {
          Text(L10n.text("Select an archive")).tag("")
          ForEach(account.organisations) { archive in Text(archive.name).tag(archive.id) }
        }
        .disabled(account.working)
        if account.organisations.isEmpty {
          Text(L10n.text("Create or join an archive on foliobruma.com, then sign in again."))
        }
        Button(L10n.text("Sign out")) { Task { await account.signOut() } }.disabled(account.working)
      } else {
        if let code = account.pairingCode {
          Text(L10n.text("Waiting for website sign-in…"))
          Text(code).font(.title2.monospaced()).textSelection(.enabled)
          Text(L10n.text("Check this code on the website, then approve the connection."))
          HStack {
            Button(L10n.text("Open sign-in page"), action: account.openSignInPage)
            Button(L10n.text("Cancel sign-in"), action: account.cancelSignIn)
          }
        } else {
          Button(L10n.text("Connect on website"), action: account.connectOnWebsite)
            .disabled(account.working)
          Text(L10n.text("Your normal browser opens Foliobruma. Sign in there, then return to the scanner."))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Toggle(L10n.text("Upload when I finish an item"), isOn: $account.automatic).disabled(account.working)
      Toggle(L10n.text("Print a label after upload"), isOn: $account.printLabel).disabled(account.working)
      Text(L10n.text("Finish item uploads all saved pages as one PDF. Next letter also finishes the current letter. Both options are off by default."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("Scans stay on this Mac. Upload requires an account and an archive. Labels open a private PDF link; sign in on the reading device first."))
        .font(.caption).foregroundStyle(.secondary)
      Link(L10n.text("Open Foliobruma"), destination: CloudAPI.origin.appendingPathComponent("app/"))
      if account.working { ProgressView().controlSize(.small) }
      if let failure = account.failure { Text(failure).foregroundStyle(.red).textSelection(.enabled) }
    }
      .task { await account.restore() }
  }
}
