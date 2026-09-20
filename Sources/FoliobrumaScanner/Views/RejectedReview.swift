import SwiftUI

struct RejectedReview: View {
  @ObservedObject var model: Scanner
  var current: RejectedScan? {
    model.rejectedScans.first { model.folder.appendingPathComponent($0.file) == model.rejectedURL }
      ?? model.rejectedScans.first
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label(L10n.text("Rejected scans"), systemImage: "exclamationmark.triangle").font(.title2)
        Spacer()
        Button(L10n.text("Done")) { model.showRejected = false }.keyboardShortcut(.cancelAction).disabled(
          model.busy)
      }
      Text(L10n.text("Capture is paused. These photos are excluded from your PDF.")).foregroundStyle(
        .secondary)
      if let scan = current {
        Picker(
          L10n.text("Photo"),
          selection: Binding(
            get: { scan.id },
            set: { id in
              if let item = model.rejectedScans.first(where: { $0.id == id }) {
                model.reviewRejected(item)
              }
            })
        ) {
          ForEach(Array(model.rejectedScans.enumerated()), id: \.element.id) { index, item in
            Text(L10n.format("Photo %ld · %@", index + 1, L10n.text(item.reason))).tag(item.id)
          }
        }.disabled(model.busy)
        Text(L10n.text(scan.reason)).font(.headline)
        ZoomImage(url: model.folder.appendingPathComponent(scan.file))
        HStack {
          Button(L10n.text("Rescan")) {
            model.replacementID = scan.replacementID
            model.showRejected = false
            model.qualityWarning = nil
            model.showCamera()
            model.status = L10n.text("Capture a new photo. The rejected photo remains available for review.")
          }.keyboardShortcut("r", modifiers: [.command, .shift])
            .help(L10n.text("Rescan (⌘⇧R)"))
          Button(L10n.text("Dismiss from review")) { model.dismissRejected(scan) }
            .keyboardShortcut(.delete, modifiers: [.command])
            .help(L10n.text("Dismiss from review (⌘⌫). The image file is kept."))
          Spacer()
          Button(L10n.text("Keep this scan anyway")) {
            model.reviewRejected(scan)
            model.keepRejected()
          }.buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .help(L10n.text("Keep this scan anyway (⌘↩)"))
        }.disabled(model.busy)
        Text(L10n.text("Original files are kept. Dismissal does not delete the photo.")).font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ContentUnavailableView(L10n.text("No scans need review"), systemImage: "checkmark.circle")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      if model.busy { ProgressView(L10n.text("Saving scan…")) }
      if let error = model.error { Text(error).foregroundStyle(.red).font(.callout) }
    }.padding(22).frame(width: 760, height: 580).interactiveDismissDisabled(model.busy)
  }
}
