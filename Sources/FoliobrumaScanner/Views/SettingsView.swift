import SwiftUI

struct SettingsView: View {
  @AppStorage("appLanguage") private var language = "system"

  var body: some View {
    Form {
      Picker(L10n.text("Language"), selection: $language) {
        Text(L10n.text("System language")).tag("system")
        Text(verbatim: "English").tag("en")
        Text(verbatim: "Français").tag("fr")
      }
      .onChange(of: language) { _, value in L10n.setLanguage(value) }
      Text(L10n.text("Quit and reopen the app to apply a language change."))
        .font(.callout).foregroundStyle(.secondary)
      CloudSettings()
      Text(L10n.text("Set automatic upload and label printing for each session in the Foliobruma menu."))
        .font(.caption).foregroundStyle(.secondary)
      USBButtonSettings()
      DeveloperSettings()
    }
    .formStyle(.grouped)
    .padding(12)
    .frame(width: 600, height: 760)
  }
}
