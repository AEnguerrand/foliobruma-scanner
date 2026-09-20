import AppKit
import SwiftUI

struct PageStrip: View {
  @ObservedObject var model: Scanner
  let gold: Color
  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 22) {
        if model.document.pages.isEmpty {
          Label("Captured pages will appear here", systemImage: "book").foregroundColor(.secondary)
            .padding(30)
        }
        ForEach(Array(model.document.pages.enumerated()), id: \.element.id) { index, p in
          Button {
            model.selected = p.id
          } label: {
            VStack(spacing: 6) {
              if let img = model.image(p) {
                Image(nsImage: img).resizable().scaledToFit().frame(width: 92, height: 88)
                  .rotationEffect(.degrees(Double(p.rotation)))
              }
              Text("\(index+1)").font(.caption)
            }.padding(7).background(model.selected == p.id ? gold.opacity(0.15) : Color.clear)
              .cornerRadius(5)
          }.buttonStyle(.plain)
        }
        Spacer()
      }.padding(.horizontal, 30).padding(.vertical, 10)
    }.frame(height: 132).background(Color(white: 0.12))
  }
}
