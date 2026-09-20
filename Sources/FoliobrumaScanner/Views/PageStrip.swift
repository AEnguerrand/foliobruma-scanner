import ImageIO
import SwiftUI

struct PageStrip: View {
  @ObservedObject var model: Scanner
  let gold: Color
  @State private var pageNumber = 1
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.text("Pages")).font(.headline).padding(.horizontal, 12)
      HStack {
        TextField(L10n.text("Page"), value: $pageNumber, format: .number).frame(width: 65)
          .accessibilityLabel(L10n.text("Page number"))
          .onSubmit { jump() }
        Button(L10n.text("Go"), action: jump)
      }.padding(.horizontal, 12)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(Array(model.document.pages.enumerated()), id: \.element.id) { index, page in
              Button {
                model.beginReview(page.id)
              } label: {
                VStack(spacing: 6) {
                  PageThumbnail(
                    url: model.folder.appendingPathComponent(page.file), rotation: page.rotation
                  )
                  .frame(width: 132, height: 116)
                  HStack {
                    Text(L10n.format("Page %ld", index + 1))
                    if model.selected == page.id { Image(systemName: "checkmark.circle.fill") }
                  }.font(.caption)
                }.padding(8).frame(maxWidth: .infinity)
                  .background(model.selected == page.id ? gold.opacity(0.15) : Color.clear)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                      model.selected == page.id ? gold : .clear, lineWidth: 2))
              }.buttonStyle(.plain).id(page.id)
                .accessibilityLabel(L10n.format("Page %ld of %ld", index + 1, model.document.pages.count))
                .accessibilityAddTraits(model.selected == page.id ? [.isSelected] : [])
            }
          }.padding(10)
        }.onChange(of: model.selected) {
          if let id = model.selected { proxy.scrollTo(id, anchor: .center) }
        }.onAppear { if let id = model.selected { proxy.scrollTo(id, anchor: .center) } }
      }
    }.padding(.top, 14).background(Color(white: 0.13)).disabled(model.busy)
  }
  private func jump() {
    guard model.document.pages.indices.contains(pageNumber - 1) else { return }
    model.beginReview(model.document.pages[pageNumber - 1].id)
  }
}

struct PageThumbnail: View {
  let url: URL
  let rotation: Int
  @State private var image: NSImage?
  var body: some View {
    Group {
      if let image = image {
        Image(nsImage: image).resizable().scaledToFit().rotationEffect(.degrees(Double(rotation)))
          .padding(rotation % 180 == 0 ? 0 : 12)
      } else {
        Image(systemName: "doc").foregroundStyle(.secondary)
      }
    }.task(id: url) {
      let file = url
      let result = await Task.detached(priority: .utility) { () -> CGImage? in
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 280,
            kCGImageSourceCreateThumbnailWithTransform: true,
          ] as CFDictionary)
      }.value
      guard !Task.isCancelled else { return }
      image = result.map { NSImage(cgImage: $0, size: .zero) }
    }
  }
}
