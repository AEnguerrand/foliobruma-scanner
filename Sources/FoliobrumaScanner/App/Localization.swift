import Foundation

// Resolve once per launch so camera messages and controls use the same language.
enum L10n {
  static let language = Bundle.main.preferredLocalizations.first ?? "en"
  static let locale = Locale(identifier: language)
  static let bundle: Bundle = {
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
      let localized = Bundle(path: path)
    else { return .main }
    return localized
  }()

  static func text(_ key: String, bundle: Bundle = L10n.bundle) -> String {
    bundle.localizedString(forKey: key, value: key, table: "Localizable")
  }

  static func format(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: text(key), locale: locale, arguments: arguments)
  }

  // AppleLanguages is scoped to this app. Removing it restores the system choice.
  static func setLanguage(_ language: String, defaults: UserDefaults = .standard) {
    guard ["system", "en", "fr"].contains(language) else { return }
    defaults.set(language, forKey: "appLanguage")
    if language == "system" {
      defaults.removeObject(forKey: "AppleLanguages")
    } else {
      defaults.set([language], forKey: "AppleLanguages")
    }
  }
}
