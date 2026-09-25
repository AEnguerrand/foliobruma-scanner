import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
  case general, usb, account, advanced
  var id: String { rawValue }
  var title: String {
    switch self {
    case .general: return "General"
    case .usb: return "USB button"
    case .account: return "Account"
    case .advanced: return "Advanced"
    }
  }
  var icon: String {
    switch self {
    case .general: return "gearshape"
    case .usb: return "button.programmable"
    case .account: return "person.crop.circle"
    case .advanced: return "slider.horizontal.3"
    }
  }
}

struct SettingsView: View {
  @AppStorage("appLanguage") private var language = "system"
  @State private var page: SettingsPage = .general

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 10) {
          BrandIcon().frame(width: 32, height: 32).accessibilityHidden(true)
          Text(verbatim: "Foliobruma").font(.headline)
        }.padding(.horizontal, 18).padding(.top, 24)
        List(SettingsPage.allCases, selection: $page) { item in
          Label(L10n.text(item.title), systemImage: item.icon)
            .padding(.vertical, 5).tag(item)
        }.listStyle(.sidebar)
      }.frame(width: 190)
      Divider()
      VStack(alignment: .leading, spacing: 0) {
        Text(L10n.text(page.title)).font(.title2.weight(.semibold))
          .padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 8)
        Form {
          switch page {
          case .general: general
          case .usb: USBButtonSettings()
          case .account: CloudSettings()
          case .advanced: DeveloperSettings()
          }
        }.formStyle(.grouped)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    .frame(width: 820, height: 620)
    // Track the Settings window itself, not the lifetime of an individual page.
    .background(USBButtonWindow { USBButton.shared.settingsWindow = $0 })
    .onAppear { USBButton.shared.start() }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
      guard let window = notification.object as? NSWindow,
        window === USBButton.shared.settingsWindow else { return }
      USBButton.shared.cancelLearning()
    }
  }

  private var general: some View {
    Group {
      Section {
        Picker(L10n.text("Language"), selection: $language) {
          Text(L10n.text("System language")).tag("system")
          Text(verbatim: "English").tag("en")
          Text(verbatim: "Français").tag("fr")
        }.onChange(of: language) { _, value in L10n.setLanguage(value) }
      } footer: {
        Text(L10n.text("Quit and reopen the app to apply a language change."))
      }
      Section(L10n.text("About")) {
        LabeledContent(L10n.text("Version")) {
          Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
            .foregroundStyle(.secondary)
        }
        Text(L10n.text("Scanning and PDF export work offline. Your scans stay on this Mac."))
          .font(.callout).foregroundStyle(.secondary)
      }
    }
  }
}
