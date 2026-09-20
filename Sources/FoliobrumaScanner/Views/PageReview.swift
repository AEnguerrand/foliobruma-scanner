import SwiftUI

struct PageReview: View {
  @ObservedObject var model: Scanner
  @State private var confirmMerge = false
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Label(L10n.text("Capture paused"), systemImage: "pause.circle").foregroundStyle(.secondary)
        Spacer()
        if let index = model.selectedIndex {
          Text(L10n.format("Page %ld of %ld", index + 1, model.document.pages.count)).font(.headline)
        }
        Spacer()
        Button {
          model.navigatePage(-1)
        } label: {
          Image(systemName: "chevron.left")
        }
        .keyboardShortcut(.leftArrow, modifiers: []).help(L10n.text("Previous page (←)"))
        .accessibilityLabel(L10n.text("Previous page")).disabled((model.selectedIndex ?? 0) == 0)
        Button {
          model.navigatePage(1)
        } label: {
          Image(systemName: "chevron.right")
        }
        .keyboardShortcut(.rightArrow, modifiers: []).help(L10n.text("Next page (→)"))
        .accessibilityLabel(L10n.text("Next page"))
        .disabled(
          model.selectedIndex == nil || model.selectedIndex == model.document.pages.count - 1)
      }.padding(14)
      if let page = model.selectedPage {
        ZoomImage(url: model.folder.appendingPathComponent(page.file), rotation: page.rotation).id(
          page.file)
        ViewThatFits(in: .horizontal) {
          HStack {
            editActions(page)
            orderActions
          }
          VStack {
            HStack { editActions(page) }
            HStack { orderActions }
          }
        }.padding(14)
      } else {
        ContentUnavailableView(
          L10n.text("No page selected"), systemImage: "doc.text.magnifyingglass",
          description: Text(L10n.text("Select a page in the sidebar, or return to Scan to add pages."))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }.disabled(model.busy)
      .confirmationDialog(L10n.text("Merge with next page?"), isPresented: $confirmMerge,
                          titleVisibility: .visible) {
        Button(L10n.text("Merge pages")) { model.mergeWithNextPage() }
        Button(L10n.text("Cancel"), role: .cancel) {}
      } message: {
        Text(L10n.text("The selected page goes on the left. The next page goes on the right. Their heights are matched. Original files are kept. Overlapping details are not aligned."))
      }
  }
  @ViewBuilder func editActions(_ page: ScanPage) -> some View {
    Button(L10n.text("Rotate")) { model.rotate(page) }.keyboardShortcut("r")
    Button(L10n.text("Crop from original…")) {
      model.autoCapture = false
      model.showCrop = true
    }.keyboardShortcut("c", modifiers: [.command, .shift])
      .help(L10n.text("Crop from original (⌘⇧C)"))
    Button(L10n.text("Replace…"), action: model.replaceSelectedPage)
      .keyboardShortcut("r", modifiers: [.command, .shift])
      .help(L10n.text("Replace page (⌘⇧R)"))
    Button(L10n.text("Remove")) { model.remove(page) }
      .keyboardShortcut(.delete, modifiers: [.command])
      .help(L10n.text("Remove page (⌘⌫). Original files are kept."))
  }
  @ViewBuilder var orderActions: some View {
    Button(L10n.text("Merge with next page…")) { confirmMerge = true }
      .disabled(!model.canMergeWithNextPage)
    Button(L10n.text("Move earlier")) { model.movePage(-1) }
      .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
      .help(L10n.text("Move earlier (⌘⇧←)"))
      .disabled((model.selectedIndex ?? 0) == 0)
    Button(L10n.text("Move later")) { model.movePage(1) }
      .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
      .help(L10n.text("Move later (⌘⇧→)"))
      .disabled(model.selectedIndex == nil || model.selectedIndex == model.document.pages.count - 1)
  }
}

struct ZoomImage: View {
  let url: URL
  var rotation = 0
  @State private var image: NSImage?
  @State private var zoom = 1.0
  var body: some View {
    VStack(spacing: 0) {
      GeometryReader { geometry in
        if let image = image {
          let turned = rotation % 180 != 0
          let size = image.size
          let width = max(1, turned ? size.height : size.width)
          let height = max(1, turned ? size.width : size.height)
          let fit = min(
            max(1, geometry.size.width - 32) / width, max(1, geometry.size.height - 32) / height)
          ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image).resizable()
              .frame(width: size.width * fit * zoom, height: size.height * fit * zoom)
              .rotationEffect(.degrees(Double(rotation)))
              .frame(width: width * fit * zoom, height: height * fit * zoom)
              .padding(16)
              .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
          }
        } else {
          ContentUnavailableView(
            L10n.text("Image unavailable"), systemImage: "doc.questionmark",
            description: Text(L10n.text("Check that the session image file is still on this Mac.")))
        }
      }.background(.black)
      HStack {
        Button(L10n.text("Fit")) { zoom = 1 }.keyboardShortcut("0")
          .help(L10n.text("Fit image (⌘0)"))
        Slider(value: $zoom, in: 1...5).frame(width: 180).accessibilityLabel(L10n.text("Image zoom"))
        Text(L10n.format("%ld%% of fit", Int(zoom * 100))).monospacedDigit().frame(width: 110)
        Spacer()
        Text(L10n.text("Scroll to inspect a zoomed image")).font(.caption).foregroundStyle(.secondary)
      }.padding(10)
    }.task(id: url) {
      let file = url
      let data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: file) }.value
      guard !Task.isCancelled else { return }
      image = data.flatMap { NSImage(data: $0) }
      zoom = 1
    }
  }
}
