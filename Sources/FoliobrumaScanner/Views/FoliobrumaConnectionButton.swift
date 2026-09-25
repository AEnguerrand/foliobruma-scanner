import SwiftUI

struct FoliobrumaConnectionButton: View {
  @ObservedObject var model: Scanner
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
        Text(verbatim: "Foliobruma")
        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.borderless)
    .padding(.vertical, 6)
    .fixedSize()
    .accessibilityValue(L10n.text(account.user == nil ? "Signed out" : "Signed in"))
    .help(account.user?.email ?? L10n.text("Connect to Foliobruma"))
    .popover(isPresented: $showAccount, arrowEdge: .bottom) {
      Form { CloudSettings(); SessionFinishSettings(model: model) }.formStyle(.grouped).fittedPanel(width: 420, height: account.pairingCode != nil || account.user != nil ? 650 : 600)
    }
  }
}
