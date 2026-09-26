import SwiftUI

#if !SCANNER_TESTS
  @main struct FoliobrumaApp: App {
    var body: some Scene {
      WindowGroup("Foliobruma Scanner") { ContentView() }.defaultSize(
        width: 1440, height: 1000
      ).commands { ScannerCommands() }
      Settings { SettingsView() }.windowResizability(.contentSize)
    }
  }

#endif
