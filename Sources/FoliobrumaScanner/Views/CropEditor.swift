import SwiftUI

struct CropEditor: View {
  @ObservedObject var model: Scanner
  @State private var image: NSImage?
  @State private var loading = true
  @State private var left = 0.0
  @State private var right = 1.0
  @State private var top = 1.0
  @State private var bottom = 0.0
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L10n.text("Crop from original")).font(.title2)
      Text(
        L10n.text("Select the area for this page. For a book spread, select only the required side. The original and earlier page image are kept.")
      )
      .foregroundStyle(.secondary)
      GeometryReader { geometry in
        if let image = image {
          let scale = min(
            geometry.size.width / image.size.width, geometry.size.height / image.size.height)
          let width = image.size.width * scale
          let height = image.size.height * scale
          ZStack(alignment: .topLeading) {
            Image(nsImage: image).resizable().frame(width: width, height: height)
            Rectangle().stroke(.yellow, lineWidth: 3)
              .frame(width: (right - left) * width, height: (top - bottom) * height)
              .offset(x: left * width, y: (1 - top) * height)
          }.frame(width: geometry.size.width, height: geometry.size.height)
        } else if loading {
          ProgressView(L10n.text("Loading image…"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Text(L10n.text("Original image unavailable")).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }.background(.black).environment(\.colorScheme, .dark)
      Grid(alignment: .leading) {
        GridRow {
          Text(L10n.text("Left"))
          Slider(value: $left, in: 0...max(0.001, right - 0.02)).accessibilityLabel(
            L10n.text("Left crop edge"))
          Text(L10n.text("Right"))
          Slider(value: $right, in: min(0.999, left + 0.02)...1).accessibilityLabel(
            L10n.text("Right crop edge"))
        }
        GridRow {
          Text(L10n.text("Top"))
          Slider(value: $top, in: min(0.999, bottom + 0.02)...1).accessibilityLabel(L10n.text("Top crop edge"))
          Text(L10n.text("Bottom"))
          Slider(value: $bottom, in: 0...max(0.001, top - 0.02)).accessibilityLabel(
            L10n.text("Bottom crop edge"))
        }
      }.disabled(model.busy)
      HStack {
        Button(L10n.text("Cancel")) { model.showCrop = false }.keyboardShortcut(.cancelAction).disabled(
          model.busy)
        Button(L10n.text("Reset edges")) {
          left = 0
          right = 1
          top = 1
          bottom = 0
        }.disabled(model.busy)
        Spacer()
        if model.busy { ProgressView().controlSize(.small) }
        Button(L10n.text("Save crop")) {
          model.cropSelectedPage(
            to: CGRect(x: left, y: bottom, width: right - left, height: top - bottom))
        }
        .buttonStyle(.borderedProminent).disabled(image == nil || model.busy)
        .keyboardShortcut(.return, modifiers: [.command])
        .help(L10n.text("Save crop (⌘↩)"))
      }
      if let error = model.error { Text(error).foregroundStyle(.red).font(.callout) }
    }.padding(22).frame(width: 740, height: 580).interactiveDismissDisabled(model.busy)
      .task {
        guard let page = model.selectedPage else { loading = false; return }
        let url = model.folder.appendingPathComponent(page.original)
        let data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }
          .value
        if !Task.isCancelled {
          image = data.flatMap { NSImage(data: $0) }
          loading = false
        }
      }
  }
}
