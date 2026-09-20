import AppKit
import SwiftUI

struct SessionFooter: View {
  @ObservedObject var model: Scanner
  var body: some View {
    HStack(spacing: 20) {
      Label(
        model.connected ? "\(model.resolution) · Connected" : "Local only",
        systemImage: model.connected ? "camera" : "lock")
      Text("\(model.document.pages.count) pages")
      Spacer()
      Button("Undo removal", action: model.undo).disabled(model.deleting == nil)
      Button {
        NSWorkspace.shared.open(model.folder)
      } label: {
        Label("Originals & session", systemImage: "folder")
      }
      if let pdf = model.lastPDF { Button("Open PDF") { NSWorkspace.shared.open(pdf) } }
    }.font(.callout).foregroundColor(.secondary).padding(18)
  }
}
