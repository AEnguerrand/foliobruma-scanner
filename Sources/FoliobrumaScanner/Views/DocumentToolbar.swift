import SwiftUI

struct DocumentToolbar: ToolbarContent {
  @ObservedObject var model: Scanner
  @Binding var rename: Bool
  @Binding var showSetup: Bool
  @Binding var showUpload: Bool

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button(action: model.browseSessions) {
        Label(L10n.text("Documents"), systemImage: "sidebar.left")
      }.help(L10n.text("Documents"))
      Button(action: model.prepareNewItem) {
        Label(L10n.text("New item…"), systemImage: "plus")
      }.help(L10n.text("New item…"))
    }
    ToolbarItem(placement: .principal) {
      Picker(L10n.text("Workspace"), selection: Binding(
        get: { model.metadataWorkspace ? "metadata" : (model.reviewing ? "review" : "scan") },
        set: {
          switch $0 {
          case "metadata": model.showCatalog()
          case "review": model.beginReview()
          default: model.showCamera()
          }
        })) {
          Text(L10n.text("Scan")).tag("scan")
          Text(L10n.text("Review")).tag("review")
          Text(L10n.text("Details")).tag("metadata")
        }.pickerStyle(.segmented).frame(width: 220).disabled(model.busy)
    }
    ToolbarItemGroup(placement: .primaryAction) {
      Menu {
        Button(L10n.text("Rename document…")) { model.autoCapture = false; rename = true }
        Button(L10n.text("Edit details…"), action: model.showItemMetadata)
        Divider()
        Button(L10n.text("Export PDF"), action: model.prepareExport)
          .disabled(model.document.pages.isEmpty)
        Button(L10n.text("Upload to Foliobruma")) { model.autoCapture = false; showUpload = true }
          .disabled(model.document.pages.isEmpty)
        Button(L10n.text("Label…"), action: model.showItemLabel)
        if model.isSheetBatch { Button(L10n.text("Group sheets…"), action: model.prepareSheetGroups) }
        Divider()
        Menu(L10n.text("Recovery")) {
          Button(L10n.text("Confirm label handled"), action: model.confirmSheetLabelHandled)
          Button(L10n.text("Clear upload record…"), action: model.clearCloudUpload)
          Button(L10n.text("Open session folder…"), action: model.openSession)
        }
      } label: { Label(L10n.text("Document actions"), systemImage: "ellipsis.circle") }
        .accessibilityLabel(L10n.text("Document actions")).help(L10n.text("Document actions"))
        .disabled(model.busy)
      if model.reviewing || model.metadataWorkspace {
        Button(model.finishActionTitle, action: model.finishCurrentItem)
          .disabled(model.busy || model.document.pages.isEmpty)
      }
      if !model.reviewing && !model.metadataWorkspace {
        Button { showSetup.toggle() } label: {
          Label(L10n.text("Scan setup"), systemImage: "sidebar.right")
        }.help(L10n.text("Show or hide scan setup")).disabled(!model.connected)
      }
      FoliobrumaConnectionButton(model: model)
    }
  }
}

struct ScannerCommands: Commands {
  @FocusedObject private var model: Scanner?
  private func perform(_ action: (Scanner) -> Void) {
    guard let model, !model.busy, model.error == nil,
      NSApp.keyWindow?.attachedSheet == nil, NSApp.keyWindow?.sheetParent == nil,
      NSApp.modalWindow == nil else { return }
    action(model)
  }
  private var canEditPages: Bool {
    guard let model else { return false }
    return model.reviewing && !model.metadataWorkspace && !model.busy && model.selectedPage != nil
      && !model.showNewItem && !model.showMetadata && !model.showLabel && !model.showSessions
      && !model.showRejected && !model.showExport && !model.showCrop && !model.showSheetGroups
      && NSApp.mainWindow?.attachedSheet == nil && NSApp.modalWindow == nil
  }
  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button(L10n.text("New item…")) { perform { $0.prepareNewItem() } }.keyboardShortcut("n")
        .disabled(model == nil || model?.busy == true)
      Button(L10n.text("Documents")) { perform { $0.browseSessions() } }.keyboardShortcut("o")
        .disabled(model == nil || model?.busy == true)
    }
    CommandMenu(L10n.text("Page")) {
      Button(L10n.text("Replace…")) { if canEditPages { perform { $0.replaceSelectedPage() } } }
        .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(!canEditPages)
      Button(L10n.text("Move earlier")) { if canEditPages { perform { $0.movePage(-1) } } }
        .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
        .disabled(!canEditPages || (model?.selectedIndex ?? 0) == 0)
      Button(L10n.text("Move later")) { if canEditPages { perform { $0.movePage(1) } } }
        .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
        .disabled(!canEditPages || model?.selectedIndex == (model?.document.pages.count ?? 0) - 1)
    }
    CommandGroup(after: .saveItem) {
      Button(L10n.text("Export PDF")) { perform { $0.prepareExport() } }.keyboardShortcut("e")
        .disabled(model == nil || model?.busy == true || model?.document.pages.isEmpty == true)
      Button(model?.finishActionTitle ?? L10n.text("Finish item")) { perform { $0.finishCurrentItem() } }.keyboardShortcut(.return, modifiers: [.command, .shift])
        .disabled(model == nil || model?.busy == true || model?.document.pages.isEmpty == true)
    }
  }
}
