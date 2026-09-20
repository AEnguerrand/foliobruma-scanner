import SwiftUI

struct FramingPreview: View {
  @ObservedObject var model: Scanner
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(L10n.text("Crop and split preview")).font(.title2)
        Spacer()
        Button(L10n.text("Done")) { model.showFraming = false }.keyboardShortcut(.cancelAction).disabled(
          model.busy)
      }
      Text(
        L10n.text("Preview from the camera feed. No page has been saved. Check edges and spine before scanning.")
      )
      .foregroundStyle(.secondary)
      if model.busy {
        ProgressView(L10n.text("Preparing preview…")).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        HStack {
          ForEach(Array(model.framingImages.enumerated()), id: \.offset) { index, image in
            VStack {
              Image(nsImage: image).resizable().scaledToFit()
              Text(L10n.format("Page %ld", index + 1)).font(.caption)
            }
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }.padding(24).frame(width: 720, height: 520).interactiveDismissDisabled(model.busy)
  }
}
