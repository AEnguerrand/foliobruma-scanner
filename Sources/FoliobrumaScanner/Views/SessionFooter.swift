import AppKit
import SwiftUI

struct SessionFooter: View {
  @ObservedObject var model: Scanner
  var body: some View {
    VStack(spacing: 8) {
      if let progress = model.exportProgress {
        ProgressView(model.status, value: progress).accessibilityLabel(model.status)
      }
      HStack(spacing: 12) {
        Label(
          model.sessionSaved ? L10n.text("Session saved on this Mac") : L10n.text("New session · No pages saved"),
          systemImage: "internaldrive"
        ).font(.caption).foregroundStyle(.secondary)
        Spacer()
        if !model.rejectedScans.isEmpty {
          Button(L10n.format("Rejected (%ld)", model.rejectedScans.count)) {
            model.autoCapture = false
            model.showRejected = true
          }.disabled(model.busy)
        }
        Button(L10n.text("Undo removal"), action: model.undo).keyboardShortcut("z")
          .disabled(model.deleting == nil || model.busy)
        Menu {
          Button(L10n.text("Originals and session")) { NSWorkspace.shared.open(model.folder) }
          if let pdf = model.lastPDF {
            Button(L10n.text("Open PDF")) { NSWorkspace.shared.open(pdf) }
            Button(L10n.text("Show PDF in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([pdf]) }
          }
        } label: {
          Label(L10n.text("Files"), systemImage: "folder")
        }
        if model.lastPDF != nil {
          Label(
            model.pdfIsCurrent ? L10n.text("PDF is up to date") : L10n.text("PDF needs export"),
            systemImage: model.pdfIsCurrent ? "checkmark.circle" : "arrow.clockwise"
          )
          .font(.caption).foregroundStyle(model.pdfIsCurrent ? .secondary : .primary)
        }
      }
    }.padding(12)
  }
}
