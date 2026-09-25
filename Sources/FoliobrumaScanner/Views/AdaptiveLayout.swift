import AppKit
import SwiftUI

// Keep actions readable when translations or a narrow pane need more space.
struct AdaptiveActions<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) { content }.fixedSize(horizontal: true, vertical: false)
      VStack(spacing: 10) { content }
    }.frame(maxWidth: .infinity)
  }
}

extension View {
  // Sheets must leave room for the parent title bar and the screen edges.
  // Their content must scroll independently of their action buttons.
  func fittedPanel(width: CGFloat, height: CGFloat, withinParent: Bool = true) -> some View {
    let documentWindow = NSApp.keyWindow?.sheetParent ?? NSApp.mainWindow
      ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain && $0.sheetParent == nil }
    let parent = withinParent ? documentWindow : nil
    let screen = parent?.screen ?? NSScreen.main
    let visible = screen?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
    let availableWidth = min(visible.width - 80, (parent?.frame.width ?? visible.width) - 32)
    let availableHeight = min(visible.height - 96, (parent?.frame.height ?? visible.height) - 80)
    return frame(width: min(width, max(320, availableWidth)),
                 height: min(height, max(320, availableHeight)))
  }
}
