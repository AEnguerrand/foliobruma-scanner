import SwiftUI

struct FoliobrumaConnectionButton: View {
  @ObservedObject private var account = CloudAccount.shared
  @State private var showAccount = false

  var body: some View {
    Button { showAccount.toggle() } label: {
      HStack(spacing: 6) {
        if account.working {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: account.user == nil ? "person.crop.circle" : "person.crop.circle.badge.checkmark")
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: "Foliobruma")
          Text(L10n.text(account.user == nil ? "Signed out" : "Signed in"))
            .font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .fixedSize()
    .help(account.user?.email ?? L10n.text("Connect to Foliobruma"))
    .popover(isPresented: $showAccount, arrowEdge: .bottom) {
      Form { CloudSettings() }.formStyle(.grouped).frame(width: 480, height: 500)
    }
  }
}
