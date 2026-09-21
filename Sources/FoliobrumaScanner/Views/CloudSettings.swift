import SwiftUI

struct CloudSettings: View {
  @ObservedObject private var account = CloudAccount.shared

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          Image(systemName: "person.crop.circle").font(.title)
            .foregroundStyle(.secondary).accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "Foliobruma").font(.headline)
            Text(account.user?.email ?? L10n.text("Connect your account"))
              .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
          }
          Spacer(minLength: 0)
          if account.working { ProgressView().controlSize(.small) }
        }
        if account.user != nil {
          HStack {
            Link(L10n.text("Open Foliobruma"), destination: CloudAPI.origin.appendingPathComponent("app/"))
            Spacer()
            Button(L10n.text("Sign out")) { Task { await account.signOut() } }
              .disabled(account.working)
          }
        } else if let code = account.pairingCode {
          Text(L10n.text("Waiting for website sign-in…")).font(.callout)
          Text(code).font(.title2.monospaced()).textSelection(.enabled)
          Text(L10n.text("Check this code on the website, then approve the connection."))
            .font(.caption).foregroundStyle(.secondary)
          HStack {
            Button(L10n.text("Open sign-in page"), action: account.openSignInPage)
            Button(L10n.text("Cancel sign-in"), action: account.cancelSignIn)
          }
        } else {
          Text(L10n.text("Sign in with your browser to upload scans to your archive."))
            .font(.callout).foregroundStyle(.secondary)
          Button(action: account.connectOnWebsite) {
            Label(L10n.text("Connect on website"), systemImage: "arrow.up.right")
          }.buttonStyle(.borderedProminent).disabled(account.working)
        }
        if let failure = account.failure {
          Label(failure, systemImage: "exclamationmark.circle")
            .font(.callout).foregroundStyle(.red).textSelection(.enabled)
        }
      }.padding(.vertical, 4)
    }
    Section {
      if account.user != nil {
        Picker(L10n.text("Upload archive"), selection: $account.organisationID) {
          Text(L10n.text("Select an archive")).tag("")
          ForEach(account.organisations) { archive in Text(archive.name).tag(archive.id) }
        }.disabled(account.working)
        if account.organisations.isEmpty {
          Text(L10n.text("Create or join an archive on foliobruma.com, then sign in again."))
            .font(.caption).foregroundStyle(.secondary)
        }
      }

    } header: {
      Text(L10n.text("Upload destination"))
    } footer: {
      Text(L10n.text("Scans stay on this Mac. Upload needs an account and an archive. Label links require website sign-in."))
        .font(.caption).foregroundStyle(.secondary)
    }
    .task { await account.restore() }
  }
}
